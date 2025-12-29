return {
  "snacks.nvim",
  opts = function(_, opts)
    -- terminal不支援圖片顯示，關閉圖片功能, 修正 checkhealth 報錯：覆寫 image 模組的 health 檢查
    vim.schedule(function()
      if _G.Snacks then
        _G.Snacks.image.health = function()
          Snacks.health.warn("Image module is disabled (suppressed checks)")
        end
      end
    end)

    -- 初始化 dashboard 配置
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}

    -- [顏色配置區塊]
    local colors = {
      header = "SnacksDashboardHeader",
      lunar = "Special", -- 農曆顏色
      news_odd = "DiagnosticInfo", -- 新聞奇數行
      news_even = "DiagnosticOk", -- 新聞偶數行
      keys = "SnacksDashboardKey",
    }

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

    -- 自動換行處理函數 (回傳行列表)
    local function wrap_text_to_lines(text, maxw)
      local lines = {}
      for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
        local cur = ""
        for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
          local next_str = cur .. ch
          if cur ~= "" and vim.fn.strdisplaywidth(next_str) > maxw then
            table.insert(lines, cur)
            cur = ch
          else
            cur = next_str
          end
        end
        table.insert(lines, cur)
      end
      return lines
    end

    -- 計算最大顯示寬度
    local maxw = opts.dashboard.width or 60
    maxw = math.min(maxw, math.max(20, math.floor((vim.o.columns - (opts.dashboard.pane_gap or 4)) / 2)))

    -- 1. 處理農曆內容 (執行指令取得文字)
    local lunar_content = vim.fn.system("ggGetLunar")
    local lunar_lines = wrap_text_to_lines(lunar_content, maxw)
    local formatted_lunar = {}
    for _, line in ipairs(lunar_lines) do
      table.insert(formatted_lunar, { line .. "\n", hl = colors.lunar })
    end

    -- 2. 處理新聞內容 (交叉換色)
    local news_file = [[C:\Users\ZZ0075\.cache\todayNews.txt]]
    local news_text = read_text_file(news_file) or ""
    local formatted_news = {}
    if news_text ~= "" then
      local raw_lines = wrap_text_to_lines(news_text, maxw)
      for i, line in ipairs(raw_lines) do
        if line ~= "" then
          local hl_group = (i % 2 == 0) and colors.news_even or colors.news_odd
          table.insert(formatted_news, { line .. "\n", hl = hl_group })
        else
          table.insert(formatted_news, { "\n" })
        end
      end
    end

    -- 設定 Dashboard 區塊結構
    opts.dashboard.sections = {
      { text = formatted_lunar, padding = 1, align = "left" },
      { section = "header", align = "left", hl = colors.header },
      { section = "keys", gap = 1, padding = 1, hl = colors.keys },
      { section = "startup" },
    }

    -- 插入新聞面板
    if #formatted_news > 0 then
      table.insert(opts.dashboard.sections, 2, {
        pane = 2,
        padding = 2,
        align = "left",
        text = formatted_news,
      })
    end

    opts.dashboard.preset.header = ""
  end,
}
