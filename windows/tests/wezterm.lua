-- Run with: nvim --headless -u NONE -i NONE -l windows/tests/wezterm.lua
local root = vim.fn.getcwd()
local action = setmetatable({}, { __index = function(_, name)
  if name == 'DisableDefaultAssignment' or name == 'ShowLauncher' or name == 'ActivateCopyMode' or name == 'QuickSelect' then
    return name
  end
  return function(value) return { name = name, value = value } end
end })
package.preload.wezterm = function()
  return { action = action, home_dir = '/test profile', target_triple = 'x86_64-pc-windows-msvc',
    font_with_fallback = function(fonts) return fonts end }
end
local original = dofile
local distro
_G.dofile = function(path)
  if path == '/test profile/.config/wezterm/base.lua' then
    return original(root .. '/wezterm/.config/wezterm/wezterm.lua')
  elseif path == '/test profile/.config/wezterm/distro.lua' then
    return distro
  end
  return original(path)
end
distro = nil
local native = dofile(root .. '/windows/wezterm/wezterm.lua')
assert(native.default_domain == 'local')
assert(native.wsl_domains == nil)
assert(native.default_prog[1] == 'pwsh.exe')
distro = 'archlinux'
local config = dofile(root .. '/windows/wezterm/wezterm.lua')
assert(config.default_domain == 'WSL:archlinux')
assert(config.default_prog == nil)
assert(config.wsl_domains[1].name == 'WSL:archlinux')
assert(config.wsl_domains[1].distribution == 'archlinux')
assert(config.wsl_domains[1].default_cwd == '~')
assert(config.color_scheme == 'Tokyo Night')
assert(config.font[1] == 'IoskeleyMonoTerm Nerd Font Mono')
assert(config.font[2] == 'Ioskeley Mono')
-- GlazeWM only tiles windows with a resize frame.
assert(native.window_decorations == 'RESIZE')
assert(config.window_decorations == 'RESIZE')
local found = {}
for _, key in ipairs(config.keys) do
  if key.key == 't' and key.mods == 'CTRL' then
    assert(key.action.value == 'CurrentPaneDomain')
    found.tabs = true
  elseif key.key == 'p' and key.mods == 'CTRL|SHIFT' then
    assert(key.action.value.domain.DomainName == 'local')
    assert(key.action.value.args[1] == 'pwsh.exe')
    found.powershell = true
  end
end
assert(found.tabs and found.powershell)
print('PASS: Windows WezTerm domains and keybindings')
