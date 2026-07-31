-- util/calltree.lua
-- 階層式 Call Hierarchy 樹狀檢視（非同步查詢，不阻塞編輯器）
-- 用法：require("util.calltree").incoming() / .outgoing()

local M = {}

-- ── 設定 ──────────────────────────────────────────────
local MAX_DEPTH = 8 -- 最大遞迴深度（防無限迴圈）
local INDENT = "  " -- 每層縮排
local ICONS = {
  expanded = "▼ ",
  collapsed = "▶ ",
  loading = "… ",
  leaf = "  ",
}

local ns = vim.api.nvim_create_namespace("calltree")

-- ── 內部狀態 ──────────────────────────────────────────
local state = {
  buf = nil, -- calltree buffer
  win = nil, -- calltree window
  nodes = {}, -- flat list of tree nodes (one per display line)
  display = {}, -- 目前顯示中的節點（依行號）
  direction = nil, -- "incoming" or "outgoing"
  root_name = nil, -- 起點函式名稱
  source_bufnr = nil, -- 觸發時的程式碼 buffer（用於查詢 LSP）
  client = nil, -- 記住啟動時的 LSP client
  generation = 0, -- 世代計數；重開/關閉面板時遞增，使過期的非同步回應失效
  expanding = false, -- 遞迴展開進行中（防重入）
}

-- ── 工具函式 ──────────────────────────────────────────

--- 取得支援 callHierarchy 的 LSP client
local function get_client(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, c in ipairs(clients) do
    if c:supports_method("textDocument/prepareCallHierarchy") then
      return c
    end
  end
  return nil
end

--- 啟動時記住的 client 是否仍可用（LSP 重啟後會變成殘留 handle）
local function client_alive()
  return state.client ~= nil and not state.client:is_stopped()
end

--- 使進行中的非同步回應失效（重建面板、使用者關閉面板時呼叫）
local function cancel_pending()
  state.generation = state.generation + 1
  state.expanding = false
end

--- 從 URI 取得短檔名
local function short_name(uri)
  local path = vim.uri_to_fname(uri)
  return vim.fn.fnamemodify(path, ":t")
end

--- 建立 tree node
local function make_node(item, depth, parent_index)
  return {
    item = item, -- callHierarchy item
    name = item.name,
    detail = item.detail or "",
    file = short_name(item.uri),
    lnum = item.range.start.line + 1,
    col = item.range.start.character + 1,
    uri = item.uri,
    depth = depth,
    parent = parent_index,
    children = nil, -- nil = 未查詢, {} = 已查詢但無子節點
    expanded = false,
  }
end

-- ── 非同步查詢 ────────────────────────────────────────

--- 非同步查詢某節點的子呼叫者/被呼叫者，完成後以子 item 列表呼叫 cb
--- 世代不符（面板已重建/關閉）時直接丟棄回應，不會呼叫 cb
local function fetch_children_async(node, gen, cb)
  local method = state.direction == "incoming" and "callHierarchy/incomingCalls"
    or "callHierarchy/outgoingCalls"

  local status = state.client:request(method, { item = node.item }, function(err, result)
    vim.schedule(function()
      if gen ~= state.generation then
        return
      end
      local children = {}
      if not err and result then
        for _, call in ipairs(result) do
          local child_item = state.direction == "incoming" and call.from or call.to
          if child_item then
            table.insert(children, child_item)
          end
        end
      end
      cb(children)
    end)
  end)

  if not status then
    cb({})
  end
end

--- 把查回來的子 item 掛到節點上
local function attach_children(node, children)
  node.children = {}
  node._fetched = true
  for _, child_item in ipairs(children) do
    local child_node = make_node(child_item, node.depth + 1, nil)
    table.insert(state.nodes, child_node)
    table.insert(node.children, #state.nodes)
  end
end

-- ── 渲染 ─────────────────────────────────────────────

--- 產生一行顯示文字，並回傳函式名稱的起始 byte 位置（供高亮用）
local function render_line(node)
  local icon
  if node._loading then
    icon = ICONS.loading
  elseif node.children == nil then
    icon = ICONS.collapsed -- 尚未查詢
  elseif #node.children == 0 then
    icon = ICONS.leaf -- 葉節點（無呼叫者）
  elseif node.expanded then
    icon = ICONS.expanded
  else
    icon = ICONS.collapsed
  end

  local indent = string.rep(INDENT, node.depth)
  local location = node.file .. ":" .. node.lnum
  return indent .. icon .. node.name .. " (" .. location .. ")", #indent + #icon
end

--- 把樹狀結構攤平成顯示行
local function flatten_nodes(nodes)
  local flat = {}
  local function walk(node_list)
    for _, node in ipairs(node_list) do
      table.insert(flat, node)
      if node.expanded and node.children and #node.children > 0 then
        -- children 是 index，要轉成 node
        local child_nodes = {}
        for _, idx in ipairs(node.children) do
          if nodes[idx] then
            table.insert(child_nodes, nodes[idx])
          end
        end
        walk(child_nodes)
      end
    end
  end

  -- 只從 depth=0 的根節點開始
  local roots = {}
  for _, n in ipairs(nodes) do
    if n.depth == 0 then
      table.insert(roots, n)
    end
  end
  walk(roots)
  return flat
end

--- 重新渲染 buffer
local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local display = flatten_nodes(state.nodes)
  state.display = display

  local lines = {}
  local name_starts = {}
  for i, node in ipairs(display) do
    lines[i], name_starts[i] = render_line(node)
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  -- 高亮：byte 位置以該行實際 icon 長度計算
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for i, node in ipairs(display) do
    local name_end = name_starts[i] + #node.name
    vim.api.nvim_buf_set_extmark(state.buf, ns, i - 1, name_starts[i], {
      end_col = name_end,
      hl_group = "Function",
    })
    vim.api.nvim_buf_set_extmark(state.buf, ns, i - 1, name_end, {
      end_col = #lines[i],
      hl_group = "Comment",
    })
  end
end

--- render 後把游標留在原行（行數可能變少）
local function restore_cursor(row)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_cursor(state.win, { math.min(row, vim.api.nvim_buf_line_count(state.buf)), 0 })
  end
end

-- ── Buffer / Window 管理 ──────────────────────────────

--- 純視窗管理（重建面板時內部使用，不取消進行中的查詢）
local function close_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
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
  vim.bo[buf].filetype = "calltree"
  vim.bo[buf].modifiable = false

  state.buf = buf
  return buf
end

local function open_window()
  close_window()
  local buf = create_buffer()

  -- 左側分割視窗
  vim.cmd("topleft vertical " .. 50 .. "split")
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

  -- 設定標題
  local title = state.direction == "incoming" and "Incoming Calls" or "Outgoing Calls"
  vim.api.nvim_buf_set_name(buf, title .. ": " .. (state.root_name or ""))

  return win
end

-- ── Keymap 動作 ───────────────────────────────────────

--- 取得目前游標對應的 node
local function get_cursor_node()
  if not state.display or not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return nil, nil
  end
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.display[row], row
end

--- 展開/收合切換
local function toggle_node()
  local node, row = get_cursor_node()
  if not node then
    return
  end

  if node.expanded then
    -- 收合
    node.expanded = false
    render()
    restore_cursor(row)
    return
  end

  if node._fetched then
    -- 已查詢過，直接展開
    node.expanded = true
    render()
    restore_cursor(row)
    return
  end

  -- 尚未查詢：發出非同步請求（進行中則忽略重複觸發）
  if node._loading then
    return
  end
  if not client_alive() then
    vim.notify("LSP client 已斷線，請重新開啟 calltree", vim.log.levels.WARN)
    return
  end

  node._loading = true
  render()
  restore_cursor(row)

  fetch_children_async(node, state.generation, function(children)
    node._loading = false
    attach_children(node, children)
    node.expanded = true
    render()
    restore_cursor(row)
  end)
end

--- 遞迴展開全部（逐層 BFS 並發查詢，不阻塞編輯器）
local function expand_all()
  if state.expanding then
    return
  end
  if not client_alive() then
    vim.notify("LSP client 已斷線，請重新開啟 calltree", vim.log.levels.WARN)
    return
  end

  local gen = state.generation
  local seen = {}
  state.expanding = true
  vim.notify("遞迴展開中...", vim.log.levels.INFO)

  local function finish()
    state.expanding = false
    render()
    vim.notify("展開完成", vim.log.levels.INFO)
  end

  local function process_level(level, depth)
    if gen ~= state.generation then
      return -- 面板已重建/關閉，中止
    end
    if depth > MAX_DEPTH then
      return finish()
    end

    -- 濾掉已看過的節點（防循環參照）
    local work = {}
    for _, node in ipairs(level) do
      local key = node.uri .. ":" .. node.item.range.start.line
      if not seen[key] then
        seen[key] = true
        table.insert(work, node)
      end
    end
    if #work == 0 then
      return finish()
    end

    local pending = #work
    local next_level = {}

    local function on_node_done(node)
      node.expanded = true
      if node.children then
        for _, idx in ipairs(node.children) do
          if state.nodes[idx] then
            table.insert(next_level, state.nodes[idx])
          end
        end
      end
      pending = pending - 1
      if pending == 0 then
        render() -- 每完成一層渲染一次，呈現進度
        process_level(next_level, depth + 1)
      end
    end

    for _, node in ipairs(work) do
      if node._fetched then
        on_node_done(node)
      else
        fetch_children_async(node, gen, function(children)
          attach_children(node, children)
          on_node_done(node)
        end)
      end
    end
  end

  local roots = {}
  for _, n in ipairs(state.nodes) do
    if n.depth == 0 then
      table.insert(roots, n)
    end
  end
  process_level(roots, 0)
end

--- 全部收合
local function collapse_all()
  for _, node in ipairs(state.nodes) do
    node.expanded = false
  end
  render()
end

--- 跳轉到定義
local function goto_definition(close)
  local node = get_cursor_node()
  if not node then
    return
  end

  local fname = vim.uri_to_fname(node.uri)

  if close then
    close_panel()
  end

  -- 跳到目前主要編輯區
  local target_win = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= state.win then
      local buf = vim.api.nvim_win_get_buf(win)
      local bt = vim.bo[buf].buftype
      if bt == "" then
        target_win = win
        break
      end
    end
  end

  if target_win then
    vim.api.nvim_set_current_win(target_win)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(fname))
  vim.api.nvim_win_set_cursor(0, { node.lnum, node.col - 1 })
  vim.cmd("normal! zz")
end

--- 設定 buffer 內的 keymaps
local function setup_keymaps()
  local buf = state.buf
  local opts = { buffer = buf, nowait = true, silent = true }

  -- 展開/收合
  vim.keymap.set("n", "<CR>", toggle_node, vim.tbl_extend("force", opts, { desc = "展開/收合" }))
  vim.keymap.set("n", "o", toggle_node, vim.tbl_extend("force", opts, { desc = "展開/收合" }))
  vim.keymap.set("n", "l", toggle_node, vim.tbl_extend("force", opts, { desc = "展開/收合" }))
  vim.keymap.set("n", "h", function()
    local node = get_cursor_node()
    if node and node.expanded then
      node.expanded = false
      render()
    end
  end, vim.tbl_extend("force", opts, { desc = "收合" }))

  -- 展開全部 / 收合全部
  vim.keymap.set("n", "L", expand_all, vim.tbl_extend("force", opts, { desc = "遞迴展開全部" }))
  vim.keymap.set("n", "H", collapse_all, vim.tbl_extend("force", opts, { desc = "收合全部" }))

  -- 跳轉
  vim.keymap.set("n", "gd", function()
    goto_definition(false)
  end, vim.tbl_extend("force", opts, { desc = "跳轉到定義" }))
  vim.keymap.set("n", "gD", function()
    goto_definition(true)
  end, vim.tbl_extend("force", opts, { desc = "跳轉到定義並關閉" }))

  -- 關閉
  vim.keymap.set("n", "q", close_panel, vim.tbl_extend("force", opts, { desc = "關閉" }))
  vim.keymap.set("n", "<Esc>", close_panel, vim.tbl_extend("force", opts, { desc = "關閉" }))

  -- 幫助
  vim.keymap.set("n", "?", function()
    vim.notify(table.concat({
      "Calltree 快捷鍵:",
      "  <CR>/o/l  展開/收合節點",
      "  h         收合節點",
      "  L         遞迴展開全部",
      "  H         收合全部",
      "  gd        跳轉到定義",
      "  gD        跳轉到定義並關閉面板",
      "  q/<Esc>   關閉面板",
      "  ?         顯示此幫助",
    }, "\n"), vim.log.levels.INFO)
  end, vim.tbl_extend("force", opts, { desc = "幫助" }))
end

-- ── 公開 API ─────────────────────────────────────────

--- 啟動 incoming calls 階層樹
function M.incoming()
  M._run("incoming")
end

--- 啟動 outgoing calls 階層樹
function M.outgoing()
  M._run("outgoing")
end

function M._run(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local client = get_client(bufnr)
  if not client then
    vim.notify("沒有支援 Call Hierarchy 的 LSP client", vim.log.levels.ERROR)
    return
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

  vim.notify("準備 Call Hierarchy...", vim.log.levels.INFO)

  client:request("textDocument/prepareCallHierarchy", params, function(err, result)
    if err then
      vim.notify("prepareCallHierarchy 失敗: " .. tostring(err.message), vim.log.levels.ERROR)
      return
    end
    if not result or #result == 0 then
      vim.notify("游標位置無法建立 Call Hierarchy", vim.log.levels.WARN)
      return
    end

    vim.schedule(function()
      -- 舊面板的所有 in-flight 回應到此失效
      cancel_pending()
      local gen = state.generation

      state.direction = direction
      state.root_name = result[1].name
      state.source_bufnr = bufnr
      state.client = client
      state.nodes = {}
      state.display = {}

      -- 建立根節點，先開視窗再非同步載入第一層
      local root = make_node(result[1], 0, nil)
      table.insert(state.nodes, root)

      open_window()
      setup_keymaps()
      root._loading = true
      render()

      fetch_children_async(root, gen, function(children)
        root._loading = false
        attach_children(root, children)
        root.expanded = true
        render()

        local what = direction == "incoming" and "呼叫者" or "被呼叫的函式"
        if #children == 0 then
          vim.notify("沒有找到" .. what, vim.log.levels.INFO)
        else
          vim.notify(
            "找到 " .. #children .. " 個" .. what .. "，按 l/Enter 展開、L 遞迴展開全部",
            vim.log.levels.INFO
          )
        end
      end)
    end)
  end, bufnr)
end

return M
