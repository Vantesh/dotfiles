if not status is-interactive
    exit
end

if command -q tv
    tv init fish | source

    # Keep Atuin's history search instead of Television's Ctrl-R binding.
    if functions -q _atuin_search
        bind \cr _atuin_search
        bind -M insert \cr _atuin_search
    end
end
