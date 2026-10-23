function mirror --description 'update pacman mirrorlist'
    sudo reflector @/etc/xdg/reflector/reflector.conf
end
