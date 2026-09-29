-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(


---@type ChadrcConfig
local M = {}

M.ui = {
  tabufline = {
    enabled = true,
    lazyload = true,
    order = { "treeOffset", "buffers", "tabs", "btns" },

    modules = {
      btns = function()
        local btn = require("nvchad.tabufline.utils").btn
        return btn(" 󰅖 ", "CloseAllBufsBtn", "CloseAllBufs")
      end,
    },
  },

  telescope = { style = "bordered" },




}


return M
