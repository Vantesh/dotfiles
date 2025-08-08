function wget --wraps=wget --description 'Wget respects XDG base directories'
    if type -f wget >/dev/null
        command wget --hsts-file="$XDG_CACHE_HOME/wget-hsts" $argv
    end
end
