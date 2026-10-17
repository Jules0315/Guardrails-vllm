"""Check packaged syntax, symlinks, document links and recorded file hashes locally."""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    checked = 0
    for p in root.rglob('*'):
        if '.git' in p.parts or '__pycache__' in p.parts:
            continue
        if p.is_symlink():
            assert p.resolve().is_dir(), 'Broken script entry: ' + str(p)
            continue
        if not p.is_file():
            continue
        if p.suffix == '.py':
            ast.parse(p.read_text(), filename=str(p))
            checked += 1
        elif p.suffix in {'.sh', '.sbatch'}:
            subprocess.check_call(['bash', '-n', str(p)])
            for embedded in re.findall(r"<<'PY'[^\n]*\n(.*?)\nPY(?:\n|$)", p.read_text(), re.S):
                ast.parse(embedded, filename=str(p) + ':embedded-python')
            checked += 1
        if p.name in {'RELEASE_MANIFEST.json', 'TOOLS_MANIFEST.json'}:
            for name, digest in json.loads(p.read_text())['files'].items():
                file = p.parent / name
                assert hashlib.sha256(file.read_bytes()).hexdigest() == digest, 'Hash mismatch: ' + str(file)
        if p.suffix == '.md':
            for target in re.findall(r'\[[^\]]+\]\(([^\s)]+)\)', p.read_text()):
                if '://' in target or target.startswith('#'):
                    continue
                assert (p.parent / target.split('#')[0]).exists(), 'Broken document link: ' + target
    print('PASS: syntax for {} scripts, manifest hashes, symlinks and local document links.'.format(checked))


if __name__ == '__main__':
    main()
