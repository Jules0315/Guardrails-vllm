# Shared Leonardo inference framework

Start with [QUICK_GUIDE.md](QUICK_GUIDE.md) to run GLM or DeepSeek, locate your session API key, create an SSH tunnel and run English API tests.

- `profiles/`: model settings, resources and runtime selection.
- `inference.py`, `node.py`, `serve_model.sbatch`, `lifecycle.py`: shared server workflow.
- `client.py`, `test_endpoint.py`: shared client and API checks.
- `hooks/`: reviewed model-specific pre-start steps.
- `site.example.json`: operator template for existing assets and Slurm settings.
- `RELEASE_MANIFEST.json`: snapshot file hashes.

The SIF, Python overlay, checkpoints and private keys are stored separately from this code release. See the quick guide for the validation scope and installation layout.
