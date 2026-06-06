# servus

A self-installing server utility kit for Linux. Automates the recurring chores that eat sysadmin time — disk reports, log cleanup, service monitoring, resource alerts — all delivered to a webhook and managed through cron. Each component have their own cron pipeline.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ruhanirabin/servus/main/install.sh | sudo bash
```

⚠️Requires: Linux with `systemd`, `curl`. Tested on Ubuntu, Debian, Rocky Linux, AlmaLinux.

## What it does

| Command | What it runs |
|---|---|
| `servus disk-report` | Sends disk usage, MySQL size, and log size to your webhook |
| `servus log-vacuum` | Truncates log files older than N days, vacuums systemd journal |
| `servus system-info` | Prints CPU, RAM, disk, and uptime to the terminal |
| `servus cpu-ram-alert` | Alerts via webhook if CPU or RAM stays above threshold for N minutes |
| `servus service-watchdog` | Alerts (and optionally restarts) services that go down |
| `servus swap-alert` | Alerts if swap usage stays high — an early warning for memory pressure |
| `servus tmp-cleanup` | Deletes old files from `/tmp` and `/var/tmp` |
| `servus heartbeat` | Pings uptime monitoring endpoints (UptimeKuma push, BetterStack, generic HTTP) |

All alerts send a JSON payload to a webhook URL you configure once during setup.

## Setup

The installer runs the setup wizard automatically. To re-run it later:

```bash
servus setup
```

This asks for your webhook URL, alert thresholds, services to watch, and sets up cron schedules interactively. Config is saved to `/usr/local/etc/servus/config`.

To manage cron jobs independently:

```bash
servus cron
```

## Cron schedule options

The cron wizard offers: every 5 min, 15 min, 30 min, hourly, every 6h, every 12h, daily, weekly, or a custom expression. Each module's schedule is set independently.

## Updating

```bash
servus update
```

Checks GitHub for a newer version. Minor and patch updates apply with a single confirmation. Major version upgrades show a warning and require explicit confirmation — check the [changelog](https://github.com/ruhanirabin/servus/releases) first.

## Other commands

```bash
servus heartbeat add      # add a heartbeat endpoint (prompted)
servus heartbeat list     # show configured endpoints
servus heartbeat remove   # remove an endpoint
servus status             # show current config and cron jobs, check for updates
servus detect             # auto-detect installed services on this system
servus uninstall          # remove everything cleanly
servus help               # list all commands
```

## Installed paths

| Path | Purpose |
|---|---|
| `/usr/local/bin/servus` | Main binary |
| `/usr/local/lib/servus/` | Modules and libraries |
| `/usr/local/etc/servus/config` | Configuration |
| `/var/lib/servus/` | State files (alert tracking) |
| `/var/log/servus/servus.log` | Internal log |

## Webhook payload

Every module sends a JSON payload. Example from `disk-report`:

```json
{
  "host_name": "web01",
  "host_ip": "192.168.1.10",
  "timestamp": "2026-01-15 09:00:00",
  "disk_used_gb": 42.5,
  "disk_total_gb": 100.0,
  "disk_use_pct": 42,
  "mysql_space_mb": 1024,
  "logs_space_mb": 310
}
```

## Requirements

- Linux (systemd required for `service-watchdog`)
- `curl`
- Root access for install and runtime

## License

MIT — see [LICENSE](LICENSE).

---

Made by [Ruhani Rabin](https://www.ruhanirabin.com/tools/)
