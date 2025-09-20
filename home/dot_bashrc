#!/usr/bin/env bash
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='\[\e[32m\]\u\[\e[37m\]@\[\e[36m\]\h\[\e[37m\] in \[\e[35m\]\w\n\[\e[32m\]\$ \[\e[0m\]'

# shellcheck disable=SC1091
[[ -f "$HOME/.config/shell/exportsrc" ]] && source "$HOME/.config/shell/exportsrc"
# shellcheck disable=SC1091
[[ -f "$HOME/.config/shell/aliasrc" ]] && source "$HOME/.config/shell/aliasrc"
# shellcheck disable=SC1091
[[ -f /usr/share/doc/pkgfile/command-not-found.bash ]] && source /usr/share/doc/pkgfile/command-not-found.bash

export HISTFILE="${XDG_CACHE_HOME}/bash/history"

## GENERAL OPTIONS ##

# Prevent file overwrite on stdout redirection
# Use `>|` to force redirection to an existing file
set -o noclobber

# Update window size after every command
shopt -s checkwinsize

# Automatically trim long paths in the prompt (requires Bash 4.x)
PROMPT_DIRTRIM=2

# Enable history expansion with space
# E.g. typing !!<space> will replace the !! with your last command
bind Space:magic-space

# Turn on recursive globbing (enables ** to recurse all directories)
shopt -s globstar 2>/dev/null

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

## SMARTER TAB-COMPLETION (Readline bindings) ##

# Perform file completion in a case insensitive fashion
bind "set completion-ignore-case on"

# Treat hyphens and underscores as equivalent
bind "set completion-map-case on"

# Display matches for ambiguous patterns at first tab press
bind "set show-all-if-ambiguous on"

# Immediately add a trailing slash when autocompleting symlinks to directories
bind "set mark-symlinked-directories on"

## SANE HISTORY DEFAULTS ##

# Append to the history file, don't overwrite it
shopt -s histappend

# Save multi-line commands as one command
shopt -s cmdhist

# Record each line as it gets issued
PROMPT_COMMAND='history -a'

# Huge history. Doesn't appear to slow things down, so why not?
HISTSIZE=500000
HISTFILESIZE=100000

# Avoid duplicate entries
HISTCONTROL="erasedups:ignoreboth"

# Don't record some commands
export HISTIGNORE="&:[ ]*:exit:ls:bg:fg:history:clear"

# Use standard ISO 8601 timestamp
# %F equivalent to %Y-%m-%d
# %T equivalent to %H:%M:%S (24-hours format)
HISTTIMEFORMAT='%F %T '

# Enable incremental history search with up/down arrows (also Readline goodness)
# Learn more about this here: http://codeinthehole.com/writing/the-most-important-command-line-tip-incremental-history-searching-with-inputrc/
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e[C": forward-char'
bind '"\e[D": backward-char'

## BETTER DIRECTORY NAVIGATION ##

# Prepend cd to directory names automatically
shopt -s autocd 2>/dev/null
# Correct spelling errors during tab-completion
shopt -s dirspell 2>/dev/null
# Correct spelling errors in arguments supplied to cd
shopt -s cdspell 2>/dev/null

# Better cd
if command -v zoxide &>/dev/null; then
  export _ZO_ECHO=0
  eval "$(zoxide init --cmd cd bash)"
fi
