> Public adaptation: configure your project and installation paths first. See [installation](glm53-installation.md). Historical results do not establish that this adapted copy has been GPU validated.

# Quick guide: start a GLM server and connect to its API

For the new model-independent workflow, see the [common GLM/DeepSeek server and client guide](../releases/inference/2026-10-19-docs1/QUICK_GUIDE.md). It uses `scripts/inference` and versioned runtime assets. Both models passed fresh two-node GPU and English API validation with one operator account; see [results](common-gpu-validation.md). The legacy procedure below remains available.

**Public adaptation:** 17 October 2026 · Original team procedure: 14 October 2026 (Europe/Berlin)

Two roles: the **server operator** submits the GPU job using their own Leonardo account; **API clients** connect using their own Leonardo accounts and the operator's session API key.

**Status:** `scripts/glm53` is validated for `the original operator account` with the retained shared cache; `the original operator account` follows the Operator section of the full guide (see the end of this page). Other team members should use `scripts/glm53-next`, the per-user candidate. It has not yet passed inference validation under another team member's account. Treat the first run as a coordinated validation attempt.

**Access:** obtain a personal Leonardo account, an approved Slurm project allocation and access to the installation from your administrator.

Coordinate before submitting: **one GLM server per team at a time**, using two nodes and eight A100 GPUs. Check current project budget, storage quota and queue availability with the operator/mentors. The session from 13 October has ended; obtain a fresh endpoint and key. All test prompts must be in English.

**Shell:** the commands below use Bash (macOS, Linux, or Windows WSL). Server commands run on Leonardo. The helper scripts replace long commands and embedded Python; do not paste visually wrapped commands from an older PDF.

**Helpers:** `$WORK/team_vllm/scripts/glm53-tools` points to a separate, read-only helper release. These helpers prepare files and shorten commands; they do not change the model launcher or validate the per-user inference candidate.

## A. Server operator — on Leonardo

### 1. Log in and prepare a private run directory

From your computer, replace `YOUR_LOGIN` with your own account:

```bash
ssh YOUR_LOGIN@login01-ext.leonardo.cineca.it
```

Then, on Leonardo:

```bash
BASE="$WORK/team_vllm"
TOOLS="$BASE/scripts/glm53-tools"
RUN_DIR=$(bash "$TOOLS/prepare_run.sh") && cd "$RUN_DIR"
printf 'Private run directory: %s\n' "$RUN_DIR"
```

If preparation fails, stop and contact the operator. The helper checks source hashes, pins the selected candidate and tools, copies them into a new private directory, and records their paths in `RUN_SETUP.json`. It does not generate a key or submit a job. Keep the printed directory path. Submit from this private directory, never from the shared snapshot. Model weights, SIF and Python overlay are reused; no download or build is required. The candidate writes caches to `$BASE/users/$USER/glm53/`.

### 2. Check cache access and seed it before your first run

Historical cache status: an operator cache-preparation job completed on 13 October 2026 in the original installation. Still run the following from your own account, because only your account can confirm your access. If the access check fails, contact the operator; do not proceed with the server submission.

```bash
python3 check_cache_access.py && sbatch --wait 06_seed_user_cache.sbatch
```

Confirm that the cache job completed successfully and its `glm53-cache-seed-<jobid>.out` log contains `CACHE_SEED_DONE`. If it fails, resolve the error before continuing. Seeding copies cached kernels; it does not validate inference. Startup with an empty per-user cache remains unvalidated and may exceed the 25-minute initialization timeout.

### 3. Generate your session API key

In the same private run directory:

```bash
python3 create_api_key.py .runtime/api_key
readlink -f .runtime/api_key
```

The last command prints the absolute **file path**, not the key. Key creation must succeed before submission; it refuses to overwrite an existing file. This is an inference API key, separate from your Leonardo password. Keep it private.

### 4. Submit once and wait for readiness

Only after the previous team server has stopped and the checks above succeed:

```bash
bash submit_server.sh &&
  job_id=$(cat .runtime/job_id) &&
  tail -F "${USER}-glm53-${job_id}.out"
```

If submission fails, the chain stops; inspect the error before trying again. `tail -F` keeps waiting while the job is still queued and its log file does not exist yet. The helper submits one two-hour job using `boost_qos_lprod`, then saves its job ID in `.runtime/job_id`. It refuses another submission from the same run directory.

This uses the general queue. For an approved reservation covering the full requested runtime, use `bash submit_server.sh NAME` **instead of** the command above. For a shorter runtime, for example, use `GLM_WALLTIME=00:45:00 bash submit_server.sh`. Do not reuse the dated 13 October reservation without checking.

Wait for **`INFERENCE_READY`**. Previously validated startups took about 9–13 minutes; candidate startup time is unknown. Initialization times out after 25 minutes. `Ctrl+C` stops log following, not the job.

```bash
job_id=$(cat .runtime/job_id)
cat .runtime/endpoint.json
squeue -j "$job_id" -o "%.10i %.8T %e"
```

Verify the endpoint's `job_id` matches your active job. Share its **host, port, model, job ID and expected end time (with timezone)**; the last column of the `squeue` output is the end time in Leonardo's local time (CET/CEST). Read `.runtime/api_key` privately and send its contents through an agreed private channel. Do not publish the key file or Leonardo credentials. Service shuts down approximately 90 seconds before allocation expiry.

## B. API clients — on your own computer

You do not need to submit a job or install the model. Obtain the ready session details and key from its operator. Use Python 3 and SSH.

### 1. Download the client helpers and open the tunnel in terminal 1

Replace `YOUR_LOGIN` with your own account. All downloaded files are public scripts; no HPC credentials are copied.

```bash
umask 077
LOGIN='YOUR_LOGIN'
HOST='login01-ext.leonardo.cineca.it'
WORK_ROOT='/leonardo_work/YOUR_PROJECT'
BASE="$WORK_ROOT/team_vllm"
TOOLS="$BASE/scripts/glm53-tools"
CLIENT_DIR=$(mktemp -d "$HOME/glm53-client-XXXXXX")
cd "$CLIENT_DIR"
for file in open_tunnel.py create_api_key.py test_api.sh; do
    scp "$LOGIN@$HOST:$TOOLS/$file" .
done
TEST="$BASE/scripts/glm53-next/test_endpoint.py"
scp "$LOGIN@$HOST:$TEST" .
printf 'Client directory: %s\n' "$PWD"
python3 open_tunnel.py
```

If a download fails, resolve it before continuing. The tunnel helper prompts for your Leonardo login and the **host and API port from the new endpoint.json**. Authenticate with your own account and keep this terminal open. Successful forwarding usually produces no SSH output. Use the printed client-directory path in terminal 2.

Connectivity from each team member's account still needs verification. If forwarding is restricted, ask the mentors/CINECA for an approved route.

### 2. Save the key and run the API checks in terminal 2

Replace the directory placeholder with the path printed in terminal 1:

```bash
cd /your/private/client/directory
python3 create_api_key.py api_key.txt --prompt
bash test_api.sh
```

Enter the operator's current **inference API key** at the hidden prompt. The helper saves it with mode `600` and prints only the file path. If key creation fails, resolve the error before running the tests. `test_api.sh` runs the English suite and saves results to a unique `team_test_results-*.json` file.

Expected: seven `PASS` results covering authentication, the model catalog, arithmetic, an English response, SSE streaming, function-call output and four concurrent requests. Function-call output is checked; no function is executed. Coordinate test suites so their four-request batches do not overlap unnecessarily.

### 3. Connect your application

| Setting | Value |
| --- | --- |
| OpenAI-compatible API base URL | `http://127.0.0.1:18083/v1` |
| Model | `glm-5.3-flash-leonardo` |
| API key | Contents of your private `api_key.txt` |
| Initial generation settings | Temperature `0`, `max_tokens=1024` |
| Extra request fields, if supported | `chat_template_kwargs: {"reasoning_effort":"low","clear_thinking":true}` |

Function calls arrive in `tool_calls`, but `finish_reason` is `stop` rather than `tool_calls`; adapters must check `tool_calls` directly.

Text only; context limit **2,048 tokens including input and output**, with up to four active requests. The test script takes the base URL **without `/v1`**; application clients use **`/v1`**. This localhost URL is for an application on the computer running the tunnel. Docker/Kubernetes/GKE requires a separately configured and validated gateway.

## C. Finish and troubleshoot

- **Client:** close terminal 1 with `Ctrl+C`; remove your local `api_key.txt` when finished. Share reviewed test JSON with the operator, including job ID and test time.
- **Operator:** from your private run directory, run `scancel "$(cat .runtime/job_id)"`, then `squeue -j "$(cat .runtime/job_id)"`. This works from a new login, where `$job_id` is no longer set. After confirming the job has ended, remove `.runtime/api_key`. Retain private logs and publish only reviewed, credential-free results under `$BASE/runs/<date>/job-<jobid>/`.
- **HTTP 401 with the supplied key:** confirm it belongs to the current session. A 401 in the unauthenticated test is expected.
- **`Host key verification failed`:** use the dedicated hostname `login01-ext.leonardo.cineca.it`. Verify the expected fingerprint with CINECA before replacing a stored host key.
- **Connection refused / timeout:** check `INFERENCE_READY`, active job state, current host/port and account reachability. If local port 18083 is occupied, set the same `GLM_LOCAL_PORT` value for both `open_tunnel.py` and `test_api.sh`, and update the application URL.

For the full procedure, on Leonardo run:

```bash
BASE="$WORK/team_vllm"
less "$BASE/docs/glm53-installation.md"
```
