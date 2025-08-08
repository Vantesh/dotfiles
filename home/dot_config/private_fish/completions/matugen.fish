function __fish_subcommand_satisfies
    set -l cmd (commandline -poc)
    set -e cmd[1]
    set -l len (count $argv)

    if test (count $cmd) -lt $len
        return 1
    end

    for i in (seq $len)
        if test $cmd[$i] != $argv[$i]
            return 1
        end
    end

    return 0
end

function __fish_subcommand_is
    set -l cmd (commandline -poc)
    set -e cmd[1]

    if test (count $cmd) -ne (count $argv)
        return 1
    end

    __fish_subcommand_satisfies $argv
end

function __fish_no_subcommand
    set -l cmd (commandline -poc)
    set -e cmd[1]
    test (count $cmd) -eq 0
end

complete -c matugen -f

# Top-level subcommands ------------------------------------------------------------------
complete -c matugen -n __fish_no_subcommand -a image -d 'The image to use for generating a color scheme'
complete -c matugen -n __fish_no_subcommand -a color -d 'The source color to use for generating a color scheme'
complete -c matugen -n __fish_no_subcommand -a help -d 'Print help'

# color subcommands ----------------------------------------------------------------------
complete -c matugen -n '__fish_subcommand_is color' -a hex -d 'Provide a HEX color string'
complete -c matugen -n '__fish_subcommand_is color' -a rgb -d 'Provide an RGB color string'
complete -c matugen -n '__fish_subcommand_is color' -a hsl -d 'Provide an HSL color string'
complete -c matugen -n '__fish_subcommand_is color' -a help -d 'Print help for color'

# image arguments ------------------------------------------------------------------------
complete -c matugen -n '__fish_subcommand_is image' -F -d 'Path to image file'

# color arguments ------------------------------------------------------------------------
complete -c matugen -n '__fish_subcommand_is color hex' -r -f -d 'HEX color string, e.g. #ff00aa'
complete -c matugen -n '__fish_subcommand_is color rgb' -r -f -d 'RGB string, e.g. 255,0,170 or rgb(255,0,170)'
complete -c matugen -n '__fish_subcommand_is color hsl' -r -f -d 'HSL string, e.g. 312,100%,50% or hsl(312,100%,50%)'

# Global options (apply everywhere) ------------------------------------------------------
# Type (with per-scheme descriptions)
complete -c matugen -s t -l type -r -f -a scheme-tonal-spot -d 'Balanced neutrals with focused accent'
complete -c matugen -s t -l type -r -f -a scheme-expressive -d 'Lively multi-hue accents; more colorful'
complete -c matugen -s t -l type -r -f -a scheme-fidelity -d 'Faithful to seed; minimal hue shifts'
complete -c matugen -s t -l type -r -f -a scheme-content -d 'Content-first; muted surfaces, high legibility'
complete -c matugen -s t -l type -r -f -a scheme-monochrome -d 'Grayscale; minimal color distraction'
complete -c matugen -s t -l type -r -f -a scheme-neutral -d 'Low-chroma, understated, calm palette'
complete -c matugen -s t -l type -r -f -a scheme-rainbow -d 'Playful multi-hue palette; varied accents'
complete -c matugen -s t -l type -r -f -a scheme-fruit-salad -d 'Bold curated multi-color accents'

# Config file
complete -c matugen -s c -l config -d 'Sets a custom config file' -r -F

# Prefix path
complete -c matugen -s p -l prefix -d 'Sets a custom config file' -r -F

# Contrast value
complete -c matugen -l contrast -d 'Contrast from -1 to 1 (min..max)' -r -f

# Verbosity and mode toggles
complete -c matugen -s v -l verbose -d 'Show verbose output'
complete -c matugen -s q -l quiet -d 'Show no output'
complete -c matugen -s d -l debug -d 'Show debug output'

# Mode
complete -c matugen -s m -l mode -r -f -a light -d 'Light mode'
complete -c matugen -s m -l mode -r -f -a dark -d 'Dark mode'

# Dry run and show colors
complete -c matugen -l dry-run -d 'Do not generate templates, reload apps, set wallpaper or run commands'
complete -c matugen -l show-colors -d 'Show generated colors'

# JSON dump format (value descriptions)
complete -c matugen -s j -l json -r -f -a hex -d 'HEX (#rrggbb)'
complete -c matugen -s j -l json -r -f -a rgb -d 'RGB (r,g,b)'
complete -c matugen -s j -l json -r -f -a rgba -d 'RGBA (r,g,b,a)'
complete -c matugen -s j -l json -r -f -a hsl -d 'HSL (h,s,l)'
complete -c matugen -s j -l json -r -f -a hsla -d 'HSLA (h,s,l,a)'
complete -c matugen -s j -l json -r -f -a strip -d 'Flat array without keys'

# Help and version
complete -c matugen -s h -l help -d 'Print help'
complete -c matugen -s V -l version -d 'Print version'
