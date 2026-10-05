local monitors = { external = "DP-1", laptop = "eDP-1" }

-- Keep unknown outputs usable and automatically place the external display to the left.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = monitors.external, mode = "highres", position = "auto-left", scale = 1 })
hl.monitor({ output = monitors.laptop, mode = "preferred", position = "auto-right", scale = 1 })

return monitors
