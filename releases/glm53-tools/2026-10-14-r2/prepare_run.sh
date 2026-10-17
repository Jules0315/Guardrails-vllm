#!/bin/bash
# Run on Leonardo. Print only the new private run directory on stdout.
set -euo pipefail
umask 077
TOOLS=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
python3 - "$TOOLS" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from datetime import datetime

tools = Path(sys.argv[1]).resolve()
base = Path(os.environ['WORK']) / 'team_vllm'
source = (base / 'scripts/glm53-next').resolve(strict=True)
model_files = ['04_run_model.sbatch', 'run_model.sh',
               '06_seed_user_cache.sbatch', 'test_endpoint.py']
helper_files = ['check_cache_access.py', 'create_api_key.py',
                'submit_server.sh', 'open_tunnel.py', 'test_api.sh']
release = json.loads((source / 'RELEASE_MANIFEST.json').read_text())
helpers = json.loads((tools / 'TOOLS_MANIFEST.json').read_text())

def verify(folder, names, hashes):
    for name in names:
        actual = hashlib.sha256((folder / name).read_bytes()).hexdigest()
        if actual != hashes.get(name):
            raise RuntimeError('Checksum mismatch: ' + str(folder / name))

verify(source, model_files, release['files'])
verify(tools, helper_files, helpers['files'])
run = Path(tempfile.mkdtemp(
    prefix='glm53-run-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '-',
    dir=os.environ.get('GLM_PRIVATE_RUN_ROOT', str(Path.home()))))
try:
    for folder, names in [(source, model_files + ['RELEASE_MANIFEST.json']),
                          (tools, helper_files + ['TOOLS_MANIFEST.json'])]:
        for name in names:
            shutil.copyfile(str(folder / name), str(run / name))
            (run / name).chmod(0o600)
    for name in ['.runtime', 'evidence']:
        (run / name).mkdir(mode=0o700)
    verify(run, model_files, release['files'])
    verify(run, helper_files, helpers['files'])
    (run / 'RUN_SETUP.json').write_text(json.dumps({
        'selected_candidate': str(source), 'selected_tools': str(tools),
        'candidate_status': release.get('status'),
        'tools_version': helpers['version'],
    }, indent=2) + '\n')
except Exception:
    shutil.rmtree(str(run))
    raise
print(str(run))
PY
