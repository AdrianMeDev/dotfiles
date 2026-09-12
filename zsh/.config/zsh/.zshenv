# Environment also used by noninteractive editor tasks.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

typeset -U path PATH
path=("$HOME/.local/bin" "$XDG_DATA_HOME/fnm" "$HOME/.cargo/bin" "$HOME/.dotnet/tools" $path)
if (( $+commands[nvim] )); then
  export EDITOR=nvim VISUAL=nvim
fi
source "$ZDOTDIR/runtime.zsh"
# Interactive overrides run after all other modules in .zshrc.
if [[ ! -o interactive && -f "$ZDOTDIR/local.zsh" ]]; then
  source "$ZDOTDIR/local.zsh"
fi
