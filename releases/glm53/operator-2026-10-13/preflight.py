"""Check the real GPU and GLM-5.3-Flash backend without loading weights."""
import importlib
import importlib.metadata
import inspect
import json
import math
import os
from pathlib import Path
import socket
import time
import traceback

import vllm
import torch
from vllm.config import VllmConfig, set_current_vllm_config
from vllm.model_executor.models import ModelRegistry
from vllm.platforms import current_platform
from vllm.v1.attention.selector import get_attn_backend


def run_check(report, name, function):
    try:
        value = function()
        report[name] = {"passed": True, "result": value}
    except Exception as error:
        report[name] = {
            "passed": False,
            "error_type": type(error).__name__,
            "error": str(error),
            "traceback": traceback.format_exc(),
        }
    print(json.dumps({name: report[name]}), flush=True)


def main():
    metadata_dir = Path(os.environ["GLM_METADATA_DIR"])
    cfg = json.loads((metadata_dir / "config.json").read_text())
    text_cfg = cfg.get("text_config", cfg)
    report = {
        "test": "GLM-5.3-Flash GPU compatibility; no checkpoint weights loaded",
        "job_id": os.environ.get("SLURM_JOB_ID"),
        "node": socket.gethostname(),
        "started_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "model": "zai-org/GLM-5.3-Flash",
        "model_metadata": json.loads((metadata_dir / "manifest.json").read_text()),
        "versions": {},
        "attention_config": {
            key: text_cfg.get(key)
            for key in ["kv_lora_rank", "qk_nope_head_dim", "qk_rope_head_dim", "mla_nope", "index_topk"]
        },
    }
    for name in ["vllm", "torch", "transformers", "flashinfer-python"]:
        try:
            report["versions"][name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            report["versions"][name] = None
    report["target_registered"] = "Glm5NextForConditionalGeneration" in ModelRegistry.get_supported_archs()

    def gpu_check():
        torch.cuda.init()
        x = torch.ones((32, 32), device="cuda", dtype=torch.bfloat16)
        y = x @ x
        torch.cuda.synchronize()
        assert y[0, 0].item() == 32
        props = torch.cuda.get_device_properties(0)
        return {"name": props.name, "compute_capability": list(torch.cuda.get_device_capability(0)), "total_memory_bytes": props.total_memory, "bf16_matmul": "passed"}

    run_check(report, "gpu", gpu_check)
    if report["gpu"]["passed"]:
        capability = current_platform.get_device_capability()

        def inspect_model():
            from vllm.model_executor.models.interfaces import supports_pp
            entry = ModelRegistry.models["Glm5NextForConditionalGeneration"]
            module = importlib.import_module(entry.module_name)
            cls = getattr(module, entry.class_name)
            return {"module": entry.module_name, "class": cls.__name__, "supports_pipeline_parallel": supports_pp(cls)}

        run_check(report, "model_import", inspect_model)

        def choose_sparse_backend():
            signature = inspect.signature(get_attn_backend)
            print("selector_signature:", str(signature), flush=True)
            kwargs = {
                "head_size": int(text_cfg.get("kv_lora_rank", 512)) + (0 if text_cfg.get("mla_nope") else int(text_cfg.get("qk_rope_head_dim", 0))),
                "dtype": torch.bfloat16,
                "kv_cache_dtype": "auto",
                "use_mla": True,
                "use_sparse": True,
            }
            if "num_heads" in signature.parameters:
                kwargs["num_heads"] = int(text_cfg.get("num_attention_heads", 64))
            with set_current_vllm_config(VllmConfig()):
                backend = get_attn_backend(**kwargs)
            return {"backend": backend.__name__, "head_size": kwargs["head_size"], "sparse": True}

        run_check(report, "sparse_backend_selection", choose_sparse_backend)

        if report["sparse_backend_selection"]["passed"] and "Triton" in report["sparse_backend_selection"]["result"]["backend"]:
            def sparse_kernel_check():
                from vllm.v1.attention.ops.triton_mla_sparse_kernel import triton_mla_sparse_attention
                torch.manual_seed(42)
                q = torch.randn((2, 4, 512), device="cuda", dtype=torch.bfloat16)
                kv = torch.randn((64, 1, 512), device="cuda", dtype=torch.bfloat16)
                indices = torch.tensor([list(range(16)), list(range(16, 32))], device="cuda", dtype=torch.int32).unsqueeze(1)
                scale = 1 / math.sqrt(512)
                result = triton_mla_sparse_attention(q, kv, indices, sm_scale=scale, num_kv_splits=1)
                chosen = kv[indices[:, 0].long(), 0].float()
                scores = torch.einsum("thd,tkd->thk", q.float(), chosen) * scale
                expected = torch.einsum("thk,tkd->thd", torch.softmax(scores, dim=-1), chosen)
                torch.cuda.synchronize()
                torch.testing.assert_close(result.float(), expected, rtol=0.02, atol=0.02)
                return {"shape": list(result.shape), "reference": "PyTorch FP32 sparse attention", "max_absolute_error": (result.float() - expected).abs().max().item()}
            run_check(report, "triton_sparse_kernel", sparse_kernel_check)

        if os.environ.get("GLM_CHECK_MHC") == "1":
            def mhc_check():
                import tilelang
                import tilelang.webgpu
                from vllm.model_executor.kernels.mhc import mhc_pre_tilelang, mhc_pre_torch
                torch.manual_seed(123)
                residual = torch.randn((8, 4, 4096), device="cuda", dtype=torch.bfloat16)
                fn = torch.randn((24, 4 * 4096), device="cuda", dtype=torch.float32) * 0.01
                scale = torch.ones((3,), device="cuda", dtype=torch.float32)
                base = torch.randn((24,), device="cuda", dtype=torch.float32) * 0.01
                arguments = (residual, fn, scale, base, 1e-6, 1e-6, 1e-6, 2.0, 20)
                with set_current_vllm_config(VllmConfig()):
                    actual = mhc_pre_tilelang(*arguments)
                    expected = mhc_pre_torch(*arguments)
                torch.cuda.synchronize()
                errors = []
                for a, b in zip(actual, expected, strict=True):
                    torch.testing.assert_close(a.float(), b.float(), rtol=0.02, atol=0.02)
                    errors.append((a.float() - b.float()).abs().max().item())
                return {"tilelang_version": importlib.metadata.version("tilelang"), "import_path": str(Path(tilelang.__file__)), "reference": "vLLM PyTorch mHC pre implementation", "max_absolute_errors": errors}
            run_check(report, "mhc_pre_kernel", mhc_check)

        checks = [
            ("flashattn_mla_sparse", "FlashAttnMLASparseBackend"),
            ("flashinfer_mla_sparse", "FlashInferMLASparseTRTLLMBackend"),
            ("flashinfer_mla_sparse_sm90", "FlashInferMLASparseSM90Backend"),
            ("flashmla_sparse", "FlashMLASparseBackend"),
        ]
        for module_name, class_name in checks:
            def check(module_name=module_name, class_name=class_name):
                module = importlib.import_module("vllm.v1.attention.backends.mla." + module_name)
                cls = getattr(module, class_name)
                return {"supports_actual_gpu": cls.supports_compute_capability(capability), "head_sizes": cls.get_supported_head_sizes()}
            run_check(report, class_name, check)

    report["weights_downloaded"] = False
    report["inference_tested"] = False
    report["preflight_passed"] = all(report.get(key, {}).get("passed", False) for key in ["gpu", "model_import", "sparse_backend_selection"])
    if "triton_sparse_kernel" in report:
        report["preflight_passed"] = report["preflight_passed"] and report["triton_sparse_kernel"]["passed"]
    if "mhc_pre_kernel" in report:
        report["preflight_passed"] = report["preflight_passed"] and report["mhc_pre_kernel"]["passed"]
    output = Path(os.environ["GLM_PREFLIGHT_OUTPUT"])
    output.write_text(json.dumps(report, indent=2) + "\n")
    print("saved_report:", str(output), flush=True)
    raise SystemExit(0 if report["preflight_passed"] else 2)


if __name__ == "__main__":
    main()
