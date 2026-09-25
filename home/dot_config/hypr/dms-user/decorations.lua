hl.config({

  general = {
    gaps_in = 5,
    gaps_out = 5,
    border_size = 2,
    layout = "dwindle",
  },
  decoration = {

    rounding = 12,
    active_opacity = 0.9,
    inactive_opacity = 0.9,
    fullscreen_opacity = 1.0,

    dim_inactive = true,
    dim_strength = 0.035,
    dim_special = 0.07,


    blur = {
      enabled = true,
      special = false,
      xray = false,
      size = 10,
      passes = 4,
      brightness = 1,
      popups = true,
      popups_ignorealpha = 0.6
    },
    shadow = {
      enabled = false
    },
  },

})
