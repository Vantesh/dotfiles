if not status is-interactive
    exit
end

if type -q zoxide
    zoxide init --cmd cd fish | source
end
