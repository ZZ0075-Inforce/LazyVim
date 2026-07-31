-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- 註：java 不 autoformat 已由 options.lua 的 vim.g.autoformat = false 全域涵蓋，
-- 原本針對 java 的 vim.b.autoformat = false 為多餘，已移除。
-- 若日後把全域 autoformat 打開，需在此重新為 java 補上 buffer 層關閉。

-- Disable spell checking and wrapping enabled by LazyVim
-- 用 pcall 包住：若 LazyVim 改名/移除此 augroup，才不會在啟動時報錯
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap_spell")
