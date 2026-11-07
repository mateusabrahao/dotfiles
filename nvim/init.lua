vim.g.mapleader = ' '

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")

vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme gruvbox]])
vim.api.nvim_set_hl(0, "SignColumn", { bg = "#282828" })

-- barbar plugin
vim.api.nvim_set_hl(0, "BufferCurrent", { fg = "#ebdbb2" })

vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*:*",
  callback = function()
    vim.schedule(function()
      vim.cmd("redraw!")
    end)
  end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "GitSignsUpdate",
  callback = function()
    vim.cmd("redrawstatus")
  end,
})
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.opt.showcmd = false
vim.opt.clipboard = 'unnamedplus'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.api.nvim_set_hl(0, "ModeMsg", { fg = "#ebdbb2", bold = false })

-- file
vim.keymap.set('n', '<leader>fs', '<cmd>write<CR>', { desc = 'Save file' })

-- buffer
vim.keymap.set('n', '<leader>bn', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bp', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = 'Kill buffer' })
vim.keymap.set('n', '<leader>by', '<cmd>%yank +<CR>', { desc = 'Yank buffer' })
for i = 1, 9 do
    vim.keymap.set('n', '<leader>' .. i, '<cmd>BufferGoto ' .. i .. '<CR>', { silent = true, desc = 'which_key_ignore' })
end

-- window management
vim.keymap.set('n', '<leader>wv', '<cmd>vsplit<CR>', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>ws', '<cmd>split<CR>', { desc = 'Split window' })
vim.keymap.set('n', '<leader>ww', '<C-w>w', { desc = 'Switch window' })
vim.keymap.set('n', '<leader>wq', '<cmd>quit<CR>', { desc = 'Close window' })
vim.keymap.set('n', '<leader>wh', '<C-w>h', { desc = 'Go to left window' })
vim.keymap.set('n', '<leader>wj', '<C-w>j', { desc = 'Go to bottom window' })
vim.keymap.set('n', '<leader>wk', '<C-w>k', { desc = 'Go to top window' })
vim.keymap.set('n', '<leader>wl', '<C-w>l', { desc = 'Go to right window' })
vim.keymap.set('n', '<leader>wT', '<C-w>T', { desc = 'Move window to new tab' })

-- nvim-tree binds 
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-h>', '<C-w>h', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-j>', '<C-w>j', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-k>', '<C-w>k', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-l>', '<C-w>l', { noremap = true, silent = true })
