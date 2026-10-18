-- Window rules — https://wiki.hypr.land/configuring/core/rules/window-rules/
-- Broad defaults come first; later rules override individual properties.

-- Full-width scrolling columns on the laptop; floating geometry is unaffected.
hl.window_rule({
  name = "laptop-scrolling-width",
  match = { workspace = "10" },
  scrolling_width = 1.0,
})

-- === Simple behavior and appearance ===
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "no-shadow-tiled", match = { float = false }, no_shadow = true })
hl.window_rule({ match = { float = true, xwayland = false }, center = true })
-- Keep special-workspace borders under workspace-rule control.
hl.window_rule({ match = { float = false, workspace = "s[false]w[tv1]" }, border_size = 2 })
hl.window_rule({ match = { xwayland = true, title = "^(win[0-9]+)$" }, no_dim = true, no_shadow = true, rounding = 10 })

-- Tearing for matching game windows.
hl.window_rule({ name = "immediate-wine-exe", match = { title = ".*\\.exe" }, immediate = true })
hl.window_rule({ name = "immediate-minecraft", match = { title = ".*minecraft.*" }, immediate = true })
hl.window_rule({ name = "immediate-steam-app", match = { class = "^(steam_app_.*)$" }, immediate = true })

-- Simple application floating rules; geometry exceptions follow below.
hl.window_rule({ match = { class = "^(vlc)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(scrcpy)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(org\\.qbittorrent\\.qBittorrent)$" }, float = true })
hl.window_rule({ match = { title = "^(About Mozilla Firefox)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.kdialog)$", title = "^(mpv playlist|Select Files)$" }, float = true })

-- === Opacity ===
hl.window_rule({
  name = "tag-opaque",
  match = { class = "^(foot|equibop|imv|[Bb]rave(-browser)?|mpv|vlc|celluloid|zoom|org\\.kde\\.kdenlive|com\\.obsproject\\.Studio|com\\.github\\.PintaProject\\.Pinta|org\\.gnome\\.NautilusPreviewer)$" },
  tag = "+opaque",
})
hl.window_rule({ name = "fx-opaque", match = { tag = "opaque" }, opaque = true })
hl.window_rule({ match = { title = ".*(YouTube).*" }, opacity = "1.0 override" })

-- === Idle inhibition ===
hl.window_rule({ name = "tag-idle-media", match = { class = "^(celluloid|mpv|vlc|[Ss]potify|[Ss]potifast|[Ss]poticast)$" }, tag = "+idle-media" })
hl.window_rule({
  name = "tag-idle-browser",
  match = { class = "^([Ll]ibre[Ww]olf|floorp|[Bb]rave(-browser)?|firefox|chromium|zen|vivaldi)$" },
  tag = "+idle-browser",
})
hl.window_rule({ name = "fx-idle-media", match = { tag = "idle-media" }, idle_inhibit = "focus" })
hl.window_rule({ name = "fx-idle-browser", match = { tag = "idle-browser" }, idle_inhibit = "fullscreen" })

-- === Screen-sharing privacy ===
hl.window_rule({
  name = "tag-private",
  match = { class = "^(discord|vesktop|org\\.telegram\\.desktop|[Ss]ignal|[Ww]hats[Aa]pp|[Bb]itwarden)$" },
  tag = "+private",
})
hl.window_rule({ name = "fx-private", match = { tag = "private" }, no_screen_share = true })
hl.window_rule({ match = { class = "^(polkit-.*|pinentry.*)$", title = "^([Aa]uthenticate)$" }, no_screen_share = true })

-- === Floating presets ===
-- Tag producers precede their effects. Media players share the large preset.
hl.window_rule({
  name = "tag-float-large",
  match = { class = "^(auto-cpufreq-gtk|center-float-large|qimgv|nvidia-settings|localsend|org\\.localsend\\.localsend_app|org\\.gnome\\.Evince|mpv|celluloid|com\\.github\\.rafostar\\.Clapper)$" },
  tag = "+float-large",
})
hl.window_rule({ name = "fx-float-large", match = { tag = "float-large" }, float = true, center = true, size = { "monitor_w*0.7", "monitor_h*0.7" } })
hl.window_rule({
  name = "tag-float-medium",
  match = { class = "^(center-float|xdg-desktop-portal-gtk|selectdefaultapplication)$" },
  tag = "+float-medium",
})
hl.window_rule({ name = "fx-float-medium", match = { tag = "float-medium" }, float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.5" } })
hl.window_rule({
  name = "tag-float-small",
  match = { class = "^(center-float-mini|galculator|ytdlp-gui|udiskie|Calculator)$" },
  tag = "+float-small",
})
hl.window_rule({ name = "fx-float-small", match = { tag = "float-small" }, float = true, center = true, size = { "monitor_w*0.3", "monitor_h*0.4" } })

-- No application-specific size or position.
hl.window_rule({
  name = "tag-float-plain",
  match = { class = "^(kvantummanager|qt5ct|qt6ct|nwg-look|org\\.kde\\.ark|[Ss]ignal|app\\.drey\\.[Ww]arp|net\\.davidotek\\.pupgui2|yad|io\\.github\\.alainm23\\.planify|io\\.gitlab\\.theevilskeleton\\.Upscaler|com\\.github\\.unrud\\.VideoDownloader|io\\.gitlab\\.adhami3310\\.Impression)$" },
  tag = "+float-plain",
})
hl.window_rule({ name = "fx-float-plain", match = { tag = "float-plain" }, float = true })

-- === Generic dialogs ===
-- File selection, downloads, and file operations.
hl.window_rule({
  match = { title = "^(Open File|Select a File|Choose wallpaper|Open Folder|Save As|Library|File Upload|.*Save File.*|.*Save Folder.*|.*Save Image.*|.*Open As.*|.*Open Network Stream.*|.*Choose Files.*|.*Downloads -.*|File Operation Progress|Downloads.*|Choose Directory|Where do you want to save the.*)$" },
  float = true,
  center = true,
  size = { "monitor_w*0.55", "monitor_h*0.55" },
})
-- Confirmation, warning, and error dialogs take priority over file-dialog sizing.
hl.window_rule({
  match = { title = "^(.*File Already Exists.*|.*Confirm to replace files.*|.*Confirm to delete files.*|Rename.*|Delete.*|Move to Trash.*|.*Confirmation.*|.*Warning.*|.*Error.*)$" },
  float = true,
  center = true,
  size = { "monitor_w*0.2", "monitor_h*0.15" },
})
hl.window_rule({ match = { title = "^(Pick a Font)$" }, float = true, center = true, size = { "monitor_w*0.4", "monitor_h*0.4" } })

-- === Application geometry ===
-- VLC: broad main-window sizing before the smaller dialog exceptions.
hl.window_rule({ match = { title = "^(.*VLC media player)$", class = "^(vlc)$" }, size = { "monitor_w*0.7", "monitor_h*0.7" } })
hl.window_rule({
  match = { class = "^(vlc)$", title = "^(Select one or more files to open|Simple Preferences|Adjustments and Effects|Current Media Information|Open URL|Open Media|Save playlist as\\.\\.\\.|Open Directory) — VLC media player$" },
  size = { "monitor_w*0.5", "monitor_h*0.5" },
})
hl.window_rule({ match = { class = "^(org\\.kde\\.kdialog)$", title = "^(Select Files)$" }, size = { "monitor_w*0.5", "monitor_h*0.5" } })

-- qBittorrent main window and preview dialog.
hl.window_rule({ match = { title = "^(qBittorrent.*)$", class = "^(org\\.qbittorrent\\.qBittorrent)$" }, size = { "monitor_w*0.7", "monitor_h*0.7" } })
hl.window_rule({ match = { title = "^(Preview selection)$", class = "^(org\\.qbittorrent\\.qBittorrent)$" }, size = { "monitor_w*0.4", "monitor_h*0.9" } })

-- Editors and file managers.
hl.window_rule({ match = { class = "^(dev\\.zed\\.Zed)$", title = "^(Zed — Settings)" }, float = true, center = true, size = { "monitor_w*0.7", "monitor_h*0.7" } })
hl.window_rule({
  name = "obsidian-main",
  match = { class = "^([Oo]bsidian|md\\.obsidian\\.Obsidian)$", initial_title = "negative:^Settings - Obsidian.*$" },
  float = true,
  center = true,
  size = { "monitor_w*0.8", "monitor_h*0.8" },
})
hl.window_rule({
  name = "obsidian-settings",
  match = { class = "^([Oo]bsidian|md\\.obsidian\\.Obsidian)$", initial_title = "^Settings - Obsidian.*$" },
  float = true,
  center = true,
  size = { "monitor_w*0.6", "monitor_h*0.65" },
})
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus)$", initial_title = "^(Loading…|Home)$" }, float = true, center = true, size = { "monitor_w*0.8", "monitor_h*0.8" } })

-- Desktop utilities and named terminal windows.
hl.window_rule({ match = { title = "^(.*GParted)$" }, float = true, center = true, size = { "monitor_w*0.6", "monitor_h*0.55" } })
hl.window_rule({ match = { class = "^(btrfs-assistant)$", initial_title = "^(Btrfs Assistant( \\(read-only\\))?|Diff Viewer)$" }, float = true, center = true, size = { "monitor_w*0.7", "monitor_h*0.7" } })
hl.window_rule({ match = { class = "^(imv)$" }, float = true, center = true, size = { "monitor_w*0.6", "monitor_h*0.6" } })
hl.window_rule({ match = { class = "^(io\\.missioncenter\\.MissionCenter)$" }, float = true, center = true, size = { "monitor_w*0.75", "monitor_h*0.75" } })
hl.window_rule({ match = { initial_title = "^(FloatingTerm|Yazi|System Update)$" }, float = true, center = true, size = { "monitor_w*0.8", "monitor_h*0.8" } })
hl.window_rule({
  name = "noctalia-settings",
  match = { class = "^dev\\.noctalia\\.Noctalia$" },
  float = true,
  center = true,
  size = { 1080, 920 },
})

-- === Authentication and password-manager windows ===
hl.window_rule({
  match = { class = "^(polkit-gnome-authentication-agent-1|polkit-kde-authentication-agent-1|hyprpolkitagent|pinentry.*|gcr-prompter)$" },
  float = true,
  center = true,
  pin = true,
  stay_focused = true,
})
-- Bitwarden privacy comes from the private tag; its browser popup has a separate class.
hl.window_rule({ match = { class = "^([Bb]itwarden)$" }, float = true, center = true, size = { "monitor_w*0.6", "monitor_h*0.6" } })
hl.window_rule({ match = { class = "^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$" }, float = true, center = true, size = { "monitor_w*0.3", "monitor_h*0.6" }, no_screen_share = true })
hl.window_rule({ match = { class = "^(1[Pp]assword)$" }, float = true, center = true, size = { "monitor_w*0.6", "monitor_h*0.6" } })
hl.window_rule({ match = { class = "^([Bb]rave(-browser)?)$", initial_title = "^(Sign in - Google Accounts - Brave|PayPal - Brave)$" }, float = true, center = true, size = { "monitor_w*0.3", "monitor_h*0.7" } })
hl.window_rule({ match = { initial_title = "^(Task Manager - Brave)$" }, float = true, center = true, size = { "monitor_w*0.7", "monitor_h*0.7" } })

-- === Overlays and compatibility exceptions ===
hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})
hl.window_rule({
  match = { class = "^(xwaylandvideobridge)$" },
  opacity = "0.0 override 0.0 override",
  no_anim = true,
  no_blur = true,
  no_initial_focus = true,
  max_size = { 1, 1 },
})
hl.window_rule({ match = { class = "^(hyprland-share-picker)$" }, float = true, center = true, pin = true, size = { 600, 400 } })
-- Explicit positioning takes priority over general floating-window centering.
hl.window_rule({
  match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
  float = true,
  keep_aspect_ratio = true,
  move = { "monitor_w*0.73", "monitor_h*0.72" },
  size = { "monitor_w*0.25", "monitor_w*0.25" },
  pin = true,
})

-- === Dynamic behavior ===
-- Sign-in windows can start as Untitled; initial-title rules cannot catch later title changes.
local function float_brave_sign_in(window)
  if not window or window.floating then return end
  if not (window.class == "brave-browser" or window.class == "Brave-browser"
    or window.class == "brave" or window.class == "Brave") then return end
  if window.title ~= "Sign in - Google Accounts - Brave"
    and window.title ~= "PayPal - Brave" then return end

  hl.dispatch(hl.dsp.window.float({ window = window, action = "enable" }))
  local monitor = window.monitor
  if monitor and monitor.scale > 0 then
    hl.dispatch(hl.dsp.window.resize({
      window = window,
      x = math.floor(monitor.width / monitor.scale * 0.3),
      y = math.floor(monitor.height / monitor.scale * 0.7),
      relative = false,
    }))
  end
  hl.dispatch(hl.dsp.window.center({ window = window }))
end

hl.on("window.title", float_brave_sign_in)
hl.on("config.reloaded", function()
  for _, window in ipairs(hl.get_windows() or {}) do
    float_brave_sign_in(window)
  end
end)
