#!/usr/bin/env python3
"""Render agent-config/ into ~/.claude and ~/.pi/agent; sync, check and report drift."""
import argparse
import datetime
import os
from pathlib import Path
import shutil
import sys
import tempfile

FRONTMATTER = 'claude-frontmatter.txt'
# Superseded paths (relative to the pi / Claude root) that are retired into the backup.
LEGACY = {
    'pi': ('skills/erklaeren', 'skills/projekt-erklaeren', 'prompts/plan.md', 'prompts/review.md'),
    'claude': ('skills/erklaeren', 'skills/projekt-erklaeren'),
}
# Skill directories tolerated as foreign (tool-managed or a kept local copy), never reported.
MANAGED_SKILLS = ('synced', 'next-all')


def source_files(base):
    """Yield (relative path, source path) below base; symlinks in the source are rejected."""
    if base.is_symlink():
        raise ValueError(f'Symlink in Quellpaket nicht erlaubt: {base}')
    for path in sorted(base.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Symlink in Quellpaket nicht erlaubt: {path}')
        if path.is_file():
            yield path.relative_to(base), path


def inject(skill, frontmatter, label):
    """Insert Claude-only frontmatter fields after line 1 (---) of a SKILL.md."""
    first, sep, rest = skill.partition(b'\n')
    if first.rstrip(b'\r') != b'---' or not sep:
        raise ValueError(f'{label}: erste Zeile muss --- sein, um Claude-Frontmatter einzufügen.')
    if not frontmatter.endswith(b'\n'):
        frontmatter += b'\n'
    return first + sep + frontmatter + rest


def render(repo):
    """Return {tool: {relative path: bytes}} for 'claude' and 'pi'."""
    src = repo / 'agent-config'
    out = {'claude': {}, 'pi': {}}
    for tool in out:
        for rel, path in source_files(src / tool):
            out[tool][rel.as_posix()] = path.read_bytes()
    for rel, path in source_files(src / 'skills'):
        if rel.name == FRONTMATTER:
            continue
        data = path.read_bytes()
        key = 'skills/' + rel.as_posix()
        out['pi'][key] = data
        extra = path.parent / FRONTMATTER
        if rel.name == 'SKILL.md' and rel.parent.parent == Path('.') and extra.is_file():
            data = inject(data, extra.read_bytes(), key)
        out['claude'][key] = data
    return out


def roots():
    home = Path.home()
    return {
        'claude': Path(os.environ.get('CLAUDE_CONFIG_DIR') or home / '.claude').expanduser().absolute(),
        'pi': Path(os.environ.get('PI_CODING_AGENT_DIR') or home / '.pi/agent').expanduser().absolute(),
    }


def check_symlinks(root, target):
    """Reject the root or any parent of target (up to its leaf) being a symlink."""
    for p in [target, *target.parents]:
        if p.is_symlink() and p != target:
            raise ValueError(f'Symlink im Zielpfad nicht erlaubt: {p}')
        if p == root:
            break


def classify(root, rel, data):
    """Return 'ok', 'missing' or 'modified'; raise for symlinks in the target path."""
    target = root / rel
    check_symlinks(root, target)
    if target.is_symlink():
        raise ValueError(f'Symlink als Ziel nicht erlaubt: {target}')
    if not target.exists():
        return 'missing'
    return 'ok' if target.is_file() and target.read_bytes() == data else 'modified'


def analyse(rendered, root_map):
    """Return (entries, legacy): entries = [(tool, rel, state, target)], legacy = [(tool, path)]."""
    entries, legacy = [], []
    for tool, files in rendered.items():
        root = root_map[tool]
        if root.is_symlink():
            raise ValueError(f'Symlink als Wurzel nicht erlaubt: {root}')
        for rel, data in sorted(files.items()):
            entries.append((tool, rel, classify(root, rel, data), root / rel))
        for rel in LEGACY[tool]:
            path = root / rel
            check_symlinks(root, path)
            if path.exists() or path.is_symlink():
                legacy.append((tool, path))
    return entries, legacy


def foreign_skills(rendered, root_map):
    """Return [(tool, name)] for skill dirs that are neither rendered from the repo nor legacy."""
    found = []
    for tool, files in rendered.items():
        skills = root_map[tool] / 'skills'
        if skills.is_symlink() or not skills.is_dir():
            continue
        known = {rel.split('/')[1] for rel in files if rel.startswith('skills/')}
        known |= {Path(rel).name for rel in LEGACY[tool] if rel.startswith('skills/')}
        known |= set(MANAGED_SKILLS)
        found += [(tool, p.name) for p in sorted(skills.iterdir()) if p.is_dir() and not p.name.startswith('.') and p.name not in known]
    return found


def status(entries, legacy, root_map, foreign=()):
    for tool, rel, state, _ in entries:
        print(f'[{state}] {tool}: {rel}')
    for tool, path in legacy:
        print(f'[legacy] {tool}: {path.relative_to(root_map[tool])}')
    for tool, name in foreign:
        print(f'[foreign] {tool}: skills/{name}')
    print(f'{sum(e[2] == "ok" for e in entries)} ok, {sum(e[2] == "missing" for e in entries)} fehlen, '
          f'{sum(e[2] == "modified" for e in entries)} abweichend, {len(legacy)} veraltet.')


def backup_dir():
    parent = Path.home() / '.local/state/dotfiles/backups'
    parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-')
    return Path(tempfile.mkdtemp(prefix=stamp, dir=parent))


def write(target, data):
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=f'.{target.name}.')
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, target)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Konflikte prüfen, nichts schreiben')
    parser.add_argument('--backup', action='store_true', help='Abweichende Dateien sichern und ersetzen')
    parser.add_argument('--dry-run', action='store_true', help='Änderungen nur anzeigen')
    parser.add_argument('--status', action='store_true', help='Abweichungen melden, nichts schreiben')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    root_map = roots()
    files = render(repo)
    entries, legacy = analyse(files, root_map)
    if args.status:
        status(entries, legacy, root_map, foreign_skills(files, root_map))
        return
    state_dir = Path.home() / '.local/state/dotfiles/backups'
    if state_dir.resolve().is_relative_to(repo):
        raise ValueError('Backup-Ziel darf nicht im Repository liegen.')
    conflicts = [e for e in entries if e[2] == 'modified']
    for tool, rel, _, _ in conflicts:
        print(f'Dateikonflikt: {tool}: {rel}', file=sys.stderr)
    for tool, path in legacy:
        print(f'Veralteter Pfad: {tool}: {path.relative_to(root_map[tool])}', file=sys.stderr)
    if (conflicts or legacy) and not args.backup:
        raise ValueError('Agent-Config gestoppt. Mit --backup sichern oder Konflikte manuell auflösen.')
    todo = [e for e in entries if e[2] != 'ok']
    if args.check or args.dry_run:
        if conflicts or legacy:
            print(f'Backup vorgesehen: {len(conflicts) + len(legacy)} Pfade.')
        print(f'{"Vorschau" if args.dry_run else "Prüfung"}: {len(todo)} Dateien zu schreiben.')
        return
    if not todo and not legacy:
        print('Agent-Config: bereits aktuell.')
        return
    backup = backup_dir() if (conflicts or legacy) else None
    for tool, path in legacy:
        dest = backup / tool / path.relative_to(root_map[tool])
        dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        shutil.move(str(path), str(dest))
    for tool, rel, state, target in todo:
        if state == 'modified':
            dest = backup / tool / rel
            dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            shutil.move(str(target), str(dest))
        write(target, files[tool][rel])
    print(f'Agent-Config geschrieben: {len(todo)} Dateien.')
    if backup:
        print(f'Backup gespeichert: {backup}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        print(f'Fehler: {error}', file=sys.stderr)
        sys.exit(1)
