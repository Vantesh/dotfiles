set -xg STARSHIP_CONFIG $HOME/.config/starship/starship.toml

function starship_transient_prompt_func
    starship module character
end

function prompt_newline --on-event fish_postexec
    printf "\n"
end

function clear --description 'alias clear=commandline -f clear-screen'
    command clear
    commandline -f clear-screen
end

if status is-interactive
    if type -q starship
        starship init fish | source
        enable_transience
    end
end
