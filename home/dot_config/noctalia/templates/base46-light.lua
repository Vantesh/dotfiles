local M = {}

local lighten = require("base46.colors").change_hex_lightness

M.base_30 = {
  white = "{{colors.on_background.light.hex}}",
  black = "{{colors.background.light.hex}}",
  darker_black = lighten("{{colors.background.light.hex}}", -3),
  black2 = lighten("{{colors.background.light.hex}}", 6),
  one_bg = lighten("{{colors.background.light.hex}}", 10),
  one_bg2 = lighten("{{colors.background.light.hex}}", 16),
  one_bg3 = lighten("{{colors.background.light.hex}}", 22),
  grey = "{{colors.surface_variant.light.hex}}",
  grey_fg = lighten("{{colors.surface_variant.light.hex}}", -10),
  grey_fg2 = lighten("{{colors.surface_variant.light.hex}}", -20),
  light_grey = "{{colors.outline.light.hex}}",
  red = "{{colors.terminal_normal_red.light.hex}}",
  baby_pink = lighten("{{colors.terminal_normal_red.light.hex}}", 10),
  pink = "{{colors.tertiary.light.hex}}",
  line = "{{colors.outline.light.hex}}",
  green = "{{colors.terminal_normal_green.light.hex}}",
  vibrant_green = lighten("{{colors.terminal_normal_green.light.hex}}", 10),
  blue = "{{colors.terminal_normal_blue.light.hex}}",
  nord_blue = lighten("{{colors.terminal_normal_blue.light.hex}}", 10),
  yellow = "{{colors.terminal_normal_yellow.light.hex}}",
  sun = lighten("{{colors.terminal_normal_yellow.light.hex}}", 10),
  purple = "{{colors.tertiary.light.hex}}",
  dark_purple = lighten("{{colors.tertiary.light.hex}}", -10),
  teal = "{{colors.secondary_container.light.hex}}",
  orange = "{{colors.terminal_normal_red.light.hex}}",
  cyan = "{{colors.terminal_normal_cyan.light.hex}}",
  statusline_bg = lighten("{{colors.background.light.hex}}", 6),
  pmenu_bg = "{{colors.surface_variant.light.hex}}",
  folder_bg = lighten("{{colors.primary_fixed_dim.light.hex}}", 0),
  lightbg = lighten("{{colors.background.light.hex}}", 10),
}

M.base_16 = {
  base00 = "{{colors.surface.light.hex}}",
  base01 = lighten("{{colors.surface_variant.light.hex}}", 0),
  base02 = lighten("{{colors.surface_variant.light.hex}}", 3),
  base03 = lighten("{{colors.outline.light.hex}}", 0),
  base04 = lighten("{{colors.on_surface_variant.light.hex}}", 0),
  base05 = "{{colors.on_surface.light.hex}}",
  base06 = lighten("{{colors.on_surface.light.hex}}", 0),
  base07 = "{{colors.surface.light.hex}}",
  base08 = "{{colors.terminal_normal_red.light.hex}}",
  base09 = "{{colors.terminal_normal_yellow.light.hex}}",
  base0A = "{{colors.terminal_normal_blue.light.hex}}",
  base0B = "{{colors.terminal_normal_green.light.hex}}",
  base0C = "{{colors.terminal_normal_cyan.light.hex}}",
  base0D = lighten("{{colors.terminal_normal_blue.light.hex}}", 20),
  base0E = "{{colors.tertiary.light.hex}}",
  base0F = "{{colors.inverse_surface.light.hex}}",
}

M.type = "light"

M.polish_hl = {
  defaults = {
    Comment = {
      italic = true,
      fg = M.base_16.base03,
    },
  },
  Syntax = {
    String = {
      fg = "{{colors.tertiary.light.hex}}",
    },
  },
  treesitter = {
    ["@comment"] = {
      fg = M.base_16.base03,
    },
    ["@string"] = {
      fg = "{{colors.tertiary.light.hex}}",
    },
  },
}

return M
