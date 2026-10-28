-- Show desktop without moving windows out of their layout.
local M = {}

local DESKTOP_PREFIX = "__show_desktop:"
local PINNED_TAG = "show-desktop-pinned"

function M.is_desktop_workspace(workspace)
    return workspace ~= nil and type(workspace.name) == "string"
        and workspace.name:sub(1, #DESKTOP_PREFIX) == DESKTOP_PREFIX
end

local function encode(selector)
    return (selector:gsub("([^%w_%-%.])", function(character)
        return string.format("%%%02X", string.byte(character))
    end))
end

local function decode(selector)
    return (selector:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function focus_workspace(selector)
    local target = hl.get_workspace(selector)
    local active = hl.get_active_workspace()
    -- Compare workspace objects: named workspaces have no numeric ID.
    if target and target == active then return end
    hl.dispatch(hl.dsp.focus({ workspace = target or selector }))
end

local function restore_pins()
    for _, window in ipairs(hl.get_windows({ tag = PINNED_TAG }) or {}) do
        local workspace = window.workspace
        local monitor = window.monitor
        local active = monitor and monitor.active_workspace
        if window.pinned then
            hl.dispatch(hl.dsp.window.tag({ tag = "-" .. PINNED_TAG, window = window }))
        elseif workspace and not workspace.special and active
            and not M.is_desktop_workspace(active)
            and window.floating and window.fullscreen == 0 then
            -- Pinning follows the monitor's active workspace, including after hotplug.
            pcall(hl.dispatch, hl.dsp.window.pin({ action = "enable", window = window }))
            if window.pinned then
                hl.dispatch(hl.dsp.window.tag({ tag = "-" .. PINNED_TAG, window = window }))
            end
        end
    end
end

local function unpin(window)
    if not window.pinned then return true end
    if not window.floating or window.fullscreen ~= 0 then return false end
    pcall(hl.dispatch, hl.dsp.window.pin({ action = "disable", window = window }))
    if window.pinned then return false end
    hl.dispatch(hl.dsp.window.tag({ tag = "+" .. PINNED_TAG, window = window }))
    return true
end

local function fallback_workspace(monitor)
    local previous = hl.get_last_workspace(monitor)
    if previous and previous.monitor == monitor and not previous.special
        and not M.is_desktop_workspace(previous) then
        return previous
    end
    for _, workspace in ipairs(hl.get_workspaces() or {}) do
        if workspace.monitor == monitor and not workspace.special
            and not M.is_desktop_workspace(workspace) then
            return workspace
        end
    end

    local index = 1
    local selector
    repeat
        selector = "name:__desktop_return:" .. monitor.name .. ":" .. index
        index = index + 1
    until not hl.get_workspace(selector)
    hl.workspace_rule({ workspace = selector, monitor = monitor.name })
    return selector
end

function M.toggle()
    local workspace = hl.get_active_workspace()
    if not workspace then return end

    if M.is_desktop_workspace(workspace) then
        local encoded = workspace.name:sub(#DESKTOP_PREFIX + 1):match("^(.-):%d+$")
        local origin = encoded and hl.get_workspace(decode(encoded))
        local monitor = workspace.monitor or hl.get_active_monitor()
        local selector = origin and not origin.special and origin
            or (monitor and fallback_workspace(monitor))
        if selector then focus_workspace(selector) end
        restore_pins()
        return
    end

    restore_pins()
    local monitor = workspace.monitor
    if not monitor or workspace.special then return end
    local windows = workspace:get_windows()
    if #windows == 0 then return end

    local origin = workspace.id and tostring(workspace.id) or "name:" .. workspace.addressable_name
    local index = 1
    local selector
    repeat
        selector = "name:" .. DESKTOP_PREFIX .. encode(origin) .. ":" .. index
        index = index + 1
        local desktop = hl.get_workspace(selector)
    until not desktop or (#desktop:get_windows() == 0 and desktop.monitor == monitor)

    hl.workspace_rule({ workspace = selector, monitor = monitor.name })
    for _, window in ipairs(windows) do
        if not unpin(window) then
            restore_pins()
            return
        end
    end
    focus_workspace(selector)
end

local recovery_pending = false
local function schedule_recovery()
    if recovery_pending then return end
    recovery_pending = true
    -- Let workspace switches, rule updates, and monitor migrations finish first.
    hl.timer(function()
        recovery_pending = false
        restore_pins()
    end, { timeout = 100, type = "oneshot" })
end

for _, event in ipairs({
    "workspace.active", "workspace.move_to_monitor", "monitor.added", "monitor.removed",
    "monitor.layout_changed", "config.reloaded", "window.fullscreen", "window.update_rules",
    "window.move_to_workspace",
}) do
    hl.on(event, schedule_recovery)
end

return M
