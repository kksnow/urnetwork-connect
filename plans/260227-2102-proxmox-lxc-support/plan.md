# Plan: Proxmox LXC Support for Provider_Install_Linux.sh

**Date:** 2026-02-27
**Status:** Complete
**File:** `scripts/Provider_Install_Linux.sh`

## Problem

The install script uses systemd user services (`systemctl --user`) for service management. In Proxmox LXC containers (especially unprivileged), systemd is often unavailable or broken:
- `loginctl enable-linger` fails (no dbus/systemd-logind)
- `systemctl --user` commands fail (no cgroup delegation)
- 5 of 9 operations completely broken without systemd (start, stop, status, auto-start, auto-update)

## Approach

**Don't replace systemd — add a cron + PID file fallback** when systemd is unavailable.

Rationale:
- cron is universally available (every LXC distro ships it)
- No extra dependencies (no supervisord, runit, etc.)
- PID files give us start/stop/status without a service manager
- Minimal code changes — reuse existing `has_systemd` detection

## Phases

| # | Phase | Status | Priority |
|---|-------|--------|----------|
| 1 | [Fix detection & guard systemd calls](phase-01-fix-detection-guards.md) | Complete | High |
| 2 | [Add PID-based service management](phase-02-pid-service-management.md) | Complete | High |
| 3 | [Add cron-based auto-start & auto-update](phase-03-cron-fallback.md) | Complete | Medium |
| 4 | [Update help text & user messaging](phase-04-help-messaging.md) | Complete | Low |

## Key Decisions

1. **Fallback mechanism: cron + PID file** (not supervisord/OpenRC/runit)
   - Zero additional dependencies
   - Works in every LXC container
   - KISS: simplest solution that covers all operations

2. **PID file location:** `$install_path/.pid` (alongside existing `.version`, `.date`)

3. **Cron for auto-update:** `@daily` cron entry instead of systemd timer

4. **Cron for auto-start:** `@reboot` cron entry instead of systemd enable

5. **No LXC-specific detection needed** — script already has `has_systemd`; just use that

## Dependencies

- None. All tools used (cron, kill, ps) are POSIX standard.

## Research Reports

- [Proxmox LXC systemd research](../reports/researcher-260227-2102-proxmox-lxc-systemd.md)
- [Script systemd dependency analysis](../reports/researcher-260227-2102-script-systemd-analysis.md)
