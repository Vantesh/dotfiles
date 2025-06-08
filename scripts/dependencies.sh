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

  xdg-desktop-portal-gtk       # Desktop portal for GTK apps
  xdg-desktop-portal-hyprland  # Desktop portal for Hyprland
  archlinux-xdg-menu           # Arch Linux menu integration
  xdg-user-dirs                # User directories
  xdg-utils                    # XDG utilities
  xdg-desktop-portal           # Desktop portal
  selectdefaultapplication-git # Tool to change default apps

  #required by vscode and other apps to store keyrings
  gnome-keyring
  seahorse
  libsecret

  # Sytem tools
  pacman-contrib
  topgrade
  udiskie
  ntfs-3g
  partitionmanager
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
)

# AMD-specific drivers
amd_drivers=(
  libva-mesa-driver
  vulkan-radeon

)
# NVIDIA-specific drivers
nvidia_drivers=(
  libva-nvidia-driver
  linux-zen-headers
  nvidia-dkms
  nvidia-utils
)
install_gpu_drivers() {
  for package in "${base_drivers[@]}"; do
    install_package "$package"
  done

  local gpu_info
  gpu_info=$(lspci -nn | grep -Ei "VGA compatible controller|3D controller|Display controller")

  local -A gpu_vendors=(
    ["Intel Corporation"]="intel_drivers[@]"
    ["Advanced Micro Devices"]="amd_drivers[@]"
    ["NVIDIA Corporation"]="nvidia_drivers[@]"
  )

  local gpu_found=false

  for vendor in "${!gpu_vendors[@]}"; do
    if echo "$gpu_info" | grep -Eiq "$vendor"; then
      gpu_found=true
      local vendor_name="${vendor%% *}" # Get first word
      echo
      printc cyan "$vendor_name GPU detected, installing $vendor_name drivers..."
      local driver_array_name="${gpu_vendors[$vendor]}"
      case "$driver_array_name" in
      "intel_drivers[@]") for pkg in "${intel_drivers[@]}"; do install_package "$pkg"; done ;;
      "amd_drivers[@]") for pkg in "${amd_drivers[@]}"; do install_package "$pkg"; done ;;
      "nvidia_drivers[@]") for pkg in "${nvidia_drivers[@]}"; do install_package "$pkg"; done ;;
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
if confirm "Do you want to install GPU-specific drivers?"; then
  install_gpu_drivers
else
  printc yellow "Skipping GPU driver installation."
fi
