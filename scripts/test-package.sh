#!/bin/bash
#
# Test ZigDNS package locally
#

set -euo pipefail

# Configuration
PROJECT_NAME="zdns"
VERSION="1.0.0"
TEST_DIR="/tmp/zdns-test"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🧪 Testing ZigDNS Package${NC}"
echo -e "${BLUE}=========================${NC}"

# Clean test directory
if [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
fi
mkdir -p "$TEST_DIR"

# Function to test source package
test_source_package() {
    echo -e "${BLUE}🔨 Testing source package...${NC}"
    
    cd "$TEST_DIR"
    cp ../PKGBUILD .
    cp ../zdns.install .
    
    # Create source tarball
    echo -e "${YELLOW}📦 Creating source tarball...${NC}"
    cd ..
    git archive --format=tar.gz --prefix="${PROJECT_NAME}-${VERSION}/" HEAD > "$TEST_DIR/${PROJECT_NAME}-${VERSION}.tar.gz"
    cd "$TEST_DIR"
    
    # Test build
    echo -e "${YELLOW}🏗️  Testing build...${NC}"
    if makepkg -f --noextract; then
        echo -e "${GREEN}✅ Source package builds successfully${NC}"
        
        # Test installation
        echo -e "${YELLOW}📦 Testing installation...${NC}"
        if sudo pacman -U --noconfirm "${PROJECT_NAME}-${VERSION}-1-$(uname -m).pkg.tar.zst"; then
            echo -e "${GREEN}✅ Package installs successfully${NC}"
            
            # Test functionality
            test_functionality
            
            # Remove package
            sudo pacman -R --noconfirm "$PROJECT_NAME"
        else
            echo -e "${RED}❌ Package installation failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Source package build failed${NC}"
        return 1
    fi
}

# Function to test binary package
test_binary_package() {
    echo -e "${BLUE}📦 Testing binary package...${NC}"
    
    cd "$TEST_DIR"
    cp ../PKGBUILD-bin PKGBUILD
    cp ../zdns.install .
    
    # Create mock binary release
    echo -e "${YELLOW}📦 Creating mock binary release...${NC}"
    mkdir -p "mock-release"
    
    # Build actual binary for testing
    cd ..
    zig build -Doptimize=ReleaseFast
    cd "$TEST_DIR"
    
    # Copy files to mock release
    cp ../zig-out/bin/zdns mock-release/
    cp ../README.md ../DOCS.md ../COMMANDS.md mock-release/
    cp ../packaging/* mock-release/
    
    # Create LICENSE if not exists
    if [[ ! -f ../LICENSE ]]; then
        cat > mock-release/LICENSE << 'EOF'
MIT License

Copyright (c) 2024 ZigDNS Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
    else
        cp ../LICENSE mock-release/
    fi
    
    # Create tarball
    tar -czf "${PROJECT_NAME}-${VERSION}-linux-$(uname -m).tar.gz" -C mock-release .
    
    # Update PKGBUILD to use local file
    sed -i "s|^source_.*=.*|source=(\"${PROJECT_NAME}-${VERSION}-linux-$(uname -m).tar.gz\")|" PKGBUILD
    sed -i "s|^sha256sums_.*=.*|sha256sums=('SKIP')|" PKGBUILD
    
    # Test build
    echo -e "${YELLOW}🏗️  Testing build...${NC}"
    if makepkg -f; then
        echo -e "${GREEN}✅ Binary package builds successfully${NC}"
        
        # Test installation
        echo -e "${YELLOW}📦 Testing installation...${NC}"
        if sudo pacman -U --noconfirm "${PROJECT_NAME}-bin-${VERSION}-1-$(uname -m).pkg.tar.zst"; then
            echo -e "${GREEN}✅ Package installs successfully${NC}"
            
            # Test functionality
            test_functionality
            
            # Remove package
            sudo pacman -R --noconfirm "${PROJECT_NAME}-bin"
        else
            echo -e "${RED}❌ Package installation failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Binary package build failed${NC}"
        return 1
    fi
}

# Function to test functionality
test_functionality() {
    echo -e "${BLUE}🧪 Testing functionality...${NC}"
    
    # Test binary exists
    if command -v zdns &> /dev/null; then
        echo -e "${GREEN}✅ zdns binary is available${NC}"
    else
        echo -e "${RED}❌ zdns binary not found${NC}"
        return 1
    fi
    
    # Test help
    if zdns help &> /dev/null; then
        echo -e "${GREEN}✅ Help command works${NC}"
    else
        echo -e "${RED}❌ Help command failed${NC}"
        return 1
    fi
    
    # Test version
    if zdns version &> /dev/null; then
        echo -e "${GREEN}✅ Version command works${NC}"
    else
        echo -e "${RED}❌ Version command failed${NC}"
        return 1
    fi
    
    # Test config
    if zdns config &> /dev/null; then
        echo -e "${GREEN}✅ Config command works${NC}"
    else
        echo -e "${RED}❌ Config command failed${NC}"
        return 1
    fi
    
    # Test Web3 functionality
    if zdns test-web3 &> /dev/null; then
        echo -e "${GREEN}✅ Web3 test works${NC}"
    else
        echo -e "${RED}❌ Web3 test failed${NC}"
        return 1
    fi
    
    # Test systemd service
    if [[ -f /usr/lib/systemd/system/zdns.service ]]; then
        echo -e "${GREEN}✅ Systemd service installed${NC}"
    else
        echo -e "${RED}❌ Systemd service not found${NC}"
        return 1
    fi
    
    # Test configuration file
    if [[ -f /etc/zdns/config.toml ]]; then
        echo -e "${GREEN}✅ Configuration file installed${NC}"
    else
        echo -e "${RED}❌ Configuration file not found${NC}"
        return 1
    fi
    
    # Test completions
    if [[ -f /usr/share/bash-completion/completions/zdns ]]; then
        echo -e "${GREEN}✅ Bash completion installed${NC}"
    else
        echo -e "${RED}❌ Bash completion not found${NC}"
        return 1
    fi
    
    # Test man page
    if [[ -f /usr/share/man/man1/zdns.1 ]]; then
        echo -e "${GREEN}✅ Man page installed${NC}"
    else
        echo -e "${RED}❌ Man page not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 All functionality tests passed!${NC}"
}

# Main menu
echo -e "${BLUE}Choose test:${NC}"
echo -e "1. Test source package (zdns)"
echo -e "2. Test binary package (zdns-bin)"
echo -e "3. Test both packages"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        test_source_package
        ;;
    2)
        test_binary_package
        ;;
    3)
        test_source_package
        echo -e "${BLUE}────────────────────────────────${NC}"
        test_binary_package
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 Package testing complete!${NC}"