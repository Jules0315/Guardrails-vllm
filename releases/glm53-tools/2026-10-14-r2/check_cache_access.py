"""Check the current account's shared-cache access; do not modify permissions."""
import os
from pathlib import Path


def main():
    source = Path(os.environ['WORK']) / 'team_vllm/glm53/cache'
    if not source.is_dir():
        raise SystemExit('Cache missing or inaccessible; contact the operator.')
    errors = []
    for directory, _, files in os.walk(str(source), onerror=errors.append):
        if not os.access(directory, os.R_OK | os.X_OK):
            errors.append(directory)
        for name in files:
            path = os.path.join(directory, name)
            if not os.access(path, os.R_OK):
                errors.append(path)
    if errors:
        raise SystemExit('Cache access failed; contact the operator: ' + str(errors[:5]))
    print('CACHE_ACCESS_OK')


if __name__ == '__main__':
    main()
