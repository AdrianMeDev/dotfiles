# Bootstrap the XDG configuration without changing /etc/zsh/zshenv.
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
source "$ZDOTDIR/.zshenv"
