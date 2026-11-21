#!/usr/bin/env python3
"""Unit tests for manifests/packages.tsv and scripts/pkg.sh."""
from pathlib import Path
import re
import shutil
import subprocess
import unittest

REPO = Path(__file__).resolve().parents[1]
PKG_SH = REPO / 'scripts' / 'pkg.sh'
MANIFEST = REPO / 'manifests' / 'packages.tsv'
NAME_RE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9+._-]*$')


def manifest_rows():
    rows = []
    for line in MANIFEST.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        rows.append(line.split('\t'))
    return rows


class PkgTests(unittest.TestCase):
    def setUp(self):
        self.bash = shutil.which('bash') or '/bin/bash'

    def run_pkg(self, body):
        return subprocess.run(
            [self.bash, '-c', f'source "{PKG_SH}"\n{body}'],
            cwd=REPO,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def resolve(self, family, profile):
        res = self.run_pkg(f'pkg_resolve {family} {profile}')
        self.assertEqual(res.returncode, 0, res.stderr)
        return res.stdout.split()

    def test_manifest_shape(self):
        rows = manifest_rows()
        self.assertTrue(rows)
        names = [row[0] for row in rows]
        self.assertEqual(len(names), len(set(names)), 'duplicate logical names')
        for row in rows:
            with self.subTest(name=row[0]):
                self.assertEqual(len(row), 5, row)
                self.assertTrue(all(cell.strip() == cell and cell for cell in row), row)
                self.assertIn(row[1], ('base', 'desktop', 'dev'))
                for cell in row[2:]:
                    if cell == '-':
                        continue
                    for pkg in cell.split(','):
                        self.assertRegex(pkg, NAME_RE)

    def test_fedora_desktop_has_no_duplicates(self):
        resolved = self.resolve('fedora', 'desktop')
        self.assertEqual(len(resolved), len(set(resolved)))

    def test_dev_rows_are_not_in_profile_install(self):
        for family in ('arch', 'fedora', 'debian'):
            for profile in ('headless', 'desktop'):
                resolved = self.resolve(family, profile)
                self.assertNotIn('dotnet-sdk-10.0', resolved)
                self.assertNotIn('wezterm', resolved)
                self.assertNotIn('zed', resolved)
                self.assertNotIn('ollama', resolved)
        for family, expected in (('arch', ['ollama']), ('fedora', []), ('debian', [])):
            with self.subTest(package='ollama', family=family):
                res = self.run_pkg(f'pkg_names ollama {family}')
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assertEqual(res.stdout.split(), expected)
        res =self.run_pkg('pkg_names dotnet-sdk fedora; pkg_names wezterm fedora')
        self.assertEqual(res.stdout.split(), ['dotnet-sdk-10.0', 'wezterm'])
        for family, expected in (('arch', ['zed']), ('fedora', []), ('debian', [])):
            with self.subTest(family=family):
                res = self.run_pkg(f'pkg_names zed {family}')
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assertEqual(res.stdout.split(), expected)

    def test_headless_excludes_desktop_rows(self):
        rows = manifest_rows()
        self.assertTrue(any(r[1] == 'desktop' for r in rows))
        for family, col in (('arch', 2), ('fedora', 3), ('debian', 4)):
            with self.subTest(family=family):
                # '-' marks a package that is unavailable on this family and must be skipped.
                base = {p for r in rows if r[1] == 'base' for p in r[col].split(',') if p != '-'}
                full = {p for r in rows if r[1] != 'dev' for p in r[col].split(',') if p != '-'}
                self.assertEqual(set(self.resolve(family, 'headless')), base)
                self.assertEqual(set(self.resolve(family, 'desktop')), full)

    def test_family_specific_names(self):
        arch = self.resolve('arch', 'headless')
        fedora = self.resolve('fedora', 'headless')
        debian = self.resolve('debian', 'headless')
        self.assertIn('xz', arch)
        self.assertIn('xz', fedora)
        self.assertIn('xz-utils', debian)
        self.assertIn('pkgconf', arch)
        self.assertIn('pkgconf-pkg-config', fedora)
        self.assertIn('pkg-config', debian)
        self.assertIn('base-devel', arch)
        self.assertTrue({'gcc', 'gcc-c++', 'make'} <= set(fedora))
        self.assertIn('build-essential', debian)
        self.assertIn('libssl-dev', debian)
        self.assertIn('openssl-devel', fedora)

    def test_pkg_names(self):
        res = self.run_pkg('pkg_names base-devel fedora')
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(res.stdout.split(), ['gcc', 'gcc-c++', 'make'])
        res = self.run_pkg('DISTRO_FAMILY=debian pkg_names xz')
        self.assertEqual(res.stdout.split(), ['xz-utils'])
        res = self.run_pkg('pkg_names does-not-exist arch')
        self.assertNotEqual(res.returncode, 0)

    def test_dash_cells_are_skipped(self):
        res = self.run_pkg(
            'tmp=$(mktemp); printf "a\\tbase\\t-\\tfoo,bar\\tbaz\\n" > "$tmp"; '
            'PKG_MANIFEST=$tmp; pkg_resolve arch headless; echo ---; pkg_resolve fedora headless; rm -f "$tmp"'
        )
        self.assertEqual(res.returncode, 0, res.stderr)
        arch, fedora = res.stdout.split('---')
        self.assertEqual(arch.split(), [])
        self.assertEqual(fedora.split(), ['foo', 'bar'])

    def test_unknown_family_or_profile_fails(self):
        res = self.run_pkg('pkg_resolve gentoo desktop')
        self.assertNotEqual(res.returncode, 0)
        self.assertTrue(res.stderr.strip())
        self.assertEqual(res.stdout, '')
        res = self.run_pkg('pkg_resolve fedora server')
        self.assertNotEqual(res.returncode, 0)


class PkgCommandTests(unittest.TestCase):
    """Commands per family, with sudo/have/is_wsl mocked (nothing real runs)."""

    PRELUDE = r'''
set +e
CALLS=()
sudo() { CALLS+=("sudo $*"); return "${SUDO_RC:-0}"; }
git() { CALLS+=("git $*"); mkdir -p "${!#}"; }
makepkg() { echo "makepkg $*" >&2; }  # runs in a subshell
paru() { CALLS+=("paru $*"); }
yay() { CALLS+=("yay $*"); }
HAVE=${HAVE:-}
have() { [[ " $HAVE " == *" $1 "* ]]; }
is_wsl() { [[ ${WSL:-0} == 1 ]]; }
DRY_RUN=${DRY_RUN:-0}
dump() { printf '%s\n' "${CALLS[@]}"; }
'''

    def setUp(self):
        self.bash = shutil.which('bash') or '/bin/bash'

    def run_pkg(self, body, env=None):
        import os
        full_env = dict(os.environ, **(env or {}))
        return subprocess.run(
            [self.bash, '-c', f'source "{PKG_SH}"\n{self.PRELUDE}\n{body}'],
            cwd=REPO, stdin=subprocess.DEVNULL, capture_output=True,
            text=True, timeout=10, env=full_env,
        )

    def calls(self, body, env=None):
        res = self.run_pkg(body, env)
        self.assertEqual(res.returncode, 0, res.stderr)
        return [l for l in res.stdout.splitlines() if not l.startswith('  +') and l.strip()]

    def test_install_per_family(self):
        self.assertEqual(
            self.calls('DISTRO_FAMILY=arch; pkg_install git jq >/dev/null; dump'),
            ['sudo pacman -S --needed --noconfirm git jq'])
        self.assertEqual(
            self.calls('DISTRO_FAMILY=fedora; pkg_install git jq >/dev/null; dump'),
            ['sudo dnf install -y git jq'])
        self.assertEqual(
            self.calls('DISTRO_FAMILY=debian; pkg_install git jq >/dev/null; dump'),
            ['sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y git jq'])

    def test_upgrade_per_family(self):
        self.assertEqual(self.calls('DISTRO_FAMILY=arch; pkg_upgrade >/dev/null; dump'),
                         ['sudo pacman -Syu --noconfirm'])
        self.assertEqual(self.calls('DISTRO_FAMILY=fedora; pkg_upgrade >/dev/null; dump'),
                         ['sudo dnf upgrade --refresh -y'])
        self.assertEqual(
            self.calls('DISTRO_FAMILY=fedora; pkg_upgrade >/dev/null; dump', {'WSL': '1'}),
            ["sudo dnf upgrade --refresh -y --exclude=kernel*"])
        self.assertEqual(
            self.calls('DISTRO_FAMILY=debian; pkg_upgrade >/dev/null; dump'),
            ['sudo env DEBIAN_FRONTEND=noninteractive apt-get update',
             'sudo env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y'])

    def test_upgrade_aur(self):
        self.assertEqual(
            self.calls('DISTRO_FAMILY=arch; pkg_upgrade_aur >/dev/null; dump', {'HAVE': 'paru yay'}),
            ['paru -Sua --noconfirm'])
        self.assertEqual(
            self.calls('DISTRO_FAMILY=arch; pkg_upgrade_aur >/dev/null; dump', {'HAVE': 'yay'}),
            ['yay -Sua --noconfirm'])
        self.assertEqual(self.calls('DISTRO_FAMILY=arch; pkg_upgrade_aur; dump', {'HAVE': ''}), [])
        self.assertEqual(self.calls('DISTRO_FAMILY=fedora; pkg_upgrade_aur; dump', {'HAVE': 'paru'}), [])

    def test_upgrade_aur_dry_run_executes_nothing(self):
        res = self.run_pkg('DISTRO_FAMILY=arch; pkg_upgrade_aur; dump', {'HAVE': 'paru', 'DRY_RUN': '1'})
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn('+ paru -Sua --noconfirm', res.stdout)
        self.assertEqual([l for l in res.stdout.splitlines() if l.startswith('paru ')], [])

    def test_aur_split_from_fixture_manifest(self):
        body = (
            'tmp=$(mktemp); printf "a\\tbase\\tgit\\tgit\\tgit\\nb\\tbase\\taur:foo-bin\\t-\\t-\\n" > "$tmp"; '
            'PKG_MANIFEST=$tmp; pkg_install_manifest arch headless >/dev/null; rm -f "$tmp"; dump'
        )
        self.assertEqual(self.calls(body, {'HAVE': 'paru'}),
                         ['sudo pacman -S --needed --noconfirm git',
                          'paru -S --needed --noconfirm foo-bin'])

    def test_aur_prefix_rejected_off_arch(self):
        res = self.run_pkg('DISTRO_FAMILY=fedora; pkg_install aur:foo')
        self.assertNotEqual(res.returncode, 0)

    def test_aur_helper_order(self):
        self.assertEqual(self.run_pkg('pkg_aur_helper', {'HAVE': 'paru yay'}).stdout.strip(), 'paru')
        self.assertEqual(self.run_pkg('pkg_aur_helper', {'HAVE': 'yay'}).stdout.strip(), 'yay')
        self.assertNotEqual(self.run_pkg('pkg_aur_helper', {'HAVE': ''}).returncode, 0)

    def test_yay_used_when_no_paru(self):
        self.assertEqual(
            self.calls('DISTRO_FAMILY=arch; pkg_install aur:foo >/dev/null; dump', {'HAVE': 'yay'}),
            ['yay -S --needed --noconfirm foo'])

    def test_bootstrap_via_pacman(self):
        body = ('pkg_available() { return 0; }; DISTRO_FAMILY=arch; '
                'pkg_ensure_aur_helper >/dev/null; echo "H=$PKG_AUR_HELPER"; dump')
        self.assertEqual(self.calls(body),
                         ['H=paru', 'sudo pacman -S --needed --noconfirm paru'])

    def test_bootstrap_via_makepkg(self):
        body = ('pkg_available() { return 1; }; DISTRO_FAMILY=arch; '
                'pkg_ensure_aur_helper >/dev/null; echo "H=$PKG_AUR_HELPER"; dump; '
                'rm -rf "$WORK_DIR"')
        res = self.run_pkg(body, {'HAVE': 'git makepkg pacman'})
        self.assertEqual(res.returncode, 0, res.stderr)
        out = [l for l in res.stdout.splitlines() if not l.startswith('  +') and l.strip()]
        self.assertEqual(out[0], 'H=paru')
        self.assertTrue(out[1].startswith('git clone https://aur.archlinux.org/paru-bin.git '))
        self.assertEqual(len(out), 2)
        self.assertIn('makepkg -si --noconfirm --needed', res.stderr)

    def test_dry_run_executes_nothing(self):
        body = ('DISTRO_FAMILY=arch; pkg_install git aur:foo; pkg_upgrade; '
                'echo "W=${WORK_DIR:-unset}"; dump')
        res = self.run_pkg(body, {'DRY_RUN': '1'})
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn('W=unset', res.stdout)
        executed = [l for l in res.stdout.splitlines() if l.startswith(('sudo ', 'paru ', 'git ', 'makepkg '))]
        self.assertEqual(executed, [])
        self.assertIn('sudo pacman -S --needed --noconfirm git', res.stdout)

    def test_failure_status_propagates(self):
        for family in ('arch', 'fedora', 'debian'):
            with self.subTest(family=family):
                res = self.run_pkg(f'DISTRO_FAMILY={family}; pkg_install git >/dev/null; echo "rc=$?"',
                                   {'SUDO_RC': '7'})
                self.assertIn('rc=7', res.stdout)
                res = self.run_pkg(f'DISTRO_FAMILY={family}; pkg_upgrade >/dev/null; echo "rc=$?"',
                                   {'SUDO_RC': '5'})
                self.assertIn('rc=5', res.stdout)

    def test_pkg_need(self):
        for family, tool in (('arch', 'pacman'), ('fedora', 'dnf'), ('debian', 'apt-get')):
            with self.subTest(family=family):
                ok = self.run_pkg(f'pkg_need {family}', {'HAVE': tool})
                self.assertEqual(ok.returncode, 0, ok.stderr)
                bad = self.run_pkg(f'pkg_need {family}', {'HAVE': ''})
                self.assertNotEqual(bad.returncode, 0)


if __name__ == '__main__':
    unittest.main()
