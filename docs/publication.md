# Public packaging notes

This repository contains an allowlisted copy of deployment code and reviewed documentation. The original cluster installation is unchanged.

## Adaptations

- Personal team storage names became `team_vllm`.
- Slurm account identifiers became `YOUR_PROJECT`; set your approved `SBATCH_ACCOUNT` before submission.
- Personal job-name prefixes became `leonardo-`.
- Stock SIF paths were aligned to the documented public installation layout.
- Release/helper manifests were regenerated for the adapted files.
- Historical source hashes and packaged hashes are recorded in `PUBLICATION_PROVENANCE.json`.

The original operator configuration passed model inference checks. Public path adaptations and the candidate profile have not been GPU revalidated. Operator and candidate folders remain separate to preserve that distinction.

## Excluded material

No `.env`, `.runtime`, API key, SSH credential, proxy credential, personal correspondence, raw cluster logs, model weights, SIF image, wheel, compiled cache or Python overlay is included. Model metadata is fetched separately from a pinned source.

The original team application repository is a separate project. Publishing this deployment code does not imply authorship of that application, vLLM, the community backport, or upstream kernels.
