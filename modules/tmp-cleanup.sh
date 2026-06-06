#!/bin/bash
# servus module - tmp-cleanup
# Deletes files from /tmp and /var/tmp older than N days.
# Skips files currently open by a running process to avoid breaking active apps.

run_tmp_cleanup() {
    load_config
    system_identity

    local days="${TMP_CLEANUP_DAYS:-7}"
    local dirs="${TMP_CLEANUP_DIRS:-/tmp /var/tmp}"
    local deleted=0 skipped=0 total_freed_kb=0

    info "Cleaning files older than ${days} days from: ${dirs}"

    for dir in $dirs; do
        [[ -d "$dir" ]] || { warn "Directory not found, skipping: $dir"; continue; }

        while IFS= read -r -d '' f; do
            # Skip if the file is open by any process
            if command -v lsof &>/dev/null && lsof "$f" &>/dev/null 2>&1; then
                (( skipped++ )) || true
                log "tmp-cleanup: skipped (open) $f"
                continue
            fi

            local size_kb
            size_kb=$(du -k "$f" 2>/dev/null | awk '{print $1}')
            if rm -f "$f" 2>/dev/null; then
                (( deleted++ ))   || true
                (( total_freed_kb += ${size_kb:-0} )) || true
            fi
        done < <(find "$dir" -mindepth 1 -maxdepth 3 \
            -not -path "$dir/systemd*" \
            -not -path "$dir/.X*" \
            -type f -atime "+${days}" -print0 2>/dev/null)

        # Remove empty subdirectories left behind (but not the root tmp dirs themselves)
        find "$dir" -mindepth 1 -maxdepth 3 -type d -empty -delete 2>/dev/null || true
    done

    local freed_mb
    freed_mb=$(awk "BEGIN {printf \"%.1f\", $total_freed_kb/1024}")
    success "Removed ${deleted} file(s), freed ~${freed_mb} MB (skipped ${skipped} open file(s))"
    log "tmp-cleanup: deleted=${deleted} freed=${freed_mb}MB skipped=${skipped}"
}
