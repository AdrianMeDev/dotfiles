function mkcd --description 'Create a directory and change into it'
    if test (count $argv) -ne 1
        printf 'Usage: mkcd DIRECTORY\n' >&2
        return 2
    end
    mkdir -p -- "$argv[1]"; and cd -- "$argv[1]"
end
