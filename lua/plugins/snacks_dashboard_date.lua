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

    -- 自動換行處理函數 (回傳行列表；續行沿用行首縮排，區塊式內容縮兩格用)
    local function wrap_text_to_lines(text, maxw)
      local lines = {}
      for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
        local indent = line:match("^%s*")
        local cur = ""
        for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
          local next_str = cur .. ch
          if cur ~= "" and vim.fn.strdisplaywidth(next_str) > maxw then
            table.insert(lines, cur)
            cur = indent .. ch
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

    -- 1. 處理農曆內容 (非同步執行指令，完成後刷新 dashboard，不阻塞啟動)
    -- 經 cmd.exe 執行讓 AutoRun 先 chcp 65001，輸出才是 UTF-8（與原 vim.fn.system 行為一致）
    local formatted_lunar = { { "\n", hl = colors.lunar } }
    vim.system(
      { "cmd.exe", "/s", "/c", "ggGetLunar" },
      { text = true },
      vim.schedule_wrap(function(out)
        local lunar_content = out.stdout or ""
        if lunar_content == "" then
          -- 失敗時顯示提示，避免面板無聲消失不易察覺
          lunar_content = "農曆載入失敗 (ggGetLunar exit " .. tostring(out.code) .. ")"
        end
        -- 原地改寫 formatted_lunar（sections 持有同一個 table 參照）
        for i = #formatted_lunar, 1, -1 do
          table.remove(formatted_lunar, i)
        end
        for _, line in ipairs(wrap_text_to_lines(lunar_content, maxw)) do
          table.insert(formatted_lunar, { line .. "\n", hl = colors.lunar })
        end
        if _G.Snacks and Snacks.dashboard then
          pcall(Snacks.dashboard.update)
        end
      end)
    )

    -- 2. 處理新聞內容 (交叉換色)
    -- 注意：此檔由外部排程工具產生於 ~/.cache，不可改成 stdpath("cache")（那是 %TEMP%\nvim）
    local news_file = vim.fs.joinpath(vim.uv.os_homedir(), ".cache", "todayNews.txt")
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
    -- 農曆用函式型 section：每次 update 都會重新 resolve，才讀得到非同步補上的內容
    -- （靜態 table 會在 snacks 的 config 管線被複製，事後原地修改傳不進 dashboard）
    opts.dashboard.sections = {
      function()
        return { text = formatted_lunar, padding = 1, align = "left" }
      end,
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
