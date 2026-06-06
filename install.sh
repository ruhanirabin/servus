#!/bin/bash
# servus installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ruhanirabin/servus/main/install.sh | sudo bash
set -euo pipefail

REPO="ruhanirabin/servus"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
SERVUS_VERSION=$(curl -fsSL "${RAW_BASE}/VERSION" 2>/dev/null) || SERVUS_VERSION="unknown"

INSTALL_BIN="/usr/local/bin"
LIB_DIR="/usr/local/lib/servus"
CONF_DIR="/usr/local/etc/servus"
LOG_DIR="/var/log/servus"
STATE_DIR="/var/lib/servus"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[servus]${NC} $*"; }
success() { echo -e "${GREEN}[servus]${NC} $*"; }
warn()    { echo -e "${YELLOW}[servus]${NC} $*"; }
die()     { echo -e "${RED}[servus] ERROR:${NC} $*" >&2; exit 1; }

_print_banner() {
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

# --- Pre-flight checks ---

[[ "$(uname -s)" != "Linux" ]] && die "servus requires a Linux system."
[[ $EUID -ne 0 ]] && die "Please run as root: sudo bash install.sh  (or: curl ... | sudo bash)"
command -v curl &>/dev/null || die "curl is required. Install it first."
command -v bc &>/dev/null   || warn "bc not found — some numeric formatting may be limited."

# systemd is required for service-watchdog; bail early with a clear message
if ! command -v systemctl &>/dev/null || ! systemctl list-units &>/dev/null 2>&1; then
    die "systemd is not available on this system.
  servus's service-watchdog module requires systemd.
  Detected init: $(cat /proc/1/comm 2>/dev/null || echo 'unknown')
  servus is not supported on OpenVZ/LXC containers without systemd, Alpine with OpenRC,
  or other non-systemd environments."
fi

_print_banner

# --- Choose install location ---

info "Where should servus be installed?"
echo "  1) /usr/local/bin        (recommended — system-wide)"
echo "  2) /opt/servus/bin      (self-contained directory)"
echo "  3) Custom path"
read -rp "  Choice [1]: " _choice
case "${_choice:-1}" in
    1) INSTALL_BIN="/usr/local/bin" ;;
    2) INSTALL_BIN="/opt/servus/bin" ;;
    3) read -rp "  Enter path: " INSTALL_BIN
       [[ -z "$INSTALL_BIN" ]] && die "Path cannot be empty." ;;
    *) INSTALL_BIN="/usr/local/bin" ;;
esac

# --- Handle update vs fresh install ---

if [[ -f "$INSTALL_BIN/servus" ]]; then
    warn "Existing servus installation detected at $INSTALL_BIN/servus"
    read -rp "  Update to latest version? [Y/n]: " _upd
    if [[ "${_upd,,}" == "n" ]]; then
        info "Update cancelled."
        exit 0
    fi
    info "Updating servus..."
else
    info "Installing servus..."
fi

# --- Create directories ---

mkdir -p \
    "$INSTALL_BIN" \
    "$LIB_DIR/lib" \
    "$LIB_DIR/modules" \
    "$CONF_DIR" \
    "$LOG_DIR" \
    "$STATE_DIR"

# --- Download files ---

declare -A FILES=(
    ["VERSION"]="$LIB_DIR/VERSION"
    ["servus.sh"]="$INSTALL_BIN/servus"
    ["lib/common.sh"]="$LIB_DIR/lib/common.sh"
    ["lib/setup.sh"]="$LIB_DIR/lib/setup.sh"
    ["lib/cron.sh"]="$LIB_DIR/lib/cron.sh"
    ["lib/detect.sh"]="$LIB_DIR/lib/detect.sh"
    ["lib/update.sh"]="$LIB_DIR/lib/update.sh"
    ["modules/disk-report.sh"]="$LIB_DIR/modules/disk-report.sh"
    ["modules/log-vacuum.sh"]="$LIB_DIR/modules/log-vacuum.sh"
    ["modules/system-info.sh"]="$LIB_DIR/modules/system-info.sh"
    ["modules/cpu-ram-alert.sh"]="$LIB_DIR/modules/cpu-ram-alert.sh"
    ["modules/service-watchdog.sh"]="$LIB_DIR/modules/service-watchdog.sh"
    ["modules/swap-alert.sh"]="$LIB_DIR/modules/swap-alert.sh"
    ["modules/tmp-cleanup.sh"]="$LIB_DIR/modules/tmp-cleanup.sh"
    ["modules/heartbeat.sh"]="$LIB_DIR/modules/heartbeat.sh"
)

for src in "${!FILES[@]}"; do
    dst="${FILES[$src]}"
    info "  Downloading ${src}..."
    curl -fsSL "${RAW_BASE}/${src}" -o "$dst" || die "Failed to download ${src} from ${RAW_BASE}/${src}"
    chmod +x "$dst"
done

# If using a non-standard bin dir, patch the LIB_DIR reference in the main script
if [[ "$INSTALL_BIN" != "/usr/local/bin" ]]; then
    sed -i "s|SERVUS_LIB_DIR=\"/usr/local/lib/servus\"|SERVUS_LIB_DIR=\"${LIB_DIR}\"|g" "$INSTALL_BIN/servus"
fi

# Ensure servus is on PATH
if [[ ":$PATH:" != *":$INSTALL_BIN:"* ]]; then
    warn "$INSTALL_BIN is not in PATH. Add it:"
    warn "  export PATH=\"\$PATH:$INSTALL_BIN\""
fi

# --- Write default config (skip if already configured) ---

if [[ ! -f "$CONF_DIR/config" ]]; then
    cat > "$CONF_DIR/config" <<CONF
# servus configuration
# Edit manually or run: servus setup

WEBHOOK_URL=""

# disk-report
DISK_DEVICE="auto"

# cpu-ram-alert
CPU_ALERT_THRESHOLD=85
RAM_ALERT_THRESHOLD=85
CPU_SUSTAIN_MINUTES=5

# log-vacuum
LOG_VACUUM_DIRS="/var/log"
LOG_VACUUM_DAYS=2

# service-watchdog
WATCHDOG_SERVICES=""
WATCHDOG_AUTO_RESTART=false

# swap-alert
SWAP_ALERT_THRESHOLD=60
SWAP_SUSTAIN_MINUTES=10

# tmp-cleanup
TMP_CLEANUP_DIRS="/tmp /var/tmp"
TMP_CLEANUP_DAYS=7
CONF
    chmod 640 "$CONF_DIR/config"
    info "Default config written to $CONF_DIR/config"
fi

echo ""
success "servus installed to $INSTALL_BIN/servus"
echo ""

# --- Run setup wizard ---

read -rp "Run setup wizard now? (configure webhook URL, thresholds, cron jobs) [Y/n]: " _setup
if [[ "${_setup,,}" != "n" ]]; then
    "$INSTALL_BIN/servus" setup
else
    echo ""
    info "Skipped. Run 'servus setup' any time to configure."
    info "Run 'servus help' to see all commands."
fi

echo ""
