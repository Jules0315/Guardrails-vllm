#!/bin/bash
#SBATCH --job-name=leonardo-glm53-backport-image
#SBATCH --account=YOUR_PROJECT
#SBATCH --partition=lrd_all_serial
#SBATCH --cpus-per-task=4
#SBATCH --mem=30000M
#SBATCH --time=01:30:00
#SBATCH --output=%x-%j.out
set -euo pipefail
BASE="${WORK:?}/team_vllm/glm53"
mkdir -p "$BASE/images" "$BASE/tmp" "$BASE/oci-cache"
export SINGULARITY_TMPDIR="$BASE/tmp"
export SINGULARITY_CACHEDIR="$BASE/oci-cache"
IMAGE='docker://lazymio/vllm-backport@sha256:0fc33cd7d2be777bf6faaee9b02adf781dc6d0bc44b9a09ce4865089f67e9cba'
SIF="$BASE/images/vllm-backport-v0.13.1-sm80.sif"
if [[ -s "$SIF" ]]; then
    singularity inspect "$SIF" >/dev/null
else
    singularity pull "$SIF" "$IMAGE"
fi
sha256sum "$SIF"
singularity inspect --json "$SIF" > "$BASE/images/vllm-backport-v0.13.1-sm80.labels.json"
echo IMAGE_READY
