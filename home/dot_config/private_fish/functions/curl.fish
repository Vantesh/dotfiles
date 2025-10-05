function curl --wraps=curl --description 'alias curlie'
    if type -f curlie &>/dev/null
        curlie $argv
    else
        command curl $argv
    end
end
