-- Neovim Init.lua (starter, customize as needed)
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true

vim.cmd [[
set termguicolors
syntax enable
filetype plugin indent on
]]

-- Example plugin manager (packer.nvim)
-- require('plugins')