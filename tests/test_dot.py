#!/usr/bin/env python3
"""Tests for the dot CLI entrypoint and its Stow package."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
DOT = REPO / 'dot/.local/bin/dot'


class DotCliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-dot-')
        self.base = Path(self.temp.name)
        self.home = self.base / 'home with spaces'
        self.home.mkdir()
        sysroot = self.base / 'sysroot'
        (sysroot / 'etc').mkdir(parents=True)
        (sysroot / 'etc/os-release').write_text('ID=fedora\n')
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            XDG_CONFIG_HOME=str(self.home / '.config'),
            XDG_DATA_HOME=str(self.home / '.local/share'),
            XDG_STATE_HOME=str(self.home / '.local/state'),
            XDG_CACHE_HOME=str(self.home / '.cache'),
            DOTFILES_SYSROOT=str(sysroot),
            GIT_CONFIG_NOSYSTEM='1',
        )

    def tearDown(self):
        self.temp.cleanup()

    def run_dot(self, *args, executable=DOT):
        return subprocess.run(
            [str(executable), *args],
            cwd=self.base,
            env=self.env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_help_output(self):
        for args in [(), ('help',), ('-h',), ('--help',)]:
            with self.subTest(args=args):
                result = self.run_dot(*args)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('dot install', result.stdout)
                self.assertEqual(result.stderr, '')

    def test_install_dry_run_delegates(self):
        result = self.run_dot('install', '--dry-run', '--profile', 'desktop')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('mise install', result.stdout)
        self.assertIn('Vorschau abgeschlossen', result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_symlinked_dot_resolves_repo_with_spaces(self):
        clone = self.base / 'checkout with spaces'
        shutil.copytree(REPO, clone, ignore=shutil.ignore_patterns('.git', '__pycache__', '*.log'))
        stowed = self.home / '.local/bin/dot'
        stowed.parent.mkdir(parents=True)
        stowed.symlink_to(clone / 'dot/.local/bin/dot')

        result = self.run_dot('install', '--dry-run', '--profile', 'desktop', executable=stowed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Vorschau abgeschlossen', result.stdout)

    def test_stow_installs_dot_and_handles_spaces(self):
        if not shutil.which('stow'):
            self.skipTest('GNU Stow fehlt')
        clone = self.base / 'checkout with spaces'
        shutil.copytree(REPO, clone, ignore=shutil.ignore_patterns('.git', '__pycache__', '*.log'))

        install = subprocess.run(
            ['bash', str(clone / 'install.sh'), '--only', 'dotfiles'],
            cwd=self.base,
            env=self.env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(install.returncode, 0, install.stdout + install.stderr)

        stowed = self.home / '.local/bin/dot'
        self.assertTrue(stowed.is_symlink())
        self.assertEqual(stowed.resolve(), (clone / 'dot/.local/bin/dot').resolve())

        result = self.run_dot('install', '--dry-run', '--profile', 'desktop', executable=stowed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Vorschau abgeschlossen', result.stdout)

    def test_unknown_subcommand_fails_cleanly(self):
        result = self.run_dot('unknown-cmd')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unbekannter Befehl', result.stderr)


if __name__ == '__main__':
    unittest.main()
