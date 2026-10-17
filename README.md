# Guardrails vLLM — Leonardo HPC deployment

Containerized LLM deployment and validation scripts for the Leonardo supercomputer: **Slurm, Apptainer/Singularity, NVIDIA A100, tensor/pipeline parallelism and authenticated inference APIs**.

This repository documents independent HPC deployment work supporting the Guardrails Lake Constance team at the European AI Hackathon 2026. It is separate from the team's [application repository](https://github.com/CodifyAG/european-ai-hackathon-2026).

## Demonstrated in the original installation

| Model | Original deployment | Validation scope |
| --- | --- | --- |
| Qwen3-235B-A22B-FP8 | Two nodes, eight A100 64GB GPUs; TP=4, PP=2 | Internal/external inference, authentication and four concurrent requests |
| GLM-5.3-Flash | Two nodes, eight A100 64GB GPUs; TP=4, PP=2 | Seven API checks, including authenticated requests, English responses, SSE streaming, function-call JSON and four concurrent requests |

The work included A100 compatibility investigation, a community vLLM backport, same-version TileLang package repair, CUDA compatibility configuration, Lustre checkpoint-loading adjustments, private API keys and repeatable Slurm workflows.

**Public-copy status:** personal team paths, project allocation identifiers and job-name prefixes have been generalized. These adapted files pass local packaging checks; they have **not** been rerun on Leonardo GPUs. Historical results apply to the original operator configuration. The per-user candidate remains inference-unvalidated under other team accounts. See [validation](docs/validation.md) and [publication notes](docs/publication.md).

## Layout

```text
qwen/                              staged Qwen deployment and NCCL checks
releases/glm53/operator-2026-10-13/  historical operator profile, adapted paths
candidates/glm53/per-user-2026-10-13/ per-user cache candidate
releases/glm53-tools/2026-10-14-r2/  preparation, submission and client helpers
scripts/glm53                      operator-profile symlink
scripts/glm53-next                 per-user-candidate symlink
scripts/glm53-tools                helper-release symlink
docs/                             installation, quick guide and validation
tools/                            public-package checks and metadata fetcher
```

The model weights, SIF images, Python overlay, kernel caches and runtime secrets are not included. Git stores scripts and documentation only.

## Install the scripts

Use a personal Leonardo account and an approved project allocation. On Leonardo:

```bash
export SBATCH_ACCOUNT=YOUR_PROJECT
export TEAM=team_vllm
cd "$WORK"
git clone https://github.com/Jules0315/Guardrails-vllm.git team_vllm
cd team_vllm
python3 tools/check_repository.py
```

Replace `YOUR_PROJECT` with your allocation. The job scripts retain `YOUR_PROJECT` as a deliberate placeholder; `SBATCH_ACCOUNT` supplies the actual account. Verify the site's current partitions, QoS, quotas, budget and reservation access before submitting anything. Cloning and checking the repository do not submit a job or download weights.

- [GLM installation and compatibility procedure](docs/glm53-installation.md)
- [Team server and API quick guide](docs/quick-guide.md)
- [Qwen staged deployment procedure](qwen/README.md)
- [Historical configuration and limitations](docs/validation.md)

The quick-guide preparation command is:

```bash
BASE="$WORK/team_vllm"
TOOLS="$BASE/scripts/glm53-tools"
RUN_DIR=$(bash "$TOOLS/prepare_run.sh") && cd "$RUN_DIR"
```

This requires a prepared model/container installation. It only copies pinned scripts into a new private home-directory run folder; key creation and Slurm submission are separate explicit steps. Coordinate one team server at a time under the original operating procedure.

## Local checks

No cluster connection or GPU allocation is needed:

```bash
python3 tools/check_repository.py
python3 -m unittest discover -s qwen/tests -v
```

The regression suite uses simulated HTTP, Slurm/container commands and SSH. Actual GPU kernel and model tests must run inside the matching container on allocated compute nodes.

## Runtime separation

- Shared weights, SIFs and overlays are installation assets.
- Model jobs run under Slurm; no Kubernetes cluster is provisioned by this repository.
- API keys and `.runtime` stay in private run directories with restricted permissions.
- External clients use their own Leonardo accounts, SSH local forwarding and a separate session inference key.
- Persistent external service operation, production capacity and unattended authentication are outside the validated scope.

## Upstream dependencies

- [vLLM](https://github.com/vllm-project/vllm)
- [Community SM80 backport](https://github.com/wtdcode/vllm-backport)
- [TileLang](https://github.com/tile-ai/tilelang)
- [Qwen3-235B-A22B-FP8](https://huggingface.co/Qwen/Qwen3-235B-A22B-FP8)
- [GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash)

Upstream code, model weights and containers are obtained separately under their respective licenses. This repository does not claim authorship of the vLLM backport or the model kernels.
