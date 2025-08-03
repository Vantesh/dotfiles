function rm --wraps=rm --description 'alias rm=rm --interactive --verbose'
    command rm -i -v $argv
end
