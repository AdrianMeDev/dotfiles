#!/usr/bin/env python3
"""Unit tests for manifests/packages.tsv and scripts/pkg.sh."""
from pathlib import Path
import re
import shutil
import subprocess
import unittest

REPO = Path(__file__).resolve().parents[1]
PKG_SH = REPO / 'scripts' / 'pkg.sh'
MANIFEST = REPO / 'manifests' / 'packages.tsv'
SYSTEM_TXT = REPO / 'manifests' / 'system.txt'
NAME_RE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9+._-]*$')


def manifest_rows():
    rows = []
    for line in MANIFEST.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        rows.append(line.split('\t'))
    return rows


def system_packages():
    return {
        line.strip()
        for line in SYSTEM_TXT.read_text(encoding='utf-8').splitlines()
        if line.strip() and not line.startswith('#')
    }


class PkgTests(unittest.TestCase):
    def setUp(self):
        self.bash = shutil.which('bash') or '/bin/bash'

    def run_pkg(self, body):
        return subprocess.run(
            [self.bash, '-c', f'source "{PKG_SH}"\n{body}'],
            cwd=REPO,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def resolve(self, family, profile):
        res = self.run_pkg(f'pkg_resolve {family} {profile}')
        self.assertEqual(res.returncode, 0, res.stderr)
        return res.stdout.split()

    def test_manifest_shape(self):
        rows = manifest_rows()
        self.assertTrue(rows)
        names = [row[0] for row in rows]
        self.assertEqual(len(names), len(set(names)), 'duplicate logical names')
        for row in rows:
            with self.subTest(name=row[0]):
                self.assertEqual(len(row), 5, row)
                self.assertTrue(all(cell.strip() == cell and cell for cell in row), row)
                self.assertIn(row[1], ('base', 'desktop'))
                for cell in row[2:]:
                    if cell == '-':
                        continue
                    for pkg in cell.split(','):
                        self.assertRegex(pkg, NAME_RE)

    def test_fedora_matches_system_txt(self):
        resolved = self.resolve('fedora', 'desktop')
        self.assertEqual(len(resolved), len(set(resolved)))
        self.assertEqual(set(resolved), system_packages())

    def test_headless_excludes_desktop_rows(self):
        rows = manifest_rows()
        self.assertTrue(any(r[1] == 'desktop' for r in rows))
        for family, col in (('arch', 2), ('fedora', 3), ('debian', 4)):
            with self.subTest(family=family):
                base = {p for r in rows if r[1] == 'base' for p in r[col].split(',')}
                full = {p for r in rows for p in r[col].split(',')}
                self.assertEqual(set(self.resolve(family, 'headless')), base)
                self.assertEqual(set(self.resolve(family, 'desktop')), full)

    def test_family_specific_names(self):
        arch = self.resolve('arch', 'headless')
        fedora = self.resolve('fedora', 'headless')
        debian = self.resolve('debian', 'headless')
        self.assertIn('fd', arch)
        self.assertIn('fd-find', fedora)
        self.assertIn('fd-find', debian)
        self.assertIn('base-devel', arch)
        self.assertTrue({'gcc', 'gcc-c++', 'make'} <= set(fedora))
        self.assertIn('build-essential', debian)
        self.assertIn('libssl-dev', debian)
        self.assertIn('openssl-devel', fedora)
        self.assertIn('gh', fedora)
        self.assertIn('github-cli', arch)

    def test_pkg_names(self):
        res = self.run_pkg('pkg_names base-devel fedora')
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(res.stdout.split(), ['gcc', 'gcc-c++', 'make'])
        res = self.run_pkg('DISTRO_FAMILY=debian pkg_names fd')
        self.assertEqual(res.stdout.split(), ['fd-find'])
        res = self.run_pkg('pkg_names does-not-exist arch')
        self.assertNotEqual(res.returncode, 0)

    def test_dash_cells_are_skipped(self):
        res = self.run_pkg(
            'tmp=$(mktemp); printf "a\\tbase\\t-\\tfoo,bar\\tbaz\\n" > "$tmp"; '
            'PKG_MANIFEST=$tmp; pkg_resolve arch headless; echo ---; pkg_resolve fedora headless; rm -f "$tmp"'
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        arch, fedora = res.stdout.split('---')
        self.assertEqual(arch.split(), [])
        self.assertEqual(fedora.split(), ['foo', 'bar'])

    def test_unknown_family_or_profile_fails(self):
        res = self.run_pkg('pkg_resolve gentoo desktop')
        self.assertNotEqual(res.returncode, 0)
        self.assertTrue(res.stderr.strip())
        self.assertEqual(res.stdout, '')
        res = self.run_pkg('pkg_resolve fedora server')
        self.assertNotEqual(res.returncode, 0)


if __name__ == '__main__':
    unittest.main()
