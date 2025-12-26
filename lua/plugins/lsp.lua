return {
  -- Mason for managing external tools
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "lua-language-server",
        "stylua",
      })
    end,
  },

  -- LSP Config
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = {
          -- mason = false, -- set to true if you don't want this server to be installed with mason
          -- Use this to add any default keymaps
          -- on_attach = function(client, buffer)
          -- end,
          settings = {
            Lua = {
              workspace = {
                checkThirdParty = false,
              },
              completion = {
                callSnippet = "Replace",
              },
            },
          },
        },
      },
    },
  },
}
