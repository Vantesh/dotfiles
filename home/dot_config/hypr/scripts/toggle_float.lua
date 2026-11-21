-- Toggle floating with a sensible default size
-- All windows get 75% of the monitor, then centered.

local H = require("helpers")

local M = {}

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

    H.float_window_centered(window, 0.75, 0.75, hl.get_active_monitor())
end

return M
