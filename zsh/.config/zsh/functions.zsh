mkcd() {
  if (( $# != 1 )); then
    print -u2 'Usage: mkcd DIRECTORY'
    return 2
  fi
  mkdir -p -- "$1" && builtin cd -- "$1"
}

croot() {
  local root
  root=$(command git rev-parse --show-toplevel 2>/dev/null) || {
    print -u2 'Not inside a Git worktree.'
    return 1
  }
  builtin cd -- "$root"
}

fe() {
  if (( ! $+commands[fzf] || ! $+commands[rg] )); then
    print -u2 'fe needs fzf and ripgrep.'
    return 1
  fi
  local selected
  local -a editor
  IFS= read -r -d '' selected < <(command rg --files --null | fzf --read0 --print0) || return 0
  editor=( ${(z)${EDITOR:-nvim}} )
  command "${(@Q)editor}" -- "$selected"
}

tp() {
  if (( $# > 1 )); then
    print -u2 'Usage: tp [DIRECTORY]'
    return 2
  fi
  if (( ! $+commands[tmux] )); then
    print -u2 'tp needs tmux.'
    return 1
  fi
  local project=$PWD root label digest session
  if (( $# )); then
    project=$1
  elif root=$(command git rev-parse --show-toplevel 2>/dev/null); then
    project=$root
  fi
  project=${project:A}
  if [[ ! -d $project ]]; then
    print -u2 'Directory does not exist.'
    return 1
  fi
  label=${project:t}
  label=${label//[^a-zA-Z0-9_-]/_}
  digest=$(printf '%s' "$project" | sha256sum) || return
  session="$label-${digest[1,8]}"
  if [[ -n ${TMUX:-} ]]; then
    if ! command tmux has-session -t "=$session" 2>/dev/null; then
      command tmux new-session -d -s "$session" -c "$project" || return
    fi
    command tmux switch-client -t "=$session"
  else
    command tmux new-session -A -s "$session" -c "$project"
  fi
}
