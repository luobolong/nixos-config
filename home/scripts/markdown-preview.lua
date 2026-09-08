return {
  "iamcco/markdown-preview.nvim",
  build = "cd app && npm install",
  cmd = {
    "MarkdownPreview",
    "MarkdownPreviewStop",
    "MarkdownPreviewToggle",
  },
  ft = { "markdown" },
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
  end,
  keys = {
    {
      "<leader>mp",
      "<cmd>MarkdownPreviewToggle<cr>",
      desc = "Markdown Preview",
      ft = "markdown",
    },
  },
}
