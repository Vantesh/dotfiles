#!/bin/bash

install_fonts() {
  local repo_url="https://github.com/Vantesh/Fonts.git"
  local temp_dir
  temp_dir=$(mktemp -d) || fail "Failed to create temp directory."

  local target_dir="$HOME/.local/share/fonts"
  local new_count=0
  local update_count=0

  printc yellow "Cloning fonts from $repo_url..."
  git clone --depth=1 "$repo_url" "$temp_dir" || {
    rm -rf "$temp_dir"
    fail "Failed to clone font repo."
  }

  mkdir -p "$target_dir"

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

install_fonts
