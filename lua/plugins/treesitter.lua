return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.treesitter.language.register("html", "jsp")
      if type(opts.ensure_installed) == "table" then
        -- 只列 LazyVim 預設清單沒有的 parser（lua/javascript/vim/json/bash/html 預設已含）
        vim.list_extend(opts.ensure_installed, { "gitcommit" })
      end
      -- 註:編譯器強制走 gcc 由 options.lua 的 vim.env.CC 處理
      -- (main 分支以 tree-sitter CLI 編譯,舊的 install.compilers/prefer_git 欄位已不存在)
    end,
  },
}
