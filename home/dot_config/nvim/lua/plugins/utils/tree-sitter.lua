return {

  {
    "romus204/tree-sitter-manager.nvim",
    lazy = false,
    dependencies = {}, -- tree-sitter CLI must be installed system-wide
    config = function()
      require("tree-sitter-manager").setup()
    end,
  }
}
