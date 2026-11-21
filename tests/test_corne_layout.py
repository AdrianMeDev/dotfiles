#!/usr/bin/env python3
"""Tests for the Corne v4 Vial layout and its coverage of the keybinding contract."""
import json
from pathlib import Path
import re
import unittest

REPO = Path(__file__).resolve().parents[1]
VIL = REPO / 'corne_v4.vil'
CONTRACT = REPO / 'manifests/keybindings.tsv'
LAYERS, ROWS, COLS = 6, 8, 7
MODS = {'LSFT': 'shift', 'LCTL': 'ctrl', 'LALT': 'alt', 'LGUI': 'win'}
MOD_KEYS = {'KC_LSHIFT': 'shift', 'KC_RSHIFT': 'shift', 'KC_LCTRL': 'ctrl', 'KC_LALT': 'alt', 'KC_LGUI': 'win'}
KEY_NAMES = {
    'KC_ENTER': 'enter', 'KC_ESCAPE': 'escape', 'KC_SPACE': 'space',
    'KC_LEFT': 'left', 'KC_RIGHT': 'right', 'KC_UP': 'up', 'KC_DOWN': 'down',
}
LAYER_KEY = re.compile(r'^(?:MO|LT)\((\d),?')


def load():
    return json.loads(VIL.read_text(encoding='utf-8'))


def contract():
    rows = []
    for line in CONTRACT.read_text(encoding='utf-8').splitlines():
        if line.strip() and not line.startswith('#'):
            rows.append(line.split('\t'))
    return rows


def positions(layout):
    for r in range(ROWS):
        for c in range(COLS):
            if layout[0][r][c] != -1:
                yield r, c


def resolve(layout, stack, r, c):
    """Highest active layer that does not pass the key through."""
    for layer in reversed(stack):
        code = layout[layer][r][c]
        if code != 'KC_TRNS':
            return code
    return 'KC_NO'


def tapped(code):
    """(mods, key) a keycode types, or None for non-typing codes."""
    mods = set()
    while True:
        wrap = re.match(r'^(LSFT|LCTL|LALT|LGUI)\((.*)\)$', code)
        if not wrap:
            break
        mods.add(MODS[wrap.group(1)])
        code = wrap.group(2)
    lt = re.match(r'^LT\(\d,(.*)\)$', code)
    if lt:
        code = lt.group(1)
    if code in KEY_NAMES:
        return mods, KEY_NAMES[code]
    m = re.match(r'^KC_([A-Z0-9])$', code)
    return (mods, m.group(1).lower()) if m else None


def layer_targets(layout, layer):
    return {int(m.group(1)) for r, c in positions(layout)
            if (m := LAYER_KEY.match(layout[layer][r][c]))}


def reachable_layers(layout):
    seen, todo = {0}, [0]
    while todo:
        for target in layer_targets(layout, todo.pop()) - seen:
            seen.add(target)
            todo.append(target)
    return seen


def chord_reachable(layout, mods, key):
    """True if some single-layer hold (on top of Layer 0) types `mods+key`."""
    for top in reachable_layers(layout):
        stack = [0] if top == 0 else [0, top]
        codes = {(r, c): resolve(layout, stack, r, c) for r, c in positions(layout)}
        held = {MOD_KEYS[code] for code in codes.values() if code in MOD_KEYS}
        for code in codes.values():
            typed = tapped(code)
            if typed and typed[1] == key and typed[0] <= mods and mods - typed[0] <= held:
                return True
    return False


class CorneLayoutTests(unittest.TestCase):
    def setUp(self):
        self.vil = load()
        self.layout = self.vil['layout']

    def test_vial_schema(self):
        for key in ('version', 'uid', 'layout', 'encoder_layout', 'macro', 'vial_protocol', 'via_protocol'):
            self.assertIn(key, self.vil)
        self.assertEqual((self.vil['vial_protocol'], self.vil['via_protocol']), (6, 9))
        self.assertEqual(len(self.layout), LAYERS)
        self.assertEqual(len(self.vil['encoder_layout']), LAYERS)
        absent = {(r, c) for r in range(ROWS) for c in range(COLS)} - set(positions(self.layout))
        for layer in self.layout:
            self.assertEqual(len(layer), ROWS)
            for r, row in enumerate(layer):
                self.assertEqual(len(row), COLS)
                for c, code in enumerate(row):
                    self.assertEqual(code == -1, (r, c) in absent, f'matrix hole mismatch at {r},{c}')
                    self.assertTrue(code == -1 or isinstance(code, str))

    def test_macros_are_empty(self):
        self.assertEqual(len(self.vil['macro']), 16)
        self.assertTrue(all(macro == [] for macro in self.vil['macro']))

    def test_all_layers_reachable_from_layer_0(self):
        self.assertEqual(reachable_layers(self.layout), set(range(LAYERS)))
        self.assertIn(3, layer_targets(self.layout, 0))

    def test_mo_keys_stay_transparent_on_their_layer(self):
        for r, c in positions(self.layout):
            if (m := re.fullmatch(r'MO\((\d)\)', self.layout[0][r][c])):
                self.assertEqual(self.layout[int(m.group(1))][r][c], 'KC_TRNS')

    def test_digits_and_arrows(self):
        for digit in '0123456789':
            self.assertTrue(chord_reachable(self.layout, set(), digit), digit)
        for arrow in ('left', 'down', 'up', 'right'):
            self.assertTrue(chord_reachable(self.layout, set(), arrow), arrow)

    def test_numbers_read_left_to_right(self):
        digits = [code[3:] for r in (0, 1) for code in self.layout[5][r] if re.fullmatch(r'KC_\d', str(code))]
        self.assertEqual(digits, list('1234567890'))

    def test_every_contract_binding_is_reachable(self):
        rows = contract()
        self.assertGreater(len(rows), 40)
        for name, mode, combo, windows in rows:
            *mods, key = combo.split('+')
            with self.subTest(binding=name, mode=mode, combo=combo):
                self.assertTrue(chord_reachable(self.layout, set(mods), key), f'{combo} unreachable')
            if windows.startswith(('os:', 'flow:')):
                windows_combo = windows.split(':', 1)[1]
                *mods, key = windows_combo.split('+')
                with self.subTest(binding=name, mode=mode, windows=windows_combo):
                    self.assertRegex(windows, r'^(os|flow):(win\+)?(ctrl\+)?(alt\+)?(shift\+)?[a-z0-9]+$')
                    self.assertTrue(chord_reachable(self.layout, set(mods), key),
                                    f'{windows_combo} unreachable')

    def test_resize_mode_is_covered(self):
        modes = {mode for _, mode, _, _ in contract()}
        self.assertEqual(modes, {'global', 'resize'})

    def test_media_and_rgb_stay_accessible(self):
        codes = {resolve(self.layout, [0, 3], r, c) for r, c in positions(self.layout)}
        for code in ('KC_MUTE', 'KC_MPLY', 'KC_MNXT', 'KC_MPRV', 'KC_MSTP', 'KC_VOLU', 'KC_VOLD',
                     'RGB_TOG', 'RGB_MOD', 'RGB_HUI', 'RGB_HUD', 'RGB_SAI', 'RGB_SAD', 'RGB_VAI', 'RGB_VAD'):
            self.assertIn(code, codes)


if __name__ == '__main__':
    unittest.main()
