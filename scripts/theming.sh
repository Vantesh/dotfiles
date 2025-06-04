#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly DEPENDENCIES=("jq" "curl")
readonly FONTS_REPO_URL="https://github.com/Vantesh/Fonts.git"
readonly FONTS_TARGET_DIR="$HOME/.local/share/fonts"
readonly CURSOR_REPO_OWNER="driedpampas"
readonly CURSOR_REPO_NAME="macOS-hyprcursor"
readonly CURSOR_ASSET_NAME="macOS.Hyprcursor.White.tar.gz"
readonly ICONS_DIR="$HOME/.local/share/icons"
readonly CURSOR_THEME_NAME="macOS"

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  printc cyan "Installing dependencies..."
  for dep in "${DEPENDENCIES[@]}"; do
    install_package "$dep"
  done
  printc green "Dependencies installed successfully."
}

# =============================================================================
# FONT INSTALLATION FUNCTIONS
# =============================================================================

check_existing_fonts() {
  if compgen -G "$FONTS_TARGET_DIR/*.ttf" >/dev/null || compgen -G "$FONTS_TARGET_DIR/*.otf" >/dev/null; then
    printc green "Fonts already exist in $FONTS_TARGET_DIR. Skipping download."
    return 0
  fi
  return 1
}

clone_fonts_repository() {
  local temp_dir="$1"
  printc yellow "Cloning fonts from $FONTS_REPO_URL..."
  git clone --depth=1 "$FONTS_REPO_URL" "$temp_dir" || {
    rm -rf "$temp_dir"
    fail "Failed to clone font repo."
  }
}

copy_font_files() {
  local temp_dir="$1"
  local new_count=0
  local update_count=0

  mapfile -t font_files < <(find "$temp_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" \))

  if [[ ${#font_files[@]} -eq 0 ]]; then
    rm -rf "$temp_dir"
    fail "No font files found in the repository."
  fi

  for font_file in "${font_files[@]}"; do
    local font_name
    font_name=$(basename "$font_file")
    local target_font="$FONTS_TARGET_DIR/$font_name"

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
    fc-cache -f "$FONTS_TARGET_DIR"
    printc green "Installed $new_count new fonts and updated $update_count fonts."
  else
    printc green "All fonts are already up to date."
  fi
}

install_fonts() {
  printc cyan "Installing fonts..."
  local temp_dir

  mkdir -p "$FONTS_TARGET_DIR"

  if check_existing_fonts; then
    return 0
  fi

  temp_dir=$(mktemp -d) || fail "Failed to create temp directory."

  clone_fonts_repository "$temp_dir"
  copy_font_files "$temp_dir"

  rm -rf "$temp_dir"
  printc green "Font installation completed successfully."
}

# =============================================================================
# CURSOR THEME INSTALLATION FUNCTIONS
# =============================================================================

check_existing_cursor_theme() {
  local cursor_theme_dir="$ICONS_DIR/$CURSOR_THEME_NAME"
  if [[ -d "$cursor_theme_dir" ]]; then
    printc green "Cursor theme '$CURSOR_THEME_NAME' already exists in $cursor_theme_dir. Skipping download."
    return 0
  fi
  return 1
}

get_cursor_download_url() {
  printc yellow "Querying latest release from $CURSOR_REPO_OWNER/$CURSOR_REPO_NAME..."

  local download_url
  download_url=$(curl -s "https://api.github.com/repos/$CURSOR_REPO_OWNER/$CURSOR_REPO_NAME/releases/latest" |
    jq -r ".assets[] | select(.name == \"$CURSOR_ASSET_NAME\") | .browser_download_url")

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    fail "Could not find $CURSOR_ASSET_NAME in the latest release."
  fi

  echo "$download_url"
}

download_cursor_theme() {
  local download_url="$1"
  local tmp_dir="$2"

  printc yellow "Downloading $CURSOR_ASSET_NAME..."
  curl -L --silent "$download_url" -o "$tmp_dir/cursor.tar.gz" || {
    rm -rf "$tmp_dir"
    fail "Download failed."
  }
}

extract_cursor_theme() {
  local tmp_dir="$1"

  printc yellow "Extracting to $ICONS_DIR..."
  mkdir -p "$ICONS_DIR"
  tar -xzf "$tmp_dir/cursor.tar.gz" -C "$ICONS_DIR" || {
    rm -rf "$tmp_dir"
    fail "Extraction failed."
  }
}

install_cursor_theme() {
  printc cyan "Installing cursor theme..."

  if check_existing_cursor_theme; then
    return 0
  fi

  local tmp_dir
  local download_url

  tmp_dir=$(mktemp -d) || fail "Failed to create temp directory."

  download_url=$(get_cursor_download_url)
  download_cursor_theme "$download_url" "$tmp_dir"
  extract_cursor_theme "$tmp_dir"

  printc green "macOS Hyprcursor (white) installed successfully."
  rm -rf "$tmp_dir"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  install_dependencies
  install_fonts
  install_cursor_theme
}

main
