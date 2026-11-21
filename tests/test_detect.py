#!/usr/bin/env python3
"""Unit tests for scripts/detect.sh (distro family, WSL and profile detection)."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
DETECT_SH = REPO / 'scripts' / 'detect.sh'

CLEAN_ENV_KEYS = (
    'WSL_INTEROP',
    'WSL_DISTRO_NAME',
    'DISPLAY',
    'WAYLAND_DISPLAY',
    'XDG_CURRENT_DESKTOP',
    'XDG_SESSION_TYPE',
    'container',
    'DOTFILES_SYSROOT',
)


class DetectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-detect-tests-')
        self.base = Path(self.temp.name)
        self.sysroot = self.base / 'sysroot'
        self.sysroot.mkdir()
        self.bin_dir = self.base / 'bin'
        self.bin_dir.mkdir()
        self.bash = shutil.which('bash') or '/bin/bash'

    def tearDown(self):
        self.temp.cleanup()

    def make_os_release(self, content):
        etc = self.sysroot / 'etc'
        etc.mkdir(parents=True, exist_ok=True)
        (etc / 'os-release').write_text(content, encoding='utf-8')

    def make_systemctl_stub(self, target, exit_code=0):
        stub = self.bin_dir / 'systemctl'
        stub.write_text(
            f'#!{self.bash}\n'
            f'if [[ ${{1:-}} == get-default ]]; then\n'
            f'    printf "%s\\n" {target!r}\n'
            f'    exit {exit_code}\n'
            f'fi\n'
            f'exit 1\n',
            encoding='utf-8',
        )
        stub.chmod(0o755)

    def clean_env(self, extra=None, with_stub_path=False):
        env = dict(os.environ)
        for key in CLEAN_ENV_KEYS:
            env.pop(key, None)
        env['DOTFILES_SYSROOT'] = str(self.sysroot)
        if with_stub_path:
            # Keep only the stub dir so a host systemctl cannot leak in.
            env['PATH'] = str(self.bin_dir)
        if extra:
            env.update(extra)
        return env

    def run_detect(self, body, env):
        return subprocess.run(
            [self.bash, '-c', f'source "{DETECT_SH}"\n{body}'],
            cwd=self.base,
            env=env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_detect_family_supported_distros(self):
        cases = [
            ('arch', 'ID=arch\nNAME="Arch Linux"\n', 'arch'),
            ('cachyos', 'ID=cachyos\nID_LIKE=arch\nNAME="CachyOS"\n', 'arch'),
            ('endeavouros', 'ID=endeavouros\nID_LIKE=arch\nNAME="EndeavourOS"\n', 'arch'),
            ('fedora', 'ID=fedora\nVERSION_ID=41\n', 'fedora'),
            ('debian', 'ID=debian\nVERSION_ID="12"\n', 'debian'),
            ('ubuntu', 'ID=ubuntu\nID_LIKE=debian\nVERSION_ID="24.04"\n', 'debian'),
            ('linuxmint', 'ID=linuxmint\nID_LIKE="ubuntu debian"\n', 'debian'),
        ]
        for label, os_release, expected in cases:
            with self.subTest(distro=label):
                # Reset sysroot per subtest
                shutil.rmtree(self.sysroot)
                self.sysroot.mkdir()
                self.make_os_release(os_release)
                res = self.run_detect('detect_family', self.clean_env())
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assertEqual(res.stdout.strip(), expected)

    def test_detect_family_rejects_fedora_ostree(self):
        self.make_os_release('ID=fedora\nVARIANT_ID=silverblue\n')
        run_dir = self.sysroot / 'run'
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / 'ostree-booted').write_text('', encoding='utf-8')
        res = self.run_detect('detect_family', self.clean_env())
        self.assertNotEqual(res.returncode, 0)
        self.assertIn('ostree', res.stderr.lower())

    def test_detect_family_rejects_alpine_and_missing_os_release(self):
        self.make_os_release('ID=alpine\nVERSION_ID=3.20\n')
        res_alpine = self.run_detect('detect_family', self.clean_env())
        self.assertNotEqual(res_alpine.returncode, 0)
        self.assertTrue(res_alpine.stderr.strip())

        shutil.rmtree(self.sysroot)
        self.sysroot.mkdir()
        res_missing = self.run_detect('detect_family', self.clean_env())
        self.assertNotEqual(res_missing.returncode, 0)
        self.assertTrue(res_missing.stderr.strip())

    def test_detect_family_does_not_leak_os_release_vars(self):
        self.make_os_release('ID=fedora\nID_LIKE=rhel\n')
        res = self.run_detect(
            'ID=sentinel; ID_LIKE=sentinel; detect_family >/dev/null; printf "%s|%s\\n" "$ID" "$ID_LIKE"',
            self.clean_env(),
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(res.stdout.strip(), 'sentinel|sentinel')

    def test_detect_profile_wsl_is_always_headless(self):
        self.make_systemctl_stub('graphical.target')
        env = self.clean_env(
            extra={'WSL_DISTRO_NAME': 'Arch', 'DISPLAY': ':0', 'WAYLAND_DISPLAY': 'wayland-0'},
            with_stub_path=True,
        )
        res = self.run_detect('detect_profile', env)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(res.stdout.strip(), 'headless')

    def test_detect_profile_container_markers_are_headless(self):
        self.make_systemctl_stub('graphical.target')
        for marker in ('.dockerenv', 'run/.containerenv'):
            with self.subTest(marker=marker):
                shutil.rmtree(self.sysroot)
                self.sysroot.mkdir()
                marker_path = self.sysroot / marker
                marker_path.parent.mkdir(parents=True, exist_ok=True)
                marker_path.write_text('', encoding='utf-8')
                env = self.clean_env(extra={'DISPLAY': ':0'}, with_stub_path=True)
                res = self.run_detect('detect_profile', env)
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assertEqual(res.stdout.strip(), 'headless')

        shutil.rmtree(self.sysroot)
        self.sysroot.mkdir()
        env = self.clean_env(extra={'container': 'podman', 'DISPLAY': ':0'}, with_stub_path=True)
        res = self.run_detect('detect_profile', env)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(res.stdout.strip(), 'headless')

    def test_detect_profile_graphical_session_is_desktop(self):
        self.make_systemctl_stub('multi-user.target')
        for var, val in (
            ('WAYLAND_DISPLAY', 'wayland-1'),
            ('DISPLAY', ':0'),
            ('XDG_CURRENT_DESKTOP', 'Hyprland'),
            ('XDG_SESSION_TYPE', 'wayland'),
        ):
            with self.subTest(var=var):
                env = self.clean_env(extra={var: val}, with_stub_path=True)
                res = self.run_detect('detect_profile', env)
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assertEqual(res.stdout.strip(), 'desktop')

    def test_detect_profile_systemctl_default_target(self):
        self.make_systemctl_stub('graphical.target')
        res_desktop = self.run_detect('detect_profile', self.clean_env(with_stub_path=True))
        self.assertEqual(res_desktop.returncode, 0, res_desktop.stderr)
        self.assertEqual(res_desktop.stdout.strip(), 'desktop')

        self.make_systemctl_stub('multi-user.target')
        res_headless = self.run_detect('detect_profile', self.clean_env(with_stub_path=True))
        self.assertEqual(res_headless.returncode, 0, res_headless.stderr)
        self.assertEqual(res_headless.stdout.strip(), 'headless')

    def test_detect_profile_without_systemctl_or_display_is_headless(self):
        res = self.run_detect('detect_profile', self.clean_env(with_stub_path=True))
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(res.stdout.strip(), 'headless')


if __name__ == '__main__':
    unittest.main()
