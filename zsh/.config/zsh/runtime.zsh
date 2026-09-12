# fnm and uv own Node/Python; mise handles other project runtimes.
export MISE_DISABLE_TOOLS=node,python
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi
if (( $+commands[fnm] )); then
  eval "$(fnm env --use-on-cd --version-file-strategy recursive --shell zsh)"
fi
