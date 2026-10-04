return {
  -- Use the reference config's native Neovim parser manager, not two TS installers.
  { "nvim-treesitter/nvim-treesitter", enabled = false },
  {
    "romus204/tree-sitter-manager.nvim",
    lazy = false,
    -- Requires Neovim 0.12+, tree-sitter CLI, git, and a C compiler.
    config = function()
      require("tree-sitter-manager").setup()
    end,
  },
}
