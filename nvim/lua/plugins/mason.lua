local pack = require("util.pack")

vim.pack.add({
  { src = pack.gh("mason-org/mason.nvim"), name = "mason.nvim" },
  { src = pack.gh("mason-org/mason-lspconfig.nvim"), name = "mason-lspconfig.nvim" },
  { src = pack.gh("WhoIsSethDaniel/mason-tool-installer.nvim"), name = "mason-tool-installer.nvim" },
  { src = pack.gh("neovim/nvim-lspconfig"), name = "nvim-lspconfig" },
})

require("mason").setup()

require("mason-lspconfig").setup({
  ensure_installed = {
    "bashls",
    "clangd",
    "lua_ls",
    "pyright",
    "ts_ls",
    "gopls",
  },
})

require("mason-tool-installer").setup({
  ensure_installed = {
    "bash-language-server",
    "clangd",
    "efm",
    "lua-language-server",
    "pyright",
    "typescript-language-server",
    "black",
    "flake8",
    "prettierd",
    "eslint_d",
    "fixjson",
    "cpplint",
    "clang-format",
    "stylua",
    "shellcheck",
    "shfmt",
    "gofumpt",
    "revive",
  },
  auto_update = false,
  run_on_start = true,
})
