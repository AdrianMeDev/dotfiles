#!/usr/bin/env bash

install_tools() {
    local dotnet_pkgs
    mapfile -t dotnet_pkgs < <(pkg_names dotnet-sdk)
    pkg_install "${dotnet_pkgs[@]}"
    if ! command -v mise >/dev/null 2>&1; then
        upstream_installer mise https://mise.run sh
    fi
    # Tool list lives in the repo config; mise reads it before the Stow links exist.
    local -x MISE_GLOBAL_CONFIG_FILE="$REPO_DIR/mise/.config/mise/config.toml"
    run mise install --yes
    run mise exec -- uv python install 3.14
    if has_extra java; then
        # Keep runtime state outside the Stow configuration; use via mise exec or local config.
        run mise install java@21
        log 'Java 21 installiert. Aktivieren: mise exec java@21 -- java -version; siehe README.'
    fi
    if has_extra rust; then
        if ! command -v rustup >/dev/null 2>&1 && [[ ! -x $HOME/.cargo/bin/rustup ]]; then
            upstream_installer rustup https://sh.rustup.rs sh -y --no-modify-path --profile minimal --default-toolchain stable
        else
            local rustup_cmd=rustup
            [[ -x $HOME/.cargo/bin/rustup ]] && rustup_cmd="$HOME/.cargo/bin/rustup"
            run "$rustup_cmd" toolchain install stable --profile minimal
        fi
    fi
}
