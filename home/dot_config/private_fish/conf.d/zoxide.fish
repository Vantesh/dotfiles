if not status is-interactive
    exit
end

if type -q zoxide
    zoxide init --cmd cd fish | source

    function __zoxide_zi --description "Jump to a directory using Television"
        set -l query (string join " " -- $argv)
        set -l result (command tv zoxide --input "$query" --keybindings 'enter = "confirm_selection"')
        or return $status
        test (count $result) -eq 1; and test -n "$result"
        or return 1
        __zoxide_cd -- "$result"
    end
end
