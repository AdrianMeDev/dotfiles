#!/usr/bin/env python3
"""Offline integration tests; every write is confined to a temporary home/check-out."""
import importlib.util
import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import subprocess
import tempfile
import time
import tomllib
import unittest

REPO = Path(__file__).resolve().parents[1]


def snapshot(root):
    return {
        str(p.relative_to(root)): ('link', os.readlink(p)) if p.is_symlink()
        else ('file', p.read_bytes()) if p.is_file() else ('dir',)
        for p in root.rglob('*')
    }


def jsonc(text):
    # Match strings first so comment delimiters within strings remain untouched.
    text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'Duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=unique)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-tests-')
        self.base = Path(self.temp.name)
        self.home = self.base / 'home with spaces'
        self.home.mkdir()
        runtime = self.base / 'runtime'
        runtime.mkdir(mode=0o700)
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'),
                        XDG_DATA_HOME=str(self.home / '.local/share'), XDG_STATE_HOME=str(self.home / '.local/state'),
                        XDG_CACHE_HOME=str(self.home / '.cache'), XDG_RUNTIME_DIR=str(runtime),
                        GIT_CONFIG_NOSYSTEM='1', TERM='xterm-256color')
        for key in list(self.env):
            if key.startswith(('GIT_CONFIG_', 'FNM_', 'MISE_', 'NVIM_')) and key != 'GIT_CONFIG_NOSYSTEM':
                del self.env[key]
        self.env.pop('TMUX', None)

    def tearDown(self):
        self.temp.cleanup()

    def run_command(self, command, success=True):
        result = subprocess.run(command, cwd=self.base, env=self.env, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=30)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def install(self, *args, success=True, repo=REPO):
        return self.run_command(['bash', str(repo / 'install.sh'), *args], success=success)

    def require_stow(self):
        if not shutil.which('stow'):
            self.skipTest('GNU Stow fehlt')

    def test_dry_run_writes_nothing(self):
        before = snapshot(self.home)
        result = self.install('--dry-run', '--extras', 'java,rust,rpmfusion,firefox,discord,spotify')
        self.assertEqual(snapshot(self.home), before)
        self.assertIn('fnm install 24', result.stdout)
        self.assertNotIn('mise use', result.stdout)

    def test_invalid_arguments(self):
        for args in [('--only',), ('--only', 'unknown'), ('--extras', 'unknown'), ('--only', 'dotfiles', '--extras', 'rust')]:
            self.install(*args, success=False)
        self.assertEqual(snapshot(self.home), {})

    def test_first_install_and_repeat(self):
        self.require_stow()
        result = self.install('--only', 'dotfiles')
        self.assertIn('Git-Identität unvollständig', result.stdout)
        self.assertTrue((self.home / '.config/fish/config.fish').is_symlink())
        self.assertFalse((self.home / '.config').is_symlink())
        self.assertFalse((self.home / '.config/nvim').is_symlink())
        before = snapshot(self.home)
        self.install('--only', 'dotfiles')
        self.assertEqual(snapshot(self.home), before)

    def test_conflicts_stop_before_changes_and_backup_restores_bytes(self):
        self.require_stow()
        config = self.home / '.config/fish/config.fish'
        config.parent.mkdir(parents=True)
        config.write_text('custom fish setting\n')
        legacy = self.home / '.wezterm.lua'
        legacy.write_text('return {}\n')
        before = snapshot(self.home)
        self.install('--only', 'dotfiles', success=False)
        self.assertEqual(snapshot(self.home), before)
        self.install('--only', 'dotfiles', '--backup', '--dry-run')
        self.assertEqual(snapshot(self.home), before)
        self.install('--only', 'dotfiles', '--backup')
        backups = list((self.home / '.local/state/dotfiles/backups').iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / '.config/fish/config.fish').read_text(), 'custom fish setting\n')
        self.assertEqual((backups[0] / '.wezterm.lua').read_text(), 'return {}\n')
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o700)
        self.assertFalse(legacy.exists())
        self.install('--only', 'dotfiles', '--backup')
        self.assertEqual(len(list(backups[0].parent.iterdir())), 1)

    def test_directory_symlink_is_never_followed(self):
        external = self.base / 'external'
        external.mkdir()
        (self.home / '.config').symlink_to(external, target_is_directory=True)
        self.install('--only', 'dotfiles', '--backup', success=False)
        self.assertEqual(snapshot(external), {})

    def test_foreign_and_broken_leaf_symlinks_are_backed_up(self):
        self.require_stow()
        original = self.base / 'original'
        original.write_text('original')
        (self.home / '.tmux.conf').symlink_to(original)
        (self.home / '.gitconfig').symlink_to(self.base / 'missing')
        self.install('--only', 'dotfiles', '--backup')
        self.assertEqual(original.read_text(), 'original')
        backup = next((self.home / '.local/state/dotfiles/backups').iterdir())
        self.assertTrue((backup / '.tmux.conf').is_symlink())
        self.assertTrue((backup / '.gitconfig').is_symlink())

    def test_private_file_symlinks_are_rejected(self):
        (self.home / '.gitconfig-local').symlink_to(REPO / 'README.md')
        self.install('--only', 'dotfiles', '--backup', success=False)

    def test_existing_git_identity_survives_backup_and_repeat(self):
        self.require_stow()
        self.run_command(['git', 'config', '--global', 'user.name', 'Example Developer'])
        self.run_command(['git', 'config', '--global', 'user.email', 'dev@example.com'])
        result = self.install('--only', 'dotfiles', '--backup')
        local = self.home / '.gitconfig-local'
        self.assertEqual(local.stat().st_mode & 0o777, 0o600)
        self.assertFalse(local.is_symlink())
        self.assertIn('Example Developer', local.read_text())
        self.assertNotIn('dev@example.com', result.stdout + result.stderr)
        self.assertEqual(self.run_command(['git', 'config', '--global', '--includes', 'user.email']).stdout.strip(), 'dev@example.com')
        before = local.read_bytes()
        self.install('--only', 'dotfiles')
        self.assertEqual(local.read_bytes(), before)

    def test_git_identity_interactive(self):
        self.require_stow()
        master, slave = pty.openpty()
        process = subprocess.Popen(['bash', str(REPO / 'install.sh'), '--only', 'dotfiles'],
                                   cwd=self.base, env=self.env, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b''
        try:
            os.write(master, b'Example Developer\ndev@example.com\n')
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        output += os.read(master, 65536)
                    except OSError:
                        break
                if process.poll() is not None:
                    break
            self.assertEqual(process.wait(timeout=3), 0, output.decode())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)
        local = (self.home / '.gitconfig-local').read_text()
        self.assertIn('dev@example.com', local)
        self.assertIn('Git-Benutzername:', output.decode())

    def test_checkout_path_with_spaces(self):
        self.require_stow()
        clone = self.base / 'checkout with spaces'
        shutil.copytree(REPO, clone, ignore=shutil.ignore_patterns('.git', '__pycache__', '*.log'))
        self.install('--only', 'dotfiles', repo=clone)
        self.assertEqual((self.home / '.config/fish/config.fish').resolve(), clone / 'fish/.config/fish/config.fish')

    def test_fish_without_optional_tools(self):
        fish = shutil.which('fish')
        if not fish:
            self.skipTest('Fish fehlt')
        # Dedicated path prevents optional programs on the host from being initialized.
        bin_dir = self.base / 'bin'
        bin_dir.mkdir()
        for cmd in ['mkdir', 'uname', 'dirname', 'basename', 'cat']:
            path = shutil.which(cmd)
            if path:
                (bin_dir / cmd).symlink_to(path)
        self.env['PATH'] = str(bin_dir)
        code = 'source "$REPO_CONFIG"; source "$REPO_MKCD"; mkcd "project space"; test "$PWD" = "$EXPECTED"'
        self.env.update(REPO_CONFIG=str(REPO / 'fish/.config/fish/config.fish'),
                        REPO_MKCD=str(REPO / 'fish/.config/fish/functions/mkcd.fish'), EXPECTED=str(self.base / 'project space'))
        result = self.run_command([fish, '--no-config', '-c', code])
        self.assertEqual(result.stderr, '')

    def test_mocked_package_failure_is_propagated(self):
        self.env['REPO_DIR'] = str(REPO)
        result = self.run_command(['bash', '-c', '''
set -Eeuo pipefail
source "$REPO_DIR/scripts/common.sh"
source "$REPO_DIR/scripts/system.sh"
DRY_RUN=0 EXTRAS=''
sudo() { return 42; }
install_system
'''], success=False)
        self.assertEqual(result.returncode, 42)

    def test_fnm_recursive_project_switch(self):
        fish, fnm = shutil.which('fish'), shutil.which('fnm')
        if not fish or not fnm:
            self.skipTest('Fish/fnm fehlen')
        self.env['FNM_DIR'] = str(self.home / '.local/share/fnm')
        self.env['FNM_LOGLEVEL'] = 'error'
        for version in ['24.0.0', '22.0.0']:
            install = Path(self.env['FNM_DIR']) / 'node-versions' / ('v' + version) / 'installation'
            (install / 'bin').mkdir(parents=True)
            node = install / 'bin/node'
            node.write_text('#!/bin/sh\nprintf "v' + version + '\\n"\n')
            node.chmod(0o755)
        self.run_command([fnm, 'default', '24.0.0'])
        project = self.base / 'node project'
        (project / 'subdir').mkdir(parents=True)
        (project / '.node-version').write_text('22.0.0\n')
        self.env.update(REPO_CONFIG=str(REPO / 'fish/.config/fish/config.fish'),
                        NODE_PROJECT=str(project / 'subdir'), NEUTRAL_DIR=str(self.base))
        code = '''
source "$REPO_CONFIG"
test "$MISE_DISABLE_TOOLS" = node,python; or exit 1
fnm use default >/dev/null
test (node --version) = v24.0.0; or exit 2
cd "$NODE_PROJECT"
test (node --version) = v22.0.0; or exit 3
cd "$NEUTRAL_DIR"
test (node --version) = v24.0.0; or exit 4
'''
        self.run_command([fish, '--no-config', '-c', code])

    def test_tmux_configuration(self):
        tmux = shutil.which('tmux')
        if not tmux:
            self.skipTest('tmux fehlt')
        socket = str(self.base / 'tmux.sock')
        command = [tmux, '-S', socket, '-f', str(REPO / 'tmux/.config/tmux/tmux.conf')]
        try:
            self.run_command(command + ['new-session', '-d', '-s', 'config-test', '/bin/sleep 20'])
            prefix = self.run_command([tmux, '-S', socket, 'show-option', '-gv', 'prefix'])
            self.assertEqual(prefix.stdout.strip(), 'C-a')
            status = self.run_command([tmux, '-S', socket, 'show-option', '-gv', 'status'])
            self.assertEqual(status.stdout.strip(), 'off')
        finally:
            subprocess.run([tmux, '-S', socket, 'kill-server'], env=self.env, capture_output=True)

    def test_neovim_offline_startup(self):
        plugins = os.environ.get('DOTFILES_NVIM_PLUGINS')
        nvim = shutil.which('nvim')
        if not plugins or not nvim:
            self.skipTest('Optional: DOTFILES_NVIM_PLUGINS auf vorhandene vertrauenswürdige Plugin-Quellen setzen')
        self.env.update(DOTFILES_NVIM_CONFIG=str(REPO / 'nvim/.config/nvim/init.lua'),
                        NVIM_LOG_FILE=str(self.base / 'nvim.log'))
        self.run_command([nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '-l', str(REPO / 'tests/nvim_smoke.lua')])

    def test_wezterm_keymap(self):
        wezterm = os.environ.get('DOTFILES_WEZTERM_BINARY') or shutil.which('wezterm')
        if not wezterm:
            self.skipTest('WezTerm fehlt')
        result = self.run_command([wezterm, '--config-file', str(REPO / 'wezterm/.config/wezterm/wezterm.lua'), 'show-keys', '--lua'])
        self.assertIn('ActivateCopyMode', result.stdout)
        self.assertNotIn('pwsh.exe', result.stdout)


class ConfigTests(unittest.TestCase):
    def test_structured_configs(self):
        for path in REPO.rglob('*.json'):
            if '.git' not in path.parts:
                jsonc(path.read_text())
        for path in REPO.rglob('*.toml'):
            tomllib.loads(path.read_text())
        settings = jsonc((REPO / 'zed/.config/zed/settings.json').read_text())
        self.assertNotIn('terminal_init_command', settings.get('agent', {}))
        self.assertFalse(settings['languages']['TypeScript']['prettier']['allowed'])

    def test_secret_scanner_redaction(self):
        spec = importlib.util.spec_from_file_location('scanner', REPO / 'scripts/check-secrets.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        token = 'gh' + 'p_' + 'x' * 36
        self.assertEqual(module.scan_bytes(Path('config'), token.encode()), ['access token'])
        self.assertIn('private filename', module.scan_bytes(Path('id_ed25519'), b'test'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
