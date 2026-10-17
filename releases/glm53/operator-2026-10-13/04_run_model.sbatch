#!/bin/bash
#SBATCH --job-name=leonardo-glm53-multi
#SBATCH --account=YOUR_PROJECT
#SBATCH --partition=boost_usr_prod
#SBATCH --qos=boost_qos_dbg
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-task=32
#SBATCH --mem=480GB
#SBATCH --time=00:30:00
#SBATCH --signal=B:TERM@90
#SBATCH --output=%x-%j.out
set -euo pipefail
export GLM_TEST_DIR="${SLURM_SUBMIT_DIR:?}"
export GLM_MASTER_ADDR="$(getent hosts "$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -1)" | awk '{print $1; exit}')"
export GLM_MASTER_PORT=$((29000 + SLURM_JOB_ID % 1000))
export GLM_API_PORT=$((21000 + SLURM_JOB_ID % 10000))
export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"
export PMIX_MCA_gds=hash
SRUN_PID=""
cleanup() {
    if [[ -f "$GLM_TEST_DIR/.runtime/endpoint.json" ]]; then
        python3 - "$GLM_TEST_DIR/.runtime/endpoint.json" "$SLURM_JOB_ID" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1])
if json.loads(p.read_text()).get('job_id') == sys.argv[2]: p.unlink()
PY
    fi
    if [[ -n "$SRUN_PID" ]]; then kill "$SRUN_PID" 2>/dev/null || true; wait "$SRUN_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
printf 'nodes: %s\n' "$SLURM_JOB_NODELIST"
srun --kill-on-bad-exit=1 --ntasks-per-node=1 bash "$GLM_TEST_DIR/run_model.sh" &
SRUN_PID=$!
python3 - "$GLM_API_PORT" "$SRUN_PID" <<'PY'
import json,os,sys,time,urllib.request,urllib.error
from pathlib import Path
port,pid=map(int,sys.argv[1:])
directory=Path(os.environ['GLM_TEST_DIR'])
key=(directory/'.runtime/api_key').read_text().strip()
url=f'http://127.0.0.1:{port}'
start=time.monotonic()
while time.monotonic()-start<1500:
    os.kill(pid,0)
    try:
        with urllib.request.urlopen(url+'/health',timeout=5) as r:
            if r.status==200: break
    except (urllib.error.URLError,TimeoutError): pass
    time.sleep(5)
else:
    raise RuntimeError('API failed to become healthy within 25 minutes')
healthy_after=time.monotonic()-start
body={'model':'glm-5.3-flash-leonardo','messages':[{'role':'user','content':'What is 17 + 25? Give only the number.'}], 'max_tokens':1024,'temperature':0,'chat_template_kwargs':{'reasoning_effort':'low','clear_thinking':True}}
request=urllib.request.Request(url+'/v1/chat/completions',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
inference_start=time.monotonic()
with urllib.request.urlopen(request,timeout=120) as r: response=json.load(r)
content=response['choices'][0]['message'].get('content') or ''
if '42' not in content: raise RuntimeError('Initial arithmetic inference did not return 42')
result={'job_id':os.environ['SLURM_JOB_ID'],'api_healthy_after_seconds':round(healthy_after,2),'initial_inference_seconds':round(time.monotonic()-inference_start,2),'response':response}
(directory/'evidence'/f"initial-inference-{os.environ['SLURM_JOB_ID']}.json").write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
endpoint={'job_id':os.environ['SLURM_JOB_ID'],'host':os.uname().nodename.split('.')[0],'port':port,'model':'glm-5.3-flash-leonardo'}
path=directory/'.runtime/endpoint.json'
temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(endpoint)+'\n');temporary.replace(path)
print('INFERENCE_READY',json.dumps(endpoint),flush=True)
PY
wait "$SRUN_PID"
