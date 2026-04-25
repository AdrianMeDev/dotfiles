local gh = function(x) return "https://github.com/" .. x end

vim.pack.add({
  { src = gh("folke/flash.nvim"), name = "flash" },
}, {
  load = false,
})

local function with_flash(fn)
  return function()
    vim.cmd.packadd("flash")
    fn(require("flash"))
  end
end

vim.keymap.set({ "n", "x", "o" }, "s", with_flash(function(flash)
  flash.jump()
end), { desc = "Flash" })

vim.keymap.set({ "n", "x", "o" }, "S", with_flash(function(flash)
  flash.treesitter()
end), { desc = "Flash Treesitter" })
