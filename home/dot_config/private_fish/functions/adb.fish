function adb --wraps=adb --description 'Run adb with its home in the XDG data directory'
    command mkdir -p "$XDG_DATA_HOME/android"; or return
    HOME="$XDG_DATA_HOME/android" command adb $argv
end
