--[[ ================================================================
  windowrules.lua — Hyprland 0.55+ Lua config (hl.window_rule / hl.workspace_rule)

  Load from ~/.config/hypr/hyprland.lua with:
      require("windowrules")

  HOW TO ADD OR FIX AN APP
  -------------------------------------------------------------------
  Almost everything you'll ever want to change lives in the
  "APP REGISTRY" section below: plain Lua arrays of window classes,
  grouped by what should happen to them. To add an app to a group,
  add one string to its list. To find the right string:

      hyprctl clients          -- while the app is open, look at
                                    `class` (and `initialClass`)
      hyprctl activewindow      -- same, just for the focused window

  If `class` is blank, match on `title` / `initial_title` instead
  (see the "picture-in-picture" and dialog rules further down for
  examples of title-based matching).

  Every list below is matched case-insensitively (see ci() below),
  so "Bitwarden" vs "bitwarden" style renames from upstream no
  longer silently break the rule. Renames that change the class
  *string itself* (not just casing) — e.g. LocalSend moving from
  "localsend" to "org.localsend.localsend_app" — still need a real
  fix, which is why some entries below are a small `{ "old", "new" }`
  list instead of a single string: keeping both means the rule
  survives whichever version of the app the user has installed.
================================================================ ]]

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------

-- Shallow-merge any number of tables, later ones winning.
local function merge(...)
  local out = {}
  for _, t in ipairs({ ... }) do
    for k, v in pairs(t) do out[k] = v end
  end
  return out
end

-- RE2 (what Hyprland uses for match regex) supports inline flags;
-- (?i) makes the whole pattern case-insensitive.
local function ci(pattern)
  return "(?i)" .. pattern
end

-- Registry entries are usually a single class/title string, but can
-- also be a small array of aliases (e.g. an app's old and new class
-- name). This flattens both shapes into one list of plain strings.
local function flatten(list)
  local out = {}
  for _, item in ipairs(list) do
    if type(item) == "table" then
      for _, alias in ipairs(item) do out[#out + 1] = alias end
    else
      out[#out + 1] = item
    end
  end
  return out
end

-- Build a case-insensitive "^(a|b|c)$" alternation from a registry list.
local function alt(list)
  return ci("^(" .. table.concat(flatten(list), "|") .. ")$")
end

-- {"monitor_w*0.7", "monitor_h*0.7"} for the `size`/`move` effects.
local function pct(w_pct, h_pct)
  return { ("monitor_w*%s"):format(w_pct), ("monitor_h*%s"):format(h_pct) }
end

-- float + centered + sized as a percentage of the screen — the most
-- common pattern in this file.
local function floatbox(w_pct, h_pct, extra)
  return merge({ float = true, center = true, size = pct(w_pct, h_pct) }, extra or {})
end

local function wrule(name, match, ...)
  hl.window_rule(merge({ name = name, match = match }, ...))
end

-- ---------------------------------------------------------------
-- APP REGISTRY — edit these lists to add/remove/fix apps
-- ---------------------------------------------------------------

-- Brave's WM class isn't consistent across install methods (native
-- deb/rpm vs. flatpak vs. snap all report differently) — keep both
-- known values so the rules survive whichever one your install uses.
-- Run `hyprctl clients` with Brave open to see which one applies to
-- you, and trim this list down if you like.
local brave_classes = { "brave-browser", "brave" }

local idle_inhibit_media_classes = { "celluloid", "mpv", "vlc", "spotify" }
local idle_inhibit_browser_classes = { "librewolf", "floorp", brave_classes, "firefox", "chromium", "zen", "vivaldi" }

-- Windows that should be allowed to tear, keyed by which field they
-- match on. `pattern` is matched as-is (no auto ^(...)$ wrapping)
-- since these aren't simple class alternations.
local tearing_rules = {
  { name = "immediate-wine-exe",  field = "title", pattern = ci(".*\\.exe") },
  { name = "immediate-minecraft", field = "title", pattern = ci(".*minecraft.*") },
  -- Real Steam game windows are "steam_app_<appid>", not literally
  -- "steam_app" — the un-suffixed pattern never matched anything.
  { name = "immediate-steam-app", field = "class", pattern = ci("^(steam_app_.*)$") },
}

local opaque_classes = { "foot", "equibop", "imv", "swappy", brave_classes, "mpv", "vlc", "celluloid" }

local size_categories = {
  {
    name = "float-large",
    w = 0.7,
    h = 0.7,
    classes = {
      "center-float-large", "qimgv", "nvidia-settings",
      { "localsend", "org.localsend.localsend_app" }, -- renamed upstream
      "org.gnome.evince",
    },
  },
  {
    name = "float-medium",
    w = 0.5,
    h = 0.5,
    classes = { "center-float", "xdg-desktop-portal-gtk", "selectdefaultapplication" },
  },
  {
    name = "float-small",
    w = 0.3,
    h = 0.4,
    classes = { "center-float-mini", "galculator", "ytdlp-gui", "udiskie", "calculator" },
  },
}

local media_players_large_classes = { "mpv", "celluloid", "com.github.rafostar.clapper" }

-- Messaging / auth apps to hide from screen sharing.
-- NOTE: unofficial WhatsApp clients (there is no official Linux app)
-- use all sorts of classes — check `hyprctl clients` if this misses.
local no_screenshare_classes = { "discord", "vesktop", "org.telegram.desktop", "signal", "whatsapp", "bitwarden" }

local theming_app_classes = { "kvantummanager", "qt5ct", "qt6ct", "nwg-look", "org.kde.ark" }
local network_tool_classes = { "blueman-manager", "nm-applet", "nm-connection-editor", "signal", "app.drey.warp",
  "net.davidotek.pupgui2", "yad" }
local planify_upscaler_classes = { "io.github.alainm23.planify", "io.gitlab.theevilskeleton.upscaler" }
local video_tool_classes = { "com.github.unrud.videodownloader", "io.gitlab.adhami3310.impression" }

-- ---------------------------------------------------------------
-- SYSTEM BEHAVIOR
-- ---------------------------------------------------------------

wrule("idle-inhibit-media", { class = alt(idle_inhibit_media_classes) }, { idle_inhibit = "focus" })
wrule("idle-inhibit-fullscreen-browsers", { class = alt(idle_inhibit_browser_classes) }, { idle_inhibit = "fullscreen" })

for _, r in ipairs(tearing_rules) do
  wrule(r.name, { [r.field] = r.pattern }, { immediate = true })
end

-- Visual optimizations
wrule("no-shadow-tiled", { float = false }, { no_shadow = true })
wrule("center-float-wayland", { float = true, xwayland = false }, { center = true })
wrule("opaque-media-and-tools", { class = alt(opaque_classes) }, { opaque = true })

-- Good practices
wrule("no-focus-ghost-xwayland",
  { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  { no_focus = true })
wrule("suppress-maximize", { class = ".*" }, { suppress_event = "maximize" })

-- ---------------------------------------------------------------
-- PICTURE-IN-PICTURE
-- ---------------------------------------------------------------

-- NOTE on `size`: the original hyprlang rule only ever specified ONE
-- dimension ("size = (monitor_w*0.25)"), relying on keep_aspect_ratio
-- to fill in the other. Hyprland's Lua `size` effect wants a {w, h}
-- pair, so this keeps the same 25%-of-screen-width intent; adjust the
-- height expression below if you had a specific aspect ratio in mind.
wrule("picture-in-picture",
  { title = ci("^(picture[- ]?in[- ]?picture)(.*)$") },
  {
    float = true,
    keep_aspect_ratio = true,
    move = { "monitor_w*0.73", "monitor_h*0.72" },
    size = { "monitor_w*0.25", "monitor_w*0.25" },
    pin = true,
  })

-- ---------------------------------------------------------------
-- FILE DIALOGS
-- ---------------------------------------------------------------

wrule("file-dialog-large",
  {
    title = ci(
      "^(open file|select a file|choose wallpaper|open folder|save as|library|file upload|.*save file.*|.*save folder.*|.*save image.*|.*open as.*|.*open network stream.*|.*choose files.*|.*downloads -.*|file operation progress|downloads.*|choose directory|where do you want to save the.*)$")
  },
  floatbox(0.55, 0.55))

wrule("dms", { title = ci("^(settings|system monitor)$") }, floatbox(0.75, 0.85))

wrule("confirmation-dialog-small",
  {
    title = ci(
      "^(.*file already exists.*|.*confirm to replace files.*|.*confirm to delete files.*|rename.*|delete.*|move to trash.*|.*confirmation.*|.*warning.*|.*error.*)$")
  },
  floatbox(0.2, 0.15))

-- ---------------------------------------------------------------
-- FLOATING WINDOW SIZE CATEGORIES
-- ---------------------------------------------------------------

for _, c in ipairs(size_categories) do
  wrule(c.name, { class = alt(c.classes) }, floatbox(c.w, c.h))
end

wrule("float-font-picker", { title = ci("^(pick a font)$") }, { float = true, size = pct(0.4, 0.4) })

-- ---------------------------------------------------------------
-- MEDIA PLAYERS
-- ---------------------------------------------------------------

wrule("vlc-main-float", { class = ci("^(vlc)$") }, { float = true, center = true })

wrule("vlc-dialogs",
  {
    title = ci(
      "^(select one or more files to open|simple preferences|adjustments and effects|current media information|open url|open media|save playlist as\\.\\.\\.|open directory) — vlc media player$")
  },
  { size = pct(0.5, 0.5) })

wrule("vlc-main-size", { title = ci("^(.*vlc media player)$"), class = ci("^(vlc)$") }, { size = pct(0.7, 0.7) })

wrule("media-players-large", { class = alt(media_players_large_classes) }, floatbox(0.7, 0.7))

wrule("mpv-playlist-float",
  { class = ci("^(org.kde.kdialog)$"), title = ci("^(mpv playlist|select files)$") },
  { float = true })

wrule("mpv-playlist-size",
  { class = ci("^(org.kde.kdialog)$"), title = ci("^(select files)$") },
  { size = pct(0.5, 0.5) })

wrule("youtube-opaque", { title = ci(".*(youtube).*") }, { opacity = "1.0 override" })

-- ---------------------------------------------------------------
-- AUTHENTICATION & SECURITY
-- ---------------------------------------------------------------

wrule("polkit-auth-dialog",
  {
    class = ci(
      "^(polkit-gnome-authentication-agent-1|polkit-kde-authentication-agent-1|hyprpolkitagent|pinentry.*|gcr-prompter)$")
  },
  { float = true, pin = true, stay_focused = true })

wrule("dms-polkit",
  { class = ci("^(com.danklinux.dms)$"), title = ci("^(authentication)$") },
  { float = true, pin = true, stay_focused = true })

wrule("no-screenshare-messengers", { class = alt(no_screenshare_classes) }, { no_screen_share = true })
wrule("no-screenshare-pinentry", { class = ci("^(polkit-.*|pinentry.*)$"), title = ci("^(authenticate)$") },
  { no_screen_share = true })

-- Password managers
wrule("bitwarden-float", { class = ci("^(bitwarden)$") }, floatbox(0.6, 0.6, { no_screen_share = true }))

wrule("bitwarden-extension-popup",
  { class = "^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$" }, -- extension id, not case-varying
  { float = true, size = pct(0.3, 0.6), no_screen_share = true })

wrule("onepassword-float", { class = ci("^(1password)$") }, floatbox(0.6, 0.6))

-- Brave browser popups
wrule("brave-popups",
  { class = alt(brave_classes), initial_title = ci("^(untitled - brave|paypal - brave)$") },
  floatbox(0.3, 0.7))

wrule("brave-task-manager", { initial_title = ci("^(task manager - brave)$") }, floatbox(0.7, 0.7))

-- ---------------------------------------------------------------
-- APPLICATION-SPECIFIC RULES
-- ---------------------------------------------------------------

wrule("audio-scratchpad", { class = ci("^(pavucontrol|blueman-manager|pwvucontrol)$") }, floatbox(0.4, 0.4))

wrule("nautilus-float",
  { class = ci("^(org.gnome.nautilus)$"), initial_title = ci("^(loading…|home)$") },
  floatbox(0.8, 0.8))

wrule("xwayland-video-bridge",
  { class = ci("^(xwaylandvideobridge)$") },
  {
    opacity = "0.0 override 0.0 override",
    no_anim = true,
    no_blur = true,
    no_initial_focus = true,
    max_size = { 1, 1 },
  })

wrule("hyprland-share-picker", { class = ci("^(hyprland-share-picker)$") },
  { float = true, pin = true, center = true, size = { 600, 400 } })

wrule("scrcpy-float", { class = ci("^(scrcpy)$") }, { float = true, center = true })

-- qBittorrent
wrule("qbittorrent-float", { class = ci("^(org.qbittorrent.qbittorrent)$") }, { float = true })
wrule("qbittorrent-main-size", { title = ci("^(qbittorrent.*)$"), class = ci("^(org.qbittorrent.qbittorrent)$") },
  { size = pct(0.7, 0.7) })
wrule("qbittorrent-preview-size", { title = ci("^(preview selection)$"), class = ci("^(org.qbittorrent.qbittorrent)$") },
  { size = pct(0.4, 0.9) })

wrule("overskride-float", { class = ci("^(overskride)$") }, { float = true, size = pct(0.3, 0.8) })

wrule("gparted-float", { title = ci("^(.*gparted)$") }, floatbox(0.6, 0.55))

wrule("btrfs-assistant-float",
  { class = ci("^(btrfs-assistant)$"), initial_title = ci("^(btrfs assistant|diff viewer)$") },
  floatbox(0.7, 0.7))

wrule("clipse-float", { class = ci("^(clipse-gui)$") }, floatbox(0.35, 0.45, { stay_focused = true }))

wrule("imv-float", { class = ci("^(imv)$") }, floatbox(0.6, 0.6, { opaque = true }))

wrule("wallpaper-manager-float", { class = ci("^(waypaper|org.waytrogen.waytrogen)$") }, floatbox(0.55, 0.7))

wrule("swww-advanced-float", { title = ci("^(swww advanced image settings)$") }, { float = true })

wrule("missioncenter-float", { class = ci("^(io.missioncenter.missioncenter)$") }, floatbox(0.75, 0.75))

-- "just float, no sizing" apps — one effect shared by several classes.
wrule("theming-apps-float", { class = alt(theming_app_classes) }, { float = true })
wrule("misc-float-network-tools", { class = alt(network_tool_classes) }, { float = true })
wrule("misc-float-planify-upscaler", { class = alt(planify_upscaler_classes) }, { float = true })
wrule("misc-float-video-tools", { class = alt(video_tool_classes) }, { float = true })

wrule("floating-terminal", { class = ci("^(floatingterm)$") }, floatbox(0.8, 0.8))

wrule("firefox-about-float", { title = ci("^(about mozilla firefox)$") }, { float = true })
wrule("firefox-library-float", { class = ci("^(firefox)$"), title = ci("^(library)$") }, { float = true })

wrule("xwayland-popups", { xwayland = true, title = "^(win[0-9]+)$" }, { no_dim = true, no_shadow = true, rounding = 10 })

-- ---------------------------------------------------------------
-- ANIMATIONS
-- ---------------------------------------------------------------

wrule("cava-slide", { title = ci(".*cava.*") }, { animation = "slide" })
wrule("wleave-popin", { class = ci("^(wleave)$") }, { animation = "popin" })

-- ---------------------------------------------------------------
-- WORKSPACE RULES
-- ---------------------------------------------------------------

-- Smart gaps — remove gaps for tiled windows on the tiled-only workspace.
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
wrule("workspace-tv1-border", { float = false, workspace = "w[tv1]" }, { border_size = 2 })

-- Special "exposed" workspace (e.g. an overview/expose scratchpad).
hl.workspace_rule({
  workspace   = "special:exposed",
  gaps_out    = 60,
  gaps_in     = 30,
  border_size = 5,
  no_shadow   = true,
})
