# System Architecture

This document describes the architecture of URnetwork Connect, including layer interactions, data flow, and component relationships.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Application Layer                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Consumer   │  │   Provider   │  │      CLI Tools       │  │
│  │     App      │  │    Daemon    │  │  (connectctl, etc.)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                          IP Layer (UNAT)                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  User-space NAT - TCP/UDP handling, security policies    │  │
│  │  ip.go, ip_packet.go, ip_remote_multi_client.go          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Transfer Layer                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Reliable frame delivery, contracts, routing, queuing    │  │
│  │  transfer.go, transfer_contract_manager.go, etc.         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Transport Layer                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Connection establishment, H1/H3, P2P, packet translation│  │
│  │  transport.go, transport_p2p.go, transport_pt.go         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Network Layer                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  HTTP strategies, DoH, resilient TLS, extender support   │  │
│  │  net_http.go, net_http_doh.go, net_resilient.go          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer Details

### 1. Network Layer

**Purpose:** Handles low-level network connectivity with censorship resistance.

**Files:** `net*.go`

**Components:**

| Component | File | Purpose |
|-----------|------|---------|
| HTTP Client | `net_http.go` | HTTP/1.1 and HTTP/3 strategies |
| DNS-over-HTTPS | `net_http_doh.go` | Censorship-resistant DNS |
| Regional DoH | `net_http_doh_regional.go` | Region-specific DNS profiles |
| Resilient TLS | `net_resilient.go` | Connection recovery |
| Extender | `net_extender.go` | Proxy relay support |

**Transport Modes:**

```
TransportModeAuto      → Auto-select best mode
TransportModeH3DnsPump → HTTP/3 with DNS pumping
TransportModeH3Dns     → HTTP/3 with DNS tunneling
TransportModeH1        → HTTP/1.1 WebSocket
TransportModeH3        → HTTP/3 QUIC
```

---

### 2. Transport Layer

**Purpose:** Establishes and manages connections to the platform and peers.

**Files:** `transport*.go`

**Key Components:**

```
┌─────────────────────────────────────────────┐
│              Transport Manager               │
│  ┌─────────┐ ┌─────────┐ ┌──────────────┐  │
│  │   H1    │ │   H3    │ │  P2P/Extender│  │
│  │WebSocket│ │  QUIC   │ │    Relay     │  │
│  └─────────┘ └─────────┘ └──────────────┘  │
│                     │                       │
│                     ▼                       │
│           ┌─────────────────┐              │
│           │ Packet Translation │            │
│           │ (Optional)       │            │
│           └─────────────────┘              │
└─────────────────────────────────────────────┘
```

**Packet Translation Modes:**
- Optional UDP packet transformation
- Helps with DPI/filtering avoidance
- Codec and queue management

---

### 3. Transfer Layer

**Purpose:** Provides reliable frame delivery with accounting.

**Files:** `transfer*.go`

**Core Functions:**

| Function | Description |
|----------|-------------|
| Reliable Delivery | Frames delivered up to timeout |
| In-Order Reception | Frames received in send order |
| Acknowledgments | Sender notified on receipt |
| Contract Accounting | Multi-hop path accounting |
| Multi-Route Support | Multiple paths to destination |
| Key Verification | Pre-exchanged key validation |

**Contract System:**

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Sender    │────▶│ Intermediary│────▶│  Receiver   │
│  (Client)   │     │  (Relay)    │     │ (Provider)  │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      └───────────────────┴───────────────────┘
                   Shared Contract
              (Accounting for all hops)
```

**Stream Management:**

- `StreamId` replaces `SourceId`/`DestinationId` for multi-hop
- `StreamOpen`/`StreamClose` for state management
- Contract-based routing decisions

---

### 4. IP Layer (UNAT)

**Purpose:** User-space NAT for packet handling without raw sockets.

**Files:** `ip*.go`

**Components:**

```
┌─────────────────────────────────────────────┐
│            User-Space NAT (UNAT)             │
│  ┌───────────────┐  ┌───────────────────┐  │
│  │  TCP Handler  │  │   UDP Handler     │  │
│  │  (ip.go)      │  │   (ip.go)         │  │
│  └───────────────┘  └───────────────────┘  │
│                     │                       │
│  ┌─────────────────────────────────────┐   │
│  │         Security Policy              │   │
│  │  (ip_security.go - 2.5MB blocklist) │   │
│  └─────────────────────────────────────┘   │
│                     │                       │
│  ┌─────────────────────────────────────┐   │
│  │      Multi-Client Manager            │   │
│  │  (ip_remote_multi_client.go)        │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

**Key Features:**

- Emulates raw sockets using userspace TCP/UDP
- Security policy enforcement
- IP blocklist management
- Multi-client support

---

### 5. Message Layer

**Purpose:** Efficient memory management and frame serialization.

**Files:** `message_pool.go`, `message_framer.go`

**Message Pool Architecture:**

```
┌─────────────────────────────────────────────┐
│              Message Pool                    │
│  ┌─────────────────────────────────────┐   │
│  │  [8B ID][1B tag][1B flags][2B refs]  │   │
│  │           + Data Buffer              │   │
│  └─────────────────────────────────────┘   │
│                                              │
│  Operations:                                 │
│  - Get()     → Acquire buffer               │
│  - Return()  → Release buffer               │
│  - Share()   → Increment ref count          │
│  - Copy()    → Copy data to pooled buffer   │
└─────────────────────────────────────────────┘
```

**Ownership Rules:**
1. Owner returns message to pool when done
2. Callbacks receive temporarily valid messages
3. Sharing increments reference count

---

## Data Flow

### Outbound Flow (Consumer → Provider)

```
┌──────────────┐
│  Application │
│   Request    │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│  IP Layer    │────▶│  UNAT        │
│  (SendPacket)│     │  TCP/UDP     │
└──────┬───────┘     └──────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│ Transfer     │────▶│ Contract     │
│ (SendFrame)  │     │ Manager      │
└──────┬───────┘     └──────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│ Transport    │────▶│ H1/H3/P2P    │
│ (Transmit)   │     │ Selection    │
└──────┬───────┘     └──────────────┘
       │
       ▼
┌──────────────┐
│  Network     │
│  (DoH/TLS)   │
└──────────────┘
```

### Inbound Flow (Provider → Consumer)

```
┌──────────────┐
│  Network     │
│  Receive     │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│ Transport    │────▶│ Frame        │
│ (Receive)    │     │ Parse        │
└──────┬───────┘     └──────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│ Transfer     │────▶│ Route        │
│ (Dispatch)   │     │ Manager      │
└──────┬───────┘     └──────────────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│  IP Layer    │────▶│ Security     │
│ (Receive)    │     │ Policy       │
└──────┬───────┘     └──────────────┘
       │
       ▼
┌──────────────┐
│  Application │
│  Callback    │
└──────────────┘
```

---

## Protocol Stack

### Wire Protocol (Protobuf)

```
┌─────────────────────────────────────┐
│          Frame (wrapper)             │
│  ┌───────────────────────────────┐  │
│  │  MessageType                  │  │
│  │  message_bytes                │  │
│  │  raw (bool)                   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│      TransferFrame (routing)         │
│  ┌───────────────────────────────┐  │
│  │  TransferPath                 │  │
│  │    - source_id                │  │
│  │    - destination_id           │  │
│  │    - stream_id                │  │
│  │  Frame / Pack / Ack           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Message Types

| Type | Purpose |
|------|---------|
| `TransferPack` | Data packet delivery |
| `TransferAck` | Delivery acknowledgment |
| `TransferContract` | Contract establishment |
| `TransferProvide` | Provider announcement |
| `TransferAuth` | Authentication |
| `TransferCreateStream` | Stream creation |
| `IpIpPacketToProvider` | IP packet to provider |
| `IpIpPacketFromProvider` | IP packet from provider |

---

## Deployment Architecture

### Provider Daemon

```
┌─────────────────────────────────────┐
│           Provider Daemon            │
│  ┌───────────────────────────────┐  │
│  │  Auth Manager                 │  │
│  │  ~/.urnetwork/jwt             │  │
│  └───────────────────────────────┘  │
│                  │                   │
│  ┌───────────────┴───────────────┐  │
│  │         Connect Client         │  │
│  │  - Transport                   │  │
│  │  - Transfer                    │  │
│  │  - UNAT                        │  │
│  └───────────────────────────────┘  │
│                  │                   │
│  ┌───────────────┴───────────────┐  │
│  │      Platform Connection       │  │
│  │  wss://connect.bringyour.com  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Extender Relay

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Client     │────▶│   Extender   │────▶│  Platform    │
│              │     │  (TLS Proxy) │     │  :8443       │
└──────────────┘     └──────────────┘     └──────────────┘
                           │
                     Proxy Protocol
                        Header
                    (IP whitelisting)
```

---

## Key Design Patterns

### 1. Multi-Route Transport

Multiple transports can exist for the same destination. Selection based on:
- Availability (H3 vs H1)
- Performance (RTT, throughput)
- Censorship conditions

### 2. Contract-Based Transfer

```
Sender ←──Contract──→ Receiver
   │                    │
   └─── Accounting ─────┘
        (Multi-hop)
```

### 3. Zero-Copy Pooling

```
Get() → Use() → Return()
         │
         └─→ Share() → Use() → Return()
```

### 4. Censorship Resistance

- DNS-over-HTTPS
- TLS fragmentation
- Extender relays
- Multiple transport modes

---

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md)
- [Codebase Summary](./codebase-summary.md)
- [Code Standards](./code-standards.md)
- [Deployment Guide](./deployment-guide.md)
