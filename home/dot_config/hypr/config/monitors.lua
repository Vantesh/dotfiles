local monitors = { external = "desc:Dell Inc. DELL P2425H 2RHZH14", laptop = "eDP-1" }

-- Fallback for outputs without a specific monitor rule.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Automatically place the external display to the left and the laptop display to the right.
hl.monitor({ output = monitors.external, mode = "highres", position = "auto-left", scale = 1 })
hl.monitor({ output = monitors.laptop, mode = "preferred", position = "auto-right", scale = 1 })

return monitors
