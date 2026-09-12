function tp --description 'Attach/create a tmux session for a project directory'
    if test (count $argv) -gt 1
        printf 'Usage: tp [DIRECTORY]\n' >&2
        return 2
    end
    if not command -q tmux
        printf 'tp needs tmux.\n' >&2
        return 1
    end
    set -l project $PWD
    if test (count $argv) -eq 1
        set project "$argv[1]"
    else
        set -l root (command git rev-parse --show-toplevel 2>/dev/null)
        if test $status -eq 0
            set project "$root"
        end
    end
    set project (path resolve -- "$project")
    if not test -d "$project"
        printf 'Directory does not exist.\n' >&2
        return 1
    end
    set -l label (string replace -ar '[^a-zA-Z0-9_-]' '_' -- (path basename -- "$project"))
    set -l digest (printf '%s' "$project" | sha256sum | string sub -l 8)
    set -l session "$label-$digest"
    if set -q TMUX
        if not command tmux has-session -t "=$session" 2>/dev/null
            command tmux new-session -d -s "$session" -c "$project"; or return
        end
        command tmux switch-client -t "=$session"
    else
        command tmux new-session -A -s "$session" -c "$project"
    end
end
