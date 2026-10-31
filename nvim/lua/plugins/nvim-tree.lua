return {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
        "nvim-tree/nvim-web-devicons"
    },
    config = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1

        -- optionally enable 24-bit colour
        vim.opt.termguicolors = true

        require("nvim-tree").setup({
          sort = {
            sorter = "case_sensitive",
          },
          view = {
            width = 30,
          },
          renderer = {
              group_empty = true,
              icons = {
                  show = {
                      git = false,
                      file = true,
                      folder = false,
                      folder_arrow = true,
                  },
                  glyphs = {
                      folder = {
                          arrow_closed = "⏵",
                          arrow_open = "⏷",
                      },
                  },
              },
          },
          filters = {
            dotfiles = true,
          },
        })

        vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "#242424" })
        vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { bg = "#242424" })
    end
}
