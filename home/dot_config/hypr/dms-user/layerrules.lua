-- Layer rules — https://wiki.hypr.land/configuring/core/rules/layer-rules/

hl.layer_rule({ match = { namespace = "^(hyprpicker|logout_dialog|selection)$" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "^(quickshell.*|dms.*)$" }, blur = true, ignore_alpha = 0.65, blur_popups = true, no_anim = true })
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true, ignore_alpha = 0.0 })
