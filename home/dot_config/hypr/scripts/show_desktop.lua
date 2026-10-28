-- Fade windows in place; an empty special workspace blocks input without changing
-- the regular workspace selected by Noctalia. Existing windows stay in their layout.
local M = {}
local SPECIAL_PREFIX = "special:__show_desktop:"
local HIDDEN_TAG = "show-desktop-hidden"
local FOCUS_TAG = "show-desktop-focus"
local states = {}

hl.window_rule({
    name = "show-desktop-hidden",
    match = { tag = HIDDEN_TAG },
    opacity = "0.0 override 0.0 override 0.0 override",
    no_focus = true,
    stay_focused = false,
    no_shadow = true,
    no_blur = true,
})

function M.is_desktop_workspace(workspace)
    return workspace ~= nil and workspace.special
        and workspace.addressable_name:sub(1, #SPECIAL_PREFIX) == SPECIAL_PREFIX
end

local function reveal(windows)
    for _, window in ipairs(windows) do
        if window.mapped then
            hl.dispatch(hl.dsp.window.tag({ window = window, tag = "-" .. HIDDEN_TAG }))
            hl.dispatch(hl.dsp.window.tag({ window = window, tag = "-" .. FOCUS_TAG }))
        end
    end
end

local function restore(monitor, restore_focus)
    local state = monitor and states[monitor.name]
    if not state then return end
    states[monitor.name] = nil
    state.redirect:set_enabled(false)
    -- Close the shield while windows still reject focus, then restore explicitly.
    if M.is_desktop_workspace(monitor.active_special_workspace) then
        monitor:set_special_workspace(nil)
    end
    reveal(state.windows)
    if restore_focus and state.focus and state.focus.mapped
        and state.focus.workspace == monitor.active_workspace then
        hl.dispatch(hl.dsp.focus({ window = state.focus }))
    end
end

local function restore_all(restore_focus)
    local monitor = hl.get_active_monitor()
    local focus
    for _, window in ipairs(hl.get_windows({ tag = FOCUS_TAG })) do
        if monitor and window.workspace == monitor.active_workspace then focus = window end
    end
    for _, state in pairs(states) do state.redirect:set_enabled(false) end
    states = {}
    for _, output in ipairs(hl.get_monitors()) do
        if M.is_desktop_workspace(output.active_special_workspace) then
            output:set_special_workspace(nil)
        end
    end
    -- Tags survive config reloads, unlike Lua references. Always reveal them.
    reveal(hl.get_windows({ tag = HIDDEN_TAG }))
    if restore_focus and focus and focus.mapped then
        hl.dispatch(hl.dsp.focus({ window = focus }))
    end
end

function M.toggle()
    local monitor = hl.get_active_monitor()
    local workspace = monitor and monitor.active_workspace
    if not monitor or not workspace then return end
    if states[monitor.name] then
        restore(monitor, true)
        return
    end
    -- Do not replace an application's special workspace or permit click-through.
    if monitor.active_special_workspace then return end
    if hl.get_config("input.special_fallthrough") then
        error("Show Desktop requires input.special_fallthrough = false")
    end
    local windows = workspace:get_windows()
    if #windows == 0 then return end
    local selector = SPECIAL_PREFIX .. monitor.name
    local existing = hl.get_workspace(selector)
    if existing and #existing:get_windows() > 0 then
        error("Show Desktop's reserved special workspace contains windows")
    end
    local focus = hl.get_active_window()
    -- New applications must not inherit the empty special workspace.
    local origin = workspace.id and tostring(workspace.id) or "name:" .. workspace.addressable_name
    local redirect = hl.window_rule({
        name = "show-desktop-launch:" .. monitor.name,
        match = { workspace = selector },
        workspace = origin .. " silent",
    })
    states[monitor.name] = {
        workspace = workspace, windows = windows, focus = focus, redirect = redirect,
    }
    local ok, reason = pcall(function()
        for _, window in ipairs(windows) do
            if window.mapped then
                hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. HIDDEN_TAG }))
                if window == focus then
                    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. FOCUS_TAG }))
                end
            end
        end
        -- This monitor method takes a bare special name, not a prefixed selector.
        monitor:set_special_workspace(selector:sub(#"special:" + 1))
        if not M.is_desktop_workspace(monitor.active_special_workspace) then
            error("Could not open Show Desktop's input shield")
        end
    end)
    if not ok then
        restore(monitor, true)
        error(reason)
    end
end

hl.on("workspace.active", function(workspace)
    local monitor = workspace and workspace.monitor
    local state = monitor and states[monitor.name]
    if state and workspace ~= state.workspace then restore(monitor, false) end
end)
hl.on("workspace.special_active", function(workspace, monitor)
    if monitor and states[monitor.name] and not M.is_desktop_workspace(workspace) then
        restore(monitor, false)
    end
end)
hl.on("window.open", function(window)
    restore(window and window.monitor, false)
end)
hl.on("monitor.removed", function() restore_all(false) end)
hl.on("config.unload", function() restore_all(true) end)
hl.on("config.reloaded", function() restore_all(true) end)

return M
