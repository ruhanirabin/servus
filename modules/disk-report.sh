#!/bin/bash
# servus module - disk-report

run_disk_report() {
    load_config
    system_identity

    # Resolve device name for display, but always query stats via the mount point
    # to avoid loop-device issues on LXC/snap systems where df / may return
    # /dev/loopN instead of the actual root block device.
    local device df_target
    if [[ -n "${DISK_DEVICE:-}" && "${DISK_DEVICE}" != "auto" ]]; then
        device="$DISK_DEVICE"
        df_target="$DISK_DEVICE"
    else
        df_target="/"
        device=$(df / | awk 'NR==2 {print $1}')
    fi

    # Disk usage
    local total_kb used_kb avail_kb use_pct
    read -r _ total_kb used_kb avail_kb use_pct _ < <(df "$df_target" 2>/dev/null | awk 'NR==2') || true
    [[ -z "$used_kb" ]] && { warn "Cannot read disk stats for $df_target"; return 1; }

    local disk_used_gb disk_total_gb disk_avail_gb
    disk_used_gb=$(awk "BEGIN {printf \"%.2f\", $used_kb/1024/1024}")
    disk_total_gb=$(awk "BEGIN {printf \"%.2f\", $total_kb/1024/1024}")
    disk_avail_gb=$(awk "BEGIN {printf \"%.2f\", $avail_kb/1024/1024}")
    use_pct="${use_pct//%/}"

    # MySQL space (optional — skip if not present)
    local mysql_mb=0
    if [[ -d /var/lib/mysql ]]; then
        mysql_mb=$(du -s /var/lib/mysql 2>/dev/null | awk '{printf "%.0f", $1/1024}')
    fi

    # Log space
    local logs_mb=0
    if [[ -d /var/log ]]; then
        logs_mb=$(du -s /var/log 2>/dev/null | awk '{printf "%.0f", $1/1024}')
    fi

    # CPU/RAM snapshot included for context
    # Use free -k (universally supported) and convert to GB
    local cpu_count total_ram_kb mem_used_kb total_ram_gb mem_used_gb
    cpu_count=$(nproc)
    read -r _ total_ram_kb mem_used_kb _ < <(free -k 2>/dev/null | awk '/Mem:/') || true
    total_ram_gb=$(awk "BEGIN {printf \"%.2f\", ${total_ram_kb:-0}/1024/1024}")
    mem_used_gb=$(awk "BEGIN {printf \"%.2f\", ${mem_used_kb:-0}/1024/1024}")

    local payload
    payload=$(cat <<EOF
{
  "host_name": "$HOST_NAME",
  "host_ip": "$HOST_IP",
  "timestamp": "$TIMESTAMP",
  "disk_device": "$device",
  "disk_used_gb": $disk_used_gb,
  "disk_total_gb": $disk_total_gb,
  "disk_avail_gb": $disk_avail_gb,
  "disk_use_pct": $use_pct,
  "mysql_space_mb": $mysql_mb,
  "logs_space_mb": $logs_mb,
  "cpu_count": $cpu_count,
  "total_ram_gb": ${total_ram_gb:-0},
  "mem_used_gb": ${mem_used_gb:-0}
}
EOF
)

    info "Sending disk report for $HOST_NAME ($HOST_IP)..."
    send_webhook "$WEBHOOK_URL" "$payload"
    log "disk-report sent: disk_used=${disk_used_gb}GB (${use_pct}%)"
}
