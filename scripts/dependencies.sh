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
  hyprpicker      # Color picker
  grimblast       # Screenshot tool
  hyprpaper       # Wallpaper daemon
  hyprshot        # Screenshot tool
  matugen-bin     # Color generator
  ags-hyprpanel-git # panel
  hyprpolkitagent # Polkit agent for Hyprland
  pyprland        # for scratchpads
  devify          # device notification system
  brightnessctl   # Screen brightness
  playerctl       # Media controller
  thunar          # File manager
  sddm            # Display manager
  kitty           # Terminal emulator

  xdg-desktop-portal-gtk      # Desktop portal for GTK apps
  xdg-desktop-portal-hyprland # Desktop portal for Hyprland
  archlinux-xdg-menu          # Arch Linux menu integration
  xdg-user-dirs               # User directories
  xdg-utils                   # XDG utilities
  xdg-desktop-portal          # Desktop portal
  selectdefaultapplication-git # Tool to change default apps

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
  pwvucontrol
  wireplumber
  networkmanager

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
  qt6ct
  qt5ct
)

# =======================
# Input tools and utilities
# =======================
input_tools=(
  gpu-screen-recorder
  clipse-gui
  clipse
  wtype
  wmctrl
  xdotool
  libinput-gestures
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
  linux-zen-headers
  nvidia-dkms
  nvidia-utils

)

# =======================
# optionals
# =======================
optional=(
  bemoji
  brave-bin
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
  install_package "$package"
done
