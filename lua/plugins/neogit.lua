return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim", -- 沒裝的話 Diff Popup (按 d) 幾乎所有選項都會被隱藏，按了跟沒反應一樣
    },
    cmd = "Neogit",
    keys = {
      -- <leader>gg/<leader>gG 已被 LazyVim 預設綁定給 Lazygit，這裡改用 <leader>gn 避免衝突
      { "<leader>gn", "<cmd>Neogit<cr>", desc = "Neogit" },
    },
    opts = {
      integrations = {
        diffview = true, -- 用 diffview 開兩窗格 diff：進 diff mode（]c/[c 可跳）、獨立 tab、一鍵 q 關閉
      },
    },
  },
}
