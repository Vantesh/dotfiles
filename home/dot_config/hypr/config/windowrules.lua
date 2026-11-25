-- Window rules — https://wiki.hypr.land/configuring/core/rules/window-rules/
-- Rules apply top to bottom; later matches override earlier properties.

local H = require("helpers")
local centered_float = H.centered_float

-- === Match patterns ===

-- Brave's class varies by packaging.
local BRAVE_CLASSES = {
  brave = true,
  Brave = true,
  ["brave-browser"] = true,
  ["Brave-browser"] = true,
}

local BRAVE_CLASS_PATTERN = "^([Bb]rave(-browser)?)$"
local OBSIDIAN_CLASS_PATTERN = "^([Oo]bsidian|md\\.obsidian\\.Obsidian)$"
local QB_CLASS = "^(org\\.qbittorrent\\.qBittorrent)$"
local LUCIOLE_CLASS = "^(dev\\.noctalia\\.luciole)$"
local LUCIOLE_TERMINAL_CLASS = "^(dev\\.noctalia\\.luciole\\.terminal)$"

-- === Global behavior ===

-- Full-width scrolling columns on the laptop; floating geometry is unaffected.
hl.window_rule({
  name = "laptop-scrolling-width",
  match = { workspace = "10" },
  scrolling_width = 1.0,
})

-- Tiled windows never maximize and do not cast shadows.
hl.window_rule({
  name = "suppress-maximize",
  match = { class = ".*" },
  suppress_event = "maximize",
})
hl.window_rule({
  name = "no-shadow-tiled",
  match = { float = false },
  no_shadow = true,
})

-- Center floating Wayland windows by default.
hl.window_rule({
  match = { float = true, xwayland = false },
  center = true,
})

-- Keep special-workspace borders under workspace-rule control.
hl.window_rule({
  match = { float = false, workspace = "s[false]w[tv1]" },
  border_size = 2,
})

-- === Wine, Proton and XWayland ===

hl.window_rule({
  match = { xwayland = true, title = "^(win[0-9]+)$" },
  no_dim = true,
  no_shadow = true,
  rounding = 10,
})
hl.window_rule({
  name = "immediate-wine-exe",
  match = { title = ".*\\.exe" },
  immediate = true,
})
hl.window_rule({
  name = "immediate-minecraft",
  match = { title = ".*minecraft.*" },
  immediate = true,
})
hl.window_rule({
  name = "immediate-steam-app",
  match = { class = "^(steam_app_.*)$" },
  immediate = true,
})

-- === Shared application behavior ===

-- Media viewers and the browser are fully opaque.
hl.window_rule({
  name = "opaque",
  match = {
    class = "^(imv|mpv|[Bb]rave(-browser)?)$",
  },
  opaque = true,
})

-- Keep the system awake during media playback; browsers only while fullscreen.
hl.window_rule({
  name = "idle-inhibit-media",
  match = { class = "^(mpv|spotifast)$" },
  idle_inhibit = "focus",
})
hl.window_rule({
  name = "idle-inhibit-browser",
  match = { class = BRAVE_CLASS_PATTERN },
  idle_inhibit = "fullscreen",
})

-- Hide private messaging content from screen sharing.
hl.window_rule({
  name = "private",
  match = { class = "^(zapfast)$" },
  no_screen_share = true,
})

-- Embedded video always renders at full opacity.
hl.window_rule({
  match = { title = ".*(YouTube).*" },
  opacity = "1.0 override",
})

-- === Floating presets ===

-- Applications sharing the same large floating geometry.
centered_float("float-large", {
  class = "^(auto-cpufreq-gtk|nvidia-settings|localsend|org\\.localsend\\.localsend_app|org\\.gnome\\.Evince|mpv)$",
}, "0.7", "0.7")



centered_float("float-small", {
  class = "^(udiskie)$",
}, "0.3", "0.4")

hl.window_rule({
  name = "float-plain",
  match = { class = "^(nwg-look)$" },
  float = true,
})

-- Download manager floats; geometry is configured below.
hl.window_rule({
  name = "float-qbittorrent",
  match = { class = QB_CLASS },
  float = true,
})

-- Luciole launcher: main window, file chooser windows and spawned terminals.
centered_float("luciole-main", {
  class = LUCIOLE_CLASS,
}, "0.8", "0.8")

-- File chooser windows use host-supplied titles; keep them at the previous picker size.
centered_float("luciole-dialog", {
  class = LUCIOLE_CLASS,
  title = "negative:^Luciole$",
}, "0.6", "0.6")

-- Terminals opened from Luciole share its floating geometry.
centered_float("luciole-terminal", {
  class = LUCIOLE_TERMINAL_CLASS,
}, "0.7", "0.7")

-- === Generic dialogs ===

-- File selection, downloads and file operations.
centered_float(nil, {
  title = "^(Open File|Select a File|Choose wallpaper|Open Folder|Save As|Library|File Upload|.*Save File.*|.*Save Folder.*|.*Save Image.*|.*Open As.*|.*Open Network Stream.*|.*Choose Files.*|.*Downloads -.*|File Operation Progress|Downloads.*|Choose Directory|Where do you want to save the.*)$",
}, "0.55", "0.55")

-- Confirmation, warning and error dialogs take priority over file-dialog sizing.
centered_float(nil, {
  title = "^(.*File Already Exists.*|.*Confirm to replace files.*|.*Confirm to delete files.*|Rename.*|Delete.*|Move to Trash.*|.*Confirmation.*|.*Warning.*|.*Error.*)$",
}, "0.2", "0.15")

centered_float(nil, {
  title = "^(Pick a Font)$",
}, "0.4", "0.4")

-- === Application geometry ===

-- Download manager: main window and preview dialog.
hl.window_rule({
  match = { title = "^(qBittorrent.*)$", class = QB_CLASS },
  size = { "monitor_w*0.7", "monitor_h*0.7" },
})
hl.window_rule({
  match = { title = "^(Preview selection)$", class = QB_CLASS },
  size = { "monitor_w*0.4", "monitor_h*0.9" },
})

-- Image viewer overrides its large floating preset.
centered_float(nil, {
  class = "^(imv)$",
}, "0.6", "0.6")

-- Editors.
centered_float(nil, {
  class = "^(dev\\.zed\\.Zed)$",
  title = "^(Zed — Settings)",
}, "0.7", "0.7")

centered_float("obsidian-main", {
  class = OBSIDIAN_CLASS_PATTERN,
  initial_title = "negative:^Settings - Obsidian.*$",
}, "0.8", "0.8")

centered_float("obsidian-settings", {
  class = OBSIDIAN_CLASS_PATTERN,
  initial_title = "^Settings - Obsidian.*$",
}, "0.6", "0.65")

-- System utilities.
centered_float(nil, {
  title = "^(.*GParted)$",
}, "0.6", "0.55")

centered_float(nil, {
  class = "^(btrfs-assistant)$",
  initial_title = "^(Btrfs Assistant( \\(read-only\\))?|Diff Viewer)$",
}, "0.7", "0.7")

centered_float(nil, {
  class = "^(io\\.missioncenter\\.MissionCenter)$",
}, "0.75", "0.75")

centered_float("noctalia-settings", {
  class = "^dev\\.noctalia\\.Noctalia$",
}, "0.5625", "0.85")

-- Named terminal windows opened by dotfiles helpers.
centered_float(nil, {
  initial_title = "^(FloatingTerm|Yazi|System Update|btop)$",
}, "0.8", "0.8")

-- === Authentication and password managers ===

-- Polkit agents, pinentry and GCR prompts stay focused and centered.
hl.window_rule({
  match = {
    class = "^(polkit-gnome-authentication-agent-1|polkit-kde-authentication-agent-1|hyprpolkitagent|pinentry.*|gcr-prompter)$",
  },
  float = true,
  center = true,
  pin = true,
  stay_focused = true,
})

-- Authentication prompts stay out of screen sharing.
hl.window_rule({
  match = {
    class = "^(polkit-.*|pinentry.*)$",
    title = "^([Aa]uthenticate)$",
  },
  no_screen_share = true,
})

-- Bitwarden's browser popup.
centered_float(nil, {
  class = "^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$",
}, "0.3", "0.6")
hl.window_rule({
  match = {
    class = "^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$",
  },
  no_screen_share = true,
})

-- Brave sign-in and task-manager windows.
centered_float(nil, {
  class = BRAVE_CLASS_PATTERN,
  initial_title = "^(Sign in - Google Accounts - Brave|PayPal - Brave)$",
}, "0.3", "0.7")

centered_float(nil, {
  initial_title = "^(Task Manager - Brave)$",
}, "0.7", "0.7")

-- === Overlays and compatibility ===

-- Invisible XWayland drag helper.
hl.window_rule({
  name = "fix-xwayland-drags",
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

-- Screen-sharing picker.
hl.window_rule({
  match = { class = "^(hyprland-share-picker)$" },
  float = true,
  center = true,
  pin = true,
  size = { "monitor_w*0.4", "monitor_h*0.5" },
})

-- Picture-in-picture keeps its aspect ratio and position.
hl.window_rule({
  match = {
    title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$",
  },
  float = true,
  keep_aspect_ratio = true,
  move = { "monitor_w*0.73", "monitor_h*0.72" },
  size = { "monitor_w*0.25", "monitor_w*0.25" },
  pin = true,
})

-- === Dynamic behavior ===

-- Initial-title rules cannot catch sign-in popups that start as Untitled.
-- Only windows that were *created* as a popup (initial title "Untitled - Brave") are
-- floated. A sign-in page opened in the same tab changes the main window's
-- title too, but that window never started as "Untitled", so it stays tiled.
local BRAVE_SIGN_IN_TITLES = {
  ["Sign in - Google Accounts - Brave"] = true,
  ["PayPal - Brave"] = true,
}
-- Brave appends its name, so popups start as "Untitled - Brave".
local BRAVE_POPUP_INITIAL_TITLE_PATTERN = "^Untitled"

local function float_brave_sign_in(window)
  if not window or window.floating then return end
  if not BRAVE_CLASSES[window.class] then return end
  if not BRAVE_SIGN_IN_TITLES[window.title] then return end

  local initial_title = window.initial_title or window.initialTitle
  if type(initial_title) ~= "string" then return end
  if not initial_title:find(BRAVE_POPUP_INITIAL_TITLE_PATTERN) then return end

  H.float_window_centered(window, 0.3, 0.7)
end

hl.on("window.title", float_brave_sign_in)

-- Reapply dynamic behavior to existing windows after configuration reload.
hl.on("config.reloaded", function()
  for _, window in ipairs(hl.get_windows() or {}) do
    float_brave_sign_in(window)
  end
end)
