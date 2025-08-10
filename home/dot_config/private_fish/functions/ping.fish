function ping --wraps=ping --description='alias ping -c 5'
    command ping -c 5 $argv
end
