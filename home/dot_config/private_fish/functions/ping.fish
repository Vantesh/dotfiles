function ping --wraps=ping --description='alias ping -c 10'
    command ping -c 10 $argv
end
