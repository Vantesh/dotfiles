if not test -x /usr/bin/yay; and test -x /usr/bin/paru
    function yay --wraps=paru --description 'alias paru'
        paru $argv
    end
end
