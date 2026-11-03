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

-- <leader>gb：覆寫 LazyVim 的 Git Blame Line（Snacks.picker.git_log_line），
-- 改用 git blametool（my_config 的 CLITools\git-blametool）開 TortoiseGitBlame，跳到游標那一行。
-- 先用 --hidden 查「被合併藏起來的 commit」（一般 blame 和 gitk 都看不到的別人修改），
-- 有的話列出來問要不要改用 first-parent；開視窗時帶 --no-check，不再重問。
map("n", "<leader>gb", function()
  local file = vim.fn.expand("%:p")
  if file == "" then
    return
  end
  file = vim.fs.normalize(file)
  local cwd = get_git_cwd()
  local line = tostring(vim.fn.line("."))
  local function open(first_parent)
    local cmd = { "git", "blametool", "--no-check", "-L", line }
    if first_parent then
      table.insert(cmd, "-f")
    end
    table.insert(cmd, file)
    vim.fn.jobstart(cmd, { cwd = cwd, detach = true })
  end
  vim.system({ "git", "blametool", "--hidden", file }, { cwd = cwd, text = true }, vim.schedule_wrap(function(r)
    if r.code ~= 0 then
      vim.notify(vim.trim((r.stderr or "") .. (r.stdout or "")), vim.log.levels.ERROR, { title = "git blametool" })
      return
    end
    local hidden = vim.trim(r.stdout or "")
    if hidden == "" then
      return open(false)
    end
    local msg = "這個檔有 commit 在合併時被藏起來，一般 blame 和 gitk 都看不到：\n\n"
      .. hidden
      .. "\n\n改用 first-parent 開？"
    local choice = vim.fn.confirm(msg, "&First-parent\n&Normal 一般\n&Cancel", 2)
    if choice == 1 then
      open(true)
    elseif choice == 2 then
      open(false)
    end
  end))
end, { desc = "TortoiseGitBlame（git blametool）" })

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

-- 多 repo 總覽：law_git_workspace 底下一個專案就是 20~30 個獨立 repo，
-- 上面每一個 map 都只作用於單一 .git，沒有工具能一眼看完整個專案。
-- util.gitboard 掃出當前 workspace 專案的所有子 repo，依分支分組。
map("n", "<leader>gw", function()
  require("util.gitboard").open()
end, { desc = "Workspace Git 總覽（多 repo）" })

-- 格式化選取範圍（覆寫 LazyVim 的 visual mode <leader>cf）
-- LazyVim 只把 bufnr 傳給 conform，靠 conform 自己偵測 mode 取 selection；
-- 經 which-key 觸發時 mode 可能已不是 v/V，就會變成整檔格式化。
-- 這裡改成：明確算出選取行 → 只把那幾行餵給 formatter → 寫回。
-- 好處是 sql_formatter 這類「CLI 沒有 range 參數」的 formatter 也能精準只動選取範圍。
map("x", "<leader>cf", function()
  local mode = vim.api.nvim_get_mode().mode
  local srow, erow
  if mode == "v" or mode == "V" or mode == "\22" then
    srow, erow = vim.fn.line("v"), vim.fn.line(".")
  else -- 已離開 visual mode，改讀上次選取的 marks
    srow, erow = vim.fn.line("'<"), vim.fn.line("'>")
  end
  if erow < srow then
    srow, erow = erow, srow
  end

  local conform = require("conform")
  local formatters = conform.list_formatters_to_run(0)
  local names = vim.tbl_map(function(f)
    return f.name
  end, formatters)

  -- 沒有 conform formatter（例如 Java 走 jdtls）就退回 LSP range formatting
  if #names == 0 then
    local last = vim.api.nvim_buf_get_lines(0, erow - 1, erow, true)[1]
    vim.lsp.buf.format({
      bufnr = 0,
      range = { start = { srow, 0 }, ["end"] = { erow, #last } },
    })
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
  -- formatter 輸出一律從第 0 欄開始，先記下原縮排最後補回去
  local indent = lines[1]:match("^%s*")
  local stripped = vim.tbl_map(function(l)
    return (l:gsub("^" .. indent, ""))
  end, lines)

  local err, new = conform.format_lines(names, stripped, { bufnr = 0, timeout_ms = 5000 })
  if err or not new then
    return
  end
  while #new > 0 and new[#new]:match("^%s*$") do
    table.remove(new)
  end
  new = vim.tbl_map(function(l)
    return l == "" and l or indent .. l
  end, new)

  vim.api.nvim_buf_set_lines(0, srow - 1, erow, true, new)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { desc = "格式化選取範圍" })
