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

    # --- dot doctor -------------------------------------------------------

    DOCTOR_TOOLS = ('mise', 'nvim', 'node', 'uv', 'starship', 'tree-sitter', 'lazygit', 'rg', 'fd', 'fzf', 'bat',
                    'delta', 'shfmt', 'shellcheck', 'zsh', 'tmux', 'git', 'stow', 'podman')

    def setup_doctor(self, omit=(), nvim='NVIM v0.12.1', missing='', extra=()):
        bindir = self.base / 'fakebin'
        bindir.mkdir()
        self.log = self.base / 'calls.log'
        for tool in (*self.DOCTOR_TOOLS, *extra):
            if tool in omit or tool == 'git':
                continue
            version = nvim if tool == 'nvim' else f'{tool} 1.0.0'
            body = f'#!/bin/sh\necho "{tool} $*" >> "{self.log}"\n'
            if tool == 'mise':
                body += f'if [ "$1" = ls ]; then printf %s "{missing}"; exit 0; fi\n'
            if tool == 'shellcheck':
                version = 'ShellCheck\\nversion: 0.10.0'
            body += f'printf \'{version}\\n\'\n'
            (bindir / tool).write_text(body)
            (bindir / tool).chmod(0o755)
        for basic in ('bash', 'env', 'git', 'sed', 'sort', 'head', 'cat', 'mkdir', 'dirname', 'readlink',
                      'uname', 'rm', 'mktemp', 'tr', 'grep', 'id', 'stat', 'python3', 'awk', 'diff'):
            found = shutil.which(basic)
            if found and not (bindir / basic).exists():
                (bindir / basic).symlink_to(found)
        self.env['PATH'] = f'{self.home}/.local/bin:{bindir}'
        self.env.pop('WSL_DISTRO_NAME', None)
        self.env.pop('WSL_INTEROP', None)
        local = self.home / '.gitconfig-local'
        local.write_text('[user]\n\tname = T\n\temail = t@example.invalid\n')
        local.chmod(0o600)

    def snapshot(self):
        return sorted((str(p.relative_to(self.home)), p.stat().st_mtime_ns, p.is_symlink())
                      for p in self.home.rglob('*'))

    def test_doctor_healthy(self):
        self.setup_doctor()
        before = self.snapshot()
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('[FEHLER]', result.stdout)
        self.assertNotIn('[WARN]', result.stdout.replace('PATH enthält', ''))
        for line in ('Distro: fedora', 'nvim: NVIM v0.12.1', 'node: node 1.0.0', 'fzf: fzf 1.0.0',
                     'shellcheck: 0.10.0'):
            self.assertIn(line, result.stdout)
        self.assertEqual(self.snapshot(), before)
        self.assertNotIn('mise install', self.log.read_text())

    def test_doctor_missing_tool_fails(self):
        self.setup_doctor(omit=('lazygit',))
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  lazygit fehlt.', result.stdout)

    def test_doctor_missing_fzf_fails(self):
        self.setup_doctor(omit=('fzf',))
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  fzf fehlt.', result.stdout)

    def test_doctor_outdated_nvim_fails(self):
        self.setup_doctor(nvim='NVIM v0.11.4')
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  nvim 0.11.4 ist zu alt', result.stdout)

    def test_doctor_missing_mise_tools_fail(self):
        self.setup_doctor(missing='node  24.1.0  missing\n')
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  Fehlende mise-Tools', result.stdout)
        self.assertIn('node  24.1.0', result.stdout)

    def test_doctor_stow_conflict_fails_without_changes(self):
        self.setup_doctor()
        conflict = self.home / '.config/nvim/init.lua'
        conflict.parent.mkdir(parents=True)
        conflict.write_text('-- mine\n')
        before = self.snapshot()
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  Stow-Links', result.stdout)
        self.assertIn('Dateikonflikt: .config/nvim/init.lua', result.stdout)
        self.assertEqual(conflict.read_text(), '-- mine\n')
        self.assertEqual(self.snapshot(), before)

    def test_doctor_warns_on_fnm_and_git_identity(self):
        self.setup_doctor(extra=('fnm',))
        (self.home / '.gitconfig-local').chmod(0o644)
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('[WARN]    Legacy fnm', result.stdout)
        self.assertIn('[WARN]    ~/.gitconfig-local: Rechte 644', result.stdout)
        (self.home / '.gitconfig-local').unlink()
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('~/.gitconfig-local fehlt', result.stdout)

    def test_doctor_help_and_bad_option(self):
        self.assertIn('dot doctor', self.run_dot('--help').stdout)
        self.assertEqual(self.run_dot('doctor', '--help').returncode, 0)
        self.assertNotEqual(self.run_dot('doctor', '--bogus').returncode, 0)

    # --- dot zed-template -------------------------------------------------

    ZED_FILES = ('settings.json', 'tasks.json', 'debug.json')

    def test_zed_template_creates_files(self):
        for name in ('angular', 'django', 'dotnet'):
            with self.subTest(template=name):
                dest = self.base / f'proj {name}' / 'nested'
                result = self.run_dot('zed-template', name, str(dest))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                for f in self.ZED_FILES:
                    self.assertEqual((dest / '.zed' / f).read_bytes(),
                                     (REPO / 'zed-config/projects' / name / '.zed' / f).read_bytes())

    def test_zed_template_idempotent(self):
        dest = self.base / 'x'
        self.assertEqual(self.run_dot('zed-template', 'dotnet', str(dest)).returncode, 0)
        before = {f: (dest / '.zed' / f).stat().st_mtime_ns for f in self.ZED_FILES}
        result = self.run_dot('zed-template', '--backup', 'dotnet', str(dest))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sorted(p.name for p in (dest / '.zed').iterdir()), sorted(self.ZED_FILES))
        self.assertEqual(before, {f: (dest / '.zed' / f).stat().st_mtime_ns for f in self.ZED_FILES})

    def test_zed_template_dry_run_writes_nothing(self):
        dest = self.base / 'x'
        result = self.run_dot('zed-template', '--dry-run', 'django', str(dest))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Vorschau abgeschlossen', result.stdout)
        self.assertFalse(dest.exists())
        (dest / '.zed').mkdir(parents=True)
        (dest / '.zed/settings.json').write_text('mine')
        result = self.run_dot('zed-template', '--dry-run', '--backup', 'django', str(dest))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sorted(p.name for p in (dest / '.zed').iterdir()), ['settings.json'])
        self.assertEqual((dest / '.zed/settings.json').read_text(), 'mine')

    def test_zed_template_conflict_and_backup(self):
        dest = self.base / 'x'
        (dest / '.zed').mkdir(parents=True)
        (dest / '.zed/tasks.json').write_text('mine')
        result = self.run_dot('zed-template', 'angular', str(dest))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sorted(p.name for p in (dest / '.zed').iterdir()), ['tasks.json'])
        self.assertEqual((dest / '.zed/tasks.json').read_text(), 'mine')
        result = self.run_dot('zed-template', '--backup', 'angular', str(dest))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        backups = list((dest / '.zed').glob('tasks.json.bak-*'))
        self.assertEqual([b.read_text() for b in backups], ['mine'])
        self.assertEqual((dest / '.zed/tasks.json').read_bytes(),
                         (REPO / 'zed-config/projects/angular/.zed/tasks.json').read_bytes())
        self.assertTrue((dest / '.zed/settings.json').is_file())

    def test_zed_template_rejects_symlinks_and_non_directories(self):
        dest = self.base / 'x'
        (dest / '.zed').mkdir(parents=True)
        (dest / '.zed/settings.json').symlink_to(self.base / 'elsewhere')
        result = self.run_dot('zed-template', '--backup', 'dotnet', str(dest))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sorted(p.name for p in (dest / '.zed').iterdir()), ['settings.json'])
        link = self.base / 'y'
        (link).mkdir()
        (link / '.zed').symlink_to(self.base)
        self.assertNotEqual(self.run_dot('zed-template', 'dotnet', str(link)).returncode, 0)
        afile = self.base / 'file'
        afile.write_text('')
        self.assertNotEqual(self.run_dot('zed-template', 'dotnet', str(afile)).returncode, 0)

    def test_zed_template_invalid_arguments(self):
        self.assertIn('dot zed-template', self.run_dot('--help').stdout)
        self.assertEqual(self.run_dot('zed-template', '--help').returncode, 0)
        for args in [(), ('dotnet',), ('rails', 'x'), ('--bogus', 'dotnet', 'x'), ('dotnet', 'x', 'y')]:
            with self.subTest(args=args):
                self.assertNotEqual(self.run_dot('zed-template', *args).returncode, 0)
        self.assertFalse((self.base / 'x').exists())

    def test_unknown_subcommand_fails_cleanly(self):
        result = self.run_dot('unknown-cmd')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unbekannter Befehl', result.stderr)


if __name__ == '__main__':
    unittest.main()
