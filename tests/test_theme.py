#!/usr/bin/env python3
"""Tests for the unified theme contract (theme/tokens.toml) and tool parity."""
from pathlib import Path
import json
import plistlib
import re
import shlex
import subprocess
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
    'lazygit.background': 'lazygit sets no background colors except selection; the terminal '
                          'background and opacity show through.',
    'btop.background': 'btop runs with theme_background = False so the terminal background shows '
                       'through; main_bg only documents bg.',
    'yazi.background': 'yazi only paints highlight/mode backgrounds; the terminal background and '
                       'opacity show through.',
    'claude.theme': 'Claude Code only offers built-in themes; "dark-ansi" uses the terminal ANSI '
                    'palette, so Tokyo Night comes from the terminal (WezTerm) and no hex values '
                    'can be set in Claude Code itself.',
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

    def test_bat(self):
        self.assertEqual(shlex.split(read('bat/.config/bat/config')),
                         ['--theme=tokyonight_night'])
        path = 'bat/.config/bat/themes/tokyonight_night.tmTheme'
        theme = plistlib.loads(read(path).encode())
        self.assertEqual(theme['name'], 'tokyonight_night')
        self.assert_colors_in_contract(path)
        p = self.palette
        self.assertEqual(theme['settings'][0]['settings'], {
            'background': p['bg'], 'foreground': p['fg'], 'caret': p['fg'],
            'invisibles': p['border'], 'lineHighlight': p['bg_highlight'],
            'selection': p['bg_highlight'], 'gutter': p['bg'],
            'gutterForeground': p['comment'],
        })
        scopes = {scope.strip(): rule['settings']['foreground']
                  for rule in theme['settings'][1:] for scope in rule['scope'].split(',')}
        expected = {
            'comment': 'comment', 'string': 'green', 'constant.numeric': 'orange',
            'keyword': 'magenta', 'keyword.operator': 'cyan', 'entity.name.function': 'blue',
            'entity.name.type': 'cyan', 'variable': 'fg', 'variable.parameter': 'yellow',
            'entity.name.tag': 'red', 'entity.other.attribute-name': 'yellow',
            'punctuation': 'fg_dark', 'invalid': 'red', 'markup.heading': 'blue',
            'markup.inserted': 'green', 'markup.deleted': 'red', 'markup.changed': 'yellow',
        }
        for scope, token in expected.items():
            self.assertEqual(scopes[scope], p[token], scope)

    def test_delta(self):
        # Let Git parse quoting: unquoted hex colors would become comments.
        result = subprocess.run(['git', 'config', '--file', str(REPO / 'git/.gitconfig'),
                                 '--null', '--list'], check=True, capture_output=True, text=True)
        config = dict(entry.split('\n', 1) for entry in result.stdout.split('\0') if entry)
        self.assertEqual(config['core.pager'], 'delta')
        self.assertEqual(config['interactive.difffilter'], 'delta --color-only')
        p, d = self.palette, load_tokens()['diff']
        expected = {
            'dark': 'true', 'navigate': 'true', 'syntax-theme': 'tokyonight_night',
            'minus-style': f"syntax {d['delete']}",
            'minus-emph-style': f"syntax {d['text']}",
            'plus-style': f"syntax {d['add']}",
            'plus-emph-style': f"syntax {d['text']}",
            'zero-style': f"syntax {p['bg']}",
            'hunk-header-style': f"{p['blue']} {d['change']}",
            'hunk-header-decoration-style': f"{p['border']} box",
            'line-numbers': 'true',
            'line-numbers-minus-style': f"{p['red']} {d['delete']}",
            'line-numbers-plus-style': f"{p['green']} {d['add']}",
            'line-numbers-zero-style': f"{p['comment']} {p['bg']}",
            'line-numbers-left-style': p['comment'],
            'line-numbers-right-style': p['comment'],
        }
        self.assertEqual({key.removeprefix('delta.'): value for key, value in config.items()
                          if key.startswith('delta.')}, expected)
        self.assertEqual(hexes(read('git/.gitconfig')) - self.allowed - set(d.values()), set())

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

    def test_lazygit(self):
        path = 'lazygit/.config/lazygit/config.yml'
        text = read(path)
        self.assert_colors_in_contract(path)
        p = self.palette
        self.assertRegex(text, r'(?m)^  border: rounded$')
        self.assertRegex(text, r'(?m)^  nerdFontsVersion: "3"$')
        self.assertRegex(text, r'(?m)^    pager: delta --dark --paging=never$')
        theme = {m[1]: re.findall(r'"(#[0-9a-f]{6})"', m[2]) for m in
                 re.finditer(r'(?m)^    (\w+):\n((?:      - .*\n)+)', text)}
        expected = {
            'activeBorderColor': p['border_active'], 'inactiveBorderColor': p['border'],
            'optionsTextColor': p['blue'], 'selectedLineBgColor': p['bg_highlight'],
            'inactiveViewSelectedLineBgColor': p['bg_highlight'],
            'unstagedChangesColor': p['red'], 'defaultFgColor': p['fg'],
        }
        for key, color in expected.items():
            self.assertEqual(theme[key], [color], key)
        self.assertNotIn(p['bg'], hexes(text))

    def test_btop(self):
        conf = dict(re.findall(r'(?m)^(\w+) = (.+)$', read('btop/.config/btop/btop.conf')))
        self.assertEqual(conf, {'color_theme': '"tokyo-night"', 'theme_background': 'False',
                                'truecolor': 'True', 'rounded_corners': 'True'})
        path = 'btop/.config/btop/themes/tokyo-night.theme'
        self.assert_colors_in_contract(path)
        p = self.palette
        theme = dict(re.findall(r'(?m)^theme\[(\w+)\]="(#[0-9a-f]{6})"$', read(path)))
        expected = {
            'main_bg': p['bg'], 'main_fg': p['fg'], 'title': p['fg'], 'hi_fg': p['blue'],
            'selected_bg': p['bg_highlight'], 'inactive_fg': p['comment'],
            'cpu_box': p['border'], 'mem_box': p['border'], 'net_box': p['border'],
            'proc_box': p['border'], 'div_line': p['border'],
        }
        for key, color in expected.items():
            self.assertEqual(theme[key], color, key)
        self.assertEqual(len(theme), len(re.findall(r'(?m)^theme\[', read(path))))

    def test_yazi(self):
        path = 'yazi/.config/yazi/theme.toml'
        config = tomllib.loads(read(path))
        self.assert_colors_in_contract(path)
        p = self.palette
        self.assertEqual(config['mgr']['cwd']['fg'], p['cyan'])
        self.assertEqual(config['mgr']['hovered'], {'fg': p['fg'], 'bg': p['bg_highlight']})
        self.assertEqual(config['mgr']['border_style']['fg'], p['border'])
        self.assertEqual(config['tabs']['active']['bg'], p['blue'])
        self.assertEqual(config['mode']['normal_main']['bg'], p['blue'])
        self.assertEqual(config['status']['progress_error']['fg'], p['red'])
        for section in ('confirm', 'input', 'pick', 'completion', 'tasks'):
            self.assertEqual(config[section]['border']['fg'], p['border_active'], section)
        # Terminal background must show through: never paint bg/bg_dark on the main view.
        self.assertNotIn(p['bg'], [v.get('bg') for s in config.values() if isinstance(s, dict)
                                   for v in s.values() if isinstance(v, dict)])

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

    def test_claude_code(self):
        settings = json.loads(read('agent-config/claude/settings.json'))
        self.assertEqual(settings['theme'], 'dark-ansi')
        self.assertIn('claude.theme', EXCEPTIONS)
        self.assert_colors_in_contract('agent-config/claude/settings.json')

    def test_pi(self):
        settings = json.loads(read('agent-config/pi/settings.json'))
        theme = json.loads(read('agent-config/pi/themes/tokyo-night.json'))
        self.assertEqual(settings['theme'], theme['name'])
        self.assertEqual(theme['name'], 'tokyo-night')
        self.assertEqual(theme['appearance'], 'dark')
        tokens = load_tokens()
        unknown = hexes(read('agent-config/pi/themes/tokyo-night.json')) - self.allowed - set(tokens['diff'].values())
        self.assertEqual(unknown, set())
        for key, value in tokens['palette'].items():
            self.assertEqual(theme['vars'][key], value, key)
        for key in ('add', 'delete', 'text'):  # diff.change has no pi counterpart
            self.assertEqual(theme['vars'][f'diff_{key}'], tokens['diff'][key], key)
        for key, ref in theme['colors'].items():
            self.assertIn(ref, theme['vars'], f'{key} -> {ref}')


if __name__ == '__main__':
    unittest.main()
