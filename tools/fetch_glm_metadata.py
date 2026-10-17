"""Fetch pinned public model configuration for the GPU preflight check."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    source = root / 'releases/glm53/operator-2026-10-13/metadata/manifest.json'
    manifest = json.loads(source.read_text())
    request = urllib.request.Request(manifest['config_source'], headers={'User-Agent': 'leonardo-vllm-metadata'})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != manifest['config_sha256']:
        raise RuntimeError('Pinned config checksum mismatch; output was not written.')
    json.loads(data)
    args.output.mkdir(parents=True, exist_ok=True)
    config = args.output / 'config.json'
    if config.exists() and config.read_bytes() != data:
        raise RuntimeError('Output config differs; refusing overwrite.')
    config.write_bytes(data)
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Verified pinned configuration: ' + str(config.resolve()))


if __name__ == '__main__':
    main()
