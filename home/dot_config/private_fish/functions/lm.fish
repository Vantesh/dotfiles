function lm --wraps='eza --long -a --icons' --description 'll but sort by modified time'
    if type -q eza
        eza --long -a --icons --hyperlink -s modified $argv
    else
        missing_package eza
    end
end
