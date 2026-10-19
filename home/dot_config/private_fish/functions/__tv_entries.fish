function __tv_entries --description 'Frame Television entries with a Fish-escaped argument'
    # Consumers use the escaped field as Fish code; display/output use only the original.
    # --null selects NUL-delimited input; the output is always NUL-delimited.
    while read --local --delimiter '' $argv entry
        printf '%s\t%s\0' (string escape --style=script --no-quoted -- "$entry") "$entry"
    end
end
