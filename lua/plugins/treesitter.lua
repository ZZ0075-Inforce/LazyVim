return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "lua", "javascript", "vim", "gitcommit", "json", "bash" })
      end
      -- Force use of gcc since clang/cl are missing
      require("nvim-treesitter.install").compilers = { "gcc" }
      require("nvim-treesitter.install").prefer_git = true
    end,
  },
}
