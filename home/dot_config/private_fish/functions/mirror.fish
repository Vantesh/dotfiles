function mirror --description 'update pacman mirrorlist'
    sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist
end