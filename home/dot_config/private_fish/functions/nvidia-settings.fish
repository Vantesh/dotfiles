function nvidia-settings --wraps=nvidia-settings --description 'Store NVIDIA settings in the XDG config directory'
    command mkdir -p "$XDG_CONFIG_HOME/nvidia"; or return
    command nvidia-settings --config="$XDG_CONFIG_HOME/nvidia/settings" $argv
end
