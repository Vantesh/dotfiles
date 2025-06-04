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
  local width=30

  # Calculate padding for centering
  local title_len=${#title}
  local message_len=${#message}
  local max_len=$((title_len > message_len ? title_len : message_len))

  # Adjust width if content is longer but keep it reasonable
  if ((max_len + 6 > width)); then
    width=$((max_len + 6))
    if ((width > 70)); then
      width=70
    fi
  fi

  local title_padding=$(((width - title_len - 2) / 2))
  local message_padding=$(((width - message_len - 2) / 2))

  # Create box components
  local top_border
  top_border="┌$(printf '─%.0s' $(seq 1 $((width - 2))))┐"
  local bottom_border
  bottom_border="└$(printf '─%.0s' $(seq 1 $((width - 2))))┘"
  local empty_line
  empty_line="│$(printf ' %.0s' $(seq 1 $((width - 2))))│"

  echo
  echo -e "${COLORS[cyan]}${top_border}${COLORS[reset]}"
  if [[ -n "$title" ]]; then
    # Bold cyan title
    echo -e "${COLORS[cyan]}│$(printf ' %.0s' $(seq 1 $title_padding))${COLORS[cyan]}${COLORS[bold]}${title}${COLORS[reset]}${COLORS[cyan]}$(printf ' %.0s' $(seq 1 $((width - title_len - title_padding - 2))))│${COLORS[reset]}"
    if [[ -n "$message" ]]; then
      echo -e "${COLORS[cyan]}${empty_line}${COLORS[reset]}"
      # Magenta message
      echo -e "${COLORS[cyan]}│$(printf ' %.0s' $(seq 1 $message_padding))${COLORS[magenta]}${message}${COLORS[cyan]}$(printf ' %.0s' $(seq 1 $((width - message_len - message_padding - 2))))│${COLORS[reset]}"
    fi
  elif [[ -n "$message" ]]; then
    echo -e "${COLORS[cyan]}│$(printf ' %.0s' $(seq 1 $message_padding))${COLORS[magenta]}${message}${COLORS[cyan]}$(printf ' %.0s' $(seq 1 $((width - message_len - message_padding - 2))))│${COLORS[reset]}"
  fi
  echo -e "${COLORS[cyan]}${bottom_border}${COLORS[reset]}"
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
  local delay=0.15
  local spinchars=('|' '/' '-' '\')

  local cyan='\033[1;36m'
  local reset='\033[0m'

  while kill -0 "$pid" 2>/dev/null; do
    for char in "${spinchars[@]}"; do
      printf "\r%s Installing %b%s%b... " "$char" "$cyan" "$pkg" "$reset"
      sleep $delay
    done
  done

  printf "\r\033[K" # Clear spinner line
  printf "\n"       # Add newline for any potential sudo prompts
}

# =============================================================================
# VALIDATION AND UTILITY FUNCTIONS
# =============================================================================

# Check if command exists
has_cmd() {
  command -v "$1" &>/dev/null
}

# Confirm action
confirm() {
  echo
  read -rp "$(printc magenta "$1 [Y/n]: ")" response
  [[ -z "$response" || "$response" =~ ^[Yy]$ ]]
}

ensure_sudo() {
  if ! sudo -n true 2>/dev/null; then
    sudo -v
  fi
}

# =============================================================================
# PACKAGE MANAGEMENT FUNCTIONS
# =============================================================================

# Install package using AUR helper
install_package() {
  local pkg="$1"

  if "$AUR_HELPER" -Qi "$pkg" &>/dev/null; then
    printc "<cyan>$pkg</cyan> <green>exists</green>"
    return 0
  else
    "$AUR_HELPER" -S --needed --noconfirm "$pkg" &>/dev/null &
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

  # Check if the key exists (commented or not, with or without spacing)
  if sudo grep -qE "^\s*#*\s*${key}\s*=" "$config_file"; then
    # Update in place, preserving original spacing
    if sudo sed -i -E "s|^\s*#*\s*(${key})(\s*)=(\s*).*|\1\2=\3${value}|" "$config_file"; then
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

  # Check if service exists in the scope
  if "${prefix[@]}" "${cmd[@]}" list-unit-files | grep -q "^$service"; then
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
