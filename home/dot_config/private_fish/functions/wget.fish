function wget --wraps=wget --description 'Wget resumes downloads and respects XDG base directories'
    if type -f wget >/dev/null
        command wget --hsts-file="$XDG_DATA_HOME/wget-hsts" -c $argv
    end
end
