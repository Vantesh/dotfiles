-- Local border colors, retained from the previous DMS Matugen palette.
-- Remove require("config.colors") from hyprland.lua to override.

hl.config({
	general = {
		col = {
			active_border = "rgb(f0bf6d)",
			inactive_border = "rgb(9b8f80)",
		},
	},
	group = {
		col = {
			border_active = "rgb(f0bf6d)",
			border_inactive = "rgb(9b8f80)",
			border_locked_active = "rgb(ffb4ab)",
			border_locked_inactive = "rgb(9b8f80)",
		},
		groupbar = {
			col = {
				active = "rgb(f0bf6d)",
				inactive = "rgb(9b8f80)",
				locked_active = "rgb(ffb4ab)",
				locked_inactive = "rgb(9b8f80)",
			},
		},
	},
})
