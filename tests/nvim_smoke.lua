-- Offline integration: real plugin setup, simulated installed LSPs and responses.
-- Only trusted cached sources are loaded; no downloads, parser builds or LSP processes.
local plugins = assert(os.getenv 'DOTFILES_NVIM_PLUGINS')
local config = assert(os.getenv 'DOTFILES_NVIM_CONFIG')
local names = { 'fzf-lua', 'nvim-tree.lua', 'which-key.nvim', 'nvim-lspconfig', 'mason.nvim', 'mason-lspconfig.nvim', 'nvim-treesitter' }
for _, name in ipairs(names) do
  local path = vim.fs.joinpath(plugins, name)
  assert(vim.fn.isdirectory(path) == 1, 'Missing cached plugin: ' .. name)
  vim.opt.runtimepath:append(path)
end
vim.pack.add = function(specs) assert(#specs == #names, 'Unexpected plugin count') end
local servers = { 'ts_ls', 'angularls', 'html', 'eslint', 'basedpyright', 'ruff', 'omnisharp', 'lua_ls' }
local registry = require 'mason-registry'
registry.refresh = function(callback) callback(true, {}) end
registry.get_installed_package_names = function() return servers end
registry.get_all_package_specs = function()
  local specs = {}
  for _, name in ipairs(servers) do
    table.insert(specs, { name = name, neovim = { lspconfig = name } })
  end
  return specs
end
require('nvim-treesitter').install = function()
  return { await = function(_, callback) callback() end }
end
local errors, warnings = {}, {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then table.insert(errors, tostring(message)) end
  if level == vim.log.levels.WARN then table.insert(warnings, tostring(message)) end
end

local function run()
  dofile(config)
  vim.wait(100)
  for _, name in ipairs(servers) do
    assert(vim.lsp.is_enabled(name), 'LSP not enabled: ' .. name)
    vim.lsp.enable(name, false) -- No real server processes during editing checks.
  end
  assert(not vim.lsp.is_enabled 'stylua', 'Old formatter enabled as LSP')
  local tree = require('nvim-tree.api').tree
  tree.open()
  assert(tree.is_visible(), 'Explorer did not open')
  tree.close()
  assert(not tree.is_visible(), 'Explorer did not close')
  assert(vim.fn.maparg('  ', 'n', false, true).callback == require('fzf-lua').files)
  assert(vim.fn.maparg(' /', 'n', false, true).callback == require('fzf-lua').live_grep)
  assert(vim.fn.maparg(' e', 'n'):find('NvimTreeToggle', 1, true))

  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local get_clients = vim.lsp.get_clients
  local active, fail_action, fail_format = {}, false, false
  local calls = {}
  -- Let the real vim.lsp.buf.format apply the returned text edits.
  vim.lsp.get_clients = function(filter)
    filter = filter or {}
    return vim.tbl_filter(function(client) return (not filter.name or filter.name == client.name) and (not filter.id or filter.id == client.id) end, active)
  end
  local function client(name, id)
    return {
      name = name,
      id = id,
      offset_encoding = 'utf-16',
      supports_method = function() return false end,
      request_sync = function(_, method, params, timeout, buf)
        assert(timeout == 2000, 'LSP request must have a timeout')
        table.insert(calls, name .. ':' .. method)
        local range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = #vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] } }
        if method == 'textDocument/codeAction' then
          assert(params.textDocument.uri == vim.uri_from_bufnr(buf), 'Wrong document in save action')
          assert(params.context.only[1] == 'source.organizeImports.ruff')
          if fail_action then return nil, 'timeout' end
          return {
            result = {
              {
                title = 'Sort imports',
                edit = { changes = {
                  [vim.uri_from_bufnr(buf)] = { { range = range, newText = 'sorted' } },
                } },
              },
            },
          }
        end
        assert(method == 'textDocument/formatting', 'Unexpected request: ' .. method)
        if fail_format then return nil, 'timeout' end
        if name == 'ruff' then assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'sorted', 'Formatting ran before import edits') end
        return { result = { { range = range, newText = name .. ' formatted  ' } } }
      end,
    }
  end
  local function file(ft, content)
    vim.cmd.enew()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, dir .. '/' .. buf .. '.' .. ft)
    vim.bo.filetype = ft
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { content })
    return buf
  end
  local function saved(buf) return table.concat(vim.fn.readfile(vim.api.nvim_buf_get_name(buf), 'b'), '\n') end
  local python = file('python', 'unsorted  ')
  assert(vim.bo.shiftwidth == 4)
  active = { client('basedpyright', 1), client('ruff', 2) }
  vim.cmd.write()
  assert(saved(python) == 'ruff formatted\n', 'Python changes missing from disk')
  assert(table.concat(calls, ',') == 'ruff:textDocument/codeAction,ruff:textDocument/formatting')
  local typescript = file('typescript', 'unfixed  ')
  calls = {}
  active = { client('ts_ls', 3), client('angularls', 4), client('eslint', 5) }
  vim.cmd.write()
  assert(saved(typescript) == 'eslint formatted\n', 'Wrong TS formatter')
  assert(#calls == 1 and calls[1] == 'eslint:textDocument/formatting')
  for ft, name in pairs { html = 'html', htmlangular = 'html', cs = 'omnisharp', lua = 'lua_ls' } do
    local buf = file(ft, 'unformatted')
    active = { client(name, 6), client('angularls', 4) }
    vim.cmd.write()
    assert(saved(buf) == name .. ' formatted\n', 'Wrong formatter for ' .. ft)
  end
  active = {}
  local plain = file('text', 'no server  ')
  vim.cmd.write()
  assert(saved(plain) == 'no server\n', 'Save without LSP failed')
  active = { client('ruff', 2) }
  fail_action = true
  local failing = file('python', 'timeout still saves  ')
  vim.cmd.write()
  assert(saved(failing) == 'timeout still saves\n', 'Code action timeout prevented save')
  assert(#warnings > 0, 'Code action timeout should warn')
  fail_action, fail_format = false, true
  active = { client('eslint', 5) }
  local slow = file('typescript', 'formatter timeout  ')
  vim.cmd.write()
  assert(saved(slow) == 'formatter timeout\n', 'Formatter timeout prevented save')
  fail_format = false
  -- :wall must build action URIs for each written buffer, not the visible one.
  vim.api.nvim_buf_set_lines(failing, 0, -1, false, { 'unsorted again' })
  active = { client('ruff', 2) }
  vim.cmd.wall()
  assert(saved(failing) == 'ruff formatted\n', ':wall targeted the wrong buffer')
  active = {}
  local binary = file('text', 'binary  ')
  vim.bo.binary = true
  vim.bo.endofline = false
  vim.cmd.write()
  assert(saved(binary) == 'binary  ', 'Binary data was changed')
  vim.bo.binary = false
  vim.lsp.get_clients = get_clients
  vim.fn.delete(dir, 'rf')
end
local ok, err = pcall(run)
if not ok then table.insert(errors, tostring(err)) end
if #errors > 0 then
  io.stderr:write(table.concat(errors, '\n') .. '\n')
  vim.cmd 'cquit 1'
end
print 'Neovim offline: plugin setup, explorer, LSP activation, save/format routing and timeouts OK (simulated LSPs)'
vim.cmd 'qa!'
