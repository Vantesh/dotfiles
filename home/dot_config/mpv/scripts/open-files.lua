-- This is free and unencumbered software released into the public domain.
-- The software is provided "as is", without warranty of any kind.
-- Anyone is free to copy, modify, publish, use, compile, sell, or
-- distribute this software, either in source code form or as a compiled
-- binary, for any purpose, commercial or non-commercial, and by any means.
-- For more information, please refer to <http://unlicense.org/>
--
-- Use KDE KDialog to add files to playlist, subtitles to playing video or open URLs.
-- Based on 'mpv-open-file-dialog' <https://github.com/rossy/mpv-open-file-dialog>.
--
-- Default keybindings:
--      Ctrl+o: Add files to the playlist and replace the current playlist.
--      Ctrl+Shift+o: Append files to the playlist.
--      Ctrl+s: Load a subtitle file.
--      Ctrl+u: Load a URL.
--

utils = require 'mp.utils'

sub_extensions = " *.srt *.sub *.ass *.ssa *.mplsub *.txt "
video_extensions =
" *.3ga *.3gp *.3gpp *.3g2 *.3gp2 *.3gpp2 *.avx *.dv *.m2t *.m2ts *.mpl *.mpls *.mts *.ts *.f4v *.m4v *.mp4 *.mp2 *.mpe *.mpeg *.mpg *.vob *.ogv *.moov *.mov *.qtvr *.m1u *.m4u *.mxu *.rv *.rvx *.webm *.flc *.fli *.flv *.fxm *.mkv *.mk3d *.mng *.wmp *.wmv *.asf *.avi *.divx *.nsv *.ogm *.swf *.rmvb *.real "
audio_extensions =
" *.amr *.aac *.ac3 *.flac *.mp2 *.f4a *.m4a *.mp3 *.mpga *.oga *.ogg *.opus *.dts *.dtshd *.ra *.rax *.webm *.pcm *.ape *.f4b *.m4b *.mka *.m3u *.m3u8 *.asx *.wax *.wmx *.wvx *.wma *.mpc *.mp+ *.pls *.spx *.tta *.voc *.wav *.wv *.wvp *.xmf *.cue "

function select_files()
  local focus = utils.subprocess({ args = { 'xdotool', 'getwindowfocus' } })

  if mp.get_property("path") == nil then
    directory = ""
  else
    directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
  end

  file_select = utils.subprocess({
    args = { 'kdialog', '--attach=' .. focus.stdout .. '', '--title=Select Files', '--icon=mpv', '--geometry=750x450', '--multiple', '--separate-output', '--getopenfilename', '' .. directory .. '', 'Multimedia Files  (' .. video_extensions .. audio_extensions .. ') | Video Files (' .. video_extensions .. ') | Audio Files (' .. audio_extensions .. ') | All Files (*)' },
    cancellable = false,
  })
end

function add_files()
  select_files()
  if (file_select.status ~= 0) then return end

  local first_file = true
  for filename in string.gmatch(file_select.stdout, '[^\n]+') do
    mp.commandv('loadfile', filename, first_file and 'replace' or 'append')
    first_file = false
  end
end

function append_files()
  local playlist_items = 0
  select_files()
  if (file_select.status ~= 0) then return end

  for filename in string.gmatch(file_select.stdout, '[^\n]+') do
    if (mp.get_property_number("playlist-count") == 0) then
      mp.commandv('loadfile', filename, 'replace')
    else
      mp.commandv('loadfile', filename, 'append')
    end
    playlist_items = playlist_items + 1
  end
  mp.osd_message("Added " .. playlist_items .. " file(s) to playlist")
end

function open_url()
  local focus = utils.subprocess({ args = { 'xdotool', 'getwindowfocus' } })
  local url_select = utils.subprocess({
    args = { 'kdialog', '--attach=' .. focus.stdout .. '', '--title=Open URL', '--icon=mpv', '--inputbox', 'Enter URL:', '--geometry=460' },
    cancellable = false,
  })

  if (url_select.status ~= 0) then return end

  for filename in string.gmatch(url_select.stdout, '[^\n]+') do
    mp.commandv('loadfile', filename, 'replace')
  end
end

function add_subtitle()
  local focus = utils.subprocess({ args = { 'xdotool', 'getwindowfocus' } })

  if mp.get_property("path") == nil then
    directory = ""
  else
    directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
  end

  local sub_select = utils.subprocess({
    args = { 'kdialog', '--attach=' .. focus.stdout .. '', '--title=Select Subtitle', '--icon=mpv', '--geometry=750x450', '--getopenfilename', '' .. directory .. '', 'Subtitle Files (' .. sub_extensions .. ')' },
    cancellable = false,
  })

  if (sub_select.status ~= 0) then return end

  for filename in string.gmatch(sub_select.stdout, '[^\n]+') do
    mp.commandv('sub-add', filename, 'select')
  end
end

mp.add_key_binding("Ctrl+o", "kdialog_add_files", add_files)
mp.add_key_binding("Ctrl+Shift+o", "kdialog_append_files", append_files)
mp.add_key_binding("Ctrl+u", "kdialog_open_url", open_url)
mp.add_key_binding("Ctrl+s", "kdialog_add_subtitle", add_subtitle)
