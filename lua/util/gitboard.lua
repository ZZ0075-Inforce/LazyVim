-- util/gitboard.lua
-- 多 repo Git 總覽面板：掃描當前 workspace 專案底下所有子 repo，依分支分組
-- 用法：require("util.gitboard").open()
--
-- 定位是「發現」不是「審閱」：只回答「哪些 repo 我動過 / 沒推上去」，
-- 選中後把 cwd 切過去、交給 Neogit 處理，審閱工具一概不重造。

local M = {}

local uv = vim.uv or vim.loop

-- ── 設定 ──────────────────────────────────────────────
local INDENT = "    " -- repo 層縮排
local NAME_COL = 26 -- 名稱欄寬（超過就不對齊，不截斷）
local WIDTH = 56 -- 面板寬度
local ICONS = {
  expanded = "▼ ",
  collapsed = "▶ ",
}

local ns = vim.api.nvim_create_namespace("gitboard")

-- ── 內部狀態 ──────────────────────────────────────────
local state = {
  buf = nil,
  win = nil,
  root = nil, -- 偵測到的 workspace 專案根
  repos = {}, -- { {name, path, info?, err?}, ... }
  groups = {}, -- 依分支分組後的結果
  display = {}, -- 目前顯示中的節點（依行號，第 1 行為 header）
  expanded = {}, -- 使用者手動切換過的分組展開狀態（分支名 -> bool）
  generation = 0, -- 世代計數；重掃/關閉面板時遞增，使過期的非同步回應失效
  pending = 0, -- 尚未回應的 git 呼叫數
}

--- 遞增世代，使所有進行中的回應失效
local function cancel_pending()
  state.generation = state.generation + 1
  state.pending = 0
end

-- ── 根目錄偵測 ────────────────────────────────────────

--- 列出 dir 底下「直屬子目錄中含 .git」的項目。
--- .git 可能是檔案（worktree / submodule），只判存在、不判型別。
local function child_repos(dir)
  local fd = uv.fs_scandir(dir)
  if not fd then
    return {}
  end
  local out = {}
  while true do
    local name, t = uv.fs_scandir_next(fd)
    if not name then
      break
    end
    -- t 在某些檔案系統上為 nil，一律當目錄候選試一次
    if t == "directory" or t == "link" or t == nil then
      local path = dir .. "/" .. name
      if uv.fs_stat(path .. "/.git") then
        out[#out + 1] = { name = name, path = path }
      end
    end
  end
  table.sort(out, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return out
end

--- 自 start 逐層往上，取「最低」符合「直屬子目錄中存在 .git」的那層。
--- 自底向上取最低者，可自動避開更上層碰巧也含 repo 的目錄（如 workspace 根本身）。
--- 守衛：走到家目錄或磁碟根即停，避免掃到 C:\ 這種層級。
local function find_root(start)
  local home = uv.os_homedir()
  home = home and vim.fs.normalize(home) or nil
  local dir = vim.fs.normalize(start)
  while dir and dir ~= "" do
    local repos = child_repos(dir)
    if #repos > 0 then
      return dir, repos
    end
    if home and dir == home then
      break
    end
    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
  return nil, {}
end

-- ── 資料收集 ──────────────────────────────────────────

--- 解析 git status --porcelain=v2 --branch 的輸出。
--- 一次呼叫給齊分支 / upstream / ahead / 變更數，不必逐項查詢；
--- 且零 commit 時 branch.head 仍給得出真正的分支名（rev-parse 只會回無用的 HEAD）。
local function parse_status(out)
  local info = {
    branch = nil,
    upstream = nil,
    ahead = 0,
    initial = false,
    detached = false,
    changed = 0,
    untracked = 0,
  }
  for line in (out or ""):gmatch("[^\r\n]+") do
    local head = line:match("^# branch%.head (.+)$")
    local oid = line:match("^# branch%.oid (.+)$")
    local upstream = line:match("^# branch%.upstream (.+)$")
    local ab = line:match("^# branch%.ab (.+)$")
    if head then
      info.branch = head
      info.detached = (head == "(detached)")
    elseif oid then
      info.initial = (oid == "(initial)")
    elseif upstream then
      info.upstream = upstream
    elseif ab then
      info.ahead = tonumber(ab:match("^%+(%d+)")) or 0
    elseif not line:match("^#") then
      info.changed = info.changed + 1
      if line:match("^%?") then
        info.untracked = info.untracked + 1
      end
    end
  end
  return info
end

--- 這個 repo 值得注意嗎？（決定排序與預設展開）
local function is_notable(repo)
  if repo.err then
    return true
  end
  local i = repo.info
  if not i then
    return false
  end
  return i.changed > 0 or i.ahead > 0 or i.upstream == nil or i.initial or i.detached
end

--- 這個 repo 的分組鍵
local function group_key(repo)
  if repo.err then
    return "(git 失敗)"
  end
  return (repo.info and repo.info.branch) or "(未知)"
end

-- ── 分組 ─────────────────────────────────────────────

--- 由 state.repos 重建 state.groups
local function rebuild_groups()
  local by_branch, order = {}, {}
  for _, repo in ipairs(state.repos) do
    if repo.info or repo.err then
      local key = group_key(repo)
      if not by_branch[key] then
        by_branch[key] = { branch = key, repos = {}, notable = false }
        order[#order + 1] = by_branch[key]
      end
      local g = by_branch[key]
      g.repos[#g.repos + 1] = repo
      if is_notable(repo) then
        g.notable = true
      end
    end
  end

  for _, g in ipairs(order) do
    -- 組內：值得注意的排前，其餘依名稱
    table.sort(g.repos, function(a, b)
      local na, nb = is_notable(a), is_notable(b)
      if na ~= nb then
        return na
      end
      return a.name:lower() < b.name:lower()
    end)
    -- 展開狀態：使用者手動切換過就聽使用者的，否則「有值得注意的才展開」
    if state.expanded[g.branch] == nil then
      g.expanded = g.notable
    else
      g.expanded = state.expanded[g.branch]
    end
  end

  -- 分組間：值得注意的排前，其餘依名稱
  table.sort(order, function(a, b)
    if a.notable ~= b.notable then
      return a.notable
    end
    return a.branch:lower() < b.branch:lower()
  end)

  state.groups = order
end

-- ── 渲染 ─────────────────────────────────────────────

--- 產生 repo 行的標記字串
local function repo_markers(repo)
  if repo.err then
    return "⚠ git 失敗"
  end
  local i = repo.info
  local parts = {}
  if i.changed > 0 then
    parts[#parts + 1] = "●" .. i.changed
  end
  if i.ahead > 0 then
    parts[#parts + 1] = "↑" .. i.ahead
  end
  if i.initial then
    parts[#parts + 1] = "⚠ 尚無 commit"
  elseif i.detached then
    parts[#parts + 1] = "⚠ 斷頭"
  elseif not i.upstream then
    parts[#parts + 1] = "⚠ 無 upstream"
  end
  return table.concat(parts, "  ")
end

--- 依顯示寬度補空白，讓標記欄對齊
local function pad_to(str, col)
  return string.rep(" ", math.max(1, col - vim.fn.strdisplaywidth(str)))
end

--- 攤平成顯示行；回傳 lines, nodes, highlights
local function build_lines()
  local lines, nodes, hls = {}, {}, {}

  -- header：偵測到的根 + repo 總數（驗證根偵測就靠這行）
  local done = #state.repos - state.pending
  local loading = state.pending > 0 and ("  … " .. done .. "/" .. #state.repos) or ""
  local root_str = state.root or "(找不到 workspace 根)"
  local n = #state.repos
  local header = root_str .. "  " .. n .. (n == 1 and " repo" or " repos") .. loading
  lines[1] = header
  nodes[1] = { kind = "header" }
  hls[1] = { { 0, #root_str, "Directory" }, { #root_str, #header, "Comment" } }

  for _, g in ipairs(state.groups) do
    local icon = g.expanded and ICONS.expanded or ICONS.collapsed
    local label = icon .. g.branch
    local tail = #g.repos .. (#g.repos == 1 and " repo" or " repos") .. (g.notable and "" or "  ✓")
    local line = label .. pad_to(label, NAME_COL + #INDENT) .. tail
    lines[#lines + 1] = line
    nodes[#nodes + 1] = { kind = "group", group = g }
    hls[#hls + 1] = {
      { 0, #icon, "Special" },
      { #icon, #icon + #g.branch, g.notable and "Function" or "Comment" },
      { #icon + #g.branch, #line, "Comment" },
    }

    if g.expanded then
      for _, repo in ipairs(g.repos) do
        local name = INDENT .. repo.name
        local markers = repo_markers(repo)
        local rline = markers == "" and name or (name .. pad_to(name, NAME_COL + #INDENT) .. markers)
        lines[#lines + 1] = rline
        nodes[#nodes + 1] = { kind = "repo", repo = repo, group = g }
        local i = repo.info
        local warn = repo.err or (i and (not i.upstream or i.initial or i.detached))
        hls[#hls + 1] = {
          { #INDENT, #INDENT + #repo.name, is_notable(repo) and "Normal" or "Comment" },
          { #name, #rline, warn and "DiagnosticWarn" or "DiagnosticInfo" },
        }
      end
    end
  end

  return lines, nodes, hls
end

--- 重新渲染 buffer（保留游標行）
local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local row
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    row = vim.api.nvim_win_get_cursor(state.win)[1]
  end

  local lines, nodes, hls = build_lines()
  state.display = nodes

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for i, spans in ipairs(hls) do
    for _, s in ipairs(spans) do
      if s[2] > s[1] then
        pcall(vim.api.nvim_buf_set_extmark, state.buf, ns, i - 1, s[1], { end_col = s[2], hl_group = s[3] })
      end
    end
  end

  if row and state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_cursor(state.win, { math.min(row, #lines), 0 })
  end
end

-- ── Buffer / Window 管理 ──────────────────────────────

local function close_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    -- 若是最後一個視窗，nvim_win_close 會失敗，交給 pcall 吞掉
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
end

--- 使用者關閉面板：取消進行中的查詢並關窗
local function close_panel()
  cancel_pending()
  close_window()
end

local function create_buffer()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "gitboard"
  vim.bo[buf].modifiable = false
  state.buf = buf
  return buf
end

local function open_window()
  close_window()
  local buf = create_buffer()

  vim.cmd("topleft vertical " .. WIDTH .. "split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].winfixwidth = true

  state.win = win
  pcall(vim.api.nvim_buf_set_name, buf, "Workspace Git")
  return win
end

-- ── Keymap 動作 ───────────────────────────────────────

-- 前置宣告：open_lazygit 與 refresh 都要用，但 scan 定義在檔案後段
local scan

local function get_cursor_node()
  if not state.display or not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.display[row]
end

--- 切換分組展開狀態
local function toggle_group()
  local node = get_cursor_node()
  if not node or node.kind ~= "group" then
    return
  end
  local g = node.group
  g.expanded = not g.expanded
  state.expanded[g.branch] = g.expanded
  render()
end

--- 收合指定分組，並把游標移到該分組的標題行
local function collapse_group(g)
  g.expanded = false
  state.expanded[g.branch] = false
  render()
  for row, node in ipairs(state.display) do
    if node.kind == "group" and node.group == g then
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_cursor(state.win, { row, 0 })
      end
      return
    end
  end
end

--- 前往該 repo：關閉面板、tcd 過去、開 Neogit
local function goto_repo()
  local node = get_cursor_node()
  if not node then
    return
  end
  if node.kind == "group" then
    toggle_group()
    return
  end
  if node.kind ~= "repo" then
    return
  end

  local path = node.repo.path
  close_panel()
  vim.cmd("tcd " .. vim.fn.fnameescape(path))
  -- 走 spec 已宣告的 cmd = "Neogit" 觸發載入，不依賴 lazy 對 require 的攔截
  vim.cmd("Neogit cwd=" .. vim.fn.fnameescape(path))
end

--- 在選中的 repo 開 lazygit：不動 cwd、不關面板。
--- 語意刻意與 <CR> 相對——<CR> 是「切過去待著」，這裡是「看一眼就回來」。
--- lazygit 是浮動視窗，離開後焦點自然回到面板，可接著看下一個 repo。
--- 註：Snacks 的 terminal id 由 cmd+cwd+env 組成，故每個 repo 各自一個實例且會重用。
local function open_lazygit()
  local node = get_cursor_node()
  if not node or node.kind ~= "repo" then
    return
  end

  local term = Snacks.lazygit({ cwd = node.repo.path })

  -- 離開 lazygit 時該 repo 可能已 stage/commit/push，面板數字就過期了，重掃一次。
  -- 用 generation 防呆：面板已關或期間被重開過就不做，避免把已關的面板叫回來。
  if term and term.on then
    local gen = state.generation
    term:on("TermClose", function()
      vim.schedule(function()
        if gen == state.generation and state.win and vim.api.nvim_win_is_valid(state.win) then
          scan(state.root)
        end
      end)
    end, { buf = true })
  end
end

local function set_all_expanded(value)
  for _, g in ipairs(state.groups) do
    g.expanded = value
    state.expanded[g.branch] = value
  end
  render()
end

local function refresh()
  if not state.root then
    return
  end
  state.expanded = {}
  scan(state.root)
end

local function setup_keymaps()
  local opts = { buffer = state.buf, nowait = true, silent = true }
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
  end

  map("<CR>", goto_repo, "展開收合 / 前往該 repo")
  map("o", goto_repo, "展開收合 / 前往該 repo")
  map("l", goto_repo, "展開收合 / 前往該 repo")
  map("h", function()
    local node = get_cursor_node()
    if not node then
      return
    end
    if node.kind == "group" and node.group.expanded then
      toggle_group()
    elseif node.kind == "repo" then
      -- 兩層樹裡 repo 行的 h 語意是「收合我所屬的分組」，收完把游標帶回分組行
      collapse_group(node.group)
    end
  end, "收合分組")

  -- 用 G 不用 g：g 是 Vim 前綴鍵，配上 nowait 會讓 gg 變成「連按兩次 g」，
  -- 既跳不到首行又誤開兩次 lazygit（實測過）。G 立即觸發、不影響 gg，
  -- 且面板本來就已把 L/H 挪作展開收合，佔用大寫鍵有前例。
  map("G", open_lazygit, "在此 repo 開 lazygit")

  map("L", function()
    set_all_expanded(true)
  end, "全部展開")
  map("H", function()
    set_all_expanded(false)
  end, "全部收合")
  map("R", refresh, "重新掃描")
  map("q", close_panel, "關閉")
  map("<Esc>", close_panel, "關閉")

  map("?", function()
    vim.notify(
      table.concat({
        "Workspace Git 總覽:",
        "  <CR>/o/l  分支行：展開 / 收合這一組",
        "            repo 行：工作目錄切到該 repo + 開 Neogit（面板關閉）",
        "  G         repo 行：開該 repo 的 lazygit",
        "            （不切目錄、面板保留，離開後自動重掃）",
        "  h         收合分組",
        "  L / H     全部展開 / 全部收合",
        "  R         重新掃描",
        "  q/<Esc>   關閉面板",
        "  ?         顯示此幫助",
        "",
        "標記: ●N 變更檔數(含未追蹤)  ↑N 領先未推  ⚠ 需注意",
        "註: 不做 fetch，故不顯示 behind——未 fetch 時該數字永遠是 0，是假保證。",
      }, "\n"),
      vim.log.levels.INFO
    )
  end, "幫助")
end

-- ── 掃描 ─────────────────────────────────────────────

--- 對 root 底下所有子 repo 並行跑 git status，逐筆回填後重繪
scan = function(root)
  cancel_pending()
  local gen = state.generation

  state.root = root
  state.repos = child_repos(root)
  state.groups = {}
  state.pending = #state.repos
  render()

  if #state.repos == 0 then
    return
  end

  for _, repo in ipairs(state.repos) do
    vim.system({ "git", "-C", repo.path, "status", "--porcelain=v2", "--branch" }, { text = true }, function(res)
      vim.schedule(function()
        if gen ~= state.generation then
          return -- 過期的回應，丟棄
        end
        if res.code ~= 0 then
          repo.err = true
        else
          repo.info = parse_status(res.stdout)
        end
        state.pending = state.pending - 1
        rebuild_groups()
        render()
      end)
    end)
  end
end

-- ── 公開 API ─────────────────────────────────────────

function M.open()
  local cwd = vim.fn.getcwd()
  local root = find_root(cwd)
  if not root then
    vim.notify("gitboard: 從 " .. cwd .. " 往上找不到含子 repo 的目錄", vim.log.levels.WARN)
    return
  end

  state.expanded = {}
  open_window()
  setup_keymaps()
  scan(root)
end

return M
