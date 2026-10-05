-- =============================================================================
-- binds.lua — Hyprland Lua keybinds (Hyprland 0.55+)
-- =============================================================================

local mainMod = "SUPER"
local ctrlMod = mainMod .. " + CTRL"
local ctrlShiftMod = ctrlMod .. " + SHIFT"
local ipc = "uwsm-exec noctalia msg "

-- === Applications ===
-- --- Launchers ---
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("uwsm-exec xdg-terminal-exec"), { description = "Open terminal" })
hl.bind("SUPER + B", hl.dsp.exec_cmd("uwsm-exec brave"), { description = "Open web browser" })
hl.bind("SUPER + E", hl.dsp.exec_cmd("uwsm-exec nautilus"), { description = "Open file manager" })
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"), { description = "Open app launcher" })
hl.bind("ALT + space", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"), { description = "Open app launcher" })
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"),
  { description = "Open control center" })
hl.bind("SUPER + C", hl.dsp.exec_cmd("uwsm-exec code"), { description = "Open code editor" })
hl.bind("SUPER + N", hl.dsp.exec_cmd(ipc .. "panel-toggle noctalia/notes:panel"),
  { description = "Open notes" })

-- --- Tools & Pickers ---
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher /emo "), { description = "Open emoji picker" })

hl.bind("SUPER + V", hl.dsp.exec_cmd(ipc .. "panel-toggle clipboard"), { description = "Open clipboard manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(ipc .. "panel-toggle wallpaper"), { description = "Open wallpaper picker" })
hl.bind("SUPER + K", hl.dsp.exec_cmd("uwsm-exec bitwarden.desktop"), { description = "Open password manager" })
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(ipc .. "nightlight-force-toggle"), { description = "Toggle forced night light" })

-- --- Noctalia Panels & Controls ---
hl.bind(ctrlMod .. " + M", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center media"),
  { description = "Open music panel" })
hl.bind(ctrlMod .. " + SPACE", hl.dsp.exec_cmd(ipc .. "panel-toggle wallpaper"),
  { description = "Open wallpaper picker" })
hl.bind(ctrlMod .. " + V", hl.dsp.exec_cmd(ipc .. "panel-toggle clipboard"),
  { description = "Open clipboard manager" })
hl.bind(ctrlMod .. " + B", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center bluetooth"),
  { description = "Open Bluetooth panel" })
hl.bind(ctrlMod .. " + N", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center network"),
  { description = "Open network panel" })
hl.bind(ctrlMod .. " + W", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center weather"),
  { description = "Open weather panel" })
hl.bind(ctrlShiftMod .. " + B", hl.dsp.exec_cmd(ipc .. "bluetooth-toggle"),
  { description = "Toggle Bluetooth" })
hl.bind(ctrlShiftMod .. " + W", hl.dsp.exec_cmd(ipc .. "wifi-toggle"),
  { description = "Toggle Wi-Fi" })
hl.bind(ctrlShiftMod .. " + D", hl.dsp.exec_cmd(ipc .. "clipboard-clear"),
  { description = "Clear clipboard history" })
hl.bind(ctrlMod .. " + I", hl.dsp.exec_cmd(ipc .. "caffeine-toggle"),
  { description = "Toggle idle inhibitor" })
hl.bind(ctrlShiftMod .. " + SPACE", hl.dsp.exec_cmd(ipc .. "wallpaper-random"),
  { description = "Set random wallpaper" })

-- --- Scratchpads & Special ---
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("uwsm-exec xdg-terminal-exec --app-id=FloatingTerm"),
  { description = "Toggle floating terminal" })
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("uwsm-exec xdg-terminal-exec --app-id=FloatingTerm yazi"),
  { description = "Toggle Yazi" })
hl.bind("SUPER + TAB", hl.dsp.exec_cmd(ipc .. "window-switcher hold"), { description = "Open window switcher" })
hl.bind("ALT + TAB", hl.dsp.exec_cmd(ipc .. "window-switcher hold"), { description = "Switch windows" })
hl.bind("SUPER + U", hl.dsp.exec_cmd("uwsm-exec xdg-terminal-exec --app-id=FloatingTerm ~/.config/hypr/scripts/updater.sh"),
  { description = "Update system" })

-- === Window Management ===
-- --- Focus ---
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "l" }), { description = "Move focus left" })
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "r" }), { description = "Move focus right" })
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "u" }), { description = "Move focus up" })
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "d" }), { description = "Move focus down" })

-- --- Movement ---
hl.bind("SUPER + SHIFT + LEFT", hl.dsp.window.move({ direction = "l" }), { description = "Move window left" })
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.move({ direction = "r" }), { description = "Move window right" })
hl.bind("SUPER + SHIFT + UP", hl.dsp.window.move({ direction = "u" }), { description = "Move window up" })
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.window.move({ direction = "d" }), { description = "Move window down" })

-- --- Resizing ---
hl.bind("SUPER + ALT + RIGHT", hl.dsp.window.resize({ x = 30, y = 0, relative = true }),
  { repeating = true, description = "Resize window right" })
hl.bind("SUPER + ALT + LEFT", hl.dsp.window.resize({ x = -30, y = 0, relative = true }),
  { repeating = true, description = "Resize window left" })
hl.bind("SUPER + ALT + UP", hl.dsp.window.resize({ x = 0, y = -30, relative = true }),
  { repeating = true, description = "Resize window up" })
hl.bind("SUPER + ALT + DOWN", hl.dsp.window.resize({ x = 0, y = 30, relative = true }),
  { repeating = true, description = "Resize window down" })

-- --- Layout & State ---
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
  { description = "Toggle fake fullscreen" })
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
  { description = "Toggle real fullscreen" })
hl.bind("SUPER + A", require("scripts.toggle_float").toggle, { description = "Float active window" })
hl.bind("SUPER + SHIFT + C", hl.dsp.window.center(), { description = "Center window" })
hl.bind("SUPER + Y", hl.dsp.window.pin(), { description = "Pin floating window" })

-- --- Zoom ---
hl.bind("SUPER + equal", require("scripts.zoom").zoom_in, { repeating = true, description = "Zoom in" })
hl.bind("SUPER + minus", require("scripts.zoom").zoom_out, { repeating = true, description = "Zoom out" })
hl.bind("SUPER + BackSpace", require("scripts.zoom").reset, { repeating = true, description = "Reset zoom" })

-- --- Close & Kill ---
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close active window" })
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.kill(), { description = "Force-close active window" })

-- === Workspace Navigation ===
-- --- Switch Workspaces ---
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = "1" }), { description = "Switch to workspace 1" })
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = "2" }), { description = "Switch to workspace 2" })
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" }), { description = "Switch to workspace 3" })
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = "4" }), { description = "Switch to workspace 4" })
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = "5" }), { description = "Switch to workspace 5" })
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = "6" }), { description = "Switch to workspace 6" })
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = "7" }), { description = "Switch to workspace 7" })
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = "8" }), { description = "Switch to workspace 8" })
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = "9" }), { description = "Switch to workspace 9" })
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = "10" }), { description = "Switch to workspace 10" })

-- --- Relative Workspace Navigation ---
hl.bind("SUPER + CTRL + LEFT", hl.dsp.focus({ workspace = "m-1" }), { description = "Previous workspace" })
hl.bind("SUPER + CTRL + RIGHT", hl.dsp.focus({ workspace = "m+1" }), { description = "Next workspace" })
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace (scroll)" })
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace (scroll)" })

-- --- Move Windows to Workspaces ---
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = "1" }), { description = "Move window to workspace 1" })
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = "2" }), { description = "Move window to workspace 2" })
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = "3" }), { description = "Move window to workspace 3" })
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = "4" }), { description = "Move window to workspace 4" })
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = "5" }), { description = "Move window to workspace 5" })
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = "6" }), { description = "Move window to workspace 6" })
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = "7" }), { description = "Move window to workspace 7" })
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = "8" }), { description = "Move window to workspace 8" })
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = "9" }), { description = "Move window to workspace 9" })
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }), { description = "Move window to workspace 10" })

-- --- Move Windows (Silent) ---
hl.bind("SUPER + ALT + 1", hl.dsp.window.move({ workspace = "1", follow = false }),
  { description = "Move to workspace 1 (silent)" })
hl.bind("SUPER + ALT + 2", hl.dsp.window.move({ workspace = "2", follow = false }),
  { description = "Move to workspace 2 (silent)" })
hl.bind("SUPER + ALT + 3", hl.dsp.window.move({ workspace = "3", follow = false }),
  { description = "Move to workspace 3 (silent)" })
hl.bind("SUPER + ALT + 4", hl.dsp.window.move({ workspace = "4", follow = false }),
  { description = "Move to workspace 4 (silent)" })
hl.bind("SUPER + ALT + 5", hl.dsp.window.move({ workspace = "5", follow = false }),
  { description = "Move to workspace 5 (silent)" })
hl.bind("SUPER + ALT + 6", hl.dsp.window.move({ workspace = "6", follow = false }),
  { description = "Move to workspace 6 (silent)" })
hl.bind("SUPER + ALT + 7", hl.dsp.window.move({ workspace = "7", follow = false }),
  { description = "Move to workspace 7 (silent)" })
hl.bind("SUPER + ALT + 8", hl.dsp.window.move({ workspace = "8", follow = false }),
  { description = "Move to workspace 8 (silent)" })
hl.bind("SUPER + ALT + 9", hl.dsp.window.move({ workspace = "9", follow = false }),
  { description = "Move to workspace 9 (silent)" })
hl.bind("SUPER + ALT + 0", hl.dsp.window.move({ workspace = "10", follow = false }),
  { description = "Move to workspace 10 (silent)" })

-- --- Relative Movement ---
hl.bind("SUPER + CTRL + ALT + Right", hl.dsp.window.move({ workspace = "r+1" }),
  { description = "Move window to next relative workspace" })
hl.bind("SUPER + CTRL + ALT + Left", hl.dsp.window.move({ workspace = "r-1" }),
  { description = "Move window to previous relative workspace" })

-- === System Controls ===
-- --- Session Management ---
hl.bind("SUPER + L", hl.dsp.exec_cmd("uwsm-exec loginctl lock-session $XDG_SESSION_ID"), { description = "Lock screen" })
hl.bind("SUPER + ALT + DELETE", hl.dsp.exec_cmd("uwsm-exec ~/.config/hypr/scripts/logout.sh"), { description = "Logout" })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd(ipc .. "panel-toggle session"), { description = "Open power menu" })
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(ipc .. "panel-toggle session"), { description = "Open session menu" })

-- --- Display ---
hl.bind("SUPER + F12", require("scripts.movie_mode").toggle, { description = "Toggle movie mode" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(ipc .. "brightness-up current 5"),
  { repeating = true, locked = true, description = "Increase brightness" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down current 5"),
  { repeating = true, locked = true, description = "Decrease brightness" })

-- --- Screenshots ---
-- Saving and clipboard copying follow Noctalia's shared screenshot settings.
hl.bind("Print", hl.dsp.exec_cmd(ipc .. "screenshot-region"), { description = "Screenshot region" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(ipc .. "screenshot-region"), { description = "Screenshot region" })
hl.bind("SUPER + S", hl.dsp.exec_cmd(ipc .. "screenshot-region"), { description = "Screenshot region" })
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(ipc .. "screenshot-fullscreen"), { description = "Screenshot focused monitor" })

-- --- Screen Recording ---
hl.bind("SUPER + G", hl.dsp.exec_cmd(ipc .. "plugin noctalia/screen_recorder:service all toggle"),
  { description = "Toggle screen recorder" })


-- --- Audio ---
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. "volume-up 5"),
  { repeating = true, locked = true, description = "Increase volume" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. "volume-down 5"),
  { repeating = true, locked = true, description = "Decrease volume" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. "volume-mute"),
  { repeating = true, locked = true, description = "Toggle audio mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(ipc .. "mic-mute"),
  { repeating = true, locked = true, description = "Toggle microphone mute" })

-- --- Media ---
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(ipc .. "media next"), { locked = true, description = "Next media track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(ipc .. "media toggle"),
  { locked = true, description = "Pause/play media" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(ipc .. "media toggle"), { locked = true, description = "Play media" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(ipc .. "media previous"),
  { locked = true, description = "Previous media track" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd(ipc .. "media stop"), { locked = true, description = "Stop media" })


-- === Mouse Bindings ===
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Hold to move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Hold to resize window" })
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Hold to move window" })
hl.bind("ALT + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Hold to resize window" })

-- === Help & Utilities ===
hl.bind("SUPER + F2", hl.dsp.exec_cmd(ipc .. "panel-toggle kenn/keybind-cheatsheet:cheatsheet"),
  { description = "Open keybinds help" })

hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center system"),
  { description = "Open system monitor panel" })

hl.bind("SUPER + F1", require("scripts.gamemode").toggle, { description = "Toggle game mode" })

hl.bind("XF86RFKill",
  hl.dsp.exec_cmd(
    [[uwsm-exec sh -c 'case "$(rfkill list)" in *"Soft blocked: yes"*) notify-send "rfkill" "Airplane mode is on" -u critical --icon wifi;; esac']]),
  { repeating = true, locked = true, description = "Toggle airplane mode" })



-- === Move to Monitor ===
hl.bind("SUPER + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "l" }),
  { description = "Move window to left monitor" })
hl.bind("SUPER + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "r" }),
  { description = "Move window to right monitor" })
hl.bind("SUPER +SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "u" }),
  { description = "Move window to upper monitor" })
hl.bind("SUPER + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "d" }),
  { description = "Move window to lower monitor" })
