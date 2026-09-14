#!/usr/bin/env bash
set -euo pipefail
for tool in powershell.exe wslpath; do
    command -v "$tool" >/dev/null 2>&1 || { printf 'Fehlt: %s (in WSL mit Windows-Interop ausführen).\n' "$tool" >&2; exit 1; }
done
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# -File passes arguments as data; no generated PowerShell command string.
exec powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$script_dir/install.ps1")" "$@"
