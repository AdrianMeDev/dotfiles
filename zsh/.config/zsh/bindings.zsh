# Vi-mode resets bindings during its deferred initialization.
ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none
zvm_config() {
  ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
  ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
  ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
}

_dotfiles_bindings() {
  local keymap
  for keymap in emacs viins; do
    bindkey -M "$keymap" '^[[1;5C' forward-word
    bindkey -M "$keymap" '^[[1;5D' backward-word
    if (( $+widgets[history-substring-search-up] )); then
      bindkey -M "$keymap" '^[[A' history-substring-search-up
      bindkey -M "$keymap" '^[[B' history-substring-search-down
    else
      bindkey -M "$keymap" '^[[A' history-beginning-search-backward
      bindkey -M "$keymap" '^[[B' history-beginning-search-forward
    fi
    if (( $+widgets[fzf-history-widget] )); then bindkey -M "$keymap" '^R' fzf-history-widget; fi
    if (( $+widgets[fzf-file-widget] )); then bindkey -M "$keymap" '^T' fzf-file-widget; fi
    if (( $+widgets[_fzf_file_no_hidden] )); then bindkey -M "$keymap" '^F' _fzf_file_no_hidden; fi
    if (( $+widgets[autosuggest-toggle] )); then bindkey -M "$keymap" '^\' autosuggest-toggle; fi
  done
}
zvm_after_init() { _dotfiles_bindings; }
# Native vi bindings also work when the optional plugin is absent.
bindkey -v
_dotfiles_bindings
