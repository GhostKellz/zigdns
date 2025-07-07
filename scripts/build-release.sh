#!/bin/bash
#
# Build release binaries for ZigDNS
#

set -euo pipefail

# Configuration
PROJECT_NAME="zdns"
VERSION="1.0.0"
BUILD_DIR="build"
RELEASE_DIR="release"
ARCHITECTURES=("x86_64" "aarch64")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🏗️  Building ZigDNS v${VERSION} Release Binaries${NC}"
echo -e "${BLUE}===============================================${NC}"

# Clean previous builds
if [[ -d "$BUILD_DIR" ]]; then
    echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
    rm -rf "$BUILD_DIR"
fi

if [[ -d "$RELEASE_DIR" ]]; then
    echo -e "${YELLOW}🧹 Cleaning previous releases...${NC}"
    rm -rf "$RELEASE_DIR"
fi

mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

# Build for each architecture
for arch in "${ARCHITECTURES[@]}"; do
    echo -e "${BLUE}🔨 Building for ${arch}...${NC}"
    
    # Set Zig target
    case $arch in
        x86_64)
            zig_target="x86_64-linux-gnu"
            ;;
        aarch64)
            zig_target="aarch64-linux-gnu"
            ;;
    esac
    
    # Build directory for this architecture
    arch_build_dir="$BUILD_DIR/$arch"
    mkdir -p "$arch_build_dir"
    
    # Build the binary
    echo -e "${YELLOW}  📦 Compiling ${PROJECT_NAME} for ${arch}...${NC}"
    zig build -Doptimize=ReleaseFast -Dtarget="$zig_target" --prefix "$arch_build_dir"
    
    # Create release package
    echo -e "${YELLOW}  📦 Creating release package...${NC}"
    package_dir="$RELEASE_DIR/${PROJECT_NAME}-${VERSION}-linux-${arch}"
    mkdir -p "$package_dir"
    
    # Copy binary
    cp "$arch_build_dir/bin/zdns" "$package_dir/"
    
    # Copy documentation
    cp README.md DOCS.md COMMANDS.md "$package_dir/"
    
    # Copy packaging files
    cp packaging/zdns.service "$package_dir/"
    cp packaging/config.toml "$package_dir/"
    cp packaging/zdns.1 "$package_dir/"
    cp packaging/zdns.bash "$package_dir/"
    cp packaging/zdns.zsh "$package_dir/"
    
    # Copy license (create if doesn't exist)
    if [[ ! -f LICENSE ]]; then
        cat > "$package_dir/LICENSE" << 'EOF'
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
        cp LICENSE "$package_dir/"
    fi
    
    # Create tarball
    echo -e "${YELLOW}  📦 Creating tarball...${NC}"
    cd "$RELEASE_DIR"
    tar -czf "${PROJECT_NAME}-${VERSION}-linux-${arch}.tar.gz" "${PROJECT_NAME}-${VERSION}-linux-${arch}"
    cd ..
    
    # Calculate checksums
    echo -e "${YELLOW}  🔐 Calculating checksums...${NC}"
    cd "$RELEASE_DIR"
    sha256sum "${PROJECT_NAME}-${VERSION}-linux-${arch}.tar.gz" >> "${PROJECT_NAME}-${VERSION}-checksums.txt"
    cd ..
    
    echo -e "${GREEN}  ✅ ${arch} build complete${NC}"
done

# Create source tarball
echo -e "${BLUE}📦 Creating source tarball...${NC}"
git archive --format=tar.gz --prefix="${PROJECT_NAME}-${VERSION}/" HEAD > "$RELEASE_DIR/${PROJECT_NAME}-${VERSION}.tar.gz"

# Calculate source checksum
cd "$RELEASE_DIR"
sha256sum "${PROJECT_NAME}-${VERSION}.tar.gz" >> "${PROJECT_NAME}-${VERSION}-checksums.txt"
cd ..

# Display results
echo -e "${GREEN}🎉 Release build complete!${NC}"
echo -e "${BLUE}Files created:${NC}"
ls -la "$RELEASE_DIR"

echo -e "${BLUE}📋 Checksums:${NC}"
cat "$RELEASE_DIR/${PROJECT_NAME}-${VERSION}-checksums.txt"

echo -e "${YELLOW}📝 Next steps:${NC}"
echo -e "1. Upload release files to GitHub releases"
echo -e "2. Update PKGBUILD-bin with correct checksums"
echo -e "3. Submit to AUR as zdns-bin"
echo -e "4. Update install.sh script URLs"