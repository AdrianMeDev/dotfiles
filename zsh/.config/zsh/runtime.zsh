# uv owns Python; mise handles Node and other project runtimes.
export MISE_DISABLE_TOOLS=python
if (( $+commands[mise] )); then
  if [[ -o interactive ]]; then
    eval "$(mise activate zsh)"
  else
    eval "$(mise activate zsh --shims)"
  fi
fi
