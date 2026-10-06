local M = {}
local apps = require("config.apps")
local monitors = require("config.monitors")
local wake_settings

local function notify(message)
  hl.exec_cmd(apps.launcher .. ' -- notify-send --app-name=Hyprland --expire-time=3000 "Movie mode" "' .. message .. '"')
end

local function suspend_input_wake()
  if not wake_settings then
    wake_settings = {
      mouse_move_enables_dpms = hl.get_config("misc.mouse_move_enables_dpms"),
      key_press_enables_dpms = hl.get_config("misc.key_press_enables_dpms"),
    }
  end
  hl.config({ misc = { mouse_move_enables_dpms = false, key_press_enables_dpms = false } })
end

local function wake_laptop()
  local laptop = hl.get_monitor(monitors.laptop)
  if laptop and laptop.dpms_status == false then
    hl.dispatch(hl.dsp.dpms({ monitor = laptop, action = "on" }))
  end
  if wake_settings then
    hl.config({ misc = wake_settings })
    wake_settings = nil
  end
end

function M.toggle()
  local laptop = hl.get_monitor(monitors.laptop)
  if not laptop then
    notify("Laptop display is not connected")
    return
  end

  -- Use the actual power state so toggling still works after a config reload.
  if laptop.dpms_status == false then
    wake_laptop()
    notify("Off: laptop display restored")
    return
  end

  local external = hl.get_monitor(monitors.external)
  if not external then
    notify("Connect the external monitor first")
    return
  end

  hl.dispatch(hl.dsp.dpms({ monitor = external, action = "on" }))
  hl.dispatch(hl.dsp.focus({ monitor = external }))
  if type(external.x) == "number" and type(external.y) == "number"
    and type(external.width) == "number" and type(external.height) == "number"
    and type(external.scale) == "number" and external.scale > 0 then
    hl.dispatch(hl.dsp.cursor.move({
      x = external.x + external.width / external.scale / 2,
      y = external.y + external.height / external.scale / 2,
    }))
  end
  suspend_input_wake()
  hl.dispatch(hl.dsp.dpms({ monitor = laptop, action = "off" }))
  notify("On: laptop display off, external monitor focused")
end

-- Never leave the laptop dark when the external monitor is unplugged.
hl.on("monitor.removed", function(monitor)
  if monitor and monitor.name == monitors.external then
    wake_laptop()
  end
end)

hl.on("config.reloaded", function()
  -- Capture the freshly loaded settings, not those from before the reload.
  wake_settings = nil
  local laptop = hl.get_monitor(monitors.laptop)
  local external = hl.get_monitor(monitors.external)
  if laptop and laptop.dpms_status == false and external and external.dpms_status then
    suspend_input_wake()
  end
end)

return M
