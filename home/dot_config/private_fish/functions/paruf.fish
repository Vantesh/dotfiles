if not status is-interactive
    return
end

function paruf --description 'fuzzy search and install packages with paru'
    if not command -q paru
        echo "paru not found"
        return 1
    end

    command paru -Slq | tv --preview-command 'paru -Sii {}' --layout portrait --preview-size 75 | xargs -ro paru -S
end
