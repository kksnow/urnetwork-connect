# Code Standards

This document defines the coding conventions, patterns, and best practices for the URnetwork Connect project.

---

## Go Conventions

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Packages | lowercase, single word | `connect`, `protocol` |
| Files | snake_case | `transfer_contract_manager.go` |
| Types | PascalCase | `TransferPath`, `UserNatClient` |
| Functions | PascalCase (exported), camelCase (private) | `DefaultClientSettings()`, `newMessagePool()` |
| Constants | PascalCase or UPPER_CASE | `TransportModeH3`, `DefaultMtu` |
| Variables | camelCase | `clientSettings`, `transferFrame` |
| Interfaces | PascalCase with -er suffix | `UserNatClient`, `SendPacketFunction` |

### File Organization

```
<component>.go           # Main implementation
<component>_test.go      # Tests
<component>_<sub>.go     # Sub-component implementation
```

Examples:
- `transport.go` + `transport_test.go` + `transport_p2p.go`
- `transfer.go` + `transfer_test.go` + `transfer_contract_manager.go`

---

## Memory Management

### Zero-Copy Message Pooling

The project uses a shared message pool for efficient memory management. All `[]byte` allocations use pooled buffers.

#### Pool Rules

1. **Ownership Transfer** - When passing `[]byte` to a function/channel that takes ownership, the receiver must return bytes to pool when finished.

2. **Callback Validity** - When passing `[]byte` to a callback, assume validity only during the function call. Caller returns bytes after callbacks complete.

3. **Sharing** - Use `MessagePoolShareReadOnly` before passing to multiple consumers.

#### API Functions

```go
// Get a pooled message buffer
func MessagePoolGet() []byte

// Return message to pool
func MessagePoolReturn(message []byte)

// Share message (increments ref count)
func MessagePoolShareReadOnly(message []byte) []byte

// Copy data into pooled buffer
func MessagePoolCopy(data []byte) []byte
```

#### Example Usage

```go
// Taking ownership - must return to pool
msg := MessagePoolGet()
// ... use msg ...
MessagePoolReturn(msg)

// Sharing for multiple consumers
shared := MessagePoolShareReadOnly(msg)
sendToChannel(shared)
// Original msg can still be used
```

---

## Error Handling

### Error Patterns

```go
// Return errors with context
func (c *Client) Connect() error {
    if err := c.validateAuth(); err != nil {
        return fmt.Errorf("connect: validate auth: %w", err)
    }
    return nil
}

// Use errors.Is for checking
if errors.Is(err, net.ErrClosed) {
    // handle closed connection
}

// Use errors.As for type checking
var netErr net.Error
if errors.As(err, &netErr) && netErr.Timeout() {
    // handle timeout
}
```

### Logging

```go
import "github.com/urnetwork/glog"

// Standard logging
glog.Info("message")
glog.Warning("warning message")
glog.Error("error message")

// Verbose logging (use -v flag)
glog.V(1).Info("debug message")
glog.V(2).Info("trace message")
```

---

## Shell Script Standards

Use these rules for scripts under `scripts/` that handle auth tokens or batch API operations.

### Safety Baseline

- Start scripts with `set -euo pipefail`.
- Use a single fatal helper (for example `die`) that writes to stderr and exits non-zero.

### Input and Retry Contracts

- Validate numeric inputs before arithmetic or loops.
- Retry only transient failures (`429`, `5xx`, transport errors).
- Keep retry count bounded and configurable via env var.

### Sensitive Output Handling

- Write credential-bearing files with mode `600`.
- Refuse symlink output targets for generated secret artifacts.
- If partial output is preserved on failure, exit non-zero and document the behavior in command help.

---

## Concurrency Patterns

### Mutex Usage

```go
type Client struct {
    mu     sync.Mutex
    state  *ClientState
}

func (c *Client) UpdateState() {
    c.mu.Lock()
    defer c.mu.Unlock()
    // ... modify state ...
}
```

### Atomic Operations

```go
type Counter struct {
    count atomic.Int64
}

func (c *Counter) Increment() {
    c.count.Add(1)
}
```

### Channel Patterns

```go
// Buffered channels for async processing
frameCh := make(chan *Frame, DefaultTransferBufferSize)

// Select with timeout
select {
case frame := <-frameCh:
    // process frame
case <-time.After(timeout):
    // handle timeout
}
```

---

## Protocol Buffers

### Proto File Standards

```protobuf
syntax = "proto3";
package bringyour;

option go_package = "github.com/urnetwork/connect/protocol";

// Use snake_case for field names
message TransferPath {
    optional bytes source_id = 1;
    optional bytes destination_id = 2;
    optional bytes stream_id = 3;
}
```

### Generated Code

- Generated files: `*.pb.go`
- Location: `protocol/` directory
- Regenerate with: `protoc --go_out=. protocol/*.proto`

---

## Testing Standards

### Test File Naming

```
<component>_test.go
```

### Test Function Naming

```go
func TestFunctionName(t *testing.T) {}
func TestFunctionName_Scenario(t *testing.T) {}
func BenchmarkFunctionName(b *testing.B) {}
```

### Test Patterns

```go
func TestTransferPath(t *testing.T) {
    t.Run("valid path", func(t *testing.T) {
        path := TransferPath{
            SourceId: NewId(),
            DestinationId: NewId(),
        }
        if path.SourceId == (Id{}) {
            t.Error("source id should not be empty")
        }
    })

    t.Run("from protobuf", func(t *testing.T) {
        protoPath := &protocol.TransferPath{
            SourceId: []byte{1, 2, 3},
        }
        path, err := TransferPathFromProtobuf(protoPath)
        if err != nil {
            t.Fatalf("unexpected error: %v", err)
        }
        // ... assertions
    })
}
```

### Table-Driven Tests

```go
func TestTransportMode(t *testing.T) {
    tests := []struct {
        name     string
        mode     TransportMode
        expected bool
    }{
        {"h3 mode", TransportModeH3, true},
        {"h1 mode", TransportModeH1, true},
        {"empty mode", TransportModeNone, false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // test logic
        })
    }
}
```

---

## Constants and Defaults

### Buffer Sizes

```go
const DefaultTransferBufferSize = 16
const DefaultIpBufferSize = 32
const DefaultMtu = 1440
```

### Timeouts

```go
const DefaultReadTimeout = 30 * time.Second
const DefaultWriteTimeout = 15 * time.Second
const DefaultIdleTimeout = 60 * time.Second
const DefaultConnectTimeout = 30 * time.Second
```

### Header Sizes

```go
const Ipv4HeaderSizeWithoutExtensions = 20
const Ipv6HeaderSize = 40
const UdpHeaderSize = 8
const TcpHeaderSizeWithoutExtensions = 20
```

---

## Configuration Patterns

### Settings Structures

```go
type ClientSettings struct {
    SendBufferSize          int
    ForwardBufferSize       int
    ReadTimeout             time.Duration
    BufferTimeout           time.Duration
    ControlPingTimeout      time.Duration
    SendBufferSettings      *SendBufferSettings
    ReceiveBufferSettings   *ReceiveBufferSettings
    ForwardBufferSettings   *ForwardBufferSettings
    ContractManagerSettings *ContractManagerSettings
    StreamManagerSettings   *StreamManagerSettings
    ProtocolVersion         int
}

func DefaultClientSettings() *ClientSettings {
    return &ClientSettings{
        SendBufferSize:     DefaultTransferBufferSize,
        ReadTimeout:        30 * time.Second,
        // ... defaults
    }
}
```

---

## Interface Design

### Function Types

```go
// Callback types for async operations
type AckFunction = func(err error)
type ReceiveFunction = func(source TransferPath, frames []*protocol.Frame, provideMode protocol.ProvideMode)
type ForwardFunction = func(path TransferPath, transferFrameBytes []byte)
type SendPacketFunction = func(provideMode protocol.ProvideMode, packet []byte, timeout time.Duration) bool
```

### Interface Patterns

```go
// Interface with clear contract
type UserNatClient interface {
    SendPacket(source TransferPath, provideMode protocol.ProvideMode, packet []byte, timeout time.Duration) bool
    Close()
    Shuffle()
    SecurityPolicyStats(reset bool) SecurityPolicyStats
}
```

---

## Version Compatibility

### Protocol Versioning

```go
// v1: original
// v2: 2025-05-28 - optimized memory usage (breaks v1 compatibility)
const DefaultProtocolVersion = 2

const TransportVersion = 2  // latency and speed test support
```

### Upgrade Handling

- Always check protocol version on receive
- Maintain backward compatibility where possible
- Document breaking changes in protocol files

---

## File Size Guidelines

| File Type | Recommended Size | Action When Exceeded |
|-----------|------------------|----------------------|
| Core logic | < 500 lines | Split into sub-components |
| Test files | < 400 lines | Group by test scenario |
| Utility files | < 200 lines | Re-evaluate scope |

**Note:** `ip_security.go` (2.5MB) is an exception - contains blocklist data.

---

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md)
- [Codebase Summary](./codebase-summary.md)
- [System Architecture](./system-architecture.md)
