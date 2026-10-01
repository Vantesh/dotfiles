function cleanup --description 'remove orphaned packages'
    sudo pacman -Rns (pacman -Qtdq)
end