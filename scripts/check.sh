#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for script in install.sh scripts/*.sh; do bash -n "$script"; done
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x install.sh scripts/*.sh
else
    printf 'SKIP: ShellCheck fehlt.\n'
fi
if command -v fish >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do fish --no-config -n "$file"; done < <(find fish -name '*.fish' -print0)
else
    printf 'SKIP: Fish fehlt.\n'
fi
if command -v luajit >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
        DOTFILES_LUA_FILE="$file" luajit -e 'assert(loadfile(os.getenv("DOTFILES_LUA_FILE")))'
    done < <(find nvim wezterm -name '*.lua' -print0)
else
    printf 'SKIP: LuaJIT fehlt.\n'
fi
python3 scripts/check-secrets.py --history
python3 -B -m unittest discover -s tests -v
