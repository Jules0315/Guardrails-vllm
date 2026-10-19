# Qwen3-235B common framework GPU validation — 19 October 2026

Qwen3-235B-A22B-FP8 passed real English API tests using the shared launcher and existing SM80 runtime on two Leonardo nodes, eight A100 GPUs, TP4/PP2. Model alias: `qwen3-235b-a22b-fp8-leonardo`. Checkpoint revision: `39eb2b067ea6b8e3e1dd97d3cd0c7ffeaf3e1a35`.

- Job: `61389137`; API healthy after `420.42` seconds (`7.0` minutes), excluding queue time.
- The pending validation job was changed to the permitted `boost_qos_dbg` QoS with a 30-minute limit. The published team profile retains its two-hour `boost_qos_lprod` default; node/GPU counts and engine settings are unchanged.
- Startup: 7/7 English API checks.
- SSH client: two repeat suites, each 7/7, separated by a 60-second observation interval.
- The checks cover HTTP 401 rejection, authenticated model catalog, exact arithmetic, an English HPC introduction, SSE plus `[DONE]`, function-call JSON and four concurrent requests. Tool calls were inspected, not executed. English responses were also manually reviewed.
- The server was explicitly cancelled after validation; the private endpoint, session keys and SSH forwards were removed. `CANCELLED` is the intended resource cleanup, not a natural successful batch exit.

## Runtime and port correction

The retained 48-shard checkpoint was reused without redownloading weights. Qwen uses the same registered `vllm-backport-sm80-0.13.1` SIF/overlay as GLM and DeepSeek, with eager loading, FP8 weights, Qwen3 reasoning parser, Hermes tool parser and `enable_thinking=false`. Context is 2048 tokens and maximum sequence slots are four.

During preparation, job `61388267` exposed an arithmetic overlap in the old port ranges: API and distributed-master ports could coincide for job suffixes 8000–8999. It was cancelled while pending with zero runtime and no GPU allocation. The corrected launcher uses API ports 31000–40999, separated from master/probe ports 29000–30000. A regression checks the actual batch-script formulas across all 10,000 suffixes. Candidate `2026-10-19` was withdrawn; test source is `2026-10-19-r2`.

The promoted `2026-10-19-docs1` snapshot changes documentation and validation metadata only relative to the GPU-tested r2 candidate. Execution hashes and profile comparisons are checked by the repository checker. GLM and DeepSeek Python code and engine settings remain unchanged; their GPU results remain those of 18 October. They were not GPU-rerun after the port-only correction.

## Team use and evidence

- [QUICK_GUIDE.md](../releases/inference/2026-10-19-docs1/QUICK_GUIDE.md)
- [Qwen GPU metadata](../releases/inference/2026-10-19-docs1/GPU_VALIDATION.json)
- [Reviewed Qwen results](../validation/common-2026-10-19/qwen235b)
- [Earlier GLM/DeepSeek results](common-gpu-validation.md)

Use `MODEL=qwen235b` with `scripts/inference/prepare_run.sh`. The guide covers private API-key creation/location, the dedicated SSH login, client tests, shutdown and adding models. Qwen weights remain in retained scratch storage; asset preflight checks readability. Four named teammates were granted read/traverse access to the checkpoint and shared release. This does not constitute a login/inference validation as those accounts.

This is one operator account and a short functional API test. It does not establish other-account access, sustained throughput, production availability or unattended authentication. Public evidence excludes keys, private paths and raw cluster logs; absolute model-catalog roots are redacted.
