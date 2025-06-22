# If not running interactively, don't do anything
[[ $- != *i* ]] && return

vivid_theme="catppuccin-mocha"

#history
HISTFILE="${ZDOTDIR}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase

# clone antidote if it doesn't exist
if [ ! -d "${ZDOTDIR:-$HOME}/.antidote" ]; then
  echo "Cloning antidote..."
  git clone --depth=1 https://github.com/mattmc3/antidote.git "${ZDOTDIR:-$HOME}/.antidote"
fi
zstyle ':plugin:ez-compinit' 'compstyle' 'ohmy'
#keybindings
bindkey -e
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down


ZDOTDIR="${ZDOTDIR:-$HOME}"
for file in optionrc aliasrc exportsrc; do
  [ -r "$ZDOTDIR/$file" ] && source "$ZDOTDIR/$file"
done

# Lazy-load antidote and generate the static load file only when needed
zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  source "${ZDOTDIR:-$HOME}/.antidote/antidote.zsh"
  antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
fi

source ${zsh_plugins}.zsh
# Lazy-load antidote from its functions directory.
fpath=(${ZDOTDIR:-$HOME}/.antidote/functions $fpath)
autoload -Uz antidote

# other zstyles after loading antidote

zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' rehash true  # automatically find new commands

# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completion"



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


