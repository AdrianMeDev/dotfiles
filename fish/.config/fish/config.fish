# Private settings belong in ~/.config/fish/local.fish (not versioned).
set -l data_home $HOME/.local/share
if set -q XDG_DATA_HOME
    set data_home $XDG_DATA_HOME
end
fish_add_path --global --move $HOME/.local/bin $data_home/fnm $HOME/.cargo/bin $HOME/.dotnet/tools

if command -q nvim
    set -gx EDITOR nvim
    set -gx VISUAL nvim
end

# No Node/Python activation through mise: fnm and uv own these runtimes.
set -gx MISE_DISABLE_TOOLS node,python
if command -q mise
    mise activate fish | source
end
if command -q fnm
    fnm env --use-on-cd --version-file-strategy recursive --shell fish | source
end

if status is-interactive
    set -g fish_greeting
    if command -q zoxide
        zoxide init fish | source
    end
    if command -q direnv
        direnv hook fish | source
    end
    if command -q fzf; and functions -q fzf_key_bindings
        fzf_key_bindings
    end
    if command -q starship
        starship init fish | source
    end

    abbr --add --global gs 'git status --short --branch'
    abbr --add --global gd 'git diff'
    abbr --add --global gds 'git diff --staged'
    abbr --add --global gl 'git log --oneline --graph --decorate -20'
    abbr --add --global ga 'git add'
    abbr --add --global gc 'git commit'
    abbr --add --global gsw 'git switch'
    abbr --add --global pps 'podman ps'
    abbr --add --global pc 'podman compose'
    abbr --add --global .. 'cd ..'
    abbr --add --global ... 'cd ../..'
    abbr --add --global ll 'ls -lah'
    abbr --add --global uvr 'uv run'
    abbr --add --global uvs 'uv sync'
end

if test -f $__fish_config_dir/local.fish
    source $__fish_config_dir/local.fish
end
