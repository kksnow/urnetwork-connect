# Phase 3: Add Cron-based Auto-start & Auto-update

**Priority:** Medium
**Status:** Complete
**Effort:** Medium

## Context

- [Proxmox LXC research](../reports/researcher-260227-2102-proxmox-lxc-systemd.md)
- File: `scripts/Provider_Install_Linux.sh`

## Overview

Replace systemd timer/enable with cron entries for auto-start on boot and scheduled auto-updates. Uses standard `crontab` command available on all Linux systems.

## Key Design

- **Cron marker comments** to identify our entries (like `# == urnetwork-provider` in .bashrc)
- `@reboot` for auto-start
- `@daily` / `@weekly` / `@monthly` for auto-update
- Cron entries managed via `crontab -l` + pipe + `crontab -`

## Implementation Steps

1. **Add cron helper: `cron_add_entry()`**
   ```sh
   cron_add_entry()
   {
       marker="$1"
       entry="$2"

       # Remove existing entry with this marker, then add new one
       (crontab -l 2>/dev/null | grep -v "# $marker" || true; \
        echo "$entry # $marker") | crontab -
   }
   ```

2. **Add cron helper: `cron_remove_entry()`**
   ```sh
   cron_remove_entry()
   {
       marker="$1"
       (crontab -l 2>/dev/null | grep -v "# $marker" || true) | crontab -
   }
   ```

3. **Add `toggle_auto_start_cron()`**
   ```sh
   toggle_auto_start_cron()
   {
       marker="urnetwork-autostart"

       if [ "$1" = "on" ]; then
           pr_info "Enabling auto-start via cron (@reboot)"
           cron_add_entry "$marker" "@reboot $install_path/bin/urnet-tools start"
       elif [ "$1" = "off" ]; then
           pr_info "Disabling auto-start via cron"
           cron_remove_entry "$marker"
       fi
   }
   ```

4. **Add `change_auto_update_cron()`**
   ```sh
   change_auto_update_cron()
   {
       mode="$1"
       interval="$2"
       marker="urnetwork-autoupdate"

       if [ -z "$mode" ]; then
           if crontab -l 2>/dev/null | grep -q "# $marker"; then
               pr_info "Auto update: enabled (cron)"
           else
               pr_info "Auto update: disabled"
           fi
           return
       fi

       if [ "$mode" = "on" ]; then
           case "$interval" in
               daily)   schedule="0 3 * * *" ;;
               weekly)  schedule="0 3 * * 0" ;;
               monthly) schedule="0 3 1 * *" ;;
           esac
           pr_info "Enabling auto-update via cron (%s)" "$interval"
           cron_add_entry "$marker" "$schedule $install_path/bin/urnet-tools update"
       elif [ "$mode" = "off" ]; then
           pr_info "Disabling auto-update via cron"
           cron_remove_entry "$marker"
       fi
   }
   ```

5. **Install cron entries during `do_install()` (when `has_systemd=0`)**
   - After the systemd unit install block (line 654-656), add:
   ```sh
   if [ "$has_systemd" -eq 0 ]; then
       cron_add_entry "urnetwork-autostart" "@reboot $install_path/bin/urnet-tools start"
       cron_add_entry "urnetwork-autoupdate" "0 3 * * * $install_path/bin/urnet-tools update"
       pr_info "Auto-start and auto-update configured via cron"
   fi
   ```

6. **Remove cron entries during `do_uninstall()` (when `has_systemd=0`)**
   - After systemd cleanup block (line 740-747), add:
   ```sh
   if [ "$has_systemd" -eq 0 ]; then
       cron_remove_entry "urnetwork-autostart"
       cron_remove_entry "urnetwork-autoupdate"
       pr_info "Removed cron entries"
   fi
   ```

## Related Code Files

- Modify: `scripts/Provider_Install_Linux.sh`

## Todo

- [x] Implement `cron_add_entry()` helper
- [x] Implement `cron_remove_entry()` helper
- [x] Implement `toggle_auto_start_cron()`
- [x] Implement `change_auto_update_cron()`
- [x] Add cron setup in `do_install()` for non-systemd path
- [x] Add cron cleanup in `do_uninstall()` for non-systemd path

## Success Criteria

- `urnet-tools auto-start on` adds `@reboot` cron entry
- `urnet-tools auto-start off` removes cron entry
- `urnet-tools auto-update on --interval=weekly` sets weekly cron
- `urnet-tools auto-update off` removes cron entry
- `urnet-tools auto-update` (no args) shows current state
- Install adds both cron entries; uninstall removes them
- Cron entries don't duplicate on reinstall

## Risk Assessment

- **Cron not installed:** Extremely unlikely in any standard Linux distro, but could add a `command -v crontab` check
- **Cron entry duplication:** Handled by removing old marker before adding new one
- **Time zone:** Cron runs in system timezone; acceptable for update scheduling
