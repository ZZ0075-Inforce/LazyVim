-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- System clipboard integration
map("v", "<C-c>", '"+y', { desc = "Copy to system clipboard" })
map("n", "<C-v>", '"+p', { desc = "Paste from system clipboard" })
map("i", "<C-v>", '<C-r>+', { desc = "Paste from system clipboard" })
map("v", "<C-v>", '"+p', { desc = "Paste from system clipboard" })

-- Undo breakpoints
local undo_ch = { " ", ",", ".", "!", "?", ";", ":" }
for _, ch in ipairs(undo_ch) do
  map("i", ch, ch .. "<C-g>u")
end
map("i", "<CR>", "<CR><C-g>u")
