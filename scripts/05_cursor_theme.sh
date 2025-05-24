#!/bin/bash
check_and_install_tools() {
  local tools=(curl jq)
  local missing=()

  for tool in "${tools[@]}"; do
    if ! has_cmd "$tool"; then
      missing+=("$tool")
    fi
  done

  if ((${#missing[@]} > 0)); then
    printc yellow "Missing tools: ${missing[*]}. Installing..."
    # curl and jq are official repo packages, so pacman is fine
    yay -S --noconfirm --needed "${missing[@]}" || fail "Failed to install required tools: ${missing[*]}"
    printc green "Required tools installed."
  else
    printc green "All required tools are already installed."
  fi
}

install_cursor_theme() {
  check_and_install_tools

  local repo_owner="driedpampas"
  local repo_name="macOS-hyprcursor"
  local asset_name="macOS.Hyprcursor.White.tar.gz"
  local icons_dir="$HOME/.local/share/icons"
  local tmp_dir

  tmp_dir=$(mktemp -d) || fail "Failed to create temp directory."

  printc yellow "Querying latest release from $repo_owner/$repo_name..."

  local download_url
  download_url=$(curl -s "https://api.github.com/repos/$repo_owner/$repo_name/releases/latest" |
    jq -r ".assets[] | select(.name == \"$asset_name\") | .browser_download_url")

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    rm -rf "$tmp_dir"
    fail "Could not find $asset_name in the latest release."
  fi

  printc yellow "Downloading $asset_name..."
  curl -L --silent "$download_url" -o "$tmp_dir/cursor.tar.gz" || {
    rm -rf "$tmp_dir"
    fail "Download failed."
  }

  printc yellow "Extracting to $icons_dir..."
  mkdir -p "$icons_dir"
  tar -xzf "$tmp_dir/cursor.tar.gz" -C "$icons_dir" || {
    rm -rf "$tmp_dir"
    fail "Extraction failed."
  }

  printc green "macOS Hyprcursor (white) installed successfully."
  rm -rf "$tmp_dir"
}

install_cursor_theme
