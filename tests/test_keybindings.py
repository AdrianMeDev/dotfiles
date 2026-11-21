#!/usr/bin/env python3
"""Tests for the keybinding contract and its GlazeWM parity."""
from pathlib import Path
import re
import unittest

REPO = Path(__file__).resolve().parents[1]
CONTRACT = REPO / 'manifests/keybindings.tsv'
GLAZEWM = REPO / 'windows/glazewm/config.yaml'
WEZTERM_CONFIGS = (
    REPO / 'wezterm/.config/wezterm/wezterm.lua',
    REPO / 'windows/wezterm/wezterm.lua',
)
COMBO = re.compile(r'^(win\+)?(ctrl\+)?(alt\+)?(shift\+)?[a-z0-9]+$')
EXTERNAL = ('os:', 'flow:')
MOD_ORDER = ('win', 'ctrl', 'alt', 'shift')
WEZTERM_MODS = {'super': 'win', 'win': 'win', 'ctrl': 'ctrl', 'alt': 'alt', 'shift': 'shift'}


def load_contract():
    rows = []
    for line in CONTRACT.read_text(encoding='utf-8').splitlines():
        if line.strip() and not line.startswith('#'):
            rows.append(line.split('\t'))
    return rows


def parse_glazewm(text):
    """Return {(mode, combo): command} from the GlazeWM config (line based, no YAML dependency)."""
    found = {}
    mode = None
    in_keybindings = False
    command = None
    for line in text.splitlines():
        if re.match(r'^\S', line):
            in_keybindings = line.startswith('keybindings:')
            mode = 'global' if in_keybindings else None
            if line.startswith('binding_modes:'):
                mode = ''
            continue
        name = re.match(r'^\s*- name: (\S+)\s*$', line)
        if name and mode is not None and not in_keybindings:
            mode = name.group(1)
        cmd = re.match(r"^\s*- commands: \['(.*)'\]\s*$", line)
        if cmd and mode:
            command = cmd.group(1)
        binds = re.match(r"^\s*bindings: \[(.*)\]\s*$", line)
        if binds and mode and command is not None:
            for combo in re.findall(r"'([^']+)'", binds.group(1)):
                key = (mode, combo.replace('lalt', 'alt').replace('ralt', 'alt'))
                assert key not in found, f'duplicate GlazeWM binding {key}'
                found[key] = command
            command = None
    return found


def normalize_wezterm_combo(key, mods_text):
    """Normalize a WezTerm key and pipe-separated mods string to the contract combo format."""
    mods = {WEZTERM_MODS[m.strip().lower()] for m in mods_text.split('|') if m.strip()}
    if len(key) == 1 and key.isupper():
        mods.add('shift')
    ordered = [m for m in MOD_ORDER if m in mods]
    return '+'.join([*ordered, key.lower()])


def parse_wezterm(text):
    """Return normalized combos from `{ key = '…', mods = '…' }` entries in a WezTerm config."""
    combos = []
    for line in text.splitlines():
        key_match = re.search(r"\bkey\s*=\s*['\"]([^'\"]+)['\"]", line)
        if not key_match:
            continue
        mods_match = re.search(r"\bmods\s*=\s*['\"]([^'\"]+)['\"]", line)
        combos.append(normalize_wezterm_combo(key_match.group(1), mods_match.group(1) if mods_match else ''))
    return combos


class KeybindingTests(unittest.TestCase):
    def test_schema(self):
        rows = load_contract()
        self.assertTrue(rows)
        for row in rows:
            self.assertEqual(len(row), 4, row)
            action, mode, combo, windows = row
            self.assertRegex(action, r'^[a-z0-9-]+$')
            self.assertRegex(mode, r'^[a-z]+$')
            self.assertRegex(combo, COMBO, row)
            self.assertTrue(windows, row)
            if windows.startswith(EXTERNAL):
                self.assertRegex(windows.split(':', 1)[1], COMBO, row)
        actions = [r[0] for r in rows]
        self.assertEqual(len(actions), len(set(actions)), 'duplicate actions')
        combos = [(r[1], r[2]) for r in rows]
        self.assertEqual(len(combos), len(set(combos)), 'duplicate combos per mode')

    def test_required_actions(self):
        actions = {r[0] for r in load_contract()}
        required = {'close', 'terminal', 'launcher', 'resize-mode', 'fullscreen', 'floating', 'reload',
                    'pause', 'lock', 'clipboard-history', 'screenshot'}
        for n in range(1, 10):
            required |= {f'focus-workspace-{n}', f'move-workspace-{n}'}
        for d, vim in (('left', 'h'), ('down', 'j'), ('up', 'k'), ('right', 'l')):
            required |= {f'{verb}-{d}-{key}' for verb in ('focus', 'move') for key in (vim, d)}
        self.assertFalse(required - actions, required - actions)

    def test_launcher_is_alt_space(self):
        launcher = {r[0]: r for r in load_contract()}['launcher']
        self.assertEqual(launcher[2:], ['alt+space', 'flow:alt+space'])

    def test_glazewm_parity(self):
        glaze = parse_glazewm(GLAZEWM.read_text(encoding='utf-8'))
        owned = {(m, c): w for _, m, c, w in load_contract() if not w.startswith(EXTERNAL)}
        for key, command in owned.items():
            self.assertIn(key, glaze, f'contract row {key} not bound in GlazeWM')
            self.assertEqual(glaze[key], command, key)
        self.assertEqual(sorted(set(glaze) - set(owned)), [], 'GlazeWM binding outside the contract')

    def test_external_rows_not_bound_in_glazewm(self):
        glaze = parse_glazewm(GLAZEWM.read_text(encoding='utf-8'))
        for _, mode, combo, windows in load_contract():
            if windows.startswith(EXTERNAL):
                self.assertNotIn((mode, combo), glaze)

    def test_wezterm_no_collision_with_reserved_combos(self):
        reserved = set()
        for _, mode, combo, windows in load_contract():
            if mode != 'global':
                continue
            reserved.add(combo)
            if windows.startswith(EXTERNAL):
                reserved.add(windows.split(':', 1)[1])

        for path in WEZTERM_CONFIGS:
            combos = parse_wezterm(path.read_text(encoding='utf-8'))
            collisions = sorted(set(combos) & reserved)
            self.assertEqual(collisions, [], f'{path.relative_to(REPO)} collides with reserved combos: {collisions}')


if __name__ == '__main__':
    unittest.main()
