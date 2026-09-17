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
      -- 改 unicode 是為了少開一個子程序，不是為了好看。預設的 "ascii" 會在
      -- lib/git/log.lua:391 額外跑一次 `git log --graph --color` 來畫圖；
      -- "unicode" 則是拿同一次 M.list already 抓回來的 commit 在 Lua 裡算
      -- （lib/graph/unicode.lua），零額外 git 呼叫。
      --
      -- 這台機器建立程序本身就要 ~71 ms（實測 `git --version` 不碰任何 repo
      -- 也要 71 ms，而 `git -C <repo> rev-parse HEAD` 才 73 ms——真正的 git
      -- 工作只佔 2 ms），而 Repo:refresh 是併發跑 12 個模組、每個至少一個
      -- 子程序，所以省下的每一個 spawn 都是實的。
      --
      -- 用到的字元只有 box-drawing 加 • ┊，一般等寬字型都有，不需要 Nerd Font。
      graph_style = "unicode",
    },
  },
}
