#!/usr/bin/env bash

# Chezmoi bootstrap script
# Do not remove the env "NOT_PERSONAL=1" else some scripts will fail

set -euo pipefail
IFS=$'\n\t'

readonly INSTALLER_URL="https://git.io/chezmoi"
readonly DEFAULT_BIN_DIR="${HOME}/.local/bin"

logo() {
  printf '\033[1;36m'
  sed 's/^/  /' <<'EOF'

██╗  ██╗██╗   ██╗██████╗ ██████╗ ███╗   ██╗██╗██████╗ ██╗
██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗████╗  ██║██║██╔══██╗██║
███████║ ╚████╔╝ ██████╔╝██████╔╝██╔██╗ ██║██║██████╔╝██║
██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║╚██╗██║██║██╔══██╗██║
██║  ██║   ██║   ██║     ██║  ██║██║ ╚████║██║██║  ██║██║
╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝
EOF
  printf '\033[0m\n'
  printf "\033[1;32mWelcome to Hyprniri dotfiles installer!\033[0m\n"
  printf "\n"
}

log() {
  local type=$1 message=$2
  case "$type" in
  INFO) printf "\033[1;34mINFO\033[0m %s\n" "$message" >&2 ;;
  WARN) printf "\033[1;33mWARNING:\033[0m %s\n" "$message" >&2 ;;
  ERROR) printf "\033[1;31mERROR:\033[0m %s\n" "$message" >&2 ;;
  *) printf "%s\n" "$message" >&2 ;;
  esac
}

die() {
  log ERROR "$1"
  exit "${2:-1}"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

resolve_script_dir() {
  local source="${BASH_SOURCE[0]}"
  while [ -h "$source" ]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="${dir}/${source}"
  done
  cd -P "$(dirname "$source")" && pwd
}

install_chezmoi() {
  local bin_dir="$1"
  log INFO "Installing chezmoi to ${bin_dir}..."

  if command_exists curl; then
    curl -fsSL "${INSTALLER_URL}" | sh -s -- -b "$bin_dir"
  elif command_exists wget; then
    wget -qO- "${INSTALLER_URL}" | sh -s -- -b "$bin_dir"
  else
    die "Installation requires curl or wget."
  fi
}

ensure_chezmoi_installed() {
  local bin_dir="${DEFAULT_BIN_DIR}"
  local path

  if command_exists chezmoi; then
    path=$(command -v chezmoi)
    printf "%s\n" "$path"
    return
  fi

  mkdir -p "$bin_dir"
  install_chezmoi "$bin_dir"

  path="${bin_dir}/chezmoi"
  [ -x "$path" ] || die "chezmoi executable not found at ${path}"
  printf "%s\n" "$path"
}

backup_config_if_needed() {
  if [ ! -d "${HOME}/.config" ]; then
    log WARN "No ~/.config directory found; skipping backup."
    return
  fi

  log WARN "Detected existing ~/.config directory."
  local response=""
  local prompt
  prompt=$'\033[1;36mBack up existing ~/.config before continuing?\033[0m \033[1;33m[y/N]\033[0m '
  if ! read -rp "$prompt" response; then
    printf "\n"
    response=""
  fi

  case "$response" in
  [Yy] | [Yy]) ;;
  *)
    log INFO "Skipping backup of ~/.config."
    return
    ;;
  esac

  local timestamp backup_dir
  timestamp=$(date -u +%Y%m%d%H%M%S)
  backup_dir="${HOME}/.config.backup.${timestamp}"
  log INFO "Backup created at ${backup_dir}"
  mv "${HOME}/.config" "$backup_dir"
}

run_chezmoi_init() {
  local chezmoi_bin="$1"
  local script_dir
  script_dir=$(resolve_script_dir)
  printf "\n"
  exec env NOT_PERSONAL=1 "$chezmoi_bin" init --apply --source="$script_dir" "$@"
}

main() {
  local chezmoi_bin
  logo
  chezmoi_bin=$(ensure_chezmoi_installed)
  backup_config_if_needed
  run_chezmoi_init "$chezmoi_bin" "$@"
}

main "$@"
