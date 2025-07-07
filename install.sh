#!/bin/bash
#
# ZigDNS One-liner Installation Script
# Usage: curl -sSL https://your-domain.com/install.sh | bash
# Or: bash <(curl -sSL https://your-domain.com/install.sh)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
ZDNS_VERSION="1.0.0"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/zdns"
SERVICE_DIR="/etc/systemd/system"
GITHUB_REPO="your-username/zigdns"  # Update this
ZAUR_SERVER="https://zaur.your-domain.com"  # Update this

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64) echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *) 
            echo -e "${RED}❌ Unsupported architecture: $arch${NC}" >&2
            echo -e "${YELLOW}Supported: x86_64, aarch64${NC}" >&2
            exit 1
            ;;
    esac
}

# Detect distribution
detect_distro() {
    if [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ -f /etc/alpine-release ]]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Running as root${NC}"
        USE_SUDO=""
    else
        echo -e "${BLUE}🔐 Running as user, will use sudo${NC}"
        USE_SUDO="sudo"
        # Check if sudo is available
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}❌ sudo not found. Please run as root or install sudo${NC}" >&2
            exit 1
        fi
    fi
}

# Install via ZAUR (Arch Linux)
install_zaur() {
    echo -e "${PURPLE}📦 Installing from ZAUR (custom AUR server)${NC}"
    
    # Check if yay is installed
    if command -v yay &> /dev/null; then
        echo -e "${GREEN}✅ Using yay${NC}"
        yay -S zdns
    elif command -v paru &> /dev/null; then
        echo -e "${GREEN}✅ Using paru${NC}"
        paru -S zdns
    elif command -v pamac &> /dev/null; then
        echo -e "${GREEN}✅ Using pamac${NC}"
        pamac install zdns
    else
        echo -e "${YELLOW}⚠️  No AUR helper found, using manual method${NC}"
        install_manual_arch
    fi
}

# Manual Arch installation
install_manual_arch() {
    echo -e "${BLUE}🔧 Manual Arch installation${NC}"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download PKGBUILD from ZAUR
    echo -e "${BLUE}📥 Downloading PKGBUILD...${NC}"
    curl -sSL "${ZAUR_SERVER}/packages/zdns/PKGBUILD" -o PKGBUILD
    curl -sSL "${ZAUR_SERVER}/packages/zdns/zdns.install" -o zdns.install
    
    # Download source
    curl -sSL "https://github.com/${GITHUB_REPO}/archive/v${ZDNS_VERSION}.tar.gz" -o "zdns-${ZDNS_VERSION}.tar.gz"
    
    # Build and install
    makepkg -si --noconfirm
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
}

# Install via binary download (non-Arch systems)
install_binary() {
    local arch=$(detect_arch)
    echo -e "${BLUE}📥 Installing ZigDNS v${ZDNS_VERSION} for ${arch}${NC}"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download binary
    echo -e "${BLUE}⬇️  Downloading binary...${NC}"
    curl -sSL "https://github.com/${GITHUB_REPO}/releases/download/v${ZDNS_VERSION}/zdns-${ZDNS_VERSION}-linux-${arch}.tar.gz" -o zdns.tar.gz
    
    # Extract and install
    tar -xzf zdns.tar.gz
    $USE_SUDO install -Dm755 zdns "$INSTALL_DIR/zdns"
    
    # Set capabilities
    echo -e "${BLUE}🔐 Setting capabilities...${NC}"
    $USE_SUDO setcap 'cap_net_bind_service=+ep' "$INSTALL_DIR/zdns" || {
        echo -e "${YELLOW}⚠️  Could not set capabilities. You may need to run as root for port 53${NC}"
    }
    
    # Create configuration directory
    echo -e "${BLUE}📁 Creating configuration directory...${NC}"
    $USE_SUDO mkdir -p "$CONFIG_DIR/certs"
    
    # Create systemd service
    echo -e "${BLUE}🔧 Installing systemd service...${NC}"
    $USE_SUDO tee "$SERVICE_DIR/zdns.service" > /dev/null << 'EOF'
[Unit]
Description=ZigDNS Resolver
After=network.target
Wants=network.target

[Service]
Type=simple
User=zdns
Group=zdns
ExecStart=/usr/local/bin/zdns start --daemon
Restart=always
RestartSec=5
LimitNOFILE=65536

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/zdns /var/lib/zdns
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Create zdns user
    echo -e "${BLUE}👤 Creating zdns user...${NC}"
    if ! getent group zdns > /dev/null 2>&1; then
        $USE_SUDO groupadd -r zdns
    fi
    if ! getent passwd zdns > /dev/null 2>&1; then
        $USE_SUDO useradd -r -g zdns -d /var/lib/zdns -s /bin/false zdns
        $USE_SUDO mkdir -p /var/lib/zdns
        $USE_SUDO chown zdns:zdns /var/lib/zdns
    fi
    
    # Set permissions
    $USE_SUDO chown -R zdns:zdns "$CONFIG_DIR"
    $USE_SUDO chmod 750 "$CONFIG_DIR"
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
}

# Install shell completions
install_completions() {
    echo -e "${BLUE}🔧 Installing shell completions...${NC}"
    
    # Bash completion
    if [[ -d /usr/share/bash-completion/completions ]]; then
        $USE_SUDO tee /usr/share/bash-completion/completions/zdns > /dev/null << 'EOF'
_zdns() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    if [[ ${COMP_CWORD} == 1 ]]; then
        opts="help version start query flush stats test-web3 config set"
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    elif [[ ${prev} == "--protocol" ]]; then
        COMPREPLY=( $(compgen -W "udp dot doh doq" -- ${cur}) )
    fi
}
complete -F _zdns zdns
EOF
    fi
    
    # Zsh completion
    if [[ -d /usr/share/zsh/site-functions ]]; then
        $USE_SUDO tee /usr/share/zsh/site-functions/_zdns > /dev/null << 'EOF'
#compdef zdns

_zdns() {
    local -a commands
    commands=(
        'help:Show help information'
        'version:Show version information'
        'start:Start the DNS server'
        'query:Query a domain'
        'flush:Clear DNS cache'
        'stats:Show statistics'
        'test-web3:Test Web3 functionality'
        'config:Show configuration'
        'set:Set configuration value'
    )
    
    _arguments -C \
        '--verbose[Enable verbose output]' \
        '--quiet[Suppress non-error output]' \
        '--daemon[Run as daemon]' \
        '--port=[Set port]:port:' \
        '--protocol=[Set protocol]:protocol:(udp dot doh doq)' \
        '--upstream=[Set upstream server]:server:' \
        '--no-web3[Disable Web3 support]' \
        '--no-blocklist[Disable blocking]' \
        '1: :->commands' \
        '*:: :->args'
    
    case $state in
        commands)
            _describe 'zdns commands' commands
            ;;
    esac
}

_zdns "$@"
EOF
    fi
}

# Main installation function
main() {
    echo -e "${GREEN}🚀 ZigDNS Installation Script${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    
    # Detect system
    local distro=$(detect_distro)
    local arch=$(detect_arch)
    
    echo -e "${BLUE}🔍 Detected: ${distro} (${arch})${NC}"
    
    # Check permissions
    check_root
    
    # Install based on distribution
    case $distro in
        arch)
            echo -e "${PURPLE}🎯 Arch Linux detected${NC}"
            install_zaur
            ;;
        *)
            echo -e "${BLUE}🐧 Generic Linux installation${NC}"
            install_binary
            install_completions
            ;;
    esac
    
    # Final setup
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo
    echo -e "${YELLOW}🎉 ZigDNS is now installed!${NC}"
    echo
    echo -e "${BLUE}Quick start:${NC}"
    echo -e "  ${GREEN}zdns help${NC}           # Show help"
    echo -e "  ${GREEN}zdns version${NC}        # Show version"
    echo -e "  ${GREEN}zdns start${NC}          # Start DNS server"
    echo -e "  ${GREEN}zdns start --port=5353${NC}  # Start on port 5353"
    echo
    echo -e "${BLUE}As a service:${NC}"
    echo -e "  ${GREEN}sudo systemctl enable zdns${NC}"
    echo -e "  ${GREEN}sudo systemctl start zdns${NC}"
    echo
    echo -e "${BLUE}Web3 domains:${NC}"
    echo -e "  ${GREEN}zdns query vitalik.eth${NC}"
    echo -e "  ${GREEN}zdns test-web3${NC}"
    echo
    echo -e "${BLUE}Documentation:${NC}"
    if [[ $distro == "arch" ]]; then
        echo -e "  ${GREEN}/usr/share/doc/zdns/${NC}"
    else
        echo -e "  ${GREEN}https://github.com/${GITHUB_REPO}${NC}"
    fi
    echo
}

# Handle signals
trap 'echo -e "\n${RED}❌ Installation interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@"