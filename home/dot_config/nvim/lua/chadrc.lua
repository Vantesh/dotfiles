-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

local theme = "matugen"
local theme_path = vim.fn.stdpath("data") .. "/lazy/base46/lua/base46/themes/" .. theme .. ".lua"

if vim.fn.filereadable(theme_path) ~= 1 then
	os.execute("waypaper --restore >/dev/null 2>&1")
end

M.base46 = {
	theme = theme,
	transparency = true,                       -- set to false if you want a solid background
	theme_toggle = { "matugen", "catppuccin" }, -- themes to toggle between

}

-- M.nvdash = { load_on_startup = true }
M.ui = {

	tabufline = {
		enabled = true,
		lazyload = true,
		order = { "treeOffset", "buffers", "tabs", "btns" },
		modules = nil,
	},

	cmp = {
		icons_left = false, -- only for non-atom styles!
		style = "default", -- default/flat_light/flat_dark/atom/atom_colored
		abbr_maxwidth = 60,
		-- for tailwind, css lsp etc
		format_colors = { lsp = true, icon = "󱓻" },
	},

	telescope = { style = "bordered" },

	term = {
		base46_colors = true,
		winopts = { number = false, relativenumber = false },
		sizes = { sp = 0.3, vsp = 0.2, ["bo sp"] = 0.3, ["bo vsp"] = 0.2 },
		float = {
			relative = "editor",
			row = 0.3,
			col = 0.25,
			width = 0.5,
			height = 0.4,
			border = "single",
		},
	},



}

return M
