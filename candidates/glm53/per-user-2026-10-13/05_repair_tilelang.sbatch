#!/bin/bash
#SBATCH --job-name=leonardo-glm53-tilelang
#SBATCH --account=YOUR_PROJECT
#SBATCH --partition=lrd_all_serial
#SBATCH --cpus-per-task=2
#SBATCH --mem=8000M
#SBATCH --time=00:15:00
#SBATCH --output=%x-%j.out
set -euo pipefail
BASE="${WORK:?}/team_vllm/glm53"
SIF="$BASE/images/vllm-backport-v0.13.1-sm80.sif"
WHEEL="$BASE/wheels/tilelang-0.1.12-cp38-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"
printf '%s  %s\n' bbeb5573cbe2544a51a5c9a6cc737c5e3b5c2d95411caa3687fd9b08eb9d5f97 "$WHEEL" | sha256sum -c -
export SINGULARITYENV_PYTHONPATH="$BASE/python-overlay"
export SINGULARITYENV_TILELANG_CACHE_DIR="$BASE/cache/tilelang"
export SINGULARITYENV_XDG_CACHE_HOME="$BASE/cache/xdg"
export SINGULARITYENV_PIP_DISABLE_PIP_VERSION_CHECK=1
export SINGULARITYENV_TMPDIR="$BASE/tmp/pip"
mkdir -p "$BASE/python-overlay" "$BASE/cache/tilelang" "$BASE/tmp/pip"
singularity exec --cleanenv --no-home --contain --bind "$BASE" "$SIF" \
    python3 -m pip install --no-index --no-deps --no-compile --upgrade --target "$BASE/python-overlay" "$WHEEL"
singularity exec --cleanenv --no-home --contain --bind "$BASE" "$SIF" python3 -u - <<'PY'
import importlib.metadata,json,tilelang,tilelang.webgpu
from pathlib import Path
result={"version":importlib.metadata.version("tilelang"),"import_path":str(Path(tilelang.__file__)),"webgpu_module":str(Path(tilelang.webgpu.__file__)),"tvm_ffi_version":importlib.metadata.version("apache-tvm-ffi")}
assert result["version"]=="0.1.12"
print("TILELANG_IMPORT_OK",json.dumps(result),flush=True)
PY
