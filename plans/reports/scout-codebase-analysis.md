# Scout Report: URnetwork Connect Codebase

## Overview

**Project:** URnetwork Connect - Web-standards VPN marketplace
**Language:** Go 1.24.4
**License:** MPL 2.0
**Purpose:** Fast, secure internet everywhere through a trusted VPN marketplace

---

## Architecture Summary

### Core Components

| Component | Files | Purpose |
|-----------|-------|---------|
| Transport Layer | `transport*.go` | Connection establishment, H1/H3 upgrade, P2P, packet translation |
| Transfer Layer | `transfer*.go` | Reliable frame delivery, contracts, routing, queuing |
| IP Layer | `ip*.go` | User-space NAT (UNAT) with TCP/UDP handling, security policies |
| Network Layer | `net*.go` | HTTP strategies, DoH, resilient TLS, extender support |
| Protocol | `protocol/*.proto` | Protobuf definitions for wire protocol |
| CLI Tools | `connectctl/`, `provider/` | Admin CLI and provider daemon |

### Key Patterns

1. **Multi-Route Transport** - Multiple transport modes (H1, H3, H3Dns, H3DnsPump) with automatic selection
2. **Contract-Based Transfer** - Sender-receiver contracts for accounting across multi-hop paths
3. **User-Space NAT (UNAT)** - Emulates raw sockets using userspace TCP/UDP
4. **Zero-Copy Message Pooling** - Efficient memory management with ownership semantics
5. **Censorship Resistance** - DNS tunneling, TLS fragmentation, extender relays, DoH

---

## Directory Structure

```
/home/ubuntu/Dev/urnetwork-connect/
├── *.go                    # Core library (transport, transfer, IP, net, message)
├── api/                    # OpenAPI definition (bringyour.yml)
├── protocol/               # Protobuf definitions (*.proto, generated *.pb.go)
├── connectctl/             # CLI admin tool
├── provider/               # Provider daemon + Dockerfile
├── extender/               # TLS proxy server
├── scripts/                # Installation scripts (Linux/Windows)
├── security/               # IP blocklist generation
└── res/                    # Resources (images)
```

---

## Protocol Definitions

| Proto File | Purpose |
|------------|---------|
| `frame.proto` | Message routing layer, MessageType enum |
| `transfer.proto` | Core P2P transfer: contracts, streaming, reliability |
| `ip.proto` | Raw IP packet tunneling |
| `audit.proto` | Privacy-preserving abuse audit system |
| `extender.proto` | Authentication header for proxy connections |

---

## API Endpoints (OpenAPI 3.1.0)

**Base URL:** `https://api.bringyour.com`
**Auth:** Bearer JWT

| Category | Endpoints |
|----------|-----------|
| `/auth/*` | Login, verify, password reset, network create |
| `/network/*` | Client auth, provider discovery, locations |
| `/wallet/*` | USDC balance, Circle wallet |
| `/subscription/*` | Balance codes, payment IDs |
| `/device/*` | Device adoption, share codes |
| `/stats/*` | Network stats, leaderboard |

---

## CLI Tools

### connectctl
Admin/testing CLI for interacting with BringYour API and WebSocket connect service.
- Commands: create-network, verify-send, login-network, send, sink

### provider
Background daemon providing network bandwidth to the mesh.
- Commands: auth, provide, auth-provide, proxy add/remove
- Config: `~/.urnetwork/jwt`, `~/.urnetwork/proxy`

---

## Installation Scripts

| Platform | Script | Features |
|----------|--------|----------|
| Linux | `Provider_Install_Linux.sh` | systemd + cron (LXC/Proxmox), auto-update |
| Windows | `Provider_Install_Win32.ps1` | BITS transfer, startup shortcut |
| Management | `urnet-tools` | start/stop/status/update/uninstall |

---

## Key Dependencies

- `quic-go` - QUIC protocol (HTTP/3)
- `gorilla/websocket` - WebSocket
- `gopacket` - Packet parsing
- `golang-jwt/jwt` - JWT handling
- `google.golang.org/protobuf` - Protocol buffers

---

## Unresolved Questions

None - comprehensive scouting completed.
