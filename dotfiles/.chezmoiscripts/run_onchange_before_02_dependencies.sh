#!/bin/bash

# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/.00_helpers.sh"

# =======================
# CORE COMPONENTS
# =======================
core_packages=(
  hyprland                     # Wayland compositor
  uwsm                         # Universal Wayland Session Manager
  polkit-gnome                 # Polkit authentication agent
  rofi-wayland                 # Wayland launcher
  app2unit-git                 # Run applications as units
  hypridle                     # Idle management
  hyprlock                     # Lock screen
  hyprpicker                   # Color picker
  hyprsunset                   # Blue light filter
  grimblast                    # Screenshot tool
  waypaper                     # Wallpaper manager
  swww                         # Wallpaper daemon
  imv                          # Image viewer
  hyprshot                     # Screenshot tool
  matugen-bin                  # Color generator
  ags-hyprpanel-git            # panel
  pyprland                     # for scratchpads
  devify                       # device notification system
  brightnessctl                # Screen brightness
  playerctl                    # Media controller
  nautilus                     # File manager
  sddm-git                     # Display manager
  kitty                        # Terminal emulator
  rofimoji                     # Emoji picker for Rofi
  selectdefaultapplication-git # Tool to change default apps
  yad                          # Yet Another Dialog - GUI for scripts

  xdg-desktop-portal-gtk      # Desktop portal for GTK
  xdg-desktop-portal-hyprland # Desktop portal for Hyprland
  archlinux-xdg-menu          # Arch Linux menu integration
  xdg-user-dirs               # User directories
  xdg-autostart               # XDG autostart
  xdg-terminal-exec           # launching desktop apps with Terminal=true

  #required by vscode and other apps to store keyrings
  gnome-keyring
  libgnome-keyring

  # Sytem tools
  topgrade
  mission-center
  udiskie
  ntfs-3g
  exfatprogs
  dosfstools
  f2fs-tools
  gparted
  gpart
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
  xorg-xhost
  layer-shell-qt
  layer-shell-qt5
  qt6-multimedia-ffmpeg
  android-udev
  libfido2
)

# =======================
# FONTS
# =======================
fonts=(
  powerline-fonts
  ttf-nerd-fonts-symbols
  ttf-nerd-fonts-symbols-mono
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
  qt6ct
  qt5ct
)

# =======================
# Input tools and utilities
# =======================
input_tools=(
  clipse-gui
  clipse
  wmctrl
  gpu-screen-recorder
)

# =======================
# DRIVERS
# =======================
# Base graphics drivers
base_drivers=(
  mesa-utils
  wireless-regdb
  libva-utils
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
  nvidia-utils
  nvidia-dkms
  nvidia-settings
  nvidia-prime
  opencl-nvidia
)

install_gpu_drivers() {
  if grep -q "CachyOS" /etc/os-release; then
    printc yellow "Skipping GPU driver installation on CachyOS"
    return 0
  fi
  printc cyan "Installing base graphics driver"
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
      local vendor_name="${vendor%% *}"
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

        # Check for specific kernel flavors
        local kernel_version
        kernel_version=$(uname -r)

        if [[ "$kernel_version" == *"-zen"* ]]; then
          install_package "linux-zen-headers"
        elif [[ "$kernel_version" == *"-lts"* ]]; then
          install_package "linux-lts-headers"
        elif [[ "$kernel_version" == *"-cachyos-lts"* ]]; then
          install_package "linux-cachyos-lts-headers"
        elif [[ "$kernel_version" == *"-cachyos"* ]]; then
          install_package "linux-cachyos-headers"
        else
          install_package "linux-headers"
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
  brave-bin
  visual-studio-code-bin
  qbittorrent-enhanced-git
  vlc-git
  mpv
  btop
  nvtop
  yazi
  neovim
  spotify
  git-delta
  localsend
  antidot-bin # clean up home directory
)
#-------------------------------------------------------------------------------------------------
# Main execution
#-------------------------------------------------------------------------------------------------

printc_box "DEPENDENCIES" "Installing core dependencies and tools"

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
