# Shared model server and API quick guide

This release separates the deployment code, model profiles, runtime assets and private run state. Python 3.6+ is sufficient for the host tools. Model inference uses the separately registered SIF and Python overlay.

## Start a server on Leonardo

Coordinate one team server at a time. Set `BASE` to your existing team installation; this example uses a generic name.

```bash
BASE="$WORK/team_vllm"
FRAMEWORK="$BASE/scripts/inference"
RUN_DIR=$(bash "$FRAMEWORK/prepare_run.sh" glm53 --base "$BASE") && cd "$RUN_DIR"
```

For DeepSeek, change only `glm53` to `deepseek41`. Preparation verifies the code manifest and readable assets, copies the selected framework snapshot to a private home-directory run, and generates a fresh session inference key. It does not submit a job or download weights.

```bash
python3 inference.py info
python3 inference.py cpu-check
bash submit_server.sh --dry-run
bash submit_server.sh
```

CPU-check imports the actual registered runtime without allocating GPUs. Submission requests two nodes and eight GPUs for either current profile, for up to two hours. A permitted reservation can be supplied as `--reservation NAME`. The common profiles preserve the legacy engine flags. The shared lifecycle and per-user launcher need a fresh GPU inference validation; historical model results do not validate this new launcher or another team account.

```bash
cat .runtime/job_id
tail -f *-common-*.out
```

Wait for `INFERENCE_READY`. The job runs authentication, model catalog, arithmetic, English response, SSE streaming, forced function-call output and four concurrent requests before publishing the endpoint. Function calls are inspected, never executed. This basic suite does not establish load capacity or long-term stability.

```bash
cat .runtime/endpoint.json
readlink -f .runtime/api_key
squeue -j "$(cat .runtime/job_id)"
```

`.runtime` is inside your private `RUN_DIR`; it is not in the shared release. The key file is private, mode 600. Share the current endpoint and the session inference key with approved teammates using an agreed private channel. Never copy keys, home-directory runs or caches into the shared release, reviewed results or Git. A key is valid for its running server session; a new prepared run gets a different key.

Stop your server explicitly when finished:

```bash
scancel "$(cat .runtime/job_id)"
```

The endpoint is removed when the job stops. It also stops if the launcher dies or health checks fail three times. Slurm sends a termination signal about 90 seconds before allocation expiry. Clients still need timeouts/retries; this is a personal SSH test workflow, not unattended production authentication.

## Connect from your computer

Download this complete code release, including `profiles/`, to a private local directory. No weights or container are needed by the client. Ask the server owner for the current `endpoint.json` and session inference key. Save the endpoint locally; enter the key through the hidden prompt:

```bash
python3 client.py key --profile profiles/glm53.json
python3 client.py tunnel --profile profiles/glm53.json --endpoint endpoint.json --user YOUR_LEONARDO_LOGIN
```

Keep the tunnel terminal open. In a second terminal in the same directory:

```bash
python3 client.py test --profile profiles/glm53.json
python3 client.py chat --profile profiles/glm53.json
```

For DeepSeek, use `profiles/deepseek41.json` in all four commands. Each person uses their own Leonardo login. The default local ports are GLM `18083` and DeepSeek `18084`; `--local-port` overrides them. The SSH helper uses the dedicated `login01-ext.leonardo.cineca.it` node. It binds the forwarded API to localhost only. Confirm any persistent or alternative tunnel route with CINECA; this release does not grant permission for proxy tunnels.

| Profile | Served model | Parallelism | Model-specific settings |
| --- | --- | --- | --- |
| `glm53` | `glm-5.3-flash-leonardo` | TP4 / PP2 | Sparse MLA, eager checkpoint loading, GLM parsers |
| `deepseek41` | `deepseek-v4.1-flash-1017-leonardo` | TP8 / PP1 + EP | Engram CPU offload, lazy loading, FP8 MLA KV cache, DeepSeek parsers |

Both profiles limit context to 2048 tokens. Four API requests in the test do not imply four simultaneous GPU execution slots; DeepSeek has `max-num-seqs=2`.

## Add another model

1. Register its checkpoint path in the operator-managed `inference-site.json`.
2. Copy a JSON file in `profiles/` to a new profile ID. Set model ID/revision, checkpoint key, served alias, runtime ID, resource requests, TP/PP, engine flags and client template settings.
3. Select an existing compatible runtime, or register a different runtime under a new versioned ID. Never replace a runtime used by a published profile.
4. Run schema/asset checks and compare the launch plan before submitting a GPU job. Validate the new model with English inference, streaming, tool output where supported and concurrency; add a capability-specific suite if it cannot support the default seven checks.
5. Publish a new dated framework snapshot with fresh file hashes and update `scripts/inference` only after recording its validation status. Keep old releases intact.

No launcher or client fork is required for an ordinary vLLM model. Models requiring additional preprocessing need an explicitly reviewed hook implementation; JSON cannot execute arbitrary hook scripts. GLM and DeepSeek hooks do not establish compatibility for another model, quantization or GPU type.

## Installation layout

```text
scripts/inference -> ../releases/inference/<release>
releases/inference/<release>/        common code + profiles + this guide
runtimes/<runtime>/<version>/        image.sif, python-overlay/, runtime.json
inference-site.json                 project, queues, runtime and checkpoint paths
users/<login>/<profile>--<runtime>/   private writable caches and temporary files
runs/<date>/job-<id>/                reviewed nonsecret results only
```

Checkpoint paths can refer to existing installations. Runtime registration reuses a SIF by hardlink when possible and copies the small overlay to an independent directory. The runtime manifest records hashes. A hardlinked SIF shares its inode with its legacy source: never modify either path in place; install a new version instead. Legacy script aliases remain available and retain their historical validation status. New caches are separated by both model profile and runtime ID. Legacy caches remain in place; a cold start can take longer while kernels compile.
