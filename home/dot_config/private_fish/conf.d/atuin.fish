set -x ATUIN_NOBIND true

if status is-interactive
    if type -q atuin
        atuin init fish | source
    end
end

bind \cr _atuin_search

if bind -M insert >/dev/null 2>&1
    bind -M insert \cr _atuin_search
end
