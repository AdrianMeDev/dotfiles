#!/usr/bin/env python3
"""Tests for the agent-config renderer and sync."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'scripts/agents.py'
SRC = REPO / 'agent-config'


class AgentsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-agents-')
        self.home = Path(self.temp.name) / 'home with spaces'
        self.home.mkdir()
        self.claude = self.home / '.claude'
        self.pi = self.home / '.pi/agent'
        self.env = {k: v for k, v in os.environ.items() if k not in ('CLAUDE_CONFIG_DIR', 'PI_CODING_AGENT_DIR')}
        self.env['HOME'] = str(self.home)
        self.backups = self.home / '.local/state/dotfiles/backups'

    def tearDown(self):
        self.temp.cleanup()

    def run_agents(self, *args, env=None):
        return subprocess.run([sys.executable, '-B', str(SCRIPT), *args], env=env or self.env,
                              capture_output=True, text=True, check=False)

    def tree(self):
        return sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))

    def backup_count(self):
        return len(list(self.backups.glob('*'))) if self.backups.exists() else 0

    def test_renders_both_targets(self):
        result = self.run_agents()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.claude / 'settings.json').read_bytes(), (SRC / 'claude/settings.json').read_bytes())
        self.assertEqual((self.pi / 'AGENTS.md').read_bytes(), (SRC / 'pi/AGENTS.md').read_bytes())
        self.assertTrue((self.pi / 'prompts/next.md').is_file())
        self.assertEqual((self.pi / 'themes/tokyo-night.json').read_bytes(),
                         (SRC / 'pi/themes/tokyo-night.json').read_bytes())
        self.assertTrue((self.claude / 'skills/explain/SKILL.md').is_file())
        for root in (self.claude, self.pi):
            self.assertEqual(list(root.rglob('claude-frontmatter.txt')), [])

    def test_frontmatter_only_injected_for_claude(self):
        self.run_agents()
        source = (SRC / 'skills/next/SKILL.md').read_text().split('\n', 1)
        extra = (SRC / 'skills/next/claude-frontmatter.txt').read_text()
        self.assertEqual((self.claude / 'skills/next/SKILL.md').read_text(), source[0] + '\n' + extra + source[1])
        self.assertEqual((self.pi / 'skills/next/SKILL.md').read_text(), '\n'.join(source))

    def test_agent_workspace_skill_rendered_for_both_tools(self):
        self.run_agents()
        source = (SRC / 'skills/agent-workspace/SKILL.md').read_text()
        self.assertIn('.agent/', source)
        self.assertEqual((self.pi / 'skills/agent-workspace/SKILL.md').read_text(), source)
        claude = (self.claude / 'skills/agent-workspace/SKILL.md').read_text()
        self.assertIn('user-invocable: false', claude)
        self.assertNotIn('user-invocable', (self.pi / 'skills/agent-workspace/SKILL.md').read_text())
        self.assertEqual(list(self.pi.rglob('claude-frontmatter.txt')), [])

    def test_grill_skill_rendered_for_both_tools(self):
        self.run_agents()
        source = SRC / 'skills/grill'
        self.assertLessEqual(len((source / 'SKILL.md').read_text().splitlines()), 80)
        self.assertIn('_Avoid_', (source / 'GLOSSARY-FORMAT.md').read_text())
        self.assertIn('MIT', (source / 'NOTICE.md').read_text())
        for root in (self.claude, self.pi):
            for name in ('SKILL.md', 'GLOSSARY-FORMAT.md', 'ADR-FORMAT.md', 'NOTICE.md'):
                self.assertTrue((root / 'skills/grill' / name).is_file(), name)
        self.assertIn('model: opus', (self.claude / 'skills/grill/SKILL.md').read_text())
        self.assertNotIn('model:', (self.pi / 'skills/grill/SKILL.md').read_text())
        self.assertTrue((self.pi / 'prompts/grill.md').is_file())

    def test_plan_roadmap_asks_in_grill_rounds(self):
        text = (SRC / 'skills/plan-roadmap/SKILL.md').read_text()
        self.assertIn('`grill`', text)
        self.assertNotIn('at most 6', text)
        self.assertLessEqual(len(text.splitlines()), 110)

    def test_plan_path_is_agent_dir_except_documented_fallback(self):
        self.run_agents()
        markers = ('legacy', 'fallback', 'else', 'old ')
        files = [f for root in (self.claude, self.pi) for sub in ('skills', 'prompts')
                 for f in (root / sub).rglob('*.md')]
        self.assertTrue(files)
        for f in files:
            for n, line in enumerate(f.read_text().splitlines(), 1):
                if 'agent-plan' in line:
                    self.assertTrue(any(m in line for m in markers), f'{f}:{n}: {line}')
        for tool in (self.claude, self.pi):
            self.assertIn('.agent/plan.md', (tool / 'skills/plan-commits/SKILL.md').read_text())
            self.assertIn('.agent/plan.md', (tool / 'skills/next/SKILL.md').read_text())

    def test_git_write_and_tracker_commands_are_denied(self):
        perms = json.loads((SRC / 'claude/settings.json').read_text())['permissions']
        guarded = ['Bash(git %s%s)' % (verb, tail)
                   for verb in ('commit', 'push', 'merge', 'rebase') for tail in ('', ' *')]
        guarded += ['Bash(git -C * %s%s)' % (verb, tail)
                    for verb in ('commit', 'push', 'merge', 'rebase') for tail in ('', ' *')]
        guarded += ['Bash(gh pr create *)', 'Bash(gh pr merge *)', 'Bash(gh issue create *)', 'Bash(glab *)']
        for rule in guarded:
            self.assertIn(rule, perms['deny'])
            self.assertNotIn(rule, perms['allow'])
            self.assertNotIn(rule, perms['ask'])

    def test_env_overrides_targets(self):
        env = dict(self.env, CLAUDE_CONFIG_DIR=str(self.home / 'c'), PI_CODING_AGENT_DIR=str(self.home / 'p'))
        self.assertEqual(self.run_agents(env=env).returncode, 0)
        self.assertTrue((self.home / 'c/CLAUDE.md').is_file())
        self.assertTrue((self.home / 'p/AGENTS.md').is_file())
        self.assertFalse(self.claude.exists())

    def test_second_run_is_idempotent_without_backups(self):
        self.run_agents()
        before = self.tree()
        result = self.run_agents('--backup')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.backup_count(), 0)
        self.assertEqual(self.tree(), before)

    def test_conflict_stops_without_backup(self):
        self.run_agents()
        (self.claude / 'settings.json').write_text('local\n')
        result = self.run_agents()
        self.assertEqual(result.returncode, 1)
        self.assertIn('settings.json', result.stderr)
        self.assertEqual((self.claude / 'settings.json').read_text(), 'local\n')
        self.assertEqual(self.backup_count(), 0)
        self.assertEqual(self.run_agents('--check').returncode, 1)

    def test_backup_replaces_modified_file(self):
        self.run_agents()
        (self.pi / 'settings.json').write_text('local\n')
        result = self.run_agents('--backup')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.pi / 'settings.json').read_bytes(), (SRC / 'pi/settings.json').read_bytes())
        saved = list(self.backups.glob('*/pi/settings.json'))
        self.assertEqual(len(saved), 1)
        self.assertEqual(saved[0].read_text(), 'local\n')
        self.assertEqual(self.backups.stat().st_mode & 0o777, 0o700)
        self.assertEqual(list(self.pi.rglob('*.bak*')), [])

    def test_theme_file_backup_and_idempotency(self):
        self.run_agents()
        theme = self.pi / 'themes/tokyo-night.json'
        theme.write_text('local\n')
        self.assertEqual(self.run_agents().returncode, 1)
        self.assertEqual(theme.read_text(), 'local\n')
        self.assertEqual(self.run_agents('--backup').returncode, 0)
        self.assertEqual(theme.read_bytes(), (SRC / 'pi/themes/tokyo-night.json').read_bytes())
        self.assertEqual(len(list(self.backups.glob('*/pi/themes/tokyo-night.json'))), 1)
        self.assertEqual(self.run_agents('--backup').returncode, 0)
        self.assertEqual(self.backup_count(), 1)

    def test_dry_run_and_check_write_nothing(self):
        for flag in ('--dry-run', '--check', '--status'):
            result = self.run_agents(flag)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.tree(), [])
        self.run_agents()
        (self.claude / 'CLAUDE.md').write_text('local\n')
        before = self.tree()
        result = self.run_agents('--dry-run', '--backup')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tree(), before)
        self.assertEqual((self.claude / 'CLAUDE.md').read_text(), 'local\n')

    def test_symlink_target_is_rejected(self):
        self.claude.mkdir()
        elsewhere = self.home / 'elsewhere'
        elsewhere.write_text('x')
        (self.claude / 'CLAUDE.md').symlink_to(elsewhere)
        result = self.run_agents('--backup')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Symlink', result.stderr)
        self.assertEqual(elsewhere.read_text(), 'x')

    def test_symlinked_root_is_rejected(self):
        real = self.home / 'real'
        real.mkdir()
        self.pi.parent.mkdir(parents=True)
        self.pi.symlink_to(real)
        result = self.run_agents('--backup')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Symlink', result.stderr)
        self.assertEqual(list(real.iterdir()), [])

    def test_legacy_paths_are_retired_with_backup(self):
        legacy = self.pi / 'skills/erklaeren'
        legacy.mkdir(parents=True)
        (legacy / 'SKILL.md').write_text('old\n')
        (self.pi / 'prompts').mkdir()
        (self.pi / 'prompts/plan.md').write_text('old\n')
        self.assertEqual(self.run_agents().returncode, 1)
        self.assertTrue(legacy.exists())
        result = self.run_agents('--backup')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(legacy.exists())
        self.assertFalse((self.pi / 'prompts/plan.md').exists())
        self.assertTrue(list(self.backups.glob('*/pi/skills/erklaeren/SKILL.md')))
        self.assertTrue(list(self.backups.glob('*/pi/prompts/plan.md')))
        self.assertEqual(self.run_agents('--backup').returncode, 0)
        self.assertEqual(self.backup_count(), 1)

    def test_local_next_all_is_kept_and_not_reported(self):
        for root in (self.claude, self.pi):
            (root / 'skills/next-all').mkdir(parents=True)
            (root / 'skills/next-all/SKILL.md').write_text('local\n')
        result = self.run_agents('--backup')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('next-all', result.stdout + result.stderr)
        for root in (self.claude, self.pi):
            self.assertEqual((root / 'skills/next-all/SKILL.md').read_text(), 'local\n')
        self.assertEqual(self.backup_count(), 0)

    def test_status_reports_foreign_skills_but_not_synced(self):
        self.run_agents()
        for name in ('inbox', 'synced'):
            (self.claude / 'skills' / name).mkdir()
        before = self.tree()
        result = self.run_agents('--status')
        self.assertIn('[foreign] claude: skills/inbox', result.stdout)
        self.assertNotIn('synced', result.stdout)
        self.assertNotIn('[foreign] claude: skills/next', result.stdout)
        self.assertEqual(self.tree(), before)
        self.assertEqual(self.run_agents().returncode, 0)

    def test_status_reports_ok_missing_modified(self):
        self.run_agents()
        (self.claude / 'settings.json').write_text('local\n')
        (self.pi / 'AGENTS.md').unlink()
        before = self.tree()
        result = self.run_agents('--status')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('[modified] claude: settings.json', result.stdout)
        self.assertIn('[missing] pi: AGENTS.md', result.stdout)
        self.assertIn('[ok] claude: CLAUDE.md', result.stdout)
        self.assertEqual(self.tree(), before)


if __name__ == '__main__':
    unittest.main()
