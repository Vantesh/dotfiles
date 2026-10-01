function fixpacman --description 'remove stale pacman lock file'
    sudo -v; or return 1
    command pgrep -x 'pacman|yay|paru|pamac|pamac-daemon|packagekitd' >/dev/null
    switch $status
        case 0
            echo "A package manager is running; refusing to remove the pacman lock." >&2
            return 1
        case 1
            sudo -n rm /var/lib/pacman/db.lck
        case '*'
            echo "Could not check for active package transactions; refusing to remove the pacman lock." >&2
            return 1
    end
end
