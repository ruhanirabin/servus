#!/bin/bash
# servus module - log-vacuum

run_log_vacuum() {
    load_config
    system_identity

    local dirs="${LOG_VACUUM_DIRS:-/var/log}"
    local days="${LOG_VACUUM_DAYS:-2}"
    local truncated=0 total_freed_kb=0

    info "Vacuuming log files older than ${days} days in: ${dirs}"

    for dir in $dirs; do
        [[ -d "$dir" ]] || { warn "Directory not found, skipping: $dir"; continue; }

        while IFS= read -r -d '' f; do
            local size_before
            size_before=$(stat -c%s "$f" 2>/dev/null || echo 0)
            truncate -s 0 "$f" 2>/dev/null && {
                (( truncated++ )) || true
                (( total_freed_kb += size_before / 1024 )) || true
            }
        done < <(find "$dir" -type f \( -name "*.log" -o -name "*.log.*" \) -not -path "/var/log/servus/*" -mtime "+${days}" -print0 2>/dev/null)
    done

    # Vacuum systemd journal
    local journal_result=""
    if command -v journalctl &>/dev/null; then
        journal_result=$(journalctl --vacuum-time="${days}d" 2>&1 | tail -1 || true)
        info "journalctl vacuum: $journal_result"
    fi

    local freed_mb
    freed_mb=$(awk "BEGIN {printf \"%.1f\", $total_freed_kb/1024}")
    success "Vacuumed ${truncated} log file(s), freed ~${freed_mb} MB"
    log "log-vacuum: truncated=${truncated} freed=${freed_mb}MB journal=${journal_result}"
}
