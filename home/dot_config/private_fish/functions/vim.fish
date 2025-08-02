function vim --wraps=nvim --description 'alias vim=nvim'
    if type -f nvim &>/dev/null
        nvim $argv
    else
        missing_package nvim
    end
end
