-- "Show desktop" style minimize
--   first call  -> move every window of the active workspace to special:desktop
--   second call -> bring them all back

local M = {}

local TAG = "desktop"

--- Hide all windows on the active workspace / restore them.
function M.toggle_show_desktop()
    if hl.get_workspace("special:desktop") then
        -- something is stashed away: move it back and untag
        hl.dispatch(hl.dsp.window.move({
            workspace = hl.get_active_workspace(),
            window = "tag:" .. TAG,
        }))
        hl.dispatch(hl.dsp.window.clear_tags({ window = "tag:" .. TAG }))
        return
    end

    local workspace = hl.get_active_workspace()
    if not workspace then return end

    for _, window in ipairs(hl.get_workspace_windows(workspace)) do
        hl.dispatch(hl.dsp.window.tag({ tag = TAG, window = window }))
        hl.dispatch(hl.dsp.window.move({
            workspace = "special:desktop",
            window = window,
            follow = false,
        }))
    end
end

function M.toggle_window()
    if hl.get_workspace("special:minimized") then
        hl.dispatch(hl.dsp.window.move({
            workspace = hl.get_active_workspace(),
            window = "tag:minimized",
        }))
        hl.dispatch(hl.dsp.window.clear_tags({ window = "tag:minimized" }))
    else
        hl.dispatch(hl.dsp.window.tag({ tag = "minimized", window = hl.get_active_window() }))
        hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
    end
end

return M
