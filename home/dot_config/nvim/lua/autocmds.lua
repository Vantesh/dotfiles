-- The dashboard is UI content, not a buffer that needs a Tree-sitter parser.
local treesitter_start = vim.treesitter.start
vim.treesitter.start = function(buf, language)
  buf = buf or 0
  if vim.bo[buf].filetype == "snacks_dashboard" then
    return
  end
  return treesitter_start(buf, language)
end

require "nvchad.autocmds"
