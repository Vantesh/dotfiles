if status --is-interactive
    abbr -a -- sysu 'systemctl --user'
    abbr -a -- cls clear
    abbr -a cm chezmoi

    abbr -a -- df duf

    # git abbreviations
    abbr -a gco 'git checkout'
    abbr -a ga 'git add'
    abbr -a gp 'git push'
    abbr -a gl 'git pull'
    abbr -a gcm 'git commit -m'
    abbr -a gcl 'git clone'

    # package manager abbreviations
    abbr -a pi 'paru -S'
    abbr -a painfo 'paru -Si'
    abbr -a pu 'paru -Syu'
    abbr -a cleanup 'sudo pacman -Rns (pacman -Qtdq) && sudo paccache -r'

    # journal abbreviations
    abbr -a jctl 'journalctl -p 3 -xb'
end
