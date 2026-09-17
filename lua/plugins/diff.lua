-- diff 忽略空白的開關
--
-- 預設值設在 lua/config/options.lua（vim.opt.diffopt:append("iwhite")），
-- 這裡只提供執行期切換。
--
-- 掛在 gitsigns 上有兩個理由：
-- 1. Snacks.toggle 需要 Snacks 已經 setup；gitsigns 走 LazyFile 載入，那時一定就緒
--    （LazyVim 自己的 <leader>uG 也是用同一個模式掛在這裡）。
-- 2. gitsigns 的 diff_opts 是從 diffopt 推導的，切換時要順手叫它重算。
return {
  {
    "lewis6991/gitsigns.nvim",
    -- opts 為 function 且不回傳值時，lazy.nvim 會保留原本的 opts，這裡純粹借位註冊 keymap
    opts = function()
      Snacks.toggle({
        name = "Diff 忽略空白",
        get = function()
          return vim.tbl_contains(vim.opt.diffopt:get(), "iwhite")
        end,
        set = function(state)
          if state then
            vim.opt.diffopt:append("iwhite")
          else
            vim.opt.diffopt:remove("iwhite")
          end
          -- gitsigns 的 diff_opts 只在 setup 當下由 parse_diffopt 從 diffopt 求值一次就固化，
          -- 之後改 diffopt 不會跟隨（它註冊的 OptionSet autocmd 實測不觸發），
          -- 而 refresh() 只重算 hunk、不重讀 config。所以這裡直接改它的 config 再 refresh。
          -- 註：該欄位型別是 `ignore_whitespace_change? true`，關閉要寫 nil 而非 false。
          -- 欄位名要跟 diffopt 的旗標對得起來：gitsigns/config.lua:146-153 的 optmap 是
          -- iwhite → ignore_whitespace_change、iwhiteall → ignore_whitespace，別搞混。
          pcall(function()
            local gs_config = require("gitsigns.config").config
            if gs_config and gs_config.diff_opts then
              gs_config.diff_opts.ignore_whitespace_change = state or nil
            end
            require("gitsigns").refresh()
          end)
        end,
      }):map("<leader>uW")
    end,
  },
}
