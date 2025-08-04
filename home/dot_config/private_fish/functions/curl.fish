function curl --wraps=curl --description 'alias curlie'
    if type -f curlie &>/dev/null
        curlie $argv
    else
        missing_package curlie
    end
end
