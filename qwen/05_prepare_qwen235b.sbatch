#!/bin/bash
# Download the official FP8 checkpoint on internet-enabled serial nodes.
# No GPU allocation; reuse the tested SIF. Checkpoint revision is pinned.
#SBATCH --job-name=qwen235b-prepare
#SBATCH --account=YOUR_PROJECT
#SBATCH --partition=lrd_all_serial
#SBATCH --cpus-per-task=4
#SBATCH --mem=30000M
#SBATCH --time=03:30:00
#SBATCH --output=%x-%j.out
set -euo pipefail
export TEAM="${TEAM:-team_vllm}"
export MODEL_ID=Qwen/Qwen3-235B-A22B-FP8
export MODEL_REVISION=39eb2b067ea6b8e3e1dd97d3cd0c7ffeaf3e1a35
export SIF="${SIF:-${WORK:?}/team_vllm/images/vllm-0.31.0.sif}"
export MODEL_DIR="${BASE:-$WORK/$TEAM}/models/${MODEL_ID//\//__}"
source "${SLURM_SUBMIT_DIR:-.}/common.sh"
container_env_common
cenv HF_HUB_OFFLINE 0
cenv TRANSFORMERS_OFFLINE 0
cenv MODEL_ID "$MODEL_ID"
cenv MODEL_REVISION "$MODEL_REVISION"
cenv MODEL_DIR "$MODEL_DIR"
cenv HF_HUB_DOWNLOAD_TIMEOUT 120
for v in HF_TOKEN HTTPS_PROXY HTTP_PROXY https_proxy http_proxy NO_PROXY no_proxy; do
  if [[ -n "${!v:-}" ]]; then cenv "$v" "${!v}"; fi
done
echo "Downloading $MODEL_ID revision $MODEL_REVISION to $MODEL_DIR"
"$CTR" exec --cleanenv --bind "$BASE" "$SIF" python3 -u - <<'PY'
import json
import os
from pathlib import Path
from huggingface_hub import HfApi, snapshot_download

repo = os.environ["MODEL_ID"]
revision = os.environ["MODEL_REVISION"]
directory = Path(os.environ["MODEL_DIR"])
patterns = ["*.json", "*.safetensors", "*.txt", "*.model", "*.tiktoken", "*.jinja"]
metadata = HfApi().model_info(repo, revision=revision, files_metadata=True)
assert metadata.sha == revision
print("Pinned checkpoint:", metadata.id, metadata.sha, flush=True)
snapshot_download(repo, revision=revision, local_dir=directory,
                  allow_patterns=patterns, max_workers=4)
index = json.loads((directory / "model.safetensors.index.json").read_text())
required = set(index["weight_map"].values()) | {"config.json", "tokenizer.json", "tokenizer_config.json"}
remote = {f.rfilename: f for f in metadata.siblings}
for name in sorted(required):
    path = directory / name
    expected = remote[name].size
    if not path.is_file() or path.stat().st_size != expected:
        raise RuntimeError(f"Missing or incomplete file: {name}")
manifest = {"repo": repo, "revision": revision,
            "verified_files": {name: remote[name].size for name in sorted(required)},
            "validation": "HF download integrity plus required file sizes"}
(directory / "download_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("CHECKPOINT_READY", directory, "shards", len(set(index["weight_map"].values())), flush=True)
PY
du -sh "$MODEL_DIR"
