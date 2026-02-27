# URnetwork Connect

A web-standards VPN marketplace with an emphasis on fast, secure internet everywhere. This project creates a trusted best-in-class technology for the "public VPN" market that:

- Works on consumer devices from the normal app stores
- Allows consumer devices to tap into existing resources to enhance the public VPN
- Emphasizes privacy, security, and availability

---

## Features

- **Multi-Route Transport** - Automatic selection between HTTP/1.1, HTTP/3, DNS tunneling
- **User-Space NAT (UNAT)** - Emulates raw sockets without requiring root
- **Contract-Based Transfer** - Reliable multi-hop delivery with accounting
- **Zero-Copy Pooling** - Efficient memory management
- **Censorship Resistance** - DNS-over-HTTPS, TLS fragmentation, extender relays

---

## Quick Start

### Linux / Proxmox LXC / Alpine Linux

**Prerequisites (Alpine):**
```sh
apk add curl bash python3
```

**Install:**
```sh
curl -fsSL https://raw.githubusercontent.com/kksnow/urnetwork-connect/main/scripts/Provider_Install_Linux.sh -o /tmp/urnetwork-install.sh && sh /tmp/urnetwork-install.sh
```

**Post-install:**
```sh
source ~/.bashrc           # Reload PATH
urnetwork auth             # Authenticate (get code from https://ur.io)
urnet-tools start          # Start provider
urnet-tools status         # Check status
```

### Windows

Run the PowerShell installer as Administrator:
```powershell
.\Provider_Install_Win32.ps1
```

---

## Management Commands

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

---

## Installation Options

```sh
# Install specific version
... | sh -s -- -t=v1.2.0

# Skip bashrc modification
... | sh -s -- -B

# Custom install path
... | sh -s -- -i /opt/urnetwork
```

**Non-systemd environments (LXC/Alpine):** Auto-start and auto-update configured via cron.

---

## Architecture

### Core Components

| Layer | Files | Purpose |
|-------|-------|---------|
| Transport | `transport*.go` | Connection establishment, H1/H3, P2P |
| Transfer | `transfer*.go` | Reliable delivery, contracts, routing |
| IP (UNAT) | `ip*.go` | User-space NAT, security policies |
| Network | `net*.go` | HTTP strategies, DoH, resilient TLS |
| Protocol | `protocol/*.proto` | Protobuf wire protocol |

### Key Patterns

1. **Multi-Route Transport** - Multiple modes with automatic selection
2. **Contract-Based Transfer** - Sender-receiver contracts for multi-hop accounting
3. **User-Space NAT** - Emulates raw sockets using userspace TCP/UDP
4. **Zero-Copy Pooling** - Efficient memory with ownership semantics
5. **Censorship Resistance** - DNS tunneling, TLS fragmentation, DoH

---

## Protocol

- [Protocol definition](protocol) - Protobuf messages for the realtime transport protocol
- [API definition](api) - OpenAPI definition for the marketplace API

---

## Buffer Reuse

All `[]byte` allocations use pooled message buffers. Rules:

- **Ownership transfer** - Receiver must return bytes to pool when finished
- **Callback validity** - Bytes valid only during callback execution
- **Sharing** - Use `MessagePoolShareReadOnly` before passing to multiple consumers

---

## Development

### Prerequisites

- Go 1.24.4+
- protoc (for protocol buffer compilation)

### Building

```bash
go build ./...
```

### Testing

```bash
go test ./...
```

### Dependencies

| Dependency | Purpose |
|------------|---------|
| `quic-go` | QUIC protocol (HTTP/3) |
| `gorilla/websocket` | WebSocket connections |
| `gopacket` | Packet parsing |
| `golang-jwt/jwt` | JWT handling |
| `protobuf` | Protocol buffers |

---

## Documentation

| Document | Description |
|----------|-------------|
| [Project Overview & PDR](./docs/project-overview-pdr.md) | Requirements and goals |
| [Codebase Summary](./docs/codebase-summary.md) | File structure overview |
| [System Architecture](./docs/system-architecture.md) | Component diagrams |
| [Code Standards](./docs/code-standards.md) | Coding conventions |
| [Deployment Guide](./docs/deployment-guide.md) | Installation and management |
| [Project Roadmap](./docs/project-roadmap.md) | Development phases |

---

## CLI Tools

### connectctl

Admin/testing CLI for BringYour API:
- `create-network` - Create a new network
- `verify-send` - Send verification
- `login-network` - Login to network
- `send` / `sink` - Test messaging

### provider

Background daemon for providing bandwidth:
- `auth` - Authenticate with code
- `provide` - Start providing
- `auth-provide` - Authenticate and provide
- `proxy add/remove` - Manage proxies

---

## API

**Base URL:** `https://api.bringyour.com`

| Category | Endpoints |
|----------|-----------|
| `/auth/*` | Login, verify, password reset |
| `/network/*` | Client auth, provider discovery |
| `/wallet/*` | USDC balance, Circle wallet |
| `/subscription/*` | Balance codes, payments |
| `/device/*` | Device adoption, share codes |
| `/stats/*` | Network stats, leaderboard |

---

## Community

- **Discord:** [https://discord.gg/urnetwork](https://discord.gg/urnetwork)
- **Website:** [https://ur.io](https://ur.io)

---

## License

URnetwork is licensed under the [MPL 2.0](LICENSE).

---

![URnetwork](res/images/connect-project.webp "URnetwork")

**[URnetwork](https://ur.io): better internet**
