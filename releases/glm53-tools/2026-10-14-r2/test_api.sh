#!/bin/bash
set -euo pipefail
umask 077
port=${GLM_LOCAL_PORT:-18083}
key=${GLM_API_KEY_FILE:-api_key.txt}
placeholder=$(mktemp ./team_test_results-XXXXXXXX)
output="$placeholder.json"
mv "$placeholder" "$output"
status=0
python3 test_endpoint.py \
    --base-url "http://127.0.0.1:$port" \
    --api-key-file "$key" \
    --output "$output" || status=$?
printf 'Test results: %s\n' "$output"
exit "$status"
