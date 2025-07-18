-- Smooth scrolling.
return {
  "karb94/neoscroll.nvim",
  lazy = "true",
  event = "VeryLazy",
  config = function()
    require("neoscroll").setup {}
  end,
}
