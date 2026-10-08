#!/usr/bin/env bash
# Transitional adapter for names selected by the remaining setup scripts.
# Static declarations live in mise.toml; mise owns all non-bootstrap installs.

export LAST_ERROR="${LAST_ERROR:-}"

install_package() {
  local package_name
  local -a specifications=()

  LAST_ERROR=""
  if [[ $# -eq 0 ]]; then
    LAST_ERROR="install_package() requires at least one package name"
    return 2
  fi

  case "${DISTRO_FAMILY:-}" in
    *[Aa][Rr][Cc][Hh]*) ;;
    *)
      LAST_ERROR="Unsupported or unset distro family: ${DISTRO_FAMILY:-}"
      return 1
      ;;
  esac

  if ! command_exists mise; then
    LAST_ERROR="Bootstrap invariant violated: mise is required; run the phase 00 prerequisite script first"
    return 127
  fi

  if ! command_exists pacman; then
    LAST_ERROR="pacman is required to inspect installed packages"
    return 127
  fi

  for package_name in "$@"; do
    # Preserve exact-name skipping for transitional runtime-selected packages.
    # Static aur: declarations intentionally use mise's foreign-package checks.
    if pacman -Qi -- "$package_name" >/dev/null 2>&1; then
      log SKIP "${COLOR_GREEN}${package_name}${COLOR_RESET} exists"
    elif pacman -Si -- "$package_name" >/dev/null 2>&1; then
      specifications+=("pacman:$package_name")
    else
      specifications+=("aur:$package_name")
    fi
  done

  [[ ${#specifications[@]} -gt 0 ]] || return 0

  # Explicit requests avoid applying unrelated static/global declarations.
  if ! mise --no-config bootstrap packages apply --yes "${specifications[@]}"; then
    LAST_ERROR="Failed to install selected packages with mise: ${specifications[*]}"
    return 1
  fi
}

install_group() {
  local group_name="$1"
  shift

  [[ $# -gt 0 ]] || return 0
  log STEP "Installing $group_name packages"

  if ! install_package "$@"; then
    die "$LAST_ERROR"
  fi
}
