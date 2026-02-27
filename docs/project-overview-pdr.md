# URnetwork Connect - Project Overview & PDR

## Project Summary

**Project Name:** URnetwork Connect
**Language:** Go 1.24.4
**License:** MPL 2.0
**Repository:** github.com/urnetwork/connect

URnetwork Connect is a web-standards VPN marketplace that enables fast, secure internet access through a distributed network of providers. The project emphasizes privacy, security, and availability while working on consumer devices from normal app stores.

---

## Vision & Goals

### Vision
Create a trusted, best-in-class technology for the "public VPN" market that is ubiquitous and distributed for better consumer experience.

### Primary Goals
1. **Consumer-First Design** - Works on consumer devices from normal app stores
2. **Resource Integration** - Allows consumer devices to tap into existing resources to enhance the public VPN
3. **Privacy & Security** - Emphasizes privacy, security, and availability
4. **Performance** - Fast, efficient networking with minimal overhead

---

## Target Users

### Primary Users
| User Type | Description | Use Case |
|-----------|-------------|----------|
| **Consumers** | End-users seeking VPN services | Privacy, security, accessing geo-restricted content |
| **Providers** | Users sharing bandwidth | Earn rewards by providing network resources |
| **Developers** | Integrating VPN functionality | Building apps with embedded VPN capabilities |

### Secondary Users
- Network administrators
- Security researchers
- Platform operators

---

## Functional Requirements

### FR-01: Transport Layer
- Multi-route transport support (H1, H3, H3Dns, H3DnsPump)
- Automatic transport mode selection
- HTTP/1 to HTTP/3 upgrade capability
- P2P connection support
- Extender relay support for censorship resistance

### FR-02: Transfer Layer
- Reliable frame delivery with acknowledgments
- Contract-based accounting for multi-hop paths
- In-order message delivery
- Sender verification with pre-exchanged keys
- High throughput with bounded resource usage

### FR-03: IP Layer (UNAT)
- User-space NAT implementation
- TCP and UDP packet handling
- Security policy enforcement
- Packet inspection capabilities
- IP blocklist management

### FR-04: Network Layer
- DNS-over-HTTPS (DoH) support
- Resilient TLS connections
- Censorship resistance mechanisms
- Regional DoH profiles

### FR-05: Provider System
- Background daemon for bandwidth sharing
- Authentication via JWT
- Proxy configuration
- Auto-update capability

### FR-06: CLI Tools
- Network creation and management
- Provider authentication
- Status monitoring
- Installation management

---

## Non-Functional Requirements

### NFR-01: Performance
| Metric | Requirement |
|--------|-------------|
| Throughput | Support high-bandwidth applications |
| Latency | Minimize multi-hop latency |
| Memory | Efficient zero-copy message pooling |
| CPU | Optimized QUIC vs WebSocket trade-offs |

### NFR-02: Security
- JWT-based authentication
- TLS 1.3 for all connections
- Pre-exchanged key verification
- IP security policies and blocklists
- Privacy-preserving audit system

### NFR-03: Reliability
- Automatic reconnection
- Message retry with backoff
- Timeout handling at all layers
- Graceful degradation

### NFR-04: Scalability
- Support multiple simultaneous clients
- Contract-based multi-hop routing
- Efficient resource pooling

### NFR-05: Compatibility
- Linux (systemd and non-systemd)
- Windows
- Proxmox LXC containers
- Alpine Linux

---

## Success Metrics

### Technical Metrics
- [ ] Connection establishment time < 5 seconds
- [ ] Packet loss recovery < 1 second
- [ ] Memory usage bounded to configured limits
- [ ] Zero-copy pooling efficiency > 90%

### User Metrics
- [ ] Successful authentication rate > 99%
- [ ] Provider uptime > 95%
- [ ] Installation success rate > 98%

---

## Constraints

### Technical Constraints
- Go 1.24.4+ required
- Network connectivity required for operation
- TLS/QUIC compatible network paths

### Platform Constraints
- Consumer app store compliance
- Standard network protocols only (HTTP/1.1, HTTP/3, WebSocket)
- No raw socket access on consumer devices

### Operational Constraints
- MPL 2.0 license compliance
- API rate limiting (handled via extenders)
- Provider IP whitelisting

---

## Dependencies

### Core Dependencies
| Dependency | Purpose |
|------------|---------|
| `quic-go` | QUIC protocol (HTTP/3) |
| `gorilla/websocket` | WebSocket connections |
| `gopacket` | Packet parsing |
| `golang-jwt/jwt` | JWT handling |
| `protobuf` | Protocol buffers |

### External Services
- `api.bringyour.com` - API server
- `connect.bringyour.com` - WebSocket connect service
- Circle wallet API (USDC payments)

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| DPI/Filtering | High | Multiple transport modes, DNS tunneling |
| Provider churn | Medium | Automatic route management |
| Memory exhaustion | Medium | Bounded pooling, configurable limits |
| API rate limiting | Low | Extender relays, proxy protocol |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2 | 2025-05-28 | Optimized memory usage, v2 protocol |
| 1 | Initial | Original implementation |

---

## Related Documentation

- [Codebase Summary](./codebase-summary.md)
- [System Architecture](./system-architecture.md)
- [Code Standards](./code-standards.md)
- [Deployment Guide](./deployment-guide.md)
