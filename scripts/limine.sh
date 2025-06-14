#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

DEPS=(
  snapper
  snap-pac
  limine-mkinitcpio-hook
  limine-snapper-sync
  btrfs-assistant
  btrfs-progs
  sbctl
)

readonly SERVICES=(
  "limine-snapper-sync.service"
  "snapper-cleanup.timer"
)

readonly LIMINE_CONFIG_FILE="/etc/default/limine"
readonly LIMINE_ENTRY_TEMPLATE="/etc/limine-entry-tool.conf"
readonly LIMINE_SNAPPER_TEMPLATE="/etc/limine-snapper-sync.conf"
# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  for dep in "${DEPS[@]}"; do
    install_package "$dep"
  done
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

enable_snapper_services() {
  for service in "${SERVICES[@]}"; do
    enable_service "$service" "system"
  done
}

# =============================================================================
# LIMINE CONFIGURATION
# =============================================================================

setup_limine_config_file() {
  printc -n cyan "Setting up Limine config... "

  if [[ -f "$LIMINE_CONFIG_FILE" ]]; then
    printc yellow "exists"
    return 0
  fi

  if [[ ! -f "$LIMINE_ENTRY_TEMPLATE" || ! -f "$LIMINE_SNAPPER_TEMPLATE" ]]; then
    printc red "FAILED - Missing template(s)"
    return 1
  fi

  if {
    cat "$LIMINE_ENTRY_TEMPLATE"
    echo
    echo
    cat "$LIMINE_SNAPPER_TEMPLATE"
  } | sudo tee "$LIMINE_CONFIG_FILE" >/dev/null; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_limine_settings() {
  printc -n cyan "Configuring limine snapper settings... "
  declare -A snapper_config=(
    ["MAX_SNAPSHOT_ENTRIES"]=15
    ["TERMINAL"]="kitty"
    ["TERMINAL_ARG"]="-e"
    ["ENABLE_UKI"]="yes"
  )

  local success=true
  for key in "${!snapper_config[@]}"; do
    if ! update_config "$LIMINE_CONFIG_FILE" "$key" "${snapper_config[$key]}"; then
      success=false
      break
    fi
  done

  if [[ "$success" == true ]]; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

# =============================================================================
# SNAPPER CONFIGURATION
# =============================================================================

configure_snapper_cleanup() {
  printc -n cyan "Configuring Snapper cleanup... "
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

  local success=true
  for key in "${!snapper_settings[@]}"; do
    if ! set_snapper_config_value "root" "$key" "${snapper_settings[$key]}"; then
      success=false
      break
    fi
  done

  if [[ "$success" == true ]]; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

create_updatedb() {
  write_system_config "/etc/updatedb.conf" "updatedb config" <<'EOF'
PRUNE_BIND_MOUNTS = "yes"
PRUNEFS = "9p afs anon_inodefs auto autofs bdev binfmt_misc cgroup cifs coda configfs cpuset cramfs debugfs devpts devtmpfs ecryptfs exofs ftpfs fuse fuse.encfs fuse.s3fs fuse.sshfs fusectl gfs gfs2 hugetlbfs inotifyfs iso9660 jffs2 lustre mqueue ncpfs nfs nfs4 nfsd pipefs proc ramfs rootfs rpc_pipefs securityfs selinuxfs sfs shfs smbfs sockfs sshfs sysfs tmpfs ubifs udf usbfs vboxsf"
PRUNENAMES = ".git .hg .svn .snapshots"
PRUNEPATHS = "/afs /media /mnt /net /sfs /tmp /udev /var/cache /var/lib/pacman/local /var/lock /var/run /var/spool /var/tmp"
EOF
}

# =============================================================================
# LIMINE INTERFACE CONFIGURATION
# =============================================================================

configure_limine_interface() {
  printc cyan "Configuring Limine interface..."

  local limine_conf="/boot/limine.conf"

  if [[ ! -f "$limine_conf" ]]; then
    printc red "Limine config file not found at $limine_conf"
    return 1
  fi

  printc -n cyan "Setting interface options... "

  # Interface configuration parameters
  local PARAMS=(
    "term_palette: 1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    "term_palette_bright: 585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    "term_background: 1e1e2e"
    "term_foreground: cdd6f4"
    "term_background_bright: 1e1e2e"
    "term_foreground_bright: cdd6f4"
    "timeout: 1"
    "default_entry: 2"
    "interface_branding: Arch Linux"

  )

  # Build interface configuration block
  local interface_config=$'\n# Interface Configuration\n'
  for param in "${PARAMS[@]}"; do
    interface_config+="$param"$'\n'
  done

  # Find the line with "/+Arch Linux" and insert interface config above it
  if grep -q "/+Arch Linux" "$limine_conf"; then
    # Create a temporary file with the interface config inserted
    if awk -v config="$interface_config" '
      /\/\+Arch Linux/ {
        print config
        print $0
        next
      }
      # Skip existing interface config lines if they exist
      /^term_palette:|^term_palette_bright:|^term_background:|^term_foreground:|^term_background_bright:|^term_foreground_bright:|^timeout:|^wallpaper:|^interface_branding:|^default_entry:/ {
        next
      }
      { print }
    ' "$limine_conf" | sudo tee "${limine_conf}.tmp" >/dev/null && sudo mv "${limine_conf}.tmp" "$limine_conf"; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "Arch Linux entry not found in $limine_conf"
    return 1
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  ensure_sudo
  install_dependencies
  enable_snapper_services
  setup_limine_config_file
  configure_limine_settings
  configure_snapper_cleanup
  create_updatedb
  configure_limine_interface

}

main
