hl.config({
  general = {
    layout = "dwindle",
    gaps_in = 5,
    gaps_out = 5,
    border_size = 2,
    allow_tearing = true,
    no_focus_fallback = true,
    resize_on_border = true,

    snap = {
      enabled = true,

    },
  }


})


-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
  dwindle = {
    preserve_split = true, -- You probably want this
  },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
  master = {
    new_status = "master",
  },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
  scrolling = {
    fullscreen_on_one_column = true,
  },
})
