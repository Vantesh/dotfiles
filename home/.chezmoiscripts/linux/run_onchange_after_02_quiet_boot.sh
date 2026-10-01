#!/usr/bin/env bash
# 02_quiet_boot.sh - Configure quiet boot parameters
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-snapboot.sh"

readonly QUIET_BOOT_PARAMS="quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.cur_default=1"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

# Remove quiet boot parameters from a command line string
remove_quiet_boot_params() {
  sed -E 's/\b(quiet|splash|loglevel=[0-9]+|systemd\.show_status=[a-z]+|rd\.udev\.log_level=[0-9]+|vt\.cur_default=[0-9]+)\b//g; s/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$1"
}

update_bootloader_params() {
  local bootloader

  if ! bootloader=$(detect_bootloader); then
    die "Failed to detect bootloader: $LAST_ERROR"
  fi

  case "$bootloader" in
  grub)
    log INFO "Updating GRUB kernel parameters"
    if ! update_grub_cmdline "$QUIET_BOOT_PARAMS"; then
      die "Failed to update GRUB kernel parameters: $LAST_ERROR"
    else
      log INFO "Updated GRUB kernel parameters"
    fi
    ;;
  limine)
    if [[ ! -f /etc/limine-entry-tool.d/01-default.conf ]]; then
      if [[ -r /proc/cmdline ]]; then
        local cleaned_params
        cleaned_params=$(remove_quiet_boot_params "$(cat /proc/cmdline)")

        if [[ -n "$cleaned_params" ]]; then
          if ! update_limine_cmdline "01-default.conf" "$cleaned_params"; then
            die "Failed to create default Limine config: $LAST_ERROR"
          fi
        fi
      else
        log WARN "/proc/cmdline not readable; cannot create default Limine drop-in"
      fi
    fi

    if ! update_limine_cmdline "20-quiet-boot.conf" --append "$QUIET_BOOT_PARAMS"; then
      die "Failed to write Limine quiet boot config: $LAST_ERROR"
    fi
    log INFO "Updated Limine kernel parameters"
    ;;
  *)
    log WARN "Unsupported bootloader ($bootloader), skipping kernel parameter update"
    ;;
  esac
}

main() {
  print_box "Quiet Boot"
  log STEP "Quiet Boot Configuration"
  update_bootloader_params
  log INFO "Quiet boot configuration complete"
}

main "$@"
