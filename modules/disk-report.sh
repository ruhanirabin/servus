#!/bin/bash
# servus module - disk-report

run_disk_report() {
    load_config
    system_identity

    # Resolve the root device at runtime — works for /dev/sda1, /dev/vda1,
    # /dev/nvme0n1p1, LVM paths, etc. DISK_DEVICE in config can override this
    # (useful when you want to report a non-root mount like /data).
    local device
    if [[ -n "${DISK_DEVICE:-}" && "${DISK_DEVICE}" != "auto" ]]; then
        device="$DISK_DEVICE"
    else
        device=$(df / | awk 'NR==2 {print $1}')
    fi

    # Disk usage
    local total_kb used_kb avail_kb use_pct
    read -r _ total_kb used_kb avail_kb use_pct _ < <(df "$device" 2>/dev/null | awk 'NR==2')
    [[ -z "$used_kb" ]] && { warn "Cannot read disk stats for $device"; return 1; }

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
    local cpu_count total_ram_gb mem_used_gb
    cpu_count=$(nproc)
    total_ram_gb=$(free --giga 2>/dev/null | awk '/Mem:/ {print $2}')
    mem_used_gb=$(free --giga 2>/dev/null | awk '/Mem:/ {print $3}')

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
