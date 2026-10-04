local minimize     = require("scripts.minimize")
local toggle_float = require("scripts.toggle_float")

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "down", action = minimize.toggle_show_desktop })
hl.gesture({ fingers = 3, direction = "pinch", mods = "CTRL", action = toggle_float.toggle })
hl.gesture({ fingers = 3, direction = "swipe", mods = "ALT", action = "resize" })
hl.gesture({ fingers = 3, direction = "swipe", mods = "CTRL", action = "move" })
hl.gesture({ fingers = 4, direction = "up", action = function() hl.dispatch(hl.dsp.exec_cmd(
  "noctalia msg window-switcher")) end })
