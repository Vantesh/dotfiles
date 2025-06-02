#!/bin/bash

# --- Load color map ---
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/colors.sh"
# --- Print colored messages ---
printc() {
  local color_key="${1,,}"
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

  echo -e "$str"
}

# --- Check if command exists ---
has_cmd() {
  command -v "$1" &>/dev/null
}

# --- Confirm action ---
confirm() {
  read -rp "$(printc yellow "$1 [Y/n]: ")" response
  [[ -z "$response" || "$response" =~ ^[Yy]$ ]]
}

# --- Safe exit with message ---
fail() {
  printc red "$1"
  exit "${2:-1}"
}
# --- Ensure sudo is ready before background processes ---
ensure_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo
    sudo -v
  fi
}

# --- Spinner function for showing install progress ---
spinner() {
  local pid=$1
  local pkg="$2"
  local delay=0.15
  local spinchars=('|' '/' '-' '\\')

  local cyan='\033[1;36m'
  local reset='\033[0m'

  while kill -0 "$pid" 2>/dev/null; do
    for char in "${spinchars[@]}"; do
      printf "\r%s Installing %b%s%b... " "$char" "$cyan" "$pkg" "$reset"
      sleep $delay
    done
  done

  printf "\r\033[K" # Clear spinner line
}

# --- Install package using AUR ---
install_package() {
  local pkg="$1"

  if "$AUR_HELPER" -Qi "$pkg" &>/dev/null; then
    printc "<cyan>$pkg</cyan> <green>is already installed</green>"
    return 0
  else
    ensure_sudo # ensure sudo won't interrupt the spinner

    "$AUR_HELPER" -S --needed --noconfirm "$pkg" &>/dev/null &
    local pid=$!

    spinner "$pid" "$pkg"
    wait "$pid"
    local status=$?

    if ((status == 0)); then
      printc "<cyan>$pkg</cyan> <green>has been installed</green>"
    else
      fail "Failed to install $pkg."
    fi
  fi
}

# --- Update config file ---
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
      printc green "Updated $key to $value in $config_file"
    else
      fail "Failed to update $key"
    fi
  else
    if echo -e "\n${key}=${value}" | sudo tee -a "$config_file" >/dev/null; then
      printc green "Appended $key=${value} to $config_file"
    else
      fail "Failed to append $key"
    fi
  fi
}

# --- Set snapper config value ---
set_snapper_config_value() {
  local config_name="$1"
  local key="$2"
  local value="$3"

  if ! sudo snapper list-configs | grep -q "^$config_name"; then
    if [ "$config_name" = "root" ]; then
      sudo snapper create-config -c "$config_name" /
    elif [ "$config_name" = "home" ]; then
      sudo snapper create-config -c "$config_name" /home
    else
      printc yellow "Snapper config '$config_name' does not exist. Create it first."
      return 1
    fi

  fi

  if sudo snapper -c "$config_name" set-config "${key}=${value}"; then
    printc green "Set $key=$value in snapper config '$config_name'"
  else
    fail "Failed to set $key in snapper config '$config_name'"
  fi
}

# --- enable services ---

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

      printc "<yellow>[$scope]</yellow> <white>Already enabled: $service</white>"

    else
      if "${prefix[@]}" "${cmd[@]}" enable --now "$service" &>/dev/null; then
        printc "<cyan>[$scope]</cyan> <green>Enabled $service</green>"
      else
        fail "[$scope] Failed to enable $service"
      fi
    fi
  else
    printc yellow "[$scope] Not found: $service"
  fi
}

is_btrfs() {
  findmnt -n -o FSTYPE / | grep -q btrfs
}
