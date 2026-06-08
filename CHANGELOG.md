# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-08

### Added
- Explicit `cpu_use_pct` and `ram_use_pct` fields to the `disk-report` webhook payload, providing automation tools with immediate used-to-total ratio metrics without requiring client-side calculations.

### Fixed
- Added `-P` (POSIX) flag to all `df` commands to prevent line-wrapping parsing errors on systems with long device names (e.g., LVM, ZFS).
- Replaced fragile `uptime` command parsing with a direct, locale-independent read from `/proc/loadavg` in `system-info`.
- Excluded `/var/log/servus/*` from `log-vacuum` operations to prevent the script from accidentally truncating its own audit logs.
- Added a pre-flight check for the `crontab` command in `install.sh` to prevent silent scheduling failures on minimal Debian VPS/VDS images.
- Removed the obsolete and misleading `bc` dependency warning from the installer, as all numeric formatting correctly uses `awk`.
- Masked the `WEBHOOK_URL` value in the `servus status` output to prevent accidental exposure of sensitive tokens during terminal sharing or logging.

## [1.0.15] - 2026-06-07

### Fixed
- Improved cron default values.
- Fixed color escape codes rendering.
- Added `exec 0</dev/tty` to interactive commands to ensure stdin is firmly bound to the terminal.
- Resolved minor CRLF line ending issues.
