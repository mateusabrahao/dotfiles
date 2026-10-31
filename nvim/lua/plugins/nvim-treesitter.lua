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

    require("nvim-treesitter").install({ "c", "lua", "vim", "vimdoc", "rust", "go", "cpp", "javascript", "html", "python", "dart" })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "c", "lua", "vim", "vimdoc", "rust", "go", "cpp", "javascript", "html", "python", "dart" },
      callback = function(args)
        vim.treesitter.start(args.buf)
      end,
    })
  end,
}
