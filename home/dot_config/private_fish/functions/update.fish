function update --wraps='paru -Syu' --description 'alias update=paru -Syu'
    echo '
               __     __
 __ _____  ___/ /__ _/ /____ ___
/ // / _ \/ _  / _ `/ __/ -_|_-<
\_,_/ .__/\_,_/\_,_/\__/\__/___/
   /_/
    '
    if type -q topgrade
        topgrade -k --only system
    else if type -q paru
        paru -Syu $argv
    else
        sudo pacman -Syu $argv
    end
end
