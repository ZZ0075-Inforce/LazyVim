-- diffview 開檔案面板時會補一次 wincmd = 重新平均窗格（scene/views/diff/file_panel.lua:70），
-- 但關的時候沒有（ui/panel.lua:304 的 Panel:close 只呼叫 nvim_win_close），於是 <leader>b
-- 收合面板後釋出的寬度不會平均分回 OURS/THEIRS，只有一側吃到。這裡在 toggle 後自己補一次。
local function toggle_files_equalized()
  require("diffview.actions").toggle_files()
  vim.cmd("wincmd =")
end

return {
  {
    "sindrets/diffview.nvim",
    -- 平常用不到就不載：開 neogit（dependency 連動）或下 Diffview 指令時才載入
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    opts = {
      view = {
        -- 解衝突的視窗排法。預設 diff3_horizontal 是「OURS │ 結果檔 │ THEIRS」三窗並排，太擠；
        -- 改 diff3_mixed 成上排 OURS │ THEIRS、下方結果檔（= TortoiseGitMerge 的版面）。
        -- 註：可寫的永遠只有「結果檔」那一窗（工作區檔案），OURS/THEIRS/BASE 都是唯讀。
        -- 臨時想看 BASE（共同祖先）時，在視窗內按 g<C-x> 循環切到 diff4_mixed 即可，不必改設定。
        merge_tool = {
          layout = "diff3_mixed",
        },
      },
      keymaps = {
        -- diff 兩窗格內
        -- 註：]c/[c 不需覆蓋——LazyVim 的 treesitter-textobjects 在 diff 視窗
        -- 已自動 fallback 原生「跳差異」（lazyvim/plugins/treesitter.lua 的 vim.wo.diff guard）
        view = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "關閉 diffview（整組收掉）" } },
          { "n", "<leader>b", toggle_files_equalized, { desc = "切換檔案面板（收合後平均窗格寬度）" } },
        },
        -- 左側檔案清單面板
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "關閉 diffview（整組收掉）" } },
          { "n", "<leader>b", toggle_files_equalized, { desc = "切換檔案面板（收合後平均窗格寬度）" } },
        },
      },
    },
  },
}
