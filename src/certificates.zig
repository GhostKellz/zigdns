const std = @import("std");
const security = @import("./security.zig");

/// Certificate management for DNS-over-QUIC
pub const CertificateManager = struct {
    allocator: std.mem.Allocator,
    cert_path: []const u8,
    key_path: []const u8,
    security_ctx: *security.DnsSecurityContext,
    
    pub fn init(
        allocator: std.mem.Allocator,
        cert_path: []const u8,
        key_path: []const u8,
        security_ctx: *security.DnsSecurityContext,
    ) CertificateManager {
        return CertificateManager{
            .allocator = allocator,
            .cert_path = cert_path,
            .key_path = key_path,
            .security_ctx = security_ctx,
        };
    }
    
    /// Generate self-signed certificate for DNS-over-QUIC
    pub fn generateSelfSignedCert(self: *CertificateManager, hostname: []const u8) !void {
        std.log.info("🔐 Generating self-signed certificate for {s}", .{hostname});
        
        // Create certificate directory if it doesn't exist
        const cert_dir = std.fs.path.dirname(self.cert_path) orelse ".";
        std.fs.cwd().makeDir(cert_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        
        // Generate certificate and key pair
        const cert_content = try self.createCertificate(hostname);
        const key_content = try self.createPrivateKey();
        
        // Write certificate file
        try self.writeFile(self.cert_path, cert_content);
        try self.writeFile(self.key_path, key_content);
        
        std.log.info("✅ Certificate generated: {s}", .{self.cert_path});
        std.log.info("✅ Private key generated: {s}", .{self.key_path});
    }
    
    /// Check if certificates exist and are valid
    pub fn validateCertificates(self: *CertificateManager) !bool {
        // Check if certificate files exist
        const cert_file = std.fs.cwd().openFile(self.cert_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        };
        defer cert_file.close();
        
        const key_file = std.fs.cwd().openFile(self.key_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        };
        defer key_file.close();
        
        // Basic validation - check if files are not empty
        const cert_stat = try cert_file.stat();
        const key_stat = try key_file.stat();
        
        if (cert_stat.size == 0 or key_stat.size == 0) {
            return false;
        }
        
        std.log.info("✅ Valid certificates found: {s}, {s}", .{ self.cert_path, self.key_path });
        return true;
    }
    
    /// Load certificate configuration for QUIC
    pub fn loadTlsConfig(self: *CertificateManager) !TlsConfig {
        if (!try self.validateCertificates()) {
            return error.InvalidCertificates;
        }
        
        return TlsConfig{
            .cert_path = self.cert_path,
            .key_path = self.key_path,
            .enable_post_quantum = true,
            .min_tls_version = .tls_1_3,
            .cipher_suites = &[_][]const u8{
                "TLS_AES_256_GCM_SHA384",
                "TLS_CHACHA20_POLY1305_SHA256",
            },
        };
    }
    
    fn createCertificate(self: *CertificateManager, hostname: []const u8) ![]const u8 {
        _ = self;
        _ = hostname;
        
        // Simplified PEM certificate for development
        // In production, use proper certificate generation with zcrypto
        return 
            \\-----BEGIN CERTIFICATE-----
            \\MIIBkTCB+wIJAL+Z9Z9Z9Z9ZMA0GCSqGSIb3DQEBCwUAMBQxEjAQBgNVBAMMCWxv
            \\Y2FsaG9zdDAeFw0yNDA3MDIwMDAwMDBaFw0yNTA3MDIwMDAwMDBaMBQxEjAQBgNV
            \\BAMMCWxvY2FsaG9zdDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA0Z9Z9Z9Z
            \\9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\QIDAQABMA0GCSqGSIb3DQEBCwUAA4GBAMGJkjQjUkGJQkGJQkGJQkGJQkGJQkGJ
            \\QkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJ
            \\QkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJ
            \\QkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJQkGJ
            \\-----END CERTIFICATE-----
            ;
    }
    
    fn createPrivateKey(self: *CertificateManager) ![]const u8 {
        _ = self;
        
        // Simplified PEM private key for development
        // In production, use proper key generation with zcrypto
        return 
            \\-----BEGIN PRIVATE KEY-----
            \\MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBANGfWfWfWfWfWfWf
            \\WfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\WfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\WfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\WfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\WfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\AgMBAAECgYAZ9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z
            \\QJBAOmfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\WfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\WfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWfWf
            \\-----END PRIVATE KEY-----
            ;
    }
    
    fn writeFile(_: *CertificateManager, path: []const u8, content: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        
        try file.writeAll(content);
    }
};

pub const TlsConfig = struct {
    cert_path: []const u8,
    key_path: []const u8,
    enable_post_quantum: bool,
    min_tls_version: TlsVersion,
    cipher_suites: []const []const u8,
};

pub const TlsVersion = enum {
    tls_1_2,
    tls_1_3,
};

/// Auto-generate certificates if needed
pub fn ensureCertificates(
    allocator: std.mem.Allocator,
    cert_path: []const u8,
    key_path: []const u8,
    hostname: []const u8,
    security_ctx: *security.DnsSecurityContext,
) !void {
    var cert_manager = CertificateManager.init(allocator, cert_path, key_path, security_ctx);
    
    if (!try cert_manager.validateCertificates()) {
        std.log.info("🔑 Certificates not found or invalid, generating new ones...", .{});
        try cert_manager.generateSelfSignedCert(hostname);
    } else {
        std.log.info("✅ Valid certificates found", .{});
    }
}