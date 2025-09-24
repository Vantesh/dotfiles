set -l seen __fish_seen_subcommand_from
set -l has_opt __fish_contains_opt

set -l commands brightness volume media lock logout notepad night
set -l not_seen "not $seen $commands"

# Disable file completions
complete -c dmsctl -f

# Main subcommands
complete -c dmsctl -n $not_seen -a brightness -d 'Control display brightness'
complete -c dmsctl -n $not_seen -a volume -d 'Control audio volume'
complete -c dmsctl -n $not_seen -a media -d 'Control media playback'
complete -c dmsctl -n $not_seen -a lock -d 'Lock the screen'
complete -c dmsctl -n $not_seen -a logout -d 'Log out of the session'
complete -c dmsctl -n $not_seen -a notepad -d 'Open notepad'
complete -c dmsctl -n $not_seen -a night -d 'Toggle night mode'

# Brightness subcommand (only if no brightness option already provided)
set -l brightness_opts '+' -
complete -c dmsctl -n "$seen brightness && not $seen $brightness_opts" -a '+' -d 'Increase brightness'
complete -c dmsctl -n "$seen brightness && not $seen $brightness_opts" -a - -d 'Decrease brightness'

# Volume subcommand (only if no volume option already provided)
set -l volume_opts '+' - mute micmute
complete -c dmsctl -n "$seen volume && not $seen $volume_opts" -a '+' -d 'Increase volume'
complete -c dmsctl -n "$seen volume && not $seen $volume_opts" -a - -d 'Decrease volume'
complete -c dmsctl -n "$seen volume && not $seen $volume_opts" -a mute -d 'Toggle mute'
complete -c dmsctl -n "$seen volume && not $seen $volume_opts" -a micmute -d 'Toggle microphone mute'

# Media subcommand (only if no media option already provided)
set -l media_opts next prev play-pause
complete -c dmsctl -n "$seen media && not $seen $media_opts" -a next -d 'Next track'
complete -c dmsctl -n "$seen media && not $seen $media_opts" -a prev -d 'Previous track'
complete -c dmsctl -n "$seen media && not $seen $media_opts" -a play-pause -d 'Toggle play/pause'
