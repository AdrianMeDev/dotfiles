#!/usr/bin/env python3
"""Check Stow targets without following foreign directory symlinks or copying secrets."""
import argparse
import datetime
import os
from pathlib import Path
import shutil
import sys
import tempfile


def packages(repo):
    return (repo / 'manifests/stow.txt').read_text().split()


def conflicts(repo, home):
    found = set()
    for package in packages(repo):
        base = repo / package
        for source in sorted(base.rglob('*')):
            if source.is_symlink():
                raise ValueError(f'Symlink in Quellpaket nicht erlaubt: {source.relative_to(repo)}')
            relative = source.relative_to(base)
            target = home / relative
            for ancestor in reversed(target.parents):
                if ancestor == home or home not in ancestor.parents:
                    continue
                if ancestor.is_symlink():
                    raise ValueError(f'Verzeichnis-Symlink zuerst manuell auflösen: {ancestor.relative_to(home)}')
                if ancestor.exists() and not ancestor.is_dir():
                    found.add(ancestor)
            if source.is_dir():
                if target.is_symlink():
                    raise ValueError(f'Verzeichnis-Symlink zuerst manuell auflösen: {relative}')
                if target.exists() and not target.is_dir():
                    found.add(target)
            elif target.is_symlink() and target.resolve() == source.resolve():
                continue
            elif target.exists() or target.is_symlink():
                found.add(target)
    # If a parent itself conflicts, it is moved once, not again for every child.
    return sorted(p for p in found if not any(parent in found for parent in p.parents))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--backup', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    home = Path.home().resolve()
    if repo == home or home.is_relative_to(repo):
        raise ValueError('Home-Ziel darf nicht im Repository liegen.')
    for name in ('.gitconfig-local', '.ssh/config.local'):
        p = home / name
        if p.is_symlink() or (p.exists() and not p.is_file()):
            raise ValueError(f'Private lokale Datei muss eine reguläre Datei sein: {name}')
    # Precedence: this legacy WezTerm file would mask the XDG configuration.
    collisions = conflicts(repo, home)
    legacy = home / '.wezterm.lua'
    if legacy.exists() or legacy.is_symlink():
        collisions.append(legacy)
    if not collisions:
        print('Stow-Vorprüfung: keine Dateikonflikte.')
        return
    for p in collisions:
        print(f'Dateikonflikt: {p.relative_to(home)}', file=sys.stderr)
    if not args.backup:
        raise ValueError('Verlinkung gestoppt. Mit --backup sichern oder Konflikte manuell auflösen.')
    if args.check:
        print(f'Backup vorgesehen: {len(collisions)} Pfade außerhalb des Repos.')
        return
    # Private backup directory is always outside the checkout, even for custom layouts.
    parent = home / '.local/state/dotfiles/backups'
    if parent.resolve().is_relative_to(repo):
        raise ValueError('Backup-Ziel darf nicht im Repository liegen.')
    parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-')
    backup = Path(tempfile.mkdtemp(prefix=stamp, dir=parent))
    for p in collisions:
        destination = backup / p.relative_to(home)
        destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        shutil.move(str(p), str(destination))
    print(f'Backup gespeichert: {backup}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        print(f'Fehler: {error}', file=sys.stderr)
        sys.exit(1)
