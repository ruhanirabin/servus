#!/bin/bash
# servus - shared utilities

SERVUS_LIB_DIR="/usr/local/lib/servus"
SERVUS_VERSION=$(< "$SERVUS_LIB_DIR/VERSION")
SERVUS_CONF_FILE="/usr/local/etc/servus/config"
SERVUS_LOG_FILE="/var/log/servus/servus.log"
SERVUS_STATE_DIR="/var/lib/servus"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

info()    { echo -e "${CYAN}[servus]${NC} $*"; }
success() { echo -e "${GREEN}[servus]${NC} $*"; }
warn()    { echo -e "${YELLOW}[servus]${NC} $*"; }
die()     { echo -e "${RED}[servus] ERROR:${NC} $*" >&2; exit 1; }
log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$SERVUS_LOG_FILE" 2>/dev/null || true; }

print_banner() {
    echo -e "${CYAN}"
    echo '╭─╮╭─╴╭─╮╷ ╷╷ ╷╭─╮'
    echo '╰─╮├╴ ├┬╯│╭╯│ │╰─╮'
    echo '╰─╯╰─╴╵╰╴╰╯ ╰─╯╰─╯'
    echo -e "${NC}"
    echo    "Version ${SERVUS_VERSION} - Ruhani Rabin - MIT License"
    echo    "Always read the readme file (even if you don't want to)"
    echo -e "${CYAN}https://github.com/ruhanirabin/servus${NC}   ${BOLD}https://www.ruhanirabin.com/tools/${NC}"
    echo    "-------------------------------------------------------"
    echo ""
}

load_config() {
    [[ -f "$SERVUS_CONF_FILE" ]] && source "$SERVUS_CONF_FILE" || die "Config not found: $SERVUS_CONF_FILE. Run 'servus setup'."
}

# Send JSON payload to webhook URL
# Usage: send_webhook <url> <json_payload>
send_webhook() {
    local url="$1"
    local payload="$2"

    [[ -z "$url" ]] && { warn "Webhook URL not configured. Skipping."; return 0; }

    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$url" 2>/dev/null)

    if [[ "$http_status" =~ ^2 ]]; then
        log "Webhook sent OK (HTTP $http_status) to $url"
        return 0
    else
        log "Webhook failed (HTTP $http_status) to $url"
        warn "Webhook returned HTTP $http_status"
        return 1
    fi
}

# Collect common system identity fields
system_identity() {
    HOST_NAME=$(hostname)
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
}
