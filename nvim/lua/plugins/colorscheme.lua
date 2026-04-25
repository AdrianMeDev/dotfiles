local pack = require("util.pack")

vim.pack.add({
	{ src = pack.gh("folke/tokyonight.nvim"), name = "tokyonight.nvim" },
})

require("tokyonight").setup({
	style = "night",
	transparent = true,
	styles = {
		sidebars = "transparent",
		floats = "transparent",
	},
	on_highlights = function(hl, c)
		local transparent = "NONE"

		local groups = {
			"Normal",
			"NormalNC",
			"EndOfBuffer",
			"NormalFloat",
			"FloatBorder",
			"SignColumn",
			"StatusLine",
			"StatusLineNC",
			"TabLine",
			"TabLineFill",
			"TabLineSel",
			"ColorColumn",
		}

		for _, group in ipairs(groups) do
			hl[group] = { bg = transparent }
		end

		hl.TabLineFill = { bg = transparent, fg = c.comment }
	end,
})

vim.cmd.colorscheme("tokyonight")
