-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.clipboard = "unnamedplus"
vim.opt.foldenable = false
vim.opt.foldmethod = "manual"
vim.opt.fixendofline = false


-- Force tree-sitter to use gcc
vim.env.CC = "gcc"
-- Add MinGW bin to PATH so compiled parsers can find runtime DLLs
vim.env.PATH = vim.env.PATH .. ";C:\\ProgramData\\chocolatey\\lib\\mingw\\tools\\install\\mingw64\\bin"
