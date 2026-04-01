-- Options are automatically loaded before lazy.nvim startup
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Relative line numbers (default in LazyVim, explicit for clarity)
vim.opt.relativenumber = true

-- Clipboard: use system clipboard
vim.opt.clipboard = "unnamedplus"

-- Indentation defaults (overridden per language by LSP/treesitter)
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Scroll offset
vim.opt.scrolloff = 8
