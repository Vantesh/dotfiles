local M = {}

local base46_colors = require("base46.colors")
local lighten = base46_colors.change_hex_lightness

local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")

  if #hex == 3 then
    hex = hex:gsub(".", "%0%0")
  end

  local r = tonumber(hex:sub(1, 2), 16) or 0
  local g = tonumber(hex:sub(3, 4), 16) or 0
  local b = tonumber(hex:sub(5, 6), 16) or 0

  return r, g, b
end

local function is_light_hex(hex)
  local r, g, b = hex_to_rgb(hex)
  -- Rec. 601 luma approximation
  local luma = 0.299 * r + 0.587 * g + 0.114 * b

  return luma >= 165
end

local background_hex = "{{colors.background.default.hex}}"
local surface_variant_hex = "{{colors.surface_variant.default.hex}}"
local outline_hex = "{{colors.outline.default.hex}}"
local error_hex = "{{colors.error.default.hex}}"
local tertiary_hex = "{{colors.tertiary.default.hex}}"
local secondary_hex = "{{colors.secondary.default.hex}}"
local primary_hex = "{{colors.primary.default.hex}}"
local primary_container_hex = "{{colors.primary_container.default.hex}}"
local secondary_container_hex = "{{colors.secondary_container.default.hex}}"
local tertiary_fixed_hex = "{{colors.tertiary_fixed.default.hex}}"
local primary_fixed_dim_hex = "{{colors.primary_fixed_dim.default.hex}}"
local secondary_fixed_dim_hex = "{{colors.secondary_fixed_dim.default.hex}}"
local inverse_surface_hex = "{{colors.inverse_surface.default.hex}}"

local light_mode = is_light_hex(background_hex)

local function tone(hex, amount)
  if amount == 0 then
    return hex
  end

  local offset = light_mode and -amount or amount
  return lighten(hex, offset)
end

local function inverse_tone(hex, amount)
  if amount == 0 then
    return hex
  end

  local offset = light_mode and amount or -amount
  return lighten(hex, offset)
end

M.base_30 = {
  white = "{{colors.on_background.default.hex}}",
  black = background_hex,
  darker_black = inverse_tone(background_hex, 3),
  black2 = tone(background_hex, 6),
  one_bg = tone(background_hex, 10),
  one_bg2 = tone(background_hex, 16),
  one_bg3 = tone(background_hex, 22),
  grey = surface_variant_hex,
  grey_fg = inverse_tone(surface_variant_hex, 10),
  grey_fg2 = inverse_tone(surface_variant_hex, 20),
  light_grey = outline_hex,
  red = error_hex,
  baby_pink = tone(error_hex, 10),
  pink = tertiary_hex,
  line = outline_hex,
  green = secondary_hex,
  vibrant_green = tone(secondary_hex, 10),
  blue = primary_hex,
  nord_blue = tone(primary_hex, 10),
  yellow = tone(tertiary_hex, 10),
  sun = tone(tertiary_hex, 20),
  purple = tertiary_hex,
  dark_purple = inverse_tone(tertiary_hex, 10),
  teal = secondary_container_hex,
  orange = error_hex,
  cyan = secondary_hex,
  pmenu_bg = surface_variant_hex,
  folder_bg = primary_fixed_dim_hex,
  lightbg = tone(background_hex, 10),
}

M.base_16 = {
  base00 = "{{colors.surface.default.hex}}",
  base01 = surface_variant_hex,
  base02 = secondary_fixed_dim_hex,
  base03 = outline_hex,
  base04 = "{{colors.on_surface_variant.default.hex}}",
  base05 = "{{colors.on_surface.default.hex}}",
  base06 = "{{colors.on_surface.default.hex}}",
  base07 = "{{colors.surface.default.hex}}",
  base08 = inverse_tone(error_hex, 10),
  base09 = tertiary_hex,
  base0A = primary_hex,
  base0B = tertiary_fixed_hex,
  base0C = primary_fixed_dim_hex,
  base0D = tone(primary_container_hex, 20),
  base0E = "{{colors.on_primary_container.default.hex}}",
  base0F = inverse_surface_hex,
}

M.type = light_mode and "light" or "dark"

M.polish_hl = {
  defaults = {
    Comment = {
      italic = true,
      fg = M.base_16.base03,
    },
    Visual = {
      bg = "{{colors.primary.default.hex}}",
      fg = "{{colors.on_primary.default.hex}}",
    },
  },
  Syntax = {
    String = {
      fg = "{{colors.tertiary.default.hex}}",
    },
  },
  treesitter = {
    ["@comment"] = {
      italic = true,
      fg = M.base_16.base03,
    },
    ["@string"] = {
      fg = "{{colors.tertiary.default.hex}}",
    },
  },
}

return M
