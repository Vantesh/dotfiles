function backup -d "Create a backup of a file or directory" --argument filename
    if test (count $argv) -ne 1; or test -z "$filename"
        echo "Usage: backup <filename>" >&2
        return 1
    end

    set filename (string replace -r '/+$' '' -- "$filename")
    if test -z "$filename"
        echo "Error: Refusing to back up the filesystem root." >&2
        return 1
    end

    if not test -e "$filename"; and not test -L "$filename"
        echo "Error: File or directory '$filename' does not exist." >&2
        return 1
    end

    set -l timestamp (command date +%Y-%m-%d-%H:%M:%S)
    or return 1
    set -l base (command basename -- "$filename")
    set -l dir (command dirname -- "$filename")
    if contains -- "$base" . ..
        echo "Error: Use an explicit file or directory name." >&2
        return 1
    end
    set -l backup_filename "$dir/$base.bak.$timestamp"
    if test -e "$backup_filename"; or test -L "$backup_filename"
        echo "Error: Backup '$backup_filename' already exists." >&2
        return 1
    end

    set -l staging (command mktemp -d -- "$dir/.backup.XXXXXXXXXX")
    or return 1
    if not command cp -a -- "$filename" "$staging/content"
        echo "Error: Backup copy failed; source is unchanged." >&2
        command rm -rf -- "$staging"
        return 1
    end

    # Do not replace a backup created by another invocation while copying.
    command mv -T -n -- "$staging/content" "$backup_filename"
    set -l move_status $status
    if test "$move_status" -ne 0; or test -e "$staging/content"; or test -L "$staging/content"
        echo "Error: Could not create backup '$backup_filename'." >&2
        command rm -rf -- "$staging"
        return 1
    end
    if not command rmdir -- "$staging"
        echo "Error: Backup created, but could not remove staging directory '$staging'." >&2
        return 1
    end

    echo "Backup of '$filename' created at '$backup_filename'"
end
