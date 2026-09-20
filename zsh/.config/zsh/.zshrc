# Adapted from https://github.com/radleylewis/zsh (MIT; see LICENSE).
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000
mkdir -p -- "${HISTFILE:h}" "$XDG_CACHE_HOME/zsh"
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS AUTOCD NOBEEP NUMERIC_GLOB_SORT

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

source "$ZDOTDIR/functions.zsh"
source "$ZDOTDIR/aliases.zsh"
if (( $+commands[zoxide] )); then eval "$(zoxide init zsh)"; fi
if (( $+commands[direnv] )); then eval "$(direnv hook zsh)"; fi
source "$ZDOTDIR/fzf.zsh"
source "$ZDOTDIR/bindings.zsh"
source "$ZDOTDIR/plugins.zsh"
source "$ZDOTDIR/prompt.zsh"
if [[ -f "$ZDOTDIR/local.zsh" ]]; then source "$ZDOTDIR/local.zsh"; fi

# Pi
export PATH="/home/ame/.local/share/fnm/node-versions/v24.21.0/installation/bin:$PATH"
