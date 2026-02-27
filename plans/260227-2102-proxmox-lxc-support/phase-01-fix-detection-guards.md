# Phase 1: Fix Detection & Guard systemd Calls

**Priority:** High
**Status:** Complete
**Effort:** Small

## Context

- [Script systemd analysis](../reports/researcher-260227-2102-script-systemd-analysis.md)
- File: `scripts/Provider_Install_Linux.sh`

## Overview

Several functions call `systemctl` without checking `has_systemd` first, causing cryptic errors on non-systemd systems. This phase adds guards and makes `loginctl enable-linger` conditional.

## Requirements

- All systemd calls must be gated by `has_systemd` check
- `loginctl enable-linger` must be conditional
- When systemd is unavailable, operations should either use a fallback (phases 2-3) or print a clear error message

## Implementation Steps

1. **Guard `do_start()` (line 886-895)**
   - Add `has_systemd` check at top of function
   - If `has_systemd=0`, call new `do_start_pid()` (phase 2)

2. **Guard `do_stop()` (line 897-906)**
   - Add `has_systemd` check at top
   - If `has_systemd=0`, call new `do_stop_pid()` (phase 2)

3. **Guard `show_status()` (line 908-911)**
   - Add `has_systemd` check at top
   - If `has_systemd=0`, call new `show_status_pid()` (phase 2)

4. **Guard `toggle_auto_start()` (line 855-884)**
   - Add `has_systemd` check at top
   - If `has_systemd=0`, call new `toggle_auto_start_cron()` (phase 3)

5. **Guard `change_auto_update_prefs()` (line 808-811)**
   - Replace hard exit with fallback to `change_auto_update_cron()` (phase 3)

6. **Make `loginctl enable-linger` conditional (line 673)**
   - Wrap in `if [ "$has_systemd" -eq 1 ]; then ... fi`

## Related Code Files

- Modify: `scripts/Provider_Install_Linux.sh`

## Todo

- [x] Guard `do_start()` with `has_systemd` check
- [x] Guard `do_stop()` with `has_systemd` check
- [x] Guard `show_status()` with `has_systemd` check
- [x] Guard `toggle_auto_start()` with `has_systemd` check
- [x] Update `change_auto_update_prefs()` to fallback instead of exit
- [x] Wrap `loginctl enable-linger` in conditional

## Success Criteria

- No unguarded `systemctl` or `loginctl` calls remain
- Script runs without errors on systems where `systemctl` is not in PATH
