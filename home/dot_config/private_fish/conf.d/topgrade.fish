function up --wraps='paru -Syu' --description 'alias up=paru -Syu'
    if type -f topgrade &>/dev/null
        topgrade -k --only system
    else if type -f paru &>/dev/null
        paru -Syu $argv
    else
        pacman -Syu $argv
    end
end

function upall --wraps=topgrade --description 'alias upall=topgrade'
    if type -f topgrade &>/dev/null
        topgrade -k --no-self-update $argv
    end
end
