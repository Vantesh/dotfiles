function update --wraps='paru -Syu' --description 'alias update=paru -Syu'
    if type -f topgrade &>/dev/null
        topgrade -k --only system
    else if type -f paru &>/dev/null
        paru -Syu $argv
    else
        pacman -Syu $argv
    end
end
