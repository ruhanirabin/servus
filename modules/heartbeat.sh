#!/bin/bash
# servus module - heartbeat
# Pings one or more uptime monitoring endpoints (UptimeKuma push, BetterStack,
# or any generic HTTP heartbeat URL) on each cron run.
# Endpoints are stored in /usr/local/etc/servus/heartbeats.conf — one per line:
#   name  url
# Lines starting with # are comments. Blank lines are ignored.

HEARTBEAT_CONF="${SERVUS_CONF_FILE%/*}/heartbeats.conf"

run_heartbeat() {
    load_config

    if [[ ! -f "$HEARTBEAT_CONF" ]]; then
        warn "No heartbeat config found at $HEARTBEAT_CONF"
        warn "Run 'servus heartbeat add' to configure an endpoint."
        return 1
    fi

    local ok=0 failed=0

    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        local name url
        name=$(echo "$line" | awk '{print $1}')
        url=$(echo "$line"  | awk '{print $2}')

        [[ -z "$name" || -z "$url" ]] && continue

        local http_status
        http_status=$(curl -fsSL --connect-timeout 10 --max-time 15 \
            -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

        if [[ "$http_status" =~ ^2 ]]; then
            log "heartbeat: OK [$name] HTTP $http_status"
            (( ok++ )) || true
        else
            log "heartbeat: FAIL [$name] HTTP $http_status → $url"
            warn "Heartbeat failed: $name (HTTP $http_status)"
            (( failed++ )) || true

            # Alert via webhook on failure if WEBHOOK_URL is configured
            if [[ -n "${WEBHOOK_URL:-}" ]]; then
                local payload
                payload=$(cat <<EOF
{
  "alert_type": "heartbeat_fail",
  "host_name": "$(hostname)",
  "host_ip": "$(hostname -I 2>/dev/null | awk '{print $1}')",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "monitor_name": "$name",
  "monitor_url": "$url",
  "http_status": "$http_status"
}
EOF
)
                send_webhook "$WEBHOOK_URL" "$payload"
            fi
        fi
    done < "$HEARTBEAT_CONF"

    local total=$(( ok + failed ))
    [[ $total -eq 0 ]] && { warn "No valid heartbeat entries found in $HEARTBEAT_CONF"; return 1; }

    if [[ $failed -eq 0 ]]; then
        log "heartbeat: all ${ok}/${total} OK"
    else
        warn "heartbeat: ${failed}/${total} failed"
    fi
}

# --- Management subcommands ---

heartbeat_list() {
    if [[ ! -f "$HEARTBEAT_CONF" ]] || [[ ! -s "$HEARTBEAT_CONF" ]]; then
        info "No heartbeat endpoints configured."
        return 0
    fi
    echo ""
    echo -e "${BOLD}Configured heartbeat endpoints:${NC}"
    local i=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        local name url
        name=$(echo "$line" | awk '{print $1}')
        url=$(echo "$line"  | awk '{print $2}')
        (( i++ )) || true
        printf "  %2d) %-20s %s\n" "$i" "$name" "$url"
    done < "$HEARTBEAT_CONF"
    echo ""
}

heartbeat_add() {
    mkdir -p "$(dirname "$HEARTBEAT_CONF")"
    [[ ! -f "$HEARTBEAT_CONF" ]] && cat > "$HEARTBEAT_CONF" <<'HDR'
# servus heartbeat endpoints
# Format:  name  url
# name     : short label used in logs and alerts (no spaces)
# url      : the full push/heartbeat URL
#
# UptimeKuma push example:
#   my-server   https://uptime.example.com/api/push/TOKEN?status=up&msg=OK&ping=
#
# BetterStack example:
#   my-server   https://uptime.betterstack.com/api/v1/heartbeat/TOKEN
#
# Generic HTTP ping (any URL that returns 2xx = alive):
#   my-api      https://myapp.example.com/health

HDR

    echo ""
    info "Add a heartbeat endpoint."
    info "The name must have no spaces (use hyphens). Examples: main-site, db-server"
    echo ""

    read -rp "  Name   : " hb_name
    [[ -z "$hb_name" ]] && { warn "Name cannot be empty."; return 1; }
    hb_name="${hb_name// /-}"

    read -rp "  URL    : " hb_url
    [[ -z "$hb_url" ]] && { warn "URL cannot be empty."; return 1; }

    # Check for duplicate name
    if grep -q "^${hb_name}[[:space:]]" "$HEARTBEAT_CONF" 2>/dev/null; then
        warn "An endpoint named '${hb_name}' already exists. Edit $HEARTBEAT_CONF manually to update it."
        return 1
    fi

    echo "${hb_name}  ${hb_url}" >> "$HEARTBEAT_CONF"
    success "Added: $hb_name → $hb_url"

    # Offer a test ping
    read -rp "  Test it now? [Y/n]: " yn
    if [[ "${yn,,}" != "n" ]]; then
        local http_status
        http_status=$(curl -fsSL --connect-timeout 10 --max-time 15 \
            -o /dev/null -w "%{http_code}" "$hb_url" 2>/dev/null)
        if [[ "$http_status" =~ ^2 ]]; then
            success "Ping OK (HTTP $http_status)"
        else
            warn "Ping returned HTTP $http_status — check the URL"
        fi
    fi
}

heartbeat_remove() {
    heartbeat_list
    local entries
    entries=$(grep -v '^[[:space:]]*#' "$HEARTBEAT_CONF" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
    [[ -z "$entries" ]] && return 0

    read -rp "Enter the name to remove: " hb_name
    [[ -z "$hb_name" ]] && return 1

    if ! grep -q "^${hb_name}[[:space:]]" "$HEARTBEAT_CONF" 2>/dev/null; then
        warn "No endpoint named '${hb_name}' found."
        return 1
    fi

    local tmpfile="${HEARTBEAT_CONF}.tmp"
    grep -v "^${hb_name}[[:space:]]" "$HEARTBEAT_CONF" > "$tmpfile" && mv "$tmpfile" "$HEARTBEAT_CONF"
    success "Removed: $hb_name"
}

run_heartbeat_manager() {
    echo ""
    echo -e "${BOLD}=== Heartbeat Manager ===${NC}"
    echo ""
    echo "  1) List endpoints"
    echo "  2) Add endpoint"
    echo "  3) Remove endpoint"
    echo "  4) Test all endpoints now"
    echo "  0) Exit"
    echo ""
    read -rp "Choice: " choice
    case "$choice" in
        1) heartbeat_list ;;
        2) heartbeat_add ;;
        3) heartbeat_remove ;;
        4) run_heartbeat ;;
        0) return 0 ;;
        *) warn "Invalid choice." ;;
    esac
}
