local wezterm = require 'wezterm'
local directory = wezterm.home_dir .. '/.config/wezterm'
local config = dofile(directory .. '/base.lua')
local distro = dofile(directory .. '/distro.lua')
config.wsl_domains = { { name = 'WSL:' .. distro, distribution = distro } }
config.default_domain = 'WSL:' .. distro
config.default_prog = nil
config.launch_menu = { { label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' }, domain = { DomainName = 'local' } } }
for _, binding in ipairs(config.keys) do
  if binding.key == 'p' and binding.mods == 'CTRL|SHIFT' then
    binding.action = wezterm.action.SpawnCommandInNewTab {
      args = { 'pwsh.exe', '-NoLogo' }, domain = { DomainName = 'local' },
    }
  end
end
return config
