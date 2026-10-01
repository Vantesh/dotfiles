function lt --wraps='eza --tree -a --icons' --description 'alias eza --tree -a --icons'
    if type -q eza
        eza --tree -a --icons --hyperlink=auto --level=3 $argv

    else
        missing_package eza
    end
end
