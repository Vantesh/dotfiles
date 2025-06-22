
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

vivid_theme="catppuccin-mocha"

#---------------------------------------------------
# PLUGIN MANAGER
#---------------------------------------------------

# basic plugin manager to automatically import zsh plugins
# script by mattmc3 from https://github.com/mattmc3/zsh_unplugged
# clone a plugin, identify its init file, source it, and add it to your fpath
function plugin-load {
	local repo plugdir initfile initfiles=()
	: ${ZPLUGINDIR:=${ZDOTDIR:-~/.config/zsh}/plugins}
	for repo in $@; do
		plugdir=$ZPLUGINDIR/${repo:t}
		initfile=$plugdir/${repo:t}.plugin.zsh
		if [[ ! -d $plugdir ]]; then
			echo "Cloning $repo..."
			git clone -q --depth 1 --recursive --shallow-submodules \
				https://github.com/$repo $plugdir
		fi
		if [[ ! -e $initfile ]]; then
			initfiles=($plugdir/*.{plugin.zsh,zsh-theme,zsh,sh}(N))
			(( $#initfiles )) || { echo >&2 "No init file '$repo'." && continue }
			ln -sf $initfiles[1] $initfile
		fi
		fpath+=$plugdir
		(( $+functions[zsh-defer] )) && zsh-defer . $initfile || . $initfile
	done
}

plugin-update() {
  for dir in ${(f)"$(command find ${ZPLUGINDIR:-~/.config/zsh/plugins} -mindepth 1 -maxdepth 1 -type d)"}; do
    echo "Updating ${dir:t}..."
    git -C $dir pull --ff-only --quiet || echo "❌ Failed to update ${dir:t}"
  done
}

# list of github repos of plugins
repos=(
  ryanccn/vivid-zsh
	zsh-users/zsh-autosuggestions
	zsh-users/zsh-history-substring-search
	zdharma-continuum/fast-syntax-highlighting
)
plugin-load $repos


# ---------------------------------------------------
# HISTORY SETTINGS
# ---------------------------------------------------
HISTFILE="${ZDOTDIR}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# ---------------------------------------------------
# LOAD ALIASES, EXPORTS AND OPTIONS
# ---------------------------------------------------

ZDOTDIR="${ZDOTDIR:-$HOME}"
for file in optionrc aliasrc exportsrc; do
  [ -r "$ZDOTDIR/$file" ] && source "$ZDOTDIR/$file"
done


# ---------------------------------------------------
# COMPINIT
# ---------------------------------------------------

# Autoload compinit
autoload -Uz compinit

ZCDUMP=~/.config/zsh/zcompdump
if [[ -n ${~ZCDUMP}(N.mh+24) ]]; then
  compinit -d $ZCDUMP
else
  compinit -C -d $ZCDUMP
fi

# Extras
autoload -Uz colors && colors
autoload -Uz add-zsh-hook
_comp_options+=(globdots)

# ---------------------------------------------------
# COMPLETION STYLES
# ---------------------------------------------------

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' rehash true
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' completer _complete _match _approximate

# Use completion result caching
zstyle ':completion:*:paths' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcache"


# ---------------------------------------------------
# KEY BINDINGS
# ---------------------------------------------------
zmodload zsh/terminfo
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey '^[[A' history-substring-search-up
bindkey '^[OA' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OB' history-substring-search-down
bindkey -M vicmd '^[[A' history-substring-search-up 
bindkey -M vicmd '^[OA' history-substring-search-up 
bindkey -M vicmd '^[[B' history-substring-search-down
bindkey -M vicmd '^[OB' history-substring-search-down
bindkey -M viins '^[[A' history-substring-search-up 
bindkey -M viins '^[OA' history-substring-search-up 
bindkey -M viins '^[[B' history-substring-search-down 
bindkey -M viins '^[OB' history-substring-search-down


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

