# Adapted from radleylewis/zsh (MIT; see LICENSE).
(( $+commands[fzf] )) || return 0

_dotfiles_fzf_init() {
  local integration candidate
  if integration=$(fzf --zsh 2>/dev/null); then
    eval "$integration"
    return
  fi
  for candidate in /usr/share/fzf /usr/share/fzf/shell /usr/share/doc/fzf/examples \
      /opt/homebrew/opt/fzf/shell /usr/local/opt/fzf/shell "$HOME/.fzf/shell"; do
    if [[ -r "$candidate/key-bindings.zsh" ]]; then
      source "$candidate/key-bindings.zsh"
      if [[ -r "$candidate/completion.zsh" ]]; then source "$candidate/completion.zsh"; fi
      return
    fi
  done
}
_dotfiles_fzf_init
unfunction _dotfiles_fzf_init

if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix'
elif (( $+commands[fdfind] )); then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --strip-cwd-prefix'
elif (( $+commands[rg] )); then
  export FZF_DEFAULT_COMMAND='rg --files --hidden -g !.git'
else
  export FZF_DEFAULT_COMMAND='find . -type f'
fi
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border=rounded --preview-window=right:65%:wrap:border-left'
if (( $+commands[bat] )); then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=plain,numbers --line-range=:500 {}'"
elif (( $+commands[batcat] )); then
  export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=plain,numbers --line-range=:500 {}'"
fi

_dotfiles_visible_files() {
  if (( $+commands[fd] )); then command fd --type f --print0 --strip-cwd-prefix
  elif (( $+commands[fdfind] )); then command fdfind --type f --print0 --strip-cwd-prefix
  elif (( $+commands[rg] )); then command rg --files --null
  else command find . -name '.*' ! -name . -prune -o -type f -print0
  fi
}
_fzf_file_no_hidden() {
  local selected
  if IFS= read -r -d '' selected < <(_dotfiles_visible_files | FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS ${FZF_CTRL_T_OPTS:-}" fzf --read0 --print0); then
    LBUFFER+="${(q)selected}"
  fi
  zle reset-prompt
}
zle -N _fzf_file_no_hidden
