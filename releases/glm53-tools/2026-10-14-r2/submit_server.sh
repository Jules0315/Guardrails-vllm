#!/bin/bash
# Submit only when called explicitly by the operator after team coordination.
set -euo pipefail
umask 077
if (( $# > 1 )); then
    echo 'Usage: bash submit_server.sh [APPROVED_RESERVATION]' >&2
    exit 2
fi
[[ -r 04_run_model.sbatch && -r run_model.sh && -s .runtime/api_key ]] || {
    echo 'Run from a prepared private directory after creating the API key.' >&2
    exit 1
}
[[ ! -e .runtime/job_id ]] || {
    echo 'This directory already has a submission record; use a fresh run directory.' >&2
    exit 1
}
walltime=${GLM_WALLTIME:-02:00:00}
args=(--parsable --job-name="${USER:?}-glm53")
args+=(--qos=boost_qos_lprod --time="$walltime")
if (( $# == 1 )); then
    args+=(--reservation="$1")
fi
submitted=$(sbatch "${args[@]}" 04_run_model.sbatch)
job_id=${submitted%%;*}
[[ "$job_id" =~ ^[0-9]+$ ]] || {
    echo 'Unexpected sbatch response; check squeue before trying again.' >&2
    exit 1
}
printf '%s\n' "$job_id" > .runtime/job_id
printf 'Submitted job: %s\n' "$job_id"
printf 'Follow its log: %s-glm53-%s.out\n' "$USER" "$job_id"
squeue -j "$job_id" || true
