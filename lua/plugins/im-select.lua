return {
  {
    "keaising/im-select.nvim",
    config = function()
      -- 取得當前設定檔目錄路徑 (即 C:\Users\ZZ0075\AppData\Local\nvim)
      -- 並串接出 exe 的完整路徑
      local im_select_path = vim.fn.stdpath("config") .. "/lua/plugins/im-select.exe"

      require("im_select").setup({
        -- Windows default settings
        default_im_select = "1033",
        -- 指定絕對路徑
        default_command = im_select_path,
        -- Async switch to improve performance
        async_switch_im = true,
      })
    end,
  },
}