local M = {}

local lighten = require("base46.colors").change_hex_lightness

M.base_30 = {
  white = "{{colors.on_background.dark.hex}}",
  black = "{{colors.background.dark.hex}}",
  darker_black = lighten("{{colors.background.dark.hex}}", -3),
  black2 = lighten("{{colors.background.dark.hex}}", 6),
  one_bg = lighten("{{colors.background.dark.hex}}", 10),
  one_bg2 = lighten("{{colors.background.dark.hex}}", 16),
  one_bg3 = lighten("{{colors.background.dark.hex}}", 22),
  grey = "{{colors.surface_variant.dark.hex}}",
  grey_fg = lighten("{{colors.surface_variant.dark.hex}}", -10),
  grey_fg2 = lighten("{{colors.surface_variant.dark.hex}}", -20),
  light_grey = "{{colors.outline.dark.hex}}",
  red = "{{colors.terminal_normal_red.dark.hex}}",
  baby_pink = lighten("{{colors.terminal_normal_red.dark.hex}}", 10),
  pink = "{{colors.tertiary.dark.hex}}",
  line = "{{colors.outline.dark.hex}}",
  green = "{{colors.terminal_normal_green.dark.hex}}",
  vibrant_green = lighten("{{colors.terminal_normal_green.dark.hex}}", 10),
  blue = "{{colors.terminal_normal_blue.dark.hex}}",
  nord_blue = lighten("{{colors.terminal_normal_blue.dark.hex}}", 10),
  yellow = "{{colors.terminal_normal_yellow.dark.hex}}",
  sun = lighten("{{colors.terminal_normal_yellow.dark.hex}}", 10),
  purple = "{{colors.tertiary.dark.hex}}",
  dark_purple = lighten("{{colors.tertiary.dark.hex}}", -10),
  teal = "{{colors.secondary_container.dark.hex}}",
  orange = "{{colors.terminal_normal_red.dark.hex}}",
  cyan = "{{colors.terminal_normal_cyan.dark.hex}}",
  statusline_bg = lighten("{{colors.background.dark.hex}}", 6),
  pmenu_bg = "{{colors.surface_variant.dark.hex}}",
  folder_bg = lighten("{{colors.primary_fixed_dim.dark.hex}}", 0),
  lightbg = lighten("{{colors.background.dark.hex}}", 10),
}

M.base_16 = {
  base00 = "{{colors.surface.dark.hex}}",
  base01 = lighten("{{colors.surface_variant.dark.hex}}", 0),
  base02 = lighten("{{colors.surface_variant.dark.hex}}", 3),
  base03 = lighten("{{colors.outline.dark.hex}}", 0),
  base04 = lighten("{{colors.on_surface_variant.dark.hex}}", 0),
  base05 = "{{colors.on_surface.dark.hex}}",
  base06 = lighten("{{colors.on_surface.dark.hex}}", 0),
  base07 = "{{colors.surface.dark.hex}}",
  base08 = "{{colors.terminal_normal_red.dark.hex}}",
  base09 = "{{colors.terminal_normal_yellow.dark.hex}}",
  base0A = "{{colors.terminal_normal_blue.dark.hex}}",
  base0B = "{{colors.terminal_normal_green.dark.hex}}",
  base0C = "{{colors.terminal_normal_cyan.dark.hex}}",
  base0D = lighten("{{colors.terminal_normal_blue.dark.hex}}", 20),
  base0E = "{{colors.tertiary.dark.hex}}",
  base0F = "{{colors.inverse_surface.dark.hex}}",
}

M.type = "dark"

M.polish_hl = {
  defaults = {
    Comment = {
      italic = true,
      fg = M.base_16.base03,
    },
  },
  Syntax = {
    String = {
      fg = "{{colors.tertiary.dark.hex}}",
    },
  },
  treesitter = {
    ["@comment"] = {
      fg = M.base_16.base03,
    },
    ["@string"] = {
      fg = "{{colors.tertiary.dark.hex}}",
    },
  },
}

return M
