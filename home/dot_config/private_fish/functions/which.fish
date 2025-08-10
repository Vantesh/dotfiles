function which --wrap="which" --description "Display information about command type or abbreviation"
    # If any arg looks like a flag, defer to the real `which` to preserve its flags/behavior
    for arg in $argv
        if string match -q -- '-*' $arg
            command which $argv
            return $status
        end
    end

    # No flags: keep enhanced behavior
    if test (count $argv) -gt 0; and abbr --query $argv[1]
        echo "$argv[1] is an abbreviation with definition"
        abbr --show | command grep "abbr -a -- $argv[1]"
        type --all $argv 2>/dev/null
        return 0
    else
        type --all $argv
    end
end
