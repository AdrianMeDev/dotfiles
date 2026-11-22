local wezterm = require 'wezterm'
local directory = wezterm.home_dir .. '/.config/wezterm'
local config = dofile(directory .. '/base.lua')
local distro = dofile(directory .. '/distro.lua')
if distro then
  config.wsl_domains = { { name = 'WSL:' .. distro, distribution = distro, default_cwd = '~' } }
  config.default_domain = 'WSL:' .. distro
  config.default_prog = nil
else
  config.default_domain = 'local'
  config.default_prog = { 'pwsh.exe', '-NoLogo' }
end
config.launch_menu = { { label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' }, domain = { DomainName = 'local' } } }
for _, binding in ipairs(config.keys) do
  if binding.key == 'p' and binding.mods == 'CTRL|SHIFT' then
    binding.action = wezterm.action.SpawnCommandInNewTab {
      args = { 'pwsh.exe', '-NoLogo' }, domain = { DomainName = 'local' },
    }
  end
end
-- GlazeWM floats windows without a resize frame (base.lua uses 'NONE');
-- RESIZE adds an invisible one, so WezTerm tiles and still has no title bar.
config.window_decorations = 'RESIZE'
return config
