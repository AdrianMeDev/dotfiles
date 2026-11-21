#!/usr/bin/env python3
"""Offline tests for windows/wsl-bootstrap.sh with stubbed system commands and a temp sysroot."""
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'windows/wsl-bootstrap.sh'

# Stubs log mutating calls to $STUB_STATE/calls.log and keep state in $STUB_STATE.
STUBS = {
    'pacman-key': 'echo "pacman-key $*" >> "$STUB_STATE/calls.log"',
    'pacman': '''
if [[ $1 == -Q ]]; then grep -qx -- "$2" "$STUB_STATE/packages" 2>/dev/null; exit; fi
echo "pacman $*" >> "$STUB_STATE/calls.log"
for a in "$@"; do [[ $a == -* ]] || echo "$a" >> "$STUB_STATE/packages"; done
''',
    'getent': 'grep -- "^$2:" "$STUB_STATE/passwd" 2>/dev/null',
    'id': 'sed -n "s/^$2://p" "$STUB_STATE/groups"',
    'useradd': '''
echo "useradd $*" >> "$STUB_STATE/calls.log"
echo "${@: -1}:x:1000:1000::/home/${@: -1}:/usr/bin/zsh" >> "$STUB_STATE/passwd"
echo "${@: -1}:wheel" >> "$STUB_STATE/groups"
''',
    'usermod': '''
echo "usermod $*" >> "$STUB_STATE/calls.log"
sed -i "s|^\\(${@: -1}:.*:\\)[^:]*$|\\1/usr/bin/zsh|" "$STUB_STATE/passwd"
sed -i "s|^\\(${@: -1}:.*\\)$|\\1 wheel|" "$STUB_STATE/groups"
''',
    'visudo': '[[ $1 == -cf ]] && [[ -z ${STUB_VISUDO_FAIL:-} ]]',
    'runuser': 'shift 2; exec "$@"',
    'git': '''
args=("$@")
while [[ ${args[0]:-} == -c ]]; do args=("${args[@]:2}"); done
if [[ ${args[0]} == -C ]]; then
    dir=${args[1]}
    case "${args[*]:2}" in
        "remote get-url origin") cat "$dir/.git/origin" 2>/dev/null; exit ;;
        "remote set-url origin "*) echo "git set-url ${args[5]}" >> "$STUB_STATE/calls.log"; echo "${args[5]}" > "$dir/.git/origin"; exit ;;
    esac
fi
if [[ ${args[0]} == clone ]]; then
    src=${args[2]}; dest=${args[3]}
    echo "git clone $src $dest" >> "$STUB_STATE/calls.log"
    mkdir -p "$dest/.git"; echo "$src" > "$dest/.git/origin"; exit
fi
exit 1
''',
}


class WslBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-wslboot-')
        base = Path(self.temp.name)
        self.sysroot = base / 'sys root'
        self.sysroot.mkdir()
        self.state = base / 'state'
        self.state.mkdir()
        self.stubs = base / 'stubs'
        self.stubs.mkdir()
        for name, body in STUBS.items():
            path = self.stubs / name
            path.write_text('#!/usr/bin/env bash\n' + body.strip() + '\n')
            path.chmod(0o755)
        self.source = base / 'windows clone'
        (self.source / '.git').mkdir(parents=True)
        (self.source / '.git/origin').write_text('git@example.com:me/dotfiles.git\n')
        self.env = dict(os.environ, PATH=f'{self.stubs}:{os.environ["PATH"]}', STUB_STATE=str(self.state))
        self.env.pop('STUB_VISUDO_FAIL', None)
        self.sudoers = self.sysroot / 'etc/sudoers.d/10-wheel'
        self.wsl_conf = self.sysroot / 'etc/wsl.conf'
        self.dest = self.sysroot / 'home/adrian/dotfiles'

    def tearDown(self):
        self.temp.cleanup()

    def run_script(self, *args, env=None):
        cmd = ['bash', str(SCRIPT), '--user', 'adrian', '--repo', str(self.source),
               '--sysroot', str(self.sysroot), *args]
        return subprocess.run(cmd, env=env or self.env, capture_output=True, text=True, check=False)

    def tree(self):
        return sorted(str(p.relative_to(self.sysroot)) for p in self.sysroot.rglob('*'))

    def calls(self):
        log = self.state / 'calls.log'
        return log.read_text().splitlines() if log.exists() else []

    def seed_keyring(self):
        (self.sysroot / 'etc/pacman.d/gnupg').mkdir(parents=True)
        (self.sysroot / 'etc/pacman.d/gnupg/trustdb.gpg').write_text('')

    def test_syntax(self):
        self.assertEqual(subprocess.run(['bash', '-n', str(SCRIPT)]).returncode, 0)

    def test_rejects_bad_arguments(self):
        for args in (['--user', 'Bad Name'], ['--user', 'root'], ['--bogus']):
            cmd = ['bash', str(SCRIPT), '--repo', 'x', '--sysroot', str(self.sysroot), *args]
            self.assertNotEqual(subprocess.run(cmd, env=self.env, capture_output=True).returncode, 0, args)

    def test_dry_run_writes_nothing(self):
        result = self.run_script('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tree(), [])
        self.assertEqual(self.calls(), [])
        self.assertIn('pacman-key --init', result.stdout)
        self.assertIn('useradd', result.stdout)

    def test_initial_setup(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertIn('pacman-key --init', calls)
        self.assertIn('pacman-key --populate archlinux', calls)
        self.assertIn('pacman -Syu --noconfirm --needed sudo git python zsh', calls)
        self.assertIn('useradd --create-home --groups wheel --shell /usr/bin/zsh adrian', calls)
        self.assertEqual(self.sudoers.read_text(), '%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n')
        self.assertEqual(stat.S_IMODE(self.sudoers.stat().st_mode), 0o440)
        self.assertEqual(self.wsl_conf.read_text(), '[user]\ndefault=adrian\n')
        self.assertIn(f'git clone {self.source} {self.dest}', calls)
        self.assertEqual((self.dest / '.git/origin').read_text().strip(), 'git@example.com:me/dotfiles.git')
        self.assertEqual([p for p in self.tree() if '.tmp.' in p or '.bak.' in p], [])

    def test_repeat_is_idempotent(self):
        self.assertEqual(self.run_script().returncode, 0)
        before = self.tree()
        contents = (self.sudoers.read_bytes(), self.wsl_conf.read_bytes())
        calls = self.calls()
        self.seed_keyring()
        before.extend(['etc/pacman.d', 'etc/pacman.d/gnupg', 'etc/pacman.d/gnupg/trustdb.gpg'])
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), calls)
        self.assertEqual(self.tree(), sorted(before))
        self.assertEqual((self.sudoers.read_bytes(), self.wsl_conf.read_bytes()), contents)

    def test_existing_user_is_updated(self):
        (self.state / 'passwd').write_text('adrian:x:1000:1000::/home/adrian:/bin/bash\n')
        (self.state / 'groups').write_text('adrian:users\n')
        self.assertEqual(self.run_script().returncode, 0)
        self.assertIn('usermod --shell /usr/bin/zsh --append --groups wheel adrian', self.calls())
        self.assertNotIn('useradd', ' '.join(self.calls()))

    def test_wsl_conf_merge_preserves_entries(self):
        self.wsl_conf.parent.mkdir(parents=True)
        self.wsl_conf.write_text('[boot]\nsystemd=true\n\n[user]\nfoo=bar\n\n[interop]\nenabled=false\n')
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.wsl_conf.read_text(),
                         '[boot]\nsystemd=true\n\n[user]\ndefault=adrian\nfoo=bar\n\n[interop]\nenabled=false\n')
        self.assertEqual([p for p in self.tree() if '.bak.' in p], [])

    def test_wsl_conf_appends_user_section(self):
        self.wsl_conf.parent.mkdir(parents=True)
        self.wsl_conf.write_text('[boot]\nsystemd=true\n')
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.wsl_conf.read_text(), '[boot]\nsystemd=true\n\n[user]\ndefault=adrian\n')

    def test_wsl_conf_conflict_needs_backup(self):
        self.wsl_conf.parent.mkdir(parents=True)
        original = '[user]\ndefault=root\n[boot]\nsystemd=true\n'
        self.wsl_conf.write_text(original)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--backup', result.stderr)
        self.assertEqual(self.wsl_conf.read_text(), original)
        result = self.run_script('--backup')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.wsl_conf.read_text(), '[user]\ndefault=adrian\n[boot]\nsystemd=true\n')
        backups = list(self.wsl_conf.parent.glob('wsl.conf.bak.*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), original)

    def test_sudoers_conflict_needs_backup(self):
        self.sudoers.parent.mkdir(parents=True)
        self.sudoers.write_text('%wheel ALL=(ALL) ALL\n')
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(self.sudoers.read_text(), '%wheel ALL=(ALL) ALL\n')
        self.assertEqual(self.run_script('--backup').returncode, 0)
        self.assertEqual(self.sudoers.read_text(), '%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n')
        self.assertEqual(stat.S_IMODE(self.sudoers.stat().st_mode), 0o440)
        self.assertEqual(len(list(self.sudoers.parent.glob('10-wheel.bak.*'))), 1)

    def test_invalid_sudoers_is_not_installed(self):
        env = dict(self.env, STUB_VISUDO_FAIL='1')
        result = self.run_script(env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.sudoers.exists())
        self.assertEqual(list(self.sudoers.parent.glob('*')), [])

    def test_existing_clone_is_left_alone(self):
        self.dest.mkdir(parents=True)
        (self.dest / '.git').mkdir()
        (self.dest / '.git/origin').write_text('https://other.example/x.git\n')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('unverändert', result.stderr)
        self.assertEqual((self.dest / '.git/origin').read_text().strip(), 'https://other.example/x.git')
        self.assertFalse(any(c.startswith('git clone') for c in self.calls()))

    def test_explicit_origin_and_spaces(self):
        result = self.run_script('--origin', 'https://github.com/me/my dotfiles.git')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'git clone {self.source} {self.dest}', self.calls())
        self.assertEqual((self.dest / '.git/origin').read_text().strip(), 'https://github.com/me/my dotfiles.git')
        self.assertIn(' ', str(self.dest))


if __name__ == '__main__':
    unittest.main()
