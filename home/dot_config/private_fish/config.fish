if status is-interactive
    if not type -q fisher
        echo "Installing Fisher..."
        curl -sL https://git.io/fisher | source && fisher update
    end
end
