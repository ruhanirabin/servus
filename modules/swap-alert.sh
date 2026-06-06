#!/bin/bash
# servus module - swap-alert
# Alerts when swap usage exceeds a threshold for a sustained period.
# High swap usage is a leading indicator of memory pressure before OOM kills.

STATE_SWAP_HIGH="${SERVUS_STATE_DIR}/swap_high_since"

_get_swap_pct() {
    local total used
    read -r _ total used _ < <(free -k | awk '/Swap:/')
    [[ -z "$total" || "$total" -eq 0 ]] && { echo 0; return; }
    awk "BEGIN {printf \"%.0f\", ($used/$total)*100}"
}

_get_swap_mb() {
    free -m | awk '/Swap:/ {printf "used=%s total=%s", $3, $2}'
}

run_swap_alert() {
    load_config
    system_identity

    local threshold="${SWAP_ALERT_THRESHOLD:-60}"
    local sustain="${SWAP_SUSTAIN_MINUTES:-10}"

    # Check if swap is even configured on this system
    local swap_total
    swap_total=$(free -k | awk '/Swap:/ {print $2}')
    if [[ -z "$swap_total" || "$swap_total" -eq 0 ]]; then
        info "No swap configured on this system — skipping."
        log "swap-alert: no swap found, skipped"
        return 0
    fi

    mkdir -p "$SERVUS_STATE_DIR"

    local swap_pct
    swap_pct=$(_get_swap_pct)
    local swap_detail
    swap_detail=$(_get_swap_mb)

    if (( swap_pct >= threshold )); then
        if [[ ! -f "$STATE_SWAP_HIGH" ]]; then
            date +%s > "$STATE_SWAP_HIGH"
            log "swap-alert: swap crossed threshold (${swap_pct}% >= ${threshold}%), watching..."
            return 0
        fi

        local high_since elapsed_min
        high_since=$(cat "$STATE_SWAP_HIGH")
        elapsed_min=$(( ($(date +%s) - high_since) / 60 ))

        if (( elapsed_min >= sustain )); then
            warn "SWAP ALERT on ${HOST_NAME}: ${swap_pct}% used for ${elapsed_min}min (threshold: ${threshold}%)"
            rm -f "$STATE_SWAP_HIGH"
            log "swap-alert: alerting — ${swap_pct}% for ${elapsed_min}min"

            local payload
            payload=$(cat <<EOF
{
  "alert_type": "swap_high",
  "host_name": "$HOST_NAME",
  "host_ip": "$HOST_IP",
  "timestamp": "$TIMESTAMP",
  "swap_pct": $swap_pct,
  "swap_threshold": $threshold,
  "sustained_minutes": $elapsed_min,
  "detail": "$swap_detail"
}
EOF
)
            send_webhook "$WEBHOOK_URL" "$payload"
        else
            log "swap-alert: swap still high (${swap_pct}%), ${elapsed_min}/${sustain} min elapsed"
        fi
    else
        if [[ -f "$STATE_SWAP_HIGH" ]]; then
            log "swap-alert: swap back to normal (${swap_pct}% < ${threshold}%)"
            rm -f "$STATE_SWAP_HIGH"
        fi
    fi
}
