return {
  "ellisonleao/gruvbox.nvim",
  priority = 1000,
  config = function()
    require("gruvbox").setup({
            italic = { strings = false, emphasize = false, comments = false, operators = false, folds = false, },
    })
  end,
}
