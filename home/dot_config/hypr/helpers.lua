-- Shared helpers for the Hyprland config.
-- Usage: local H = require("helpers")
-- Keep this file free of side effects: it only defines functions.

local apps = require("config.apps")

local M = {}

-- === Numbers ===

function M.is_positive_finite(value)
  return type(value) == "number" and value > 0 and value < math.huge
end

-- === Shell commands ===

--- Single-quote a string for safe use in a shell command.
function M.shell_quote(text)
  return "'" .. (tostring(text):gsub("'", "'\\''")) .. "'"
end

--- Wrap a command so it runs through the app launcher (uwsm-app).
function M.launch(command)
  return apps.launcher .. " -- " .. command
end

--- Launcher-wrapped terminal command.
M.terminal = M.launch(apps.terminal)

--- Terminal command with a window title (used by window rules to float it).
function M.floating_terminal(title)
  return M.terminal .. " --title=" .. M.shell_quote(title)
end

--- Desktop-shell IPC command, e.g. M.ipc("panel-toggle launcher").
function M.ipc(args)
  return M.launch(apps.desktopShell .. " msg " .. args)
end

--- Desktop notification via notify-send.
function M.notify(title, message)
  hl.exec_cmd(M.launch(
    "notify-send --app-name=Hyprland --expire-time=3000 "
      .. M.shell_quote(title) .. " " .. M.shell_quote(message)
  ))
end

-- === Events and timers ===

--- Register one callback for several events.
function M.on_events(events, callback)
  for _, event in ipairs(events) do
    hl.on(event, callback)
  end
end

--- Run a callback once after `delay_ms`.
function M.defer(callback, delay_ms)
  hl.timer(callback, { timeout = delay_ms, type = "oneshot" })
end

-- === Monitors and windows ===

--- Scaled (logical) size of a monitor, or nil when its data isn't usable yet.
function M.logical_size(monitor)
  if not monitor then return nil end

  local width, height, scale = monitor.width, monitor.height, monitor.scale
  if not (M.is_positive_finite(width)
        and M.is_positive_finite(height)
        and M.is_positive_finite(scale)) then
    return nil
  end

  local logical_width, logical_height = width / scale, height / scale
  -- Division can overflow.
  if not (M.is_positive_finite(logical_width)
        and M.is_positive_finite(logical_height)) then
    return nil
  end

  return logical_width, logical_height
end

--- Move the cursor to the center of a monitor.
function M.center_cursor(monitor)
  local width, height = M.logical_size(monitor)
  if not width then return end
  if type(monitor.x) ~= "number" or type(monitor.y) ~= "number" then return end

  hl.dispatch(hl.dsp.cursor.move({
    x = monitor.x + width / 2,
    y = monitor.y + height / 2,
  }))
end

--- Float a window at a fraction of a monitor's logical size, centered.
--- `monitor` defaults to the window's own monitor. Returns true on success.
function M.float_window_centered(window, width_fraction, height_fraction, monitor)
  local logical_width, logical_height = M.logical_size(monitor or window.monitor)
  if not logical_width then return false end

  -- Flooring can produce a zero-sized dimension.
  local width = math.floor(logical_width * width_fraction)
  local height = math.floor(logical_height * height_fraction)
  if not (M.is_positive_finite(width) and M.is_positive_finite(height)) then
    return false
  end

  hl.dispatch(hl.dsp.window.float({ action = "enable", window = window }))
  if not window.floating then return false end

  hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = window }))
  hl.dispatch(hl.dsp.window.center({ window = window }))
  return true
end

--- Layout of the active workspace, including special workspaces.
function M.active_layout()
  local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
  return workspace and workspace.tiled_layout
end

--- Layout message that only runs when the active workspace uses `layout`.
--- Layout messages go to whatever layout is active, so e.g. a scrolling-only
--- message on a dwindle workspace raises "Unknown dwindle layoutmsg".
function M.layout_msg(layout, message)
  return function()
    if M.active_layout() == layout then
      hl.dispatch(hl.dsp.layout(message))
    end
  end
end

-- === Window rules ===

--- Centered floating window rule with monitor-relative dimensions.
--- `name` may be nil. Sizes are fractions, e.g. 0.7.
function M.centered_float(name, match, width, height)
  hl.window_rule({
    name = name,
    match = match,
    float = true,
    center = true,
    size = { ("monitor_w*%s"):format(width), ("monitor_h*%s"):format(height) },
  })
end

return M
