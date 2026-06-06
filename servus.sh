#!/bin/bash
# servus - server utility kit
# https://github.com/ruhanirabin/servus
set -euo pipefail

SERVUS_LIB_DIR="/usr/local/lib/servus"
SERVUS_CONF_FILE="/usr/local/etc/servus/config"
SERVUS_LOG_FILE="/var/log/servus/servus.log"
SERVUS_STATE_DIR="/var/lib/servus"

source "$SERVUS_LIB_DIR/lib/common.sh"

usage() {
    print_banner
    cat <<EOF
${BOLD}Usage:${NC}
  servus <command> [options]

${BOLD}Commands:${NC}
  setup              Run interactive setup wizard (webhook URL, thresholds, cron jobs)
  disk-report        Send disk usage report to webhook
  log-vacuum         Truncate old log files and vacuum systemd journal
  system-info        Print a system snapshot (CPU, RAM, disk, uptime)
  cpu-ram-alert      Check CPU/RAM; alert if sustained above threshold
  detect             Auto-detect installed services on this system
  service-watchdog   Check configured services; alert + optionally restart if down
  swap-alert         Check swap usage; alert if sustained above threshold
  tmp-cleanup        Delete old files from /tmp and /var/tmp
  heartbeat          Ping uptime monitoring endpoints (UptimeKuma, BetterStack, etc.)
  heartbeat add      Add a heartbeat endpoint
  heartbeat remove   Remove a heartbeat endpoint
  heartbeat list     List configured endpoints
  cron               Manage automated cron job schedules
  update             Check for a newer version and upgrade if available
  status             Show current config and installed cron jobs
  uninstall          Remove servus from this system

${BOLD}One-liner install:${NC}
  curl -fsSL https://raw.githubusercontent.com/ruhanirabin/servus/main/install.sh | sudo bash

EOF
}

run_status() {
    echo ""
    echo -e "${BOLD}=== servus Status ===${NC}"
    echo ""
    if [[ -f "$SERVUS_CONF_FILE" ]]; then
        echo -e "${BOLD}Config:${NC} $SERVUS_CONF_FILE"
        while IFS='=' read -r key val; do
            [[ "$key" =~ ^#|^$ ]] && continue
            printf "  %-26s %s\n" "$key" "$val"
        done < "$SERVUS_CONF_FILE"
    else
        warn "No config found. Run 'servus setup'."
    fi
    echo ""
    source "$SERVUS_LIB_DIR/lib/cron.sh"
    list_servus_crons
    echo ""
    # Passive version hint — non-blocking, fails silently if offline
    source "$SERVUS_LIB_DIR/lib/update.sh"
    check_version_hint "$SERVUS_VERSION"
    echo ""
}

run_uninstall() {
    echo ""
    read -rp "Remove all servus files, config, and cron jobs? [y/N]: " yn
    [[ "${yn,,}" != "y" ]] && { info "Uninstall cancelled."; exit 0; }

    source "$SERVUS_LIB_DIR/lib/cron.sh"
    remove_all_servus_crons

    rm -rf /usr/local/lib/servus
    rm -rf /usr/local/etc/servus
    rm -rf /var/lib/servus
    rm -f /usr/local/bin/servus
    rm -rf /var/log/servus

    success "servus removed."
}

[[ $EUID -ne 0 ]] && die "servus must be run as root."

case "${1:-help}" in
    setup)
        source "$SERVUS_LIB_DIR/lib/setup.sh"
        source "$SERVUS_LIB_DIR/lib/cron.sh"
        run_setup
        ;;
    disk-report)
        load_config
        source "$SERVUS_LIB_DIR/modules/disk-report.sh"
        run_disk_report
        ;;
    log-vacuum)
        load_config
        source "$SERVUS_LIB_DIR/modules/log-vacuum.sh"
        run_log_vacuum
        ;;
    system-info)
        load_config
        source "$SERVUS_LIB_DIR/modules/system-info.sh"
        run_system_info
        ;;
    cpu-ram-alert)
        load_config
        source "$SERVUS_LIB_DIR/modules/cpu-ram-alert.sh"
        run_cpu_ram_alert
        ;;
    detect)
        source "$SERVUS_LIB_DIR/lib/detect.sh"
        print_detected_services
        echo ""
        info "Full list: $(detect_services)"
        ;;
    service-watchdog)
        load_config
        source "$SERVUS_LIB_DIR/modules/service-watchdog.sh"
        run_service_watchdog
        ;;
    swap-alert)
        load_config
        source "$SERVUS_LIB_DIR/modules/swap-alert.sh"
        run_swap_alert
        ;;
    tmp-cleanup)
        load_config
        source "$SERVUS_LIB_DIR/modules/tmp-cleanup.sh"
        run_tmp_cleanup
        ;;
    heartbeat)
        load_config
        source "$SERVUS_LIB_DIR/modules/heartbeat.sh"
        case "${2:-run}" in
            add)    heartbeat_add ;;
            remove) heartbeat_remove ;;
            list)   heartbeat_list ;;
            run|*)  run_heartbeat ;;
        esac
        ;;
    cron)
        source "$SERVUS_LIB_DIR/lib/cron.sh"
        run_cron_manager
        ;;
    update)
        source "$SERVUS_LIB_DIR/lib/update.sh"
        run_update
        ;;
    status)
        run_status
        ;;
    uninstall)
        run_uninstall
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        die "Unknown command: '${1}'. Run 'servus help'."
        ;;
esac
