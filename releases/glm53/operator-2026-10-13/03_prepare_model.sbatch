#!/bin/bash
#SBATCH --job-name=leonardo-glm53-checkpoint
#SBATCH --account=YOUR_PROJECT
#SBATCH --partition=lrd_all_serial
#SBATCH --cpus-per-task=4
#SBATCH --mem=30000M
#SBATCH --time=03:30:00
#SBATCH --output=%x-%j.out
set -euo pipefail
BASE="${WORK:?}/team_vllm/glm53"
SIF="${WORK}/team_vllm/images/vllm-0.31.0.sif"
mkdir -p "$BASE/models" "$BASE/cache/hf"
export SINGULARITYENV_GLM_BASE="$BASE"
export SINGULARITYENV_HF_HOME="$BASE/cache/hf"
export SINGULARITYENV_HF_HUB_DOWNLOAD_TIMEOUT=120
export SINGULARITYENV_HF_HUB_OFFLINE=0
export SINGULARITYENV_TRANSFORMERS_OFFLINE=0
export SINGULARITYENV_HF_HUB_DISABLE_TELEMETRY=1
singularity exec --cleanenv --no-home --contain --bind "$BASE" "$SIF" python3 -u - <<'PY'
import json, os, shutil
from pathlib import Path
from huggingface_hub import HfApi, snapshot_download

repo = "zai-org/GLM-5.3-Flash"
revision = "91b69215804f2d2036a8867f6ce44848e278dcda"
base = Path(os.environ["GLM_BASE"])
directory = base / "models/zai-org__GLM-5.3-Flash"
metadata = HfApi().model_info(repo, revision=revision, files_metadata=True)
assert metadata.sha == revision
weights = {f.rfilename: f for f in metadata.siblings if f.rfilename.endswith(".safetensors")}
needed = sum(f.size for f in weights.values())
existing = sum((directory / name).stat().st_size for name, f in weights.items() if (directory / name).is_file() and (directory / name).stat().st_size == f.size)
free = shutil.disk_usage(base).free
if free < needed - existing + 100 * 2**30:
    raise RuntimeError("Insufficient free shared storage for checkpoint plus 100 GiB reserve")
print("Downloading", repo, revision, "weight_bytes", needed, flush=True)
snapshot_download(repo, revision=revision, local_dir=directory, max_workers=4,
                  allow_patterns=["*.json", "*.safetensors", "*.txt", "*.model", "*.tiktoken", "*.jinja", "LICENSE"])
index = json.loads((directory / "model.safetensors.index.json").read_text())
required = set(index["weight_map"].values()) | {"config.json", "tokenizer.json", "tokenizer_config.json"}
remote = {f.rfilename: f for f in metadata.siblings}
for name in sorted(required):
    path = directory / name
    if not path.is_file() or path.stat().st_size != remote[name].size:
        raise RuntimeError("Missing or incomplete checkpoint file: " + name)
manifest = {"repo": repo, "revision": revision, "weight_bytes": needed,
            "verified_files": {name: remote[name].size for name in sorted(required)},
            "validation": "HF download integrity and required-file size checks"}
(directory / "download_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("CHECKPOINT_READY", directory, "shards", len(set(index["weight_map"].values())), flush=True)
PY
