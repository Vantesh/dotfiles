# Fish completions for matugen

# Global options
complete -c matugen -s t -l type -d 'Sets a custom color scheme type' -xa 'scheme-content\t"Content-based color scheme" scheme-expressive\t"Expressive and vibrant colors" scheme-fidelity\t"High color fidelity scheme" scheme-fruit-salad\t"Colorful fruit salad palette" scheme-monochrome\t"Single color monochrome scheme" scheme-neutral\t"Neutral balanced colors" scheme-rainbow\t"Full spectrum rainbow colors" scheme-tonal-spot\t"Tonal spot color scheme"'
complete -c matugen -s c -l config -d 'Sets a custom config file' -r -F
complete -c matugen -s p -l prefix -d 'Sets a custom config file' -r -a '(__fish_complete_directories)'
complete -c matugen -l contrast -d 'Value from -1 to 1. -1 represents minimum contrast, 0 represents standard, and 1 represents maximum contrast' -r
complete -c matugen -s v -l verbose -d 'Verbose output'
complete -c matugen -s q -l quiet -d 'Whether to show no output'
complete -c matugen -s d -l debug -d 'Whether to show debug output'
complete -c matugen -s m -l mode -d 'Which mode to use for the color scheme' -xa 'light\t"Generate light theme colors" dark\t"Generate dark theme colors"'
complete -c matugen -l dry-run -d 'Will not generate templates, reload apps, set wallpaper or run any commands'
complete -c matugen -l show-colors -d 'Whether to show colors or not'
complete -c matugen -s j -l json -d 'Whether to dump json of colors' -xa 'hex rgb rgba hsl hsla strip'
complete -c matugen -s h -l help -d 'Print help'
complete -c matugen -s V -l version -d 'Print version'

# Helper functions for subcommand detection
function __fish_matugen_no_subcommand
    set -l cmd (commandline -poc)
    set -e cmd[1]
    for i in $cmd
        switch $i
            case image color help
                return 1
        end
    end
    return 0
end

function __fish_matugen_using_subcommand
    set -l cmd (commandline -poc)
    set -e cmd[1]
    if test (count $cmd) -eq 0
        return 1
    end
    if contains -- $argv[1] $cmd[1]
        return 0
    end
    return 1
end

# Subcommands
complete -c matugen -n __fish_matugen_no_subcommand -f -a image -d 'The image to use for generating a color scheme'
complete -c matugen -n __fish_matugen_no_subcommand -f -a color -d 'The source color to use for generating a color scheme'
complete -c matugen -n __fish_matugen_no_subcommand -f -a help -d 'Print this message or the help of the given subcommand(s)'

# Image subcommand - expects image files and supports same global options
complete -c matugen -n '__fish_matugen_using_subcommand image' -F
# Add specific path argument completion for image command
complete -c matugen -n '__fish_matugen_using_subcommand image' -s t -l type -d 'Sets a custom color scheme type' -xa 'scheme-content\t"Content-based color scheme" scheme-expressive\t"Expressive and vibrant colors" scheme-fidelity\t"High color fidelity scheme" scheme-fruit-salad\t"Colorful fruit salad palette" scheme-monochrome\t"Single color monochrome scheme" scheme-neutral\t"Neutral balanced colors" scheme-rainbow\t"Full spectrum rainbow colors" scheme-tonal-spot\t"Tonal spot color scheme"'
complete -c matugen -n '__fish_matugen_using_subcommand image' -s c -l config -d 'Sets a custom config file' -r -F
complete -c matugen -n '__fish_matugen_using_subcommand image' -s p -l prefix -d 'Sets a custom config file' -r -a '(__fish_complete_directories)'
complete -c matugen -n '__fish_matugen_using_subcommand image' -l contrast -d 'Value from -1 to 1. -1 represents minimum contrast, 0 represents standard, and 1 represents maximum contrast' -r
complete -c matugen -n '__fish_matugen_using_subcommand image' -s v -l verbose -d 'Verbose output'
complete -c matugen -n '__fish_matugen_using_subcommand image' -s q -l quiet -d 'Whether to show no output'
complete -c matugen -n '__fish_matugen_using_subcommand image' -s d -l debug -d 'Whether to show debug output'
complete -c matugen -n '__fish_matugen_using_subcommand image' -s m -l mode -d 'Which mode to use for the color scheme' -xa 'light\t"Generate light theme colors" dark\t"Generate dark theme colors"'
complete -c matugen -n '__fish_matugen_using_subcommand image' -l dry-run -d 'Will not generate templates, reload apps, set wallpaper or run any commands'
complete -c matugen -n '__fish_matugen_using_subcommand image' -l show-colors -d 'Whether to show colors or not'
complete -c matugen -n '__fish_matugen_using_subcommand image' -s j -l json -d 'Whether to dump json of colors' -xa 'hex rgb rgba hsl hsla strip'
complete -c matugen -n '__fish_matugen_using_subcommand image' -s h -l help -d 'Print help'

# Color subcommand - has its own subcommands and supports global options
complete -c matugen -n '__fish_matugen_using_subcommand color' -f -a 'hex rgb hsl help' -d 'Color format subcommands'
complete -c matugen -n '__fish_matugen_using_subcommand color' -s t -l type -d 'Sets a custom color scheme type' -xa 'scheme-content\t"Content-based color scheme" scheme-expressive\t"Expressive and vibrant colors" scheme-fidelity\t"High color fidelity scheme" scheme-fruit-salad\t"Colorful fruit salad palette" scheme-monochrome\t"Single color monochrome scheme" scheme-neutral\t"Neutral balanced colors" scheme-rainbow\t"Full spectrum rainbow colors" scheme-tonal-spot\t"Tonal spot color scheme"'
complete -c matugen -n '__fish_matugen_using_subcommand color' -s c -l config -d 'Sets a custom config file' -r -F
complete -c matugen -n '__fish_matugen_using_subcommand color' -s p -l prefix -d 'Sets a custom config file' -r -a '(__fish_complete_directories)'
complete -c matugen -n '__fish_matugen_using_subcommand color' -l contrast -d 'Value from -1 to 1. -1 represents minimum contrast, 0 represents standard, and 1 represents maximum contrast' -r
complete -c matugen -n '__fish_matugen_using_subcommand color' -s v -l verbose -d 'Verbose output'
complete -c matugen -n '__fish_matugen_using_subcommand color' -s q -l quiet -d 'Whether to show no output'
complete -c matugen -n '__fish_matugen_using_subcommand color' -s d -l debug -d 'Whether to show debug output'
complete -c matugen -n '__fish_matugen_using_subcommand color' -s m -l mode -d 'Which mode to use for the color scheme' -xa 'light\t"Generate light theme colors" dark\t"Generate dark theme colors"'
complete -c matugen -n '__fish_matugen_using_subcommand color' -l dry-run -d 'Will not generate templates, reload apps, set wallpaper or run any commands'
complete -c matugen -n '__fish_matugen_using_subcommand color' -l show-colors -d 'Whether to show colors or not'
complete -c matugen -n '__fish_matugen_using_subcommand color' -s j -l json -d 'Whether to dump json of colors' -xa 'hex rgb rgba hsl hsla strip'
complete -c matugen -n '__fish_matugen_using_subcommand color' -s h -l help -d 'Print help'

# Help subcommand - can show help for other subcommands
complete -c matugen -n '__fish_matugen_using_subcommand help' -a 'image color' -f
