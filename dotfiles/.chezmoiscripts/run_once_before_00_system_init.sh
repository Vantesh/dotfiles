#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/.00_helpers"

source "${CHEZMOI_WORKING_TREE}/packages"

dependencies=(
  "${core[@]}"
  "${fonts[@]}"
  "${theming[@]}"
)
optional=(
  "${optional[@]}"
)

drivers=(
  "${drivers[@]}"
)

# =============================================================================
# Initialize Environment
# =============================================================================

if [[ $EUID -eq 0 ]]; then
  print_error "This script should not be run as root. Please run it as a normal user."
fi

ask_for_sudo

if initialize_env; then
  print_info "Starting setup script..."
  clear
else
  print_error "Failed to initialize environment."
fi

# =============================================================================
# Welcome Message
# =============================================================================
print_box "smslant" "WELCOME"

echo -e "\n---------------------------------------------"
echo -e "Hyprland Dotfiles Setup"
echo -e "Copyright 2025 \e]8;;https://github.com/vantesh/dotfiles\a${STYLE_BOLD}${COLOR_CYAN}[Vantesh]${COLOR_RESET}\e]8;;\a"
echo -e "This script will heavily modify your system."
echo -e "\nPackages: ${COLOR_MAGENTA}${#dependencies[@]}${COLOR_RESET}"
echo -e "---------------------------------------------\n"

if ! confirm "Do you want to continue?"; then
  print_info "Setup aborted by user."
  exit 0
else
  clear

fi
# =============================================================================
# Install dependencies
# =============================================================================
print_box "smslant" "Dependencies"
print_step "Installing dependencies"

failed_packages=()

for pkg in "${dependencies[@]}"; do
  install_package "$pkg"
done

# install drivers
if confirm "Do you want to install drivers?"; then
  print_step "Installing drivers"
  for driver in "${drivers[@]}"; do
    install_package "$driver"
  done
fi

if confirm "Do you want to install optional packages?"; then
  print_step "Installing optional packages"
  for pkg in "${optional[@]}"; do
    install_package "$pkg"
  done
fi

if [[ ${#failed_packages[@]} -gt 0 ]]; then
  if confirm "Some packages failed to install. Do you want to retry manually?"; then
    print_step "Retrying failed packages"
    for failed_pkg in "${failed_packages[@]}"; do
      "$AUR_HELPER" -S "$failed_pkg"
    done
  else
    print_warning "Skipping failed packages."
  fi

fi

# =============================================================================
# SETUP PACMAN
# =============================================================================
print_box "smslant" "Pacman"
print_step "Setting up Pacman configuration"

pacman_conf="/etc/pacman.conf"
lines_to_edit=(
  "Color"
  "VerbosePkgLists"
  "ParrallelDownloads"
)
if create_backup "$pacman_conf"; then
  print_info "Pacman backup created"

  for line in "${lines_to_edit[@]}"; do
    if grep -q "^#\s*$line" "$pacman_conf"; then
      sudo sed -i "s/^#\s*$line/$line/" "$pacman_conf"
      print_info "Uncommented ${COLOR_CYAN}$line${COLOR_RESET}"
    else
      print_info "$COLOR_CYAN$line${COLOR_RESET} is already uncommented"
    fi
  done

  if grep -q "^ParallelDownloads" "$pacman_conf" && ! grep -q "^ILoveCandy" "$pacman_conf"; then
    sudo sed -i "/^ParallelDownloads/a ILoveCandy" "$pacman_conf"
    print_info "Added ILoveCandy to $pacman_conf"
  else
    print_info "${COLOR_CYAN}ILoveCandy${COLOR_RESET} is already present"
  fi
fi

paccache_config="/etc/conf.d/pacman-contrib"
if update_config "$paccache_config" "PACCACHE_ARGS" "'-k1'"; then
  print_info "Updated paccache configuration"
  enable_service "paccache.timer" "system"
else
  print_warning "Failed to update paccache configuration"
fi

# mirrorlist
enable_service "reflector.timer" "system"

write_system_config "/etc/pacman.d/hooks/00-paccache.hook" "Paccache hook" <<EOF
[Trigger]
Type = Package
Operation = Remove
Operation = Install
Operation = Upgrade
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk1
Depends = pacman-contrib
EOF
write_system_config "/etc/pacman.d/hooks/01-paccache-uninstalled.hook" "Paccache uninstalled hook" <<EOF
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache for uninstalled packages...
When = PostTransaction
Exec = /usr/bin/paccache -ruk0
Depends = pacman-contrib
EOF

# =============================================================================
# SUDOERS
# =============================================================================
print_box "smslant" "Sudo"
print_step "Setting up sudoers configuration"

write_system_config "/etc/sudoers.d/timeout" "Sudo timeout configuration" <<EOF
Defaults passwd_timeout=0
EOF

declare -A faillock_config=(
  [deny]="20"
  [unlock_time]="300"
  [fail_interval]="900"
)

for key in "${!faillock_config[@]}"; do
  if update_config "/etc/security/faillock.conf" "$key" "${faillock_config[$key]}"; then
    print_info "Updated faillock configuration: $key=${faillock_config[$key]}"
  else
    print_error "Failed to update faillock configuration for $key"
  fi
done

# =============================================================================
# ENABLE SERVICES
# =============================================================================
print_box "smslant" "Services"
print_step "Enabling necessary services"

readonly USER_SERVICES=(
  gnome-keyring-daemon.service
  hypridle.service
  gcr-ssh-agent.socket
)

readonly SYSTEM_SERVICES=(
  bluetooth.service
  sddm.service
  ufw.service
)

# Enable services by scope
for scope in user system; do
  services=()
  if [[ "$scope" == "user" ]]; then
    services=("${USER_SERVICES[@]}")
  else
    services=("${SYSTEM_SERVICES[@]}")
  fi

  for service in "${services[@]}"; do
    enable_service "$service" "$scope"
  done
done

# =============================================================================
# SNAPPER
# =============================================================================
print_box "smslant" "Snapper"
print_step "Setting up Snapper configuration"
if confirm "Do you want to set up Snapper?"; then
  snapper_deps=(
    snapper
    snap-pac
    btrfs-assistant
    btrfs-progs
    inotify-tools
    sbctl
  )
  snapper_services=(
    snapper-cleanup.timer
  )

  if [[ "$(detect_bootloader)" == "limine" ]]; then
    snapper_deps+=(
      limine-mkinitcpio-hook
      limine-snapper-sync
    )

  elif [[ "$(detect_bootloader)" == "grub" ]]; then
    snapper_deps+=(
      grub-btrfs
    )
    snapper_services+=(
      grub-btrfsd.service
    )
  fi

  for package in "${snapper_deps[@]}"; do
    install_package "$package"
  done

  for service in "${snapper_services[@]}"; do
    enable_service "$service" "system"
  done

  # limine configuration
  if [[ "$(detect_bootloader)" == "limine" ]]; then
    readonly LIMINE_CONFIG_FILE="/etc/default/limine"
    readonly LIMINE_ENTRY_TEMPLATE="/etc/limine-entry-tool.conf"
    readonly LIMINE_SNAPPER_TEMPLATE="/etc/limine-snapper-sync.conf"

    if [[ ! -f "$LIMINE_ENTRY_TEMPLATE" || ! -f "$LIMINE_SNAPPER_TEMPLATE" ]]; then
      print_error "Limine templates not found."
    fi

    if {
      cat "$LIMINE_ENTRY_TEMPLATE"
      echo
      echo # just to space out the entry
      cat "$LIMINE_SNAPPER_TEMPLATE"
    } | sudo tee "$LIMINE_CONFIG_FILE" >/dev/null; then
      print_info "Limine template added."
    else
      print_error "Failed to update Limine configuration."
    fi
    declare -A limine_entries=(["MAX_SNAPSHOT_ENTRIES"]=15
      ["TERMINAL"]="kitty"
      ["TERMINAL_ARG"]="-e"
      ["SNAPSHOT_FORMAT_CHOICE"]=0
      ["QUIET_MODE"]="yes"
      ["ENABLE_UKI"]="yes"
    )

    success=true
    for key in "${!limine_entries[@]}"; do
      if ! update_config "$LIMINE_CONFIG_FILE" "$key" "${limine_entries[$key]}"; then
        print_error "Failed to update $key in $LIMINE_CONFIG_FILE"
        success=false
        break
      fi
    done

    if $success; then
      print_info "Limine configuration updated successfully."
    else
      print_error "Failed to update Limine configuration."
    fi
  fi

  # Snapper configuration
  declare -A snapper_settings=(
    ["NUMBER_CLEANUP"]="yes"
    ["NUMBER_LIMIT"]="20"
    ["TIMELINE_CREATE"]="no"
    ["TIMELINE_CLEANUP"]="yes"
    ["TIMELINE_MIN_AGE"]="1800"
    ["TIMELINE_LIMIT_HOURLY"]="5"
    ["TIMELINE_LIMIT_DAILY"]="7"
    ["TIMELINE_LIMIT_WEEKLY"]="0"
    ["TIMELINE_LIMIT_MONTHLY"]="0"
    ["TIMELINE_LIMIT_YEARLY"]="0"
    ["EMPTY_PRE_POST_CLEANUP"]="yes"
    ["EMPTY_PRE_POST_MIN_AGE"]="1800"
  )

  success=true
  for key in "${!snapper_settings[@]}"; do
    if ! set_snapper_config_value "root" "$key" "${snapper_settings[$key]}"; then
      print_error "Failed to set Snapper config: $key"
      success=false
      break
    fi
  done

  if $success; then
    print_info "Snapper configuration updated successfully."
  else
    print_error "Failed to update Snapper configuration."
  fi

  # updatedb
  write_system_config "/etc/updatedb.conf" "Updatedb configuration" <<EOF
PRUNENAMES = ".git .hg .svn .snapshots"
PRUNEPATHS = "/afs /media /mnt /net /sfs /tmp /udev /var/cache /var/lib/pacman/local /var/lock /var/run /var/spool /var/tmp"
EOF

fi

#=============================================================================
# LAPTOP POWER MANAGEMENT
#=============================================================================

if is_laptop; then
  print_box "smslant" "Laptop"
  print_step "Setting up laptop tweaks"

  if ! sudo systemctl is-enabled auto-cpufreq.service &>/dev/null; then
    if sudo auto-cpufreq --install >/dev/null 2>&1; then
      print_info "Auto CPU frequency scaling enabled"
    else
      print_warning "Failed to enable auto CPU frequency scaling"
    fi
  else
    print_info "Auto CPU frequency scaling is already enabled"
  fi

  readonly TOUCHPAD_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"
  write_system_config "$TOUCHPAD_RULE_FILE" "touchpad udev rule" <<'EOF'
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF

  reload_udev_rules || {
    print_error "Failed to reload udev rules"
  }

  precision_5530=$(sudo dmidecode -s system-product-name | grep -i "Precision 5530")
  if [[ -n "$precision_5530" ]]; then
    if sudo cp "${CHEZMOI_WORKING_TREE}/extras/udev/"*.rules /etc/udev/rules.d/ && reload_udev_rules &>/dev/null; then
      print_info "Precision 5530 udev rules applied"
    else
      print_error "Failed to apply Precision 5530 udev rules"
    fi
  fi
fi
