return {
  "snacks.nvim",
  opts = function(_, opts)
    -- 初始化 dashboard 配置
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}

    -- 讀取文字檔案內容
    -- @param path: 檔案的絕對路徑
    -- @return: 檔案內容 (字串) 或 nil
    local function read_text_file(path)
      local uv = vim.uv or vim.loop
      local stat = uv.fs_stat(path)
      if not stat or stat.type ~= "file" then
        return nil
      end
      local ok, lines = pcall(vim.fn.readfile, path)
      if not ok then
        return nil
      end
      return table.concat(lines, "\n")
    end

    -- 自動換行處理函數
    -- @param text: 原始文字
    -- @param maxw: 最大寬度
    -- @return: 處理後的文字 (已加入換行符)
    local function wrap_text(text, maxw)
      local out = {}
      for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
        local cur = ""
        for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
          local next = cur .. ch
          -- 如果加入下一個字元會超過最大寬度，則換行
          if cur ~= "" and vim.fn.strdisplaywidth(next) > maxw then
            table.insert(out, cur)
            cur = ch
          else
            cur = next
          end
        end
        table.insert(out, cur)
      end
      return table.concat(out, "\n")
    end

    -- 計算最大顯示寬度
    -- logic: 取螢幕寬度減去間隙後的一半，但不小於 20，也不超過預設寬度
    local maxw = opts.dashboard.width or 60
    maxw = math.min(maxw, math.max(20, math.floor((vim.o.columns - (opts.dashboard.pane_gap or 4)) / 2)))

    -- 設定農曆日期 (讀取快取檔案)
    local lunar_file = [[C:\\Users\\ZZ0075\\.cache\\todayLunar.txt]]
    local lunar_text = read_text_file(lunar_file) or ""
    -- 對農曆文字進行換行處理
    opts.dashboard.preset.header = wrap_text(lunar_text, maxw)

    -- 設定右側新聞內容 (讀取快取檔案)
    local news_file = [[C:\\Users\\ZZ0075\\.cache\\todayNews.txt]]
    local news_text = read_text_file(news_file) or ""
    -- 如果有新聞內容，則在後方加入換行；否則為空
    local right_text = news_text ~= "" and (news_text .. "\n\n") or ""
    -- 對新聞內容進行換行處理
    right_text = wrap_text(right_text, maxw)

    -- 設定 Dashboard 區塊配置
    opts.dashboard.sections = opts.dashboard.sections
      or {
        { section = "header", align = "left" }, -- 標題區塊設為向左對齊
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      }

    -- 將新聞內容插入到第二個區塊 (右側面板)
    table.insert(opts.dashboard.sections, 2, {
      pane = 2,
      padding = 2,
      align = "left", -- 強制向左對齊
      text = right_text,
    })
  end,
}
