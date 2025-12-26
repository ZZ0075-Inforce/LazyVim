return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      file_types = { "markdown", "Avante", "codecompanion" },
    },
    ft = { "markdown", "codecompanion" },
    keys = {
      { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle Render Markdown" },
    },
  },
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_browserfunc = "OpenMarkdownPreview"
      vim.cmd([[
function! OpenMarkdownPreview(url) abort
  " /d disables AutoRun (prevents clink/chcp from running)
  call jobstart(['cmd.exe', '/d', '/c', 'start', '""', a:url], { 'detach': v:true })
endfunction
      ]])
    end,
    keys = {
      { "<leader>uP", "<cmd>MarkdownPreviewToggle<cr>", desc = "Toggle Markdown Preview" },
    },
  },
}
