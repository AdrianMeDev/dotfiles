local pack = require("util.pack")

vim.pack.add({
	{ src = pack.gh("otavioschwanck/arrow.nvim"), name = "arrow.nvim" },
})

require("arrow").setup({
	show_icons = true,
	leader_key = ";", -- Recommended to be a single key
	buffer_leader_key = "m", -- Per Buffer Mappings
})
