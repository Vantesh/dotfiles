function more --wraps='bat' --description 'bat as more with paging'
    if set -q argv[1]; and string match -qr '^-[RrXx]' -- "$argv[1]"
        command more $argv
    else
        bat --paging=always $argv
    end
end