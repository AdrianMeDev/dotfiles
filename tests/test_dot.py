#!/usr/bin/env python3
"""Tests for the dot CLI entrypoint and its Stow package."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
CORNE_RULE = ('KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="vial:f64c2b3c", MODE="0660", '
              'GROUP="users", TAG+="uaccess", TAG+="udev-acl"\n')
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

    def setup_agent_update(self, family='fedora', tools=('claude', 'pi', 'ollama'), fail=None):
        self.setup_update(family, tools=('sudo', 'dnf', 'pacman', 'mise', *tools), fail=fail)
        bindir = self.base / 'fakebin'
        curl = bindir / 'curl'
        curl.write_text('#!/bin/sh\nwhile [ $# -gt 0 ]; do\n  if [ "$1" = --output ]; then out=$2; fi\n  shift\ndone\n'
                        f'printf \'echo "ollama-installer" >> "{self.log}"\\n\' > "$out"\n')
        curl.chmod(0o755)
        (bindir / 'sh').symlink_to(shutil.which('sh'))
        self.tmpdir = self.base / 'tmp'
        self.tmpdir.mkdir(exist_ok=True)
        self.env['TMPDIR'] = str(self.tmpdir)

    def test_update_agents(self):
        self.setup_agent_update()
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls()
        self.assertIn('claude update', calls)
        self.assertIn('mise exec -- npm install -g @earendil-works/pi-coding-agent@latest', calls)
        self.assertIn('mise reshim', calls)
        self.assertIn('ollama-installer', calls)
        self.assertEqual(list(self.tmpdir.iterdir()), [])

    def test_update_agents_skips_absent_and_arch_ollama(self):
        self.setup_agent_update(tools=())
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse([c for c in self.calls() if c.startswith(('claude', 'ollama', 'mise exec', 'mise reshim'))])
        self.log.unlink()
        shutil.rmtree(self.base / 'fakebin')
        self.setup_agent_update('arch', tools=('ollama',))
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('ollama-installer', self.calls())

    def test_update_agents_dry_run(self):
        self.setup_agent_update()
        result = self.run_dot('update', '--dry-run', '--profile', 'headless')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [])
        for step in ('claude update', '@earendil-works/pi-coding-agent@latest', 'mise reshim',
                     'https://ollama.com/install.sh'):
            self.assertIn(step, result.stdout)

    def test_update_agent_failure_propagates(self):
        self.setup_agent_update(fail='claude')
        result = self.run_dot('update', '--profile', 'headless')
        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
        self.assertEqual(list(self.tmpdir.iterdir()), [])

    def test_update_help_and_bad_option(self):
        result = self.run_dot('update', '--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('dot update', result.stdout)
        self.assertNotEqual(self.run_dot('update', '--bogus').returncode, 0)
        self.assertNotEqual(self.run_dot('update', '--profile', 'x').returncode, 0)

    # --- dot doctor -------------------------------------------------------

    DOCTOR_TOOLS = ('mise', 'nvim', 'node', 'uv', 'starship', 'tree-sitter', 'lazygit', 'rg', 'fd', 'fzf', 'bat',
                    'delta', 'shfmt', 'shellcheck', 'eza', 'yazi', 'tldr', 'just', 'lazydocker',
                    'zsh', 'tmux', 'git', 'stow', 'podman', 'claude', 'pi', 'ollama')

    def setup_doctor(self, omit=(), nvim='NVIM v0.12.1', missing='', extra=(), agents=True):
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
        # Pin the headless profile regardless of the host session.
        for var in ('WAYLAND_DISPLAY', 'DISPLAY', 'XDG_CURRENT_DESKTOP', 'XDG_SESSION_TYPE', 'HYPRLAND_INSTANCE_SIGNATURE'):
            self.env.pop(var, None)
        self.env['container'] = 'podman'
        local = self.home / '.gitconfig-local'
        local.write_text('[user]\n\tname = T\n\temail = t@example.invalid\n')
        local.chmod(0o600)
        if agents:
            subprocess.run(['python3', str(REPO / 'scripts/agents.py')], env=self.env, check=True,
                           capture_output=True, stdin=subprocess.DEVNULL)

    def agent_files(self):
        return sorted(p for p in self.home.rglob('*') if p.is_file() and p.name != '.gitconfig-local')

    def test_doctor_agent_tools(self):
        self.setup_doctor(omit=('claude', 'pi', 'ollama'))
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  claude fehlt.', result.stdout)
        self.assertIn('[FEHLER]  pi fehlt.', result.stdout)
        self.assertIn('[WARN]    ollama fehlt (optional).', result.stdout)

    def test_doctor_ollama_optional(self):
        self.setup_doctor(omit=('ollama',))
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('[WARN]    ollama fehlt (optional).', result.stdout)

    def test_doctor_extra_tools_missing(self):
        self.setup_doctor(omit=('eza', 'yazi', 'tldr', 'just', 'lazydocker'))
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        for label in ('eza', 'yazi', 'tealdeer', 'just', 'lazydocker'):
            self.assertIn(f'[FEHLER]  {label} fehlt.', result.stdout)

    def test_doctor_agent_config_ok_missing_modified(self):
        self.setup_doctor()
        result = self.run_dot('doctor')
        self.assertIn('[OK]      Agent-Config: stimmt', result.stdout)
        files = self.agent_files()
        self.assertTrue(files)
        modified = files[0]
        modified.write_text('# local\n')
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('[WARN]    Agent-Config: lokal abweichende', result.stdout)
        self.assertEqual(modified.read_text(), '# local\n')
        missing = files[-1]
        missing.unlink()
        before = self.snapshot()
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  Agent-Config: Dateien fehlen', result.stdout)
        self.assertFalse(missing.exists())
        self.assertEqual(modified.read_text(), '# local\n')
        self.assertEqual(self.snapshot(), before)

    def test_doctor_reports_foreign_skill_as_hint(self):
        self.setup_doctor()
        (self.home / '.claude/skills/inbox').mkdir(parents=True)
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('[WARN]    Agent-Config: Skills nicht aus dem Repo', result.stdout)
        self.assertIn('[foreign] claude: skills/inbox', result.stdout)

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

    def desktop_doctor(self, vial=True, rule=None, setup=True, binary='vial'):
        if setup:
            self.setup_doctor(extra=(binary,) if vial else ())
            self.env.pop('container')
            self.env['WAYLAND_DISPLAY'] = 'wayland-0'
            self.env['VIAL_UDEV_RULE'] = str(self.base / '99-vial.rules')
        if rule is not None:
            (self.base / '99-vial.rules').write_text(rule)
        before = self.snapshot()
        result = self.run_dot('doctor')
        self.assertEqual(self.snapshot(), before)
        return result

    def test_doctor_corne_desktop_ok(self):
        result = self.desktop_doctor(rule=CORNE_RULE)
        self.assertIn('[OK]      Vial vorhanden.', result.stdout)
        self.assertIn(f'[OK]      Vial-udev-Regel: {self.base}/99-vial.rules', result.stdout)

    def test_doctor_corne_desktop_accepts_capitalised_vial(self):
        result = self.desktop_doctor(rule=CORNE_RULE, binary='Vial')
        self.assertIn('[OK]      Vial vorhanden.', result.stdout)

    def test_doctor_corne_desktop_warns(self):
        result = self.desktop_doctor(vial=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('[WARN]    Vial fehlt', result.stdout)
        self.assertIn('[WARN]    Vial-udev-Regel fehlt', result.stdout)
        result = self.desktop_doctor(rule='# custom\n', setup=False)
        self.assertIn('[WARN]    Vial-udev-Regel weicht ab', result.stdout)

    def test_doctor_corne_headless_is_silent(self):
        self.setup_doctor()
        result = self.run_dot('doctor')
        self.assertNotIn('Vial', result.stdout)

    def fake_hyprland(self, version='0.57.0', verify=True, verify_rc=0):
        """Install stub hyprland (and waybar) binaries into the doctor fakebin."""
        bindir = self.base / 'fakebin'
        help_text = 'Usage: Hyprland [arg [...]].\\n  --verify-config' if verify else 'Usage: Hyprland'
        script = (
            '#!/bin/sh\n'
            f'echo "hyprland $*" >> "{self.log}"\n'
            'case "$1" in\n'
            f'  --version) echo "Hyprland {version} built from branch main";;\n'
            f'  --help) printf "{help_text}\\n";;\n'
            f'  --verify-config) echo "config error line 3"; exit {verify_rc};;\n'
            'esac\n'
        )
        (bindir / 'hyprland').write_text(script)
        (bindir / 'hyprland').chmod(0o755)
        (bindir / 'waybar').write_text('#!/bin/sh\necho "Waybar v0.12.0"\n')
        (bindir / 'waybar').chmod(0o755)

    def link_hypr_lua(self):
        lua = self.home / '.config/hypr/hyprland.lua'
        lua.parent.mkdir(parents=True, exist_ok=True)
        lua.write_text('-- stub\n')

    def test_doctor_skips_desktop_without_hyprland_on_headless(self):
        self.setup_doctor()
        result = self.run_dot('doctor')
        self.assertNotIn('hyprland', result.stdout.lower())

    def test_doctor_lists_missing_desktop_tools_on_desktop_profile(self):
        self.setup_doctor()
        for var in ('container',):
            self.env.pop(var, None)
        self.env['WAYLAND_DISPLAY'] = 'wayland-0'
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Profil: desktop', result.stdout)
        self.assertIn('[WARN]    Desktop-Tools fehlen: hyprland waybar', result.stdout)

    def test_doctor_reports_hyprland_and_waybar_versions(self):
        self.setup_doctor()
        self.fake_hyprland()
        result = self.run_dot('doctor')
        self.assertIn('[OK]      hyprland: Hyprland 0.57.0', result.stdout)
        self.assertIn('[OK]      waybar: Waybar v0.12.0', result.stdout)
        self.assertNotIn('älter als', result.stdout)
        self.assertIn('[WARN]    Desktop-Tools fehlen: fuzzel mako', result.stdout)

    def test_doctor_checks_polkit_agent(self):
        self.setup_doctor()
        self.fake_hyprland()
        agent = self.base / 'polkit-agent'
        agent.write_text('#!/bin/sh\n')
        agent.chmod(0o755)
        self.env['DOT_POLKIT_AGENTS'] = f'{self.base}/missing-agent:{agent}'
        self.assertIn(f'[OK]      Polkit-Agent: {agent}', self.run_dot('doctor').stdout)
        self.env['DOT_POLKIT_AGENTS'] = f'{self.base}/missing-agent'
        self.assertIn('[WARN]    Polkit-Agent fehlt', self.run_dot('doctor').stdout)

    def test_doctor_checks_secret_service(self):
        self.setup_doctor()
        self.fake_hyprland()
        self.assertIn('[WARN]    Secret Service fehlt', self.run_dot('doctor').stdout)
        keyring = self.base / 'fakebin/gnome-keyring-daemon'
        keyring.write_text('#!/bin/sh\n')
        keyring.chmod(0o755)
        self.assertIn('[OK]      Secret Service: gnome-keyring vorhanden.', self.run_dot('doctor').stdout)

    def test_doctor_warns_on_old_hyprland_and_leftover_conf(self):
        self.setup_doctor()
        self.fake_hyprland(version='0.56.2')
        conf = self.home / '.config/hypr/hyprland.conf'
        conf.parent.mkdir(parents=True)
        conf.write_text('# old\n')
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('[WARN]    Hyprland 0.56.2 ist älter als 0.57', result.stdout)
        self.assertIn('[WARN]    ~/.config/hypr/hyprland.conf ist ein Überrest', result.stdout)
        self.assertEqual(conf.read_text(), '# old\n')

    def test_doctor_verifies_lua_config(self):
        self.setup_doctor()
        self.fake_hyprland()
        self.link_hypr_lua()
        result = self.run_dot('doctor')
        self.assertIn('[OK]      Hyprland-Konfiguration: hyprland --verify-config', result.stdout)
        self.assertIn('hyprland --verify-config --config', self.log.read_text())

    def test_doctor_reports_lua_config_errors(self):
        self.setup_doctor()
        self.fake_hyprland(verify_rc=1)
        self.link_hypr_lua()
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  Hyprland-Konfiguration: hyprland --verify-config meldet Fehler', result.stdout)
        self.assertIn('config error line 3', result.stdout)

    def test_doctor_falls_back_to_hyprctl_configerrors(self):
        self.setup_doctor()
        self.fake_hyprland(verify=False)
        self.link_hypr_lua()
        hyprctl = self.base / 'fakebin' / 'hyprctl'
        hyprctl.write_text('#!/bin/sh\necho "Error: bindings.lua:7: bad"\n')
        hyprctl.chmod(0o755)
        result = self.run_dot('doctor')
        self.assertNotIn('--verify-config ohne', result.stdout)
        self.assertNotIn('hyprctl configerrors', result.stdout)
        self.env['HYPRLAND_INSTANCE_SIGNATURE'] = 'abc'
        result = self.run_dot('doctor')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[FEHLER]  Hyprland-Konfiguration: hyprctl configerrors meldet Fehler', result.stdout)
        self.assertIn('bindings.lua:7: bad', result.stdout)

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
