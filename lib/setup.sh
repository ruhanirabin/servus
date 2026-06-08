#!/bin/bash
# servus - interactive setup wizard

run_setup() {
    echo ""
    echo -e "${BOLD}=== servus Setup Wizard ===${NC}"
    echo ""

    local conf_dir
    conf_dir="$(dirname "$SERVUS_CONF_FILE")"
    mkdir -p "$conf_dir" "$SERVUS_STATE_DIR" "$(dirname "$SERVUS_LOG_FILE")"

    # Load existing config values as defaults if present
    [[ -f "$SERVUS_CONF_FILE" ]] && source "$SERVUS_CONF_FILE"
    local existing_webhook="${WEBHOOK_URL:-}"
    local existing_disk_device="${DISK_DEVICE:-auto}"
    local existing_cpu_thresh="${CPU_ALERT_THRESHOLD:-85}"
    local existing_ram_thresh="${RAM_ALERT_THRESHOLD:-85}"
    local existing_sustain="${CPU_SUSTAIN_MINUTES:-5}"
    local existing_vac_dirs="${LOG_VACUUM_DIRS:-/var/log}"
    local existing_vac_days="${LOG_VACUUM_DAYS:-2}"
    local existing_watchdog_svcs="${WATCHDOG_SERVICES:-}"
    local existing_watchdog_restart="${WATCHDOG_AUTO_RESTART:-false}"
    local existing_swap_thresh="${SWAP_ALERT_THRESHOLD:-60}"
    local existing_swap_sustain="${SWAP_SUSTAIN_MINUTES:-10}"
    local existing_tmp_days="${TMP_CLEANUP_DAYS:-7}"
    local existing_tmp_dirs="${TMP_CLEANUP_DIRS:-/tmp /var/tmp}"

    # --- Webhook ---
    info "Webhook URL receives all alerts and reports."
    read -rp "  Webhook URL [${existing_webhook:-none}]: " input </dev/tty
    WEBHOOK_URL="${input:-$existing_webhook}"

    # --- Disk report ---
    echo ""
    info "Disk device for usage reporting (auto = detect from / mount)."
    local detected_device
    detected_device=$(df -P / | awk 'NR==2 {print $1}')
    read -rp "  Disk device [${existing_disk_device}, detected: ${detected_device}]: " input </dev/tty
    DISK_DEVICE="${input:-$existing_disk_device}"

    # --- CPU/RAM alerts ---
    echo ""
    info "CPU/RAM alert thresholds (%)."
    read -rp "  CPU alert threshold  [${existing_cpu_thresh}]: " input </dev/tty
    CPU_ALERT_THRESHOLD="${input:-$existing_cpu_thresh}"
    read -rp "  RAM alert threshold  [${existing_ram_thresh}]: " input </dev/tty
    RAM_ALERT_THRESHOLD="${input:-$existing_ram_thresh}"
    read -rp "  Sustained minutes before alert [${existing_sustain}]: " input </dev/tty
    CPU_SUSTAIN_MINUTES="${input:-$existing_sustain}"

    # --- Log vacuum ---
    echo ""
    info "Log vacuum settings."
    read -rp "  Directories to vacuum (space-separated) [${existing_vac_dirs}]: " input </dev/tty
    LOG_VACUUM_DIRS="${input:-$existing_vac_dirs}"
    read -rp "  Truncate logs older than N days [${existing_vac_days}]: " input </dev/tty
    LOG_VACUUM_DAYS="${input:-$existing_vac_days}"

    # --- Service watchdog ---
    echo ""
    source "$SERVUS_LIB_DIR/lib/detect.sh"
    print_detected_services

    local auto_detected
    auto_detected=$(detect_services)
    local watchdog_default="${existing_watchdog_svcs:-$auto_detected}"

    info "Service watchdog: confirm or edit the list of services to monitor."
    info "(Space-separated. Press Enter to accept auto-detected list.)"
    read -rp "  Services [${watchdog_default:-none}]: " input </dev/tty
    WATCHDOG_SERVICES="${input:-$watchdog_default}"
    read -rp "  Auto-restart failed services? [${existing_watchdog_restart}]: " input </dev/tty
    WATCHDOG_AUTO_RESTART="${input:-$existing_watchdog_restart}"

    # --- Swap alert ---
    echo ""
    info "Swap alert threshold (%) and sustained minutes."
    read -rp "  Swap alert threshold [${existing_swap_thresh}]: " input </dev/tty
    SWAP_ALERT_THRESHOLD="${input:-$existing_swap_thresh}"
    read -rp "  Sustained minutes before alert [${existing_swap_sustain}]: " input </dev/tty
    SWAP_SUSTAIN_MINUTES="${input:-$existing_swap_sustain}"

    # --- Tmp cleanup ---
    echo ""
    info "Tmp cleanup: directories and age threshold."
    read -rp "  Directories (space-separated) [${existing_tmp_dirs}]: " input </dev/tty
    TMP_CLEANUP_DIRS="${input:-$existing_tmp_dirs}"
    read -rp "  Delete files not accessed in N days [${existing_tmp_days}]: " input </dev/tty
    TMP_CLEANUP_DAYS="${input:-$existing_tmp_days}"

    # Write config
    cat > "$SERVUS_CONF_FILE" <<EOF
# servus configuration — managed by 'servus setup'
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

WEBHOOK_URL="${WEBHOOK_URL}"

# disk-report
DISK_DEVICE="${DISK_DEVICE}"

# cpu-ram-alert
CPU_ALERT_THRESHOLD=${CPU_ALERT_THRESHOLD}
RAM_ALERT_THRESHOLD=${RAM_ALERT_THRESHOLD}
CPU_SUSTAIN_MINUTES=${CPU_SUSTAIN_MINUTES}

# log-vacuum
LOG_VACUUM_DIRS="${LOG_VACUUM_DIRS}"
LOG_VACUUM_DAYS=${LOG_VACUUM_DAYS}

# service-watchdog
WATCHDOG_SERVICES="${WATCHDOG_SERVICES}"
WATCHDOG_AUTO_RESTART=${WATCHDOG_AUTO_RESTART}

# swap-alert
SWAP_ALERT_THRESHOLD=${SWAP_ALERT_THRESHOLD}
SWAP_SUSTAIN_MINUTES=${SWAP_SUSTAIN_MINUTES}

# tmp-cleanup
TMP_CLEANUP_DIRS="${TMP_CLEANUP_DIRS}"
TMP_CLEANUP_DAYS=${TMP_CLEANUP_DAYS}
EOF

    chmod 640 "$SERVUS_CONF_FILE"
    success "Configuration saved to $SERVUS_CONF_FILE"

    # Offer to set up cron jobs now
    echo ""
    read -rp "Set up cron jobs now? [Y/n]: " yn </dev/tty
    if [[ "${yn,,}" != "n" ]]; then
        source "$SERVUS_LIB_DIR/lib/cron.sh"
        run_cron_manager
    fi

    echo ""
    success "Setup complete. Run 'servus help' for usage."
}
