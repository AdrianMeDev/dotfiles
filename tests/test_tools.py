#!/usr/bin/env python3
"""Tests for scripts/tools.sh with mocked installers; nothing is installed."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
CONFIG = REPO / 'mise/.config/mise/config.toml'


class ModuleTestCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-tools-')
        self.base = Path(self.temp.name)
        self.log = self.base / 'commands'
        # Empty PATH dir: only the functions mocked below can be found by `command -v`.
        self.env = dict(os.environ, REPO_DIR=str(REPO), CMD_LOG=str(self.log), PATH=f'{self.base}:/usr/bin:/bin',
                        HOME=str(self.base))

    def tearDown(self):
        self.temp.cleanup()

    def call(self, function, mocks, profile='desktop', extras='', dry_run=0, family='fedora'):
        script = f'''
set -Eeuo pipefail
source "$REPO_DIR/scripts/common.sh"
source "$REPO_DIR/scripts/pkg.sh"
source "$REPO_DIR/scripts/{function.removeprefix('install_')}.sh"
DRY_RUN={dry_run} EXTRAS={extras!r} DISTRO_FAMILY={family} PROFILE={profile}
pkg_install() {{ printf 'pkg_install %s\\n' "$*" >> "$CMD_LOG"; }}
upstream_installer() {{ printf 'upstream %s\\n' "$1" >> "$CMD_LOG"; }}
{mocks}
{function}
'''
        result = subprocess.run(['bash', '-c', script], cwd=self.base, env=self.env,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
        commands = self.log.read_text().splitlines() if self.log.exists() else []
        return result, commands


class ToolsTests(ModuleTestCase):
    MISE = 'mise() { printf "mise[%s] %s\\n" "${MISE_GLOBAL_CONFIG_FILE:-}" "$*" >> "$CMD_LOG"; }'

    def tools(self, mocks=MISE, **kwargs):
        return self.call('install_tools', mocks, **kwargs)

    def test_installs_everything_through_mise(self):
        result, commands = self.tools()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands, [
            'pkg_install dotnet-sdk-10.0',
            f'mise[{CONFIG}] install --yes',
            f'mise[{CONFIG}] exec -- uv python install 3.14',
        ])
        self.assertNotIn('fnm', result.stdout)

    def test_bootstraps_mise_when_absent(self):
        # upstream_installer defines mise once the bootstrap has run.
        mocks = ('upstream_installer() { printf "upstream %s %s\\n" "$1" "$2" >> "$CMD_LOG"; '
                 + self.MISE + '; }')
        result, commands = self.tools(mocks=mocks)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands[1], 'upstream mise https://mise.run')
        self.assertEqual(commands[2], f'mise[{CONFIG}] install --yes')

    def test_dry_run_executes_nothing(self):
        result, commands = self.tools(mocks='', dry_run=1)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands, ['pkg_install dotnet-sdk-10.0', 'upstream mise'])
        self.assertIn('mise install --yes', result.stdout)
        self.assertIn('uv python install 3.14', result.stdout)

    def test_java_extra(self):
        result, commands = self.tools(extras='java')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands[-1], f'mise[{CONFIG}] install java@21')
        self.assertNotIn('upstream rustup', commands)

    def test_rust_extra_installs_rustup_when_absent(self):
        result, commands = self.tools(extras='rust')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands[-1], 'upstream rustup')

    def test_rust_extra_updates_existing_rustup(self):
        mocks = self.MISE + '\nrustup() { printf "rustup %s\\n" "$*" >> "$CMD_LOG"; }'
        result, commands = self.tools(mocks=mocks, extras='rust')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(commands[-1], 'rustup toolchain install stable --profile minimal')

    def test_failing_mise_install_propagates(self):
        result, commands = self.tools(mocks='mise() { return 7; }')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, ['pkg_install dotnet-sdk-10.0'])


if __name__ == '__main__':
    unittest.main()
