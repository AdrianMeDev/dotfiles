if status --is-interactive
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx PAGER less
end

starship init fish | source
