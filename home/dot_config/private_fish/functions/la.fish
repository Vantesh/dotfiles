function la --wraps='eza -a --icons --group-directories-first' --description 'alias eza -a --icons --group-directories-first'
    if type -q eza
        eza -a --icons --group-directories-first --hyperlink=auto $argv

    else
        missing_package eza
    end
end
