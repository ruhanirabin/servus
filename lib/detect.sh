#!/bin/bash
# servus - service auto-detection
# Discovers which known services are present on this system via systemd unit files.
# Returns only services that actually exist — not just binaries, because a binary
# without a unit file can't be monitored with systemctl.

# Known services to probe, grouped for readability
_SERVUS_KNOWN_SERVICES=(
    # Web servers
    nginx apache2 httpd lighttpd openlitespeed lshttpd caddy traefik
    # PHP-FPM (versioned variants handled separately below)
    php-fpm
    # Databases
    mysql mariadb mariadb-server postgresql mongod mongodb redis redis-server memcached
    # Mail
    postfix dovecot exim4
    # Containers / process managers
    docker containerd podman supervisor supervisord
    # Security
    fail2ban ufw crowdsec
    # SSH (almost always present but worth watching)
    ssh sshd
    # Cron
    cron crond
    # Other common daemons
    varnish haproxy certbot-renew
)

# Check if a service unit file exists in systemd (enabled, disabled, or static)
_unit_exists() {
    systemctl list-unit-files "${1}.service" --no-legend 2>/dev/null | grep -q "^${1}\.service"
}

# Detect all versioned php-fpm units (e.g. php8.2-fpm, php7.4-fpm)
_detect_php_fpm() {
    systemctl list-unit-files --no-legend --type=service 2>/dev/null \
        | awk '{print $1}' \
        | grep -E '^php[0-9]+\.[0-9]+-fpm\.service$' \
        | sed 's/\.service$//'
}

# Main discovery function — prints a space-separated list of detected service names
detect_services() {
    local found=()

    for svc in "${_SERVUS_KNOWN_SERVICES[@]}"; do
        _unit_exists "$svc" && found+=("$svc")
    done

    # Add versioned php-fpm variants
    while IFS= read -r svc; do
        [[ -n "$svc" ]] && found+=("$svc")
    done < <(_detect_php_fpm)

    echo "${found[*]}"
}

# Pretty-print detected services grouped by category for the setup wizard
print_detected_services() {
    local found
    found=$(detect_services)

    if [[ -z "$found" ]]; then
        warn "No known services detected on this system."
        return
    fi

    info "Detected services on this system:"
    local web=() db=() php=() other=()
    for svc in $found; do
        case "$svc" in
            nginx|apache2|httpd|lighttpd|openlitespeed|lshttpd|caddy|traefik|haproxy|varnish)
                web+=("$svc") ;;
            mysql|mariadb|mariadb-server|postgresql|mongod|mongodb|redis|redis-server|memcached)
                db+=("$svc") ;;
            php*fpm*)
                php+=("$svc") ;;
            *)
                other+=("$svc") ;;
        esac
    done

    [[ ${#web[@]}   -gt 0 ]] && echo "  Web servers : ${web[*]}"
    [[ ${#db[@]}    -gt 0 ]] && echo "  Databases   : ${db[*]}"
    [[ ${#php[@]}   -gt 0 ]] && echo "  PHP-FPM     : ${php[*]}"
    [[ ${#other[@]} -gt 0 ]] && echo "  Other       : ${other[*]}"
}
