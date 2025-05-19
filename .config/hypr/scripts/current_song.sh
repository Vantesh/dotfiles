#!/bin/bash

get_current_song() {
  # Check if playerctl is installed
  if ! command -v playerctl &>/dev/null; then
    exit 1
  fi

  # Get current song information
  player_source=$(playerctl -l 2>/dev/null | head -n 1)
  music_info=$(playerctl metadata title 2>/dev/null)
  artist_info=$(playerctl metadata artist 2>/dev/null)

  case "$player_source" in
  spotify*) player_icon="" ;;
  mpv*) player_icon="" ;;
  vlc*) player_icon="󰕼" ;;
  firefox*) player_icon="" ;;
  chromium*) player_icon="" ;;
  *) player_icon="" ;;
  esac

  # Only display if there is playing
  if [ -n "$music_info" ]; then
    echo "$player_icon $artist_info - $music_info"
  fi
}

get_current_song
