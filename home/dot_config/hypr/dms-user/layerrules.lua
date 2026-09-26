--[[ ================================================================

  Layer rules target Wayland "layer surfaces" (bars, launchers,
  notifications, wallpapers) rather than regular windows, so the
  only match prop available is `namespace` — check what a given
  layer calls itself with:

      hyprctl layers

add an app/component to the relevant list below rather than writing a new hl.layer_rule() block.
================================================================ ]]

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------

local function merge(...)
  local out = {}
  for _, t in ipairs({ ... }) do
    for k, v in pairs(t) do out[k] = v end
  end
  return out
end

-- RE2 supports (?i) for case-insensitive matching inline.
local function ci(pattern)
  return "(?i)" .. pattern
end

local function alt(list)
  return ci("^(" .. table.concat(list, "|") .. ")$")
end

local function lrule(name, match, ...)
  hl.layer_rule(merge({ name = name, match = match }, ...))
end

-- ---------------------------------------------------------------
-- NAMESPACE REGISTRY — edit these lists to add/remove layers
-- ---------------------------------------------------------------

local fade_namespaces = { "hyprpicker", "logout_dialog", "selection" }
local quickshell_namespaces = { "quickshell.*", "dms.*" }

-- ---------------------------------------------------------------
-- LAYER RULES
-- ---------------------------------------------------------------

lrule("utility-layer-fade", { namespace = alt(fade_namespaces) }, { animation = "fade" })

lrule("quickshell-blur",
  { namespace = alt(quickshell_namespaces) },
  { blur = true, ignore_alpha = 0.65, blur_popups = true, no_anim = true })
