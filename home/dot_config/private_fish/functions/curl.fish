function curl --wraps=curlie --description 'alias curlie'
    if contains -- --help $argv; or contains -- -h $argv
        command curl $argv
    else if type -q curlie
        curlie $argv
    else
        command curl $argv
    end
end
