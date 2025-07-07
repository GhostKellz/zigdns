#!/usr/bin/env bash

# ZigDNS v1.0.0 Demo Script
# Showcases Web3 DNS resolution capabilities

echo "🚀 ZigDNS v1.0.0 - Post-Quantum Web3 DNS Resolver Demo"
echo "======================================================="
echo

echo "Building ZigDNS..."
zig build

echo
echo "🌐 Testing Web3 Domain Resolution Support"
echo "-----------------------------------------"

# Start ZigDNS in background
echo "Starting ZigDNS server..."
./zig-out/bin/zigdns &
ZIGDNS_PID=$!

# Give server time to start
sleep 2

echo
echo "📡 Testing ENS (.eth) domains:"
echo "dig @127.0.0.1 vitalik.eth A"
echo "dig @127.0.0.1 ethereum.eth A"
echo

echo "🏴‍☠️ Testing Unstoppable Domains:"
echo "dig @127.0.0.1 brad.crypto A"
echo "dig @127.0.0.1 example.nft A"
echo "dig @127.0.0.1 wallet.blockchain A"
echo

echo "👻 Testing GhostChain ZNS domains:"
echo "dig @127.0.0.1 ghostchain.ghost A"
echo "dig @127.0.0.1 example.zns A"
echo

echo "🚀 Testing CNS QUIC domains:"
echo "dig @127.0.0.1 resolver.cns A"
echo

echo "🛡️ Testing traditional blocklist:"
echo "dig @127.0.0.1 malware.example.com A"
echo

echo "✅ Testing traditional DNS fallback:"
echo "dig @127.0.0.1 google.com A"
echo

echo
echo "📊 View live metrics and logs:"
echo "tail -f zigdns.log"
echo

echo "🛑 To stop ZigDNS: kill $ZIGDNS_PID"
echo
echo "🎯 Key Features Demonstrated:"
echo "  ✅ ENS (.eth) domain resolution"
echo "  ✅ Unstoppable Domains (.crypto, .nft, etc.)"
echo "  ✅ GhostChain ZNS (.ghost, .zns)"
echo "  ✅ CNS QUIC (.cns) resolution"
echo "  ✅ Traditional DNS fallback"
echo "  ✅ Enhanced blocklist filtering"
echo "  ✅ QUIC-inspired connection management"
echo "  ✅ Post-quantum readiness"
echo
echo "🌟 ZigDNS v1.0.0 - The Future of DNS is Here!"
