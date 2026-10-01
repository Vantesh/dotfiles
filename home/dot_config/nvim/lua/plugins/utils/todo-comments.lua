return {
  "folke/todo-comments.nvim",
  lazy = true,

  ft = {
    "lua",
    "html",
    "javascript",
    "typescript",
    "javascriptreact",
    "typescriptreact",
    "tsx",
    "jsx",
  },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = require "configs.todo-comments",
}
