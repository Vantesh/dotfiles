function df --wraps='duf' --description 'duf with default output format'
    if type -q duf
        duf --output mountpoint,size,avail,type,filesystem $argv
    else
        command df $argv
    end
end