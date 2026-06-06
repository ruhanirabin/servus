#!/bin/bash
# servus - cron job manager

CRON_TAG="# servus-managed"

# Returns a cron schedule string chosen interactively
pick_schedule() {
    local label="$1"
    echo ""
    echo -e "${CYAN}Schedule for:${NC} ${BOLD}${label}${NC}"
    echo "  1) Every 5 minutes    (*/5 * * * *)"
    echo "  2) Every 15 minutes   (*/15 * * * *)"
    echo "  3) Every 30 minutes   (*/30 * * * *)"
    echo "  4) Hourly             (0 * * * *)"
    echo "  5) Every 6 hours      (0 */6 * * *)"
    echo "  6) Every 12 hours     (0 */12 * * *)"
    echo "  7) Daily at midnight  (0 0 * * *)"
    echo "  8) Weekly (Sun 00:00) (0 0 * * 0)"
    echo "  9) Custom cron expression"
    echo "  0) Skip / disable"
    read -rp "  Choice [4]: " choice </dev/tty
    case "${choice:-4}" in
        1) echo "*/5 * * * *" ;;
        2) echo "*/15 * * * *" ;;
        3) echo "*/30 * * * *" ;;
        4) echo "0 * * * *" ;;
        5) echo "0 */6 * * *" ;;
        6) echo "0 */12 * * *" ;;
        7) echo "0 0 * * *" ;;
        8) echo "0 0 * * 0" ;;
        9) read -rp "  Enter cron expression: " custom </dev/tty; echo "$custom" ;;
        0) echo "" ;;
        *) echo "0 * * * *" ;;
    esac
}

# Add or replace a servus cron entry
# Usage: upsert_cron <unique-id> <schedule> <command>
upsert_cron() {
    local id="$1"
    local schedule="$2"
    local cmd="$3"
    local tag="${CRON_TAG}:${id}"

    # Remove existing entry for this id
    local existing
    existing=$(crontab -l 2>/dev/null || true)
    local filtered
    filtered=$(echo "$existing" | grep -v "$tag" || true)

    if [[ -z "$schedule" ]]; then
        echo "$filtered" | crontab -
        info "Cron job '${id}' removed/disabled."
        return
    fi

    local new_entry="${schedule} ${cmd} >> ${SERVUS_LOG_FILE} 2>&1 ${tag}"
    { echo "$filtered"; echo "$new_entry"; } | grep -v '^$' | crontab -
    success "Cron job '${id}' set: ${schedule}"
}

remove_all_servus_crons() {
    local existing
    existing=$(crontab -l 2>/dev/null || true)
    echo "$existing" | grep -v "$CRON_TAG" | crontab -
    info "All servus cron jobs removed."
}

list_servus_crons() {
    local entries
    entries=$(crontab -l 2>/dev/null | grep "$CRON_TAG" || true)
    if [[ -z "$entries" ]]; then
        info "No servus cron jobs installed."
    else
        echo -e "${BOLD}Installed servus cron jobs:${NC}"
        echo "$entries" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
}

run_cron_manager() {
    echo ""
    echo -e "${BOLD}=== servus Cron Manager ===${NC}"
    echo ""
    echo "Configure automated schedules for each module."
    echo "Select '0' to skip/disable a module's cron job."
    echo ""

    local schedule

    schedule=$(pick_schedule "disk-report (send disk stats to webhook)")
    upsert_cron "disk-report" "$schedule" "/usr/local/bin/servus disk-report"

    schedule=$(pick_schedule "log-vacuum (clean old log files)")
    upsert_cron "log-vacuum" "$schedule" "/usr/local/bin/servus log-vacuum"

    schedule=$(pick_schedule "cpu-ram-alert (check for sustained high CPU/RAM)")
    upsert_cron "cpu-ram-alert" "$schedule" "/usr/local/bin/servus cpu-ram-alert"

    schedule=$(pick_schedule "service-watchdog (check services are running)")
    upsert_cron "service-watchdog" "$schedule" "/usr/local/bin/servus service-watchdog"

    schedule=$(pick_schedule "swap-alert (check for sustained high swap usage)")
    upsert_cron "swap-alert" "$schedule" "/usr/local/bin/servus swap-alert"

    schedule=$(pick_schedule "tmp-cleanup (delete old files from /tmp)")
    upsert_cron "tmp-cleanup" "$schedule" "/usr/local/bin/servus tmp-cleanup"

    schedule=$(pick_schedule "heartbeat (ping uptime monitoring endpoints)")
    upsert_cron "heartbeat" "$schedule" "/usr/local/bin/servus heartbeat"

    echo ""
    list_servus_crons
}
