function du --wraps='dust -r' --description 'dust with recursive flag'
    if type -q dust
        dust -r $argv
    else
        command du $argv
    end
end