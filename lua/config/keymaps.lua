-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Undo breakpoints
local undo_ch = { " ", ",", ".", "!", "?", ";", ":" }
for _, ch in ipairs(undo_ch) do
  map("i", ch, ch .. "<C-g>u")
end
map("i", "<CR>", "<CR><C-g>u")

-- Fix for Snacks.picker.git_log_file on Windows (quoting & redirection issue)
-- We use a custom 'proc' picker to fully control the git command.
-- CRITICAL: We must set 'cwd' to the git root and parse the output manually
-- because the default 'git_log' formatter expects a specific internal format.

-- Helper function to run git log with Windows-safe arguments and correct CWD
local function git_log_picker(opts)
  opts = opts or {}
  local path = vim.fn.expand("%:p")
  local cwd = vim.fs.root(path, ".git") or vim.fn.getcwd()

  local args = {
    "-c",
    "core.quotepath=false",
    "log",
    "--pretty=format:%h %s (%ch) [%an]", -- Minimal quoting, use [] for Windows safety
    "--abbrev-commit",
    "--decorate",
    "--date=short",
    "--color=never",
    "--no-show-signature",
    "--no-patch",
  }

  if opts.current_file then
    table.insert(args, "--follow")
    table.insert(args, "--")
    table.insert(args, path)
  end

  Snacks.picker({
    finder = "proc",
    cmd = "git",
    cwd = cwd,
    title = opts.title or "Git Log",
    args = args,
    -- Custom parsing to extract commit hash for preview/actions
    transform = function(item)
      local hash = item.text:match("^(%S+)")
      if hash then
        item.commit = hash
        if opts.current_file then
          item.file = path -- Needed for git_show preview of specific file
        end
      end
      return item
    end,
    -- Explicitly format the item to ensure text is visible
    format = function(item)
      return { { item.text, "SnacksPickerLabel" } }
    end,
    preview = "git_show",
    confirm = "git_checkout",
  })
end

map("n", "<leader>gl", function()
  git_log_picker({ current_file = true, title = "Git Log File" })
end, { desc = "日誌（當前檔案）" })
map("n", "<leader>gL", function()
  git_log_picker({ current_file = false, title = "Git Log" })
end, { desc = "日誌（專案）" })

-- Helper to get git root
local function get_git_cwd()
  local path = vim.fn.expand("%:p")
  return vim.fs.root(path, ".git") or vim.fn.getcwd()
end

-- Gitk mappings for Windows
map("n", "<leader>gk", function()
  vim.fn.jobstart({ "gitk", vim.fn.expand("%:p") }, { cwd = get_git_cwd(), detach = true })
end, { desc = "Gitk（當前檔案）" })

map("n", "<leader>gK", function()
  vim.fn.jobstart({ "gitk" }, { cwd = get_git_cwd(), detach = true })
end, { desc = "Gitk（整個 repo）" })

map("n", "<leader>gD", function()
  Snacks.picker.git_diff({ cwd = get_git_cwd() })
end, { desc = "差異（專案）" })

map("n", "<leader>gs", function()
  Snacks.picker.git_status({ cwd = get_git_cwd() })
end, { desc = "狀態" })

map("n", "<leader>gS", function()
  Snacks.picker.git_stash({ cwd = get_git_cwd() })
end, { desc = "暫存（stash）" })
