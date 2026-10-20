#!/bin/sh
set -eu

scheme=$(gsettings get org.gnome.desktop.interface color-scheme)

case "$scheme" in
  "'prefer-dark'") temporary_scheme=prefer-light ;;
  *) temporary_scheme=prefer-dark ;;
esac

# Reload GTK's user CSS, restoring the preference even if the toggle fails.
trap 'gsettings set org.gnome.desktop.interface color-scheme "$scheme"' EXIT

gsettings set org.gnome.desktop.interface color-scheme "$temporary_scheme"
