function cat --wraps='bat' --description 'alias bat'
    if type -f bat &>/dev/null
        bat $argv
    else
        command cat $argv
    end
end
