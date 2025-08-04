function lt --wraps='eza --tree -a --icons --hyprlink' --description 'alias eza --tree -a --icons'
    if type -q eza
        eza --tree -a --icons --hyperlink $argv

    else
        missing_package eza
    end
end
