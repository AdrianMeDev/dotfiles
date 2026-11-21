#!/usr/bin/env python3
"""Offline tests for bootstrap.sh with a local source repository and stubbed system commands."""
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'bootstrap.sh'
BASH = shutil.which('bash') or '/bin/bash'

DOT_STUB = '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$DOT_LOG"\n'


def write_exe(path: Path, body: str) -> None:
    path.write_text(body if body.startswith('#!') else f'#!/usr/bin/env bash\n{body}\n')
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def snapshot(root: Path) -> list[str]:
    return sorted(str(p.relative_to(root)) for p in root.rglob('*'))


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-boot-')
        self.base = Path(self.temp.name)
        self.home = self.base / 'home'
        self.home.mkdir()
        self.target = self.home / 'dotfiles'
        self.dot_log = self.base / 'dot.log'
        self.source = self.base / 'source'
        dot = self.source / 'dot/.local/bin/dot'
        dot.parent.mkdir(parents=True)
        write_exe(dot, DOT_STUB)
        for cmd in (['init', '-q'], ['add', '.'],
                    ['-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-q', '-m', 'init']):
            subprocess.run(['git', '-C', str(self.source), *cmd], check=True, capture_output=True)

    def tearDown(self):
        self.temp.cleanup()

    def env(self, **extra):
        env = {k: v for k, v in os.environ.items() if k not in ('EUID',)}
        env.update(HOME=str(self.home), DOT_LOG=str(self.dot_log), GIT_CONFIG_GLOBAL=os.devnull)
        env.update(extra)
        return env

    def run_boot(self, *args, **env_extra):
        return subprocess.run([BASH, str(SCRIPT), *args], env=self.env(**env_extra), stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=60)

    def head(self):
        return subprocess.run(['git', '-C', str(self.target), 'rev-parse', 'HEAD'],
                              capture_output=True, text=True, check=True).stdout.strip()

    def test_dry_run_writes_nothing(self):
        before = snapshot(self.home)
        r = self.run_boot('--dry-run', '--repo', str(self.source), '--profile', 'headless')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(snapshot(self.home), before)
        self.assertFalse(self.dot_log.exists())
        self.assertIn('--profile headless', r.stdout)

    def test_fresh_clone_runs_dot_install_with_forwarded_args(self):
        r = self.run_boot('--repo', str(self.source), '--profile', 'headless', '--backup')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.target / '.git').exists())
        self.assertEqual(self.dot_log.read_text().strip(), 'install --profile headless --backup')

    def test_piped_bootstrap_preview_install_and_repeat(self):
        def piped_boot(*args):
            return subprocess.run(
                [BASH, '-s', '--', '--repo', str(self.source), *args],
                input=SCRIPT.read_text(), env=self.env(), capture_output=True,
                text=True, timeout=60,
            )

        before = snapshot(self.home)
        preview = piped_boot('--dry-run')
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertEqual(snapshot(self.home), before)
        self.assertFalse(self.dot_log.exists())

        first = piped_boot('--profile', 'headless')
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertTrue((self.target / '.git').is_dir())
        # Compare all clone contents, including Git metadata, across the second run.
        before = {str(p.relative_to(self.target)): p.read_bytes()
                  for p in self.target.rglob('*') if p.is_file()}
        second = piped_boot('--profile', 'headless')
        self.assertEqual(second.returncode, 0, second.stderr)
        after = {str(p.relative_to(self.target)): p.read_bytes()
                 for p in self.target.rglob('*') if p.is_file()}
        self.assertEqual(after, before)
        self.assertEqual(self.dot_log.read_text().splitlines(),
                         ['install --profile headless'] * 2)

    def test_custom_dir_and_branch(self):
        subprocess.run(['git', '-C', str(self.source), 'branch', 'feature'], check=True)
        target = self.base / 'elsewhere'
        r = self.run_boot('--repo', str(self.source), '--dir', str(target), '--branch', 'feature')
        self.assertEqual(r.returncode, 0, r.stderr)
        branch = subprocess.run(['git', '-C', str(target), 'branch', '--show-current'],
                                capture_output=True, text=True, check=True).stdout.strip()
        self.assertEqual(branch, 'feature')

    def test_repeat_run_leaves_repository_untouched(self):
        self.assertEqual(self.run_boot('--repo', str(self.source)).returncode, 0)
        (self.target / 'local.txt').write_text('mine')
        head = self.head()
        before = snapshot(self.target / '.git')
        r = self.run_boot('--repo', str(self.source))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.head(), head)
        self.assertEqual((self.target / 'local.txt').read_text(), 'mine')
        self.assertEqual(snapshot(self.target / '.git'), before)
        self.assertEqual(self.dot_log.read_text().count('install'), 2)

    def test_non_git_target_fails(self):
        self.target.mkdir()
        (self.target / 'file').write_text('x')
        r = self.run_boot('--repo', str(self.source))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('kein Git-Klon', r.stderr)
        self.assertEqual(snapshot(self.target), ['file'])
        self.assertFalse(self.dot_log.exists())

    def test_empty_target_directory_is_accepted(self):
        self.target.mkdir()
        r = self.run_boot('--repo', str(self.source))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.target / '.git').exists())

    def test_root_is_rejected_but_dry_run_allowed(self):
        # EUID is read-only in bash, so run the script under a shim that fakes root.
        shim = self.base / 'shim.sh'
        shim.write_text(f'EUID_FAKE=1\nsource <(sed "s/EUID == 0/1 == 1/" {SCRIPT})\n')
        env = self.env()
        real = subprocess.run([BASH, str(shim), '--repo', str(self.source)], env=env, stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=60)
        self.assertNotEqual(real.returncode, 0)
        self.assertIn('root', real.stderr)
        dry = subprocess.run([BASH, str(shim), '--dry-run', '--repo', str(self.source)], env=env,
                             stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)
        self.assertEqual(dry.returncode, 0, dry.stderr)

    def prereq_env(self, family_id: str, id_like: str = ''):
        """Restricted PATH without git/python3; the package-manager stub 'installs' them."""
        sysroot = self.base / 'sysroot'
        (sysroot / 'etc').mkdir(parents=True)
        (sysroot / 'etc/os-release').write_text(f'ID={family_id}\nID_LIKE="{id_like}"\n')
        stubs = self.base / 'stubs'
        stubs.mkdir()
        log = self.base / 'calls.log'
        write_exe(stubs / 'sudo', 'echo "sudo $*" >> "$STUB_LOG"\nexec "$@"')
        installer = (
            'echo "$(basename "$0") $*" >> "$STUB_LOG"\n'
            'printf "#!/usr/bin/env bash\\nmkdir -p \\"\\${@: -1}/.git\\" \\"\\${@: -1}/dot/.local/bin\\"\\n'
            'cp \\"$DOT_SRC\\" \\"\\${@: -1}/dot/.local/bin/dot\\"\\n" > "$STUB_BIN/git"\n'
            'chmod +x "$STUB_BIN/git"\n'
            'printf "#!/bin/sh\\n" > "$STUB_BIN/python3"; chmod +x "$STUB_BIN/python3"'
        )
        for name in ('pacman', 'dnf', 'apt-get'):
            write_exe(stubs / name, installer)
        # bash builtins cover the script itself; find, env, bash, basename, chmod, mkdir and cp are the only external tools needed.
        for tool in ('find', 'env', 'bash', 'basename', 'chmod', 'mkdir', 'cp'):
            (stubs / tool).symlink_to(shutil.which(tool))
        return log, dict(PATH=str(stubs), DOTFILES_SYSROOT=str(sysroot), STUB_LOG=str(log),
                         STUB_BIN=str(stubs), DOT_SRC=str(self.source / 'dot/.local/bin/dot'))

    def test_prerequisites_installed_per_family(self):
        cases = {
            ('arch', ''): 'pacman -S --needed --noconfirm git python3',
            ('cachyos', 'arch'): 'pacman -S --needed --noconfirm git python3',
            ('fedora', ''): 'dnf install -y git python3',
            ('ubuntu', 'debian'): 'apt-get install -y git python3',
        }
        for (ident, like), expected in cases.items():
            with self.subTest(ident=ident):
                shutil.rmtree(self.base / 'sysroot', ignore_errors=True)
                shutil.rmtree(self.base / 'stubs', ignore_errors=True)
                shutil.rmtree(self.target, ignore_errors=True)
                self.dot_log.unlink(missing_ok=True)
                log, extra = self.prereq_env(ident, like)
                r = subprocess.run([BASH, str(SCRIPT), '--repo', 'unused://repo'], env=self.env(**extra),
                                   stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertIn(f'sudo {expected}', log.read_text())
                self.assertEqual(self.dot_log.read_text().strip(), 'install')

    def test_unknown_distro_fails_when_prerequisites_missing(self):
        log, extra = self.prereq_env('gentoo')
        r = subprocess.run([BASH, str(SCRIPT), '--repo', 'unused://repo'], env=self.env(**extra),
                           stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('git python3', r.stderr)
        self.assertFalse(log.exists())

    def test_help(self):
        r = self.run_boot('--help')
        self.assertEqual(r.returncode, 0)
        self.assertIn('--dry-run', r.stdout)


if __name__ == '__main__':
    unittest.main()
