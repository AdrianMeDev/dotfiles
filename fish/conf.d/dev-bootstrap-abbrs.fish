abbr -a g git
abbr -a ga 'git add'
abbr -a gb 'git branch'
abbr -a gc 'git commit'
abbr -a gca 'git commit --amend'
abbr -a gco 'git checkout'
abbr -a gd 'git diff'
abbr -a gl 'git log --oneline --graph --decorate --all'
abbr -a gp 'git push'
abbr -a gpu 'git push -u origin (git branch --show-current)'
abbr -a gst 'git status -sb'
abbr -a v nvim
abbr -a t tmux
abbr -a dcu 'docker compose up'
abbr -a dcud 'docker compose up -d'
abbr -a dcd 'docker compose down'
abbr -a dps 'docker ps'
abbr -a dimg 'docker images'
abbr -a dj 'python manage.py'
abbr -a cch 'cargo check'
abbr -a cte 'cargo test'
abbr -a dot 'dotnet'

if type -q eza
    abbr -a ls 'eza --group-directories-first'
    abbr -a ll 'eza -la --git --group-directories-first'
    abbr -a la 'eza -a --group-directories-first'
    abbr -a lt 'eza --tree --level=2 --group-directories-first'
end

function mkcd --description 'Create directory and enter it'
    mkdir -p $argv[1]
    cd $argv[1]
end

function venv --description 'Create Python venv and activate it'
    python3 -m venv .venv
    source .venv/bin/activate.fish
end
