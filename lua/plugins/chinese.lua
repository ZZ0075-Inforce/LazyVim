return {
  {
    "ZZ0075-Inforce/lazyvim.chinese.zh-tw",
    dependencies = { "folke/which-key.nvim" },
    config = function()
      require("lazyvim_chinese").setup()

      -- which-key group 定義
      local wk = require("which-key")
      wk.add({
        { "ga", group = "Call Hierarchy" }, -- 定義有意義的名稱
      })
    end,
  },
}
