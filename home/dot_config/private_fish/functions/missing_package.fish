function missing_package
    while true
        read -l -P "$argv[1] not found. Do you want to install it? [y/N] " confirm

        if test "$confirm" = y
            if type -q paru
                paru -S $argv[1]
            else if type -q yay
                yay -S $argv[1]

            else if type -q pacman
                sudo pacman -S $argv[1]
            else
                echo "No package manager found to install $argv[1]."
                return 1
            end
            break
        else
            break
        end
    end
end
