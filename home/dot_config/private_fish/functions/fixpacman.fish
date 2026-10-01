function fixpacman --description 'remove stale pacman lock file'
    sudo rm /var/lib/pacman/db.lck
end