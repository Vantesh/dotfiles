#!/usr/bin/env bash
# .lib-fedora_repos.sh - Fedora repository configuration
#
# Configures RPM Fusion (free/nonfree) and COPR repositories for Fedora.
# Handles repository detection and package installation.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args)

export LAST_ERROR="${LAST_ERROR:-}"

RPMFUSION_FREE="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
readonly RPMFUSION_FREE

RPMFUSION_NONFREE="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
readonly RPMFUSION_NONFREE

_install_rpm_from_url() {
  local url="${1:-}"

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

_copr_repo_enabled() {
  local repo="${1:-}"

  if [[ -z "$repo" ]]; then
    return 1
  fi

  local repo_id="${repo/\//:}"
  sudo dnf repolist all 2>/dev/null | grep -q "^copr:copr.fedorainfracloud.org:${repo_id}"
}

_enable_copr_repo() {
  local repo="${1:-}"

  LAST_ERROR=""

  if [[ -z "$repo" ]]; then
    LAST_ERROR="enable_copr_repo() requires a repo name"
    return 2
  fi

  if _copr_repo_enabled "$repo"; then
    return 0
  fi

  if ! sudo dnf copr enable -y "$repo" >/dev/null 2>&1; then
    LAST_ERROR="Failed to enable COPR repo: $repo"
    return 1
  fi

  return 0
}

# Configures RPM Fusion repositories.
#
# Installs RPM Fusion free and nonfree release packages for current
# Fedora version. Skips if already installed.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure
setup_rpmfusion() {
  LAST_ERROR=""

  if ! _install_rpm_from_url "$RPMFUSION_FREE"; then
    return 1
  fi

  if ! _install_rpm_from_url "$RPMFUSION_NONFREE"; then
    return 1
  fi

  return 0
}

# Enables COPR repositories.
#
# Enables specified COPR repos. Skips already-enabled repos.
#
# Arguments:
#   $@ - COPR repo names (format: owner/repo)
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args
setup_copr_repos() {
  LAST_ERROR=""

  if [[ $# -eq 0 ]]; then
    LAST_ERROR="setup_copr_repos() requires at least one repo"
    return 2
  fi

  if ! rpm -q dnf-plugins-core >/dev/null 2>&1; then
    if ! sudo dnf install -y dnf-plugins-core >/dev/null 2>&1; then
      LAST_ERROR="Failed to install dnf-plugins-core"
      return 1
    fi
  fi

  local failed_repos=()
  local repo

  for repo in "$@"; do
    if ! _enable_copr_repo "$repo"; then
      failed_repos+=("$repo")
    fi
  done

  if [[ ${#failed_repos[@]} -gt 0 ]]; then
    LAST_ERROR="Failed to enable COPR repos: ${failed_repos[*]}"
    return 1
  fi

  return 0
}
