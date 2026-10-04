-- Workspace placement and startup are separate from general window styling.
local monitors = require("config.monitors")
local dual_display = hl.get_monitor(monitors.external) ~= nil and hl.get_monitor(monitors.laptop) ~= nil
local placement_rules = {}

for id = 1, 9 do
  placement_rules[#placement_rules + 1] = hl.workspace_rule({
    workspace = tostring(id),
    monitor = monitors.external,
    default = id == 1,
    enabled = dual_display,
  })
end
placement_rules[#placement_rules + 1] = hl.workspace_rule({
  workspace = "10", monitor = monitors.laptop, default = true, persistent = true, enabled = dual_display,
})

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 1, gaps_in = 1 })
hl.workspace_rule({ workspace = "special:exposed", gaps_out = 60, gaps_in = 30, border_size = 5, no_shadow = true })

-- "silent" prevents switching workspaces; no_initial_focus still allows manual focus later.
local spotify_rule = hl.window_rule({
  name = "spotify-workspace",
  match = { class = "^([Ss]potify)$" },
  workspace = "10 silent",
  no_initial_focus = true,
  enabled = dual_display,
})

local function place_workspaces()
  local external = hl.get_monitor(monitors.external)
  local laptop = hl.get_monitor(monitors.laptop)
  local connected = external ~= nil and laptop ~= nil
  if connected ~= dual_display then
    dual_display = connected
    for _, rule in ipairs(placement_rules) do rule:set_enabled(connected) end
    if spotify_rule then spotify_rule:set_enabled(connected) end
  end
  if not external or not laptop then return end

  local active = hl.get_active_workspace()
  local active_id = active and active.id
  for _, workspace in ipairs(hl.get_workspaces() or {}) do
    if type(workspace.id) == "number" and workspace.id > 0 then
      local target = workspace.id == 10 and laptop or external
      if target and workspace.monitor ~= target then
        hl.dispatch(hl.dsp.workspace.move({ workspace = workspace, monitor = target }))
      end
    end
  end

  -- Also put an already-running Spotify back on the laptop after reconnecting.
  for _, window in ipairs(hl.get_windows() or {}) do
    if type(window.class) == "string" and window.class:match("^[Ss]potify$")
      and window.workspace and window.workspace.id and window.workspace.id ~= 10 then
      hl.dispatch(hl.dsp.window.move({ window = window, workspace = "10", follow = false }))
    end
  end

  laptop:set_workspace({ workspace = "10" })
  local current = hl.get_active_workspace()
  -- Focusing the current workspace toggles back when workspace_back_and_forth is enabled.
  if active_id and (not current or current.id ~= active_id) then
    hl.dispatch(hl.dsp.focus({ workspace = tostring(active_id) }))
  end
end

local function schedule_placement()
  -- Defer until Hyprland finishes applying the monitor layout / creating the workspace.
  hl.timer(place_workspaces, { timeout = 100, type = "oneshot" })
end

hl.on("config.reloaded", schedule_placement)
hl.on("monitor.added", schedule_placement)
hl.on("monitor.removed", schedule_placement)
hl.on("workspace.created", schedule_placement)

hl.on("hyprland.start", function()
  hl.timer(function()
    place_workspaces()
    if not dual_display then return end
    local monitor = hl.get_monitor(monitors.external)
    if monitor then
      hl.dispatch(hl.dsp.focus({ monitor = monitor }))
      local active = hl.get_active_workspace()
      if not active or active.id ~= 1 then
        hl.dispatch(hl.dsp.focus({ workspace = "1" }))
      end
      if type(monitor.x) == "number" and type(monitor.y) == "number"
        and type(monitor.width) == "number" and type(monitor.height) == "number"
        and type(monitor.scale) == "number" and monitor.scale > 0 then
        hl.dispatch(hl.dsp.cursor.move({
          x = monitor.x + monitor.width / monitor.scale / 2,
          y = monitor.y + monitor.height / monitor.scale / 2,
        }))
      end
    end
    hl.exec_cmd("uwsm-exec spotify-launcher")
  end, { timeout = 100, type = "oneshot" })
end)
