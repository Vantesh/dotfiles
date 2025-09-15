function restore -d "Restore the most recent backup of a file or directory, then delete the backup" --argument filename
    if test (count $argv) -ne 1
        echo "Usage: restore <filename>"
        return 1
    end

    set filename $argv[1]

    # Remove trailing slash
    while test (string sub -s -1 -l 1 -- $filename) = /
        set filename (string sub -s 1 -l (math (string length $filename) - 1) -- $filename)
    end

    # Strip .bak.TIMESTAMP suffix if given
    if test (string match -r '\.bak\.\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}$' $filename)
        set filename (string replace -r '\.bak\.\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}$' '' $filename)
    end

    if test -e "$filename"
        echo "Warning: '$filename' already exists and will be overwritten."
    end

    set dir (dirname -- "$filename")
    set base (basename -- "$filename")

    # Use printf + globbing + sort instead of ls
    set backups (printf "%s\n" $dir/$base.bak.* | sort -r)

    if test (count $backups) -eq 0
        echo "Error: No backup found for '$filename'."
        return 1
    end

    set latest_backup $backups[1]

    echo "Restoring backup '$latest_backup' to '$filename'..."

    if test -d "$filename"
        rm -rf "$filename"
    else if test -e "$filename"
        rm "$filename"
    end

    if test -d "$latest_backup"
        cp -a "$latest_backup" "$filename"
        rm -rf "$latest_backup"
    else
        cp "$latest_backup" "$filename"
        rm "$latest_backup"
    end

    echo "Restore complete. Backup file deleted."
end
