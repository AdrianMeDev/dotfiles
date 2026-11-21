#!/usr/bin/env python3
"""Tests for scripts/apps.sh with mocked installers, package manager, mise and ollama; nothing is installed."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_tools import CONFIG, ModuleTestCase  # noqa: E402

CLAUDE = 'upstream claude https://claude.ai/install.sh bash'
PI_INSTALL = f'mise[{CONFIG}] exec -- npm install -g @earendil-works/pi-coding-agent'
PI_RESHIM = f'mise[{CONFIG}] reshim'
OLLAMA = 'upstream ollama https://ollama.com/install.sh sh'
PULL = 'ollama pull qwen2.5-coder:7b-base'
MOCKS = '''
# Installing ollama (package or upstream script) makes the binary available, like the real thing.
upstream_installer() { printf "upstream %s %s %s\\n" "$1" "$2" "$3" >> "$CMD_LOG"; [[ $1 != ollama ]] || ollama() { printf "ollama %s\\n" "$*" >> "$CMD_LOG"; }; }
pkg_install() { printf "pkg_install %s\\n" "$*" >> "$CMD_LOG"; ollama() { printf "ollama %s\\n" "$*" >> "$CMD_LOG"; }; }
mise() { printf "mise[%s] %s\\n" "${MISE_GLOBAL_CONFIG_FILE:-}" "$*" >> "$CMD_LOG"; }
install_wezterm() { printf "wezterm\\n" >> "$CMD_LOG"; }
'''


class AppsTests(ModuleTestCase):
    def apps(self, mocks='', **kwargs):
        # Only functions defined here count as installed binaries, never host ones.
        isolated = 'have() { declare -F "$1" >/dev/null 2>&1; }\n' + MOCKS + mocks
        return self.call('install_apps', isolated, **kwargs)

    def ok(self, *args, **kwargs):
        result, commands = self.apps(*args, **kwargs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result, commands

    def test_desktop_installs_agents_and_gui_apps(self):
        _, commands = self.ok()
        self.assertEqual(commands, [CLAUDE, PI_INSTALL, PI_RESHIM, 'wezterm',
                                    'upstream zed https://zed.dev/install.sh sh'])

    def test_headless_installs_cli_agents_only(self):
        result, commands = self.ok(profile='headless')
        self.assertEqual(commands, [CLAUDE, PI_INSTALL, PI_RESHIM])
        self.assertIn('headless', result.stdout)

    def test_installed_agents_are_kept(self):
        _, commands = self.ok(mocks='claude() { :; }\npi() { :; }', profile='headless')
        self.assertEqual(commands, [])

    def test_installed_claude_does_not_skip_pi(self):
        _, commands = self.ok(mocks='claude() { :; }', profile='headless')
        self.assertEqual(commands, [PI_INSTALL, PI_RESHIM])

    def test_no_ollama_without_extra(self):
        for family in ('arch', 'fedora', 'debian'):
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                _, commands = self.ok(profile='headless', family=family)
                self.assertFalse([c for c in commands if 'ollama' in c], commands)

    def test_ollama_extra_uses_package_on_arch(self):
        _, commands = self.ok(profile='headless', extras='ollama', family='arch')
        self.assertEqual(commands[3:], ['pkg_install ollama'])

    def test_ollama_extra_uses_upstream_installer_elsewhere(self):
        for family in ('fedora', 'debian'):
            with self.subTest(family=family):
                self.log.unlink(missing_ok=True)
                _, commands = self.ok(profile='headless', extras='ollama', family=family)
                self.assertEqual(commands[3:], [OLLAMA])

    def test_ollama_extra_does_not_pull_models(self):
        _, commands = self.ok(profile='headless', extras='ollama')
        self.assertNotIn(PULL, commands)

    def test_ollama_models_extra_installs_and_pulls(self):
        _, commands = self.ok(profile='headless', extras='ollama,ollama-models')
        self.assertEqual(commands[3:], [OLLAMA, PULL])

    def test_ollama_models_extra_alone_installs_ollama(self):
        _, commands = self.ok(profile='headless', extras='ollama-models', family='arch')
        self.assertEqual(commands[3:], ['pkg_install ollama', PULL])

    def test_installed_ollama_is_kept_but_models_are_pulled(self):
        mocks = 'ollama() { printf "ollama %s\\n" "$*" >> "$CMD_LOG"; }'
        _, commands = self.ok(mocks=mocks, profile='headless', extras='ollama-models')
        self.assertEqual(commands[3:], [PULL])

    def test_models_come_from_environment_override(self):
        _, commands = self.ok(mocks='OLLAMA_MODELS="a:1 b:2"', profile='headless', extras='ollama-models')
        self.assertEqual(commands[-2:], ['ollama pull a:1', 'ollama pull b:2'])

    def test_extras_apply_to_desktop_too(self):
        _, commands = self.ok(mocks='zeditor() { :; }', extras='ollama-models', family='arch')
        self.assertIn('pkg_install ollama', commands)
        self.assertIn(PULL, commands)
        self.assertIn('wezterm', commands)

    def test_dry_run_executes_nothing(self):
        result, commands = self.ok(dry_run=1, extras='ollama-models', family='arch')
        # Installers are mocked and still logged; mise and ollama must never run.
        self.assertFalse([c for c in commands if c.startswith(('mise', 'ollama '))], commands)
        self.assertIn('mise exec -- npm install -g @earendil-works/pi-coding-agent', result.stdout)
        self.assertIn('ollama pull qwen2.5-coder:7b-base', result.stdout)
        self.assertFalse(list(self.base.glob('dotfiles.*')))

    def test_failing_pi_install_propagates(self):
        result, commands = self.apps(mocks='mise() { return 7; }', profile='headless')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [CLAUDE])

    def test_failing_claude_installer_propagates(self):
        result, commands = self.apps(mocks='upstream_installer() { return 5; }', profile='headless')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])

    def test_failing_model_pull_propagates(self):
        result, _ = self.apps(mocks='ollama() { return 9; }', profile='headless', extras='ollama-models')
        self.assertNotEqual(result.returncode, 0)

    def test_failing_ollama_installer_propagates(self):
        mocks = 'upstream_installer() { [[ $1 != ollama ]] || return 4; }'
        result, _ = self.apps(mocks=mocks, profile='headless', extras='ollama')
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
