return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  dependencies = { "neovim-treesitter/treesitter-parser-registry" },

  config = function()
    require("nvim-treesitter").setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    require("nvim-treesitter").install({ "c", "lua", "vim", "vimdoc", "rust", "go", "cpp", "javascript", "html" })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "c", "lua", "vim", "vimdoc", "rust", "go", "cpp", "javascript", "html" },
      callback = function(args)
        vim.treesitter.start(args.buf)
      end,
    })
  end,
}
