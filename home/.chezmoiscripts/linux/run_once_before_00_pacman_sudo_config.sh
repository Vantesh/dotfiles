#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

# =============================================================================
# Initialize Environment
# =============================================================================
common_init

# =============================================================================
# SETUP PACMAN
# =============================================================================
print_box "smslant" "Pacman"
print_step "Configuring Pacman settings"
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
if update_config "$paccache_config" "PACCACHE_ARGS" "'-k2'"; then
  print_info "Updated paccache configuration"
else
  print_warning "Failed to update paccache configuration"
fi

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
Exec = /usr/bin/paccache -rk2
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
# SETUP SUDO
# =============================================================================

print_box "smslant" "Sudo"
print_step "Setting up sudoers configuration"

write_system_config "/etc/sudoers.d/timeout" "Sudo timeout configuration" <<EOF
Defaults passwd_timeout=0
EOF
write_system_config "/etc/sudoers.d/passwd_tries" "Sudo password tries configuration" <<EOF
Defaults passwd_tries=10
EOF

declare -A faillock_config=(
  [deny]="20"
  [unlock_time]="120"
  [fail_interval]="900"
)

for key in "${!faillock_config[@]}"; do
  if update_config "/etc/security/faillock.conf" "$key" "${faillock_config[$key]}"; then
    print_info "Updated faillock configuration: $key=${faillock_config[$key]}"
  else
    print_error "Failed to update faillock configuration for $key"
  fi
done
