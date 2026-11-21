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

    # --- dot update -------------------------------------------------------

    def setup_update(self, family='fedora', tools=('sudo', 'mise', 'flatpak', 'pacman', 'dnf', 'apt-get', 'paru', 'yay'),
                     fail=None, mise_after='node 24.2.0'):
        """Fake tools on PATH that only log their invocation."""
        bindir = self.base / 'fakebin'
        bindir.mkdir()
        self.log = self.base / 'calls.log'
        for tool in tools:
            script = bindir / tool
            body = f'#!/bin/sh\necho "{tool} $*" >> "{self.log}"\n'
            if tool == 'mise':
                state = self.base / 'mise-state'
                body += (f'if [ "$1" = ls ]; then cat "{state}"; exit 0; fi\n'
                         f'if [ "$1" = upgrade ]; then echo "{mise_after}" > "{state}"; fi\n')
            if fail == tool:
                body += 'exit 3\n'
            script.write_text(body)
            script.chmod(0o755)
        (self.base / 'mise-state').write_text('node 24.1.0\n')
        (self.base / 'sysroot/etc/os-release').write_text(f'ID={family}\n')
        # Isolated PATH: host tools such as a real paru or flatpak must never be reachable.
        for basic in ('bash', 'env', 'git', 'diff', 'awk', 'sort', 'sed', 'cat', 'mkdir', 'dirname',
                      'readlink', 'uname', 'rm', 'mktemp', 'tr', 'grep', 'head', 'id'):
            found = shutil.which(basic)
            if found and not (bindir / basic).exists():
                (bindir / basic).symlink_to(found)
        self.env['PATH'] = str(bindir)
        self.env.pop('WSL_DISTRO_NAME', None)
        self.env.pop('WSL_INTEROP', None)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def make_plugin(self, name, advance=True):
        """Local git clone of a local origin; optionally the origin gets a new commit."""
        git = ['git', '-c', 'user.name=t', '-c', 'user.email=t@example.invalid', '-c', 'commit.gpgsign=false']
        origin = self.base / f'origin-{name}'
        origin.mkdir()
        subprocess.run([*git, 'init', '-q', '-b', 'main', str(origin)], check=True, env=self.env)
        (origin / 'a').write_text('1')
        subprocess.run([*git, '-C', str(origin), 'add', 'a'], check=True, env=self.env)
        subprocess.run([*git, '-C', str(origin), 'commit', '-qm', 'one'], check=True, env=self.env)
        dest = self.home / '.local/share/zsh/plugins' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([*git, 'clone', '-q', str(origin), str(dest)], check=True, env=self.env)
        if advance:
            (origin / 'b').write_text('2')
            subprocess.run([*git, '-C', str(origin), 'add', 'b'], check=True, env=self.env)
            subprocess.run([*git, '-C', str(origin), 'commit', '-qm', 'two'], check=True, env=self.env)
        return dest

    def test_update_arch_with_aur_and_mise_diff(self):
        self.setup_update('arch')
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [
            'sudo pacman -Syu --noconfirm', 'paru -Sua --noconfirm',
            'mise ls --current --no-header', 'mise upgrade --yes', 'mise ls --current --no-header'])
        self.assertIn('< node 24.1.0', result.stdout)
        self.assertIn('> node 24.2.0', result.stdout)
        self.assertIn('nvim-pack-lock.json', result.stdout)

    def test_update_arch_without_aur_helper(self):
        self.setup_update('arch', tools=('sudo', 'pacman', 'mise'))
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls()[0], 'sudo pacman -Syu --noconfirm')
        self.assertFalse([c for c in self.calls() if c.startswith(('paru', 'yay'))])

    def test_update_fedora_wsl_excludes_kernel(self):
        self.setup_update('fedora')
        self.env['WSL_DISTRO_NAME'] = 'Fedora'
        result = self.run_dot('update')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls()[0], 'sudo dnf upgrade --refresh -y --exclude=kernel*')
        self.assertFalse([c for c in self.calls() if c.startswith('flatpak')])

    def test_update_fedora_plain(self):
        self.setup_update('fedora')
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls()[0], 'sudo dnf upgrade --refresh -y')

    def test_update_debian(self):
        self.setup_update('debian')
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls()[:2], [
            'sudo env DEBIAN_FRONTEND=noninteractive apt-get update',
            'sudo env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y'])

    def test_update_mise_without_changes(self):
        self.setup_update('fedora', mise_after='node 24.1.0')
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('keine Versionsänderungen', result.stdout)

    def test_update_flatpak_desktop_and_headless(self):
        self.setup_update('fedora')
        desktop = self.run_dot('update', '--profile', 'desktop')
        self.assertEqual(desktop.returncode, 0, desktop.stdout + desktop.stderr)
        self.assertIn('flatpak update --user --noninteractive -y', self.calls())
        self.log.unlink()
        headless = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(headless.returncode, 0, headless.stdout + headless.stderr)
        self.assertFalse([c for c in self.calls() if c.startswith('flatpak')])

    def test_update_desktop_without_flatpak_installed(self):
        self.setup_update('fedora', tools=('sudo', 'dnf', 'mise'))
        result = self.run_dot('update', '--profile', 'desktop')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_update_zsh_plugins_pull(self):
        self.setup_update('fedora')
        plugin = self.make_plugin('zsh-test')
        (self.home / '.local/share/zsh/plugins/not-a-repo').mkdir()
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((plugin / 'b').exists())

    def test_update_failure_propagates(self):
        for tool in ('sudo', 'mise'):
            with self.subTest(tool=tool):
                self.setup_update('fedora', fail=tool)
                result = self.run_dot('update', '--profile', 'headless')
                self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
                shutil.rmtree(self.base / 'fakebin')
                self.log.unlink()

    def test_update_plugin_failure_propagates(self):
        self.setup_update('fedora')
        plugin = self.make_plugin('zsh-test', advance=False)
        (plugin / 'local').write_text('x')
        subprocess.run(['git', '-C', str(plugin), 'remote', 'set-url', 'origin', str(self.base / 'missing')],
                       check=True, env=self.env)
        result = self.run_dot('update', '--profile', 'headless')
        self.assertNotEqual(result.returncode, 0)

    def test_update_dry_run_writes_nothing(self):
        self.setup_update('arch')
        plugin = self.make_plugin('zsh-test')
        head = subprocess.run(['git', '-C', str(plugin), 'rev-parse', 'HEAD'], capture_output=True,
                              text=True, check=True, env=self.env).stdout
        result = self.run_dot('update', '--dry-run', '--profile', 'desktop')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [])
        for step in ('sudo pacman -Syu --noconfirm', 'paru -Sua --noconfirm', 'mise upgrade --yes',
                     'flatpak update --user --noninteractive -y', 'pull --ff-only'):
            self.assertIn(step, result.stdout)
        self.assertIn('Vorschau abgeschlossen', result.stdout)
        self.assertEqual(subprocess.run(['git', '-C', str(plugin), 'rev-parse', 'HEAD'], capture_output=True,
                                        text=True, check=True, env=self.env).stdout, head)
        self.assertFalse((plugin / 'b').exists())

    def test_update_help_and_bad_option(self):
        result = self.run_dot('update', '--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('dot update', result.stdout)
        self.assertNotEqual(self.run_dot('update', '--bogus').returncode, 0)
        self.assertNotEqual(self.run_dot('update', '--profile', 'x').returncode, 0)

    def test_unknown_subcommand_fails_cleanly(self):
        result = self.run_dot('unknown-cmd')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unbekannter Befehl', result.stderr)


if __name__ == '__main__':
    unittest.main()
