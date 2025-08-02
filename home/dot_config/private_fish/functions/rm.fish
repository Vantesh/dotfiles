function rm --wraps=rm --description 'alias rm=rm -i'
    command rm -i $argv
end
