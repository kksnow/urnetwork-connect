# Deployment Guide

This guide covers installation, configuration, and management of URnetwork Connect components.

---

## Prerequisites

### Linux
- Go 1.24.4+ (for building from source)
- `curl` or `wget`
- `bash`
- `python3` or `jq` (for JSON parsing)

### Windows
- PowerShell 5.1+
- Administrator privileges

---

## Linux Installation

### Quick Install (Recommended)

**Using curl:**
```bash
curl -fsSL https://raw.githubusercontent.com/kksnow/urnetwork-connect/main/scripts/Provider_Install_Linux.sh -o /tmp/urnetwork-install.sh && sh /tmp/urnetwork-install.sh
```

**Using wget:**
```bash
wget -qO /tmp/urnetwork-install.sh https://raw.githubusercontent.com/kksnow/urnetwork-connect/main/scripts/Provider_Install_Linux.sh && sh /tmp/urnetwork-install.sh
```

### Alpine Linux

**Install prerequisites:**
```bash
apk add curl bash python3
```

Then run the quick install command above.

### Installation Options

| Flag | Description | Example |
|------|-------------|---------|
| `-t=VERSION` | Install specific version | `sh -s -- -t=v1.2.0` |
| `-B` | Skip bashrc modification | `sh -s -- -B` |
| `-i PATH` | Custom install path | `sh -s -- -i /opt/urnetwork` |

### Post-Installation

```bash
# Reload PATH
source ~/.bashrc

# Authenticate (get code from https://ur.io)
urnetwork auth

# Start provider
urnet-tools start

# Check status
urnet-tools status
```

---

## Proxmox LXC Installation

LXC containers typically don't use systemd. The installation script auto-detects and configures cron-based management.

**Features:**
- Auto-start via cron @reboot
- Auto-update via cron job
- No systemd dependency

**Management:**
```bash
# Auto-start control
urnet-tools auto-start on
urnet-tools auto-start off

# Auto-update control
urnet-tools auto-update on
urnet-tools auto-update off
```

---

## Windows Installation

### PowerShell (Administrator)

```powershell
# Download and run installer
.\Provider_Install_Win32.ps1
```

**Features:**
- BITS transfer for reliable downloads
- Startup shortcut creation
- Automatic updates

---

## Management Commands

### urnet-tools (Linux)

| Command | Description |
|---------|-------------|
| `urnet-tools start` | Start provider |
| `urnet-tools stop` | Stop provider |
| `urnet-tools status` | Show status |
| `urnet-tools update` | Update to latest version |
| `urnet-tools reinstall` | Reinstall |
| `urnet-tools uninstall` | Remove installation |
| `urnet-tools auto-start on\|off` | Enable/disable auto-start |
| `urnet-tools auto-update on\|off` | Enable/disable auto-update |

### urnet-tools.ps1 (Windows)

Similar commands available in PowerShell version.

---

## Provider Authentication

### Interactive Auth

```bash
urnetwork auth
```

This will prompt for an auth code obtained from https://ur.io.

### Non-Interactive Auth

```bash
urnetwork auth <auth_code>
```

### With User Credentials

```bash
provider auth --user_auth=<email> --password=<password>
```

---

## Proxy Batch Markdown Export (`scripts/urnet-proxy.sh`)

Use this helper when you need a batch export of HTTPS proxy credentials in Markdown format.

### Auth Sources

`scripts/urnet-proxy.sh` will use the first available auth source:
- JWT provided via environment
- `~/.urnetwork_jwt`
- `AUTH_CODE` or `auth_code` (for automatic code login)

### Batch Command

```bash
# Option 1: explicit args
./scripts/urnet-proxy.sh batch-md 100 us us-https-proxies.md

# Option 2: defaults from .env
./scripts/urnet-proxy.sh batch-md
```

### Batch Hardening Behavior

| Behavior | Contract |
|---------|----------|
| Input validation | `count` must be a positive integer |
| Capacity guard | Fails early if requested count exceeds available client slots (max 128) |
| Retry policy | Retries transient API failures (`429`/`5xx`) and curl transient failures with backoff |
| Retry config | Max attempts are bounded (default: `4`) |
| Output hardening | Rejects symlink output paths and writes output with mode `600` |
| Failure mode | Exits non-zero on mid-run failure and keeps partial output file |

### Security Notes

- Exported Markdown includes live auth tokens.
- Keep export files out of git and handle as secrets.

---

## Configuration

### File Locations

| File | Purpose |
|------|---------|
| `~/.urnetwork/jwt` | Authentication token |
| `~/.urnetwork/proxy` | Proxy configuration |

### Provider Options

```bash
provider provide \
  --port=<port> \
  --api_url=<api_url> \
  --connect_url=<connect_url> \
  --max-memory=<mem> \
  -v...
```

### Default URLs

| Service | URL |
|---------|-----|
| API | `https://api.bringyour.com` |
| Connect | `wss://connect.bringyour.com` |

---

## Docker Deployment

### Using Dockerfile

```bash
# Build image
cd provider/
docker build -t urnetwork-provider .

# Run container
docker run -d \
  -v ~/.urnetwork:/root/.urnetwork \
  --name provider \
  urnetwork-provider
```

### Docker Compose

```yaml
version: '3'
services:
  provider:
    build: ./provider
    volumes:
      - ~/.urnetwork:/root/.urnetwork
    restart: unless-stopped
```

---

## Extender Deployment

Extenders act as TLS proxy relays to help clients in restricted regions.

### Setup

1. Deploy extender server (`extender/`)
2. Configure to forward to `connect.bringyour.com:8443`
3. Add proxy protocol headers
4. Whitelist extender IP on platform

### Configuration

Extenders append proxy protocol headers for IP identification:

```
PROXY TCP4 <client_ip> <extender_ip> <client_port> <extender_port>
```

---

## Troubleshooting

### Common Issues

#### Authentication Fails

```bash
# Check JWT file
cat ~/.urnetwork/jwt

# Re-authenticate
urnetwork auth
```

#### Connection Issues

```bash
# Check status
urnet-tools status

# View logs
journalctl -u urnetwork -f  # systemd
cat /tmp/urnetwork.log      # cron-based
```

#### Provider Not Starting

```bash
# Check if already running
ps aux | grep provider

# Kill stale processes
pkill -f provider

# Restart
urnet-tools stop
urnet-tools start
```

#### Memory Issues

```bash
# Set memory limit
provider provide --max-memory=512M
```

### Log Locations

| Platform | Log Location |
|----------|--------------|
| systemd | `journalctl -u urnetwork` |
| cron | `/tmp/urnetwork.log` |
| Windows | Event Log |

### Debug Mode

```bash
# Enable verbose logging
provider provide -vvv
```

---

## Uninstallation

### Linux

```bash
urnet-tools uninstall
```

Or run the uninstall script:
```bash
sh Provider_Uninstall_Linux.sh
```

### Windows

```powershell
.\Provider_Uninstall_Win32.ps1
```

---

## Security Considerations

### Network Security

- All connections use TLS 1.3
- JWT tokens stored in `~/.urnetwork/jwt`
- Provider IP whitelisting via extenders

### File Permissions

```bash
# Secure JWT file
chmod 600 ~/.urnetwork/jwt
```

### Firewall Configuration

Ensure outbound access to:
- `api.bringyour.com:443`
- `connect.bringyour.com:443`
- `connect.bringyour.com:8443` (extender port)

---

## Performance Tuning

### Memory Settings

```bash
# Limit memory usage
provider provide --max-memory=1G
```

### Connection Settings

```bash
# Custom port
provider provide --port=8080
```

### Buffer Sizes

Default buffer sizes are optimized for most use cases. For high-throughput scenarios, consider increasing:

| Setting | Default | Description |
|---------|---------|-------------|
| `SendBufferSize` | 16 | Frame send buffer |
| `ForwardBufferSize` | 16 | Frame forward buffer |
| `ReadTimeout` | 30s | Read timeout |

---

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md)
- [System Architecture](./system-architecture.md)
- [Codebase Summary](./codebase-summary.md)
- [Project Roadmap](./project-roadmap.md)
