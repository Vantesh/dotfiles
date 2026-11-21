-- Toggle "game mode": kills animations, blur, shadows, rounding, gaps and
-- opacity effects in one hl.config() call, and hides the Noctalia bars.

local H = require("helpers")

local M = {}

function M.toggle()
    local game_mode_on = (hl.get_config("animations.enabled") == false)

    if game_mode_on then
        -- restore everything from the config files
        hl.dispatch(hl.dsp.reload_config())
        hl.exec_cmd(H.ipc("bar-show"))
        H.notify("Gamemode", "Default settings restored")
        return
    end

    hl.config({
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = 1,
        },
        animations = {
            enabled = false,
        },
        decoration = {
            rounding = 0,
            active_opacity = 1,
            inactive_opacity = 1,
            shadow = { enabled = false },
            blur = { enabled = false },
        },
    })

    hl.exec_cmd(H.ipc("bar-hide"))
    H.notify("Gamemode", "Animations and blur disabled")
end

return M
