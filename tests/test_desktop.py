#!/usr/bin/env python3
"""Tests for scripts/desktop.sh: Hyprland stack per family/profile/WSL with a mocked sudo."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
COMMON = ['hyprland', 'xdg-desktop-portal-hyprland', 'waybar', 'fuzzel', 'mako', 'hyprlock',
          'hypridle', 'hyprpaper', 'cliphist', 'grim', 'slurp', 'wireplumber', 'brightnessctl', 'playerctl', 'gnome-keyring',
          'pavucontrol', 'libnotify']


class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-desktop-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.log = self.base / 'commands'
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, REPO_DIR=str(REPO), CMD_LOG=str(self.log))
        for key in ('WSL_INTEROP', 'WSL_DISTRO_NAME'):
            self.env.pop(key, None)

    def stub_hyprland(self, version):
        stub = self.bin / 'hyprland'
        stub.write_text(f'#!/bin/sh\necho "Hyprland {version} built from branch main"\n')
        stub.chmod(0o755)

    def desktop(self, family, profile='desktop', dry_run=0, sudo='log', env=None):
        mock = {'log': 'sudo() { printf "%s\\n" "$*" >> "$CMD_LOG"; }',
                'fail': 'sudo() { return 42; }'}[sudo]
        script = f'''
set -Eeuo pipefail
source "$REPO_DIR/scripts/common.sh"
source "$REPO_DIR/scripts/pkg.sh"
source "$REPO_DIR/scripts/desktop.sh"
DRY_RUN={dry_run} EXTRAS='' DISTRO_FAMILY={family} PROFILE={profile}
{mock}
install_desktop
'''
        run_env = dict(self.env, PATH=f'{self.bin}:{os.environ["PATH"]}', **(env or {}))
        result = subprocess.run(['bash', '-c', script], cwd=self.base, env=run_env,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
        commands = self.log.read_text().splitlines() if self.log.exists() else []
        return result, commands

    def test_arch_installs_hypr_packages(self):
        result, commands = self.desktop('arch')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(commands), 1, commands)
        self.assertTrue(commands[0].startswith('pacman -S --needed --noconfirm '), commands)
        packages = commands[0].split()
        for name in [*COMMON, 'polkit-kde-agent']:
            self.assertIn(name, packages)

    def test_fedora_enables_copr_then_installs(self):
        result, commands = self.desktop('fedora')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands[0], 'dnf copr enable -y sdegler/hyprland')
        self.assertTrue(commands[1].startswith('dnf install -y '), commands)
        packages = commands[1].split()
        for name in [*COMMON, 'polkit-kde']:
            self.assertIn(name, packages)
        self.assertEqual(len(commands), 2)

    def test_dry_run_only_prints(self):
        for family, first in (('arch', 'sudo pacman -S'), ('fedora', 'sudo dnf copr enable')):
            with self.subTest(family=family):
                result, commands = self.desktop(family, dry_run=1)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(first, result.stdout)
                self.assertIn('hyprland', result.stdout)
                self.assertEqual(commands, [])

    def test_skips_headless_wsl_and_debian(self):
        cases = {
            'headless': dict(family='arch', profile='headless'),
            'wsl': dict(family='fedora', env={'WSL_INTEROP': '/run/WSL/interop'}),
            'debian': dict(family='debian'),
        }
        for name, kwargs in cases.items():
            with self.subTest(case=name):
                result, commands = self.desktop(**kwargs)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('übersprungen', result.stdout)
                self.assertEqual(commands, [])

    def test_rerun_is_idempotent(self):
        for family in ('arch', 'fedora'):
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                first, commands_a = self.desktop(family)
                self.log.unlink(missing_ok=True)
                second, commands_b = self.desktop(family)
                self.assertEqual(first.returncode, 0, first.stderr)
                self.assertEqual(second.returncode, 0, second.stderr)
                self.assertEqual(commands_a, commands_b)
                self.assertTrue(any('--needed' in c or 'install -y' in c for c in commands_b))

    def test_failure_is_propagated(self):
        for family in ('arch', 'fedora'):
            with self.subTest(family=family):
                result, _ = self.desktop(family, sudo='fail')
                self.assertEqual(result.returncode, 42, result.stdout + result.stderr)

    def test_old_hyprland_warns_without_failing(self):
        self.stub_hyprland('0.54.0')
        result, _ = self.desktop('arch')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Hyprland 0.54.0 ist älter als 0.57', result.stderr)

    def test_current_hyprland_does_not_warn(self):
        for version in ('0.57.0', '0.60.1'):
            with self.subTest(version=version):
                self.stub_hyprland(version)
                result, _ = self.desktop('arch')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn('älter', result.stderr)


if __name__ == '__main__':
    unittest.main()
