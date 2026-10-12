#!/usr/bin/env bash
# Transitional adapter for legacy NVIDIA installed/repository-origin handling.
# Fixed groups live in mise/conf.d/packages.toml; exact header pairs use pacman.

export LAST_ERROR="${LAST_ERROR:-}"

install_package() {
  local package_name
  local -a specifications=()

  LAST_ERROR=""
  if [[ $# -eq 0 ]]; then
    LAST_ERROR="install_package() requires at least one package name"
    return 2
  fi

  for package_name in "$@"; do
    # Keep this skip: native AUR checks only consider foreign packages.
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
