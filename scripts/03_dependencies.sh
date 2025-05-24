#!/bin/bash

# =======================
# CORE COMPONENTS
# =======================
core_packages=(
  hyprland        # Wayland compositor
  uwsm            # Universal Wayland Session Manager
  rofi-wayland    # Wayland launcher
  app2unit-git    # Run applications as units
  hypridle        # Idle management
  hyprlock        # Lock screen
  hyprpaper       # Wallpaper daemon
  hyprshot        # Screenshot tool
  hyprpolkitagent # Polkit agent for Hyprland
  pyprland        # for scratchpads
  waybar          # Status bar
  waybar-updates  # Updates module for waybar
  swaync-git      # Notifications
  wlogout         # Logout menu
  devify          # device notification system
  brightnessctl   # Screen brightness
  playerctl       # Media controller
  dolphin         # File manager
  sddm            # Display manager
  kitty           # Terminal emulator

  xdg-desktop-portal-gtk      # Desktop portal for GTK apps
  xdg-desktop-portal-hyprland # Desktop portal for Hyprland
  archlinux-xdg-menu          # Arch Linux menu integration
  xdg-user-dirs               # User directories
  xdg-utils                   # XDG utilities
  xdg-desktop-portal          # Desktop portal

  #required by vscode and other apps to store keyrings
  gnome-keyring
  seahorse
  libsecret

  # Sytem tools
  pacman-contrib
  topgrade
  udiskie
  unzip
  bluez
  bluez-utils
  overskride
  ufw
  pipewire
  pipewire-alsa
  pipewire-pulse
  pipewire-jack
  pavucontrol
  wireplumber
  iwd
  iwgtk
)

# =======================
# FONTS
# =======================
fonts=(
  powerline-fonts
  ttf-nerd-fonts-symbols
  ttf-nerd-fonts-symbols-mono
  ttf-nerd-fonts-symbols-common
  ttf-apple-emoji
  ttf-tabler-icons
  ttf-jetbrains-mono-nerd
  ttf-font-awesome
  noto-fonts-cjk
  noto-fonts-extra
)

# =======================
# APPEARANCE / THEMING
# =======================
appearance=(
  apple_cursor
  nwg-look
  kvantum
  kvantum-qt5
  qt5-wayland
  qt6-wayland
)

# =======================
# Input tools and utilities
# =======================
input_tools=(
  gpu-screen-recorder
  gpu-screenrecorder-gtk
  clipse-gui
  clipse
  wtype
  wmctrl
  xdotool
  libinput-gestures
  libva-intel-driver
)

# =======================
# DRIVERS
# =======================
drivers=(
  mesa
  libva
  libva-utils
  libva-intel-driver
  libva-nvidia-driver
  intel-ucode
  nvidia-dkms

)

# =======================
# optionals
# =======================
optional=(
  google-chrome
  bemoji
  zen-browser
  visual-studio-code-bin
  vlc
  ark
  btop
  nvtop
  yazi
  neovim
  spotify-launcher

)

packages=(
  "${core_packages[@]}"
  "${fonts[@]}"
  "${appearance[@]}"
  "${input_tools[@]}"
  "${drivers[@]}"
  "${optional[@]}"
)

for package in "${packages[@]}"; do
  if yay -Qi "$package" &>/dev/null; then
    printc green "$package is already installed."
  else
    if yay -S --needed --noconfirm "$package"; then
      printc green "$package installed successfully."
    else
      printc red "Failed to install $package."
    fi
  fi
done
