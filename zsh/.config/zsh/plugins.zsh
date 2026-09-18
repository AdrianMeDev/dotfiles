# Explicit installation only; startup never fetches plugins.
# Adapted from radleylewis/zsh (MIT; see LICENSE).
typeset -g ZPLUGINDIR="$XDG_DATA_HOME/zsh/plugins"
typeset -g ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'
typeset -ga _dotfiles_zplugins=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-history-substring-search
  jeffreytse/zsh-vi-mode
  zdharma-continuum/fast-syntax-highlighting
)

zplugin-install() {
  (( $+commands[git] )) || { print -u2 'zplugin-install needs git.'; return 1; }
  local plugin destination temporary
  local failed=0
  mkdir -p -- "$ZPLUGINDIR" || return
  for plugin in "${_dotfiles_zplugins[@]}"; do
    destination="$ZPLUGINDIR/${plugin:t}"
    if [[ -e $destination || -L $destination ]]; then
      if [[ ! -f "$destination/${plugin:t}.plugin.zsh" ]]; then
        print -u2 "Incomplete plugin: $destination (move it aside and retry)."
        failed=1
      fi
      continue
    fi
    temporary=$(mktemp -d "$ZPLUGINDIR/.install.XXXXXXXX") || return
    if command git clone --depth=1 "https://github.com/$plugin" "$temporary" &&
        [[ -f "$temporary/${plugin:t}.plugin.zsh" ]] &&
        command mv -T -n -- "$temporary" "$destination"; then
      print "Installed ${plugin:t}; open a new zsh to load it."
    else
      print -u2 "Failed to install ${plugin:t}; run zplugin-install to retry."
      failed=1
    fi
    # Only the temporary directory created by this invocation may be removed.
    [[ ! -d $temporary ]] || command rm -rf -- "$temporary"
  done
  return $failed
}

zplugin-update() {
  (( $+commands[git] )) || { print -u2 'zplugin-update needs git.'; return 1; }
  local plugin destination
  local failed=0
  for plugin in "${_dotfiles_zplugins[@]}"; do
    destination="$ZPLUGINDIR/${plugin:t}"
    [[ -d "$destination/.git" ]] || continue
    command git -C "$destination" pull --ff-only || failed=1
  done
  return $failed
}

_dotfiles_zplugin_load() {
  local plugin
  for plugin in "${_dotfiles_zplugins[@]}"; do
    if [[ -r "$ZPLUGINDIR/${plugin:t}/${plugin:t}.plugin.zsh" ]]; then
      if [[ ${plugin:t} = fast-syntax-highlighting ]]; then
        # Upstream downloads this theme if absent. Seed it from the local clone.
        typeset -g FAST_WORK_DIR="$XDG_CACHE_HOME/zsh/fsh"
        if [[ ! -e "$FAST_WORK_DIR/secondary_theme.zsh" ]]; then
          mkdir -p -- "$FAST_WORK_DIR" || continue
          command cp -- "$ZPLUGINDIR/${plugin:t}/share/free_theme.zsh" \
            "$FAST_WORK_DIR/secondary_theme.zsh" || continue
        fi
      fi
      source "$ZPLUGINDIR/${plugin:t}/${plugin:t}.plugin.zsh"
      if [[ ${plugin:t} = fast-syntax-highlighting ]]; then
        # Tokyo Night: apply a compact overlay without downloading another theme.
        FAST_HIGHLIGHT_STYLES[defaultunknown-token]='fg=#f7768e,bold'
        FAST_HIGHLIGHT_STYLES[defaultreserved-word]='fg=#bb9af7'
        FAST_HIGHLIGHT_STYLES[defaultcommand]='fg=#7aa2f7'
        FAST_HIGHLIGHT_STYLES[defaultbuiltin]='fg=#2ac3de'
        FAST_HIGHLIGHT_STYLES[defaultfunction]='fg=#7dcfff'
        FAST_HIGHLIGHT_STYLES[defaultpath]='fg=#73daca,underline'
        FAST_HIGHLIGHT_STYLES[defaultsingle-quoted-argument]='fg=#9ece6a'
        FAST_HIGHLIGHT_STYLES[defaultdouble-quoted-argument]='fg=#9ece6a'
        FAST_HIGHLIGHT_STYLES[defaultcomment]='fg=#565f89'
        FAST_HIGHLIGHT_STYLES[defaultvariable]='fg=#e0af68'
      fi
    fi
  done
}
_dotfiles_zplugin_load
unfunction _dotfiles_zplugin_load
