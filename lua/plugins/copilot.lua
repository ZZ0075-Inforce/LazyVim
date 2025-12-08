return {
  {
    "github/copilot.vim",
    config = function()
      -- Copilot filetypes
      vim.g.copilot_filetypes = {
        ["*"] = true,
        ["gitcommit"] = true,
        ["markdown"] = true,
        ["yaml"] = true,
      }

      -- Keymaps
      vim.g.copilot_no_tab_map = true
      vim.keymap.set("i", "<C-l>", 'copilot#Accept("\\<CR>")', { expr = true, replace_keycodes = false })

      -- Autocmds for gitcommit
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "gitcommit",
        callback = function()
          vim.cmd("Copilot enable")
          vim.keymap.set("n", "<leader>ce", ":Copilot enable<CR>", { buffer = true })
        end,
      })
    end,
  },
}
