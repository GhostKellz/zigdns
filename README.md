# ZigDNS

![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-f7a41d?logo=zig)
![DoT/DoH Secure](https://img.shields.io/badge/DoT%2FDoH-Secure-blueviolet)
![Cloudflare DNS Ready](https://img.shields.io/badge/Cloudflare%20DNS-Ready-orange)
[![Arch Linux](https://img.shields.io/badge/platform-Arch%20Linux-blue)](https://archlinux.org)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/ghostkellz/zigdns/ci.yml?branch=main)](https://github.com/ghostkellz/zigdns/actions)

> Cutting-edge DNS resolver built in Zig for Arch Linux and beyond. Supports DNS-over-UDP, DNS-over-TLS (DoT), DNS-over-HTTPS (DoH), blocklists, root hints, and blazing performance.

## Features
- **DNS-over-UDP, DoT, DoH**: Choose your preferred protocol via config.
- **Blocklists**: StevenBlack, Hagezi, AdGuard, and more.
- **Root Hints**: Automatic root server fallback and refresh.
- **High Performance**: LRU cache, async, and connection pooling.
- **Arch Linux First**: Designed for modern Linux, but portable.
- **Configurable**: Simple config file for all options.

## Quick Start
```sh
zig build
./zig-out/bin/zigdns
```

## Configuration
Edit `src/config.zig` to set:
- `mode`: `udp`, `dot`, or `doh`
- `upstream`: Hostname (recommended for DoT/DoH) or IP:port
- `blocklist_urls`: Add or remove blocklists

**Example:**
```zig
pub const Config = struct {
    listen_addr: []const u8,
    upstream: []const u8, // e.g. "cloudflare-dns.com:853"
    mode: []const u8,     // "udp", "dot", or "doh"
    blocklist_urls: []const []const u8,
};
```

## Running as a systemd Service
1. Copy your binary to `/usr/bin/zigdns`.
2. Create `/etc/systemd/system/zigdns.service`:
   ```ini
   [Unit]
   Description=ZigDNS Resolver
   After=network.target

   [Service]
   ExecStart=/usr/bin/zigdns
   Restart=on-failure
   User=nobody
   Group=nogroup

   [Install]
   WantedBy=multi-user.target
   ```
3. Reload systemd and start:
   ```sh
   sudo systemctl daemon-reload
   sudo systemctl enable zigdns
   sudo systemctl start zigdns
   sudo systemctl status zigdns
   ```

## Security Notes
- For DoT, always use a hostname for upstream for proper TLS validation.
- If you use an IP, cert validation may fail unless the cert matches the IP.

## Docs
See [DOCS.md](DOCS.md) for advanced usage, troubleshooting, and architecture.

## License
MIT

