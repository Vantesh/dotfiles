#--------------------------------------------------
# RESPECT XDG BASE DIRECTORIES
#--------------------------------------------------
# NOTE: Most XDG variables are now set in ~/.config/environment.d/*.conf
# These are loaded by systemd user session and available to all processes.
# We keep fallbacks here for non-systemd environments or if variables aren't set.

set -q XDG_CONFIG_HOME; or set -xg XDG_CONFIG_HOME $HOME/.config
set -q XDG_DATA_HOME; or set -xg XDG_DATA_HOME $HOME/.local/share
set -q XDG_CACHE_HOME; or set -xg XDG_CACHE_HOME $HOME/.cache
set -q XDG_STATE_HOME; or set -xg XDG_STATE_HOME $HOME/.local/state
set -q XDG_BIN_HOME; or set -xg XDG_BIN_HOME $HOME/.local/bin
set -q XDG_RUNTIME_DIR; or set -xg XDG_RUNTIME_DIR /run/user/$(id -u)

#--------------------------------------------------
# PATHS
#--------------------------------------------------
fish_add_path $XDG_BIN_HOME
fish_add_path $CARGO_HOME/bin
fish_add_path $GOPATH/bin
fish_add_path $XDG_DATA_HOME/npm/bin

#--------------------------------------------------
# MANPAGER
#--------------------------------------------------
set -x LESS_TERMCAP_mb (printf '\033[1;34m')
set -x LESS_TERMCAP_md (printf '\033[1;34m')
set -x LESS_TERMCAP_so (printf '\033[1;33m')
set -x LESS_TERMCAP_se (printf '\033[0;10m')
set -x LESS_TERMCAP_us (printf '\033[4;35m')
set -x LESS_TERMCAP_ue (printf '\033[0;10m')
set -x LESS_TERMCAP_me (printf '\033[0;10m')
set -xg GROFF_NO_SGR 1
