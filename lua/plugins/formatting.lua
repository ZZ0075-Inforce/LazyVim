return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        json = { "prettier" },
        jsonc = { "prettier" },
        sql = { "sql_formatter" },
        plsql = { "sql_formatter" },
      },
    },
  },
}
