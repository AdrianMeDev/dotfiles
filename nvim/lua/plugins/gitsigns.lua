local pack = require("util.pack")

vim.pack.add({
	{ src = pack.gh("dmmulroy/ts-error-translator.nvim"), name = "gitsigns.nvim" },
})

require("gitsigns").setup({})
