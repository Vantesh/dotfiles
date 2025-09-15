function backup -d "Create a backup of a file or directory" --argument filename
    if test (count $argv) -ne 1
        echo "Usage: backup <filename>"
        return 1
    end

    set filename $argv[1]

    # Remove trailing slash - fallback for older fish versions
    while test (string sub -s -1 -l 1 -- $filename) = /
        set filename (string sub -s 1 -l (math (string length $filename) - 1) -- $filename)
    end

    if not test -e "$filename"
        echo "Error: File or directory '$filename' does not exist."
        return 1
    end

    set timestamp (date +%Y-%m-%d-%H:%M:%S)
    set base (basename -- "$filename")
    set dir (dirname -- "$filename")
    set backup_filename "$dir/$base.bak.$timestamp"

    if test -d "$filename"
        cp -a "$filename" "$backup_filename"
    else
        cp "$filename" "$backup_filename"
    end

    echo "Backup of '$filename' created at '$backup_filename'"
end
