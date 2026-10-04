local monitors = { external = "DP-1", laptop = "eDP-1" }

-- Keep unknown outputs usable, but place the Dell to the left of the laptop.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = monitors.external, mode = "1920x1080@100", position = "0x0", scale = 1 })
hl.monitor({ output = monitors.laptop, mode = "preferred", position = "auto-right", scale = 1 })

return monitors
