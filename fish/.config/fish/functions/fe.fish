function fe --description 'Select a project file with fzf and open it in the editor'
    if not command -q fzf; or not command -q rg
        printf 'fe needs fzf and ripgrep.\n' >&2
        return 1
    end
    set -l selected (command rg --files --null | fzf --read0 --print0 | string split0)
    if test (count $selected) -eq 0
        return
    end
    set -l editor nvim
    if set -q EDITOR
        set editor (string split ' ' -- "$EDITOR")
    end
    command $editor -- "$selected"
end
