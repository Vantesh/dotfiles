#--------------------------------------------------
# RESPECT XDG BASE DIRECTORIES
#--------------------------------------------------
# uwsm sets these variables but we add a fallback if not running under uwsm
set -q XDG_CONFIG_HOME; or set -xg XDG_CONFIG_HOME $HOME/.config
set -q XDG_DATA_HOME; or set -xg XDG_DATA_HOME $HOME/.local/share
set -q XDG_CACHE_HOME; or set -xg XDG_CACHE_HOME $HOME/.cache
set -q XDG_STATE_HOME; or set -xg XDG_STATE_HOME $HOME/.local/state
set -q XDG_BIN_HOME; or set -xg XDG_BIN_HOME $HOME/.local/bin
set -q XDG_RUNTIME_DIR; or set -xg XDG_RUNTIME_DIR /run/user/$UID

set -xg CONAN_USER_HOME $XDG_CONFIG_HOME
set -xg GOPATH $XDG_DATA_HOME/go
set -xg GOMODCACHE $XDG_CACHE_HOME/go/mod
set -xg RUSTUP_HOME $XDG_DATA_HOME/rustup
set -xg CARGO_HOME $XDG_DATA_HOME/cargo
set -xg LEIN_HOME $XDG_DATA_HOME/lein
set -xg NUGET_PACKAGES $XDG_CACHE_HOME/NuGetPackages
set -xg ANDROID_USER_HOME $XDG_DATA_HOME/android
set -xg NODE_REPL_HISTORY $XDG_DATA_HOME/node_repl_history
set -xg DOCKER_CONFIG $XDG_CONFIG_HOME/docker
set -xg SQLITE_HISTORY $XDG_DATA_HOME/sqlite_history
set -xg GRADLE_USER_HOME $XDG_DATA_HOME/gradle
set -xg RIPGREP_CONFIG_PATH $HOME/.config/rg/.ripgreprc
set -xg ANSIBLE_HOME $XDG_CONFIG_HOME/ansible
set -xg FFMPEG_DATADIR $XDG_CONFIG_HOME/ffmpeg
set -xg MYSQL_HISTFILE $XDG_DATA_HOME/mysql_history
set -xg OMNISHARPHOME $XDG_CONFIG_HOME/omnisharp
set -xg PYENV_ROOT $XDG_DATA_HOME/pyenv
set -xg WORKON_HOME $XDG_DATA_HOME/virtualenvs
set -xg XINITRC $XDG_CONFIG_HOME/X11/xinitrc
set -xg XSERVERRC $XDG_CONFIG_HOME/X11/xserverrc
set -xg HISTFILE $XDG_STATE_HOME/bash/history
set -xg WINEPREFIX $XDG_DATA_HOME/wine
set -xg NPM_CONFIG_USERCONFIG $XDG_CONFIG_HOME/npm/npmrc
set -xg GTK2_RC_FILES $XDG_CONFIG_HOME/gtk-2.0/gtkrc
set -xg DOTNET_CLI_HOME $XDG_DATA_HOME/dotnet
set -xg PNPM_HOME $XDG_DATA_HOME/pnpm
set -xg WGETRC $XDG_CONFIG_HOME/wget/wgetrc
set -xg GNUPGHOME $XDG_DATA_HOME/gnupg
set -xg CUDA_CACHE_PATH $XDG_CACHE_HOME/nv
set -xg PYTHON_HISTORY $XDG_STATE_HOME/python_history
set -xg _JAVA_OPTIONS -Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java
set -xg MAVEN_OPTS -Dmaven.repo.local=$XDG_DATA_HOME/maven/repository
set -xg MAVEN_ARGS --settings $XDG_CONFIG_HOME/maven/settings.xml

#--------------------------------------------------
# PATHS
#--------------------------------------------------
fish_add_path $XDG_BIN_HOME
fish_add_path $CARGO_HOME/bin
fish_add_path $GOPATH/bin
fish_add_path $XDG_DATA_HOME/npm/bin

#--------------------------------------------------
# EDITORS
#--------------------------------------------------
set -xg EDITOR nvim
set -xg VISUAL code
set -xg SUDO_EDITOR $EDITOR
set -xg PAGER less

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
