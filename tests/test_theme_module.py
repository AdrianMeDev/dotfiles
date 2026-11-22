#!/usr/bin/env python3
"""Exercise the theme installer without accessing the host desktop."""
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import tomllib
import unittest
import zlib

REPO = Path(__file__).resolve().parents[1]


class ThemeModuleTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='dotfiles-theme-')
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.home = self.base / 'home'
        self.home.mkdir()
        (self.base / 'etc').mkdir()

    def preview(self, distro, profile, wsl=False):
        (self.base / 'etc/os-release').write_text(f'ID={distro}\n')
        env = dict(PATH=os.environ['PATH'], HOME=str(self.home), DOTFILES_SYSROOT=str(self.base))
        if wsl:
            env['WSL_INTEROP'] = 'test'
        return subprocess.run([REPO / 'install.sh', '--dry-run', '--only', 'theme', '--profile', profile],
                              env=env, capture_output=True, text=True, check=True).stdout

    def test_desktop_preview(self):
        for distro, package in [('arch', 'adw-gtk-theme'), ('fedora', 'adw-gtk3-theme')]:
            with self.subTest(distro=distro):
                output = self.preview(distro, 'desktop')
                for name in (package, 'papirus-icon-theme', 'qt5ct', 'qt6ct', 'kvantum'):
                    self.assertIn(name, output)
                self.assertIn('bibata-cursor-theme-bin' if distro == 'arch' else
                              'Bibata-Modern-Classic.tar.xz', output)
                for setting in ('color-scheme prefer-dark', 'gtk-theme adw-gtk3-dark',
                                'icon-theme Papirus-Dark', 'cursor-theme Bibata-Modern-Classic',
                                'cursor-size 24'):
                    self.assertIn('gsettings set org.gnome.desktop.interface ' + setting, output)
                self.assertIn(str(self.home / '.local/share/dotfiles/wallpaper.png'), output)
                self.assertIn(f'install -D -m 0644 {REPO}/theme/gtk-3.0/settings.ini {self.home}/.config/gtk-3.0/settings.ini', output)
                self.assertEqual(list(self.home.iterdir()), [])

    def apply(self, gsettings, extra=''):
        """Run install_theme for real with stubbed packages; gsettings: None, 'noschema' or 'schema'."""
        bin_dir = self.base / 'bin'
        bin_dir.mkdir(exist_ok=True)
        calls = self.base / 'gsettings.log'
        if gsettings:
            schemas = 'org.gnome.desktop.interface' if gsettings == 'schema' else 'org.example.other'
            fake = bin_dir / 'gsettings'
            fake.write_text(f'#!/usr/bin/env bash\n[[ $1 == list-schemas ]] && {{ echo {schemas}; exit 0; }}\n'
                            f'echo "$*" >> {calls}\n')
            fake.chmod(0o755)
        script = (f'set -Eeuo pipefail; REPO_DIR={REPO}; PROFILE=desktop; DISTRO_FAMILY=arch; DRY_RUN=0; {extra}\n'
                  f'PKG_MANIFEST={REPO}/manifests/packages.tsv\n'
                  f'source {REPO}/scripts/common.sh; source {REPO}/scripts/pkg.sh; source {REPO}/scripts/theme.sh\n'
                  'is_wsl() { return 1; }; pkg_install() { :; }\n'
                  + ('have() { [[ $1 == gsettings ]] || command -v "$1" >/dev/null; }\n' if gsettings else
                     'have() { [[ $1 != gsettings ]] && command -v "$1" >/dev/null; }\n')
                  + 'install_theme\n')
        env = dict(PATH=f'{bin_dir}:{os.environ["PATH"]}', HOME=str(self.home))
        output = subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True, check=True).stdout
        self.assertTrue((self.home / '.local/share/dotfiles/wallpaper.png').is_file())
        return output, calls.read_text().splitlines() if calls.exists() else []

    def test_gsettings_missing(self):
        for mode in (None, 'noschema'):
            with self.subTest(mode=mode):
                output, calls = self.apply(mode)
                self.assertIn('GTK-Einstellungen übersprungen', output)
                self.assertEqual(calls, [])

    def test_gsettings_applied(self):
        output, calls = self.apply('schema')
        self.assertNotIn('übersprungen', output)
        self.assertEqual(len(calls), 5)
        self.assertIn('set org.gnome.desktop.interface cursor-size 24', calls)

    def gtk_files(self):
        return [(v, f) for v in (3, 4) for f in ('settings.ini', 'gtk.css')]

    def test_gtk_missing_is_copied(self):
        self.apply(None)
        for v, f in self.gtk_files():
            target = self.home / f'.config/gtk-{v}.0/{f}'
            self.assertFalse(target.is_symlink())
            self.assertEqual(target.read_bytes(), (REPO / f'theme/gtk-{v}.0/{f}').read_bytes())

    def test_gtk_old_symlink_is_replaced(self):
        folder = self.home / '.config/gtk-3.0'
        folder.mkdir(parents=True)
        (folder / 'settings.ini').symlink_to(self.home / 'dotfiles/hypr/.config/gtk-3.0/settings.ini')
        self.apply(None)
        self.assertFalse((folder / 'settings.ini').is_symlink())
        self.assertEqual((folder / 'settings.ini').read_bytes(), (REPO / 'theme/gtk-3.0/settings.ini').read_bytes())

    def test_gtk_identical_is_skipped(self):
        self.apply(None)
        target = self.home / '.config/gtk-4.0/gtk.css'
        mtime = target.stat().st_mtime_ns
        output, _ = self.apply(None)
        self.assertEqual(target.stat().st_mtime_ns, mtime)
        self.assertNotIn('weicht ab', output)

    def test_gtk_different_is_kept_unless_backup(self):
        target = self.home / '.config/gtk-3.0/settings.ini'
        target.parent.mkdir(parents=True)
        target.write_text('[Settings]\ngtk-font-name=Noto Sans\n')
        output, _ = self.apply(None)
        self.assertEqual(target.read_text(), '[Settings]\ngtk-font-name=Noto Sans\n')
        self.assertIn('weicht ab', output)
        self.assertIn('--backup', output)
        self.assertFalse((self.home / '.local/state').exists())
        self.apply(None, 'BACKUP=1')
        self.assertEqual(target.read_bytes(), (REPO / 'theme/gtk-3.0/settings.ini').read_bytes())
        saved = list((self.home / '.local/state/dotfiles/backups').glob('gtk-*/gtk-3.0/settings.ini'))
        self.assertEqual([p.read_text() for p in saved], ['[Settings]\ngtk-font-name=Noto Sans\n'])

    def test_skip(self):
        for args in [('fedora', 'headless'), ('debian', 'desktop'), ('arch', 'desktop', True)]:
            with self.subTest(args=args):
                output = self.preview(*args)
                self.assertIn('übersprungen', output)
                self.assertNotIn('  +', output)
                self.assertEqual(list(self.home.iterdir()), [])

    def test_wallpaper(self):
        def generate(path):
            subprocess.run([sys.executable, REPO / 'scripts/wallpaper.py', path], check=True)

        first, second = self.base / 'one/image.png', self.base / 'two.png'
        generate(first)
        generate(second)
        png = first.read_bytes()
        self.assertEqual(png, second.read_bytes())
        self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
        width, height = struct.unpack_from('>II', png, 16)
        length, kind = struct.unpack_from('>I4s', png, 33)
        self.assertEqual(kind, b'IDAT')
        pixels = zlib.decompress(png[41:41 + length])
        self.assertEqual(len(pixels), height * (1 + width * 3))
        palette = tomllib.loads((REPO / 'theme/tokens.toml').read_text())['palette']

        def pixel(x, y):
            start = y * (1 + width * 3) + 1 + x * 3
            return pixels[start:start + 3]

        def distance(colour, key):
            return sum((a - b) ** 2 for a, b in zip(colour, bytes.fromhex(palette[key][1:])))

        # The accent glows must be visible so translucent windows show them.
        for key, x, y in [('blue', 0.15, 0.25), ('magenta', 0.85, 0.75)]:
            with self.subTest(glow=key):
                colour = pixel(int(x * width), int(y * height))
                self.assertLess(distance(colour, key), distance(bytes.fromhex(palette['bg_dark'][1:]), key))
                self.assertGreater(distance(colour, 'bg_dark'), 40 ** 2)
        first.write_bytes(b'custom wallpaper')
        before = first.stat()
        generate(first)
        self.assertEqual(first.read_bytes(), b'custom wallpaper')
        self.assertEqual(first.stat().st_mtime_ns, before.st_mtime_ns)
