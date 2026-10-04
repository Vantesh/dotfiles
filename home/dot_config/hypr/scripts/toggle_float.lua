-- Toggle floating with a sensible default size
-- All windows get 75% of the monitor, then centered.

local M = {}


local function is_positive_finite(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

function M.toggle()
    local window = hl.get_active_window()
    if not window then return end

    -- Pin changes, resize and center require a non-fullscreen/non-maximized window.
    if (window.fullscreen or 0) ~= 0 then return end

    if window.floating then
        -- Unpin while still floating; never tile if unpinning failed.
        if window.pinned then
            hl.dispatch(hl.dsp.window.pin({ action = "disable", window = window }))
            if window.pinned then return end
        end
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = window }))
        return
    end

    local monitor = hl.get_active_monitor()
    if not monitor then return end

    local monitor_width, monitor_height, scale = monitor.width, monitor.height, monitor.scale
    if not is_positive_finite(monitor_width)
        or not is_positive_finite(monitor_height)
        or not is_positive_finite(scale) then return end

    local width  = math.floor(monitor_width / scale * 0.75)
    local height = math.floor(monitor_height / scale * 0.75)
    -- Division can overflow, and flooring can produce a zero-sized dimension.
    if not is_positive_finite(width) or not is_positive_finite(height) then return end

    hl.dispatch(hl.dsp.window.float({ action = "enable", window = window }))
    if not window.floating then return end
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = window }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end

return M
