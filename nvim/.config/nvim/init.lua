-- Meine Neovim-Config: eine Datei, direkte Einstellungen, keine Distribution.
-- Konzept: github.com/radleylewis/nvim-lite; Bedienung: meine Zed-Config.
-- Lesen/erweitern: Optionen → Plugins → Sprachen → Formatierung → Tasten.
if vim.fn.has 'nvim-0.12' == 0 then
  vim.notify('Diese Config benötigt Neovim >= 0.12 (vim.pack).', vim.log.levels.ERROR)
  return
end

-- 1. Grundeinstellungen -------------------------------------------------------
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.guicursor = 'n-v-c:block,i-ci-ve:ver25,r-cr:hor20,a:blinkon0'
opt.termguicolors = true
opt.wrap = false
opt.scrolloff = 8
opt.signcolumn = 'yes'
opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.ignorecase = true
opt.smartcase = true
opt.splitright = true
opt.splitbelow = true
opt.clipboard = 'unnamedplus'
opt.undofile = true -- Undo bleibt nach dem Neustart verfügbar (im Neovim-Datenverzeichnis).
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = 'menuone,noselect,popup'
opt.laststatus = 3
opt.statusline = '%f %m%r%=%y  %l:%c  %p%%'
opt.showtabline = 0 -- Buffer wechseln per Tastatur, keine zusätzliche Tab-Leiste.

opt.background = 'dark'
vim.cmd.colorscheme 'default'
vim.api.nvim_set_hl(0, 'Normal', { fg = '#e0e2ea', bg = '#15171c' })
vim.api.nvim_set_hl(0, 'NormalFloat', { fg = '#e0e2ea', bg = '#2c2e33' })
vim.api.nvim_set_hl(0, 'Comment', { fg = '#9b9ea4' })
vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#2c2e33' })

local group = vim.api.nvim_create_augroup('MeineConfig', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = { 'python', 'cs' },
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end,
})
vim.api.nvim_create_autocmd('TextYankPost', {
  group = group,
  callback = function() vim.hl.on_yank() end,
})

-- 2. Plugins -----------------------------------------------------------------
-- Hinzufügen: URL unten eintragen, darunter require('plugin').setup {} ergänzen.
-- Fehlende Plugins werden einmalig geladen; beim normalen Start kein Update.
-- Updates: :lua vim.pack.update()  (Änderungen prüfen und mit :write übernehmen)
-- Danach nvim-pack-lock.json mit versionieren. Details: :help vim.pack
vim.pack.add {
  'https://github.com/ibhagwan/fzf-lua',
  'https://github.com/nvim-tree/nvim-tree.lua',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/folke/flash.nvim',
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/mason-org/mason-lspconfig.nvim',
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
}

require('fzf-lua').setup {
  'default-title',
  defaults = { file_icons = false },    -- Keine zusätzliche Icon-Abhängigkeit.
}
require('fzf-lua').register_ui_select() -- Auch Code-Actions nutzen dieselbe Auswahl.
local Flash = require 'flash'

local function goto_word()
  local function format(opts)
    return {
      { opts.match.label1, 'FlashMatch' },
      { opts.match.label2, 'FlashLabel' },
    }
  end

  Flash.jump {
    search = {
      mode = 'search',
      multi_window = false,
    },
    label = {
      after = false,
      before = { 0, 0 },
      uppercase = false,
      format = format,
    },
    pattern = [[\<]],
    action = function(match, state)
      state:hide()

      Flash.jump {
        search = { max_length = 0 },
        highlight = { matches = false },
        label = { format = format },

        matcher = function(win)
          return vim.tbl_filter(function(m)
            return m.label == match.label and m.win == win
          end, state.results)
        end,

        labeler = function(matches)
          for _, m in ipairs(matches) do
            m.label = m.label2
          end
        end,
      }
    end,

    labeler = function(matches, state)
      local labels = state:labels()

      for m, match in ipairs(matches) do
        match.label1 = labels[math.floor((m - 1) / #labels) + 1]
        match.label2 = labels[(m - 1) % #labels + 1]
        match.label = match.label1
      end
    end,
  }
end
require('nvim-tree').setup {
  view = { width = 30 },
  renderer = { icons = { show = { file = false, folder = false, git = false } } },
  update_focused_file = { enable = true },
}
require('which-key').setup { delay = 300, icons = { mappings = false } }
require('which-key').add {
  { '<leader>f', group = 'Dateien / Suche' },
  { '<leader>b', group = 'Buffer' },
  { '<leader>c', group = 'Code' },
  { '<leader>x', group = 'Diagnosen' },
  { '<leader>s', group = 'Splits' },
  { '<leader>t', group = 'Terminal' },
  { '<leader>u', group = 'Ansicht' },
}

-- Parser liefern Syntaxfarben; LSP liefert Codeverständnis. Das ist unabhängig.
-- Neue Sprache: Parsernamen ergänzen; :TSUpdate nach Plugin-Updates ausführen.
local parsers =
{ 'lua', 'vim', 'vimdoc', 'query', 'javascript', 'typescript', 'tsx', 'html', 'css', 'json', 'python', 'c_sharp',
  'markdown', 'markdown_inline', 'bash' }
local function highlight(buf)
  if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
    -- Ohne fertigen Parser bleibt die eingebaute Syntaxhervorhebung aktiv.
    pcall(vim.treesitter.start, buf)
  end
end
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  callback = function(event) highlight(event.buf) end,
})
require('nvim-treesitter').install(parsers):await(function()
  -- Auch bereits geöffnete Dateien nach der ersten Parserinstallation aktivieren.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then highlight(buf) end
  end
end)

-- 3. Sprachserver ------------------------------------------------------------
-- nvim-lspconfig liefert Startbefehle/Projektwurzeln, Mason installiert Programme.
-- Neue Sprache: z.B. gopls = {} ergänzen; Mason übernimmt diesen Server ebenfalls.
-- Projektabhängigkeiten (ESLint, Angular etc.) weiterhin im Projekt installieren.
local servers = {
  ts_ls = {},
  angularls = {},
  html = { filetypes = { 'html', 'htmlangular' } },
  eslint = { settings = { workingDirectory = { mode = 'auto' }, format = true } },
  basedpyright = {},
  ruff = {
    on_attach = function(client) client.server_capabilities.hoverProvider = false end,
  }, -- Python-Hover kommt von basedpyright, Formatierung von Ruff.
  omnisharp = { cmd_env = { DOTNET_ROLL_FORWARD = 'LatestMajor' } },
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        diagnostics = { globals = { 'vim' } },
        workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        format = { enable = true },
      },
    },
  },
}
require('mason').setup {}
for name, config in pairs(servers) do
  vim.lsp.config(name, config)
end
require('mason-lspconfig').setup {
  ensure_installed = vim.tbl_keys(servers),
  automatic_enable = vim.tbl_keys(servers), -- Nur diese Server, keine alten Mason-Installationen.
}

vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method 'textDocument/completion' then
      vim.lsp.completion.enable(true, client.id,
        event.buf, { autotrigger = true })
    end
  end,
})
-- Native Completion: Ctrl-Space anfordern, Ctrl-n/p auswählen, Ctrl-y übernehmen.
vim.keymap.set('i', '<C-Space>', vim.lsp.completion.get, { desc = 'Vervollständigung' })

-- 4. Formatierung ------------------------------------------------------------
-- Genau ein Formatter pro Dateityp, auch wenn mehrere LSPs angeschlossen sind.
-- ESLints Formatierungsanfrage führt die verfügbaren ESLint-Fixes aus (kein Prettier).
local formatters = {
  javascript = 'eslint',
  javascriptreact = 'eslint',
  typescript = 'eslint',
  typescriptreact = 'eslint',
  html = 'html',
  htmlangular = 'html',
  python = 'ruff',
  cs = 'omnisharp',
  lua = 'lua_ls',
}
local timeout_ms = 2000 -- Pro LSP-Anfrage begrenzt warten, bevor gespeichert wird.

-- Ruff liefert Importsortierung als Code-Action. Synchron abfragen und anwenden,
-- damit die Änderungen vor dem Schreiben auf der Platte landen.
local function organize_imports(client, buf)
  local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
  params.context = { diagnostics = {}, only = { 'source.organizeImports.ruff' } }
  local response, err = client:request_sync('textDocument/codeAction', params, timeout_ms, buf)
  if err or (response and response.err) then error(vim.inspect(err or response.err)) end
  for _, action in ipairs(response and response.result or {}) do
    if not action.disabled then
      if not action.edit and client:supports_method 'codeAction/resolve' then
        local resolved, resolve_err = client:request_sync('codeAction/resolve', action, timeout_ms, buf)
        if resolve_err or (resolved and resolved.err) then error(vim.inspect(resolve_err or resolved.err)) end
        action = resolved and resolved.result or action
      end
      if action.edit then vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding) end
      if action.command then
        local command = type(action.command) == 'table' and action.command or action
        local result, command_err = client:request_sync('workspace/executeCommand', command, timeout_ms, buf)
        if command_err or (result and result.err) then error(vim.inspect(command_err or result.err)) end
      end
    end
  end
end

local function format_buffer(buf)
  local name = formatters[vim.bo[buf].filetype]
  if not name then return end
  local client = vim.lsp.get_clients({ bufnr = buf, name = name, method = 'textDocument/formatting' })[1]
  if not client then return end -- Datei auch ohne installierten/gestarteten Server speichern.
  local ok, err = pcall(function()
    if name == 'ruff' then organize_imports(client, buf) end
    vim.lsp.buf.format { bufnr = buf, id = client.id, async = false, timeout_ms = timeout_ms }
  end)
  if not ok then vim.notify('Formatierung: ' .. tostring(err), vim.log.levels.WARN) end
end

vim.api.nvim_create_autocmd('BufWritePre', {
  group = group,
  callback = function(event)
    local buf = event.buf
    if vim.bo[buf].buftype ~= '' or not vim.bo[buf].modifiable or vim.bo[buf].binary then return end
    -- buf_call hält auch :wall korrekt: LSP-Parameter beziehen sich auf diese Datei.
    vim.api.nvim_buf_call(buf, function()
      format_buffer(buf)
      local view = vim.fn.winsaveview()
      vim.cmd [[keeppatterns %s/\s\+$//e]]
      vim.fn.winrestview(view)
      vim.bo[buf].fixendofline = true
      vim.bo[buf].endofline = true
    end)
  end,
})

-- 5. Tastenkürzel ------------------------------------------------------------
-- map('n', '<leader>...', Aktion, { desc = 'Beschreibung' }) ergänzen.
-- desc erscheint in Which-Key; Space kurz halten zeigt die vorhandenen Gruppen.
local map = vim.keymap.set
local fzf = require 'fzf-lua'
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Suchmarkierung löschen' })
map('n', '<leader><leader>', fzf.files, { desc = 'Datei suchen' })
map('n', '<leader>ff', fzf.files, { desc = 'Datei suchen' })
map('n', '<leader>fg', fzf.live_grep, { desc = 'Projekt durchsuchen' })
map('n', '<leader>/', fzf.live_grep, { desc = 'Projekt durchsuchen' })
map('n', '<leader>fs', fzf.lsp_live_workspace_symbols, { desc = 'Projektsymbole' })
map('n', '<leader>fo', fzf.lsp_document_symbols, { desc = 'Dateisymbole' })
map('n', '<leader>e', '<cmd>NvimTreeToggle<CR>', { desc = 'Explorer umschalten' })
map('n', '<leader>fe', '<cmd>NvimTreeFindFile<CR>', { desc = 'Datei im Explorer zeigen' })
map('n', '<leader>bb', '<C-^>', { desc = 'Vorherige Datei' })
map('n', '<leader>bn', '<cmd>bnext<CR>', { desc = 'Nächster Buffer' })
map('n', '<leader>bp', '<cmd>bprevious<CR>', { desc = 'Vorheriger Buffer' })
map('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = 'Buffer schließen' })
map('n', '<leader>fb', fzf.buffers, { desc = 'Buffer auswählen' })
map('n', '<leader>ca', vim.lsp.buf.code_action, { desc = 'Code-Action' })
map('n', '<leader>cr', vim.lsp.buf.rename, { desc = 'Symbol umbenennen' })
map('n', '<leader>j', goto_word, { desc = 'Zu Wort springen' })
map('n', '<leader>cf', function() format_buffer(vim.api.nvim_get_current_buf()) end, { desc = 'Datei formatieren' })
map('n', '<leader>cu', fzf.lsp_references, { desc = 'Verwendungen' })
map('n', 'gd', vim.lsp.buf.definition, { desc = 'Zur Definition' })
map('n', '<leader>xx', fzf.diagnostics_workspace, { desc = 'Alle bekannten Diagnosen' })
map('n', '<leader>xf', fzf.diagnostics_document, { desc = 'Diagnosen dieser Datei' })
map('n', '<leader>xn', function() vim.diagnostic.jump { count = 1, float = true } end, { desc = 'Nächste Diagnose' })
map('n', '<leader>xp', function() vim.diagnostic.jump { count = -1, float = true } end, { desc = 'Vorherige Diagnose' })
map(
  'n',
  '<leader>xi',
  function() vim.diagnostic.config { virtual_text = not vim.diagnostic.config().virtual_text } end,
  { desc = 'Inline-Diagnosen umschalten' }
)
vim.diagnostic.config { virtual_text = false, severity_sort = true, float = { border = 'rounded' } }
map('n', '<leader>sl', '<cmd>rightbelow vsplit<CR>', { desc = 'Split rechts' })
map('n', '<leader>sh', '<cmd>leftabove vsplit<CR>', { desc = 'Split links' })
map('n', '<leader>sj', '<cmd>rightbelow split<CR>', { desc = 'Split unten' })
map('n', '<leader>sk', '<cmd>leftabove split<CR>', { desc = 'Split oben' })
map('n', '<leader>un', function() vim.wo.relativenumber = not vim.wo.relativenumber end,
  { desc = 'Relative Zeilennummern' })
map(
  'n',
  '<leader>ui',
  function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = 0 }, { bufnr = 0 }) end,
  { desc = 'Inlay-Hints umschalten' }
)
map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Speichern' })
map('n', '<leader>p', fzf.commands, { desc = 'Befehle' })

-- Ein wiederverwendbares Terminal unten; Schließen des Fensters erhält die Shell.
-- Space tn erstellt bewusst eine neue Shell; Space tt merkt sich die zuletzt erstellte.
local terminal_buf
local function terminal(new)
  if not new and terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
    local win = vim.fn.bufwinid(terminal_buf)
    if win ~= -1 then
      vim.api.nvim_win_close(win, false)
      return
    end
    vim.cmd 'botright 12split'
    vim.api.nvim_win_set_buf(0, terminal_buf)
  else
    vim.cmd 'botright 12new'
    vim.cmd.terminal(vim.fn.executable 'zsh' == 1 and 'zsh' or vim.o.shell)
    terminal_buf = vim.api.nvim_get_current_buf()
    vim.bo.bufhidden = 'hide'
  end
  vim.cmd 'startinsert'
end
map('n', '<leader>tt', function() terminal(false) end, { desc = 'Terminal umschalten' })
map('n', '<leader>tn', function() terminal(true) end, { desc = 'Neues Terminal' })
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Terminal-Normalmodus' })
-- Auch direkt aus der laufenden Shell mit den gewohnten Ctrl-w-Tasten navigieren.
for _, key in ipairs { 'h', 'j', 'k', 'l', 'q', 'c' } do
  map('t', '<C-w>' .. key, '<C-\\><C-n><C-w>' .. key, { desc = 'Terminalfenster: ' .. key })
end
