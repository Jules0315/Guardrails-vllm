#!/bin/bash
set -euo pipefail
TEST_DIR="${GLM_TEST_DIR:?}"
BASE="${WORK:?}/team_vllm/glm53"
SIF="$BASE/images/vllm-backport-v0.13.1-sm80.sif"
MODEL_DIR="$BASE/models/zai-org__GLM-5.3-Flash"
export SINGULARITYENV_VLLM_ENABLE_CUDA_COMPATIBILITY=1
export SINGULARITYENV_VLLM_API_KEY="$(cat "$TEST_DIR/.runtime/api_key")"
export SINGULARITYENV_VLLM_HOST_IP="$(getent hosts "$(hostname -s)" | awk '{print $1; exit}')"
export SINGULARITYENV_VLLM_NO_USAGE_STATS=1
export SINGULARITYENV_HF_HUB_OFFLINE=1
export SINGULARITYENV_TRANSFORMERS_OFFLINE=1
export SINGULARITYENV_HF_HOME="$BASE/cache/hf"
export SINGULARITYENV_VLLM_CACHE_ROOT="$BASE/cache/vllm"
export SINGULARITYENV_TRITON_CACHE_DIR="$BASE/cache/triton"
export SINGULARITYENV_TORCHINDUCTOR_CACHE_DIR="$BASE/cache/inductor"
export SINGULARITYENV_XDG_CACHE_HOME="$BASE/cache/xdg"
export SINGULARITYENV_FLASHINFER_WORKSPACE_BASE="$BASE/cache/flashinfer-root"
export SINGULARITYENV_TILELANG_CACHE_DIR="$BASE/cache/tilelang"
export SINGULARITYENV_PYTHONPATH="$BASE/python-overlay"
export SINGULARITYENV_TMPDIR=/tmp/glm-tmp
mkdir -p "$BASE/cache/flashinfer-root" "$BASE/cache/tilelang" "$BASE/tmp/runtime"
export SINGULARITYENV_CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:?}"
export SINGULARITYENV_NCCL_ALGO=Ring
export SINGULARITYENV_NCCL_PROTO=Simple
export SINGULARITYENV_NCCL_DEBUG=INFO
export SINGULARITYENV_NCCL_DEBUG_SUBSYS=INIT,NET

args=(vllm serve "$MODEL_DIR" --served-model-name glm-5.3-flash-leonardo
      --tensor-parallel-size 4 --pipeline-parallel-size 2 --nnodes 2
      --node-rank "${SLURM_NODEID:?}" --master-addr "${GLM_MASTER_ADDR:?}"
      --master-port "${GLM_MASTER_PORT:?}" --dtype bfloat16
      --gpu-memory-utilization 0.90 --max-model-len 2048 --max-num-seqs 4
      --max-num-batched-tokens 2048 --enforce-eager --disable-custom-all-reduce
      --limit-mm-per-prompt '{"image":0,"video":0}'
      --safetensors-load-strategy eager --attention-backend TRITON_MLA_SPARSE
      --reasoning-parser glm45 --tool-call-parser glm47 --enable-auto-tool-choice)
if [[ "$SLURM_NODEID" == 0 ]]; then
    args+=(--host 0.0.0.0 --port "${GLM_API_PORT:?}")
else
    args+=(--headless)
fi
exec singularity exec --nv --cleanenv --no-home --contain \
    --bind "$BASE" --bind "$TEST_DIR" --bind /dev/infiniband \
    --bind "$BASE/tmp/runtime:/tmp/glm-tmp" \
    "$SIF" "${args[@]}"
