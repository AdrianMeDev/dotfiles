#!/usr/bin/env python3
"""Tests for the unified theme contract (theme/tokens.toml) and tool parity."""
from pathlib import Path
import json
import re
import tomllib
import unittest

REPO = Path(__file__).resolve().parents[1]
HEX = re.compile(r'^#[0-9a-f]{6}$')
HEX_IN_TEXT = re.compile(r'#[0-9a-fA-F]{6}\b')

PALETTE_KEYS = {
    'bg', 'bg_dark', 'bg_highlight', 'fg', 'fg_dark', 'comment', 'border', 'border_active',
    'red', 'orange', 'yellow', 'green', 'teal', 'cyan', 'blue', 'blue_bright', 'magenta',
}
DIFF_KEYS = {'add', 'change', 'delete', 'text'}

# Documented deviations from the contract. Every entry says why the tool does
# not (or cannot) carry the token itself. Tests must not silently skip a token.
EXCEPTIONS = {
    'window.opacity': 'Owned by the terminal emulator (WezTerm/Windows Terminal); tmux, Starship, '
                      'fzf and zsh draw on the terminal background and inherit its opacity.',
    'window.blur': 'Compositor/terminal feature; CLI tools cannot configure blur.',
    'window.blur.wezterm': 'Blur radius/passes are compositor-owned on Linux; WezTerm only gets '
                           'opacity here and is not given blur settings.',
    'window.blur.neovim': 'Neovim runs inside the terminal and inherits its blur and opacity.',
    'font.neovim': 'Neovim runs inside the terminal and inherits its font and size.',
    'font.size.ui_bar': 'ui (15) applies to Zed UI only; bar (12) has no consumer in WezTerm/Zed/Neovim yet.',
    'font': 'Fonts and sizes are set by the terminal; CLI/TUI tools inherit them.',
    'border': 'Rounded borders only apply where the tool supports them (fzf --border=rounded); '
              'tmux draws plain pane borders and Starship has none.',
    'starship.foreground': 'Starship palette foreground uses fg_dark, matching the tmux/fzf text color.',
}


def load_tokens():
    with open(REPO / 'theme/tokens.toml', 'rb') as handle:
        return tomllib.load(handle)


def read(path):
    return (REPO / path).read_text(encoding='utf-8')


def jsonc(text):
    text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    return json.loads(text)


def hexes(text):
    return {h.lower() for h in HEX_IN_TEXT.findall(text)}


class TokenContractTests(unittest.TestCase):
    def setUp(self):
        self.tokens = load_tokens()

    def test_palette_schema(self):
        palette = self.tokens['palette']
        self.assertEqual(set(palette), PALETTE_KEYS)
        for key, value in palette.items():
            self.assertRegex(value, HEX, key)

    def test_diff_schema(self):
        diff = self.tokens['diff']
        self.assertEqual(set(diff), DIFF_KEYS)
        for key, value in diff.items():
            self.assertRegex(value, HEX, key)

    def test_fonts_and_sizes(self):
        font = self.tokens['font']
        self.assertEqual(font['editor_family'], 'Ioskeley Mono')
        self.assertEqual(font['terminal_family'], 'IoskeleyMonoTerm Nerd Font Mono')
        sizes = font['size']
        self.assertEqual(set(sizes), {'editor', 'terminal', 'ui', 'bar'})
        for key, value in sizes.items():
            self.assertIsInstance(value, int, key)
            self.assertGreater(value, 0, key)

    def test_opacity_matches_alpha_hex(self):
        window = self.tokens['window']
        self.assertEqual(window['opacity'], 0.75)
        self.assertEqual(window['alpha_hex'], f"{round(window['opacity'] * 255):02x}")
        self.assertEqual(window['alpha_hex'], 'bf')

    def test_blur_and_border(self):
        blur = self.tokens['window']['blur']
        self.assertIs(blur['enabled'], True)
        self.assertGreater(blur['radius'], 0)
        self.assertGreater(blur['passes'], 0)
        border = self.tokens['border']
        self.assertGreater(border['width'], 0)
        self.assertGreater(border['radius'], 0)
        self.assertEqual(border['style'], 'rounded')

    def test_exceptions_are_documented(self):
        for key, reason in EXCEPTIONS.items():
            self.assertTrue(reason.strip(), key)


class ParityTests(unittest.TestCase):
    def setUp(self):
        self.palette = load_tokens()['palette']
        self.allowed = {v.lower() for v in self.palette.values()}

    def assert_colors_in_contract(self, path):
        unknown = hexes(read(path)) - self.allowed
        self.assertEqual(unknown, set(), f'{path}: colors outside theme/tokens.toml')

    def test_tmux(self):
        text = read('tmux/.config/tmux/tmux.conf')
        self.assert_colors_in_contract('tmux/.config/tmux/tmux.conf')
        p = self.palette
        expected = {
            'status-style': f"fg={p['fg_dark']},bg={p['bg']}",
            'status-left-style': f"fg={p['bg']},bg={p['blue']}",
            'window-status-style': f"fg={p['comment']},bg={p['bg']}",
            'window-status-current-style': f"fg={p['bg']},bg={p['magenta']}",
            'pane-border-style': f"fg={p['border']}",
            'pane-active-border-style': f"fg={p['border_active']}",
            'message-style': f"fg={p['bg']},bg={p['yellow']}",
            'mode-style': f"fg={p['bg']},bg={p['cyan']}",
        }
        for option, value in expected.items():
            self.assertRegex(text, rf"set -g {option} '{re.escape(value)}(,bold)?'")

    def test_starship(self):
        path = 'starship/.config/starship.toml'
        config = tomllib.loads(read(path))
        self.assertEqual(config['palette'], 'tokyo_night')
        starship = config['palettes']['tokyo_night']
        p = self.palette
        expected = {
            'background': p['bg'], 'foreground': p['fg_dark'], 'comment': p['comment'],
            'red': p['red'], 'orange': p['orange'], 'yellow': p['yellow'], 'green': p['green'],
            'cyan': p['cyan'], 'blue': p['blue'], 'magenta': p['magenta'],
        }
        self.assertEqual(starship, expected)

    def test_fzf(self):
        text = read('zsh/.config/zsh/fzf.zsh')
        self.assert_colors_in_contract('zsh/.config/zsh/fzf.zsh')
        p = self.palette
        expected = {
            'fg': p['fg_dark'], 'bg': p['bg'], 'hl': p['blue'], 'fg+': p['fg'],
            'bg+': p['bg_highlight'], 'hl+': p['cyan'], 'info': p['comment'],
            'prompt': p['cyan'], 'pointer': p['magenta'], 'marker': p['green'],
            'spinner': p['magenta'], 'header': p['teal'], 'border': p['border'],
        }
        opts = re.search(r"FZF_DEFAULT_OPTS='([^']*)'", text).group(1)
        actual = dict(pair.split(':', 1) for chunk in re.findall(r'--color=(\S+)', opts)
                      for pair in chunk.split(','))
        self.assertEqual(actual, expected)
        self.assertIn('--border=rounded', opts)

    def test_zsh_plugins(self):
        text = read('zsh/.config/zsh/plugins.zsh')
        self.assert_colors_in_contract('zsh/.config/zsh/plugins.zsh')
        self.assertIn(f"ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg={self.palette['comment']}'", text)

    def test_zed(self):
        tokens = load_tokens()
        p, font, window = tokens['palette'], tokens['font'], tokens['window']
        settings = jsonc(read('zed-config/.config/zed/settings.json'))
        self.assertEqual(settings['theme'], tokens['meta']['name'])
        self.assertEqual(settings['buffer_font_family'], font['editor_family'])
        self.assertEqual(settings['buffer_font_size'], font['size']['editor'])
        self.assertEqual(settings['ui_font_size'], font['size']['ui'])
        self.assertEqual(settings['terminal']['font_family'], font['terminal_family'])
        self.assertEqual(settings['terminal']['font_size'], font['size']['terminal'])
        overrides = settings['experimental.theme_overrides']
        self.assertEqual(overrides['background.appearance'], 'blurred')
        self.assertEqual(overrides['background'], p['bg'] + window['alpha_hex'])
        surfaces = [k for k, v in overrides.items() if k.endswith('.background') and k != 'background']
        self.assertTrue(surfaces)
        for key in surfaces:
            self.assertEqual(overrides[key], '#00000000', key)

    def test_wezterm(self):
        tokens = load_tokens()
        text = read('wezterm/.config/wezterm/wezterm.lua')
        self.assertIn(f"config.color_scheme = '{tokens['meta']['name']}'", text)
        self.assertIn(f"config.window_background_opacity = {tokens['window']['opacity']}", text)
        self.assertIn(f"config.font_size = {tokens['font']['size']['terminal']}\n", text)
        self.assertRegex(text, rf"font_with_fallback \{{\s*'{re.escape(tokens['font']['terminal_family'])}',"
                               rf"\s*'{re.escape(tokens['font']['editor_family'])}'")

    def test_neovim(self):
        tokens = load_tokens()
        text = read('nvim/.config/nvim/init.lua')
        self.assertIn(f"style = '{tokens['meta']['variant']}'", text)
        self.assertIn('transparent = true', text)
        self.assertIn("styles = { sidebars = 'transparent', floats = 'transparent' }", text)
        self.assertIn(f"colorscheme 'tokyonight-{tokens['meta']['variant']}'", text)


if __name__ == '__main__':
    unittest.main()
