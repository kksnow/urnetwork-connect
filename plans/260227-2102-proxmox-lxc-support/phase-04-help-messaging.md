# Phase 4: Update Help Text & User Messaging

**Priority:** Low
**Status:** Complete
**Effort:** Small

## Context

- File: `scripts/Provider_Install_Linux.sh`

## Overview

Update help text and installation messages to reflect that the script works with or without systemd. Users should know which mode they're in.

## Implementation Steps

1. **Update `show_help()` — mention cron fallback**
   - Add note under "Options for auto-update" and "Options for auto-start" that cron is used when systemd is unavailable

2. **Update install completion message (lines 676-689)**
   - When `has_systemd=0`, show cron-based instructions instead of systemctl commands:
   ```
   Start:                 urnet-tools start
   Stop:                  urnet-tools stop
   Status:                urnet-tools status
   Auto-start configured via cron (@reboot)
   Auto-update configured via cron (daily at 3:00 AM)
   ```

3. **Add init mode info to `show_status()` / `show_status_pid()`**
   - Print whether running in systemd or PID mode

## Related Code Files

- Modify: `scripts/Provider_Install_Linux.sh`

## Todo

- [x] Update help text for auto-start and auto-update sections
- [x] Update install completion messages for non-systemd
- [x] Add mode indicator to status output

## Success Criteria

- Users on LXC containers see relevant instructions (not systemctl commands)
- Help text mentions cron fallback
- Status output shows which service mode is active
