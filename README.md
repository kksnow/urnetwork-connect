# URnetwork Connect

A web-standards VPN marketplace with an emphasis on fast, secure internet everwhere. This project exists to create a trusted best-in-class technology for the "public VPN" market, that:

- Works on consumer devices from the normal app stores
- Allows consumer devices to tap into existing resources to enhance the public VPN. We believe a more ubiquitous and distributed VPN will be better for consumers.
- Emphasizes privacy, security, and availability


## Protocol

[Protocol defintion](protocol): Protobuf messages for the realtime transport protocol

[API definition](api): OpenAPI definition for the API for clients to interact with the marketplace


## Buffer reuse

Anywhere in the code that returns a `[]byte` will allocate it from the shared message pool. The following rules are used:

- When passing `[]byte` into a function that takes ownership of the `[]byte`, the final owner should return the byte to the message pool when finished. Examples of this are passing a `[]byte` to a channel and async io loop functions.
- When passing a `[]byte` to a callback, the callback should assume the `[]byte` is valid only for the duration of the function call. The caller will return the `[]byte` to the message pool after the callbacks are processed.


## Installation

### Linux / Proxmox LXC / Alpine Linux

**Prerequisites (Alpine):**
```sh
apk add curl bash python3  # or jq instead of python3
```

**Install (one-liner):**
```sh
curl -fsSL https://raw.githubusercontent.com/kksnow/urnetwork-connect/main/scripts/Provider_Install_Linux.sh | sh
```

**Or with wget:**
```sh
wget -qO- https://raw.githubusercontent.com/kksnow/urnetwork-connect/main/scripts/Provider_Install_Linux.sh | sh
```

**Post-install:**
```sh
source ~/.bashrc           # Reload PATH
urnetwork auth             # Authenticate (get code from https://ur.io)
urnet-tools start          # Start provider
urnet-tools status         # Check status
```

**Optional flags:**
```sh
# Install specific version
... | sh -s -- -t=v1.2.0

# Skip bashrc modification
... | sh -s -- -B

# Custom install path
... | sh -s -- -i /opt/urnetwork
```

**Non-systemd environments (LXC/Alpine):** Auto-start and auto-update configured via cron.

### Management Commands

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


## Discord

[https://discord.gg/urnetwork](https://discord.gg/urnetwork)


## License

URnetwork is licenced under the [MPL 2.0](LICENSE).


![URnetwork](res/images/connect-project.webp "URnetwork")

[URnetwork](https://ur.io): better internet

