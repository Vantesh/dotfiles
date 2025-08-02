if type -q eza
    function ll --wraps='eza --long -a --icons  --group-directories-first' --description 'alias eza --long -a --icons  --group-directories-first'

        eza --long -a --icons --group-directories-first --hyperlink $argv
    end

    function ls --wraps='eza -a --icons --group-directories-first' --description 'alias eza -a --icons --group-directories-first'

        eza -a --icons --group-directories-first --hyperlink $argv

    end

    function la --wraps='eza -a --icons --group-directories-first' --description 'alias eza -a --icons --group-directories-first'

        eza -a --icons --group-directories-first --hyperlink $argv
    end

    function lt --wraps='eza --tree -a --icons' --description 'alias eza --tree -a --icons '

        eza --tree -a --icons --hyperlink $argv
    end

    function lm --wraps='eza --long -a --icons' --description 'alias eza --long -a --icons'

        eza --long -a --icons --hyperlink -s modified $argv
    end
else
    missing_package eza
end
