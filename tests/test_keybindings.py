#!/usr/bin/env python3
"""Tests for the keybinding contract and its GlazeWM parity."""
import json
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
ZED_KEYMAP = REPO / 'zed-config/.config/zed/keymap.json'
COMBO = re.compile(r'^(win\+)?(ctrl\+)?(alt\+)?(shift\+)?[a-z0-9]+$')
EXTERNAL = ('os:', 'flow:')
MOD_ORDER = ('win', 'ctrl', 'alt', 'shift')
WEZTERM_MODS = {'super': 'win', 'win': 'win', 'ctrl': 'ctrl', 'alt': 'alt', 'shift': 'shift'}
ZED_MODS = {**WEZTERM_MODS, 'cmd': 'win'}


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


HYPR_BINDINGS = REPO / 'hypr/.config/hypr/bindings.lua'
HYPR_NAMES = {'super': 'win', 'ctrl': 'ctrl', 'control': 'ctrl', 'alt': 'alt', 'shift': 'shift',
              'return': 'enter', 'escape': 'escape', 'space': 'space'}


def normalize_hypr_combo(keys):
    """Normalize a Hyprland key string like `ALT + SHIFT + H` to the contract combo format."""
    parts = [HYPR_NAMES.get(p.strip().lower(), p.strip().lower()) for p in keys.split('+')]
    mods = {p for p in parts[:-1]}
    ordered = [m for m in MOD_ORDER if m in mods]
    return '+'.join([*ordered, parts[-1]])


def parse_hyprland(text):
    """Return the list of (mode, combo) from `hl.bind("<keys>", …)` lines; submap blocks set the mode."""
    found = []
    mode = 'global'
    for line in text.splitlines():
        submap = re.match(r'^\s*hl\.define_submap\("([^"]+)",\s*function\(\)', line)
        if submap:
            mode = submap.group(1)
            continue
        if mode != 'global' and re.match(r'^\s*end\)\s*$', line):
            mode = 'global'
            continue
        bind = re.match(r'^\s*hl\.bind\("([^"]+)"', line)
        if bind:
            found.append((mode, normalize_hypr_combo(bind.group(1))))
    return found


def jsonc(text):
    # Match strings first so comment delimiters within strings remain untouched.
    text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'Duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=unique)


def normalize_zed_combo(chord):
    """Normalize a single-chord Zed keybinding to the contract combo format."""
    if chord == '-':
        return '-'
    parts = chord.split('-')
    if len(parts) >= 2 and parts[-1] == '' and parts[-2] == '':
        mod_parts, key = parts[:-2], '-'
    else:
        mod_parts, key = parts[:-1], parts[-1]
    mods = {ZED_MODS[m.lower()] for m in mod_parts if m}
    ordered = [m for m in MOD_ORDER if m in mods]
    return '+'.join([*ordered, key.lower()])


def parse_zed(text):
    """Return normalized single-chord combos from a Zed keymap JSONC file."""
    combos = []
    for entry in jsonc(text):
        for chord in entry.get('bindings', {}):
            if ' ' not in chord:
                combos.append(normalize_zed_combo(chord))
    return combos


CHEATSHEET = REPO / 'CHEATSHEET.md'
DOC_KEYS = {'esc': 'escape', 'return': 'enter', 'left': 'left', 'down': 'down', 'up': 'up', 'right': 'right'}
DOC_MODS = {'win': 'win', 'ctrl': 'ctrl', 'alt': 'alt', 'shift': 'shift'}


def expand_doc_token(token):
    """Expand a cheatsheet token like `Alt+Shift+1..9` or `Alt+h/j/k/l` into contract combos."""
    *mods, keys = token.split('+')
    mods = {DOC_MODS[m.lower()] for m in mods}
    if re.fullmatch(r'\d\.\.\d', keys):
        names = [str(n) for n in range(int(keys[0]), int(keys[-1]) + 1)]
    else:
        names = keys.split('/')
    return [
        '+'.join([*[m for m in MOD_ORDER if m in mods], DOC_KEYS.get(n.lower(), n.lower())])
        for n in names
    ]


def parse_cheatsheet_wm(text):
    """Return {(mode, combo)} from the first column of the tables under `## Hyprland = GlazeWM`."""
    found = set()
    section = mode = None
    for line in text.splitlines():
        if line.startswith('## '):
            section = line[3:].strip()
            mode = None
        elif line.startswith('### '):
            mode = {'Global': 'global', 'Resize-Modus': 'resize'}.get(line[4:].strip())
        elif section == 'Hyprland = GlazeWM' and mode and line.startswith('|'):
            first = line.split('|')[1]
            for token in re.findall(r'`([^`]+)`', first):
                for combo in expand_doc_token(token):
                    found.add((mode, combo))
    return found


def reserved_combos():
    reserved = set()
    for _, mode, combo, windows in load_contract():
        if mode != 'global':
            continue
        reserved.add(combo)
        if windows.startswith(EXTERNAL):
            reserved.add(windows.split(':', 1)[1])
    return reserved


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
        required = {'close', 'terminal', 'browser', 'file-manager', 'editor', 'git-ui', 'launcher', 'resize-mode', 'fullscreen', 'floating', 'reload',
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

    def test_hyprland_parity(self):
        found = parse_hyprland(HYPR_BINDINGS.read_text(encoding='utf-8'))
        self.assertEqual(len(found), len(set(found)), 'duplicate Hyprland binding in a mode')
        expected = {(mode, combo) for _, mode, combo, _ in load_contract()}
        self.assertEqual(sorted(expected - set(found)), [], 'contract row not bound in Hyprland')
        self.assertEqual(sorted(set(found) - expected), [], 'Hyprland binding outside the contract')

    def test_hyprland_exec_commands_call_session_tools(self):
        text = HYPR_BINDINGS.read_text(encoding='utf-8')
        execs = dict(re.findall(r'hl\.bind\("([^"]+)", hl\.dsp\.exec_cmd\("(.*)"\)\)$', text, re.M))
        self.assertEqual(execs['ALT + SPACE'], 'fuzzel')
        self.assertEqual(execs['ALT + SHIFT + X'], 'hyprlock')
        for tool in ('cliphist list', 'fuzzel --dmenu', 'cliphist decode', 'wl-copy'):
            self.assertIn(tool, execs['ALT + V'])
        for tool in ('grim', 'slurp', 'wl-copy'):
            self.assertIn(tool, execs['ALT + SHIFT + S'])
        self.assertIn('xdg-settings get default-web-browser', execs['ALT + B'])
        # Tools come from mise, which only a login shell puts on PATH.
        for combo, tool in (('ALT + E', 'yazi'), ('ALT + N', 'nvim'), ('ALT + G', 'lazygit')):
            self.assertEqual(execs[combo], f'wezterm start -- zsh -lic {tool}')

    def test_caps_escape_swap_is_limited_to_the_laptop_keyboard(self):
        text = (REPO / 'hypr/.config/hypr/hyprland.lua').read_text(encoding='utf-8')
        self.assertNotIn('kb_options', re.search(r'(?s)hl\.config\(\{.*?\n\}\)', text).group(0))
        device = re.search(r'hl\.device\(\{ name = "at-translated-set-2-keyboard",(.*)\}\)', text)
        self.assertIsNotNone(device)
        self.assertIn('kb_options = "caps:swapescape"', device.group(1))

    def test_hyprland_combo_normalization(self):
        self.assertEqual(normalize_hypr_combo('ALT + SHIFT + H'), 'alt+shift+h')
        self.assertEqual(normalize_hypr_combo('SHIFT + SUPER + RETURN'), 'win+shift+enter')
        self.assertEqual(normalize_hypr_combo('ALT + SPACE'), 'alt+space')

    def test_wezterm_no_collision_with_reserved_combos(self):
        reserved = reserved_combos()

        for path in WEZTERM_CONFIGS:
            combos = parse_wezterm(path.read_text(encoding='utf-8'))
            collisions = sorted(set(combos) & reserved)
            self.assertEqual(collisions, [], f'{path.relative_to(REPO)} collides with reserved combos: {collisions}')

    def test_zed_no_collision_with_reserved_combos(self):
        reserved = reserved_combos()
        combos = parse_zed(ZED_KEYMAP.read_text(encoding='utf-8'))
        collisions = sorted(set(combos) & reserved)
        self.assertEqual(collisions, [], f'{ZED_KEYMAP.relative_to(REPO)} collides with reserved combos: {collisions}')

    def test_cheatsheet_wm_matches_contract(self):
        documented = parse_cheatsheet_wm(CHEATSHEET.read_text(encoding='utf-8'))
        expected = {(mode, combo) for _, mode, combo, _ in load_contract()}
        self.assertEqual(sorted(documented - expected), [], 'CHEATSHEET binding not in contract')
        self.assertEqual(sorted(expected - documented), [], 'contract binding missing in CHEATSHEET')

    def test_cheatsheet_token_expansion(self):
        self.assertEqual(expand_doc_token('Alt+Shift+1..3'), ['alt+shift+1', 'alt+shift+2', 'alt+shift+3'])
        self.assertEqual(expand_doc_token('Alt+h/j'), ['alt+h', 'alt+j'])
        self.assertEqual(expand_doc_token('Esc'), ['escape'])
        self.assertEqual(expand_doc_token('Alt+Space'), ['alt+space'])


if __name__ == '__main__':
    unittest.main()
