-- Offline startup with existing plugin sources. Downloads/builds are disabled;
-- all actual plugin setup functions still run. Use only trusted cached plugins.
local plugins = assert(os.getenv 'DOTFILES_NVIM_PLUGINS')
local config = assert(os.getenv 'DOTFILES_NVIM_CONFIG')
for name, kind in vim.fs.dir(plugins) do
  if kind == 'directory' then vim.opt.runtimepath:append(vim.fs.joinpath(plugins, name)) end
end
vim.pack.add = function() end
require('mason-registry').refresh = function(callback) callback(true, {}) end
require('mason-tool-installer').setup = function() end
require('nvim-treesitter').install = function() return { await = function() end } end
local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then table.insert(errors, tostring(message)) end
end
local ok, error_message = pcall(dofile, config)
if not ok then table.insert(errors, tostring(error_message)) end
vim.wait(100)
for _, name in ipairs { 'ts_ls', 'angularls', 'basedpyright', 'ruff', 'omnisharp', 'lua_ls' } do
  if not vim.lsp.is_enabled(name) then table.insert(errors, 'LSP not enabled: ' .. name) end
end
if vim.lsp.is_enabled 'stylua' then table.insert(errors, 'Formatter registered as LSP') end
if #errors > 0 then
  io.stderr:write(table.concat(errors, '\n') .. '\n')
  vim.cmd 'cquit 1'
else
  print('Neovim offline startup: OK (downloads/LSP processes not tested)')
  vim.cmd 'qa!'
end
