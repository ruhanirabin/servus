#!/bin/bash
# servus module - system-info

run_system_info() {
    load_config
    system_identity

    # CPU
    local cpu_count cpu_model cpu_load
    cpu_count=$(nproc)
    cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
    cpu_load=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    # RAM
    local total_ram_gb used_ram_gb free_ram_gb ram_use_pct
    read -r _ total_ram_kb used_ram_kb free_ram_kb _ < <(free -k | awk '/Mem:/') || true
    total_ram_gb=$(awk "BEGIN {printf \"%.1f\", ${total_ram_kb:-0}/1024/1024}")
    used_ram_gb=$(awk "BEGIN {printf \"%.1f\", ${used_ram_kb:-0}/1024/1024}")
    free_ram_gb=$(awk "BEGIN {printf \"%.1f\", ${free_ram_kb:-0}/1024/1024}")
    ram_use_pct=$(awk "BEGIN {printf \"%.0f\", (${used_ram_kb:-0}/${total_ram_kb:-1})*100}")

    # Uptime
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null || uptime)

    # OS
    local os_pretty
    os_pretty=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -r)

    # Disk (root)
    local disk_used_gb disk_total_gb disk_pct
    read -r _ disk_total_kb disk_used_kb _ disk_pct _ < <(df / | awk 'NR==2') || true
    disk_used_gb=$(awk "BEGIN {printf \"%.1f\", ${disk_used_kb:-0}/1024/1024}")
    disk_total_gb=$(awk "BEGIN {printf \"%.1f\", ${disk_total_kb:-0}/1024/1024}")

    echo ""
    echo -e "${BOLD}=== System Info: ${HOST_NAME} ===${NC}"
    echo -e "  Timestamp  : $TIMESTAMP"
    echo -e "  IP Address : $HOST_IP"
    echo -e "  OS         : $os_pretty"
    echo -e "  Uptime     : $uptime_str"
    echo ""
    echo -e "  ${BOLD}CPU${NC}"
    echo -e "    Model    : $cpu_model"
    echo -e "    vCPUs    : $cpu_count"
    echo -e "    Load avg : $cpu_load"
    echo ""
    echo -e "  ${BOLD}Memory${NC}"
    echo -e "    Total    : ${total_ram_gb} GB"
    echo -e "    Used     : ${used_ram_gb} GB (${ram_use_pct}%)"
    echo -e "    Free     : ${free_ram_gb} GB"
    echo ""
    echo -e "  ${BOLD}Disk (root /)${NC}"
    echo -e "    Used     : ${disk_used_gb} GB / ${disk_total_gb} GB (${disk_pct})"
    echo ""
}
