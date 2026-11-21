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
        self.log = Path(temp.name) / 'calls.log'
        self.engine = Path(temp.name) / 'engine'
        self.engine.write_text(
            '#!/usr/bin/env bash\n'
            'printf "%s\\n" "$*" >> "$STUB_LOG"\n'
            '[[ -z ${STUB_FAIL:-} || " $* " != *" $STUB_FAIL"* ]]\n'
        )
        self.engine.chmod(0o755)

    def run_matrix(self, *args, fail=''):
        env = dict(os.environ, CONTAINER_ENGINE=str(self.engine), STUB_LOG=str(self.log), STUB_FAIL=fail)
        return subprocess.run(
            [shutil.which('bash') or '/bin/bash', str(SCRIPT), *args],
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
            self.assertIn(f'run --rm -v {REPO}:/dotfiles:ro,z {image}', call)
            self.assertTrue(call.endswith(f'scripts/container-entry.sh {distro}'), call)

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


if __name__ == '__main__':
    unittest.main(verbosity=2)
