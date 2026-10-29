# Keep configuration, persistent stores and logs separate before the first launch.
set -l atuin_data_home "$XDG_DATA_HOME"
test -n "$atuin_data_home"; or set atuin_data_home "$HOME/.local/share"
set -l atuin_state_home "$XDG_STATE_HOME"
test -n "$atuin_state_home"; or set atuin_state_home "$HOME/.local/state"
# Match the fixed Chezmoi dot_config target, including with a custom XDG_CONFIG_HOME.
set -gx ATUIN_HOME "$HOME/.config/atuin"
set -gx ATUIN_CONFIG_DIR "$HOME/.config/atuin"
set -gx ATUIN_DATA_DIR "$atuin_data_home/atuin"
set -gx ATUIN_LOGS__DIR "$atuin_state_home/atuin"
if test -n "$XDG_RUNTIME_DIR"
    set -gx ATUIN_DAEMON__SOCKET_PATH "$XDG_RUNTIME_DIR/atuin.sock"
    set -gx ATUIN_DAEMON__PIDFILE_PATH "$XDG_RUNTIME_DIR/atuin.pid"
end

set -x ATUIN_NOBIND true

if status is-interactive
    if type -q atuin
        atuin init fish | source
    end
end

bind \cr _atuin_search

if bind -M insert >/dev/null 2>&1
    bind -M insert \cr _atuin_search
end
