#!/bin/bash
#SBATCH --job-name=glm53-cache-seed
#SBATCH --account=YOUR_PROJECT
#SBATCH --partition=lrd_all_serial
#SBATCH --cpus-per-task=1
#SBATCH --mem=2000M
#SBATCH --time=00:20:00
#SBATCH --output=%x-%j.out
set -euo pipefail
SRC="${WORK:?}/team_vllm/glm53/cache"
DST="${GLM_RUN_BASE:-${WORK:?}/team_vllm/users/${USER:?}/glm53}/cache"
if [[ "$(stat -c %U "$SRC")" == "$USER" ]]; then
    chmod -R a+rX "$SRC"
fi
mkdir -p "$DST"
rsync -rlt "$SRC"/ "$DST"/
changes="$(rsync -rltn --itemize-changes "$SRC"/ "$DST"/)"
if [[ -n "$changes" ]]; then
    printf '%s\n' "$changes" | head -20
    exit 1
fi
du -sh "$DST"
echo CACHE_SEED_DONE "$DST"
