function yayf --description 'fuzzy search and install packages with yay/paru'
    if type -q yay
        yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S
    else if type -q paru
        paru -Slq | fzf --multi --preview "paru -Sii {1}" --preview-window=down:75% | xargs -ro paru -S
    else
        echo "Neither yay nor paru found"
        return 1
    end
end