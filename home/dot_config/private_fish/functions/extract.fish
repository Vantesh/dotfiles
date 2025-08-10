function extract --description "Expand or extract bundled & compressed files"
    for file in $argv
        if test -f $file
            switch $file
                case "*.tar.bz2"
                    tar xjf $file
                case "*.tar.gz" "*.tgz"
                    tar xzf $file
                case "*.bz2"
                    bunzip2 $file
                case "*.rar"
                    rar x $file
                case "*.gz"
                    gunzip $file
                case "*.tar"
                    tar xf $file
                case "*.tbz2"
                    tar xjf $file
                case "*.tgz"
                    tar xzf $file
                case "*.zip"
                    unzip $file
                case "*.Z"
                    uncompress $file
                case "*.7z"
                    7z x $file
                case '*'
                    echo "$file cannot be extracted via extract"
            end
        else
            echo >&2 "$file is not a valid file"
        end
    end
end
