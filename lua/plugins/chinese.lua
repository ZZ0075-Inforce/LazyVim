return {
  {
    "ZZ0075-Inforce/lazyvim.chinese.zh-tw",
    -- 翻譯機制在 VeryLazy 掃描 keymap 改寫 desc，太早載入會掃不到東西
    event = "VeryLazy",
    dependencies = { "folke/which-key.nvim" },
    config = function()
      require("lazyvim_chinese").setup()
    end,
  },
}
