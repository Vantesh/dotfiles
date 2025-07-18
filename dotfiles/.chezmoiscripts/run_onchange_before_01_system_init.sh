#!/bin/bash

# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/.00_helpers.sh"

# ===================== SUDO CONFIG =====================
configure_sudo_timeout() {
  printc -n cyan "Disabling sudo password prompt timeout... "
  local sudoers_config="/etc/sudoers.d/timeout"
  if echo "Defaults passwd_timeout=0" | sudo tee "$sudoers_config" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_sudo_insults() {
  printc -n cyan "Enabling sudo insults... "
  local sudoers_config="/etc/sudoers.d/insults"
  if echo "Defaults insults" | sudo tee "$sudoers_config" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_sudo_pwfeedback() {
  printc -n cyan "Enabling sudo password feedback... "
  local sudoers_config="/etc/sudoers.d/pwfeedback"
  if echo "Defaults pwfeedback" | sudo tee "$sudoers_config" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_faillock() {
  declare -A faillock_config=(
    [deny]="10"
    [unlock_time]="300"
    [fail_interval]="900"
  )
  printc -n cyan "Configuring faillock settings... "
  local success=true
  for key in "${!faillock_config[@]}"; do
    if ! update_config "/etc/security/faillock.conf" "$key" "${faillock_config[$key]}"; then
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

# ===================== PACMAN CONFIG =====================
readonly PACMAN_CONFIG="/etc/pacman.conf"
readonly PACMAN_BACKUP="${PACMAN_CONFIG}.bak"
readonly PACMAN_OPTIONS=("Color" "VerbosePkgLists" "ILoveCandy")

deps=(
  "pacman-contrib"
  "reflector"
)
for dep in "${deps[@]}"; do
  install_package "$dep"
done

validate_pacman_config() {
  [[ -f "$PACMAN_CONFIG" ]] || fail "pacman.conf not found at $PACMAN_CONFIG"
}

create_pacman_backup() {
  printc -n cyan "Backing up pacman.conf... "
  if sudo cp "$PACMAN_CONFIG" "$PACMAN_BACKUP"; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

enable_pacman_option() {
  local option="$1"
  printc -n cyan "Enabling $option... "
  if sudo grep -q "^\s*$option\s*$" "$PACMAN_CONFIG"; then
    printc yellow "Exists"
  elif sudo grep -q "^\s*#\s*$option" "$PACMAN_CONFIG"; then
    sudo sed -i "s/^\s*#\s*${option}/${option}/" "$PACMAN_CONFIG" && printc green "OK"
  elif [[ "$option" == "ILoveCandy" ]]; then
    sudo sed -i "/^\s*Color/a $option" "$PACMAN_CONFIG" && printc green "OK"
  else
    printc yellow "not found"
  fi
}

setup_chaotic_aur() {
  printc cyan "Setting up Chaotic AUR repository..."
  printc -n cyan "Installing Chaotic AUR keyring and mirrorlist... "
  if sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com &>/dev/null &&
    sudo pacman-key --lsign-key 3056513887B78AEB &>/dev/null &&
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
  printc -n cyan "Adding Chaotic AUR to pacman.conf... "
  if ! sudo grep -q "[chaotic-aur]" "$PACMAN_CONFIG"; then
    if echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a "$PACMAN_CONFIG" >/dev/null; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "already present"
  fi
  printc -n cyan "Updating package databases... "
  if sudo pacman -Syy --noconfirm &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
}

configure_paccache() {
  printc -n cyan "Configuring paccache arguments... "
  local paccache_config="/etc/conf.d/pacman-contrib"
  if update_config "$paccache_config" "PACCACHE_ARGS" "'-k1'"; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
  enable_service "paccache.timer" "system"
}

pacman_hooks() {
  write_system_config "/etc/pacman.d/hooks/00-paccache.hook" "Paccache hook" <<EOF
[Trigger]
Type = Package
Operation = Remove
Operation = Install
Operation = Upgrade
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk1
Depends = pacman-contrib
EOF
  write_system_config "/etc/pacman.d/hooks/01-paccache-uninstalled.hook" "Paccache uninstalled hook" <<EOF
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache for uninstalled packages...
When = PostTransaction
Exec = /usr/bin/paccache -ruk0
Depends = pacman-contrib
EOF
}

update_mirrorlist() {
  printc -n cyan "Backing up current mirrorlist... "
  if sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
  printc -n cyan "Generating new mirrorlist... "
  if sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    sudo cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
    return 1
  fi
  enable_service "reflector.timer" "system"
}

configure_pacman() {
  validate_pacman_config
  create_pacman_backup
  for option in "${PACMAN_OPTIONS[@]}"; do
    enable_pacman_option "$option"
  done
  configure_paccache
  pacman_hooks
  if echo && confirm "Do you want to update mirrorlist?"; then
    update_mirrorlist
  else
    printc yellow "Skipping mirrorlist update."
  fi
  if echo && confirm "Do you want to setup Chaotic AUR repository?"; then
    setup_chaotic_aur
  else
    printc yellow "Skipping Chaotic AUR setup."
  fi
}

# ===================== AUR HELPER =====================
readonly AVAILABLE_AUR_HELPERS=("yay" "paru")

get_user_choice() {
  AUR_HELPER=$(choice "Choose your preferred AUR helper:" "${AVAILABLE_AUR_HELPERS[@]}") || {
    fail "No AUR helper selected. Exiting."
  }
}

has_chaotic_aur() {
  grep -q "chaotic-aur" /etc/pacman.conf
}

clone_aur_helper_repository() {
  local temp_dir="$1"
  git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$temp_dir" &>/dev/null || {
    rm -rf "$temp_dir"
    fail "Failed to clone $AUR_HELPER repository."
  }
}

build_and_install_aur_helper() {
  local temp_dir="$1"
  pushd "$temp_dir" &>/dev/null || {
    rm -rf "$temp_dir"
    fail "Failed to enter $temp_dir"
  }
  if makepkg -si --noconfirm &>/dev/null; then
    popd &>/dev/null || exit
  else
    popd &>/dev/null || exit
    rm -rf "$temp_dir"
    fail "Failed to build and install $AUR_HELPER."
  fi
}

install_aur_helper() {
  if has_cmd "$AUR_HELPER"; then
    printc green "$AUR_HELPER is already installed"
    return
  fi
  if has_chaotic_aur; then
    printc -n cyan "Installing $AUR_HELPER from Chaotic AUR repository..."
    if sudo pacman -S --noconfirm "$AUR_HELPER" &>/dev/null; then
      printc green "OK"
      return
    else
      printc yellow "Failed to install from repository, falling back to manual build."
    fi
  fi
  printc cyan "Building $AUR_HELPER from source..."
  local temp_dir
  temp_dir=$(mktemp -d) || fail "Failed to create temporary directory."
  clone_aur_helper_repository "$temp_dir"
  pushd "$temp_dir" &>/dev/null || exit
  build_and_install_aur_helper "$temp_dir"
  popd &>/dev/null || exit
  printc green "$AUR_HELPER installed successfully."
  rm -rf "$temp_dir"
}

configure_paru() {
  if [[ "$AUR_HELPER" == "paru" ]]; then
    printc -n cyan "Configuring paru... "
    if ! sudo sed -i 's/^#BottomUp/BottomUp/' /etc/paru.conf; then
      fail "Fail"
    fi
    printc green "OK"
  fi
}

sync_aur_database() {
  printc -n cyan "Synchronizing database..."
  "$AUR_HELPER" -Sy --noconfirm &>/dev/null || {
    fail "Failed"
  }
  printc green "OK"
}

# ===================== MAIN =====================
if [[ "$(id -u)" -eq 0 ]]; then
  fail
fi

ask_for_sudo
initialize_environment
printc_box "SYSTEM INIT" "Configuring system (sudo, pacman, AUR)"
configure_sudo_timeout
configure_sudo_insults
configure_sudo_pwfeedback
configure_faillock
printc_box "PACMAN" "Configuring Pacman"
configure_pacman
printc_box "AUR HELPER" "Configuring AUR helper"
echo
get_user_choice
install_aur_helper
configure_paru
sync_aur_database
