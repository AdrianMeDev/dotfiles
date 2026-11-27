#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for script in bootstrap.sh install.sh scripts/*.sh windows/*.sh agent-config/claude/*.sh dot/.local/bin/dot; do bash -n "$script"; done
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x bootstrap.sh install.sh scripts/*.sh windows/*.sh agent-config/claude/*.sh dot/.local/bin/dot
else
    printf 'SKIP: ShellCheck fehlt.\n'
fi
if command -v zsh >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do zsh -f -n "$file"; done < <(find zsh -type f \( -name '*.zsh' -o -name '.zshenv' -o -name '.zshrc' \) -print0)
else
    printf 'SKIP: zsh fehlt.\n'
fi
if command -v luajit >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
        DOTFILES_LUA_FILE="$file" luajit -e 'assert(loadfile(os.getenv("DOTFILES_LUA_FILE")))'
    done < <(find nvim wezterm windows hypr -name '*.lua' -print0)
else
    printf 'SKIP: LuaJIT fehlt.\n'
fi
python3 scripts/check-secrets.py --history

if command -v pwsh >/dev/null 2>&1; then
    # PowerShell variables must reach PowerShell literally.
    # shellcheck disable=SC2016
    if pwsh -NoProfile -Command 'if (Get-Module -ListAvailable Pester | Where-Object Version -ge ([version]"5.0")) { exit 0 } else { exit 1 }'; then
        pwsh -NoProfile -File windows/check.ps1
    else
        printf 'SKIP: Pester 5 fehlt (Install-Module Pester -MinimumVersion 5.0).\n'
    fi
else
    printf 'SKIP: PowerShell-Syntax und Pester-Tests (pwsh fehlt).\n'
fi
if command -v node >/dev/null 2>&1; then
    node --check windows/zebar/bar.mjs
else
    printf 'SKIP: Zebar-JavaScript-Syntax (node fehlt).\n'
fi

python3 -B -m unittest discover -s tests -v
