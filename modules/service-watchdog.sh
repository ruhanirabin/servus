#!/bin/bash
# servus module - service-watchdog
# Alerts when a configured service goes down. Uses state files to fire once on
# transition (up→down and down→up) rather than spamming on every cron run.

_watchdog_state_file() {
    echo "${SERVUS_STATE_DIR}/watchdog_${1//\//_}_down"
}

run_service_watchdog() {
    load_config
    system_identity

    if ! command -v systemctl &>/dev/null; then
        die "service-watchdog requires systemd. systemctl not found on this system."
    fi

    local services="${WATCHDOG_SERVICES:-}"
    local auto_restart="${WATCHDOG_AUTO_RESTART:-false}"

    if [[ -z "$services" ]]; then
        warn "No services configured. Add WATCHDOG_SERVICES to config or run 'servus setup'."
        return 0
    fi

    mkdir -p "$SERVUS_STATE_DIR"

    local newly_down=() still_down=() recovered=() all_ok=()

    for svc in $services; do
        local state_file
        state_file=$(_watchdog_state_file "$svc")
        local was_down=false
        [[ -f "$state_file" ]] && was_down=true

        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            # Service is UP
            if $was_down; then
                recovered+=("$svc")
                rm -f "$state_file"
                log "service-watchdog: $svc recovered"
            else
                all_ok+=("$svc")
            fi
        else
            # Service is DOWN
            if ! $was_down; then
                newly_down+=("$svc")
                date +%s > "$state_file"
                log "service-watchdog: $svc went DOWN"

                if [[ "${auto_restart,,}" == "true" ]]; then
                    info "Auto-restarting $svc..."
                    if systemctl restart "$svc" 2>/dev/null; then
                        sleep 3
                        if systemctl is-active --quiet "$svc" 2>/dev/null; then
                            log "service-watchdog: $svc restarted successfully"
                            recovered+=("$svc")
                            newly_down=("${newly_down[@]/$svc}")
                            rm -f "$state_file"
                        else
                            log "service-watchdog: $svc restart failed, still down"
                        fi
                    fi
                fi
            else
                local down_since elapsed_min
                down_since=$(cat "$state_file")
                elapsed_min=$(( ($(date +%s) - down_since) / 60 ))
                still_down+=("${svc}(${elapsed_min}m)")
                log "service-watchdog: $svc still down (${elapsed_min}min)"
            fi
        fi
    done

    # Print summary
    [[ ${#all_ok[@]}     -gt 0 ]] && success "OK:        ${all_ok[*]}"
    [[ ${#recovered[@]}  -gt 0 ]] && success "Recovered: ${recovered[*]}"
    [[ ${#newly_down[@]} -gt 0 ]] && warn    "DOWN:      ${newly_down[*]}"
    [[ ${#still_down[@]} -gt 0 ]] && warn    "Still down: ${still_down[*]}"

    # Send webhook for state changes only (down or recovered)
    local changed=("${newly_down[@]}" "${recovered[@]}")
    [[ ${#changed[@]} -eq 0 ]] && return 0

    local down_list
    down_list=$(printf '"%s",' "${newly_down[@]}" | sed 's/,$//')
    local recovered_list
    recovered_list=$(printf '"%s",' "${recovered[@]}" | sed 's/,$//')

    local payload
    payload=$(cat <<EOF
{
  "alert_type": "service_watchdog",
  "host_name": "$HOST_NAME",
  "host_ip": "$HOST_IP",
  "timestamp": "$TIMESTAMP",
  "newly_down": [${down_list}],
  "recovered": [${recovered_list}],
  "still_down_count": ${#still_down[@]},
  "auto_restart_enabled": ${auto_restart}
}
EOF
)
    send_webhook "$WEBHOOK_URL" "$payload"
}
