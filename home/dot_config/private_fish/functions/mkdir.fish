function mkdir --wraps='mkdir -p' --description 'alias mkdir -p'
    command mkdir -p $argv
end
