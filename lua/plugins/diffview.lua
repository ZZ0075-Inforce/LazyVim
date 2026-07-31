return {
  {
    "sindrets/diffview.nvim",
    opts = {
      keymaps = {
        -- diff 兩窗格內
        view = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "關閉 diffview（整組收掉）" } },
          -- 蓋回 Vim 原生 diff motion，避免被其他 plugin 全域搶走
          { "n", "]c", "]c", { desc = "下一個差異", noremap = true } },
          { "n", "[c", "[c", { desc = "上一個差異", noremap = true } },
        },
        -- 左側檔案清單面板
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "關閉 diffview（整組收掉）" } },
        },
      },
    },
  },
}
