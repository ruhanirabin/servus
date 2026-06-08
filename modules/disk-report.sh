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
        device=$(df -P / | awk 'NR==2 {print $1}')
    fi

    # Disk usage
    local total_kb used_kb avail_kb use_pct
    read -r _ total_kb used_kb avail_kb use_pct _ < <(df -P "$df_target" 2>/dev/null | awk 'NR==2') || true
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
    local cpu_count total_ram_kb mem_used_kb total_ram_gb mem_used_gb ram_use_pct cpu_use_pct
    cpu_count=$(nproc)
    read -r _ total_ram_kb mem_used_kb _ < <(free -k 2>/dev/null | awk '/Mem:/') || true
    total_ram_gb=$(awk "BEGIN {printf \"%.2f\", ${total_ram_kb:-0}/1024/1024}")
    mem_used_gb=$(awk "BEGIN {printf \"%.2f\", ${mem_used_kb:-0}/1024/1024}")
    ram_use_pct=$(awk "BEGIN {printf \"%.0f\", (${mem_used_kb:-0}/${total_ram_kb:-1})*100}")

    # Sample CPU usage over 1 second
    local cpu1 cpu2
    read -r _ cpu1 < <(grep '^cpu ' /proc/stat) || true
    sleep 1
    read -r _ cpu2 < <(grep '^cpu ' /proc/stat) || true
    local arr1=($cpu1) arr2=($cpu2)
    local total1=$(( ${arr1[0]:-0} + ${arr1[1]:-0} + ${arr1[2]:-0} + ${arr1[3]:-0} ))
    local total2=$(( ${arr2[0]:-0} + ${arr2[1]:-0} + ${arr2[2]:-0} + ${arr2[3]:-0} ))
    local dtotal=$(( total2 - total1 ))
    local didle=$(( ${arr2[3]:-0} - ${arr1[3]:-0} ))
    if [[ $dtotal -eq 0 ]]; then
        cpu_use_pct=0
    else
        cpu_use_pct=$(awk "BEGIN {printf \"%.0f\", (($dtotal - $didle) / $dtotal) * 100}")
    fi

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
  "cpu_use_pct": ${cpu_use_pct:-0},
  "total_ram_gb": ${total_ram_gb:-0},
  "mem_used_gb": ${mem_used_gb:-0},
  "ram_use_pct": ${ram_use_pct:-0}
}
EOF
)

    info "Sending disk report for $HOST_NAME ($HOST_IP)..."
    send_webhook "$WEBHOOK_URL" "$payload"
    log "disk-report sent: disk_used=${disk_used_gb}GB (${use_pct}%)"
}
