#!/bin/bash

get_current_song() {
  command -v playerctl &>/dev/null || exit 1

  current_player=$(playerctl -a metadata -f '{{playerName}} {{status}}' 2>/dev/null | awk '$2 == "Playing" {print $1; exit}')
  [ -z "$current_player" ] && exit 0

  title=$(playerctl -p "$current_player" metadata title 2>/dev/null)
  artist=$(playerctl -p "$current_player" metadata artist 2>/dev/null)

  # Clean unwanted tags from title
  cleaned_title=$(echo "$title" | sed -E \
    -e 's/\s*[-|–]*\s*\(?official music video\)?//I' \
    -e 's/\s*[-|–]*\s*\(?official video\)?//I' \
    -e 's/\s*[-|–]*\s*\(?lyrics\)?//I' \
    -e 's/\s*[-|–]*\s*\(?HD\)?//I' \
    -e 's/\s*\[[^]]*\]//g' \
    -e 's/\s*\([^)]*\)//g' \
    -e 's/\s{2,}/ /g' \
    -e 's/^\s+|\s+$//g')

  case "$current_player" in
  *spotify*) icon="" ;;
  *mpv*) icon="" ;;
  *vlc*) icon="󰕼" ;;
  *firefox*) icon="" ;;
  *brave*) icon="" ;;
  *chromium* | *chrome*) icon="" ;;
  *) icon="" ;;
  esac

  if [ -n "$cleaned_title" ]; then
    if [[ -n "$artist" && "$cleaned_title" != *"$artist"* ]]; then
      echo "$icon $artist - $cleaned_title"
    else
      echo "$icon $cleaned_title"
    fi
  fi
}

get_current_song
