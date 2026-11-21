#!/usr/bin/env bash

install_agents() {
    local flags=()
    ((DRY_RUN)) && flags+=(--dry-run)
    ((BACKUP)) && flags+=(--backup)
    python3 "$REPO_DIR/scripts/agents.py" "${flags[@]}"
}
