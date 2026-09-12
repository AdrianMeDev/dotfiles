local wezterm = require 'wezterm'
local act = wezterm.action

local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Minimal outer-layer terminal config:
-- - WezTerm handles tabs/workspaces
-- - tmux handles project panes/processes

config.font = wezterm.font_with_fallback { 'JetBrainsMono Nerd Font', 'DejaVu Sans Mono' }
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'
if wezterm.target_triple:find 'linux' then
  local ok, shell = wezterm.run_child_process { 'sh', '-c', 'command -v fish' }
  if ok then config.default_prog = { shell:gsub('%s+$', ''), '-l' } end
end

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.window_decorations = 'NONE'
config.adjust_window_size_when_changing_font_size = false
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.keys = {
  -- Simpler tab switching than the default Ctrl+Shift+Number
  { key = '1', mods = 'CTRL', action = act.ActivateTab(0) },
  { key = '2', mods = 'CTRL', action = act.ActivateTab(1) },
  { key = '3', mods = 'CTRL', action = act.ActivateTab(2) },
  { key = '4', mods = 'CTRL', action = act.ActivateTab(3) },
  { key = '5', mods = 'CTRL', action = act.ActivateTab(4) },
  { key = '6', mods = 'CTRL', action = act.ActivateTab(5) },
  { key = '7', mods = 'CTRL', action = act.ActivateTab(6) },
  { key = '8', mods = 'CTRL', action = act.ActivateTab(7) },
  { key = '9', mods = 'CTRL', action = act.ActivateTab(8) },

  -- Disable the default Ctrl+Shift+Number bindings so there is only one way
  { key = '1', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '2', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '3', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '4', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '5', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '6', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '7', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '8', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  { key = '9', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },

  -- Tab management
  { key = 't', mods = 'CTRL', action = act.SpawnTab('CurrentPaneDomain') },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },

  -- Open the launcher/workspace menu
  { key = 'o', mods = 'CTRL|SHIFT', action = act.ShowLauncher },

  -- Optional WezTerm pane controls, useful when you are not inside tmux
  { key = 'd', mods = 'CTRL|ALT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'D', mods = 'CTRL|ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'h', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Right' },
}

if wezterm.target_triple:find 'windows' then
  table.insert(config.keys, {
    key = 'p', mods = 'CTRL|SHIFT',
    action = act.SpawnCommandInNewTab { args = { 'pwsh.exe', '-NoLogo' } },
  })
end
table.insert(config.keys, { key = 'x', mods = 'CTRL|SHIFT', action = act.ActivateCopyMode })
table.insert(config.keys, { key = 'Space', mods = 'CTRL|SHIFT', action = act.QuickSelect })

return config
