local show_desktop = require("scripts.show_desktop")
local toggle_float = require("scripts.toggle_float")

local horizontal_action

local function is_scrolling()
  local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
  return workspace and workspace.tiled_layout == "scrolling"
end

local function update_horizontal_gesture()
  local action = is_scrolling() and "scroll_move" or "workspace"
  if action == horizontal_action then return end

  -- Native gestures cannot share a binding; replace it when the layout changes.
  if horizontal_action then
    hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" })
  end
  hl.gesture({ fingers = 3, direction = "horizontal", action = action })
  horizontal_action = action
end

update_horizontal_gesture()

for _, event in ipairs({
  "hyprland.start", "config.reloaded", "config.props_refreshed",
  "monitor.focused", "workspace.active", "workspace.special_active", "window.active",
}) do
  hl.on(event, update_horizontal_gesture)
end
hl.gesture({ fingers = 4, direction = "down", action = show_desktop.toggle })
hl.gesture({ fingers = 3, direction = "pinch", mods = "CTRL", action = toggle_float.toggle })
hl.gesture({ fingers = 3, direction = "swipe", mods = "ALT", action = "resize" })
hl.gesture({ fingers = 3, direction = "swipe", mods = "CTRL", action = "move" })
hl.gesture({ fingers = 4, direction = "up", action = function()
  hl.exec_cmd("noctalia msg window-switcher")
end })
