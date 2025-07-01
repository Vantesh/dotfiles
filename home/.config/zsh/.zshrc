
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#---------------------------------------------------
# PLUGIN MANAGER
#---------------------------------------------------

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit --wait --lucid for \
		@zsh-users/zsh-history-substring-search \
    --atinit="ZINIT[COMPINIT_OPTS]=-C; zicompinit; autoload -U bashcompinit && bashcompinit; zicdreplay" \
    --nocd --atload="fast-theme XDG:catppuccin-mocha -q" \
    @zdharma-continuum/fast-syntax-highlighting \
    \
    --blockf --atpull="zinit creinstall -q ." \
    @zsh-users/zsh-completions \
    \
    --nocd --atload="!_zsh_autosuggest_start" \
    @zsh-users/zsh-autosuggestions \
    --atinit'vivid_theme="catppuccin-mocha"' \
    --atload'zstyle ":completion:*"  list-colors "${(s.:.)LS_COLORS}"' \
   @ryanccn/vivid-zsh\


zinit --wait=2 --lucid --is-snippet --id-as='auto' --nocd for \
    --if="[[ -e /usr/share/doc/pkgfile/command-not-found.zsh ]]" \
    --atload="[[ -e /usr/share/doc/find-the-command/ftc.zsh ]] && source /usr/share/doc/find-the-command/ftc.zsh" \
    /usr/share/doc/pkgfile/command-not-found.zsh

# ---------------------------------------------------
# HISTORY SETTINGS
# ---------------------------------------------------
HISTFILE="${ZDOTDIR}/.zsh_history"
HISTSIZE=5000
SAVEHIST=$HISTSIZE
setopt APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt INC_APPEND_HISTORY
setopt HIST_REDUCE_BLANKS
setopt HIST_EXPIRE_DUPS_FIRST
# ---------------------------------------------------
# options
# ---------------------------------------------------
setopt AUTO_CD
setopt EXTENDED_GLOB
setopt NO_CASE_GLOB
setopt RC_EXPAND_PARAM
setopt CHECK_JOBS
setopt NUMERIC_GLOB_SORT
setopt NO_BEEP
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_MINUS
setopt NOTIFY
setopt INTERACTIVE_COMMENTS
setopt CORRECT
setopt GLOB_DOTS
setopt LONG_LIST_JOBS
setopt PROMPT_SUBST

# ---------------------------------------------------
# LOAD ALIASES AND EXPORTS
# ---------------------------------------------------

ZDOTDIR="${ZDOTDIR:-$HOME}"
for file in aliasrc exportsrc; do
  [ -r "$ZDOTDIR/$file" ] && source "$ZDOTDIR/$file"
done


# ---------------------------------------------------
# ZSH AUTOLOADS AND CONFIGURATION
# ---------------------------------------------------

autoload -Uz colors && colors

# ---------------------------------------------------
# COMPLETION STYLES
# ---------------------------------------------------

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:paths' accept-exact '*(N)'

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompcache"

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bold,standout'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='none'
HISTORY_SUBSTRING_SEARCH_FUZZY="yes"

# ---------------------------------------------------
# KEY BINDINGS
# ---------------------------------------------------

# Bind the Up arrow key (history substring search up)
bindkey '^[[A' history-substring-search-up
bindkey '^[OA' history-substring-search-up

# Bind the Down arrow key (history substring search down)
bindkey '^[[B' history-substring-search-down
bindkey '^[OB' history-substring-search-down


# ----------------------------------------------------
# SHELL INTERGRATIONS
# ----------------------------------------------------

if command -v fzf &>/dev/null; then
  eval "$(fzf --zsh)"
  export FZF_DEFAULT_OPTS=" \
--height 40%  --layout reverse --border rounded --info right \
--preview 'bat --style=numbers --color=always {} || highlight --syntax=sh {} || cat {}' \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--color=border:#313244,label:#cdd6f4"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init --cmd cd zsh)"
fi

if command -v oh-my-posh &>/dev/null; then
  eval "$(oh-my-posh init zsh --config "${ZDOTDIR}/ohmyposh/ohmyposh.toml")"
fi


# instantly rehash all zsh instances
TRAPUSR1() { rehash }

# ----------------------------------------------------
# ZSH SPECIFIC ALIASES
# ----------------------------------------------------

ref() {
    exec zsh
}

