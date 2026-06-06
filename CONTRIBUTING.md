# Contributing to servus

Thanks for taking the time. Contributions are welcome — bug fixes, new modules, and improvements to existing ones.

## Before you start

- Open an issue first for anything beyond a small bug fix. A quick discussion saves wasted effort if the idea doesn't fit the project's direction.
- Keep the scope focused. servus is a server utility kit, not a general-purpose framework. New modules should solve a concrete, recurring sysadmin problem.

## Adding a new module

1. Create `modules/your-module.sh` following the pattern of an existing module.
2. Start with `load_config` and `system_identity` from `lib/common.sh`.
3. Name the entry function `run_your_module`.
4. Add the command to `servus.sh` (the `case` block and the `usage()` list).
5. Add a `pick_schedule` entry in `lib/cron.sh` → `run_cron_manager`.
6. Add any new config keys to `lib/setup.sh` with existing-value defaults.
7. Add the file to the download list in `install.sh` and the upgrade list in `lib/update.sh`.
8. Add a line to the README command table.

## Code style

- POSIX-compatible bash where possible, bash 4+ features where needed.
- Use `local` for all variables inside functions.
- Error output goes to stderr via `die` or `warn` from `common.sh`.
- State files (for sustained-alert tracking) go in `$SERVUS_STATE_DIR`.
- Webhook payloads are plain JSON strings — no external JSON tools required.
- Don't add dependencies beyond what's on a minimal Linux server (`curl`, `awk`, `find`, `systemctl`).

## Pull requests

- One thing per PR. Mixed concerns are harder to review and harder to revert.
- Test on at least one real Linux server before submitting.
- Update `VERSION` only if you're the one cutting a release — leave it alone in feature PRs.

## Reporting bugs

Open a GitHub issue with:
- Your OS and version (`cat /etc/os-release`)
- The exact command you ran
- The full output or error message
