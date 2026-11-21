#!/usr/bin/env python3
"""Conservative local scan. Reports only paths and categories, never matched values."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

PATTERNS = {
    'private key': re.compile(r'-----BEGIN (?:OPENSSH |RSA |EC |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    'access token': re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9_-]{24,}|AKIA[A-Z0-9]{16})'),
    'credential assignment': re.compile(r'''(?i)(?:password|api[_-]?key|access[_-]?token|client[_-]?secret)\s*[=:]\s*["'][^"'\s]{8,}["']'''),
    'credential URL': re.compile(r'https?://[^\s/:]+:[^\s/@]+@'),
    'machine-specific home': re.compile(r'/home/[a-zA-Z0-9_.-]+/'),
}


def scan_bytes(path, data):
    text = data.decode('utf-8', errors='replace')
    findings = [kind for kind, pattern in PATTERNS.items() if pattern.search(text)]
    if path.name in {'.gitconfig-local', 'config.local', 'local.zsh', 'fish_variables', '.netrc', '.npmrc'} or path.name.startswith('id_'):
        findings.append('private filename')
    if path.name == '.env' or (path.name.startswith('.env.') and not path.name.endswith('.example')):
        findings.append('environment file')
    return findings


def load_allowlist(path):
    """Reviewed historical blob IDs: one 40-hex Git object ID per line, then an optional note."""
    allowed = set()
    if not path.is_file():
        return allowed
    for number, line in enumerate(path.read_text().splitlines(), 1):
        fields = line.split('#', 1)[0].split()
        if not fields:
            continue
        oid = fields[0]
        if len(fields) != 1 or not re.fullmatch(r'[0-9a-f]{40}', oid):
            raise SystemExit(f'{path.name}:{number}: ungültige Blob-ID')
        allowed.add(oid)
    return allowed


def scan_history(root, allowed):
    """Yield (path, finding) for every reachable blob that is not on the allowlist."""
    objects = subprocess.check_output(['git', '-C', str(root), 'rev-list', '--objects', '--all']).splitlines()
    for entry in objects:
        oid, _, raw_name = entry.partition(b' ')
        if not raw_name or oid.decode() in allowed:
            continue
        kind = subprocess.check_output(['git', '-C', str(root), 'cat-file', '-t', oid.decode()]).strip()
        if kind != b'blob':
            continue
        data = subprocess.check_output(['git', '-C', str(root), 'cat-file', 'blob', oid.decode()])
        for finding in scan_bytes(Path(raw_name.decode()), data):
            yield raw_name.decode(), finding


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true', help='Also scan all reachable Git blobs except reviewed ones in scripts/secret-scan-allowlist.txt; does not rewrite history.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    paths = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z', '--cached', '--others', '--exclude-standard']).split(b'\0')
    failed = False
    for name in sorted(set(paths)):
        if not name:
            continue
        relative = Path(name.decode())
        path = root / relative
        if not path.is_file() or path.is_symlink():
            continue
        for kind in scan_bytes(relative, path.read_bytes()):
            print(f'{relative}: {kind}')
            failed = True
    if args.history:
        allowed = load_allowlist(root / 'scripts/secret-scan-allowlist.txt')
        for name, finding in scan_history(root, allowed):
            print(f'History {name}: {finding}')
            failed = True
    if not failed:
        print('Secret-Scan: keine Treffer in den geprüften Dateien (heuristisch, keine Garantie).')
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
