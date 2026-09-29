-- Toggle floating with a sensible default size
-- Terminals get 65% of the monitor, everything else 75%, then centered.

local M = {}

local TERMINAL_CLASSES = {
    kitty = true,
    Alacritty = true,
    ["com.mitchellh.ghostty"] = true,
    foot = true,
}

function M.toggle()
    local window = hl.get_active_window()
    if not window then return end

    -- already floating -> just tile it back
    if window.floating then
        hl.dispatch(hl.dsp.window.float({ action = "toggle", window = window }))
        return
    end

    local monitor = hl.get_active_monitor()
    if not monitor then return end

    local scale  = monitor.scale or 1
    local factor = TERMINAL_CLASSES[window.initial_class] and 0.65 or 0.75
    local width  = math.floor(monitor.width / scale * factor)
    local height = math.floor(monitor.height / scale * factor)

    hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = window }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end

return M
