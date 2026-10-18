# Common framework: Leonardo GPU and English API validation

Both GLM-5.3-Flash and DeepSeek-V4.1-Flash-1017 passed real inference tests through the shared launcher on Leonardo. Each model used two nodes and eight A100 GPUs. The runs were sequential; the GLM allocation was stopped before DeepSeek was submitted.

| Profile | Slurm job | Nodes / GPUs | Time to healthy API | Startup suite | SSH client suites |
| --- | --- | --- | --- | --- | --- |
| glm53 | 61299807 | 2 / 8 A100 | 800.78 s | 7/7 | 2 × 7/7 |
| deepseek41 | 61300901 | 2 / 8 A100 | 1546.53 s | 7/7 | 2 × 7/7 |

The health timer starts in the batch lifecycle after the launcher is started. It includes cold-cache initialization and is not a request-latency benchmark. Each SSH suite ran all seven checks, with a 60-second observation interval between the two suites.

## What was tested

The exact execution code in `releases/inference/2026-10-18` was run with the common SIF/overlay location, explicit container mounts and private caches separated by profile and runtime ID. GLM used TP4/PP2. DeepSeek used TP8/PP1, expert parallelism and Engram CPU offload; its NCCL/EP correctness hook and read-only Engram warmup completed before model startup.

Each model passed:

1. Unauthenticated requests rejected with HTTP 401.
2. Authenticated model catalog containing the expected served alias.
3. English arithmetic response returning exactly `42`.
4. A nonempty English HPC assistant introduction, also manually reviewed.
5. SSE streaming with content and a terminal `[DONE]` event.
6. Forced `sum_numbers` function-call output with JSON arguments `a=17`, `b=25`. The tool was not executed.
7. Four concurrent arithmetic requests returning `42`.

The same checks then passed twice through an SSH local forward from the operator's computer. This is fresh GPU inference evidence; the separate mocked regression suite is not counted as model inference.

## Published snapshot and evidence

`scripts/inference` selects `releases/inference/2026-10-18-docs1`. The promoted snapshot adds the `QUICK_GUIDE.md` name and validation documentation/metadata. Its executable Python, shell and Slurm files are byte-for-byte identical to the GPU-tested release. Engine and client profile settings are unchanged; only profile validation text was updated. `GPU_VALIDATION.json` records execution hashes, the tested manifest digest and the two jobs. The repository checker verifies these relationships.

- [Team quick guide](../releases/inference/2026-10-18-docs1/QUICK_GUIDE.md)
- [Validation metadata](../releases/inference/2026-10-18-docs1/GPU_VALIDATION.json)
- [Reviewed GLM results](../validation/common-2026-10-18/glm53)
- [Reviewed DeepSeek results](../validation/common-2026-10-18/deepseek41)

The result folders contain startup checks, both client suites, timing and checkpoint metadata digests. Absolute checkpoint roots in model catalog responses are replaced with `<CHECKPOINT_DIRECTORY>`. Keys, private run directories, site configuration and raw cluster logs are excluded.

## Shutdown and limits

Both servers were explicitly cancelled after the API checks passed. Their private endpoints were removed, test keys were deleted and SSH forwards were cancelled. A Slurm `CANCELLED` state reflects this deliberate stop; it is not a natural successful batch exit. No validation server was left running.

These runs validate one operator account and a short API observation window. They do not establish another teammate's inference access, sustained application load, production availability or unattended authentication. A new server run creates a fresh key and endpoint. DeepSeek's four client requests are queued against `max-num-seqs=2`; GLM uses four sequence slots. Both profiles limit context to 2048 tokens.
