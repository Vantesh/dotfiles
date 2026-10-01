if not status is-interactive
    exit
end

abbr -a -- sysu 'systemctl --user'
abbr -a -- cls clear
abbr -a cm chezmoi

# color-enhanced commands
abbr -a grep 'ugrep --color=auto'
abbr -a fgrep 'ugrep -F --color=auto'
abbr -a egrep 'ugrep -E --color=auto'
abbr -a dir 'dir --color=auto'
abbr -a vdir 'vdir --color=auto'

# git abbreviations
abbr -a gs 'git status --short --branch'
abbr -a gl "git log --all --graph --pretty=format:'%C(magenta)%h %C(cyan)%an <%ae> %C(white)%ar%C(auto) %D%n%s%n'"
abbr -a gcl 'git clone'
abbr -a gd 'git diff'

abbr -a gco 'git checkout'
abbr -a ga 'git add'
abbr -a gp 'git push'
abbr -a gcm 'git commit -m'


# optional modern replacements
if type -q delta
    abbr -a diff delta
else
    abbr -a diff 'diff --color=auto'
end

if type -q nvim
    abbr -a vim nvim
    abbr -a vi nvim
    abbr -a vimdiff 'nvim -d'
    abbr -a view 'nvim -R'
    abbr -a v nvim
end

# package manager abbreviations
abbr -a pi 'paru -S'
abbr -a painfo 'paru -Si'
abbr -a pu 'paru -Syu'

abbr -a jctl 'journalctl -p 3 -xb'
abbr -a jtcl 'journalctl -p 3 -xb'
abbr -a h history
