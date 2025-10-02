#!/usr/bin/env bash

# Return Codes:
#   0 - Success
#   1 - Operation failed (details in LAST_ERROR)
#   2 - Invalid arguments
#
set -euo pipefail

export LAST_ERROR="${LAST_ERROR:-}"

RPMFUSION_FREE="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
RPMFUSION_NONFREE="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# COPR repositories to enable
COPR_REPOS=(
  solopasha/hyprland
  errornointernet/quickshell
  tofik/nwg-shell
  lihaohong/yazi
  alternateved/eza
)

install_rpm_from_url() {
  local url="${1:-}"

  # Clear previous error
  LAST_ERROR=""

  if [[ -z "$url" ]]; then
    LAST_ERROR="install_rpm_from_url() requires a URL"
    return 2
  fi

  local pkg_name
  pkg_name="$(basename "$url" .noarch.rpm)"

  if rpm -q "$pkg_name" >/dev/null 2>&1; then
    return 0
  fi

  if ! sudo dnf install -y "$url" >/dev/null 2>&1; then
    LAST_ERROR="Failed to install RPM from $url"
    return 1
  fi

  return 0
}

copr_repo_enabled() {
  local repo="${1:-}"

  LAST_ERROR=""

  if [[ -z "$repo" ]]; then
    LAST_ERROR="copr_repo_enabled() requires a repo name"
    return 2
  fi

  local repo_id="${repo/\//:}"
  sudo dnf repolist all 2>/dev/null | grep -q "^copr:copr.fedorainfracloud.org:${repo_id}"
}

enable_copr_repo() {
  local repo="${1:-}"

  LAST_ERROR=""

  if [[ -z "$repo" ]]; then
    LAST_ERROR="enable_copr_repo() requires a repo name"
    return 2
  fi

  if copr_repo_enabled "$repo"; then
    return 0
  fi

  if ! sudo dnf copr enable -y "$repo" >/dev/null 2>&1; then
    LAST_ERROR="Failed to enable COPR repo: $repo"
    return 1
  fi

  return 0
}

setup_rpmfusion() {
  LAST_ERROR=""

  # Install RPM Fusion Free
  if ! install_rpm_from_url "$RPMFUSION_FREE"; then
    return 1
  fi

  # Install RPM Fusion Nonfree
  if ! install_rpm_from_url "$RPMFUSION_NONFREE"; then
    return 1
  fi

  return 0
}

setup_copr_repos() {
  LAST_ERROR=""

  # Ensure dnf-plugins-core is installed
  if ! rpm -q dnf-plugins-core >/dev/null 2>&1; then
    if ! sudo dnf install -y dnf-plugins-core >/dev/null 2>&1; then
      LAST_ERROR="Failed to install dnf-plugins-core"
      return 1
    fi
  fi

  local failed_repos=()
  for repo in "${COPR_REPOS[@]}"; do
    if ! enable_copr_repo "$repo"; then
      failed_repos+=("$repo")
    fi
  done

  if [[ ${#failed_repos[@]} -gt 0 ]]; then
    LAST_ERROR="Failed to enable COPR repos: ${failed_repos[*]}"
    return 1
  fi

  return 0
}
