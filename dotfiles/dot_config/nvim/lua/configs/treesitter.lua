local options = {
  ensure_installed = {
    "bash",
    "css",
    "html",
    "hyprlang",
    "javascript",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "python",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
  },

  highlight = {
    enable = true,
    use_languagetree = true,
  },

  indent = { enable = true },
}

require("nvim-treesitter.configs").setup(options)
