#!/bin/bash
#
# Update AUR packages for ZigDNS
#

set -euo pipefail

# Configuration
PROJECT_NAME="zdns"
VERSION="1.0.0"
AUR_REPO_SOURCE="ssh://aur@aur.archlinux.org/zdns.git"
AUR_REPO_BIN="ssh://aur@aur.archlinux.org/zdns-bin.git"
TEMP_DIR="/tmp/aur-update"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}📦 Updating AUR packages for ZigDNS v${VERSION}${NC}"
echo -e "${BLUE}=============================================${NC}"

# Clean temp directory
if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
fi
mkdir -p "$TEMP_DIR"

# Function to update source package
update_source_package() {
    echo -e "${BLUE}📦 Updating source package (zdns)...${NC}"
    
    cd "$TEMP_DIR"
    git clone "$AUR_REPO_SOURCE" zdns
    cd zdns
    
    # Copy files
    cp ../../PKGBUILD .
    cp ../../zdns.install .
    
    # Update .SRCINFO
    makepkg --printsrcinfo > .SRCINFO
    
    # Commit changes
    git add .
    git commit -m "Update to v${VERSION}"
    
    echo -e "${YELLOW}📤 Ready to push source package. Run:${NC}"
    echo -e "  cd $TEMP_DIR/zdns && git push"
}

# Function to update binary package
update_binary_package() {
    echo -e "${BLUE}📦 Updating binary package (zdns-bin)...${NC}"
    
    cd "$TEMP_DIR"
    git clone "$AUR_REPO_BIN" zdns-bin
    cd zdns-bin
    
    # Copy files
    cp ../../PKGBUILD-bin PKGBUILD
    cp ../../zdns.install .
    
    # Update checksums from release
    if [[ -f "../../release/${PROJECT_NAME}-${VERSION}-checksums.txt" ]]; then
        echo -e "${YELLOW}📋 Updating checksums...${NC}"
        
        # Extract checksums
        x86_64_sum=$(grep "x86_64" "../../release/${PROJECT_NAME}-${VERSION}-checksums.txt" | cut -d' ' -f1)
        aarch64_sum=$(grep "aarch64" "../../release/${PROJECT_NAME}-${VERSION}-checksums.txt" | cut -d' ' -f1)
        
        # Update PKGBUILD
        sed -i "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${x86_64_sum}')/" PKGBUILD
        sed -i "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('${aarch64_sum}')/" PKGBUILD
        
        echo -e "${GREEN}✅ Checksums updated${NC}"
    else
        echo -e "${RED}❌ Checksums file not found. Run build-release.sh first${NC}"
        return 1
    fi
    
    # Update .SRCINFO
    makepkg --printsrcinfo > .SRCINFO
    
    # Commit changes
    git add .
    git commit -m "Update to v${VERSION}"
    
    echo -e "${YELLOW}📤 Ready to push binary package. Run:${NC}"
    echo -e "  cd $TEMP_DIR/zdns-bin && git push"
}

# Function to create initial AUR packages
create_aur_packages() {
    echo -e "${BLUE}🆕 Creating initial AUR packages...${NC}"
    
    # Create source package
    mkdir -p "$TEMP_DIR/zdns-new"
    cd "$TEMP_DIR/zdns-new"
    cp ../../PKGBUILD .
    cp ../../zdns.install .
    makepkg --printsrcinfo > .SRCINFO
    
    # Create binary package
    mkdir -p "$TEMP_DIR/zdns-bin-new"
    cd "$TEMP_DIR/zdns-bin-new"
    cp ../../PKGBUILD-bin PKGBUILD
    cp ../../zdns.install .
    
    # Update checksums if available
    if [[ -f "../../release/${PROJECT_NAME}-${VERSION}-checksums.txt" ]]; then
        x86_64_sum=$(grep "x86_64" "../../release/${PROJECT_NAME}-${VERSION}-checksums.txt" | cut -d' ' -f1)
        aarch64_sum=$(grep "aarch64" "../../release/${PROJECT_NAME}-${VERSION}-checksums.txt" | cut -d' ' -f1)
        
        sed -i "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${x86_64_sum}')/" PKGBUILD
        sed -i "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('${aarch64_sum}')/" PKGBUILD
    fi
    
    makepkg --printsrcinfo > .SRCINFO
    
    echo -e "${GREEN}✅ Initial AUR packages created in:${NC}"
    echo -e "  Source: $TEMP_DIR/zdns-new"
    echo -e "  Binary: $TEMP_DIR/zdns-bin-new"
    echo -e "${YELLOW}📤 Submit these to AUR manually${NC}"
}

# Main menu
echo -e "${BLUE}Choose action:${NC}"
echo -e "1. Update existing AUR packages"
echo -e "2. Create initial AUR packages"
echo -e "3. Update source package only"
echo -e "4. Update binary package only"
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        update_source_package
        update_binary_package
        ;;
    2)
        create_aur_packages
        ;;
    3)
        update_source_package
        ;;
    4)
        update_binary_package
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 AUR update process complete!${NC}"