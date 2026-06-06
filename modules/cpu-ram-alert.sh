#!/bin/bash
# servus module - cpu-ram-alert
# Uses state files to detect sustained high CPU or RAM usage before alerting.
# Designed to run frequently via cron (e.g. every 5 minutes).

STATE_CPU_HIGH="$SERVUS_STATE_DIR/cpu_high_since"
STATE_RAM_HIGH="$SERVUS_STATE_DIR/ram_high_since"

_get_cpu_pct() {
    # Sample CPU usage over 1 second via /proc/stat
    local cpu1 cpu2 idle1 idle2 total1 total2
    read -r _ cpu1 < <(grep '^cpu ' /proc/stat)
    sleep 1
    read -r _ cpu2 < <(grep '^cpu ' /proc/stat)

    local arr1=($cpu1) arr2=($cpu2)
    local user1=${arr1[0]} nice1=${arr1[1]} sys1=${arr1[2]} idle1=${arr1[3]}
    local user2=${arr2[0]} nice2=${arr2[1]} sys2=${arr2[2]} idle2=${arr2[3]}

    total1=$(( user1 + nice1 + sys1 + idle1 ))
    total2=$(( user2 + nice2 + sys2 + idle2 ))
    local dtotal=$(( total2 - total1 ))
    local didle=$(( idle2 - idle1 ))

    [[ $dtotal -eq 0 ]] && echo 0 && return
    awk "BEGIN {printf \"%.0f\", (($dtotal - $didle) / $dtotal) * 100}"
}

_get_ram_pct() {
    awk '/Mem:/ {printf "%.0f", ($3/$2)*100}' <(free -k)
}

# Check one metric; manage state file; return 1 if alert should fire
_check_metric() {
    local name="$1"
    local current="$2"
    local threshold="$3"
    local sustain_min="$4"
    local state_file="$5"

    mkdir -p "$SERVUS_STATE_DIR"

    if (( current >= threshold )); then
        if [[ ! -f "$state_file" ]]; then
            date +%s > "$state_file"
            log "cpu-ram-alert: ${name} crossed threshold (${current}% >= ${threshold}%), watching..."
            return 1  # not alerting yet, just started tracking
        fi

        local high_since
        high_since=$(cat "$state_file")
        local now elapsed_min
        now=$(date +%s)
        elapsed_min=$(( (now - high_since) / 60 ))

        if (( elapsed_min >= sustain_min )); then
            log "cpu-ram-alert: ${name} sustained high for ${elapsed_min}min (${current}% >= ${threshold}%) — alerting"
            # Reset state so next alert only fires after another sustained period
            rm -f "$state_file"
            return 0  # alert
        else
            log "cpu-ram-alert: ${name} still high (${current}% >= ${threshold}%), ${elapsed_min}/${sustain_min} min elapsed"
            return 1
        fi
    else
        # Below threshold — clear any high state
        if [[ -f "$state_file" ]]; then
            log "cpu-ram-alert: ${name} back to normal (${current}% < ${threshold}%)"
            rm -f "$state_file"
        fi
        return 1
    fi
}

run_cpu_ram_alert() {
    load_config
    system_identity

    local cpu_threshold="${CPU_ALERT_THRESHOLD:-85}"
    local ram_threshold="${RAM_ALERT_THRESHOLD:-85}"
    local sustain="${CPU_SUSTAIN_MINUTES:-5}"

    local cpu_pct ram_pct
    cpu_pct=$(_get_cpu_pct)
    ram_pct=$(_get_ram_pct)

    local alerts=()

    if _check_metric "CPU" "$cpu_pct" "$cpu_threshold" "$sustain" "$STATE_CPU_HIGH"; then
        alerts+=("cpu")
    fi

    if _check_metric "RAM" "$ram_pct" "$ram_threshold" "$sustain" "$STATE_RAM_HIGH"; then
        alerts+=("ram")
    fi

    [[ ${#alerts[@]} -eq 0 ]] && return 0

    # Build alert message
    local alert_msg="HIGH RESOURCE ALERT on ${HOST_NAME}"
    local details=""
    for a in "${alerts[@]}"; do
        case "$a" in
            cpu) details="${details} CPU: ${cpu_pct}% (threshold: ${cpu_threshold}%);" ;;
            ram) details="${details} RAM: ${ram_pct}% (threshold: ${ram_threshold}%);" ;;
        esac
    done

    local payload
    payload=$(cat <<EOF
{
  "alert_type": "resource_high",
  "host_name": "$HOST_NAME",
  "host_ip": "$HOST_IP",
  "timestamp": "$TIMESTAMP",
  "message": "$alert_msg",
  "cpu_pct": $cpu_pct,
  "ram_pct": $ram_pct,
  "cpu_threshold": $cpu_threshold,
  "ram_threshold": $ram_threshold,
  "sustained_minutes": $sustain,
  "details": "${details}"
}
EOF
)

    warn "$alert_msg —$details"
    send_webhook "$WEBHOOK_URL" "$payload"
}
