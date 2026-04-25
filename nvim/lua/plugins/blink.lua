local pack = require("util.pack")

vim.pack.add({
  { src = pack.gh("saghen/blink.cmp"), name = "blink.cmp" },
})

require("blink.cmp").setup({
  keymap = {
    preset = "default",
  },
  appearance = {
    nerd_font_variant = "mono",
  },
  completion = {
    documentation = {
      auto_show = true,
    },
  },
  sources = {
    default = { "lsp", "path", "buffer", "snippets" },
  },
})
