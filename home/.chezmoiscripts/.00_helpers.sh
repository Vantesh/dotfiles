#!/bin/bash

# =============================================================================
# COLORS AND STYLING
# =============================================================================

# Color Map
# shellcheck disable=SC2034
declare -A COLORS=(
  [reset]='\033[0m'
  [red]='\033[0;31m'
  [green]='\033[0;32m'
  [yellow]='\033[0;33m'
  [blue]='\033[0;34m'
  [magenta]='\033[0;35m'
  [cyan]='\033[0;36m'
  [white]='\033[1;37m'
)

# =============================================================================
# OUTPUT AND MESSAGING FUNCTIONS
# =============================================================================

# Print colored messages with tag support
printc() {
  local newline=true
  local color_key=""

  # Check for -n flag to disable newline
  if [[ "$1" == "-n" ]]; then
    newline=false
    shift
  fi

  color_key="${1,,}"
  shift
  local str="$*"
  # Check if first word is a valid color tag
  local default_color="${COLORS[$color_key]}"
  if [[ -n "$default_color" ]]; then
    str="${default_color}${str}${COLORS[reset]}"
  else
    # First arg wasn't a color — treat as part of the string
    str="$color_key $str"
  fi

  # Parse color tags like <red>text</red>
  for color in "${!COLORS[@]}"; do
    str="${str//<$color>/${COLORS[$color]}}"
    str="${str//<\/$color>/${COLORS[reset]}}"
  done

  if [[ "$newline" == true ]]; then
    echo -e "$str"
  else
    printf "%b" "$str"
  fi
}

# Print boxed messages for cleaner output
printc_box() {
  local title="$1"
  local message="$2"

  echo
  gum style \
    --border normal \
    --margin "0" \
    --padding "0.1 0.1" \
    --border-foreground "#22d3ee" \
    "$(gum style --bold --foreground "#22d3ee" "$title")" \
    "$(gum style --foreground "#f783ac" "$message")"
  echo
}

# Safe exit with message
fail() {
  printc red "$1"
  exit "${2:-1}"
}

# Spinner function for showing install progress
spinner() {
  local pid=$1
  local pkg="$2"

  gum spin --spinner line --title "Installing $pkg..." -- sh -c "while kill -0 $pid 2>/dev/null; do sleep 0.1; done"
}

# =============================================================================
# VALIDATION AND UTILITY FUNCTIONS
# =============================================================================

# Check if command exists
has_cmd() {
  [[ -n "$1" ]] && command -v "$1" &>/dev/null
}

# Confirm action
confirm() {
  gum confirm --no-show-help --default=true "$1"
}

# Choice selection with gum styling
choice() {
  local prompt="$1"
  shift
  local options=("$@")
  gum choose \
    --no-show-help \
    --cursor="* " \
    --header="$prompt" "${options[@]}"
}

# Ask for sudo privileges (replaces ensure_sudo)
ask_for_sudo() {
  sudo -n true 2>/dev/null || {
    printc cyan "This script requires sudo privileges\n"
    sudo -v
  }
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
}

is_laptop() {
  for bat in /sys/class/power_supply/BAT*; do
    [[ -d "$bat" ]] && return 0
  done
  [[ -d /proc/acpi/battery ]] && return 0
  return 1
}

# =============================================================================
# PACKAGE MANAGEMENT FUNCTIONS
# =============================================================================
install_package() {
  local pkg="$1"
  local installer query_cmd install_cmd

  if [[ -n "${AUR_HELPER:-}" ]] && command -v "$AUR_HELPER" &>/dev/null; then
    installer="$AUR_HELPER"
    query_cmd=("$installer" "-Qi")
    install_cmd=("$installer" "-S" "--needed" "--noconfirm")
  else
    installer="pacman"
    query_cmd=("sudo" "$installer" "-Qi")
    install_cmd=("sudo" "$installer" "-S" "--needed" "--noconfirm")
  fi

  if "${query_cmd[@]}" "$pkg" &>/dev/null; then
    printc "<cyan>$pkg</cyan> <green>exists</green>"
    return 0
  else
    "${install_cmd[@]}" "$pkg" &>/dev/null &
    local pid=$!
    spinner "$pid" "$pkg"
    wait "$pid"
    local status=$?

    if ((status == 0)); then
      printc "<cyan>$pkg</cyan> <green>installed</green>"
    else
      printc "<red>$pkg</red> <yellow>failed to install</yellow>"
      return 1
    fi
  fi
}

# =============================================================================
# CONFIGURATION MANAGEMENT FUNCTIONS
# =============================================================================

# Update config file key-value pairs
update_config() {
  local config_file="$1"
  local key="$2"
  local value="$3"

  # Ensure the file exists
  if [[ ! -f "$config_file" ]]; then
    sudo touch "$config_file"
    sudo chown root:root "$config_file"
    sudo chmod 644 "$config_file"
  fi

  # Escape square brackets in the key for regex matching if they exist
  local escaped_key="$key"
  if [[ "$key" == *"["* && "$key" == *"]"* ]]; then
    escaped_key=$(printf '%s\n' "$key" | sed 's/\[/\\[/g; s/\]/\\]/g')
  fi

  # Check if the key exists (commented or not, with or without spacing)
  if sudo grep -qE "^\s*#*\s*${escaped_key}\s*=" "$config_file"; then

    if sudo sed -i -E "s|^\s*#*\s*(${escaped_key})(\s*)=(\s*).*|\1\2=\3${value}|" "$config_file"; then
      return 0
    else
      fail "Failed to update $key"
    fi
  else
    if echo -e "\n${key}=${value}" | sudo tee -a "$config_file" >/dev/null; then
      return 0
    else
      fail "Failed to append $key"
    fi
  fi
}

# Set snapper config value
set_snapper_config_value() {
  local config_name="$1"
  local key="$2"
  local value="$3"

  if ! sudo snapper list-configs | grep -q "^$config_name"; then
    if [ "$config_name" = "root" ]; then
      sudo snapper -c "$config_name" create-config /
    elif [ "$config_name" = "home" ]; then
      sudo snapper -c "$config_name" create-config /home
    else
      printc yellow "Snapper config '$config_name' does not exist. Create it first."
      return 1
    fi
  fi

  if sudo snapper -c "$config_name" set-config "${key}=${value}"; then
    return 0
  else
    fail "Failed to set $key in snapper config '$config_name'"
  fi
}

write_system_config() {
  local config_file="$1"
  local description="$2"
  shift 2

  printc -n cyan "Writing $description... "

  if sudo mkdir -p "$(dirname "$config_file")" && sudo tee "$config_file" >/dev/null; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

# =============================================================================
# SYSTEM SERVICE MANAGEMENT FUNCTIONS
# =============================================================================

# Enable systemd services
enable_service() {
  local service="$1" scope="$2"
  local prefix=()
  local cmd=("systemctl")

  if [[ $scope == "user" ]]; then
    cmd+=("--user")
  else
    prefix=(sudo)
  fi

  # Handle template services (services with @)
  local template_service=""
  if [[ "$service" == *@*.service ]]; then
    template_service="${service%@*}@.service"
  fi

  # Check if service or template exists
  local service_exists=false
  if "${prefix[@]}" "${cmd[@]}" list-unit-files | grep -q "^$service" ||
    [[ -n "$template_service" ]] && "${prefix[@]}" "${cmd[@]}" list-unit-files | grep -q "^$template_service"; then
    service_exists=true
  elif [[ -n "$template_service" ]] && [[ -f "/etc/systemd/system/$template_service" || -f "/usr/lib/systemd/system/$template_service" ]]; then
    service_exists=true
  fi

  if [[ "$service_exists" == true ]]; then
    # Skip if already enabled
    if "${prefix[@]}" "${cmd[@]}" is-enabled "$service" &>/dev/null; then
      printc "<magenta>[$scope]</magenta> <yellow>$service</yellow> <green>already enabled</green>"
    else
      if "${prefix[@]}" "${cmd[@]}" enable "$service" &>/dev/null; then
        printc "<cyan>[$scope]</cyan> <green>Enabled $service</green>"
      else
        fail "[$scope] Failed to enable $service"
      fi
    fi
  else
    printc yellow "[$scope] Not found: $service"
  fi
}

disable_service() {
  local service="$1" scope="$2"
  local prefix=()
  local cmd=("systemctl")

  if [[ $scope == "user" ]]; then
    cmd+=("--user")
  else
    prefix=(sudo)
  fi

  if "${prefix[@]}" "${cmd[@]}" is-enabled "$service" >/dev/null 2>&1; then
    if "${prefix[@]}" "${cmd[@]}" disable "$service" >/dev/null 2>&1; then
      printc "<cyan>[$scope]</cyan> <green>Disabled $service</green>"
    else
      fail "[$scope] Failed to disable $service"
    fi
  else
    printc "<magenta>[$scope]</magenta> <yellow>$service</yellow> <green>already disabled</green>"
  fi
}

# =============================================================================
# BACKUP AND FILE MANAGEMENT FUNCTIONS
# =============================================================================

# Backup with timestamp
backup_with_timestamp() {
  local src="$1"
  local dest="$2"

  if [[ ! -d "$dest" ]]; then
    printc yellow "Destination directory $dest does not exist. Creating it..."
    mkdir -p "$dest" || {
      printc red "Failed to create destination directory $dest."
      return 1
    }
  fi

  local timestamp
  local backup_name
  local backup_path

  timestamp=$(date +"%Y%m%d_%H%M%S")
  backup_name="$(basename "$src")_backup_$timestamp"
  backup_path="$dest/$backup_name"

  if [[ -d "$src" ]]; then
    if cp -r "$src" "$backup_path"; then
      printc green "Backup created at $backup_path"
      return 0
    else
      fail "Failed to create directory backup."
    fi
  elif [[ -f "$src" ]]; then
    if cp "$src" "$backup_path"; then
      printc green "Backup created at $backup_path"
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

# =============================================================================
# INITRAMFS REGENERATION FUNCTION
# =============================================================================

# Regenerate initramfs using the appropriate tool
regenerate_initramfs() {
  printc -n cyan "Regenerating initramfs..."

  if has_cmd limine-mkinitcpio; then
    if sudo limine-mkinitcpio >/dev/null 2>&1; then
      printc green "OK"
    else
      fail "limine-mkinitcpio"
    fi

  elif has_cmd mkinitcpio; then
    if sudo mkinitcpio -P >/dev/null 2>&1; then
      printc green "OK"
    else
      printc yellow "Run 'sudo mkinitcpio -P' manually to regenerate initramfs."
    fi

  else
    fail "Neither limine-mkinitcpio nor mkinitcpio found."
  fi
}

reload_systemd_daemon() {
  printc -n cyan "Reloading systemd daemon... "
  if sudo systemctl daemon-reload; then
    printc green "OK"
  else
    printc yellow "FAILED"
  fi
}

reload_udev_rules() {
  printc -n cyan "Reloading udev rules... "
  if sudo udevadm control --reload-rules && sudo udevadm trigger; then
    printc green "OK"
  else
    printc yellow "FAILED"
  fi
}

# =============================================================================
# BOOTLOADER DETECTION AND MANAGEMENT
# =============================================================================

detect_limine_bootloader() {
  has_cmd limine || [[ -x /usr/bin/limine ]]
}

detect_bootloader() {
  if detect_limine_bootloader; then
    echo "limine"
  elif has_cmd grub-mkconfig && [[ -f /etc/default/grub ]]; then
    echo "grub"
  else
    echo "unknown"
  fi
}

# =============================================================================
# BOOTLOADER CONFIGURATION FUNCTIONS
# =============================================================================

update_grub_cmdline() {
  local params="$1"
  local grub_file="/etc/default/grub"

  printc -n cyan "Updating GRUB configuration... "
  local current_cmdline
  current_cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" | sed 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/')

  read -ra param_array <<<"$params"
  local updated_cmdline="$current_cmdline"

  for param in "${param_array[@]}"; do
    # Extract parameter name (before = or the whole param if no =)
    local param_name
    if [[ "$param" == *"="* ]]; then
      param_name="${param%%=*}"
    else
      param_name="$param"
    fi
    # Remove existing instances of this parameter
    updated_cmdline=$(echo "$updated_cmdline" | sed -E "s/(^|[[:space:]])${param_name}(=[^[:space:]]*)?([[:space:]]|$)/ /g")
  done

  updated_cmdline="$updated_cmdline $params"

  # Clean up spacing and remove any remaining duplicates
  updated_cmdline=$(echo "$updated_cmdline" | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//; s/ *$//')

  # Update the GRUB file
  if sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$updated_cmdline\"|" "$grub_file"; then
    printc green "OK"
    if sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
      return 0
    else
      fail "Failed to update GRUB configuration"
    fi
  else
    fail "Failed to update GRUB cmdline"
  fi
}

update_limine_cmdline() {
  local params="$1"
  local limine_cfg="/boot/limine.cfg"

  printc -n cyan "Updating Limine configuration... "

  if [[ ! -f "$limine_cfg" ]]; then
    printc yellow "Limine config not found at $limine_cfg"
    return 1
  fi

  # Read current cmdline parameters
  local current_cmdline
  current_cmdline=$(grep -E "^[[:space:]]*CMDLINE=" "$limine_cfg" | head -1 | sed 's/^[[:space:]]*CMDLINE=//')

  read -ra param_array <<<"$params"
  local updated_cmdline="$current_cmdline"

  for param in "${param_array[@]}"; do
    # Extract parameter name (before = or the whole param if no =)
    local param_name
    if [[ "$param" == *"="* ]]; then
      param_name="${param%%=*}"
    else
      param_name="$param"
    fi
    # Remove existing instances of this parameter
    updated_cmdline=$(echo "$updated_cmdline" | sed -E "s/(^|[[:space:]])${param_name}(=[^[:space:]]*)?([[:space:]]|$)/ /g")
  done

  updated_cmdline="$updated_cmdline $params"

  # Clean up spacing
  updated_cmdline=$(echo "$updated_cmdline" | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//; s/ *$//')

  # Update the Limine config
  if sudo sed -i "s|^[[:space:]]*CMDLINE=.*|CMDLINE=$updated_cmdline|" "$limine_cfg"; then
    printc green "OK"
  else
    fail "Failed to update Limine cmdline"
  fi
}

# Harden /boot mount options in fstab
harden_boot_fstab() {
  printc -n cyan "Hardening /boot mount options in fstab... "
  if sudo sed -i '/[[:space:]]\/boot[[:space:]]/s|vfat[[:space:]].*|vfat defaults,umask=0077 0 2|' /etc/fstab; then
    printc green "OK"
  else
    printc yellow "Failed to harden /boot mount options."
  fi
}

initialize_environment() {
  clear
  apps=(
    "git"
    "gum"
  )

  for app in "${apps[@]}"; do
    if ! has_cmd "$app"; then
      printc -n cyan "Installing $app... "
      sudo pacman -S --noconfirm "$app" &>/dev/null
      if has_cmd "$app"; then
        printc green "OK"
      else
        printc yellow "Failed to install $app."
      fi
    fi
  done

  # Check if running on TTY and configure console font
  if [[ $(tty) =~ ^/dev/tty[0-9]+$ ]]; then
    printc -n cyan "Installing and setting TTY console font..."
    if sudo pacman -S --noconfirm terminus-font &>/dev/null; then
      if sudo setfont ter-122b &>/dev/null; then
        printc green "OK"
      else
        printc yellow "Font installed but failed to set ter-124b"
      fi
    else
      printc yellow "Failed to install terminus-font"
    fi
  fi
}

update_kernel_cmdline() {
  local params="$1"
  local bootloader
  bootloader=$(detect_bootloader)

  case "$bootloader" in
  "limine")
    update_limine_cmdline "$params"
    ;;
  "grub")
    update_grub_cmdline "$params"
    ;;
  *)
    printc yellow "Unknown bootloader, skipping kernel parameter update"
    ;;
  esac
}

edit_grub_config() {
  local grub_file="/etc/default/grub"
  declare -A grub_config=(
    ["GRUB_TIMEOUT"]="2"
    ["GRUB_DEFAULT"]="0"
  )
  success=true
  printc -n cyan "Editing GRUB configuration... "
  for key in "${!grub_config[@]}"; do
    if ! update_config "$grub_file" "$key" "${grub_config[$key]}"; then
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
