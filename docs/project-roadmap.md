# Project Roadmap

This document tracks the development phases, milestones, and future plans for URnetwork Connect.

---

## Current Status

**Version:** v2 (Protocol v2)
**Last Updated:** 2025-02-28
**Status:** Active Development

---

## Release History

| Version | Date | Description |
|---------|------|-------------|
| v2 | 2025-05-28 | Optimized memory usage, v2 protocol (breaking change) |
| v1 | Initial | Original implementation |

---

## Development Phases

### Phase 1: Core Infrastructure (Complete)

**Status:** Complete

**Deliverables:**
- [x] Transport layer with H1/H3 support
- [x] Transfer layer with reliable delivery
- [x] IP layer with UNAT
- [x] Network layer with DoH
- [x] Message pooling system
- [x] Protocol buffer definitions

**Key Files:**
- `transport.go`, `transfer.go`, `ip.go`, `net_http.go`
- `protocol/*.proto`

---

### Phase 2: Provider System (Complete)

**Status:** Complete

**Deliverables:**
- [x] Provider daemon (`provider/`)
- [x] Authentication system
- [x] Auto-update mechanism
- [x] Linux installation scripts
- [x] Windows installation scripts
- [x] Management CLI (`urnet-tools`)

**Key Files:**
- `provider/main.go`
- `scripts/Provider_Install_Linux.sh`
- `scripts/Provider_Install_Win32.ps1`

---

### Phase 3: Censorship Resistance (Complete)

**Status:** Complete

**Deliverables:**
- [x] DNS-over-HTTPS support
- [x] Regional DoH profiles
- [x] Extender relay support
- [x] Packet translation modes
- [x] TLS fragmentation
- [x] Multiple transport mode selection

**Key Files:**
- `net_http_doh.go`, `net_extender.go`
- `transport_pt.go`

---

### Phase 4: Multi-Hop & Scaling (Complete)

**Status:** Complete

**Deliverables:**
- [x] Contract-based multi-hop routing
- [x] Stream management
- [x] Route manager
- [x] Multi-client IP handling
- [x] RTT calculations

**Key Files:**
- `transfer_contract_manager.go`
- `transfer_stream_manager.go`
- `transfer_route_manager.go`
- `ip_remote_multi_client.go`

---

### Phase 5: Platform Integration (In Progress)

**Status:** In Progress

**Deliverables:**
- [x] API client implementation
- [x] JWT authentication
- [ ] Enhanced monitoring/metrics
- [ ] Performance dashboards
- [ ] Extended API coverage

**Key Files:**
- `api.go`, `jwt.go`
- `api/bringyour.yml`

---

### Phase 6: Enterprise Features (Planned)

**Status:** Planned

**Deliverables:**
- [ ] Enterprise authentication
- [ ] Advanced security policies
- [ ] Custom extender deployment
- [ ] SLA monitoring
- [ ] Audit logging enhancements

---

## Milestones

### Milestone 1: Stable Provider (Reached)
- Provider daemon runs stably
- Auto-update working
- Multi-platform support

### Milestone 2: Censorship Resistance (Reached)
- Multiple transport modes
- DoH integration
- Extender relay support

### Milestone 3: Protocol v2 (Reached)
- Memory optimization
- Breaking protocol changes
- Migration path documented

### Milestone 4: Enterprise Ready (In Progress)
- Monitoring and metrics
- Enterprise authentication
- SLA compliance

---

## Future Features

### Short-Term (Next 3 Months)

| Feature | Priority | Status |
|---------|----------|--------|
| Enhanced metrics collection | High | Planned |
| Performance dashboards | Medium | Planned |
| WebRTC P2P improvements | Medium | In Progress |
| Additional DoH providers | Low | Planned |

### Medium-Term (3-6 Months)

| Feature | Priority | Status |
|---------|----------|--------|
| Enterprise authentication | High | Planned |
| Custom extender deployment | Medium | Planned |
| Advanced audit logging | Medium | Planned |
| Mobile SDK improvements | High | Planned |

### Long-Term (6-12 Months)

| Feature | Priority | Status |
|---------|----------|--------|
| Decentralized provider network | Medium | Research |
| Blockchain-based accounting | Low | Research |
| Custom protocol extensions | Medium | Planned |

---

## Known Limitations

### Current Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Raw socket unavailable on mobile | High | User-space NAT (UNAT) |
| Protocol v1/v2 incompatibility | Medium | Version negotiation |
| DPI in restricted regions | High | Multiple transport modes |
| Provider IP rate limiting | Low | Extender relays |

### Technical Debt

| Item | Priority | Notes |
|------|----------|-------|
| Large ip_security.go file | Low | Blocklist data, acceptable |
| Test coverage gaps | Medium | Ongoing improvement |
| Documentation updates | Medium | This effort |

---

## Success Metrics

### Technical Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Connection time | < 5s | TBD |
| Packet loss recovery | < 1s | TBD |
| Memory efficiency | > 90% pool usage | TBD |
| Test coverage | > 80% | TBD |

### Operational Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Provider uptime | > 95% | TBD |
| Installation success | > 98% | TBD |
| Auth success rate | > 99% | TBD |

---

## Contributing

### Development Priorities

1. Test coverage improvements
2. Performance optimization
3. Documentation updates
4. Feature development

### Getting Started

1. Read [Project Overview](./project-overview-pdr.md)
2. Review [Code Standards](./code-standards.md)
3. Study [System Architecture](./system-architecture.md)
4. Follow [Deployment Guide](./deployment-guide.md)

---

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md)
- [Codebase Summary](./codebase-summary.md)
- [System Architecture](./system-architecture.md)
- [Deployment Guide](./deployment-guide.md)
