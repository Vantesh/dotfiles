#!/usr/bin/env bash
# .lib-xdg_setup.sh - XDG user directories configuration
#
# Sets up XDG Base Directory specification environment variables
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
# Exit codes:
#   0 (success), 1 (failure), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

_ensure_xdg_directories() {
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
}

_setup_gopath() {
  if [[ -z "${GOPATH:-}" ]]; then
    export GOPATH="$XDG_DATA_HOME/go"
  fi

  case ":$PATH:" in
  *":$GOPATH/bin:"*) ;;
  *) export PATH="$GOPATH/bin:$PATH" ;;
  esac
}

_create_gnupg_directory() {
  local gnupg_dir="${HOME}/.local/share/gnupg"

  if [[ ! -d "$gnupg_dir" ]]; then
    if ! mkdir -p "$gnupg_dir" 2>/dev/null; then
      LAST_ERROR="Failed to create GnuPG directory: $gnupg_dir"
      return 1
    fi
  fi

  if ! chmod 700 "$gnupg_dir" 2>/dev/null; then
    LAST_ERROR="Failed to set permissions for GnuPG directory: $gnupg_dir"
    return 1
  fi

  return 0
}

_create_state_directories() {
  local bash_state_dir="${XDG_STATE_HOME}/bash"
  local python_state_dir="${XDG_STATE_HOME}/python"

  if ! mkdir -p "$bash_state_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create bash state directory: $bash_state_dir"
    return 1
  fi

  if ! mkdir -p "$python_state_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create python state directory: $python_state_dir"
    return 1
  fi

  return 0
}

_migrate_bash_history() {
  local old_histfile="${HOME}/.bash_history"
  local new_histfile="${XDG_STATE_HOME}/bash/history"

  if [[ -f "$old_histfile" ]] && [[ ! -f "$new_histfile" ]]; then
    if ! cat "$old_histfile" >>"$new_histfile" 2>/dev/null; then
      LAST_ERROR="Failed to migrate bash history"
      return 1
    fi

    if ! rm -f "$old_histfile" 2>/dev/null; then
      LAST_ERROR="Failed to remove old bash history file"
      return 1
    fi
  fi

  return 0
}

_create_maven_config() {
  local maven_config_dir="${HOME}/.config/maven"
  local settings_file="${maven_config_dir}/settings.xml"

  if ! mkdir -p "$maven_config_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create Maven config directory: $maven_config_dir"
    return 1
  fi

  if ! cat >"$settings_file" <<'EOF'; then
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository>${env.XDG_CACHE_HOME}/maven/repository</localRepository>
</settings>
EOF
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
  export RIPGREP_CONFIG_PATH="$HOME/.config/rg/.ripgreprc"
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

# Configures XDG Base Directory specification.
#
# Sets up XDG environment variables, creates directories, migrates bash history,
# and configures tools to use XDG paths (Maven, GnuPG, Python, etc.).
#
# Globals:
#   LAST_ERROR - Set on failure
#   XDG_* - Sets all XDG environment variables
#   GOPATH, CARGO_HOME, etc. - Sets tool-specific XDG paths
# Returns:
#   0 on success, 1 on failure
setup_xdg() {
  LAST_ERROR=""

  _ensure_xdg_directories
  _setup_gopath

  if ! _create_gnupg_directory; then
    return 1
  fi

  if ! _create_state_directories; then
    return 1
  fi

  if ! _migrate_bash_history; then
    return 1
  fi

  if ! _create_maven_config; then
    return 1
  fi

  _export_xdg_env_vars

  return 0
}
