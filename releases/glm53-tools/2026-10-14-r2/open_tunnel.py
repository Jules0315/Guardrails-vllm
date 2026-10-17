"""Prompt for current session details and keep a local-only SSH tunnel open."""
import os
import re
import subprocess


def main():
    user = input('Your Leonardo login: ').strip()
    node = input('Model host from the new endpoint.json: ').strip()
    port = int(input('Model API port from the new endpoint.json: ').strip())
    local = int(os.environ.get('GLM_LOCAL_PORT', '18083'))
    pattern = r'[A-Za-z0-9][A-Za-z0-9_.-]*'
    if not re.fullmatch(pattern, user) or not re.fullmatch(pattern, node):
        raise SystemExit('Invalid login or hostname.')
    if not (1 <= port <= 65535 and 1 <= local <= 65535):
        raise SystemExit('Ports must be between 1 and 65535.')
    args = ['ssh', '-N', '-o', 'ExitOnForwardFailure=yes',
            '-o', 'ServerAliveInterval=30', '-o', 'ServerAliveCountMax=3',
            '-L', '127.0.0.1:{}:{}:{}'.format(local, node, port),
            user + '@login01-ext.leonardo.cineca.it']
    print('Keep this terminal open; Ctrl+C closes the tunnel.', flush=True)
    try:
        raise SystemExit(subprocess.call(args))
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
