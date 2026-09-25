hl.config({
  input = {
    -- empty inherits XKB_DEFAULT_LAYOUT (libxkbcommon), falls back to "us"
    kb_layout = "",
    numlock_by_default = true,
    follow_mouse = 1,
    sensitivity = 0.4,
    touchpad = {
      tap_to_click = true,
      natural_scroll = true,
      disable_while_typing = true
    },
  },

})
