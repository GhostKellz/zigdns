# ZigDNS Commands Reference

Complete reference for all `zdns` CLI commands and options.

## Table of Contents

- [Basic Commands](#basic-commands)
- [Server Commands](#server-commands)
- [Query Commands](#query-commands)
- [Configuration Commands](#configuration-commands)
- [Utility Commands](#utility-commands)
- [Global Options](#global-options)
- [Protocol Options](#protocol-options)
- [Examples](#examples)

---

## Basic Commands

### `zdns help`
**Aliases:** `-h`, `--help`

Show comprehensive help information including all commands, options, and examples.

```bash
zdns help
zdns -h
zdns --help
```

### `zdns version`
**Aliases:** `-v`, `--version`

Display version information, build details, and feature list.

```bash
zdns version
zdns -v
zdns --version
```

**Sample Output:**
```
ZigDNS v1.0.0

Features:
  • Web3 DNS Resolution (ENS, Unstoppable, ZNS, CNS)
  • DNS-over-QUIC (DoQ) support
  • Post-Quantum Cryptography ready
  • Ad/Malware blocking
  • Secure caching

Build: debug - simple-resolver
Zig: 0.15.0-dev
```

---

## Server Commands

### `zdns start`
**Aliases:** `run`

Start the DNS server with specified protocol and options. This is the default command if none specified.

```bash
zdns start [OPTIONS]
zdns run [OPTIONS]
zdns [OPTIONS]  # Implicit start
```

**Common Usage:**
```bash
# Start on default UDP:53
zdns start

# Start on custom port
zdns start --port=5353

# Start with specific protocol
zdns start --protocol=dot
zdns start --protocol=doh
zdns start --protocol=doq

# Run as daemon
zdns start --daemon

# Verbose mode
zdns start --verbose

# Custom upstream
zdns start --upstream=8.8.8.8:53
```

**Protocol Behavior:**
- `udp` - Traditional DNS on port 53 (default)
- `dot` - DNS-over-TLS on port 853
- `doh` - DNS-over-HTTPS on port 443
- `doq` - DNS-over-QUIC on port 853 (post-quantum ready)

---

## Query Commands

### `zdns query <domain>`
**Aliases:** `resolve`

Query a specific domain and show resolution details. Supports both traditional and Web3 domains.

```bash
zdns query <domain>
zdns resolve <domain>
```

**Examples:**
```bash
# Traditional domains
zdns query google.com
zdns query cloudflare.com

# Web3 domains (ENS)
zdns query vitalik.eth
zdns query uniswap.eth

# Web3 domains (Unstoppable)
zdns query brad.crypto
zdns query unstoppable.nft

# Web3 domains (GhostChain ZNS)
zdns query ghost.zns
zdns query example.ghost

# Web3 domains (CNS QUIC)
zdns query secure.cns
```

**Sample Output:**
```
🔍 Querying domain: vitalik.eth
🌐 Web3 domain detected
✅ Resolved via ENS:
   192.168.1.100
```

**For Traditional Domains:**
```
🔍 Querying domain: google.com
🏢 Traditional domain - would forward to upstream
   Upstream: 1.1.1.1:53
✅ Domain not blocked, would resolve normally
```

### `zdns test-web3`
**Aliases:** `test`

Test Web3 domain resolution functionality across all supported protocols.

```bash
zdns test-web3
zdns test
```

**Sample Output:**
```
🧪 Testing Web3 domain resolution
================================

🔍 Testing: vitalik.eth
  ✅ Resolver: ENS
  📍 Address: 192.168.1.100
  ⏱️  TTL: 300s

🔍 Testing: unstoppable.crypto
  ✅ Resolver: Unstoppable Domains
  📍 Address: 10.0.0.100
  ⏱️  TTL: 300s
  📦 Content: ipfs://QmYourContentHash

✅ Web3 testing complete
```

---

## Configuration Commands

### `zdns config`
**Aliases:** None

Display current configuration settings.

```bash
zdns config
```

**Sample Output:**
```
⚙️  ZigDNS Configuration
=======================
Listen address:    0.0.0.0:53
QUIC address:      0.0.0.0:853
Upstream DNS:      1.1.1.1:53
Upstream QUIC:     1.1.1.1:853
Mode:              doq
Post-Quantum:      false
Zero-copy:         true
Cache size:        4096
Max queries:       10000
Auto-gen certs:    true
Blocklist sources: 5
```

### `zdns set <key> <value>`
**Aliases:** None

Set configuration values (feature in development).

```bash
zdns set <key> <value>
```

**Examples:**
```bash
zdns set upstream 8.8.8.8:53
zdns set mode dot
zdns set cache_size 8192
```

---

## Utility Commands

### `zdns stats`
**Aliases:** `status`

Show server statistics and performance metrics.

```bash
zdns stats
zdns status
```

**Sample Output:**
```
📊 ZigDNS Statistics
===================
Cache hits:       1250
Cache misses:     324
Blocked queries:  89
UDP queries:      1563
QUIC queries:     0

🌐 Web3 Statistics
ENS queries:      45
UNS queries:      12
ZNS queries:      3
CNS queries:      1

Note: Live statistics require running server
```

### `zdns flush`
**Aliases:** `clear-cache`

Clear the DNS cache.

```bash
zdns flush
zdns clear-cache
```

**Output:**
```
🧹 DNS cache flushed
Note: This is a simulation - actual cache flushing requires server restart
```

---

## Global Options

### Verbosity Options

#### `--verbose`
**Aliases:** `-v`

Enable verbose output with detailed information.

```bash
zdns start --verbose
zdns query example.com --verbose
```

#### `--quiet`
**Aliases:** `-q`

Suppress non-error output for minimal logging.

```bash
zdns start --quiet
zdns query example.com --quiet
```

### Server Options

#### `--daemon`
**Aliases:** `-d`

Run the server as a background daemon.

```bash
zdns start --daemon
```

#### `--port=<port>`

Set the DNS server port (default depends on protocol).

```bash
zdns start --port=5353
zdns start --port=8853
```

**Default Ports:**
- UDP: 53
- DoT: 853
- DoH: 443
- DoQ: 853

#### `--upstream=<server>`

Set the upstream DNS server.

```bash
zdns start --upstream=8.8.8.8:53
zdns start --upstream=1.1.1.1:53
zdns start --upstream=9.9.9.9:53
```

### Feature Toggles

#### `--no-web3`

Disable Web3 domain resolution.

```bash
zdns start --no-web3
```

#### `--no-blocklist`

Disable ad/malware blocking.

```bash
zdns start --no-blocklist
```

---

## Protocol Options

### `--protocol=<protocol>`

Set the DNS protocol. Available options:

#### `--protocol=udp` (Default)
Traditional DNS over UDP on port 53.

```bash
zdns start --protocol=udp
zdns start --protocol=udp --port=5353
```

#### `--protocol=dot`
DNS-over-TLS on port 853.

```bash
zdns start --protocol=dot
zdns start --protocol=dot --port=8853
```

**Features:**
- TLS 1.3 encryption
- Certificate validation
- Secure against eavesdropping

#### `--protocol=doh`
DNS-over-HTTPS on port 443.

```bash
zdns start --protocol=doh
zdns start --protocol=doh --port=8443
```

**Features:**
- HTTPS transport
- Web-friendly (works through firewalls)
- HTTP/2 multiplexing

#### `--protocol=doq`
DNS-over-QUIC on port 853.

```bash
zdns start --protocol=doq
zdns start --protocol=doq --port=8853
```

**Features:**
- QUIC transport protocol
- Post-quantum cryptography ready
- Low latency
- Connection migration support

---

## Examples

### Basic Server Setup

```bash
# Start simple UDP DNS server
zdns start

# Start on custom port (non-privileged)
zdns start --port=5353

# Start with verbose logging
zdns start --verbose

# Start as daemon
zdns start --daemon --quiet
```

### Secure DNS Setup

```bash
# DNS-over-TLS server
zdns start --protocol=dot

# DNS-over-HTTPS server  
zdns start --protocol=doh

# DNS-over-QUIC with post-quantum crypto
zdns start --protocol=doq

# Custom port for testing
zdns start --protocol=dot --port=8853 --verbose
```

### Custom Configuration

```bash
# Custom upstream and port
zdns start --upstream=8.8.8.8:53 --port=5353

# Disable Web3 features
zdns start --no-web3

# Minimal DNS server (no blocking, no Web3)
zdns start --no-web3 --no-blocklist --quiet

# Development mode
zdns start --port=5353 --verbose --upstream=1.1.1.1:53
```

### Web3 and Query Examples

```bash
# Test Web3 functionality
zdns test-web3

# Query traditional domains
zdns query google.com
zdns query cloudflare.com

# Query ENS domains
zdns query vitalik.eth
zdns query uniswap.eth

# Query Unstoppable Domains
zdns query brad.crypto
zdns query unstoppable.nft

# Quiet query mode
zdns query example.com --quiet

# Verbose query mode
zdns query vitalik.eth --verbose
```

### Monitoring and Maintenance

```bash
# Check server status
zdns stats

# View configuration
zdns config

# Clear cache
zdns flush

# Check version
zdns version
```

### Production Deployment

```bash
# Production server with all features
zdns start --protocol=doq --daemon --upstream=1.1.1.1:853

# High-performance UDP server
zdns start --protocol=udp --port=53 --daemon --quiet

# Secure DoT server
zdns start --protocol=dot --daemon --verbose

# Development/testing server
zdns start --protocol=udp --port=5353 --verbose --upstream=8.8.8.8:53
```

---

## Environment Variables

ZigDNS respects the following environment variables:

- `ZDNS_UPSTREAM` - Default upstream DNS server
- `ZDNS_PORT` - Default port
- `ZDNS_PROTOCOL` - Default protocol
- `ZDNS_VERBOSE` - Enable verbose mode (set to "1")
- `ZDNS_NO_WEB3` - Disable Web3 features (set to "1")

**Example:**
```bash
export ZDNS_UPSTREAM=8.8.8.8:53
export ZDNS_PORT=5353
export ZDNS_VERBOSE=1
zdns start
```

---

## Exit Codes

- `0` - Success
- `1` - General error (invalid arguments, startup failure)
- `2` - Permission denied (typically port binding)
- `3` - Configuration error
- `4` - Network error

---

## Supported Web3 Domains

| TLD | Protocol | Description | Example |
|-----|----------|-------------|---------|
| `.eth` | ENS | Ethereum Name Service | `vitalik.eth` |
| `.crypto` | UNS | Unstoppable Domains | `brad.crypto` |
| `.nft` | UNS | Unstoppable Domains | `unstoppable.nft` |
| `.blockchain` | UNS | Unstoppable Domains | `example.blockchain` |
| `.bitcoin` | UNS | Unstoppable Domains | `satoshi.bitcoin` |
| `.wallet` | UNS | Unstoppable Domains | `my.wallet` |
| `.888` | UNS | Unstoppable Domains | `lucky.888` |
| `.dao` | UNS | Unstoppable Domains | `governance.dao` |
| `.x` | UNS | Unstoppable Domains | `profile.x` |
| `.ghost` | ZNS | GhostChain ZNS | `example.ghost` |
| `.zns` | ZNS | GhostChain ZNS | `secure.zns` |
| `.cns` | CNS | CNS QUIC | `fast.cns` |

---

For more detailed setup and usage information, see [DOCS.md](DOCS.md).