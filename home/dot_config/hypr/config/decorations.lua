hl.config({

  decoration = {
    rounding = 12,
    active_opacity = 0.9,
    inactive_opacity = 0.9,
    fullscreen_opacity = 1.0,

    dim_inactive = true,
    dim_strength = 0.035,
    dim_special = 0.07,


    blur = {
      enabled            = true,
      special            = false,
      xray               = false,
      size               = 8,
      passes             = 4,
      popups             = true,
      popups_ignorealpha = 0.6,
      noise              = 0.05,
      input_methods      = true



    },
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "0xee1a1a1a",
    },

  },

})
