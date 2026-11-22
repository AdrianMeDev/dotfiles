#!/usr/bin/env python3
"""Tests for scripts/container-matrix.sh using a stub container engine."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'scripts' / 'container-matrix.sh'
IMAGES = {
    'arch': 'docker.io/library/archlinux:latest',
    'fedora': 'docker.io/library/fedora:latest',
    'debian': 'docker.io/library/debian:stable',
}


class ContainerMatrixTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='dotfiles-matrix-')
        self.addCleanup(temp.cleanup)
        self.repo = Path(temp.name) / 'repo'
        (self.repo / 'scripts').mkdir(parents=True)
        (self.repo / '.git').mkdir()
        self.script = self.repo / 'scripts/container-matrix.sh'
        shutil.copyfile(SCRIPT, self.script)
        self.log = Path(temp.name) / 'calls.log'
        self.engine = Path(temp.name) / 'engine'
        self.engine.write_text(
            '#!/usr/bin/env bash\n'
            'printf "%s\\n" "$*" >> "$STUB_LOG"\n'
            '[[ -z ${STUB_FAIL:-} || " $* " != *" $STUB_FAIL"* ]]\n'
        )
        self.engine.chmod(0o755)

    def run_matrix(self, *args, fail='', token=None):
        env = dict(os.environ, CONTAINER_ENGINE=str(self.engine), STUB_LOG=str(self.log), STUB_FAIL=fail)
        env.pop('GITHUB_TOKEN', None)
        if token is not None:
            env['GITHUB_TOKEN'] = token
        return subprocess.run(
            [shutil.which('bash') or '/bin/bash', str(self.script), *args],
            env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30,
        )

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_default_runs_every_distro(self):
        res = self.run_matrix()
        self.assertEqual(res.returncode, 0, res.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 3)
        for call, (distro, image) in zip(calls, IMAGES.items()):
            self.assertIn(f'run --rm -v {self.repo}:/dotfiles:ro,z {image}', call)
            self.assertTrue(call.endswith(f'scripts/container-entry.sh {distro}'), call)

    def test_linked_worktree_mounts_external_git_metadata_read_only(self):
        common = self.repo.parent / 'external.git'
        git_dir = common / 'worktrees/test'
        git_dir.mkdir(parents=True)
        (common / 'objects').mkdir()
        (common / 'refs').mkdir()
        for directory in (common, git_dir):
            (directory / 'HEAD').write_text('ref: refs/heads/main\n')
        (git_dir / 'commondir').write_text('../..\n')
        (self.repo / '.git').rmdir()
        (self.repo / '.git').write_text(f'gitdir: {git_dir}\n')

        res = self.run_matrix('debian')

        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn(f'-v {self.repo}:/dotfiles:ro,z -v {common}:{common}:ro,z',
                      self.calls()[0])

    def test_broken_worktree_fails_before_starting_containers(self):
        (self.repo / '.git').rmdir()
        (self.repo / '.git').write_text(f'gitdir: {self.repo.parent}/missing\n')
        res = self.run_matrix('debian')
        self.assertNotEqual(res.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_github_token_is_forwarded_by_name_only(self):
        res = self.run_matrix('arch', token='secret-value')
        self.assertEqual(res.returncode, 0, res.stderr)
        call = self.calls()[0]
        self.assertIn('run --rm -e GITHUB_TOKEN -v', call)
        self.assertNotIn('secret-value', call)

    def test_no_token_flag_without_github_token(self):
        self.run_matrix('arch')
        self.assertNotIn('GITHUB_TOKEN', self.calls()[0])

    def test_subset(self):
        res = self.run_matrix('debian', 'arch')
        self.assertEqual(res.returncode, 0, res.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 2)
        self.assertIn(IMAGES['debian'], calls[0])
        self.assertIn(IMAGES['arch'], calls[1])

    def test_unknown_distro_fails_without_running(self):
        res = self.run_matrix('arch', 'gentoo')
        self.assertNotEqual(res.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_failure_status_is_propagated(self):
        res = self.run_matrix(fail='fedora')
        self.assertNotEqual(res.returncode, 0)
        self.assertEqual(len(self.calls()), 3)
        self.assertRegex(res.stdout, r'rot\s+fedora')
        self.assertRegex(res.stdout, r'grün\s+arch')

    def test_entry_script_checks_hyprland_steps(self):
        entry = (REPO / 'scripts' / 'container-entry.sh').read_text(encoding='utf-8')
        for link in ('hyprland.lua', 'bindings.lua', 'media.lua'):
            self.assertIn(link, entry)
        for module in ('desktop', 'theme'):
            self.assertIn('--only $module --profile desktop --dry-run', entry)
            self.assertIn(module, entry)
        self.assertIn('hyprland-session.target', entry)
        self.assertIn('if [[ $family != debian ]]', entry)
        # The preview must be compared against a snapshot of $HOME.
        self.assertRegex(entry, r'before=\$\(snapshot\)\n\s+for module in desktop theme')
        for link in ('hyprland.lua', 'bindings.lua', 'media.lua'):
            self.assertTrue((REPO / 'hypr/.config/hypr' / link).is_file())
        self.assertTrue((REPO / 'hypr/.config/systemd/user/hyprland-session.target').is_file())


if __name__ == '__main__':
    unittest.main(verbosity=2)
