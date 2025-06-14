#!/bin/bash

# =======================
# CORE COMPONENTS
# =======================
core_packages=(
  hyprland          # Wayland compositor
  uwsm              # Universal Wayland Session Manager
  rofi-wayland      # Wayland launcher
  app2unit-git      # Run applications as units
  hypridle          # Idle management
  hyprlock          # Lock screen
  hyprpicker        # Color picker
  grimblast         # Screenshot tool
  swww              # Wallpaper daemon
  hyprshot          # Screenshot tool
  matugen-bin       # Color generator
  ags-hyprpanel-git # panel
  hyprpolkitagent   # Polkit agent for Hyprland
  pyprland          # for scratchpads
  devify            # device notification system
  brightnessctl     # Screen brightness
  playerctl         # Media controller
  thunar            # File manager
  sddm              # Display manager
  kitty             # Terminal emulator

  xdg-desktop-portal-gtk       # Desktop portal for GTK
  xdg-desktop-portal-hyprland  # Desktop portal for Hyprland
  archlinux-xdg-menu           # Arch Linux menu integration
  xdg-user-dirs                # User directories
  xdg-utils                    # XDG utilities
  xdg-desktop-portal           # Desktop portal
  selectdefaultapplication-git # Tool to change default apps
  yad                          # Yet Another Dialog - GUI for scripts

  #required by vscode and other apps to store keyrings
  gnome-keyring
  seahorse
  libsecret

  # Sytem tools
  topgrade
  udiskie
  ntfs-3g
  gparted
  gpart
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
  usbutils
  man-db
  tealdeer
  xorg-xhost

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
  apple-fonts
  ttf-jetbrains-mono-nerd
  ttf-font-awesome
  noto-fonts-cjk
  noto-fonts-extra
  ttf-liberation
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
  clipse-gui
  clipse
  wtype
  wmctrl
  xdotool
  gpu-screen-recorder
)

# =======================
# DRIVERS
# =======================
# Base graphics drivers
base_drivers=(
  mesa
  libva
  libva-utils
  linux-firmware
  vulkan-tools
  vulkan-headers

)

# Intel-specific drivers
intel_drivers=(
  libva-intel-driver
  intel-media-driver
  vulkan-intel
  xf86-video-intel
)

# AMD-specific drivers
amd_drivers=(
  libva-mesa-driver
  vulkan-radeon

)
# NVIDIA-specific drivers
nvidia_drivers=(
  libva-nvidia-driver
  nvidia-utils

)

install_gpu_drivers() {
  # Install base GPU-related packages
  for package in "${base_drivers[@]}"; do
    install_package "$package"
  done

  local gpu_info
  gpu_info=$(lspci -nn | grep -Ei "VGA compatible controller|3D controller|Display controller")

  # Define vendor -> driver array mappings
  local -A gpu_vendors=(
    ["Intel Corporation"]="intel_drivers[@]"
    ["Advanced Micro Devices"]="amd_drivers[@]"
    ["NVIDIA Corporation"]="nvidia_drivers[@]"
  )

  local gpu_found=false

  for vendor in "${!gpu_vendors[@]}"; do
    if echo "$gpu_info" | grep -Eiq "$vendor"; then
      gpu_found=true
      local vendor_name="${vendor%% *}" # Get first word for message
      echo
      printc cyan "$vendor_name GPU detected, installing $vendor_name drivers..."

      local driver_array_name="${gpu_vendors[$vendor]}"

      case "$driver_array_name" in
      "intel_drivers[@]")
        for pkg in "${intel_drivers[@]}"; do install_package "$pkg"; done
        ;;
      "amd_drivers[@]")
        for pkg in "${amd_drivers[@]}"; do install_package "$pkg"; done
        ;;
      "nvidia_drivers[@]")
        for pkg in "${nvidia_drivers[@]}"; do install_package "$pkg"; done

        # Extract kernel flavor (e.g. zen, lts, etc)
        local kernel_flavor
        kernel_flavor=$(uname -r | grep -oP '(?<=-)[^-]+$')

        # Install matching headers
        if [[ -n "$kernel_flavor" ]] && pacman -Qq "linux-$kernel_flavor-headers" &>/dev/null; then
          install_package "linux-$kernel_flavor-headers"
          install_package "nvidia-dkms"
        elif pacman -Qq "linux-headers" &>/dev/null; then
          install_package "linux-headers"
          install_package "nvidia"
        else
          printc yellow "⚠️  Could not detect a matching kernel headers package for: $(uname -r)"
        fi
        ;;
      esac
    fi
  done

  if ! $gpu_found; then
    echo
    printc yellow "No known GPU vendor detected. Skipping GPU driver installation."
  fi
}

# =======================
# optionals
# =======================
optional=(
  bemoji
  brave-bin
  zen-browser-bin
  visual-studio-code-bin
  qbittorrent
  vlc
  mpv
  ark
  btop
  nvtop
  yazi
  neovim
  spotify-launcher
  antidot-bin # clean up home directory

)

packages=(
  "${core_packages[@]}"
  "${fonts[@]}"
  "${appearance[@]}"
  "${input_tools[@]}"
  "${optional[@]}"
)

for package in "${packages[@]}"; do
  install_package "$package"
done

# Install GPU-specific drivers
echo
if confirm "Do you want to install GPU-specific drivers?"; then
  install_gpu_drivers
else
  printc yellow "Skipping GPU driver installation."
fi
