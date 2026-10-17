# Historical validation and scope

The original Leonardo runs took place on 8 and 13 October 2026. Public packaging on 17 October generalized personal team paths, project account identifiers and job names. Local checks of this adapted repository do not replace GPU inference validation.

## Qwen3-235B-A22B-FP8

- Model revision: `39eb2b067ea6b8e3e1dd97d3cd0c7ffeaf3e1a35`.
- Two Leonardo nodes, eight NVIDIA A100 64GB GPUs, TP=4 within nodes and PP=2 across nodes, without Ray.
- vLLM 0.31.0, host driver 535.274.02 with CUDA compatibility enabled.
- FP8 weights, BF16 activations, Marlin kernels, 2,048-token context, four active sequences.
- Checkpoint: approximately 239.07GB, 48 weight shards. Required-file sizes and checkpoint revision were checked.
- Successful internal and external inference, authentication rejection without a key, and four concurrent short requests.
- Eager Safetensors loading was used after investigating slow mmap loading on Lustre. Node/cache conditions differed between attempts; no controlled speedup percentage is claimed.

## GLM-5.3-Flash

- Model revision: `91b69215804f2d2036a8867f6ce44848e278dcda`.
- Two nodes, eight A100 64GB GPUs; TP=4, PP=2; text-only inference.
- Community vLLM SM80 backport 0.13.1; Triton sparse MLA; Marlin FP8 kernels; BF16 activations/KV cache.
- Checkpoint: 328,337,455,672 bytes, 62 shards. Required-file sizes and revision were checked; independent hashing of every weight file was not performed.
- Seven English-only checks passed in the subsequent team session: authentication rejection, model catalog, arithmetic, English output, SSE streaming, function-call JSON and four concurrent requests.
- Function-call output was validated without executing a function. The observed response used `finish_reason=stop`; adapters must inspect `tool_calls` directly.
- In one successful original run, API health was reached after 775.72 seconds, excluding download, image creation and queue time. A later team session reached health after 565.57 seconds. These are observations, not a benchmark comparison.
- Logs confirmed NCCL communication using InfiniBand and GPUDirect RDMA paths.

Pinned backport image:

```text
docker://lazymio/vllm-backport@sha256:0fc33cd7d2be777bf6faaee9b02adf781dc6d0bc44b9a09ce4865089f67e9cba
Historical SIF SHA-256: 775d1d1acecb610301473c9b8ab74deb08bbec1766691fdf9e7c4fcea4957fa1
```

The image did not identify a source commit; a source-to-binary match was not independently verified. The backport and kernels are upstream/community work; the deployment work here configured, repaired and validated their use on Leonardo.

## Compatibility issues addressed

1. Missing A100 sparse MLA support in the stock GLM configuration: used a separately validated community SM80 runtime.
2. Incomplete TileLang package: restored the official same-version wheel into a separate Python overlay and checked mHC numerically on an A100 against PyTorch.
3. Read-only or unsuitable cache locations: redirected FlashInfer, TileLang and related caches to writable work storage.
4. Insufficient contained `/tmp` space during package installation: used shared work storage.
5. Unix socket path-length errors: mounted the runtime temporary directory at a shorter container path.

## Remaining validation

- Per-user candidate inference from the other team accounts.
- Production or unattended operation, long-duration stability and workshop-scale load.
- Joint operation with moderation models, long-context capacity and multimodal inputs.
- A controlled performance comparison with other hosted inference services.

The historical GPU jobs and their endpoints have ended. This repository contains no active endpoint or session API key.
