function update-all --wraps=topgrade --description 'alias update-all=topgrade'
    if type -f topgrade &>/dev/null
        topgrade -k --no-self-update $argv
    else
        missing_package topgrade
    end
end
