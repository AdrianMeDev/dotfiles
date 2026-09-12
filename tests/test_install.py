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
        self.env.pop('ZDOTDIR', None)

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
        self.assertTrue((self.home / '.config/zsh/.zshrc').is_symlink())
        self.assertTrue((self.home / '.zshenv').is_symlink())
        self.assertFalse((self.home / '.config').is_symlink())
        self.assertFalse((self.home / '.config/nvim').is_symlink())
        before = snapshot(self.home)
        self.install('--only', 'dotfiles')
        self.assertEqual(snapshot(self.home), before)

    def test_conflicts_stop_before_changes_and_backup_restores_bytes(self):
        self.require_stow()
        config = self.home / '.config/zsh/.zshrc'
        config.parent.mkdir(parents=True)
        config.write_text('custom zsh setting\n')
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
        self.assertEqual((backups[0] / '.config/zsh/.zshrc').read_text(), 'custom zsh setting\n')
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
        self.assertEqual((self.home / '.config/zsh/.zshrc').resolve(), clone / 'zsh/.config/zsh/.zshrc')

    def prepare_zsh(self):
        zsh = shutil.which('zsh')
        if not zsh:
            self.skipTest('zsh fehlt')
        config = self.home / '.config/zsh'
        config.mkdir(parents=True, exist_ok=True)
        for source in (REPO / 'zsh/.config/zsh').iterdir():
            (config / source.name).symlink_to(source)
        (self.home / '.zshenv').symlink_to(REPO / 'zsh/.zshenv')
        return zsh

    def test_zsh_without_optional_tools(self):
        zsh = self.prepare_zsh()
        bin_dir = self.base / 'bin'
        bin_dir.mkdir()
        for cmd in ['mkdir', 'uname', 'dirname', 'basename', 'cat', 'rm', 'mv', 'chmod']:
            executable = shutil.which(cmd)
            if executable:
                (bin_dir / cmd).symlink_to(executable)
        self.env['PATH'] = str(bin_dir)
        self.env['EXPECTED'] = str(self.base / 'project space')
        for flags, code in [('-c', '[[ $MISE_DISABLE_TOOLS = node,python ]]'),
                            ('-ic', 'mkcd "project space" && [[ $PWD = $EXPECTED ]]')]:
            result = self.run_command([zsh, flags, code])
            self.assertEqual(result.stderr, '')
            self.assertEqual(result.stdout, '')
        self.assertFalse((self.home / '.local/share/zsh/plugins').exists())

    def test_fish_migration_preserves_private_and_foreign_files(self):
        self.require_stow()
        config = self.home / '.config/fish'
        (config / 'functions').mkdir(parents=True)
        own = config / 'config.fish'
        own.symlink_to(REPO / 'fish/.config/fish/config.fish')
        relative = config / 'functions/mkcd.fish'
        relative.symlink_to(os.path.relpath(REPO / 'fish/.config/fish/functions/mkcd.fish', relative.parent))
        foreign = config / 'functions/fe.fish'
        foreign.symlink_to(self.base / 'other-checkout/fe.fish')
        for name in ['local.fish', 'fish_variables', 'functions/tp.fish']:
            (config / name).write_text('private data\n')
        external = self.base / 'external-conf'
        external.mkdir()
        (config / 'conf.d').symlink_to(external, target_is_directory=True)
        (external / 'fnm.fish').symlink_to(REPO / 'fish/.config/fish/conf.d/fnm.fish')
        before = snapshot(self.home)
        self.install('--only', 'dotfiles', '--dry-run')
        self.assertEqual(snapshot(self.home), before)
        (self.home / '.zshenv').write_text('custom bootstrap\n')
        self.install('--only', 'dotfiles', success=False)
        self.assertTrue(own.is_symlink())
        self.install('--only', 'dotfiles', '--backup')
        self.assertFalse(own.is_symlink())
        self.assertFalse(relative.is_symlink())
        self.assertTrue(foreign.is_symlink())
        self.assertTrue((external / 'fnm.fish').is_symlink())
        for name in ['local.fish', 'fish_variables', 'functions/tp.fish']:
            self.assertEqual((config / name).read_text(), 'private data\n')
        before = snapshot(self.home)
        self.install('--only', 'dotfiles')
        self.assertEqual(snapshot(self.home), before)

    def test_zsh_runtime_order_and_local_overrides(self):
        zsh = self.prepare_zsh()
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True)
        scripts = {
            'mise': "printf 'typeset -ga runtime_order; runtime_order+=(mise)\\n'\n",
            'fnm': "printf 'runtime_order+=(fnm)\\n'\n",
            'git': 'exit 99\n',
        }
        for name, body in scripts.items():
            executable = bin_dir / name
            executable.write_text('#!/bin/sh\n' + body)
            executable.chmod(0o755)
        (self.home / '.config/zsh/local.zsh').write_text('runtime_order+=(local)\n')
        for cmd in ['mkdir', 'rm', 'mv', 'cat', 'chmod']:
            (bin_dir / cmd).symlink_to(shutil.which(cmd))
        self.env['PATH'] = str(bin_dir)
        for flag in ['-c', '-ic']:
            result = self.run_command([zsh, flag, 'print -r -- "${(j:,:)runtime_order}"'])
            self.assertEqual(result.stdout.strip(), 'mise,fnm,local')
            self.assertEqual(result.stderr, '')
        self.assertFalse((self.home / '.local/share/zsh/plugins').exists())

    def test_zsh_helpers_handle_special_paths_and_errors(self):
        zsh = self.prepare_zsh()
        self.env['HELPERS'] = str(REPO / 'zsh/.config/zsh/functions.zsh')
        project = self.base / 'project [x] with spaces'
        project.mkdir()
        self.run_command(['git', 'init', '-q', str(project)])
        (project / 'subdir').mkdir()
        self.env['PROJECT'] = str(project)
        code = '''
source "$HELPERS"
mkcd >/dev/null 2>&1; [[ $? = 2 ]] || exit 1
mkcd 'new [x] directory' || exit 2
[[ $PWD = */'new [x] directory' ]] || exit 3
croot >/dev/null 2>&1; [[ $? = 1 ]] || exit 4
cd "$PROJECT/subdir"
croot && [[ $PWD = $PROJECT ]] || exit 5
tp a b >/dev/null 2>&1; [[ $? = 2 ]] || exit 6
'''
        self.run_command([zsh, '-f', '-c', code])
        bin_dir = self.base / 'bin'
        bin_dir.mkdir()
        filename = 'file [a] $x\nwith newline.txt'
        self.env['SELECTED'] = filename
        self.env['OUTPUT'] = str(self.base / 'editor-args')
        self.env['EDITOR'] = '"' + str(bin_dir / 'editor with space') + '" --wait'
        scripts = {
            'rg': 'printf "%s\\0" "$SELECTED"\n',
            'fzf': 'exec /bin/cat\n',
            'editor with space': 'printf "%s\\0" "$@" > "$OUTPUT"\n',
            'tmux': 'printf "%s\\0" "$@" > "$OUTPUT"\n',
        }
        for name, body in scripts.items():
            executable = bin_dir / name
            executable.write_text('#!/bin/sh\n' + body)
            executable.chmod(0o755)
        self.env['PATH'] = str(bin_dir) + ':' + self.env['PATH']
        self.run_command([zsh, '-f', '-c', 'source "$HELPERS"; fe'])
        self.assertEqual(Path(self.env['OUTPUT']).read_bytes().split(b'\0')[:-1],
                         [b'--wait', b'--', filename.encode()])
        self.run_command([zsh, '-f', '-c', 'source "$HELPERS"; tp "$PROJECT"'])
        args = Path(self.env['OUTPUT']).read_bytes().split(b'\0')[:-1]
        self.assertEqual(args[:3], [b'new-session', b'-A', b'-s'])
        self.assertRegex(args[3].decode(), r'^project__x__with_spaces-[0-9a-f]{8}$')
        self.assertEqual(args[-1].decode(), str(project))
        self.env['TMUX'] = 'test'
        self.run_command([zsh, '-f', '-c', 'source "$HELPERS"; tp "$PROJECT"'])
        self.assertEqual(Path(self.env['OUTPUT']).read_bytes().split(b'\0')[0], b'switch-client')
        (bin_dir / 'fzf').write_text('#!/bin/sh\nexit 130\n')
        Path(self.env['OUTPUT']).unlink()
        self.run_command([zsh, '-f', '-c', 'source "$HELPERS"; fe'])
        self.assertFalse(Path(self.env['OUTPUT']).exists())

    def test_zsh_plugins_install_update_and_retry_offline(self):
        zsh = self.prepare_zsh()
        plugins = ['zsh-users/zsh-autosuggestions', 'zsh-users/zsh-history-substring-search',
                   'jeffreytse/zsh-vi-mode', 'zdharma-continuum/fast-syntax-highlighting']
        remotes = self.base / 'remotes'
        self.env['GIT_CONFIG_GLOBAL'] = str(self.base / 'git-test-config')
        self.env['GIT_AUTHOR_NAME'] = self.env['GIT_COMMITTER_NAME'] = 'Test'
        self.env['GIT_AUTHOR_EMAIL'] = self.env['GIT_COMMITTER_EMAIL'] = 'test@example.invalid'
        self.run_command(['git', 'config', '--global', f'url.{remotes.as_uri()}/.insteadOf', 'https://github.com/'])
        for plugin in plugins:
            source = remotes / plugin
            self.run_command(['git', 'init', '-q', str(source)])
            (source / (source.name + '.plugin.zsh')).write_text('# offline plugin fixture\n')
            if source.name == 'fast-syntax-highlighting':
                (source / 'share').mkdir()
                (source / 'share/free_theme.zsh').write_text('# local theme fixture\n')
            self.run_command(['git', '-C', str(source), 'add', '.'])
            self.run_command(['git', '-C', str(source), 'commit', '-qm', 'initial'])
        self.env['PLUGIN_MODULE'] = str(REPO / 'zsh/.config/zsh/plugins.zsh')
        self.env['XDG_DATA_HOME'] = str(self.home / 'custom data')
        code = 'source "$PLUGIN_MODULE"; _dotfiles_zplugins=(missing/plugin); zplugin-install'
        self.run_command([zsh, '-f', '-c', code], success=False)
        installed = Path(self.env['XDG_DATA_HOME']) / 'zsh/plugins'
        self.assertEqual(list(installed.iterdir()), [])
        self.run_command([zsh, '-f', '-c', 'source "$PLUGIN_MODULE"; zplugin-install'])
        before = snapshot(installed)
        self.run_command([zsh, '-f', '-c', 'source "$PLUGIN_MODULE"; zplugin-install'])
        self.assertEqual(snapshot(installed), before)
        source = remotes / plugins[0]
        (source / 'new-file').write_text('updated')
        self.run_command(['git', '-C', str(source), 'add', '.'])
        self.run_command(['git', '-C', str(source), 'commit', '-qm', 'update'])
        self.run_command([zsh, '-f', '-c', 'source "$PLUGIN_MODULE"; zplugin-update'])
        self.assertEqual((installed / source.name / 'new-file').read_text(), 'updated')
        local = installed / source.name
        (local / 'local-file').write_text('keep this')
        self.run_command(['git', '-C', str(local), 'add', '.'])
        self.run_command(['git', '-C', str(local), 'commit', '-qm', 'local change'])
        (source / 'remote-file').write_text('remote change')
        self.run_command(['git', '-C', str(source), 'add', '.'])
        self.run_command(['git', '-C', str(source), 'commit', '-qm', 'remote change'])
        self.run_command([zsh, '-f', '-c', 'source "$PLUGIN_MODULE"; zplugin-update'], success=False)
        self.assertEqual((local / 'local-file').read_text(), 'keep this')
        self.assertFalse((local / 'remote-file').exists())

    def test_zsh_fzf_quotes_selection_and_ignores_cancellation(self):
        zsh = self.prepare_zsh()
        bin_dir = self.base / 'bin'
        bin_dir.mkdir()
        self.env['SELECTED'] = 'file [x] $name\nsecond line'
        self.env['FZF_MODULE'] = str(REPO / 'zsh/.config/zsh/fzf.zsh')
        for name, body in {
            'fzf': 'if [ "$1" = --zsh ]; then exit 0; fi\nexec /bin/cat\n',
            'fd': 'printf "%s\\0" "$SELECTED"\n',
        }.items():
            executable = bin_dir / name
            executable.write_text('#!/bin/sh\n' + body)
            executable.chmod(0o755)
        self.env['PATH'] = str(bin_dir)
        code = '''
source "$FZF_MODULE"
zle() { :; }
LBUFFER=''
_fzf_file_no_hidden
eval "set -- $LBUFFER"
[[ $# = 1 && $1 = $SELECTED ]]
'''
        self.run_command([zsh, '-f', '-c', code])
        (bin_dir / 'fzf').write_text('#!/bin/sh\nif [ "$1" = --zsh ]; then exit 0; fi\nexit 130\n')
        self.run_command([zsh, '-f', '-c', '''
source "$FZF_MODULE"
zle() { :; }
LBUFFER='keep this'
_fzf_file_no_hidden
[[ $LBUFFER = 'keep this' ]]
'''])

    def test_zsh_bindings_survive_vi_initialization(self):
        zsh = self.prepare_zsh()
        self.env['BINDINGS'] = str(REPO / 'zsh/.config/zsh/bindings.zsh')
        code = r'''
noop() { :; }
for widget in fzf-history-widget fzf-file-widget _fzf_file_no_hidden autosuggest-toggle history-substring-search-up history-substring-search-down; do
  zle -N "$widget" noop
done
source "$BINDINGS"
bindkey -M viins '^R' history-incremental-search-backward
zvm_after_init
for key in '^R' '^T' '^F' '^\' '^[[A' '^[[B' '^[[1;5C' '^[[1;5D'; do
  bindkey -M viins "$key"
done
'''
        result = self.run_command([zsh, '-f', '-ic', code])
        for widget in ['fzf-history-widget', 'fzf-file-widget', '_fzf_file_no_hidden',
                       'autosuggest-toggle', 'history-substring-search-up',
                       'history-substring-search-down', 'forward-word', 'backward-word']:
            self.assertIn(widget, result.stdout)

    def test_zsh_real_plugins_offline_startup(self):
        plugins = os.environ.get('DOTFILES_ZSH_PLUGINS')
        if not plugins:
            self.skipTest('Optional: DOTFILES_ZSH_PLUGINS auf vorhandene Plugin-Quellen setzen')
        zsh = self.prepare_zsh()
        installed = self.home / '.local/share/zsh/plugins'
        shutil.copytree(plugins, installed, ignore=shutil.ignore_patterns('.git'))
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True)
        self.env['NETWORK_LOG'] = str(self.base / 'network-log')
        for name in ['git', 'curl', 'wget']:
            executable = bin_dir / name
            executable.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$NETWORK_LOG"\nexit 99\n')
            executable.chmod(0o755)
        before = snapshot(REPO / 'zsh')
        code = r'''
zvm_init
[[ $ZVM_INSERT_MODE_CURSOR = $ZVM_CURSOR_BEAM ]] || exit 1
[[ $ZVM_NORMAL_MODE_CURSOR = $ZVM_CURSOR_BLOCK ]] || exit 2
(( $+widgets[autosuggest-toggle] && $+widgets[history-substring-search-up] )) || exit 3
(( $+functions[_zsh_highlight] )) || exit 4
bindkey -M viins '^R'
bindkey -M viins '^[[A'
bindkey -M viins '^\'
'''
        master, slave = pty.openpty()
        try:
            result = subprocess.run([zsh, '-ic', code], cwd=self.base, env=self.env,
                                    stdin=slave, capture_output=True, text=True, timeout=30)
        finally:
            os.close(slave)
            os.close(master)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertIn('history-substring-search-up', result.stdout)
        self.assertIn('autosuggest-toggle', result.stdout)
        if shutil.which('fzf'):
            self.assertIn('fzf-history-widget', result.stdout)
        self.assertFalse(Path(self.env['NETWORK_LOG']).exists())
        self.assertTrue((self.home / '.cache/zsh/fsh/secondary_theme.zsh').is_file())
        self.assertEqual(snapshot(REPO / 'zsh'), before)

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

    def test_fedora_wsl_system_upgrade_keeps_windows_kernel(self):
        self.env['REPO_DIR'] = str(REPO)
        self.env['WSL_INTEROP'] = '/run/WSL/interop'
        self.env['WSL_LOG'] = str(self.base / 'wsl-commands')
        result = self.run_command(['bash', '-c', '''
set -Eeuo pipefail
source "$REPO_DIR/scripts/common.sh"
source "$REPO_DIR/scripts/system.sh"
DRY_RUN=0 EXTRAS=''
sudo() { printf '%s\\n' "$*" >> "$WSL_LOG"; }
install_manifest() { printf 'install:%s\\n' "$*" >> "$WSL_LOG"; }
install_system
'''])
        commands = Path(self.env['WSL_LOG']).read_text().splitlines()
        self.assertEqual(commands[0], 'dnf upgrade --refresh -y --exclude=kernel*')
        self.assertEqual(commands[1], 'install:system.txt')
        self.assertIn('WSL erkannt', result.stdout)

    def test_fedora_wsl_dry_run_reports_kernel_exclusion(self):
        self.env['REPO_DIR'] = str(REPO)
        self.env['WSL_DISTRO_NAME'] = 'Fedora'
        result = self.run_command(['bash', '-c', '''
set -Eeuo pipefail
source "$REPO_DIR/scripts/common.sh"
source "$REPO_DIR/scripts/system.sh"
DRY_RUN=1 EXTRAS=''
install_system
'''])
        self.assertIn('--exclude=kernel\\*', result.stdout)

    def test_fnm_recursive_project_switch(self):
        zsh, fnm = self.prepare_zsh(), shutil.which('fnm')
        if not fnm:
            self.skipTest('fnm fehlt')
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
        self.env.update(NODE_PROJECT=str(project / 'subdir'), NEUTRAL_DIR=str(self.base))
        code = '''
[[ $MISE_DISABLE_TOOLS = node,python ]] || exit 1
fnm use default >/dev/null
[[ $(node --version) = v24.0.0 ]] || exit 2
cd "$NODE_PROJECT"
[[ $(node --version) = v22.0.0 ]] || exit 3
cd "$NEUTRAL_DIR"
[[ $(node --version) = v24.0.0 ]] || exit 4
'''
        self.run_command([zsh, '-c', code])

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
            if Path('/usr/bin/zsh').is_file():
                shell = self.run_command([tmux, '-S', socket, 'show-option', '-gv', 'default-shell'])
                self.assertEqual(shell.stdout.strip(), '/usr/bin/zsh')
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
