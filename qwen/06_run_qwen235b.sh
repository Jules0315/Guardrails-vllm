#!/bin/bash
# Submit a short two-node loading/inference test after the download completes.
set -euo pipefail
cd "$(dirname "$0")"
export TEAM="${TEAM:-team_vllm}"
export MODEL_ID=Qwen/Qwen3-235B-A22B-FP8
export MODEL_REVISION=39eb2b067ea6b8e3e1dd97d3cd0c7ffeaf3e1a35
export SIF="${SIF:-${WORK:?}/team_vllm/images/vllm-0.31.0.sif}"
export MODEL_DIR="${BASE:-$WORK/$TEAM}/models/${MODEL_ID//\//__}"
export MAX_MODEL_LEN=2048 GPU_MEM_UTIL=0.90
export ENDPOINT_NAME="${ENDPOINT_NAME:-leonardo-qwen235b-20261008}"
# Read each shard sequentially into host RAM; mmap random reads are slow on Lustre.
export VLLM_EXTRA_ARGS="--dtype bfloat16 --quantization fp8 --enforce-eager --max-num-seqs 4 --safetensors-load-strategy eager"
model_dir="$MODEL_DIR"
python3 - "$model_dir/download_manifest.json" "$MODEL_REVISION" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
manifest = json.loads(path.read_text())
assert manifest["repo"] == "Qwen/Qwen3-235B-A22B-FP8"
assert manifest["revision"] == sys.argv[2]
for name, size in manifest["verified_files"].items():
    assert (path.parent / name).stat().st_size == size, name
print("Checkpoint files verified; submitting two-node inference test.")
PY
exec sbatch --job-name=qwen235b-multi --time=00:30:00 04_vllm_multinode.sbatch
