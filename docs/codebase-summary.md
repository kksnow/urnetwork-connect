# Codebase Summary

Generated from repomix compaction. This document provides an overview of the URnetwork Connect codebase structure and key files.

---

## Repository Statistics

| Metric | Value |
|--------|-------|
| Total Files | 118 files |
| Total Tokens | ~1.69M tokens |
| Language | Go 1.24.4 |
| License | MPL 2.0 |

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

## Core Library Files

### Transport Layer (~60KB combined)

| File | Size | Purpose |
|------|------|---------|
| `transport.go` | 32KB | Main transport implementation, mode selection |
| `transport_p2p.go` | 9.5KB | P2P connection handling |
| `transport_pt.go` | 19KB | Packet translation modes |
| `transport_pt_codec.go` | 7.3KB | Packet translation codec |
| `transport_pt_queue.go` | 8.0KB | Packet translation queue |
| `transport_test.go` | 685B | Transport tests |

**Key Types:**
- `TransportMode` - enum for transport modes (H1, H3, H3Dns, H3DnsPump, Auto)
- `ClientAuth` - client authentication structure
- `PlatformTransportSettings` - transport configuration

### Transfer Layer (~110KB combined)

| File | Size | Purpose |
|------|------|---------|
| `transfer.go` | 109KB | Core transfer implementation, reliable delivery |
| `transfer_contract_manager.go` | 31KB | Contract management for multi-hop |
| `transfer_control.go` | 4.4KB | Transfer control signals |
| `transfer_oob_control.go` | 2.9KB | Out-of-band control |
| `transfer_queue.go` | 6.9KB | Frame queuing |
| `transfer_route_manager.go` | 31KB | Route management |
| `transfer_rtt.go` | 4.7KB | RTT calculations |
| `transfer_stream_manager.go` | 11KB | Stream management |

**Key Types:**
- `TransferPath` - source/destination/stream identification
- `AckFunction` - acknowledgment callback type
- `ReceiveFunction` - frame receive callback
- `ForwardFunction` - frame forward callback

### IP Layer (UNAT) (~180KB combined)

| File | Size | Purpose |
|------|------|---------|
| `ip.go` | 79KB | User-space NAT implementation |
| `ip_packet.go` | 5.7KB | Packet handling utilities |
| `ip_remote_multi_client.go` | 93KB | Multi-client IP handling |
| `ip_remote_multi_client_api.go` | 6.9KB | IP client API |
| `ip_remote_multi_client_monitor.go` | 8.3KB | Client monitoring |
| `ip_security.go` | 2.5MB | Security policies, blocklists |

**Key Types:**
- `UserNatClient` - user-space NAT interface
- `SendPacketFunction` - packet send callback
- `ReceivePacketFunction` - packet receive callback

### Network Layer (~60KB combined)

| File | Size | Purpose |
|------|------|---------|
| `net.go` | 2.7KB | Network utilities |
| `net_http.go` | 35KB | HTTP strategies |
| `net_http_doh.go` | 12KB | DNS-over-HTTPS implementation |
| `net_http_doh_regional.go` | 1.9KB | Regional DoH profiles |
| `net_resilient.go` | 13KB | Resilient connection handling |
| `net_tls.go` | 713B | TLS configuration |
| `net_util.go` | 1.5KB | Network utilities |
| `net_extender.go` | 7.5KB | Extender support |
| `net_extender_profiles.go` | 2.6KB | Extender profiles |

### Message Layer (~20KB combined)

| File | Size | Purpose |
|------|------|---------|
| `message_pool.go` | 12KB | Zero-copy message pooling |
| `message_framer.go` | 4.7KB | Frame serialization |

**Key Patterns:**
- Ownership-based pooling
- Reference counting for shared messages
- Automatic garbage collection fallback

### Core Types

| File | Size | Purpose |
|------|------|---------|
| `connect.go` | 11KB | Core types, TransferPath, Id |
| `frame.go` | 5.2KB | Frame handling |
| `api.go` | 11KB | API client |
| `jwt.go` | 989B | JWT utilities |
| `log.go` | 958B | Logging configuration |
| `trace.go` | 3.5KB | Tracing utilities |
| `util.go` | 7.9KB | General utilities |
| `wakeup_schedule.go` | 631B | Wakeup scheduling |

---

## Protocol Definitions

| Proto File | Purpose |
|------------|---------|
| `frame.proto` | Message routing layer, MessageType enum |
| `transfer.proto` | Core P2P transfer: contracts, streaming, reliability |
| `ip.proto` | Raw IP packet tunneling |
| `audit.proto` | Privacy-preserving abuse audit system |
| `extender.proto` | Authentication header for proxy connections |

### Message Types (frame.proto)

```protobuf
enum MessageType {
    TransferPack = 0;
    TransferAck = 1;
    TransferContract = 2;
    TransferProvide = 3;
    TransferAuth = 4;
    TransferCreateStream = 5;
    // ... more types
}
```

---

## CLI Tools

### connectctl/
Admin/testing CLI for BringYour API interactions.

**Commands:**
- `create-network` - Create a new network
- `verify-send` - Send verification
- `login-network` - Login to network
- `send` - Send test messages
- `sink` - Receive test messages

### provider/
Background daemon for providing network bandwidth.

**Commands:**
- `auth` - Authenticate with auth code
- `provide` - Start providing
- `auth-provide` - Authenticate and provide
- `proxy add/remove` - Manage proxies

**Config Locations:**
- `~/.urnetwork/jwt` - Authentication token
- `~/.urnetwork/proxy` - Proxy configuration

---

## API Definition

**File:** `api/bringyour.yml`
**Format:** OpenAPI 3.1.0
**Base URL:** `https://api.bringyour.com`

### Endpoint Categories

| Category | Endpoints |
|----------|-----------|
| `/auth/*` | Login, verify, password reset, network create |
| `/network/*` | Client auth, provider discovery, locations |
| `/wallet/*` | USDC balance, Circle wallet |
| `/subscription/*` | Balance codes, payment IDs |
| `/device/*` | Device adoption, share codes |
| `/stats/*` | Network stats, leaderboard |

---

## Installation Scripts

| Platform | Script | Features |
|----------|--------|----------|
| Linux | `Provider_Install_Linux.sh` | systemd + cron (LXC), auto-update |
| Windows | `Provider_Install_Win32.ps1` | BITS transfer, startup shortcut |
| Management | `urnet-tools.ps1` | start/stop/status/update |

### Linux Management Commands

```bash
urnet-tools start          # Start provider
urnet-tools stop           # Stop provider
urnet-tools status         # Show status
urnet-tools update         # Update to latest
urnet-tools reinstall      # Reinstall
urnet-tools uninstall      # Remove
urnet-tools auto-start on|off   # Enable/disable auto-start
urnet-tools auto-update on|off  # Enable/disable auto-update
```

---

## Key Dependencies

```go
import (
    "github.com/gorilla/websocket"  // WebSocket
    quic "github.com/quic-go/quic-go"  // QUIC/HTTP3
    "github.com/google/gopacket"    // Packet parsing
    gojwt "github.com/golang-jwt/jwt/v5"  // JWT
    "google.golang.org/protobuf/proto"  // Protobuf
    "github.com/urnetwork/glog"     // Logging
)
```

---

## Test Files

| File | Purpose |
|------|---------|
| `connect_test.go` | Core connection tests |
| `ip_test.go` | IP layer tests |
| `ip_remote_multi_client_test.go` | Multi-client tests |
| `message_framer_test.go` | Framer tests |
| `message_pool_test.go` | Pool tests |
| `net_http_doh_test.go` | DoH tests |
| `net_util_test.go` | Network util tests |
| `transfer_control_test.go` | Control tests |
| `transfer_contract_manager_test.go` | Contract tests |
| `transfer_route_manager_test.go` | Route tests |
| `transfer_rtt_test.go` | RTT tests |
| `transfer_test.go` | Transfer tests |
| `transport_pt_codec_test.go` | Codec tests |
| `transport_pt_queue_test.go` | Queue tests |
| `transport_pt_test.go` | Packet translation tests |
| `util_test.go` | Utility tests |
| `wakeup_schedule_test.go` | Schedule tests |

---

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md)
- [System Architecture](./system-architecture.md)
- [Code Standards](./code-standards.md)
