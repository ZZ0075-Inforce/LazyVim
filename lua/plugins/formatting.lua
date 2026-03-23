return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        -- The Mason batch wrapper is unreliable with vim.system stdin on Windows.
        xmlformatter = {
          command = function()
            return vim.fs.joinpath(
              vim.fn.stdpath("data"),
              "mason",
              "packages",
              "xmlformatter",
              "venv",
              "Scripts",
              "xmlformat.exe"
            )
          end,
          args = { "--overwrite", "$FILENAME" },
          stdin = false,
        },
      },
      formatters_by_ft = {
        json = { "prettier" },
        jsonc = { "prettier" },
        sql = { "sql_formatter" },
        plsql = { "sql_formatter" },
        xml = { "xmlformatter", lsp_format = "fallback" },
      },
    },
  },
}
