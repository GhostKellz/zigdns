# ZigDNS Documentation

Complete setup and usage guide for ZigDNS - the advanced DNS resolver with Web3 support and post-quantum cryptography.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Protocol Setup](#protocol-setup)
- [Web3 Integration](#web3-integration)
- [Security Features](#security-features)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

---

## Overview

ZigDNS is a modern DNS resolver written in Zig that combines traditional DNS functionality with cutting-edge features:

### 🚀 **Core Features**
- **Multiple Protocols**: UDP, DNS-over-TLS (DoT), DNS-over-HTTPS (DoH), DNS-over-QUIC (DoQ)
- **Web3 Integration**: ENS, Unstoppable Domains, GhostChain ZNS, CNS QUIC
- **Post-Quantum Ready**: ML-KEM-768 + ML-DSA-65 cryptography
- **Ad/Malware Blocking**: Multiple filter lists with real-time updates
- **High Performance**: Zero-copy operations, efficient caching
- **Easy CLI**: Intuitive `zdns` command with comprehensive options

### 🎯 **Use Cases**
- **Workstation DNS**: Replace systemd-resolved on Arch Linux/other distros
- **Privacy-focused DNS**: Encrypted DNS protocols with blocking
- **Web3 Development**: Native support for blockchain domains
- **Enterprise DNS**: Post-quantum security for future-proofing
- **Home Network**: Family-safe DNS with comprehensive blocking

---

## Installation

### Prerequisites

- **Zig 0.15.0+** (development version)
- **Linux/macOS/Windows** (Linux recommended)
- **Root access** for port 53 (or use alternate ports)

### Building from Source

```bash
# Clone the repository
git clone https://github.com/your-username/zigdns.git
cd zigdns

# Build the project
zig build

# Install (optional)
sudo cp zig-out/bin/zdns /usr/local/bin/
```

### Quick Build Test

```bash
# Test the build
./zig-out/bin/zdns version

# Test help
./zig-out/bin/zdns help

# Test Web3 functionality
./zig-out/bin/zdns test-web3
```

### Dependencies

**Current Build:**
- No external dependencies (simple resolver mode)
- All features work without zquic/zcrypto

**Full Build (when available):**
- ZQUIC v0.3.0+ for DNS-over-QUIC
- ZCRYPTO v0.5.0+ for post-quantum cryptography

---

## Quick Start

### 1. Basic DNS Server

Start a simple UDP DNS server:

```bash
# Start on port 53 (requires root)
sudo zdns start

# Start on unprivileged port
zdns start --port=5353
```

### 2. Secure DNS Server

Start with encrypted protocols:

```bash
# DNS-over-TLS (port 853)
sudo zdns start --protocol=dot

# DNS-over-HTTPS (port 443)  
sudo zdns start --protocol=doh

# DNS-over-QUIC (port 853, post-quantum ready)
sudo zdns start --protocol=doq
```

### 3. Testing Queries

```bash
# Traditional DNS
zdns query google.com

# Web3 domains
zdns query vitalik.eth
zdns query brad.crypto
zdns query example.ghost

# Test all Web3 protocols
zdns test-web3
```

### 4. Configuration

```bash
# View current config
zdns config

# Check server stats
zdns stats

# View version info
zdns version
```

---

## Configuration

### Default Configuration

ZigDNS comes with sensible defaults:

```yaml
Listen Address: 0.0.0.0:53
QUIC Address: 0.0.0.0:853
Upstream DNS: 1.1.1.1:53
Upstream QUIC: 1.1.1.1:853
Protocol: UDP (default)
Post-Quantum: false (compatibility)
Cache Size: 4096 entries
Max Queries: 10000 concurrent
Auto-gen Certs: true
Blocklist Sources: 5 active lists
```

### Environment Variables

Set defaults via environment:

```bash
# Set default upstream
export ZDNS_UPSTREAM=8.8.8.8:53

# Set default port
export ZDNS_PORT=5353

# Set default protocol
export ZDNS_PROTOCOL=dot

# Enable verbose mode
export ZDNS_VERBOSE=1

# Disable Web3 features
export ZDNS_NO_WEB3=1

# Apply settings
zdns start
```

### Command Line Override

Override any setting via CLI:

```bash
# Custom everything
zdns start \
  --protocol=doq \
  --port=8853 \
  --upstream=9.9.9.9:53 \
  --verbose \
  --daemon
```

### Configuration File (Future)

Config file support planned for `/etc/zdns/config.toml`:

```toml
[server]
listen_addr = "0.0.0.0:53"
protocol = "doq"
daemon = true

[upstream]
primary = "1.1.1.1:853"
secondary = "8.8.8.8:853"
protocol = "doq"

[web3]
enabled = true
ens_endpoint = "https://mainnet.infura.io/v3/YOUR_KEY"
unstoppable_endpoint = "https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"

[security]
enable_post_quantum = true
auto_generate_certs = true
cert_path = "/etc/zdns/certs/"

[cache]
size = 10000
ttl_min = 60
ttl_max = 3600

[blocklist]
enabled = true
update_interval = "24h"
sources = [
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
]
```

---

## Protocol Setup

### UDP DNS (Traditional)

Basic UDP DNS on port 53:

```bash
# Standard setup
sudo zdns start

# Custom port for testing
zdns start --port=5353

# Custom upstream
zdns start --upstream=8.8.8.8:53 --port=5353
```

**Pros:**
- Universal compatibility
- Low latency
- Simple setup

**Cons:**
- No encryption
- Vulnerable to tampering
- Limited by UDP packet size

### DNS-over-TLS (DoT)

Encrypted DNS over TLS on port 853:

```bash
# Basic DoT server
sudo zdns start --protocol=dot

# Custom port
zdns start --protocol=dot --port=8853

# With custom upstream
zdns start --protocol=dot --upstream=1.1.1.1:853
```

**Pros:**
- Strong encryption (TLS 1.3)
- Standard port (853)
- Good firewall traversal

**Cons:**
- Blocked by some networks
- Slightly higher latency than UDP

### DNS-over-HTTPS (DoH)

DNS over HTTPS on port 443:

```bash
# Basic DoH server
sudo zdns start --protocol=doh

# Custom port
zdns start --protocol=doh --port=8443

# With custom upstream
zdns start --protocol=doh --upstream=cloudflare-dns.com:443
```

**Pros:**
- Uses standard HTTPS port (443)
- Excellent firewall traversal
- HTTP/2 multiplexing

**Cons:**
- Higher overhead than DoT
- More complex implementation

### DNS-over-QUIC (DoQ)

Next-generation DNS over QUIC on port 853:

```bash
# Basic DoQ server (post-quantum ready)
sudo zdns start --protocol=doq

# Custom port with verbose logging
zdns start --protocol=doq --port=8853 --verbose

# Production setup
sudo zdns start --protocol=doq --daemon --upstream=1.1.1.1:853
```

**Pros:**
- Lowest latency of encrypted protocols
- Connection migration support
- Post-quantum cryptography ready
- Multiplexed streams

**Cons:**
- Newer protocol (less support)
- More complex implementation

### Protocol Comparison

| Protocol | Port | Encryption | Latency | Firewall | PQ-Ready |
|----------|------|------------|---------|----------|----------|
| UDP      | 53   | ❌         | Lowest  | ✅       | ❌       |
| DoT      | 853  | ✅ TLS     | Low     | ⚠️       | ❌       |
| DoH      | 443  | ✅ HTTPS   | Medium  | ✅       | ❌       |
| DoQ      | 853  | ✅ QUIC    | Low     | ⚠️       | ✅       |

---

## Web3 Integration

ZigDNS provides native support for blockchain-based domain names.

### Supported Protocols

#### Ethereum Name Service (ENS)
Resolve `.eth` domains to IP addresses and content.

```bash
# Test ENS resolution
zdns query vitalik.eth
zdns query uniswap.eth
zdns query ethereum.eth
```

**Features:**
- Direct Ethereum blockchain queries
- Content hash resolution (IPFS/IPNS)
- Text records (avatar, description, etc.)
- Reverse resolution support

#### Unstoppable Domains (UNS)
Resolve various TLDs to decentralized content.

```bash
# Test Unstoppable Domains
zdns query brad.crypto
zdns query unstoppable.nft
zdns query example.blockchain
zdns query satoshi.bitcoin
zdns query my.wallet
zdns query lucky.888
zdns query governance.dao
zdns query profile.x
```

**Features:**
- Multi-chain support (Ethereum, Polygon)
- IPFS content hosting
- Social media integration
- Crypto payment addresses

#### GhostChain ZNS
Resolve `.ghost` and `.zns` domains.

```bash
# Test GhostChain domains
zdns query example.ghost
zdns query secure.zns
```

**Features:**
- Post-quantum secure blockchain
- Privacy-focused domains
- Anonymous resolution

#### CNS QUIC
Resolve `.cns` domains via QUIC protocol.

```bash
# Test CNS domains
zdns query fast.cns
zdns query secure.cns
```

**Features:**
- QUIC-native resolution
- Post-quantum cryptography
- Low-latency queries

### Web3 Configuration

Configure blockchain endpoints for resolution:

```bash
# Test all Web3 protocols
zdns test-web3

# Check current Web3 support
zdns config | grep -A 10 "Web3"

# Disable Web3 features
zdns start --no-web3
```

### Development Setup

For Web3 development with custom endpoints:

```bash
# Set custom ENS endpoint
export ENS_ENDPOINT="https://mainnet.infura.io/v3/YOUR_API_KEY"

# Set custom Unstoppable endpoint  
export UNS_ENDPOINT="https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

# Start with custom configuration
zdns start --verbose
```

### Web3 Caching

Web3 domains use specialized caching:

```bash
# View Web3 statistics
zdns stats

# Clear Web3 cache
zdns flush
```

**Cache Behavior:**
- ENS domains: 5-minute TTL
- Unstoppable Domains: 10-minute TTL  
- GhostChain ZNS: 15-minute TTL
- CNS QUIC: 5-minute TTL with cryptographic verification

---

## Security Features

### Ad/Malware Blocking

ZigDNS includes comprehensive blocking capabilities:

**Default Filter Lists:**
- Steven Black's Unified Hosts
- AdGuard DNS Filter
- Hagezi's Multi DNS Blocklist
- Additional security-focused lists

```bash
# Start with blocking enabled (default)
zdns start

# Disable blocking
zdns start --no-blocklist

# View blocked query stats
zdns stats
```

**Blocking Behavior:**
- Returns `NXDOMAIN` for blocked domains
- Logs blocked queries for monitoring
- Real-time filter list updates (planned)

### Post-Quantum Cryptography

When fully integrated, ZigDNS will support:

**Algorithms:**
- **ML-KEM-768**: Key encapsulation mechanism
- **ML-DSA-65**: Digital signature algorithm  
- **SHA-3**: Cryptographic hashing

```bash
# Enable post-quantum features (when available)
zdns start --protocol=doq

# Check PQ status
zdns config | grep "Post-Quantum"
```

**Current Status:**
- Infrastructure implemented
- Integration pending zquic/zcrypto stability
- Protocols designed for PQ transition

### Certificate Management

Automatic TLS certificate handling:

```bash
# Auto-generate self-signed certificates
zdns start --protocol=dot

# Use custom certificates
zdns start --protocol=dot --cert=/path/to/cert.pem --key=/path/to/key.pem
```

**Certificate Features:**
- Auto-generation for testing
- Support for Let's Encrypt (planned)
- Certificate rotation (planned)
- Post-quantum certificate algorithms (future)

### Secure Caching

Advanced caching with integrity verification:

**Features:**
- Cryptographic signatures on cache entries
- TTL-based expiration
- Secure cache invalidation
- Protection against cache poisoning

---

## Deployment

### Development Setup

Quick development environment:

```bash
# Clone and build
git clone https://github.com/your-username/zigdns.git
cd zigdns
zig build

# Start development server
./zig-out/bin/zdns start --port=5353 --verbose

# Test in another terminal
./zig-out/bin/zdns query google.com
./zig-out/bin/zdns test-web3
```

### Workstation Setup (Arch Linux)

Replace systemd-resolved with ZigDNS:

```bash
# Stop systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Install ZigDNS
sudo cp zig-out/bin/zdns /usr/local/bin/

# Create systemd service
sudo tee /etc/systemd/system/zdns.service << EOF
[Unit]
Description=ZigDNS Resolver
After=network.target

[Service]
Type=simple
User=zdns
Group=zdns
ExecStart=/usr/local/bin/zdns start --daemon --protocol=dot
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create zdns user
sudo useradd -r -s /bin/false zdns

# Configure resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Start service
sudo systemctl enable zdns
sudo systemctl start zdns

# Check status
sudo systemctl status zdns
```

### Server Deployment

Production DNS server setup:

```bash
# Install ZigDNS
sudo cp zig-out/bin/zdns /usr/local/bin/

# Create configuration directory
sudo mkdir -p /etc/zdns/certs

# Generate certificates (for DoT/DoH/DoQ)
sudo zdns start --protocol=dot --daemon --generate-certs

# Create production service
sudo tee /etc/systemd/system/zdns.service << EOF
[Unit]
Description=ZigDNS Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/zdns start --protocol=doq --daemon --quiet
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall
sudo ufw allow 53/udp comment "DNS UDP"
sudo ufw allow 853/tcp comment "DNS-over-TLS/QUIC"  
sudo ufw allow 443/tcp comment "DNS-over-HTTPS"

# Start production service
sudo systemctl enable zdns
sudo systemctl start zdns
```

### Docker Deployment

```dockerfile
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache zig

# Copy ZigDNS
COPY zig-out/bin/zdns /usr/local/bin/
COPY certs/ /etc/zdns/certs/

# Create user
RUN adduser -D -s /bin/false zdns

# Expose ports
EXPOSE 53/udp 853/tcp 443/tcp

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD zdns query health.check || exit 1

# Start ZigDNS
USER zdns
CMD ["zdns", "start", "--daemon", "--protocol=doq"]
```

Build and run:

```bash
# Build image
docker build -t zigdns .

# Run container
docker run -d \
  --name zigdns \
  --restart unless-stopped \
  -p 53:53/udp \
  -p 853:853/tcp \
  -p 443:443/tcp \
  zigdns

# Check logs
docker logs zigdns

# Test queries
docker exec zigdns zdns query google.com
```

---

## Troubleshooting

### Common Issues

#### Permission Denied (Port 53)

```bash
# Problem: Cannot bind to port 53
# Error: error.AccessDenied

# Solution 1: Use sudo
sudo zdns start

# Solution 2: Use unprivileged port
zdns start --port=5353

# Solution 3: Set capabilities (Linux)
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/zdns
zdns start  # Now works without sudo
```

#### DNS Resolution Fails

```bash
# Problem: Queries not resolving
# Check server status
zdns stats

# Check configuration
zdns config

# Test with verbose mode
zdns start --verbose

# Test specific query
zdns query google.com --verbose

# Check upstream connectivity
dig @1.1.1.1 google.com
```

#### Web3 Domains Not Working

```bash
# Problem: ENS/Web3 domains failing
# Test Web3 functionality
zdns test-web3

# Check Web3 status
zdns config | grep -i web3

# Enable Web3 explicitly
zdns start --web3

# Check blockchain endpoints
curl -X POST https://mainnet.infura.io/v3/YOUR_KEY \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Debugging Commands

```bash
# Verbose server startup
zdns start --verbose --port=5353

# Debug specific query
zdns query example.com --verbose

# Check all statistics
zdns stats

# View configuration
zdns config

# Test all Web3 protocols
zdns test-web3

# Monitor logs (if using systemd)
sudo journalctl -u zdns -f

# Check network connectivity
ss -tulpn | grep zdns
netstat -tulpn | grep 53
```

---

## Advanced Usage

### Custom Filter Lists

Add custom blocking lists:

```bash
# Create custom blocklist
echo "ads.example.com" >> /etc/zdns/custom-blocklist.txt
echo "tracker.evil.com" >> /etc/zdns/custom-blocklist.txt

# Start with custom list
zdns start --blocklist=/etc/zdns/custom-blocklist.txt
```

### Monitoring Integration

#### Prometheus Metrics

```bash
# Export metrics (planned feature)
zdns start --metrics-port=9090

# Prometheus configuration
cat >> /etc/prometheus/prometheus.yml << EOF
  - job_name: 'zdns'
    static_configs:
      - targets: ['localhost:9090']
EOF
```

### Scripting and Automation

#### Health Checks

```bash
#!/bin/bash
# health-check.sh

# Check if ZigDNS is running
if ! pgrep zdns > /dev/null; then
    echo "ZigDNS not running"
    exit 1
fi

# Test DNS resolution
if ! zdns query google.com --quiet > /dev/null 2>&1; then
    echo "DNS resolution failed"
    exit 1
fi

# Test Web3 resolution
if ! zdns query vitalik.eth --quiet > /dev/null 2>&1; then
    echo "Web3 resolution failed"
    exit 1
fi

echo "Health check passed"
exit 0
```

---

## Getting Help

### Community Support

- **GitHub Issues**: Report bugs and request features
- **Documentation**: Complete command reference in [COMMANDS.md](COMMANDS.md)
- **Examples**: See example configurations and scripts

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

### Development

```bash
# Build development version
zig build

# Run tests
zig build test

# Format code
zig fmt src/

# Check for issues
zig build-exe src/main.zig --check
```

---

**ZigDNS** - The future of DNS resolution is here! 🚀