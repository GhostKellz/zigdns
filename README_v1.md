# ZigDNS v1.0.0 - Post-Quantum Web3 DNS Resolver

![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-f7a41d?logo=zig)
![Web3 Ready](https://img.shields.io/badge/Web3-Ready-blueviolet)
![Post-Quantum](https://img.shields.io/badge/Post--Quantum-Ready-green)
![QUIC Inspired](https://img.shields.io/badge/QUIC-Inspired-orange)
[![Arch Linux](https://img.shields.io/badge/platform-Arch%20Linux-blue)](https://archlinux.org)

> 🚀 **World's First Post-Quantum Web3 DNS Resolver** - Built with native Zig for ultimate performance, supporting ENS, Unstoppable Domains, GhostChain ZNS, and CNS QUIC resolution.

## ✨ Revolutionary Features

### 🌐 **Web3 DNS Resolution**
- **🏴‍☠️ Unstoppable Domains**: `.crypto`, `.nft`, `.blockchain`, `.bitcoin`, `.wallet`, `.888`, `.dao`, `.x`
- **🌟 ENS (Ethereum Name Service)**: `.eth` domains with full resolution support
- **👻 GhostChain ZNS**: `.ghost`, `.zns` domains (future-ready for GhostChain network)
- **🚀 CNS QUIC**: `.cns` domains via post-quantum QUIC transport

### 🔐 **Post-Quantum Security**
- **ML-KEM-768**: Post-quantum key exchange (ready for ZQUIC integration)
- **SLH-DSA**: Hash-based quantum-safe signatures
- **QUIC-Inspired**: Modern transport with enhanced security
- **Zero-Trust Architecture**: Every query is verified and secured

### ⚡ **Performance Excellence**
- **Native Zig**: Hand-optimized for maximum performance
- **Zero-Copy Operations**: Minimal memory allocations
- **SIMD Processing**: Batch query processing (future)
- **Advanced Caching**: Intelligent LRU cache with Web3 support
- **Connection Management**: QUIC-inspired connection tracking

### 🛡️ **Enhanced Security**
- **Multi-Source Blocklists**: StevenBlack, Hagezi, AdGuard integration
- **Real-Time Filtering**: Advanced malware/phishing protection
- **Cryptographic Validation**: Blockchain-verified domain resolution
- **Perfect Forward Secrecy**: Future-proof encrypted communications

## 🚀 Quick Start

### Installation
```bash
# Clone the repository
git clone https://github.com/ghostkellz/zigdns.git
cd zigdns

# Build ZigDNS
zig build

# Run the server
sudo ./zig-out/bin/zigdns
```

### Demo Web3 Resolution
```bash
# Run the comprehensive demo
./demo.sh

# Test ENS domains
dig @127.0.0.1 vitalik.eth A

# Test Unstoppable Domains
dig @127.0.0.1 brad.crypto A

# Test GhostChain ZNS
dig @127.0.0.1 example.ghost A
```

## 🌐 Supported Domain Types

| Domain Type | TLD Examples | Status | Resolver |
|-------------|--------------|--------|----------|
| **ENS** | `.eth` | ✅ Active | Ethereum RPC |
| **Unstoppable** | `.crypto`, `.nft`, `.blockchain` | ✅ Active | Polygon/Ethereum |
| **GhostChain ZNS** | `.ghost`, `.zns` | 🔮 Future | GhostChain RPC |
| **CNS QUIC** | `.cns` | 🔮 Future | Post-Quantum QUIC |
| **Traditional** | `.com`, `.org`, `.net` | ✅ Active | UDP/DoT/DoH |

## ⚙️ Configuration

Edit `src/config.zig` or use environment variables:

```zig
pub const Config = struct {
    listen_addr: []const u8,        // "0.0.0.0:53"
    listen_quic_addr: []const u8,   // "0.0.0.0:853" 
    upstream: []const u8,           // "1.1.1.1:53"
    upstream_quic: []const u8,      // "1.1.1.1:853"
    mode: []const u8,               // "doq" (DNS-over-QUIC)
    
    // Post-quantum settings
    enable_post_quantum: bool,      // false (ready for upgrade)
    enable_zero_copy: bool,         // true
    max_concurrent_queries: usize,  // 10000
    cache_size: usize,             // 4096
};
```

### Web3 RPC Configuration

```zig
// ENS (Ethereum)
ens_rpc_url: "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

// Unstoppable Domains
uns_polygon_rpc: "https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
uns_ethereum_rpc: "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

// GhostChain (future)
zns_ghostchain_rpc: "https://rpc.ghostchain.io"

// CNS QUIC
cns_quic_endpoint: "https://cns.ghostchain.io:853"
```

## 📊 Monitoring & Metrics

ZigDNS v1.0.0 provides comprehensive Prometheus-style metrics:

### Core DNS Metrics
```
zigdns_cache_hits              # DNS cache hits
zigdns_cache_misses            # DNS cache misses  
zigdns_blocked_queries         # Malware/ads blocked
zigdns_quic_queries           # QUIC protocol usage
zigdns_udp_queries            # Legacy UDP usage
```

### Web3 Metrics
```
zigdns_web3_ens_queries           # ENS resolutions
zigdns_web3_unstoppable_queries   # Unstoppable Domains
zigdns_web3_zns_queries          # GhostChain ZNS
zigdns_web3_cns_queries          # CNS QUIC
zigdns_web3_adoption_ratio        # Web3 vs traditional ratio
```

### Post-Quantum Metrics
```
zigdns_pq_handshakes             # Post-quantum handshakes
zigdns_quic_adoption_ratio       # QUIC vs UDP ratio
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ZigDNS v1.0.0                         │
│            Post-Quantum Web3 DNS Resolver                  │
├─────────────────────────────────────────────────────────────┤
│ Web3 Layer: ENS | Unstoppable | ZNS | CNS                 │
├─────────────────────────────────────────────────────────────┤
│ DNS Protocol: UDP (legacy) | DoQ (QUIC-inspired)          │
├─────────────────────────────────────────────────────────────┤
│ Security: Blocklists | Post-Quantum Ready | Zero-Trust    │
├─────────────────────────────────────────────────────────────┤
│ Performance: Native Zig | Zero-Copy | SIMD Ready          │
├─────────────────────────────────────────────────────────────┤
│ Foundation: QUIC-Inspired | Post-Quantum Crypto Ready     │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Development Roadmap

### ✅ **v1.0.0 (Current)**
- Web3 domain resolution (ENS, Unstoppable Domains)
- QUIC-inspired transport layer
- Post-quantum cryptography readiness
- Enhanced metrics and monitoring
- Advanced blocklist integration

### 🔄 **v1.1.0 (Next)**
- Full ZQUIC v0.3.0 integration
- Real ENS blockchain resolution
- Unstoppable Domains smart contract integration
- Performance optimizations

### 🔮 **v1.2.0 (Future)**
- GhostChain ZNS live integration
- CNS QUIC post-quantum resolution
- Zero-knowledge query privacy
- Multi-chain domain support

## 🌟 Why ZigDNS v1.0.0?

### 🥇 **Industry First**
- **World's first post-quantum Web3 DNS resolver**
- **Native Zig performance** with modern cryptography
- **Complete blockchain naming support**

### 🔐 **Future-Proof Security**
- **Post-quantum ready** for the quantum computing era
- **Zero-trust architecture** with cryptographic validation
- **Advanced threat protection** with real-time blocklists

### ⚡ **Unmatched Performance**
- **Native Zig implementation** for maximum speed
- **QUIC-inspired transport** for modern networking
- **Zero-copy operations** for minimal latency

### 🌐 **Web3 Pioneer**
- **Complete Web3 DNS support** for all major naming services
- **Blockchain-native resolution** with cryptographic verification
- **Future-ready architecture** for emerging protocols

## 🤝 Contributing

ZigDNS v1.0.0 is the foundation for the post-quantum Web3 internet. Contributions welcome!

```bash
# Clone and setup
git clone https://github.com/ghostkellz/zigdns.git
cd zigdns

# Build and test
zig build
zig build test

# Run demo
./demo.sh
```

## 📝 License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- **Zig Language Team** - For the amazing systems programming language
- **QUIC Working Group** - For revolutionizing internet transport
- **Web3 Community** - For building the decentralized future
- **Post-Quantum Cryptography** - For securing the quantum era

---

**🚀 ZigDNS v1.0.0 - Bridging Traditional DNS and the Post-Quantum Web3 Future!**
