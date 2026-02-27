# systemd Dependency Analysis: Provider_Install_Linux.sh

## Executive Summary

Script contains **systemd-dependent code at multiple critical stages**. When `has_systemd=0`, ~35% of operational commands become non-functional (service management, auto-update, auto-start). Installation succeeds but produces limited automation.

---

## 1. ALL SYSTEMD-DEPENDENT CODE PATHS

### 1.1 Global Systemd Detection (Line 117-119)
```sh
if command -v systemctl > /dev/null; then
    has_systemd=1
fi
```
**Impact:** Single point of detection. If `systemctl` is in PATH, sets flag for entire script lifecycle.

### 1.2 Systemd Configuration Paths (Lines 296-300)
```sh
systemd_userdir="$HOME/.config/systemd/user"
systemd_service="$systemd_userdir/urnetwork.service"
systemd_update_service="$systemd_userdir/urnetwork-update.service"
systemd_update_timer="$systemd_userdir/urnetwork-update.timer"
systemd_units_stopped=0
```
**Path Location:** User-level systemd units (no root required).

### 1.3 Function: `stop_systemd_units()` (Lines 302-320)

| Operation | Command | Behavior |
|-----------|---------|----------|
| Check if service exists | `[ -f "$systemd_service" ]` | Conditional check |
| Check if service running | `systemctl --user is-active urnetwork.service` | Warns user if active during update |
| Stop service | `systemctl --user disable --now urnetwork.service` | Stops + disables before update |
| Stop timer | `systemctl --user disable --now urnetwork-update.timer` | Stops auto-update timer |

**Called by:** `do_install()` at line 594 **when** `has_systemd=1`

**Gap:** If `has_systemd=0`, service/timer are never stopped during update. Old instance may continue running during binary replacement.

### 1.4 Function: `install_systemd_units()` (Lines 322-381)

**Operations:**
1. **Create service file** (lines 329-339)
   ```sh
   cat > "$systemd_service" <<EOF
   [Unit]
   Description=URnetwork Provider
   [Service]
   ExecStart=$install_path/bin/urnetwork provide
   Restart=no
   [Install]
   WantedBy=default.target
   EOF
   ```
   - Creates `~/.config/systemd/user/urnetwork.service`
   - Restarts disabled (manual start required)

2. **Create update service** (lines 341-349)
   ```sh
   cat > "$systemd_update_service" <<EOF
   [Unit]
   Description=URnetwork Update
   [Service]
   Type=oneshot
   ExecStart=$install_path/bin/urnet-tools update
   EOF
   ```
   - Creates update helper service (executed by timer)

3. **Create update timer** (lines 351-362)
   ```sh
   cat > "$systemd_update_timer" <<EOF
   [Unit]
   Description=Run URnetwork Update
   [Timer]
   OnCalendar=$update_timer_oncalendar
   Persistent=true
   [Install]
   WantedBy=default.target
   EOF
   ```
   - Schedules updates via systemd timer (default: daily)

4. **Enable service** (lines 364-367)
   ```sh
   systemctl --user enable urnetwork.service
   systemctl --user enable urnetwork-update.timer
   ```
   - Registers with systemd for user session
   - Ensures auto-start on login

5. **Start service if interrupted** (lines 374-380)
   ```sh
   if [ "$start" -eq 1 ]; then
       systemctl --user daemon-reload
       systemctl --user start urnetwork.service
   fi
   ```
   - Restarts service if stopped before update

**Called by:** `do_install()` at line 655 **when** `has_systemd=1`

**Gap:** If `has_systemd=0`, no service files created, no auto-start configured.

### 1.5 Function: `change_auto_update_prefs()` (Lines 764-853)

**Operations:**
1. **Check systemd availability** (lines 808-811)
   ```sh
   if [ "$has_systemd" -eq 0 ]; then
       pr_err "This system doesn't seem to have systemd"
       exit 1
   fi
   ```
   **Hard requirement:** Exits if systemd not available.

2. **Query timer state** (line 813)
   ```sh
   state="$(systemctl --user is-enabled urnetwork-update.timer)"
   ```

3. **Update timer interval** (lines 821-841)
   ```sh
   sed -e "s/daily/$interval/g; s/weekly/$interval/g; s/monthly/$interval/g" \
       -i "$HOME/.config/systemd/user/urnetwork-update.timer"
   systemctl --user daemon-reload
   systemctl --user enable --now urnetwork-update.timer
   ```

4. **Disable auto-update** (lines 844-851)
   ```sh
   systemctl --user disable --now urnetwork-update.timer
   ```

**Called by:** Operation `auto-update`

**Gap:** **BLOCKS entire operation** if systemd absent. No fallback.

### 1.6 Function: `toggle_auto_start()` (Lines 855-884)

**Operations:**
1. Enable on login (lines 867-873)
   ```sh
   if systemctl --user is-enabled --quiet urnetwork.service; then
       # already enabled
   else
       systemctl --user enable urnetwork.service
   fi
   ```

2. Disable (lines 876-882)
   ```sh
   if ! systemctl --user is-enabled --quiet urnetwork.service; then
       # already disabled
   else
       systemctl --user disable urnetwork.service
   fi
   ```

**Called by:** Operation `auto-start`

**Gap:** **No fallback logic.** Silently fails if systemd unavailable (no error check on `has_systemd`).

### 1.7 Function: `do_start()` (Lines 886-895)

```sh
if ! systemctl --user is-active --quiet urnetwork.service; then
    pr_info "Starting urnetwork.service"
    systemctl --user start urnetwork.service
fi
```

**Called by:** Operation `start`

**Gap:** **Assumes systemd exists.** No check for `has_systemd`.

### 1.8 Function: `do_stop()` (Lines 897-906)

```sh
if systemctl --user is-active --quiet urnetwork.service; then
    pr_info "Stopping urnetwork.service"
    systemctl --user stop urnetwork.service
fi
```

**Called by:** Operation `stop`

**Gap:** **Assumes systemd exists.** No check for `has_systemd`.

### 1.9 Function: `show_status()` (Lines 908-911)

```sh
systemctl --user status urnetwork.service
```

**Called by:** Operation `status`

**Gap:** **Hard requirement.** No fallback or error handling.

### 1.10 Function: `do_uninstall()` (Lines 702-762)

**Systemd operations** (lines 740-747):
```sh
if [ "$has_systemd" -eq 1 ]; then
    pr_info "Removing systemd unit files"
    systemctl --user disable --now urnetwork.service
    systemctl --user disable --now urnetwork-update.timer
    rm -f "$HOME/.config/systemd/user/urnetwork.service"
    rm -f "$HOME/.config/systemd/user/urnetwork-update.service"
    rm -f "$HOME/.config/systemd/user/urnetwork-update.timer"
fi
```

**Behavior:**
- If systemd present: disables units before removing files
- If systemd absent: skips cleanup (orphaned unit files left behind if manually created)

---

## 2. `loginctl enable-linger` USAGE

### Location: Line 673

```sh
loginctl enable-linger
```

**Context:** Inside `do_install()` after successful binary installation.

**Purpose:** Enables user session lingering:
- Keeps user systemd session alive even after logout
- Allows systemd user services to run in background
- Essential for daemon operation without login shell

**systemd Dependency:** Hard requirement—`loginctl` is systemd utility.

**Gap:**
- **Called unconditionally** regardless of `has_systemd` value
- If systemd unavailable: command fails silently (missing binary)
- User session won't persist after logout on non-systemd systems

---

## 3. NON-SYSTEMD CODE PATHS

### 3.1 Unconditional Operations (Always Execute)

| Operation | Lines | Description |
|-----------|-------|-------------|
| Fetch release info | 494-547 | Network call to GitHub API (systemd-independent) |
| Download tarball | 549-591 | curl/wget download + tar extraction |
| Copy binary | 618-620 | `cp` to `$install_path/bin/urnetwork` |
| Install urnet-tools | 641-649 | Copy install script to `$install_path/bin/urnet-tools` |
| Store version/date | 651-652 | Write `.version` and `.date` metadata files |
| Update ~/.bashrc | 658-671 | Add PATH exports (awk-based) |
| Show installation complete message | 676-689 | Display instructions (systemd shown conditionally) |

### 3.2 Conditional Operations (Gated by `has_systemd`)

**Lines 593-595:**
```sh
if [ "$has_systemd" -eq 1 ]; then
    stop_systemd_units
fi
```
Only calls `stop_systemd_units()` if systemd detected.

**Lines 654-656:**
```sh
if [ "$has_systemd" -eq 1 ]; then
    install_systemd_units
fi
```
Only calls `install_systemd_units()` if systemd detected.

**Lines 683-689:**
Conditionally shows systemd-specific setup commands in final message.

### 3.3 Installation Without systemd

**Functional capabilities:**
✓ Binary downloaded and installed
✓ PATH configured in ~/.bashrc
✓ Manual start possible via `$install_path/bin/urnetwork provide`
✓ Update available via manual script run

**Missing capabilities:**
✗ No service manager integration
✗ No auto-start on login
✗ No auto-update scheduling
✗ No user session persistence (loginctl enable-linger)

---

## 4. GAP ANALYSIS: WHEN `has_systemd=0`

### 4.1 Silent Failures (No Error Reported)

| Function | Operation | Result |
|----------|-----------|--------|
| `toggle_auto_start` | Lines 867-883 | Silently no-ops; user may think auto-start enabled |
| `do_start` | Line 888-895 | `systemctl --user start` fails; no error handling |
| `do_stop` | Line 899-906 | `systemctl --user stop` fails; no error handling |
| `show_status` | Line 910 | `systemctl --user status` fails; no error handling |
| Installation | Line 673 | `loginctl enable-linger` fails; no error handling |

### 4.2 Partial Failures (Logged but Continues)

| Function | Operation | Result |
|----------|-----------|--------|
| `change_auto_update_prefs` | Line 808-811 | **Explicit exit** if systemd absent |

### 4.3 Scenario: User Installs on Non-systemd System

**Step-by-step execution:**

1. **Detection phase (line 117-119):**
   - `systemctl` not in PATH
   - `has_systemd=0`

2. **Install operation:**
   - Binary downloads ✓
   - Binary installed ✓
   - Script tools installed ✓
   - PATH updated in ~/.bashrc ✓
   - **Line 673: `loginctl enable-linger` called** → fails silently
   - Service files NOT created (line 654-656 skipped)
   - User shown installation complete with note: *"(systemd info skipped)"*

3. **Post-install state:**
   - `~/.local/share/urnetwork-provider/bin/urnetwork` exists
   - Manual start works: `urnetwork provide`
   - **BUT:** Start/stop/status/auto-start/auto-update operations **fail at runtime**

4. **User attempts `urnet-tools start`:**
   - Calls `do_start()` (line 886)
   - Runs `systemctl --user start urnetwork.service`
   - Command not found error (systemctl doesn't exist)
   - Process exits with error, but unclear cause to user

### 4.4 Data Files Left Behind on Uninstall

If user manually creates systemd files on non-systemd-aware system, then uninstalls:

```sh
if [ "$has_systemd" -eq 1 ]; then
    # cleanup code (line 740-747)
else
    # NOTHING HAPPENS
fi
```

- Manual .service/.timer files not removed
- User must clean up manually

---

## 5. SERVICE MANAGEMENT OPERATIONS MAP

### Operation Matrix

| Operation | Implementation | Requires systemd | Fallback | Status |
|-----------|-----------------|------------------|----------|--------|
| **install** | `do_install()` | Partial* | Manual start | ✓ Works without systemd |
| **update** | `do_install()` | Partial* | Manual restart | ✓ Works without systemd |
| **reinstall** | `do_install()` | Partial* | Manual start | ✓ Works without systemd |
| **uninstall** | `do_uninstall()` | No | N/A | ✓ Works, partial cleanup |
| **start** | `do_start()` | **YES** | None | ✗ Fails without systemd |
| **stop** | `do_stop()` | **YES** | None | ✗ Fails without systemd |
| **status** | `show_status()` | **YES** | None | ✗ Fails without systemd |
| **auto-start** | `toggle_auto_start()` | **YES** | None | ✗ Fails silently without systemd |
| **auto-update** | `change_auto_update_prefs()` | **YES** | None | ✗ Explicit exit without systemd |

**\* Partial:** Install/update succeed but no service automation configured.

### Detailed Operation Breakdown

#### 1. **install** (Lines 383-700)
- **Without systemd:**
  - ✓ Binary installed
  - ✓ PATH configured
  - ✓ Metadata stored
  - ✗ No service integration
  - ✗ `loginctl enable-linger` fails silently (line 673)

#### 2. **update** (Lines 431-448 in do_install)
- **Without systemd:**
  - ✓ New binary downloaded/installed
  - ✓ .version/.date updated
  - ✗ Old instance not stopped (line 594 skipped)
  - ✗ No auto-restart after update (lines 374-380 skipped)

#### 3. **reinstall** (Lines 450-491 in do_install)
- **Without systemd:**
  - Same as update

#### 4. **uninstall** (Lines 702-762)
- **Without systemd:**
  - ✓ Binary directory removed
  - ✓ ~/.urnetwork removed
  - ✓ ~/.bashrc cleaned
  - ⚠ Unit files NOT disabled (line 742-743 skipped)
  - ⚠ Orphaned .service/.timer files remain

#### 5. **start** (Lines 886-895)
- **Without systemd:**
  - ✗ Calls `systemctl --user start urnetwork.service`
  - ✗ Command fails
  - No fallback to manual invocation

#### 6. **stop** (Lines 897-906)
- **Without systemd:**
  - ✗ Calls `systemctl --user stop urnetwork.service`
  - ✗ Command fails
  - No process kill fallback

#### 7. **status** (Lines 908-911)
- **Without systemd:**
  - ✗ Calls `systemctl --user status urnetwork.service`
  - ✗ Command fails
  - No alternative status check

#### 8. **auto-start** (Lines 855-884)
- **Without systemd:**
  - ✗ Calls `systemctl --user enable/disable urnetwork.service`
  - ✗ Commands fail
  - **BUT:** No explicit error check—fails silently
  - No cron/other fallback

#### 9. **auto-update** (Lines 764-853)
- **Without systemd:**
  - **Explicit error:** `pr_err "This system doesn't seem to have systemd"` (line 809)
  - `exit 1` terminates operation
  - No fallback scheduling mechanism

---

## 6. MISSING ERROR HANDLING

### Functions Without `has_systemd` Checks

1. **`toggle_auto_start()` (Lines 855-884)**
   - Uses `systemctl --user is-enabled` without checking `has_systemd`
   - Silently fails if systemd absent
   - Recommendation: Add check at line 867/876

2. **`do_start()` (Lines 886-895)**
   - Assumes `systemctl --user start` will work
   - No error handling if systemd missing
   - Recommendation: Check `has_systemd` before execution

3. **`do_stop()` (Lines 897-906)**
   - Assumes `systemctl --user stop` will work
   - No error handling if systemd missing
   - Recommendation: Check `has_systemd` before execution

4. **`show_status()` (Lines 908-911)**
   - Direct `systemctl --user status` call
   - No error handling or fallback
   - Recommendation: Check `has_systemd` before execution

5. **Installation Phase (Line 673)**
   - `loginctl enable-linger` called unconditionally
   - Fails silently if systemd absent
   - Recommendation: Wrap in conditional or error trap

### Operations with Proper Error Handling

1. **`change_auto_update_prefs()` (Line 808-811)**
   - ✓ Checks `has_systemd` explicitly
   - ✓ Exits with error message if systemd absent

2. **`do_install()` (Lines 593-595, 654-656)**
   - ✓ Checks `has_systemd` before systemd operations

3. **`do_uninstall()` (Lines 740-747)**
   - ✓ Checks `has_systemd` before systemd cleanup

---

## 7. SCRIPT FLOW DIAGRAM

```
┌─────────────────────────────────────────┐
│ START                                   │
│ Detect systemd: has_systemd = 0 or 1   │
└────────────┬────────────────────────────┘
             │
             ▼
      ┌──────────────┐
      │ OPERATION    │
      └──────┬───────┘
             │
    ┌────────┼────────┬──────────┬─────────────┐
    ▼        ▼        ▼          ▼             ▼
 install  update  uninstall  status/start/stop  auto-*
    │        │        │          │             │
    ▼        ▼        ▼          ▼             ▼
 [A]      [B]      [C]         [D]           [E]

[A] do_install()
    ├─ [has_systemd=1] stop_systemd_units() ✓
    ├─ [always] Download & install binary ✓
    ├─ [always] loginctl enable-linger ✗ no error check
    ├─ [has_systemd=1] install_systemd_units() ✓
    └─ [always] Update ~/.bashrc ✓

[B] do_install()
    └─ Same as [A], but binary already exists

[C] do_uninstall()
    ├─ [always] Remove binary ✓
    ├─ [has_systemd=1] Disable & remove units ✓
    └─ [always] Clean ~/.bashrc ✓

[D] do_start() / do_stop() / show_status()
    ├─ [MISSING: has_systemd check]
    └─ Direct systemctl calls ✗ fails if no systemd

[E] toggle_auto_start() / change_auto_update_prefs()
    ├─ [MISSING in toggle_auto_start()] has_systemd check
    └─ Direct systemctl calls ✗ fails
```

---

## Unresolved Questions

1. **Is `loginctl enable-linger` supposed to be optional?**
   - Currently called unconditionally but only works with systemd
   - Should it be gated by `has_systemd` or wrapped in error trap?

2. **What's the intended behavior for start/stop/status on non-systemd systems?**
   - Should script provide manual alternative (e.g., `pkill urnetwork`)?
   - Or is non-systemd a "not supported" scenario?

3. **Should auto-start/auto-update have non-systemd fallbacks?**
   - cron jobs for auto-update?
   - systemd user sessions alternative?
   - Or explicitly document as systemd-only features?

4. **Why does `auto-update` have explicit error check but others don't?**
   - Inconsistency suggests oversight in `start/stop/status` and `auto-start`
