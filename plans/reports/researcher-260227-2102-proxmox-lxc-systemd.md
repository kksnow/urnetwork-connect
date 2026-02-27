# Proxmox LXC & systemd Research Report

**Date:** 2026-02-27
**Focus:** systemd functionality in Proxmox LXC containers, alternatives, best practices, and detection methods

---

## 1. Proxmox LXC & systemd: Core Limitations

### Why systemd Fails in Most LXC Containers

systemd requires several host-level features that unprivileged LXC containers lack:

**Critical Requirements:**
- **cgroup v2 delegation**: systemd needs write access to cgroup controllers. Unprivileged containers receive delegated cgroups but with restrictions
- **dbus**: systemd relies on systemd-logind and user dbus sessions; access requires user namespacing permissions
- **/sys/fs/cgroup writable access**: systemd must create and manage cgroup hierarchies
- **CAP_SYS_ADMIN**: Full system administration capability; unprivileged containers drop this
- **systemd version 231+**: Critical for cgroup v2 support on modern kernels

**Real Impact:**
- Services don't auto-respawn on failure
- User timers and services fail (`--user` mode systemd-run, `enable-linger`)
- Device access restrictions
- Journal integration incomplete
- socket/timer units often non-functional

### Privileged vs Unprivileged Containers

| Feature | Privileged | Unprivileged |
|---------|-----------|--------------|
| systemd **guaranteed work** | Yes, with proper config | No, requires special setup |
| UID mapping | Direct root | Mapped (0→unprivileged UID) |
| Security model | AppArmor + seccomp | Full kernel namespacing |
| Risk profile | Higher (LXC team: unsafe for untrusted) | Lower (security isolated to mapped user) |
| cgroup delegation | Full access | Restricted subset |
| dbus access | Possible | Limited |

**Proxmox Default:** Unprivileged containers (recommended for security)

### When systemd Works

**Works Reliably:**
1. **Privileged containers** with proper AppArmor/seccomp rules
2. **Unprivileged containers with nesting enabled** (`lxc.nesting = true` in LXC config)
   - Enables nested container support
   - Delegates additional cgroup controllers
   - Still restricted compared to privileged mode
   - Performance penalty

**Partially Works:**
- System-level services (not user services)
- Basic service management if cgroup v2 available
- Requires systemd 231+ on host and container

**Doesn't Work:**
- `loginctl enable-linger` (user session management)
- User-level systemd services/timers
- Full dbus integration
- Device cgroup management

---

## 2. Alternative Init Systems for LXC Containers

### Overview: Practical Alternatives

1. **OpenRC** (Alpine Linux standard)
   - Lightweight, script-based
   - No daemon process overhead
   - Works in unprivileged containers
   - Simple service dependencies
   - Used by: Alpine, Devuan, Artix Linux
   - **Best for:** Minimal containers, edge systems

2. **sysvinit** (Traditional SysV init)
   - Well-established, rock-solid
   - Pure shell scripts in `/etc/init.d`
   - No complexity overhead
   - Limited by lack of parallel startup
   - Used by: Debian (legacy support), CentOS 6
   - **Best for:** Legacy systems, maximum compatibility

3. **runit** (Supervision-based)
   - Minimal init, relies on service supervision
   - Fast startup, reliable service restarts
   - No complex dependency tracking
   - Simple directory-based config: `/service` structure
   - Used by: Void Linux, some Debian systems
   - **Best for:** Embedded, minimal deployments

4. **s6** (Supervision suite)
   - Ultra-minimal, pure supervision
   - Modular, can run in containers
   - Steep learning curve
   - Used by: Specialized systems, embedded Linux
   - **Best for:** Extreme minimalism, custom deployments

5. **supervisord** (Process management)
   - Python-based daemon supervisor
   - Web UI optional, conf-file driven
   - Restarts failed processes
   - Independent of init system
   - Used by: Docker, application containers
   - **Best for:** Multi-process application containers

6. **Entrypoint scripts** (Container-style)
   - Simple shell script as PID 1
   - No persistent init daemon
   - Manages foreground process
   - Used by: Docker, most OCI containers
   - **Best for:** Single-purpose containers

7. **Cron-based** (Minimal supervision)
   - Use system cron for periodic service restarts
   - Shell scripts run checks
   - No init system overhead
   - Used by: Embedded systems, custom setups
   - **Best for:** Very lightweight containers

### Feature Comparison

| Init | Process Restart | Dependencies | Overhead | LXC Compatible |
|-----|-----------------|--------------|----------|----------------|
| systemd | Yes (auto) | Complex | High | No (unprivileged) |
| OpenRC | Manual | Simple | Low | Yes |
| sysvinit | Manual | Simple | Very low | Yes |
| runit | Yes (supervision) | Manual | Low | Yes |
| s6 | Yes (supervision) | Manual | Very low | Yes |
| supervisord | Yes (auto) | Conf file | Low-Med | Yes |
| Entrypoint | Manual | None | None | Yes |
| Cron | Manual | None | Low | Yes |

---

## 3. Common Patterns for Running Services Without systemd

### Pattern A: OpenRC (Alpine-style)

**Typical structure:**
```bash
# /etc/init.d/myservice
#!/sbin/openrc-run
command="/usr/local/bin/myapp"
command_args="--daemon"
start() {
    ebegin "Starting myservice"
    start-stop-daemon --start --pidfile /var/run/myapp.pid \
        --exec $command -- $command_args
    eend $?
}
```

**Start services:**
```bash
/etc/init.d/myservice start
# Or enable for boot:
rc-update add myservice default
rc-service myservice start
```

**Adoption:** Alpine Linux, Devuan, Artix

---

### Pattern B: runit Supervision

**Service directory structure:**
```
/service/myservice/
├── run              # Main service script
├── log/
│   └── run          # Logging script
└── down             # (optional) prevents autostart
```

**Example `/service/myservice/run`:**
```bash
#!/bin/sh
exec 2>&1
exec chpst -u myuser:mygroup /usr/local/bin/myapp --foreground
```

**Usage:**
```bash
sv start myservice
sv status myservice
sv restart myservice
```

**Adoption:** Void Linux, artix

---

### Pattern C: Entrypoint Script (Docker-style)

**Simple container entrypoint:**
```bash
#!/bin/sh
set -e

# Trap signals
trap 'kill $CHILD_PID' TERM INT

# Start services in background
/usr/local/bin/service1 &
CHILD_PID=$!

/usr/local/bin/service2 --daemon &
CHILD_PID2=$!

# Wait for PID 1 process
wait $CHILD_PID
```

**LXC usage:**
```bash
# Container config
lxc.init.cmd = /entrypoint.sh
```

**Adoption:** Docker, Podman, OCI containers, increasingly LXC

---

### Pattern D: supervisord

**Config file `/etc/supervisor/conf.d/myservice.conf`:**
```ini
[program:myservice]
command=/usr/local/bin/myapp --foreground
user=myuser
autostart=true
autorestart=true
startsecs=10
stdout_logfile=/var/log/myservice.log
```

**Control:**
```bash
supervisorctl status myservice
supervisorctl restart myservice
```

**Adoption:** Docker containers, Python apps, multi-process containers

---

### Pattern E: Simple Shell Loop (Extreme Minimal)

```bash
#!/bin/sh
# Ultra-minimal, restarts service on crash
while true; do
    /usr/local/bin/myapp
    sleep 1  # Avoid tight loop
done
```

**Adoption:** Embedded systems, custom CI/CD containers

---

### Pattern F: sysvinit Standard

**Traditional `/etc/init.d/myservice`:**
```bash
#!/bin/bash
### BEGIN INIT INFO
# Provides: myservice
# Required-Start: $network
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:
# Description: My Application
### END INIT INFO

case "$1" in
  start)
    /usr/local/bin/myapp &
    ;;
  stop)
    pkill -f myapp
    ;;
  restart)
    $0 stop
    $0 start
    ;;
esac
```

**Enable boot start:**
```bash
update-rc.d myservice defaults
service myservice start
```

**Adoption:** Debian, CentOS 6-7, legacy systems

---

## 4. `loginctl enable-linger` in LXC

### Does It Work?

**Short answer: No, not reliably in unprivileged LXC containers.**

### Why It Fails

`enable-linger` creates persistent user sessions managed by systemd-logind, which requires:
- dbus access to org.freedesktop.login1
- systemd-logind running with full capabilities
- cgroup delegation for user session tracking
- User namespacing compatibility

**In unprivileged LXC:**
- dbus connection fails (permission denied)
- systemd-logind can't manage user sessions (lacks CAP_SYS_ADMIN)
- Linger state doesn't persist across reboot

### What This Breaks

- User-level systemd services won't persist after logout
- User timers (`systemctl --user timer start`) don't survive session end
- SSH login/logout lifecycle doesn't trigger service management

### Alternatives

**Option 1: Use privileged container** (if security acceptable)
```bash
lxc.privileged = 1
# Then enable-linger works
```

**Option 2: Direct crontab for persistence**
```bash
# Instead of: systemctl --user enable myservice
# Use crontab to start on boot:
@reboot /home/user/.local/bin/myservice
```

**Option 3: System-level service with --user override**
```bash
# Create system service that invokes user command:
/etc/systemd/system/user-myservice.service
[Service]
User=myuser
ExecStart=/home/myuser/.local/bin/myservice
```

**Option 4: Supervisord with user process**
```ini
[program:myservice]
command=/home/myuser/.local/bin/myservice
user=myuser
autostart=true
```

**Option 5: OpenRC + su for user services**
```bash
# /etc/init.d/user-myservice
#!/sbin/openrc-run
start() {
    su - myuser -c '/home/myuser/.local/bin/myservice &'
}
```

---

## 5. Detecting LXC Container Environment

### Reliable Detection Methods

**Method 1: Check `/proc/1/cgroup` for container markers**
```bash
if grep -q "lxc" /proc/1/cgroup; then
    echo "Running in LXC container"
fi
```
**Reliability:** Good. Works in both privileged and unprivileged.

---

**Method 2: Check for LXC-specific files**
```bash
if [ -f /proc/sys/kernel/osrelease ] && grep -q "lxc" /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "LXC detected"
fi
```
**Reliability:** Medium. May not work in all cases.

---

**Method 3: Check for cgroup v2 delegation (LXC-specific)**
```bash
if [ -r /proc/self/cgroup ] && grep -q "0::/" /proc/self/cgroup; then
    if [ ! -w "/sys/fs/cgroup" ]; then
        echo "Unprivileged container detected"
    fi
fi
```
**Reliability:** Good for unprivileged LXC detection.

---

**Method 4: Check environment variables (LXC-set)**
```bash
if [ ! -z "$LXC_CONTAINER_ID" ] || [ ! -z "$LXC_NAME" ]; then
    echo "LXC container detected"
fi
```
**Reliability:** Medium. Only if container runtime sets these.

---

**Method 5: Comprehensive detection (most reliable)**
```bash
detect_lxc() {
    # Check multiple markers
    if grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    if [ -f "/.dockerenv" ]; then
        # Not LXC, Docker
        return 1
    fi
    if grep -qE "^0::" /proc/self/cgroup 2>/dev/null; then
        # Unprivileged, likely LXC
        return 0
    fi
    return 1
}

if detect_lxc; then
    echo "LXC detected"
fi
```
**Reliability:** Excellent. Tests multiple markers.

---

**Method 6: Check for LXC-specific sysctl**
```bash
if sysctl kernel.nesting 2>/dev/null | grep -q "1"; then
    echo "LXC nesting enabled (likely nested LXC or privileged)"
fi
```
**Reliability:** Medium. Only indicates nesting state.

---

**Method 7: Test systemd capabilities (indirect detection)**
```bash
if ! systemctl is-system-running &>/dev/null; then
    echo "systemd not fully functional (likely unprivileged LXC)"
fi
```
**Reliability:** Low. Other environments also fail this test.

---

### Best Comprehensive Script

```bash
#!/bin/bash
# Detects LXC container type

detect_container_type() {
    # Check for Docker first
    if [ -f "/.dockerenv" ]; then
        echo "docker"
        return
    fi

    # Check for LXC markers
    if grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        # Determine privileged vs unprivileged
        if grep -q "0::" /proc/self/cgroup 2>/dev/null; then
            echo "lxc-unprivileged"
        else
            echo "lxc-privileged"
        fi
        return
    fi

    # Check for cgroup v2 unprivileged (generic check)
    if grep -qE "^0::" /proc/self/cgroup 2>/dev/null; then
        echo "container-unprivileged"
        return
    fi

    # Check environment
    if [ ! -z "$LXC_CONTAINER_ID" ]; then
        echo "lxc"
        return
    fi

    echo "host"
}

CONTAINER_TYPE=$(detect_container_type)
echo "Container type: $CONTAINER_TYPE"

case "$CONTAINER_TYPE" in
    lxc-unprivileged|container-unprivileged)
        echo "Use OpenRC, runit, or supervisord for service management"
        ;;
    lxc-privileged)
        echo "systemd should work; fallback to OpenRC if not"
        ;;
    docker)
        echo "Use entrypoint script pattern"
        ;;
    host)
        echo "systemd available on bare metal"
        ;;
esac
```

---

## 6. Proxmox LXC Best Practices for Background Services

### Recommended Approach by Use Case

**Case 1: Full System Container (legacy apps)**
- **Recommendation:** Privileged LXC container + systemd
- **Config:**
  ```
  lxc.privileged = 1
  lxc.apparmor.profile = unconfined
  ```
- **Trade-off:** Higher security risk, full compatibility
- **When:** Trustworthy applications, internal infrastructure

---

**Case 2: Unprivileged System Container (best security)**
- **Recommendation:** OpenRC init system
- **Setup:**
  ```bash
  # In container:
  apt-get install openrc
  # Replace systemd as PID 1
  ```
- **Config:**
  ```
  lxc.init.cmd = /sbin/openrc
  lxc.init.cwd = /
  ```
- **Services:** Use `/etc/init.d/*` scripts
- **When:** Security critical, standard workloads

---

**Case 3: Application Container (single/few services)**
- **Recommendation:** Entrypoint script + supervisord
- **Structure:**
  ```
  /entrypoint.sh              # Main init
  /etc/supervisor/conf.d/*    # Service configs
  ```
- **Config:**
  ```
  lxc.init.cmd = /entrypoint.sh
  ```
- **When:** Microservices, web apps, limited services

---

**Case 4: Minimal Container (Alpine base)**
- **Recommendation:** OpenRC (built-in on Alpine)
- **Advantage:** Alpine is ~5MB, OpenRC included
- **Services:** Use rc-service commands
- **When:** Resource constrained, edge deployments

---

**Case 5: Nested LXC (containers in containers)**
- **Requirement:** Enable nesting in parent container
  ```
  lxc.nesting = true
  lxc.apparmor.profile = unconfined
  lxc.cap.drop =
  lxc.cap.keep = sys_admin
  ```
- **Init:** systemd works better here (cgroup delegation)
- **Trade-off:** Significant performance penalty
- **When:** Testing, development environments

---

### Configuration Examples

**Privileged Container with systemd (Debian):**
```
# /etc/pve/lxc/100.conf (Proxmox format)
arch: amd64
cores: 2
hostname: privileged-app
memory: 1024
ostype: debian
privileged: 1
rootfs: local:100/vm-100-disk-0.raw
swap: 512
```

---

**Unprivileged Container with OpenRC (Alpine):**
```
# /etc/pve/lxc/101.conf
arch: amd64
cores: 2
hostname: alpine-app
memory: 512
ostype: alpine
unprivileged: 1
rootfs: local:101/vm-101-disk-0.raw
lxc.init.cmd: /sbin/openrc
lxc.init.cwd: /
```

---

**Container with Custom Entrypoint:**
```
# /etc/pve/lxc/102.conf
arch: amd64
cores: 2
hostname: app-container
memory: 768
ostype: debian
unprivileged: 1
rootfs: local:102/vm-102-disk-0.raw
lxc.init.cmd: /entrypoint.sh
lxc.init.cwd: /
```

---

### Service Management Commands by Init System

**systemd (privileged/working):**
```bash
systemctl start myservice
systemctl enable myservice
systemctl status myservice
```

**OpenRC:**
```bash
rc-service myservice start
rc-update add myservice default
rc-service myservice status
```

**runit:**
```bash
sv start myservice
sv enable myservice
sv status myservice
```

**supervisord:**
```bash
supervisorctl start myservice
supervisorctl restart myservice
supervisorctl status myservice
```

---

### Proxmox-Specific Optimization

**Resource limits (cgroup configuration):**
```
# /etc/pve/lxc/100.conf
cores: 4
memory: 2048
swap: 1024
```

**Network optimization for services:**
```
net0: name=eth0,bridge=vmbr0,hwaddr=XX:XX:XX:XX:XX:XX
```

**Storage for logs:**
```
mp0: /var/log,mp=/data/logs
```

**Important:** Use `lxc.apparmor.profile = unconfined` with caution; only in trusted environments.

---

## Unresolved Questions / Further Investigation Needed

1. **Exact cgroup v2 delegation behavior**: How precisely does cgroup delegation differ between privileged/unprivileged/nested LXC? (Requires kernel-level trace)

2. **dbus availability**: Can user-level dbus socket be accessed in unprivileged containers via workarounds?

3. **Performance penalty quantification**: What's the actual overhead of enabling nesting? (Benchmark-dependent)

4. **Modern Proxmox best practices (v8+)**: Have recent Proxmox versions improved systemd support in unprivileged containers?

5. **Alternative init performance**: Head-to-head benchmark: systemd vs OpenRC vs runit startup times in LXC

6. **Kubernetes/containerd compatibility**: How do these patterns interact with Kubernetes nodes running on Proxmox LXC?

---

## Summary & Recommendations

| Scenario | Best Init | Reasoning |
|----------|-----------|-----------|
| **Legacy system app** | systemd (privileged) | Full compatibility, known patterns |
| **Security critical** | OpenRC (unprivileged) | Best isolation, reliable |
| **Microservices** | Supervisord (unprivileged) | Purpose-built for process mgmt |
| **Minimal/embedded** | runit or s6 (unprivileged) | Low overhead |
| **Alpine container** | OpenRC (unprivileged) | Native, included by default |
| **Testing/dev** | Entrypoint script (any) | Simplest, flexible |

**Key takeaway:** systemd in unprivileged LXC is fundamentally limited by kernel isolation. Choose alternatives based on your specific workload requirements rather than forcing systemd compatibility.

---

## Sources

- [Proxmox VE LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [LXC Official Documentation](https://linuxcontainers.org/lxc/documentation/)
- Alpine Linux OpenRC: https://wiki.alpinelinux.org/wiki/OpenRC
- runit: http://smarden.org/runit/
- s6 supervision suite: https://skarnet.org/software/s6/
