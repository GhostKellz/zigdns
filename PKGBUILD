# Maintainer: Your Name <your.email@example.com>
pkgname=zdns
pkgver=1.0.0
pkgrel=1
pkgdesc="Advanced DNS resolver with Web3 support and post-quantum cryptography"
arch=('x86_64' 'aarch64')
url="https://github.com/your-username/zigdns"
license=('MIT')
depends=('glibc')
makedepends=('zig>=0.15.0')
provides=('zdns')
conflicts=('zdns')
backup=('etc/zdns/config.toml')
install=zdns.install
source=("$pkgname-$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
    cd "$srcdir/$pkgname-$pkgver"
    zig build -Doptimize=ReleaseFast
}

check() {
    cd "$srcdir/$pkgname-$pkgver"
    zig build test
}

package() {
    cd "$srcdir/$pkgname-$pkgver"
    
    # Install binary
    install -Dm755 "zig-out/bin/zdns" "$pkgdir/usr/bin/zdns"
    
    # Install systemd service
    install -Dm644 "$srcdir/$pkgname-$pkgver/packaging/zdns.service" "$pkgdir/usr/lib/systemd/system/zdns.service"
    
    # Install configuration directory
    install -dm755 "$pkgdir/etc/zdns"
    install -Dm644 "$srcdir/$pkgname-$pkgver/packaging/config.toml" "$pkgdir/etc/zdns/config.toml"
    
    # Install documentation
    install -Dm644 "$srcdir/$pkgname-$pkgver/README.md" "$pkgdir/usr/share/doc/$pkgname/README.md"
    install -Dm644 "$srcdir/$pkgname-$pkgver/DOCS.md" "$pkgdir/usr/share/doc/$pkgname/DOCS.md"
    install -Dm644 "$srcdir/$pkgname-$pkgver/COMMANDS.md" "$pkgdir/usr/share/doc/$pkgname/COMMANDS.md"
    
    # Install man page
    install -Dm644 "$srcdir/$pkgname-$pkgver/packaging/zdns.1" "$pkgdir/usr/share/man/man1/zdns.1"
    
    # Install shell completions
    install -Dm644 "$srcdir/$pkgname-$pkgver/packaging/zdns.bash" "$pkgdir/usr/share/bash-completion/completions/zdns"
    install -Dm644 "$srcdir/$pkgname-$pkgver/packaging/zdns.zsh" "$pkgdir/usr/share/zsh/site-functions/_zdns"
    
    # Install license
    install -Dm644 "$srcdir/$pkgname-$pkgver/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    
    # Create certificates directory
    install -dm755 "$pkgdir/etc/zdns/certs"
    
    # Create zdns user home directory
    install -dm755 "$pkgdir/var/lib/zdns"
}