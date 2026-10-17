#!/bin/bash
#SBATCH --job-name=leonardo-glm53-preflight
#SBATCH --account=YOUR_PROJECT
#SBATCH --partition=boost_usr_prod
#SBATCH --qos=boost_qos_dbg
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH --time=00:10:00
#SBATCH --output=%x-%j.out
set -euo pipefail

TEST_DIR="${SLURM_SUBMIT_DIR:?}"
SIF="${GLM_SIF:-${WORK:?}/team_vllm/images/vllm-0.31.0.sif}"
mkdir -p "$TEST_DIR/cache" "$TEST_DIR/evidence"
export SINGULARITYENV_VLLM_ENABLE_CUDA_COMPATIBILITY=1
export SINGULARITYENV_VLLM_NO_USAGE_STATS=1
export SINGULARITYENV_HF_HUB_OFFLINE=1
export SINGULARITYENV_TRANSFORMERS_OFFLINE=1
export SINGULARITYENV_HF_HOME="$TEST_DIR/cache/hf"
export SINGULARITYENV_VLLM_CACHE_ROOT="$TEST_DIR/cache/vllm"
export SINGULARITYENV_TRITON_CACHE_DIR="$TEST_DIR/cache/triton"
export SINGULARITYENV_XDG_CACHE_HOME="$TEST_DIR/cache/xdg"
if [[ "${GLM_CHECK_MHC:-0}" == 1 ]]; then
    BASE="${WORK:?}/team_vllm/glm53"
    mkdir -p "$BASE/cache/tilelang" "$BASE/cache/flashinfer-root" "$BASE/tmp/runtime"
    export SINGULARITYENV_PYTHONPATH="$BASE/python-overlay"
    export SINGULARITYENV_TILELANG_CACHE_DIR="$BASE/cache/tilelang"
    export SINGULARITYENV_FLASHINFER_WORKSPACE_BASE="$BASE/cache/flashinfer-root"
    export SINGULARITYENV_TMPDIR="$BASE/tmp/runtime"
    export SINGULARITYENV_GLM_CHECK_MHC=1
fi
export SINGULARITYENV_GLM_METADATA_DIR="$TEST_DIR/metadata"
export SINGULARITYENV_GLM_PREFLIGHT_OUTPUT="$TEST_DIR/evidence/preflight-${SLURM_JOB_ID}.json"
export SINGULARITYENV_SLURM_JOB_ID="$SLURM_JOB_ID"
if [[ -n "${CUDA_VISIBLE_DEVICES:-}" ]]; then
    export SINGULARITYENV_CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES"
fi
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
# Re-exec after vLLM installs forward-compatibility library paths.
binds=(--bind "$TEST_DIR")
if [[ "${GLM_CHECK_MHC:-0}" == 1 ]]; then binds+=(--bind "$BASE"); fi
singularity exec --nv --cleanenv --no-home --contain "${binds[@]}" "$SIF" \
    python3 -c 'import os,sys,vllm; os.execv(sys.executable,[sys.executable,*sys.argv[1:]])' \
    "$TEST_DIR/preflight.py"
