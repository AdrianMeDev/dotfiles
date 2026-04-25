local gh = function(x) return "https://github.com/" .. x end

vim.pack.add({
  { src = gh("folke/snacks.nvim"), name = "snacks.nvim" },
})

require("snacks").setup({
picker = { enabled = true },
explorer = { enabled = true },

-- optional, aber oft nützlich:
input = { enabled = true },
notifier = { enabled = true },
quickfile = { enabled = true },
})

vim.keymap.set("n", "<leader>e", function()
Snacks.explorer()
end, { desc = "Explorer (Snacks)" })

vim.keymap.set("n", "<leader>fe", function()
Snacks.explorer()
end, { desc = "Explorer (Snacks)" })

vim.keymap.set("n", "<leader><space>", function()
Snacks.picker.smart()
end, { desc = "Smart Find Files" })
