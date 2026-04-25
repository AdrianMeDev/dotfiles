local pack = require("util.pack")

vim.pack.add({
	{ src = pack.gh("dmmulroy/ts-error-translator.nvim"), name = "ts-error-translator.nvim" },
})

require("ts-error-translator").setup({
	servers = {
		"astro",
		"svelte",
		"ts_ls",
		"tsserver", -- deprecated, use ts_ls
		"typescript-tools",
		"volar",
		"vtsls",
	},
})
