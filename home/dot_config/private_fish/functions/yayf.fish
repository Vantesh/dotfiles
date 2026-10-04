function yayf --description 'fuzzy search and install packages with yay/paru'
    if command -q yay
        command yay -Slq | tv --preview-command 'yay -Sii {}' --layout portrait --preview-size 75 | xargs -ro yay -S
    else if command -q paru
        command paru -Slq | tv --preview-command 'paru -Sii {}' --layout portrait --preview-size 75 | xargs -ro paru -S
    else
        echo "Neither yay nor paru found"
        return 1
    end
end
