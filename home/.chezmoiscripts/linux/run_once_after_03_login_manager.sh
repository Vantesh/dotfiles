#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

# =============================================================================
# Initialize Environment
# =============================================================================
common_init

#===================================================================================
# Ly
#===================================================================================
print_box "smslant" "Ly"
print_step "Setting up Ly display manager"

readonly LY_CONFIG_FILE="/etc/ly/config.ini"
readonly LY_SAVE_FILE="/etc/ly/save.ini"

declare -A ly_config=(
  ["allow_empty_password"]="false"
  ["clear_password"]="true"
  # https://codeberg.org/fairyglade/ly/issues/811
  # issue fixed
  # ["path"]="null"
  ["bg"]="0"
  ["fg"]="8"
  ["bigclock"]="en"
  ["border_fg"]="8"
  ["sleep_cmd"]="systemctl suspend"
  ["session_log"]="/tmp/ly-session.log"
)

for key in "${!ly_config[@]}"; do
  update_config "$LY_CONFIG_FILE" "$key" "${ly_config[$key]}"
done

write_system_config "$LY_SAVE_FILE" "Ly session save file"  <<EOF
user=${USER}
session_index=2
EOF

enable_service "ly.service" "system"

if sudo systemctl disable getty@tty2.sevice >/dev/null 2>&1; then
  print_info "TTY2 service disabled successfully"
else
  print_warning "Failed to disable TTY2 service"
fi

