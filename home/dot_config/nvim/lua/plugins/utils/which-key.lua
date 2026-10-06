---@type wk.Win.opts
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  cmd = "WhichKey",
  opts = require "configs.which-key",
  config = function(_, opts)
    require("which-key").setup(opts)
  end,
}
