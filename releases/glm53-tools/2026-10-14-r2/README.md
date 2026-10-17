# GLM-5.3 quick-guide helpers

Version: `2026-10-14-r2`; `test_api.sh` now creates unique result filenames on macOS as well as Linux. These helpers shorten the team quick guide. They do not change the model launcher, promote an inference candidate, or start a GPU job automatically.

| Script | Run where | Purpose |
| --- | --- | --- |
| `prepare_run.sh` | Leonardo | Pin and verify the candidate and helpers, copy into a new private run directory, print its path. |
| `check_cache_access.py` | Leonardo | Check shared-cache access from the current account without changing permissions. |
| `create_api_key.py` | Leonardo or client | Generate a new key; `--prompt` privately saves the operator's supplied key. Never overwrite a key. |
| `submit_server.sh` | Leonardo private run directory | Explicitly submit one two-hour job and record its ID. An optional argument selects an approved reservation; `GLM_WALLTIME` overrides runtime. |
| `open_tunnel.py` | Client computer | Prompt for account, current model host and port; open a localhost-only SSH tunnel. |
| `test_api.sh` | Client private directory | Run the English API suite and create a unique result filename. |

Entry point: `$WORK/team_vllm/scripts/glm53-tools`.

Server preparation:

```bash
BASE="$WORK/team_vllm"
TOOLS="$BASE/scripts/glm53-tools"
RUN_DIR=$(bash "$TOOLS/prepare_run.sh") && cd "$RUN_DIR"
```

Only `.runtime` and keys in private directories may hold session secrets. Share reviewed results separately. Coordinate one server at a time and check quota, budget and reservation validity before explicitly running `submit_server.sh`.

The helper release has local behavioral checks only. `scripts/glm53-next` remains an inference candidate; use the full guide for validated operator scope. Publishing these helpers does not establish team-account connectivity or inference validation.
