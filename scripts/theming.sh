#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

DEPS=("jq" "curl")
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
  for dep in "${DEPS[@]}"; do
    install_package "$dep"
  done
}

# =============================================================================
# FONT INSTALLATION FUNCTIONS
# =============================================================================

check_existing_fonts() {
  if compgen -G "$FONTS_TARGET_DIR/*.ttf" >/dev/null || compgen -G "$FONTS_TARGET_DIR/*.otf" >/dev/null; then
    printc green "Fonts already installed"
    return 0
  fi
  return 1
}

clone_fonts_repository() {
  local temp_dir="$1"
  printc -n cyan "Cloning fonts... "
  if git clone --depth=1 "$FONTS_REPO_URL" "$temp_dir" 2>/dev/null; then
    printc green "OK"
  else
    rm -rf "$temp_dir"
    fail "FAILED"
  fi
}

copy_font_files() {
  local temp_dir="$1"
  local new_count=0
  local update_count=0

  printc -n cyan "Installing fonts... "

  mapfile -t font_files < <(find "$temp_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" \))

  if [[ ${#font_files[@]} -eq 0 ]]; then
    rm -rf "$temp_dir"
    fail "No fonts found"
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
    fc-cache -f "$FONTS_TARGET_DIR" 2>/dev/null
    printc green "OK ($new_count new, $update_count updated)"
  else
    printc green "up to date"
  fi
}

install_fonts() {
  mkdir -p "$FONTS_TARGET_DIR"

  if check_existing_fonts; then
    return 0
  fi

  local temp_dir
  temp_dir=$(mktemp -d) || fail "Failed to create temp directory"

  clone_fonts_repository "$temp_dir"
  copy_font_files "$temp_dir"

  rm -rf "$temp_dir"
}

# =============================================================================
# CURSOR THEME INSTALLATION FUNCTIONS
# =============================================================================

check_existing_cursor_theme() {
  local cursor_theme_dir="$ICONS_DIR/$CURSOR_THEME_NAME"
  if [[ -d "$cursor_theme_dir" ]]; then
    printc green "Cursor theme already installed"
    return 0
  fi
  return 1
}

get_cursor_download_url() {
  local download_url
  download_url=$(curl -s "https://api.github.com/repos/$CURSOR_REPO_OWNER/$CURSOR_REPO_NAME/releases/latest" |
    jq -r ".assets[] | select(.name == \"$CURSOR_ASSET_NAME\") | .browser_download_url")

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    fail "Could not find $CURSOR_ASSET_NAME"
  fi

  echo "$download_url"
}

download_cursor_theme() {
  local download_url="$1"
  local tmp_dir="$2"

  printc -n cyan "Downloading cursor theme... "
  if curl -L --silent "$download_url" -o "$tmp_dir/cursor.tar.gz"; then
    printc green "OK"
  else
    rm -rf "$tmp_dir"
    fail "FAILED"
  fi
}

extract_cursor_theme() {
  local tmp_dir="$1"

  printc -n cyan "Extracting cursor theme... "
  mkdir -p "$ICONS_DIR"
  if tar -xzf "$tmp_dir/cursor.tar.gz" -C "$ICONS_DIR"; then
    printc green "OK"
  else
    rm -rf "$tmp_dir"
    fail "FAILED"
  fi
}

install_cursor_theme() {
  if check_existing_cursor_theme; then
    return 0
  fi

  local tmp_dir
  local download_url

  tmp_dir=$(mktemp -d) || fail "Failed to create temp directory"

  download_url=$(get_cursor_download_url)
  download_cursor_theme "$download_url" "$tmp_dir"
  extract_cursor_theme "$tmp_dir"

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
