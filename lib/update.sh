#!/bin/bash
# servus - update checker and upgrader

_REMOTE_VERSION_URL="https://raw.githubusercontent.com/ruhanirabin/servus/main/VERSION"
_RAW_BASE="https://raw.githubusercontent.com/ruhanirabin/servus/main"

# Compare two semver strings. Returns 0 if $1 > $2, 1 otherwise.
_version_gt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && [ "$1" != "$2" ]
}

_major() { echo "$1" | cut -d. -f1; }

# Fetch remote version silently. Prints version string or empty string on failure.
fetch_remote_version() {
    curl -fsSL --connect-timeout 5 "$_REMOTE_VERSION_URL" 2>/dev/null | tr -d '[:space:]'
}

# Passive check — used by `servus status`. Prints one line if update available, silent otherwise.
check_version_hint() {
    local local_ver="$1"
    local remote_ver
    remote_ver=$(fetch_remote_version)

    [[ -z "$remote_ver" ]] && return 0

    if _version_gt "$remote_ver" "$local_ver"; then
        if [ "$(_major "$remote_ver")" -gt "$(_major "$local_ver")" ]; then
            warn "Update available: v${local_ver} → v${remote_ver}  ${BOLD}(major — review changelog before upgrading)${NC}"
        else
            info "Update available: v${local_ver} → v${remote_ver}  — run 'servus update' to upgrade"
        fi
    fi
}

# Full interactive update command
run_update() {
    local local_ver="$SERVUS_VERSION"

    info "Checking for updates..."
    local remote_ver
    remote_ver=$(fetch_remote_version)

    if [[ -z "$remote_ver" ]]; then
        warn "Could not reach GitHub to check for updates. Check your connection."
        return 1
    fi

    echo "  Installed : v${local_ver}"
    echo "  Latest    : v${remote_ver}"
    echo ""

    if ! _version_gt "$remote_ver" "$local_ver"; then
        success "Already up to date (v${local_ver})."
        return 0
    fi

    local is_major=false
    if [ "$(_major "$remote_ver")" -gt "$(_major "$local_ver")" ]; then
        is_major=true
    fi

    if $is_major; then
        echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  MAJOR VERSION UPGRADE: v${local_ver} → v${remote_ver}          ${NC}"
        echo -e "${YELLOW}║  Major upgrades may include breaking changes.    ${NC}"
        echo -e "${YELLOW}║  Review the changelog before proceeding:         ${NC}"
        echo -e "${YELLOW}║  https://github.com/ruhanirabin/servus/releases  ${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        read -rp "Type 'yes' to proceed with the major upgrade: " confirm
        [[ "$confirm" != "yes" ]] && { info "Upgrade cancelled."; return 0; }
    else
        echo -e "${GREEN}Non-breaking upgrade available (v${local_ver} → v${remote_ver}).${NC}"
        read -rp "Upgrade now? [Y/n]: " confirm
        [[ "${confirm,,}" == "n" ]] && { info "Upgrade cancelled."; return 0; }
    fi

    _do_upgrade "$remote_ver"
}

_do_upgrade() {
    local new_ver="$1"
    local lib_dir="$SERVUS_LIB_DIR"
    local install_bin
    install_bin=$(dirname "$(command -v servus 2>/dev/null || echo "/usr/local/bin/servus")")

    info "Upgrading servus to v${new_ver}..."

    local files=(
        "VERSION:${lib_dir}/VERSION"
        "servus.sh:${install_bin}/servus"
        "lib/common.sh:${lib_dir}/lib/common.sh"
        "lib/setup.sh:${lib_dir}/lib/setup.sh"
        "lib/cron.sh:${lib_dir}/lib/cron.sh"
        "lib/detect.sh:${lib_dir}/lib/detect.sh"
        "lib/update.sh:${lib_dir}/lib/update.sh"
        "modules/disk-report.sh:${lib_dir}/modules/disk-report.sh"
        "modules/log-vacuum.sh:${lib_dir}/modules/log-vacuum.sh"
        "modules/system-info.sh:${lib_dir}/modules/system-info.sh"
        "modules/cpu-ram-alert.sh:${lib_dir}/modules/cpu-ram-alert.sh"
        "modules/service-watchdog.sh:${lib_dir}/modules/service-watchdog.sh"
        "modules/swap-alert.sh:${lib_dir}/modules/swap-alert.sh"
        "modules/tmp-cleanup.sh:${lib_dir}/modules/tmp-cleanup.sh"
        "modules/heartbeat.sh:${lib_dir}/modules/heartbeat.sh"
    )

    local failed=()
    for entry in "${files[@]}"; do
        local src="${entry%%:*}"
        local dst="${entry##*:}"
        if curl -fsSL --connect-timeout 10 "${_RAW_BASE}/${src}" -o "${dst}.tmp" 2>/dev/null; then
            mv "${dst}.tmp" "$dst"
            chmod +x "$dst"
        else
            rm -f "${dst}.tmp"
            failed+=("$src")
            warn "Failed to download: $src"
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        warn "Upgrade incomplete — ${#failed[@]} file(s) failed to download."
        warn "Run 'servus update' again or reinstall manually."
        return 1
    fi

    success "Upgraded to v${new_ver}."
    log "upgrade: v${SERVUS_VERSION} → v${new_ver}"

    # Reload and show new version
    echo ""
    servus status
}
