#!/usr/bin/env python3
"""Tests for scripts/corne.sh with mocked package manager, download, udevadm and uname; nothing is installed."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_tools import ModuleTestCase  # noqa: E402

RULE = ('KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="vial:f64c2b3c", MODE="0660", '
        'GROUP="users", TAG+="uaccess", TAG+="udev-acl"\n')
RELOAD = ['udevadm control --reload-rules', 'udevadm trigger --subsystem-match=hidraw --action=add']
APPIMAGE = '#!/usr/bin/env bash\nmkdir -p squashfs-root\nprintf "#!/bin/sh\\necho vial-ran\\n" > squashfs-root/AppRun\nchmod +x squashfs-root/AppRun\n'
ASSET = 'Vial-v0.7.5-x86_64.AppImage'
MOCKS = '''
# Only functions defined here count as installed binaries, never host ones.
have() { declare -F "$1" >/dev/null 2>&1; }
is_wsl() { return %(wsl)d; }
uname() { printf '%(arch)s\\n'; }
udevadm() { printf 'udevadm %%s\\n' "$*" >> "$CMD_LOG"; }
pkg_install() { printf 'pkg_install %%s\\n' "$*" >> "$CMD_LOG"; }
%(extra)s
'''
# github_asset stand-in: leaves a fake AppImage that "extracts" itself like the real one.
FAKE_ASSET = '''
github_asset() {
    printf 'github_asset %s %s\\n' "$1" "$2" >> "$CMD_LOG"
    printf '%s' "$APPIMAGE" > "$3"
}
'''
# Real github_asset with the network replaced by local release metadata.
FAKE_DOWNLOAD = '''
download() {
    case "$1" in
        */releases/latest) cp "$RELEASE_JSON" "$2" ;;
        *) printf '%s' "$APPIMAGE" > "$2" ;;
    esac
}
'''


class CorneTests(ModuleTestCase):
    def setUp(self):
        super().setUp()
        self.home = self.base / 'home'
        self.home.mkdir()
        self.rule = self.base / 'etc/udev/rules.d/99-vial.rules'
        self.env.update(HOME=str(self.home), VIAL_UDEV_RULE=str(self.rule), APPIMAGE=APPIMAGE)

    def corne(self, extra='', arch='x86_64', wsl=False, **kwargs):
        mocks = MOCKS % dict(wsl=0 if wsl else 1, arch=arch, extra=extra)
        return self.call('install_corne', mocks, **kwargs)

    def ok(self, *args, **kwargs):
        result, commands = self.corne(*args, **kwargs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result, commands

    def write_release(self, digest):
        release = self.base / 'release.json'
        release.write_text(json.dumps({'prerelease': False, 'draft': False, 'assets': [{
            'name': ASSET, 'browser_download_url': f'https://example.invalid/{ASSET}', 'digest': digest}]}))
        self.env['RELEASE_JSON'] = str(release)

    def test_arch_installs_aur_package_and_rule(self):
        _, commands = self.ok(family='arch')
        self.assertEqual(commands, ['pkg_install aur:vial-appimage', *RELOAD])
        self.assertEqual(self.rule.read_text(), RULE)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_fedora_and_debian_extract_appimage(self):
        for family in ('fedora', 'debian'):
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                self.rule.unlink(missing_ok=True)
                _, commands = self.ok(FAKE_ASSET, family=family)
                self.assertEqual(commands, ['github_asset vial-kb/vial-gui Vial-v.*-x86_64\\.AppImage', *RELOAD])
                self.assertTrue((self.home / '.local/opt/vial/AppRun').is_file())
                wrapper = self.home / '.local/bin/vial'
                self.assertEqual(subprocess.run([wrapper], env=self.env, capture_output=True, text=True).stdout,
                                 'vial-ran\n')
                desktop = (self.home / '.local/share/applications/vial.desktop').read_text()
                self.assertIn(f'Exec="{wrapper}"\n', desktop)
                self.assertEqual(self.rule.read_text(), RULE)

    def test_spaces_in_home(self):
        home = self.base / 'my home dir'
        home.mkdir()
        self.env['HOME'] = str(home)
        self.ok(FAKE_ASSET)
        wrapper = home / '.local/bin/vial'
        self.assertEqual(subprocess.run([wrapper], env=self.env, capture_output=True, text=True).stdout, 'vial-ran\n')
        self.assertIn(f'Exec="{wrapper}"\n', (home / '.local/share/applications/vial.desktop').read_text())

    def test_digest_is_verified(self):
        self.write_release('sha256:' + hashlib.sha256(APPIMAGE.encode()).hexdigest())
        self.ok(FAKE_DOWNLOAD)
        self.assertTrue((self.home / '.local/opt/vial/AppRun').is_file())

    def test_digest_mismatch_installs_nothing(self):
        self.write_release('sha256:' + '0' * 64)
        result, commands = self.corne(FAKE_DOWNLOAD)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SHA-256', result.stderr)
        self.assertEqual(commands, [])
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertFalse(self.rule.exists())

    def test_aarch64_is_rejected(self):
        result, commands = self.corne(FAKE_ASSET, arch='aarch64')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('aarch64', result.stderr)
        self.assertEqual(commands, [])
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertFalse(self.rule.exists())

    def test_installed_vial_is_kept_and_rule_is_idempotent(self):
        _, commands = self.ok('vial() { :; }', family='arch')
        self.assertEqual(commands, RELOAD)
        self.log.unlink()
        mtime = self.rule.stat().st_mtime_ns
        result, commands = self.ok('vial() { :; }', family='arch')
        self.assertEqual(commands, [])
        self.assertIn('aktuell', result.stdout)
        self.assertEqual(self.rule.stat().st_mtime_ns, mtime)

    def test_capitalised_vial_binary_skips_install(self):
        result, commands = self.ok('Vial() { :; }', family='arch')
        self.assertEqual(commands, RELOAD)
        self.assertIn('Vial ist vorhanden', result.stdout)

    def test_conflicting_rule_needs_backup(self):
        self.rule.parent.mkdir(parents=True)
        self.rule.write_text('# custom\n')
        result, commands = self.corne('vial() { :; }')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--backup', result.stderr)
        self.assertEqual(self.rule.read_text(), '# custom\n')
        self.assertEqual(commands, [])
        self.assertFalse((self.home / '.local/state').exists())

    def test_backup_replaces_conflicting_rule(self):
        self.rule.parent.mkdir(parents=True)
        self.rule.write_text('# custom\n')
        _, commands = self.ok('vial() { :; }\nBACKUP=1')
        self.assertEqual(commands, RELOAD)
        self.assertEqual(self.rule.read_text(), RULE)
        backups = list((self.home / '.local/state/dotfiles/backups').glob('*/99-vial.rules'))
        self.assertEqual([b.read_text() for b in backups], ['# custom\n'])

    def test_skips_headless_and_wsl(self):
        for kwargs in ({'profile': 'headless'}, {'wsl': True}):
            with self.subTest(**kwargs):
                result, commands = self.ok(**kwargs)
                self.assertIn('übersprungen', result.stdout)
                self.assertEqual(commands, [])
                self.assertEqual(list(self.home.iterdir()), [])
                self.assertFalse(self.rule.exists())

    def test_dry_run_writes_nothing(self):
        for family in ('arch', 'fedora', 'debian'):
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                result, commands = self.ok(FAKE_ASSET, family=family, dry_run=1)
                self.assertEqual([c for c in commands if not c.startswith('pkg_install')], [])
                self.assertIn('install -D -m 0644 /dev/stdin', result.stdout)
                self.assertIn('udevadm control --reload-rules', result.stdout)
                self.assertEqual(list(self.home.iterdir()), [])
                self.assertFalse(self.rule.parent.exists())
                self.assertFalse(list(self.base.glob('dotfiles.*')))

    def test_dry_run_with_conflict_writes_nothing(self):
        self.rule.parent.mkdir(parents=True)
        self.rule.write_text('# custom\n')
        self.ok('vial() { :; }\nBACKUP=1', dry_run=1)
        self.assertEqual(self.rule.read_text(), '# custom\n')
        self.assertEqual(list(self.home.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
