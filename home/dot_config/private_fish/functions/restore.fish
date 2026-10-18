function restore -d "Restore the most recent backup of a file or directory, then delete the backup" --argument filename
    if test (count $argv) -ne 1; or test -z "$filename"
        echo "Usage: restore <filename>" >&2
        return 1
    end

    set filename (string replace -r '/+$' '' -- "$filename")
    set filename (string replace -r '\.bak\.\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}$' '' -- "$filename")
    if test -z "$filename"
        echo "Error: Refusing to restore the filesystem root." >&2
        return 1
    end

    set -l dir (command dirname -- "$filename")
    set -l base (command basename -- "$filename")
    if contains -- "$base" . ..
        echo "Error: Use an explicit file or directory name." >&2
        return 1
    end
    set filename "$dir/$base"

    set -l latest_backup
    # Quoted path components keep spaces and wildcard characters literal.
    for candidate in "$dir/$base.bak."*
        if string match -qr -- '\.bak\.\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}$' "$candidate"
            set latest_backup "$candidate"
        end
    end
    if test -z "$latest_backup"
        echo "Error: No backup found for '$filename'." >&2
        return 1
    end

    set -l staging (command mktemp -d -- "$dir/.restore.XXXXXXXXXX")
    or return 1
    if not command cp -a -- "$latest_backup" "$staging/content"
        echo "Error: Restore copy failed; destination and backup are unchanged." >&2
        command rm -rf -- "$staging"
        return 1
    end

    set -l had_original 0
    if test -e "$filename"; or test -L "$filename"
        if not command mv -T -- "$filename" "$staging/original"
            echo "Error: Could not move the existing destination; backup preserved." >&2
            command rm -rf -- "$staging"
            return 1
        end
        set had_original 1
    end

    command mv -T -n -- "$staging/content" "$filename"
    set -l move_status $status
    if test "$move_status" -ne 0; or test -e "$staging/content"; or test -L "$staging/content"
        echo "Error: Could not install restored content; backup preserved." >&2
        if test "$had_original" -eq 1
            command mv -T -n -- "$staging/original" "$filename"
            if test -e "$staging/original"; or test -L "$staging/original"
                echo "Error: Could not roll back; original retained at '$staging/original'." >&2
                return 1
            end
        end
        command rm -rf -- "$staging"
        return 1
    end

    if not command rm -rf -- "$staging"
        echo "Error: Content restored, but staging cleanup failed; backup preserved." >&2
        return 1
    end
    if not command rm -rf -- "$latest_backup"
        echo "Error: Content restored, but could not delete backup '$latest_backup'." >&2
        return 1
    end

    echo "Restore complete. Backup file deleted."
end
