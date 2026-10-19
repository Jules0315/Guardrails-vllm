# Guardrails vLLM — Leonardo HPC deployment

Containerized LLM deployment and validation scripts for the Leonardo supercomputer: **Slurm, Apptainer/Singularity, NVIDIA A100, tensor/pipeline parallelism and authenticated inference APIs**.

This repository documents independent HPC deployment work supporting the Guardrails Lake Constance team at the European AI Hackathon 2026. It is separate from the team's [application repository](https://github.com/CodifyAG/european-ai-hackathon-2026).

## Demonstrated in the original installation

| Model | Original deployment | Validation scope |
| --- | --- | --- |
| Qwen3-235B-A22B-FP8 | Two nodes, eight A100 64GB GPUs; TP=4, PP=2 | Fresh common-launcher validation: seven English API checks and two SSH repeat suites |
| GLM-5.3-Flash | Two nodes, eight A100 64GB GPUs; TP=4, PP=2 | Seven API checks, including authenticated requests, English responses, SSE streaming, function-call JSON and four concurrent requests |
| DeepSeek-V4.1-Flash-1017 | Two nodes, eight A100 64GB GPUs; TP=8 with expert parallelism and Engram CPU offload | Original r2 operator deployment passed startup and repeated English API suites; the common launcher passed seven English API checks and two SSH repeat suites |

The work included A100 compatibility investigation, a community vLLM backport, same-version TileLang package repair, CUDA compatibility configuration, Lustre checkpoint-loading adjustments, private API keys and repeatable Slurm workflows.

**Validation status:** the common framework passed two-node GPU inference and English API validation for GLM/DeepSeek on 18 October and Qwen on 19 October on Leonardo with one operator account. The current documentation snapshot preserves the Qwen-tested execution bytes and engine settings. The new port-only correction was GPU-validated with Qwen; GLM/DeepSeek were not rerun after that correction. Historical Qwen/GLM public adaptations retain their earlier validation scope; other team accounts remain inference-unvalidated. See the [common GPU validation record](docs/common-gpu-validation.md) and [historical validation](docs/validation.md).

## Layout

```text
releases/inference/2026-10-18/       GPU-tested execution snapshot
releases/inference/2026-10-18-docs1/ earlier GLM/DeepSeek validation metadata
releases/inference/2026-10-19-r2/    Qwen-tested source and port correction
releases/inference/2026-10-19-docs1/ current three-model guide and Qwen evidence
scripts/inference                  common-framework release symlink
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

The [common framework](docs/common-framework.md) serves GLM, DeepSeek and Qwen and separates model configuration from execution code and versioned SIF/overlay assets. All three profiles share one registered runtime. Start with the [QUICK_GUIDE.md](releases/inference/2026-10-19-docs1/QUICK_GUIDE.md) for server and client commands. Legacy paths remain available. Fresh GPU results are recorded in [common GPU validation](docs/common-gpu-validation.md).

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
- [GLM and DeepSeek QUICK_GUIDE.md](releases/inference/2026-10-19-docs1/QUICK_GUIDE.md)
- [Qwen common validation and port correction](docs/qwen-common-validation.md)
- [Legacy GLM team guide](docs/quick-guide.md)
- [Qwen staged deployment procedure](qwen/README.md)
- [Historical configuration and limitations](docs/validation.md)

The quick-guide preparation command is:

```bash
BASE="$WORK/team_vllm"
FRAMEWORK="$BASE/scripts/inference"
RUN_DIR=$(bash "$FRAMEWORK/prepare_run.sh" qwen235b --base "$BASE") && cd "$RUN_DIR"
```

This requires prepared runtime/checkpoint assets and `$BASE/inference-site.json`; see the [installation layout](docs/common-framework.md). Preparation copies pinned scripts into a private home-directory run and creates a fresh private API key. Slurm submission is a separate explicit step. Choose `glm53` or `deepseek41` instead of `qwen235b` for the other models. Coordinate one team server at a time.

## Local checks

No cluster connection or GPU allocation is needed:

```bash
python3 tools/check_repository.py
python3 -m unittest discover -s tests -v
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
- [DeepSeek-V4.1-Flash-1017](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017)

Upstream code, model weights and containers are obtained separately under their respective licenses. This repository does not claim authorship of the vLLM backport or the model kernels.

The shared quick guide covers GLM, DeepSeek and Qwen. New model profiles select a registered runtime without copying the launcher, API client or container.
