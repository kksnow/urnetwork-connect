# Code Review: Proxmox LXC Support in Provider_Install_Linux.sh

## Scope
- File: `/home/ubuntu/Dev/urnetwork-connect/scripts/Provider_Install_Linux.sh`
- LOC: 1122
- Delta: ~150 lines added/modified
- Focus: PID-based process management, cron-based scheduling, systemd guards

## Overall Assessment

The design is sound -- when `has_systemd=0`, the script falls back to cron for scheduling and PID files for process management. All systemd call sites are properly guarded. The cron helpers use a marker-based approach that prevents duplicates. Several issues found, mostly medium severity, with one high-priority bug.

---

## Critical Issues

None.

---

## High Priority

### H1. `-i`/`--install` flag does not update `pid_file` and `log_file`

**Lines 114-117 vs 303:**
`pid_file` and `log_file` are derived from `install_path` at line 116-117, but `install_path` can be overridden at line 303 via `-i`/`--install`. The derived variables are never recalculated.

```sh
# Line 114-117 (initialization)
install_path="$HOME/.local/share/urnetwork-provider"
version_file="$install_path/.version"
pid_file="$install_path/.pid"
log_file="$install_path/provider.log"

# Line 303 (override - pid_file/log_file still point to old path)
install_path="$2"
```

**Impact:** If user passes `-i /opt/urnetwork`, PID file operations will target `~/.local/share/urnetwork-provider/.pid` while the binary runs from `/opt/urnetwork/`. Start/stop/status will be broken. Note: `version_file` has the same pre-existing bug.

**Fix:** After the `-i` parsing block, re-derive all path-dependent variables:
```sh
-i|--install)
    ...
    install_path="$2"
    version_file="$install_path/.version"
    pid_file="$install_path/.pid"
    log_file="$install_path/provider.log"
    shift 2
    ;;
```

### H2. `do_start_pid` race: PID captured from `$!` may not be the nohup child

**Lines 1009-1010:**
```sh
nohup "$install_path/bin/urnetwork" provide >> "$log_file" 2>&1 &
echo "$!" > "$pid_file"
```

`$!` captures the PID of the backgrounded process. With `nohup` in `/bin/sh`, some shells may give the PID of the nohup wrapper rather than the child. On most Linux `/bin/sh` (dash, bash), `nohup cmd &` gives the correct child PID, but behavior is shell-dependent.

**Impact:** Low probability but if PID is wrong, `kill` in `do_stop_pid` kills wrong process or nothing. The `is_running` check (`kill -0`) would also give false results.

**Mitigation:** Acceptable for current targets (Debian/Ubuntu LXC). If portability to other `/bin/sh` implementations is needed, consider writing PID from the process itself or using `exec` after nohup.

### H3. `do_stop_pid` and `do_install` stop do not wait for process termination

**Lines 1038-1041 (`do_stop_pid`):**
```sh
pid="$(cat "$pid_file")"
kill "$pid" 2>/dev/null
rm -f "$pid_file"
```

**Lines 634-638 (`do_install` pre-update stop):**
```sh
pid="$(cat "$pid_file")"
kill "$pid" 2>/dev/null
rm -f "$pid_file"
```

`kill` sends SIGTERM but does not wait for the process to actually exit. If the provider takes time to shut down (closing connections, flushing state), the install proceeds immediately -- copying over a binary that may still be running.

**Fix:** Add a brief wait loop:
```sh
kill "$pid" 2>/dev/null
# Wait up to 10s for process to exit
i=0
while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done
if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
fi
rm -f "$pid_file"
```

---

## Medium Priority

### M1. `is_running` does not validate PID is the urnetwork process (PID reuse)

**Lines 229-241:**
```sh
is_running ()
{
    if [ -f "$pid_file" ]; then
        pid="$(cat "$pid_file")"
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$pid_file"
    fi
    return 1
}
```

`kill -0` checks if *any* process with that PID exists, not that it is `urnetwork provide`. After reboot or long uptime, the PID could be reused by an unrelated process. The stale PID file cleanup only triggers when the PID is dead, not when it belongs to a different process.

**Impact:** `do_start_pid` would refuse to start ("already running") when it is not. `do_stop_pid` would kill an unrelated process.

**Fix:** Validate process name via `/proc/$pid/cmdline` or `ps`:
```sh
is_running ()
{
    if [ -f "$pid_file" ]; then
        pid="$(cat "$pid_file")"
        if kill -0 "$pid" 2>/dev/null; then
            # Verify it's actually our process
            if [ -f "/proc/$pid/cmdline" ] && \
               tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q "urnetwork provide"; then
                return 0
            fi
            # PID exists but not our process - stale
            rm -f "$pid_file"
            return 1
        fi
        rm -f "$pid_file"
    fi
    return 1
}
```

### M2. `has_systemd` detection: `systemctl` present but non-functional in LXC

**Lines 123-125:**
```sh
if command -v systemctl > /dev/null; then
    has_systemd=1
fi
```

Many LXC containers have `systemctl` installed (it comes with the `systemd` package) but systemd is not PID 1 -- the container runs under a different init. `systemctl` commands will fail at runtime.

**Impact:** Script detects `has_systemd=1` in an LXC container, then all systemd commands fail. The cron/PID fallback never activates.

**Fix:** Check if systemd is actually the init system:
```sh
if command -v systemctl > /dev/null && [ -d /run/systemd/system ]; then
    has_systemd=1
fi
```

`/run/systemd/system` only exists when systemd is PID 1. This is the standard detection method used by `systemd` itself.

### M3. No log rotation for `provider.log`

**Line 1009:**
```sh
nohup "$install_path/bin/urnetwork" provide >> "$log_file" 2>&1 &
```

Logs append indefinitely. On a long-running LXC provider, this file will grow without bound. With systemd, journal handles rotation; with PID mode, nothing does.

**Impact:** Disk space exhaustion over time.

**Suggestion:** Not blocking for merge, but consider adding logrotate config during install or truncating on start.

### M4. `cron_remove_entry` leaves empty crontab

**Lines 254-258:**
```sh
cron_remove_entry ()
{
    marker="$1"
    (crontab -l 2>/dev/null | grep -v "# $marker" || true) | crontab -
}
```

If the only entries in the crontab are urnetwork entries, removing them results in an empty crontab. `crontab -` with empty stdin installs an empty crontab, which is fine functionally but some cron implementations log warnings about empty crontabs.

**Impact:** Cosmetic. No functional issue.

### M5. `do_uninstall` stops process then deletes `install_path` containing PID file

**Lines 790-798:**
```sh
if is_running; then
    pr_info "Stopping running provider before uninstall"
    pid="$(cat "$pid_file")"
    kill "$pid" 2>/dev/null
fi

if ! rm -r "$install_path"; then
```

Same issue as H3 -- no wait after `kill`. Additionally, PID file is not explicitly removed because `rm -r "$install_path"` will delete it. But if the process is still running when `rm -r` executes, the binary may still be open (fine on Linux due to inode semantics, but messy).

---

## Low Priority

### L1. Global variable `pid` leaks from `is_running()` into caller scope

**Line 233:** `pid="$(cat "$pid_file")"` sets a global variable `pid` in POSIX sh (no `local` keyword in POSIX). Several callers also use `pid` as a variable name (lines 636, 792, 1038, 1063). Currently works because callers read `pid_file` independently, but fragile.

### L2. `toggle_auto_start` does not have a status query mode (no-arg prints status)

Unlike `change_auto_update_prefs` which shows status when called with no arg, `toggle_auto_start` errors on no arg. Inconsistent UX but arguably correct since the help text says "on or off" is required.

---

## Edge Cases Found by Scouting

1. **`-i` flag + PID/log path mismatch** -- See H1 above.
2. **Systemd present but non-functional in LXC** -- See M2 above. This is the primary use case for this feature and the detection would fail.
3. **Concurrent `urnet-tools start` invocations** -- TOCTOU between `is_running` check and PID file write in `do_start_pid`. Two concurrent starts could both pass the check and both write PIDs. Low probability in practice.
4. **`crontab` command not available** -- Some minimal LXC containers may not have `cron` installed. No check for `crontab` availability before using it. Would produce confusing errors.
5. **Reboot with stale PID file** -- After reboot, PID file persists but PID is invalid. `is_running()` correctly handles this (stale cleanup). However, the `@reboot` cron job calls `urnet-tools start` which calls `do_start_pid` which calls `is_running` -- this works correctly.

---

## Positive Observations

- Guard pattern is consistent: all systemd call sites check `has_systemd`
- `cron_add_entry` prevents duplicates by removing before adding (idempotent)
- `loginctl enable-linger` properly guarded for non-systemd systems
- Clean separation: `*_pid()` and `*_cron()` functions isolate non-systemd logic
- Help text updated to document cron fallback behavior
- Install messages show appropriate commands per environment

---

## Recommended Actions (Priority Order)

1. **[M2] Fix `has_systemd` detection** -- Add `/run/systemd/system` check. Without this, the entire LXC feature may not activate on many containers. This is the most impactful fix.
2. **[H1] Re-derive `pid_file`/`log_file` after `-i` override** -- Straightforward 3-line fix.
3. **[H3] Add wait-for-exit after `kill` in stop paths** -- Prevents binary replacement while process still running.
4. **[M1] Validate PID belongs to urnetwork** -- Prevents PID-reuse false positives.
5. **[M3] Consider log rotation** -- Not blocking, but should be tracked for follow-up.

---

## Unresolved Questions

1. Is the `-i`/`--install` flag actively used by any deployment scripts? If not, H1 may be lower priority.
2. Does the `urnetwork provide` binary handle SIGTERM gracefully (clean shutdown), or does it need SIGINT?
3. Should cron-based auto-start also auto-start the provider immediately at install time (not just on next reboot)?
4. Is there a plan to support containers where neither systemd nor cron is available (e.g., Alpine with OpenRC)?
