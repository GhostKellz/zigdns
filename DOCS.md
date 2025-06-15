# ZenDNS Documentation

## Overview
ZigDNS is a high-performance DNS resolver written in Zig, designed for Arch Linux and modern systems. It supports DNS-over-UDP, DNS-over-TLS (DoT), DNS-over-HTTPS (DoH), blocklists, root hints, and more.

## Configuration
- Edit `src/config.zig` to set your DNS mode, upstream, and blocklists.
- **mode**: `udp`, `dot`, or `doh`
- **upstream**: Hostname (recommended for DoT/DoH) or IP:port
- **blocklist_urls**: List of blocklist URLs (StevenBlack, Hagezi, AdGuard, etc.)

## Usage
- Build: `zig build`
- Run: `./zig-out/bin/zendns`
- Logs: See `zigdns.log` for events and blocklist actions.

## Switching Modes
- Change the `mode` field in your config to switch between UDP, DoT, and DoH.
- For DoT, use a hostname for upstream for best security.

## Blocklists
- Blocklists are loaded at startup from the URLs in your config.
- You can add or remove blocklists by editing the config.

## Root Hints
- Root hints are fetched and refreshed automatically.
- Used for fallback if upstream DNS fails.

## Running as a systemd Service
1. Copy your binary to `/usr/bin/zigdns`.
2. Create `/etc/systemd/system/zigdns.service` (see README for example).
3. Reload systemd and start:
   ```sh
   sudo systemctl daemon-reload
   sudo systemctl enable zendns
   sudo systemctl start zendns
   sudo systemctl status zendns
   ```

## Security
- For DoT, always use a hostname for upstream for proper TLS validation.
- If you use an IP, cert validation may fail unless the cert matches the IP.

## Troubleshooting
- If you see certificate errors with DoT, try using a hostname for upstream.
- Check `zigdns.log` for blocklist and resolver events.

## Architecture
- Async event loop for high performance.
- LRU cache for DNS responses.
- Connection pooling for DoT/DoH.
- Modular design for easy extension.

## Contributing
PRs and issues welcome! See [README.md](README.md) for project overview.
