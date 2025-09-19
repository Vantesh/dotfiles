-- ==UserScript==
-- @name         mpv-playlist
-- @description  Display mpv playlist in kdialog and switch entries
-- @author       Vantesh X ChatGPT
-- ==/UserScript==

local options = {
  -- window dimensions
  width = 750,
  height = 600,
  reopen_on_select = false,
  reopen_on_track_change = false
}

require 'mp.options'.read_options(options)
local utils = require 'mp.utils'

-- helper: strip path, keep only filename
local function basename(path)
  return path and path:match("^.+/(.+)$") or path
end

local function playlist_kdialog()
  local arr = mp.get_property_native("playlist")
  local args = {
    'kdialog',
    '--title=mpv playlist',
    '--icon=mpv',
    '--geometry=' .. utils.to_string(options.width) .. 'x' .. utils.to_string(options.height),
    '--radiolist',
    'Select playlist entry',
    '--'
  }

  for i, v in ipairs(arr) do
    table.insert(args, utils.to_string(i))                                    -- ID
    table.insert(args, v.title or basename(v.filename) or utils.to_string(i)) -- label
    table.insert(args, v.playing and "on" or "off")                           -- state
  end

  local res = mp.command_native {
    name = "subprocess",
    args = args,
    capture_stdout = true,
    playback_only = options.reopen_on_track_change,
    capture_size = 32
  }

  local success = false
  if res.status == 0 and tonumber(res.stdout) and tonumber(res.stdout) > 0 then
    mp.set_property_native("playlist-pos-1", tonumber(res.stdout))
    success = true
  end

  if (success and options.reopen_on_select)
      or (options.reopen_on_track_change and res.killed_by_us) then
    mp.add_timeout(0.1, playlist_kdialog)
  end
end

-- keybinding: Ctrl+L to open playlist
mp.add_key_binding("Ctrl+l", "kdialog_open_playlist", playlist_kdialog)
