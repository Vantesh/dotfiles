-- Keep the same structure as NvChad's nvconfig.lua.
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

-- Base46 prefers WallSync's generated theme; this handles fresh installations.
package.preload["themes.wallsync"] = function()
  return require "base46.themes.gruvchad"
end

M.base46 = {
  theme = "wallsync",
  transparency = true,
  hl_add = require "configs.snacks-highlights",
}

M.ui = {
  tabufline = {
    enabled = true,
    lazyload = true,
    order = { "treeOffset", "buffers", "tabs" },
  },
  telescope = { style = "bordered" },
}

return M
