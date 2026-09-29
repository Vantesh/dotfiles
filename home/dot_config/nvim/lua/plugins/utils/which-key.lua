---@type wk.Win.opts
return {
  "folke/which-key.nvim",
  keys = { "<leader>", "<c-r>", "<c-w>", '"', "'", "`", "c", "v", "g" },
  cmd = "WhichKey",
  opts = require "configs.which-key",
  config = function(_, opts)
    require("which-key").setup(opts)
  end,
}
