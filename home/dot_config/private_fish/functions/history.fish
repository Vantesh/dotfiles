function history
    if test (count $argv) -eq 0
        builtin history --show-time='%F %T ' --reverse
    else
        builtin history $argv
    end
end
