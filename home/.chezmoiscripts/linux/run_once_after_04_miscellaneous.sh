#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

# =============================================================================
# Initialize Environment
# =============================================================================
common_init

# ===============================================================================
# MISCELLANEOUS
# ===============================================================================
print_box "smslant" "Miscellaneous"
print_step "Setting up miscellaneous configurations"

if ! sudo systemctl is-enabled pkgfile-update.timer >/dev/null 2>&1; then
  print_info "Updating pkgfile database"
  if sudo pkgfile --update >/dev/null 2>&1; then
    print_info "pkgfile database updated successfully"
    enable_service "pkgfile-update.timer" "system"
  else
    print_warning "Failed to update pkgfile database"
  fi
fi

# Regenerate fonts cache
print_info "Regenerating font cache"
if fc-cache -f -v >/dev/null 2>&1; then
  print_info "Font cache regenerated successfully"
else
  print_warning "Failed to regenerate font cache"
fi

# setup ssh known hosts
if [[ ! -f "${HOME}/.ssh/known_hosts" ]]; then
  print_info "Creating SSH known_hosts file"
  touch "${HOME}/.ssh/known_hosts"
  chmod 644 "${HOME}/.ssh/known_hosts"
  print_info "SSH known_hosts file created successfully"
fi

# generate github and gitlab known hosts
if ! grep -q "github.com" "${HOME}/.ssh/known_hosts"; then
  print_info "Adding GitHub to SSH known_hosts"
  ssh-keyscan github.com >> "${HOME}/.ssh/known_hosts" 2>/dev/null
fi

if ! grep -q "gitlab.com" "${HOME}/.ssh/known_hosts"; then
  print_info "Adding GitLab to SSH known_hosts"
  ssh-keyscan gitlab.com >> "${HOME}/.ssh/known_hosts" 2>/dev/null
fi


# ===============================================================================
# FSTAB
# ===============================================================================

if is_btrfs; then
  if grep -q 'btrfs.*relatime' /etc/fstab; then
    if sudo sed -i -E '/btrfs/ { s/\brelatime\b/noatime/g; s/\bdefaults\b/defaults,noatime/g; s/(,noatime){2,}/,noatime/g; s/,+/,/g; }' /etc/fstab; then
      print_info "Updated /etc/fstab with noatime for Btrfs"
      reload_systemd_daemon
    else
      print_error "Failed to update /etc/fstab with noatime for Btrfs"
    fi

  fi
fi
