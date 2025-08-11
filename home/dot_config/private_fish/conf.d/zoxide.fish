if status --is-interactive
    if type -q zoxide
        zoxide init --cmd cd fish | source
    end
end
