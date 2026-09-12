function croot --description 'Change to the Git worktree root'
    set -l root (command git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        printf 'Not inside a Git worktree.\n' >&2
        return 1
    end
    cd -- "$root"
end
