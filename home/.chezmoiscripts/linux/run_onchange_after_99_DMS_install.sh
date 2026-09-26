#!/usr/bin/env bash
# 99_DMS_install.sh - Install DankMaterialShell headlessly
#
# Runs the official DankLinux installer without prompts for the local Hyprland
# and Kitty setup.
#
# Exit codes:
#   0 (success), 1 (failure), 127 (missing dependency)

set -euo pipefail

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"
readonly DANK_INSTALL_URL="https://install.danklinux.com"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

main() {

	if command_exists dms; then
		log INFO "DankMaterialShell is already installed"
		return 0
	fi

	if ! command_exists curl; then
		die 127 "curl is required to install DankMaterialShell"
	fi

	if ! keep_sudo_alive; then
		die "Failed to obtain sudo access: $LAST_ERROR"
	fi

	log STEP "Installing DankMaterialShell"

	if ! curl -fsSL "$DANK_INSTALL_URL" | sh -s -- \
		--compositor hyprland \
		--term kitty \
		--danksearch \
		--dankcalendar \
		--yes; then
		die "DankMaterialShell installation failed"
	fi

	log INFO "Installed DankMaterialShell"
}

main "$@"
