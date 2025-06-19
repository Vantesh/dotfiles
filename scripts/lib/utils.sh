#!/bin/bash

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

ensure_sudo() {
  if ! sudo -n true 2>/dev/null; then
    sudo -v
  fi
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
      fail "Failed to install $pkg."
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
      return 0
    else
      fail "limine-mkinitcpio"
    fi

  elif has_cmd mkinitcpio; then
    sync
    sleep 1
    if sudo mkinitcpio -P >/dev/null 2>&1; then
      printc green "OK"
      return 0
    else
      printc yellow "Run 'sudo mkinitcpio -P' manually to regenerate initramfs."
      return 0
    fi

  else
    fail "Neither limine-mkinitcpio nor mkinitcpio found."
  fi
}
