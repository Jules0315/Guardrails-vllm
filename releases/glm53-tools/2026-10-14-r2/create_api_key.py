"""Generate a session key, or save one entered privately with --prompt."""
import argparse
from getpass import getpass
import os
from pathlib import Path
import secrets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    parser.add_argument('--prompt', action='store_true')
    args = parser.parse_args()
    key = getpass('Session inference API key: ').strip() if args.prompt else secrets.token_urlsafe(32)
    if not key or any(char.isspace() for char in key):
        raise SystemExit('Key must be nonempty and contain no whitespace.')
    # Create with private permissions from the start; never overwrite a key.
    fd = os.open(str(args.path), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as handle:
        handle.write(key + '\n')
    print('API key file: ' + str(args.path.resolve()))


if __name__ == '__main__':
    main()
