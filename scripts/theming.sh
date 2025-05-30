#!/bin/bash

deps=(
  jq
  curl
)

for dep in "${deps[@]}"; do
  install_package "$dep"
done

install_fonts() {
  local repo_url="https://github.com/Vantesh/Fonts.git"
  local temp_dir
  local target_dir="$HOME/.local/share/fonts"
  local new_count=0
  local update_count=0

  mkdir -p "$target_dir"

  # Only download fonts if none exist in the target directory
  if compgen -G "$target_dir/*.ttf" >/dev/null || compgen -G "$target_dir/*.otf" >/dev/null; then
    printc green "Fonts already exist in $target_dir. Skipping download."
    return 0
  fi

  temp_dir=$(mktemp -d) || fail "Failed to create temp directory."

  printc yellow "Cloning fonts from $repo_url..."
  git clone --depth=1 "$repo_url" "$temp_dir" || {
    rm -rf "$temp_dir"
    fail "Failed to clone font repo."
  }

  mapfile -t font_files < <(find "$temp_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" \))

  if [[ ${#font_files[@]} -eq 0 ]]; then
    rm -rf "$temp_dir"
    fail "No font files found in the repository."
  fi

  for font_file in "${font_files[@]}"; do
    local font_name
    font_name=$(basename "$font_file")
    local target_font="$target_dir/$font_name"

    if [[ -f "$target_font" ]]; then
      if ! cmp -s "$font_file" "$target_font"; then
        cp "$font_file" "$target_font"
        ((update_count++))
      fi
    else
      cp "$font_file" "$target_font"
      ((new_count++))
    fi
  done

  if ((new_count > 0 || update_count > 0)); then
    printc yellow "Refreshing font cache..."
    fc-cache -f "$target_dir"
    printc green "Installed $new_count new fonts and updated $update_count fonts."
  else
    printc green "All fonts are already up to date."
  fi

  rm -rf "$temp_dir"
}

install_cursor_theme() {

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

install_fonts
install_cursor_theme
