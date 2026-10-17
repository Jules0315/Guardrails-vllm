# GLM-5.3-Flash installation on Leonardo

This is the documented preparation workflow for the original A100 deployment, with public installation paths. GPU revalidation is required after adapting paths or runtime settings. Do preparation from a private working directory; preserve versioned source folders.

## Requirements and paths

- A personal Leonardo login, Slurm project allocation and access to the compute/serial partitions used by the scripts.
- `WORK` set by the cluster environment; `SBATCH_ACCOUNT` set to your approved project.
- Singularity/Apptainer, sufficient shared storage and an appropriate internet-enabled CPU partition for image/model preparation.
- A stock vLLM 0.31.0 SIF for compatibility comparison and checkpoint downloading. The Qwen preparation script can create it with `TEAM=team_vllm VLLM_TAG=v0.31.0`; set `SIF`/`GLM_SIF` as appropriate.

The public defaults use:

```text
$WORK/team_vllm/images/vllm-0.31.0.sif     stock image for compatibility/download
$WORK/team_vllm/glm53/images/             separate SM80 backport SIF
$WORK/team_vllm/glm53/models/             pinned GLM checkpoint
$WORK/team_vllm/glm53/python-overlay/     same-version TileLang repair
$WORK/team_vllm/users/<user>/glm53/       candidate per-user cache
```

To create that stock SIF with the Qwen preparation script, from `qwen/` set the tag used for the filename and the explicit upstream image separately:

```bash
export TEAM=team_vllm
export VLLM_TAG=0.31.0
export VLLM_IMAGE=docker://vllm/vllm-openai:v0.31.0
sbatch 00_prepare.sbatch
```

This CPU job also downloads the small default plumbing-test model. Wait for successful completion before using the SIF; inspect its logged versions and actual path.

## Preparation stages

1. Copy the operator-profile scripts and `metadata/manifest.json` into a private working directory. Obtain `metadata/config.json` from its pinned upstream revision using the metadata helper below. This repository intentionally does not bundle upstream model configuration/weights.
2. Use `01_preflight.sbatch` against the stock image to investigate CUDA initialization, model import and sparse-backend selection. In the historical A100 installation the stock image did not provide a usable sparse MLA backend.
3. Submit `02_prepare_backport.sbatch` on a CPU serial node to obtain the separate pinned SM80 image. Set `GLM_SIF` to that image and rerun preflight.
4. Submit `03_prepare_model.sbatch` only after checking storage. It downloads the pinned checkpoint and checks required-file sizes. The original checkpoint was approximately 328.34GB, with 62 shards; the script also requires a free-space reserve.
5. Obtain the official TileLang 0.1.12 wheel below and place it in `$WORK/team_vllm/glm53/wheels/`. `05_repair_tilelang.sbatch` verifies its hash and installs it into the separate overlay without upgrading dependencies.
6. Rerun preflight with `GLM_CHECK_MHC=1` and the backport SIF, then prepare a private inference run and key. The operator profile uses the retained shared cache; the per-user profile uses read-only model mounts and separate caches.
7. Submit `04_run_model.sbatch` explicitly after checking team coordination, account, resources, quota and runtime. Wait for `INFERENCE_READY` before sharing the new endpoint.

Metadata helper, from the repository root:

```bash
python3 tools/fetch_glm_metadata.py --output /your/private/run/metadata
```

It downloads only `config.json` from the pinned revision, verifies the expected SHA-256, and copies the public metadata manifest. It does not download weights or submit jobs.

Required repair wheel:

```text
tilelang-0.1.12-cp38-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl
SHA-256: bbeb5573cbe2544a51a5c9a6cc737c5e3b5c2d95411caa3687fd9b08eb9d5f97
Source: https://pypi.org/project/tilelang/0.1.12/#files
```

## Historical runtime settings

The successful original configuration used vLLM community backport 0.13.1, Triton sparse MLA, Marlin FP8 kernels, BF16 activations/KV cache, TP=4, PP=2, text-only input, 2,048-token context and four active sequences. It used a short `/tmp/glm-tmp` bind mount to avoid Unix socket path-length errors and writable work storage for kernel caches and wheel installation.

The corresponding image digest and measured validation scope are recorded in [validation](validation.md). These settings are model/runtime-specific, not universal defaults for other open-weight models.
