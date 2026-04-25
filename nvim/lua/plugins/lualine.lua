local gh = function(repo)
	return "https://github.com/" .. repo
end

vim.pack.add({
	{ src = gh("nvim-lualine/lualine.nvim"), name = "lualine.nvim" },
})

require("lualine").setup({
	options = {
		theme = "auto",
		icons_enabled = true,
		globalstatus = true,
		component_separators = { left = "|", right = "|" },
		section_separators = { left = "", right = "" },
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = { "branch", "diff", "diagnostics" },
		lualine_c = { "filename" },
		lualine_x = { "encoding", "fileformat", "filetype" },
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
})
