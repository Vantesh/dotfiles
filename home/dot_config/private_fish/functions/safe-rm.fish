function safe-rm --description 'A safer rm'
    set -l loc (dirname (status --current-filename))
    $loc/__shell-safe-rm.bash $argv
end
