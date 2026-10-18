#!/usr/bin/env bash
# Early environment for user-level AUR builds and mise package installation.
# environment.d and shell startup files cannot update this running process.
# Keep paths aligned with dot_config/environment.d/00-xdg.conf.tmpl.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
# Exit codes:
#   0 (success), 1 (failure), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

_export_xdg_base() {
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
  export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
  export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

  case ":$PATH:" in
  *":$XDG_BIN_HOME:"*) ;;
  *) export PATH="$XDG_BIN_HOME:$PATH" ;;
  esac
  case ":$PATH:" in
  *":/usr/bin/core_perl:"*) ;;
  *) export PATH="$PATH:/usr/bin/core_perl" ;;
  esac
  export GOPATH="${GOPATH:-$XDG_DATA_HOME/go}"

  case ":$PATH:" in
  *":$GOPATH/bin:"*) ;;
  *) export PATH="$GOPATH/bin:$PATH" ;;
  esac
}

_create_gnupg_directory() {
  if [[ -L "$GNUPGHOME" ]]; then
    LAST_ERROR="Refusing to change permissions through GnuPG home symlink: $GNUPGHOME"
    return 1
  fi

  if ! (umask 077; mkdir -p -- "$GNUPGHOME") || ! chmod 700 -- "$GNUPGHOME"; then
    LAST_ERROR="Failed to create or secure GnuPG directory: $GNUPGHOME"
    return 1
  fi

  return 0
}

_create_state_directories() {
  if ! mkdir -p -- "$XDG_STATE_HOME/bash" "$XDG_STATE_HOME/python"; then
    LAST_ERROR="Failed to create Bash/Python state directories under $XDG_STATE_HOME"
    return 1
  fi

  return 0
}

_create_maven_config() {
  local maven_config_dir="$XDG_CONFIG_HOME/maven"
  local settings_file="${maven_config_dir}/settings.xml"

  # Existing settings may contain user-specific repositories or credentials.
  if [[ -e "$settings_file" || -L "$settings_file" ]]; then
    [[ -f "$settings_file" ]] && return 0
    LAST_ERROR="Maven settings path is not a regular file: $settings_file"
    return 1
  fi

  if ! mkdir -p -- "$maven_config_dir"; then
    LAST_ERROR="Failed to create Maven config directory: $maven_config_dir"
    return 1
  fi

  if ! (
    temporary_settings=$(mktemp "$maven_config_dir/.settings.XXXXXX") || exit 1
    trap 'rm -f -- "$temporary_settings"' EXIT
    cat >"$temporary_settings" <<'EOF' || exit 1
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository>${env.XDG_DATA_HOME}/maven/repository</localRepository>
</settings>
EOF
    ln -- "$temporary_settings" "$settings_file"
  ); then
    LAST_ERROR="Failed to create Maven settings file: $settings_file"
    return 1
  fi

  return 0
}

_export_xdg_env_vars() {
  export CONAN_USER_HOME="$XDG_CONFIG_HOME"
  export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
  export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
  export CARGO_HOME="$XDG_DATA_HOME/cargo"
  export LEIN_HOME="$XDG_DATA_HOME/lein"
  export NUGET_PACKAGES="$XDG_CACHE_HOME/NuGetPackages"
  export ANDROID_USER_HOME="$XDG_DATA_HOME/android"
  export NODE_REPL_HISTORY="$XDG_DATA_HOME/node_repl_history"
  export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
  export SQLITE_HISTORY="$XDG_DATA_HOME/sqlite_history"
  export GRADLE_USER_HOME="$XDG_DATA_HOME/gradle"
  export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/ripgreprc"
  export ANSIBLE_HOME="$XDG_CONFIG_HOME/ansible"
  export FFMPEG_DATADIR="$XDG_CONFIG_HOME/ffmpeg"
  export MYSQL_HISTFILE="$XDG_DATA_HOME/mysql_history"
  export OMNISHARPHOME="$XDG_CONFIG_HOME/omnisharp"
  export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet"
  export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
  export WORKON_HOME="$XDG_DATA_HOME/virtualenvs"
  export XINITRC="$XDG_CONFIG_HOME/X11/xinitrc"
  export XSERVERRC="$XDG_CONFIG_HOME/X11/xserverrc"
  export HISTFILE="$XDG_STATE_HOME/bash/history"
  export WINEPREFIX="$XDG_DATA_HOME/wine"
  export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
  export npm_config_cache="$XDG_CACHE_HOME/npm"
  export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc"
  export PNPM_HOME="$XDG_DATA_HOME/pnpm"
  export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
  export GNUPGHOME="$XDG_DATA_HOME/gnupg"
  export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"
  export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
  export _JAVA_OPTIONS="-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java"
  export MAVEN_OPTS="-Dmaven.repo.local=$XDG_DATA_HOME/maven/repository"
  export MAVEN_ARGS="--settings $XDG_CONFIG_HOME/maven/settings.xml"
}

# Run before makepkg or mise. Only directories/settings needed by this process
# are initialized here; tool caches and repositories are created by their tools.
setup_xdg() {
  LAST_ERROR=""

  _export_xdg_base
  _export_xdg_env_vars

  if ! _create_gnupg_directory; then
    return 1
  fi

  if ! _create_state_directories; then
    return 1
  fi

  if ! _create_maven_config; then
    return 1
  fi

  return 0
}
