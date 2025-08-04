function cat --wraps='bat' --description 'alias bat --style header --style snip --style changes --style header'
    if type -f bat &>/dev/null
        bat --style header --style snip --style changes --style header $argv
    else
        cat --paging=always $argv
    end
end
