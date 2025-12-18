return {
  "snacks.nvim",
  opts = function(_, opts)
    -- 初始化 dashboard 配置
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}

    -- 讀取文字檔案內容
    local function read_text_file(path)
      local f = io.open(path, "r")
      if not f then
        return nil
      end
      local content = f:read("*a")
      f:close()
      return content
    end

    -- 自動換行處理函數 (支援中文字元寬度)
    local function wrap_text(text, maxw)
      local out = {}
      for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
        local cur = ""
        for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
          local next_str = cur .. ch
          if cur ~= "" and vim.fn.strdisplaywidth(next_str) > maxw then
            table.insert(out, cur)
            cur = ch
          else
            cur = next_str
          end
        end
        table.insert(out, cur)
      end
      return table.concat(out, "\n")
    end

    -- 計算最大顯示寬度
    local maxw = opts.dashboard.width or 60
    maxw = math.min(maxw, math.max(20, math.floor((vim.o.columns - (opts.dashboard.pane_gap or 4)) / 2)))

    -- 設定圖片或文字 Header
    local image_path = [[C:\Users\ZZ0075\Pictures\87.gif]]
    local use_image = false
    local chafa_cmd -- 預先聲明，避免型別衝突

    -- 檢查 chafa 是否可用
    if vim.fn.executable("chafa") == 1 then
      chafa_cmd = "chafa"
    else
      local win_chafa = [[C:\Users\ZZ0075\AppData\Local\Microsoft\WinGet\Links\chafa.exe]]
      if vim.uv.fs_stat(win_chafa) then
        chafa_cmd = win_chafa
      end
    end

    -- if chafa_cmd and vim.uv.fs_stat(image_path) then
    --   use_image = true
    -- end

    if use_image then
      -- 使用圖片作為 Header
      local cmd = string.format('"%s" "%s" --format=symbols --size=%dx20', chafa_cmd, image_path, math.floor(maxw))
      opts.dashboard.sections = {
        { section = "terminal", cmd = cmd, height = 20, padding = 1, align = "left" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      }
    else
      -- 使用農曆文字作為 Header
      -- local lunar_file = [[C:\Users\ZZ0075\.cache\todayLunar.txt]]
      -- local lunar_text = read_text_file(lunar_file) or ""
      -- opts.dashboard.preset.header = wrap_text(lunar_text, maxw)
      opts.dashboard.preset.header = ""
      opts.dashboard.sections = {
        { section = "terminal", cmd = "ggGetLunar", height = 20, padding = 0, align = "left" },
        { section = "header", align = "left" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      }
    end

    -- 設定右側新聞內容
    local news_file = [[C:\Users\ZZ0075\.cache\todayNews.txt]]
    local news_text = read_text_file(news_file) or ""
    local right_text = news_text ~= "" and (news_text .. "\n\n") or ""
    right_text = wrap_text(right_text, maxw)

    -- 將新聞內容插入到第二個區塊 (右側面板)
    table.insert(opts.dashboard.sections, 2, {
      pane = 2,
      padding = 2,
      align = "left",
      text = right_text,
    })
  end,
}
