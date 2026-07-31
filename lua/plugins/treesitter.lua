return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.treesitter.language.register("html", "jsp")
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "lua", "javascript", "vim", "gitcommit", "json", "bash", "html" })
      end
      -- 註:編譯器強制走 gcc 由 options.lua 的 vim.env.CC 處理
      -- (main 分支以 tree-sitter CLI 編譯,舊的 install.compilers/prefer_git 欄位已不存在)
    end,
  },
}
