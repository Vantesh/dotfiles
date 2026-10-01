function yayf --description 'fuzzy search and install packages with yay/paru'
    if command -q yay
        command yay -Slq | fzf --multi --preview 'command yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S
    else if command -q paru
        command paru -Slq | fzf --multi --preview 'command paru -Sii {1}' --preview-window=down:75% | xargs -ro paru -S
    else
        echo "Neither yay nor paru found"
        return 1
    end
end