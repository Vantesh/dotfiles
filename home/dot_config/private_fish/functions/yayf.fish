if not status is-interactive
    return
end

function yayf --description 'fuzzy search and install packages with yay'
    if not command -q yay
        echo "yay not found"
        return 1
    end

    command yay -Slq | tv --preview-command 'yay -Sii {}' --layout portrait --preview-size 75 | xargs -ro yay -S
end
