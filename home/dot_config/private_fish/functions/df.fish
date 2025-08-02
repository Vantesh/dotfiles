function df --wraps=df --description 'alias df=duf'
    if type -f duf &>/dev/null
        command duf $argv
    else
        missing_package duf
    end

end
