vim.lsp.enable({
  "bashls",
  "clangd",
  "lua_ls",
  "pyright",
  "ts_ls",
  "gopls",
  "efm",
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      telemetry = {
        enable = false,
      },
    },
  },
})

vim.lsp.config("efm", {
  init_options = {
    documentFormatting = true,
  },
  settings = {
    languages = {
      lua = {
        {
          formatCommand = "stylua -",
          formatStdin = true,
        },
      },
      sh = {
        {
          lintCommand = "shellcheck --color=never --format=gcc -",
          lintStdin = true,
          lintIgnoreExitCode = true,
          lintFormats = {
            "-:%l:%c: %trror: %m",
            "-:%l:%c: %tarning: %m",
            "-:%l:%c: %tote: %m",
          },
        },
        {
          formatCommand = "shfmt -filename '${INPUT}' -",
          formatStdin = true,
        },
      },
      python = {
        {
          lintCommand = "flake8 -",
          lintStdin = true,
          lintIgnoreExitCode = true,
          lintFormats = { "stdin:%l:%c: %t%n %m" },
        },
        {
          formatCommand = "black --quiet -",
          formatStdin = true,
        },
      },
    },
  },
})
