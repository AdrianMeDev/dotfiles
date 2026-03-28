-- lua/plugins/rose-pine.lua
return {
  "rose-pine/neovim",
  name = "rose-pine",
  priority = 1000,
  config = function()
    vim.o.termguicolors = true

    require("rose-pine").setup({
      styles = {
        transparency = true,
      },

      highlight_groups = {
        Normal       = { bg = "none" },
        NormalNC     = { bg = "none" },
        SignColumn   = { bg = "none" },
        EndOfBuffer  = { bg = "none" },
        LineNr       = { bg = "none" },
        FoldColumn   = { bg = "none" },
        NormalFloat  = { bg = "none" },
        FloatBorder  = { bg = "none" },
      },
    })

    vim.cmd.colorscheme("rose-pine")
  end,
}

