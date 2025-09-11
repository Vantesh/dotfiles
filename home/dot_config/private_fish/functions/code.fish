function code --wraps='code' --description 'alias code to open files in VSCode'
    if type -f code &>/dev/null
        uwsm-exec code $argv
    end
end
