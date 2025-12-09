return {
  {
    "ZZ0075-Inforce/lazyvim.chinese.zh-tw",
    dependencies = { "folke/which-key.nvim" },
    config = function()
      require("lazyvim_chinese").setup()
    end,
  },
}
