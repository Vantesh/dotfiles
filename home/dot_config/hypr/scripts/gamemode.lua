-- Toggle "game mode": kills animations, blur, shadows, rounding, gaps and
-- opacity effects in one hl.config() call, and hides the DMS bar.

local M = {}

function M.toggle()
    local game_mode_on = (hl.get_config("animations.enabled") == false)

    if game_mode_on then
        -- restore everything from the config files
        hl.exec_cmd("hyprctl reload")
        hl.exec_cmd("dms ipc call bar reveal index 0")
        hl.exec_cmd([[notify-send --app-name="Hyprland" --expire-time=3000 "Gamemode" "Default settings restored"]])
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

    hl.exec_cmd("dms ipc call bar hide index 0")
    hl.exec_cmd([[notify-send --app-name="Hyprland" --expire-time=3000 "Gamemode" "Animations and blur disabled"]])
end

return M
