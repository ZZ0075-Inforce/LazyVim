return {
  {
    "sindrets/diffview.nvim",
    -- 平常用不到就不載：開 neogit（dependency 連動）或下 Diffview 指令時才載入
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    opts = {
      keymaps = {
        -- diff 兩窗格內
        -- 註：]c/[c 不需覆蓋——LazyVim 的 treesitter-textobjects 在 diff 視窗
        -- 已自動 fallback 原生「跳差異」（lazyvim/plugins/treesitter.lua 的 vim.wo.diff guard）
        view = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "關閉 diffview（整組收掉）" } },
        },
        -- 左側檔案清單面板
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "關閉 diffview（整組收掉）" } },
        },
      },
    },
  },
}
