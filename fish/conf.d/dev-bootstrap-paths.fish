fish_add_path ~/.local/bin ~/bin ~/.cargo/bin

set -l fnm_dir "$HOME/.local/share/fnm"
if test -d "$fnm_dir"
    fish_add_path $fnm_dir
end

if type -q zoxide
    zoxide init fish | source
end

if type -q direnv
    direnv hook fish | source
end

if type -q fnm
    fnm env --use-on-cd --shell fish | source
end
