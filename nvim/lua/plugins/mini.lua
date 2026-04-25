local gh = function(repo)
  return "https://github.com/" .. repo
end

vim.pack.add({
  { src = gh("nvim-mini/mini.nvim"), name = "mini.nvim" },
})

require("mini.ai").setup({})
require("mini.comment").setup({})
require("mini.move").setup({})
require("mini.surround").setup({})
require("mini.cursorword").setup({})
require("mini.indentscope").setup({})
require("mini.pairs").setup({})
require("mini.trailspace").setup({})
require("mini.bufremove").setup({})
require("mini.notify").setup({})
require("mini.icons").setup({})
