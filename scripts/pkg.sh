#!/usr/bin/env bash
# Löst logische Paketnamen aus manifests/packages.tsv pro Distro-Familie auf.
# Spalten: logical, group (base|desktop), arch, fedora, debian. "-" = überspringen.

if ! declare -F die >/dev/null 2>&1; then
    # shellcheck source=scripts/common.sh
    source "${BASH_SOURCE[0]%/*}/common.sh"
fi

PKG_MANIFEST=${PKG_MANIFEST:-${BASH_SOURCE[0]%/*}/../manifests/packages.tsv}

_pkg_column() {
    case "$1" in
        arch) printf '3\n' ;;
        fedora) printf '4\n' ;;
        debian) printf '5\n' ;;
        *) die "Unbekannte Distro-Familie: ${1:-<leer>}" ;;
    esac
}

# pkg_names LOGICAL [FAMILY]: Paketnamen (einer pro Zeile) für einen logischen Namen.
pkg_names() {
    local logical=${1:-} family=${2:-${DISTRO_FAMILY:-}}
    [[ -n $logical ]] || die 'pkg_names: logischer Name fehlt.'
    local col
    col=$(_pkg_column "$family") || return 1
    [[ -r $PKG_MANIFEST ]] || die "Paketmanifest fehlt: $PKG_MANIFEST"

    local name group c_arch c_fedora c_debian cell pkg found=0
    while IFS=$'\t' read -r name group c_arch c_fedora c_debian || [[ -n $name ]]; do
        [[ -z $name || $name == \#* ]] && continue
        [[ $name == "$logical" ]] || continue
        found=1
        case "$col" in 3) cell=$c_arch ;; 4) cell=$c_fedora ;; *) cell=$c_debian ;; esac
        [[ $cell == - ]] && continue
        local IFS=,
        for pkg in $cell; do printf '%s\n' "$pkg"; done
    done < "$PKG_MANIFEST"
    ((found)) || die "Unbekanntes Paket im Manifest: $logical"
}

# pkg_resolve FAMILY PROFILE: Paketnamen (einer pro Zeile); base immer, desktop nur bei Profil desktop.
pkg_resolve() {
    local family=${1:-} profile=${2:-}
    local col
    col=$(_pkg_column "$family") || return 1
    case "$profile" in
        headless|desktop) ;;
        *) die "Unbekanntes Profil: ${profile:-<leer>}" ;;
    esac
    [[ -r $PKG_MANIFEST ]] || die "Paketmanifest fehlt: $PKG_MANIFEST"

    local name group c_arch c_fedora c_debian cell pkg
    while IFS=$'\t' read -r name group c_arch c_fedora c_debian || [[ -n $name ]]; do
        [[ -z $name || $name == \#* ]] && continue
        [[ $group == base || ($group == desktop && $profile == desktop) ]] || continue
        case "$col" in 3) cell=$c_arch ;; 4) cell=$c_fedora ;; *) cell=$c_debian ;; esac
        [[ $cell == - ]] && continue
        local IFS=,
        for pkg in $cell; do printf '%s\n' "$pkg"; done
    done < "$PKG_MANIFEST"
}
