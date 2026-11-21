#!/usr/bin/env python3
"""Tests for scripts/system.sh: per-family command order with a mocked sudo."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]

APT = 'env DEBIAN_FRONTEND=noninteractive apt-get'
# family -> (commands before the manifest install, prefix of the manifest install, commands after it)
FAMILIES = {
    'arch': (['pacman -Syu --noconfirm'], 'pacman -S --needed --noconfirm ', ['aur-helper']),
    'fedora': (['dnf upgrade --refresh -y'], 'dnf install -y ', []),
    'debian': ([f'{APT} update', f'{APT} full-upgrade -y'], f'{APT} install -y ', []),
}
DESKTOP_ONLY = ('flatpak', 'xclip', 'wl-clipboard')


class SystemTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-system-')
        self.base = Path(self.temp.name)
        self.log = self.base / 'commands'
        self.env = dict(os.environ, REPO_DIR=str(REPO), CMD_LOG=str(self.log))
        for key in ('WSL_INTEROP', 'WSL_DISTRO_NAME'):
            self.env.pop(key, None)

    def tearDown(self):
        self.temp.cleanup()

    def system(self, family, profile='desktop', extras='', dry_run=0, sudo='log', env=None):
        """Run install_system; sudo/pkg_ensure_aur_helper are mocked to log into CMD_LOG."""
        mock = {'log': 'sudo() { printf "%s\\n" "$*" >> "$CMD_LOG"; }',
                'fail': 'sudo() { return 42; }'}[sudo]
        script = f'''
set -Eeuo pipefail
source "$REPO_DIR/scripts/common.sh"
source "$REPO_DIR/scripts/pkg.sh"
source "$REPO_DIR/scripts/system.sh"
DRY_RUN={dry_run} EXTRAS={extras!r} DISTRO_FAMILY={family} PROFILE={profile}
{mock}
pkg_ensure_aur_helper() {{ printf 'aur-helper\\n' >> "$CMD_LOG"; }}
install_system
'''
        result = subprocess.run(['bash', '-c', script], cwd=self.base, env=dict(self.env, **(env or {})),
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
        commands = self.log.read_text().splitlines() if self.log.exists() else []
        return result, commands

    def test_command_order_per_family(self):
        for family, (before, install, after) in FAMILIES.items():
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                result, commands = self.system(family)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(commands[:len(before)], before)
                self.assertTrue(commands[len(before)].startswith(install), commands)
                self.assertEqual(commands[len(before) + 1:], after)
                self.assertIn('git', commands[len(before)].split())
                self.assertIn('flatpak', commands[len(before)].split())

    def test_headless_installs_no_desktop_packages(self):
        for family, (before, install, after) in FAMILIES.items():
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                result, commands = self.system(family, profile='headless')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                packages = commands[len(before)].split()
                self.assertIn('git', packages)
                for name in DESKTOP_ONLY:
                    self.assertNotIn(name, packages)
                self.assertEqual(commands[len(before) + 1:], after)

    def test_rpmfusion_is_skipped_with_hint_outside_fedora(self):
        for family in ('arch', 'debian'):
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                result, commands = self.system(family, extras='rpmfusion')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('rpmfusion gilt nur für Fedora', result.stdout)
                self.assertFalse([c for c in commands if 'rpmfusion' in c])

    def test_fedora_rpmfusion_dry_run_installs_release_packages(self):
        result, commands = self.system('fedora', extras='rpmfusion', dry_run=1)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('gilt nur für Fedora', result.stdout)
        for variant in ('free', 'nonfree'):
            self.assertIn(f'rpmfusion-{variant}-release-FEDORA_VERSION.noarch.rpm', result.stdout)
        self.assertEqual(commands, [])

    def test_failure_is_propagated(self):
        for family in FAMILIES:
            with self.subTest(family=family):
                result, _ = self.system(family, sudo='fail')
                self.assertEqual(result.returncode, 42, result.stdout + result.stderr)

    def test_unknown_family_fails(self):
        result, commands = self.system('plan9')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])

    def test_fedora_wsl_system_upgrade_keeps_windows_kernel(self):
        result, commands = self.system('fedora', env={'WSL_INTEROP': '/run/WSL/interop'})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands[0], 'dnf upgrade --refresh -y --exclude=kernel*')
        self.assertTrue(commands[1].startswith('dnf install -y '))
        self.assertIn('WSL erkannt', result.stdout)

    def test_fedora_wsl_dry_run_reports_kernel_exclusion(self):
        result, _ = self.system('fedora', dry_run=1, env={'WSL_DISTRO_NAME': 'Fedora'})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('--exclude=kernel\\*', result.stdout)


class InstallerDryRunTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='dotfiles-dry-run-')
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        self.home = base / 'home'
        self.home.mkdir()
        self.sysroot = base / 'sysroot'
        (self.sysroot / 'etc').mkdir(parents=True)
        self.env = dict(HOME=str(self.home), PATH=os.environ['PATH'],
                        DOTFILES_SYSROOT=str(self.sysroot), WSL_DISTRO_NAME='test')

    def preview(self, distro, *args):
        (self.sysroot / 'etc/os-release').write_text(f'ID={distro}\n')
        result = subprocess.run([str(REPO / 'install.sh'), '--dry-run', *args], env=self.env,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
        self.assertEqual(list(self.home.iterdir()), [])
        return result

    def test_full_preview_per_family(self):
        for distro, family in [('cachyos', 'arch'), ('fedora', 'fedora'), ('ubuntu', 'debian')]:
            with self.subTest(distro=distro):
                result = self.preview(distro)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(f'Distro-Familie: {family} · Profil: headless · WSL: ja', result.stdout)
                self.assertIn(FAMILIES[family][0][-1], result.stdout)
                self.assertIn('Modul: dotfiles', result.stdout)

    def test_unsupported_systems_allow_only_dotfiles(self):
        for distro in ('alpine', 'fedora'):
            with self.subTest(distro=distro):
                if distro == 'fedora':
                    (self.sysroot / 'run').mkdir()
                    (self.sysroot / 'run/ostree-booted').touch()
                result = self.preview(distro)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('ostree' if distro == 'fedora' else 'alpine', result.stderr)
                self.assertIn('--only dotfiles', result.stderr)
                self.assertNotIn('Modul:', result.stdout)
                result = self.preview(distro, '--only', 'dotfiles')
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_profile(self):
        result = self.preview('fedora', '--profile', 'server')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Ungültiges Profil', result.stderr)

    def test_profile_controls_flatpak_and_clipboard(self):
        for profile in ('desktop', 'headless'):
            with self.subTest(profile=profile):
                result = self.preview('ubuntu', '--profile', profile, '--extras', 'firefox')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f'Profil: {profile}', result.stdout)
                commands = ' '.join(line for line in result.stdout.splitlines() if line.startswith('  +'))
                for word in ('wl-clipboard', 'flatpak'):
                    self.assertEqual(word in commands.split(), profile == 'desktop', commands)
                if profile == 'headless':
                    self.assertIn('Flatpak wird im Profil headless übersprungen', result.stdout)
                else:
                    self.assertIn('+ flatpak install', commands)


if __name__ == '__main__':
    unittest.main()
