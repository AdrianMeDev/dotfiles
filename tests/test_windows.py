"""Portable checks for the WSL wrapper and optional PowerShell behavior suite."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WindowsSetupTests(unittest.TestCase):
    def test_wsl_wrapper_preserves_arguments_and_exit_status(self):
        with tempfile.TemporaryDirectory(prefix="windows wrapper ") as temporary:
            directory = Path(temporary)
            wrapper = directory / "repo with spaces" / "install.sh"
            wrapper.parent.mkdir()
            shutil.copy(ROOT / "windows/install.sh", wrapper)
            capture = directory / "args.json"
            programs = {
                "wslpath": '#!/usr/bin/env python3\nimport os\nprint(os.environ["WINDOWS_TEST_PATH"])\n',
                "powershell.exe": '#!/usr/bin/env python3\nimport json,os,sys\njson.dump(sys.argv[1:],open(os.environ["WINDOWS_TEST_CAPTURE"],"w"))\nsys.exit(17)\n',
            }
            for name, content in programs.items():
                path = directory / name
                path.write_text(content)
                path.chmod(0o755)
            for windows_path in (r"C:\repo with spaces\windows\install.ps1", r"\\wsl.localhost\Fedora\home\user\repo with spaces\windows\install.ps1"):
                env = dict(os.environ, PATH=f"{directory}:{os.environ['PATH']}", WINDOWS_TEST_PATH=windows_path, WINDOWS_TEST_CAPTURE=str(capture))
                result = subprocess.run(["bash", str(wrapper), "-DryRun", "-Distro", "Fedora Test", "-Backup", "-NoAutostart"], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 17, result.stderr)
                self.assertEqual(json.loads(capture.read_text()), ["-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", windows_path, "-DryRun", "-Distro", "Fedora Test", "-Backup", "-NoAutostart"])

    @unittest.skipUnless(shutil.which("pwsh"), "PowerShell fehlt")
    def test_powershell_installer(self):
        result = subprocess.run(["pwsh", "-NoProfile", "-File", str(ROOT / "windows/tests/installer.Tests.ps1")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which("nvim"), "Neovim für Lua-Verhaltenstest fehlt")
    def test_wezterm_windows_domains(self):
        result = subprocess.run(["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", "windows/tests/wezterm.lua"], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_zebar_json(self):
        for name in ("settings.json", "zpack.json"):
            json.loads((ROOT / "windows/zebar" / name).read_text())


if __name__ == "__main__":
    unittest.main()
