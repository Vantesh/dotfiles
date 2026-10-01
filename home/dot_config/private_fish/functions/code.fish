function code --wraps='zeditor' --description 'alias zeditor'
    if type -q zeditor
        zeditor $argv
    else
        command code $argv
    end
end
