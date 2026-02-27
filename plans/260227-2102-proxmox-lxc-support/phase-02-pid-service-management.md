# Phase 2: Add PID-based Service Management

**Priority:** High
**Status:** Complete
**Effort:** Medium

## Context

- [Script systemd analysis](../reports/researcher-260227-2102-script-systemd-analysis.md)
- File: `scripts/Provider_Install_Linux.sh`

## Overview

Add PID file-based start/stop/status as fallback when systemd is unavailable. Uses standard POSIX tools (`kill`, `ps`, backgrounding).

## Key Design

- **PID file:** `$install_path/.pid`
- **Log file:** `$install_path/provider.log`
- Process runs as background daemon with output redirected to log
- PID file cleaned up on stop/crash detection

## Implementation Steps

1. **Add PID file path variable (near line 110)**
   ```sh
   pid_file="$install_path/.pid"
   log_file="$install_path/provider.log"
   ```

2. **Add helper: `is_running()`**
   ```sh
   is_running()
   {
       if [ -f "$pid_file" ]; then
           pid="$(cat "$pid_file")"
           if kill -0 "$pid" 2>/dev/null; then
               return 0
           fi
           # Stale PID file
           rm -f "$pid_file"
       fi
       return 1
   }
   ```

3. **Add `do_start_pid()`**
   ```sh
   do_start_pid()
   {
       if is_running; then
           pr_info "URnetwork provider is already running (PID: %s)" "$(cat "$pid_file")"
           exit 1
       fi

       pr_info "Starting URnetwork provider (PID mode)"
       nohup "$install_path/bin/urnetwork" provide >> "$log_file" 2>&1 &
       echo "$!" > "$pid_file"
       pr_info "Started with PID %s" "$!"
       pr_info "Logs: %s" "$log_file"
   }
   ```

4. **Add `do_stop_pid()`**
   ```sh
   do_stop_pid()
   {
       if ! is_running; then
           pr_info "URnetwork provider is not running"
           exit 1
       fi

       pid="$(cat "$pid_file")"
       pr_info "Stopping URnetwork provider (PID: %s)" "$pid"
       kill "$pid" 2>/dev/null
       rm -f "$pid_file"
   }
   ```

5. **Add `show_status_pid()`**
   ```sh
   show_status_pid()
   {
       if is_running; then
           pid="$(cat "$pid_file")"
           pr_info "URnetwork provider is running (PID: %s)" "$pid"
       else
           pr_info "URnetwork provider is not running"
       fi
   }
   ```

6. **Update `do_install()` — stop running PID process before update (when `has_systemd=0`)**
   - After line 593-595, add:
   ```sh
   if [ "$has_systemd" -eq 0 ] && is_running; then
       pr_info "Stopping running provider before update"
       pid="$(cat "$pid_file")"
       kill "$pid" 2>/dev/null
       rm -f "$pid_file"
   fi
   ```

7. **Update `do_uninstall()` — clean up PID file**
   - Before `rm -r "$install_path"` (line 732), add:
   ```sh
   if is_running; then
       pr_info "Stopping running provider before uninstall"
       pid="$(cat "$pid_file")"
       kill "$pid" 2>/dev/null
   fi
   ```

## Related Code Files

- Modify: `scripts/Provider_Install_Linux.sh`

## Todo

- [x] Add `pid_file` and `log_file` variables
- [x] Implement `is_running()` helper
- [x] Implement `do_start_pid()`
- [x] Implement `do_stop_pid()`
- [x] Implement `show_status_pid()`
- [x] Update `do_install()` to stop PID process before update
- [x] Update `do_uninstall()` to stop PID process before uninstall

## Success Criteria

- `urnet-tools start` works on non-systemd systems, launches provider in background
- `urnet-tools stop` cleanly stops the provider
- `urnet-tools status` shows running/not-running state
- Stale PID files are cleaned up automatically
- Updates stop old process before replacing binary

## Risk Assessment

- **PID file race condition:** Minimal risk — single-user tool, not multi-instance
- **Orphaned processes on crash:** PID check via `kill -0` handles stale files
- **Signal handling:** `kill` (SIGTERM) is standard; provider should handle graceful shutdown

## Implementation Notes

**Improvements beyond original spec:**
- Added `wait_for_exit()` helper with 10-second timeout + SIGKILL fallback for forceful termination
- PID validation via `/proc/$pid/cmdline` to prevent killing wrong process on PID reuse
- Re-derived `pid_file` and `log_file` after `-i` install path override to ensure correct paths in all code branches
