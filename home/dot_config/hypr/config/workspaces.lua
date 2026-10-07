local apps = require("config.apps")
local monitors = require("config.monitors")
local minimize = require("scripts.minimize")

local LAPTOP_WORKSPACE = 10
local EXTERNAL_WORKSPACE = 1
local PLACEMENT_DELAY = 100

local function get_monitors()
  return hl.get_monitor(monitors.external),
    hl.get_monitor(monitors.laptop)
end

local external, laptop = get_monitors()
local dual_display = external ~= nil and laptop ~= nil
local placement_rules = {}

local function add_placement_rule(options)
  options.enabled = dual_display
  placement_rules[#placement_rules + 1] = hl.workspace_rule(options)
end

for id = 1, 9 do
  add_placement_rule({
    workspace = tostring(id),
    monitor = monitors.external,
    default = id == EXTERNAL_WORKSPACE,
  })
end

add_placement_rule({
  workspace = tostring(LAPTOP_WORKSPACE),
  monitor = monitors.laptop,
  layout = "scrolling",
  default = true,
  persistent = true,
})

hl.workspace_rule({
  workspace = "w[tv1]",
  gaps_out = 1,
  gaps_in = 1,
})

hl.workspace_rule({
  workspace = "special:exposed",
  gaps_out = 60,
  gaps_in = 30,
  border_size = 5,
  no_shadow = true,
})

local spotify_rule = hl.window_rule({
  name = "spotify-workspace",
  match = { class = "^([Ss]potify|[Ss]potifast|[Ss]poticast)$" },
  workspace = tostring(LAPTOP_WORKSPACE) .. " silent",
  no_initial_focus = true,
  enabled = dual_display,
})

local function update_rules(connected)
  if connected == dual_display then return end

  dual_display = connected

  for _, rule in ipairs(placement_rules) do
    rule:set_enabled(connected)
  end

  if spotify_rule then
    spotify_rule:set_enabled(connected)
  end
end

local function active_workspace_id()
  local workspace = hl.get_active_workspace()
  return workspace and workspace.id
end

local function focus_workspace(id)
  -- Avoid toggling back when workspace_back_and_forth is enabled.
  if id and active_workspace_id() ~= id then
    local workspace = hl.get_workspace(tostring(id))
    hl.dispatch(hl.dsp.focus({
      workspace = workspace and workspace.config_name or tostring(id),
    }))
  end
end

local function move_workspaces(external_monitor, laptop_monitor)
  for _, workspace in ipairs(hl.get_workspaces() or {}) do
    if not minimize.is_desktop_workspace(workspace)
      and type(workspace.id) == "number" and workspace.id > 0 then
      local target = workspace.id == LAPTOP_WORKSPACE
        and laptop_monitor or external_monitor

      if workspace.monitor ~= target then
        hl.dispatch(hl.dsp.workspace.move({
          workspace = workspace,
          monitor = target,
        }))
      end
    end
  end
end

local function move_spotify()
  for _, window in ipairs(hl.get_windows() or {}) do
    local is_spotify = type(window.class) == "string"
      and (window.class:match("^[Ss]potify$")
              or window.class:match("^[Ss]potifast$")
              or window.class:match("^[Ss]poticast$"))
    local workspace_id = window.workspace and window.workspace.id

    if is_spotify and workspace_id
      and workspace_id ~= LAPTOP_WORKSPACE then
      hl.dispatch(hl.dsp.window.move({
        window = window,
        workspace = tostring(LAPTOP_WORKSPACE),
        follow = false,
      }))
    end
  end
end

local function place_workspaces()
  local external_monitor, laptop_monitor = get_monitors()

  update_rules(external_monitor ~= nil and laptop_monitor ~= nil)

  -- Direct checks let the Lua analyzer narrow both monitor types.
  if not external_monitor or not laptop_monitor then return end

  local previous_workspace = active_workspace_id()

  move_workspaces(external_monitor, laptop_monitor)
  move_spotify()

  if not minimize.is_desktop_workspace(laptop_monitor.active_workspace) then
    laptop_monitor:set_workspace({
      workspace = tostring(LAPTOP_WORKSPACE),
    })
  end

  focus_workspace(previous_workspace)
end

local function center_cursor(monitor)
  for _, field in ipairs({ "x", "y", "width", "height", "scale" }) do
    if type(monitor[field]) ~= "number" then return end
  end
  if monitor.scale <= 0 then return end

  hl.dispatch(hl.dsp.cursor.move({
    x = monitor.x + monitor.width / monitor.scale / 2,
    y = monitor.y + monitor.height / monitor.scale / 2,
  }))
end

local function defer(callback)
  hl.timer(callback, {
    timeout = PLACEMENT_DELAY,
    type = "oneshot",
  })
end

local function schedule_placement(workspace)
  if minimize.is_desktop_workspace(workspace) then return end
  defer(place_workspaces)
end

for _, event in ipairs({
  "config.reloaded",
  "monitor.added",
  "monitor.removed",
  "workspace.created",
}) do
  hl.on(event, schedule_placement)
end

hl.on("hyprland.start", function()
  defer(function()
    place_workspaces()
    if not dual_display then return end

    local external_monitor = hl.get_monitor(monitors.external)
    if external_monitor then
      hl.dispatch(hl.dsp.focus({
        monitor = external_monitor,
      }))
      focus_workspace(EXTERNAL_WORKSPACE)
      center_cursor(external_monitor)
    end

    hl.exec_cmd(apps.launcher .. " -- " .. apps.music)
  end)
end)
