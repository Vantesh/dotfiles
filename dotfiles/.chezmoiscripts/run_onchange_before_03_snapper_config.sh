#!/bin/bash

# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/.00_helpers.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

limine_deps=(
  "limine-mkinitcpio-hook"
  "limine-snapper-sync"
)
grub_deps=(
  "grub-btrfs"
)
DEPS=(
  snapper
  snap-pac
  btrfs-assistant
  btrfs-progs
  inotify-tools
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
# BOOTLOADER VALIDATION
# =============================================================================

validate_bootloader() {
  local bootloader
  bootloader=$(detect_bootloader)

  case "$bootloader" in
  "limine" | "grub")
    return 0
    ;;
  "unknown")
    return 1
    ;;
  esac
}

if ! validate_bootloader; then
  printc yellow "Snapper setup skipped: unsupported bootloader"
  exit 0
fi

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  # Install common dependencies
  for dep in "${DEPS[@]}"; do
    install_package "$dep"
  done

  # Install bootloader-specific dependencies
  if [[ "$(detect_bootloader)" == "limine" ]]; then
    for dep in "${limine_deps[@]}"; do
      install_package "$dep"
    done
  elif [[ "$(detect_bootloader)" == "grub" ]]; then
    for dep in "${grub_deps[@]}"; do
      install_package "$dep"
    done
  fi
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

enable_snapper_services() {
  if [[ "$(detect_bootloader)" == "limine" ]]; then
    for service in "${SERVICES[@]}"; do
      enable_service "$service" "system"
    done
  elif [[ "$(detect_bootloader)" == "grub" ]]; then
    # Only enable snapper cleanup for GRUB, not limine-snapper-sync
    enable_service "snapper-cleanup.timer" "system"
    enable_service "grub-btrfsd.service" "system"
  fi
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
    ["SNAPSHOT_FORMAT_CHOICE"]=0
    ["QUIET_MODE"]="yes"
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
# GRUB CONFIGURATION
# =============================================================================

update_grub_config() {
  printc -n cyan "Updating GRUB configuration... "

  if sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED to update GRUB config"
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
# BOOTLOADER-SPECIFIC SETUP
# =============================================================================

setup_limine() {
  printc cyan "Setting up Limine bootloader..."
  setup_limine_config_file
  configure_limine_settings
}

setup_grub() {
  printc cyan "Setting up GRUB bootloader..."
  update_grub_config
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Check if user wants to setup snapper
if echo && confirm "Setup Snapper for BTRFS snapshots?"; then
  printc_box "SNAPPER SETUP" "Configuring Snapper"

  bootloader=$(detect_bootloader)
  printc cyan "Bootloader detected: $bootloader"

  install_dependencies
  enable_snapper_services
  configure_snapper_cleanup
  create_updatedb

  # Bootloader-specific setup
  if [[ "$bootloader" == "limine" ]]; then
    setup_limine
  elif [[ "$bootloader" == "grub" ]]; then
    setup_grub
  fi

  printc green "Setup completed for $bootloader bootloader!"
else
  printc yellow "Skipping Snapper setup."
fi
