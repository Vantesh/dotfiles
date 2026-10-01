local M        = {}

local MIN_ZOOM = 1
local MAX_ZOOM = 10
local STEP_IN  = 1.1
local STEP_OUT = 1 / STEP_IN

local function set_zoom(value)
    value = math.max(MIN_ZOOM, math.min(MAX_ZOOM, value))
    value = math.floor(value * 100 + 0.5) / 100
    hl.config({ cursor = { zoom_factor = value } })
end

function M.zoom_in()
    local current = hl.get_config("cursor.zoom_factor") or MIN_ZOOM
    set_zoom(current * STEP_IN)
end

function M.zoom_out()
    local current = hl.get_config("cursor.zoom_factor") or MIN_ZOOM
    set_zoom(current * STEP_OUT)
end

function M.reset()
    hl.config({ cursor = { zoom_factor = MIN_ZOOM } })
end

return M
