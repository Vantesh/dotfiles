function ll --wraps='eza --long -a --icons --group-directories-first' --description 'alias eza --long -a --icons --group-directories-first'
    if type -q eza
        eza --long -a --icons --group-directories-first --hyperlink $argv

    else
        missing_package eza
    end
end
