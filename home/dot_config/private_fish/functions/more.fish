function more --wraps='bat' --description 'bat as more with paging'
    set -l first_arg $argv[1]
    if string match -qr '^-[RrXx]' -- $first_arg
        command more $argv
    else
        bat --paging=always $argv
    end
end