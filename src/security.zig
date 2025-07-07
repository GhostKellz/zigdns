const std = @import("std");
const zcrypto = @import("zcrypto");

/// Post-quantum security context for DNS operations
pub const DnsSecurityContext = struct {
    allocator: std.mem.Allocator,
    ml_kem: zcrypto.ml_kem.MlKem768,
    ml_dsa: zcrypto.ml_dsa.MlDsa65,
    sha3: zcrypto.sha3.Sha3_256,
    
    // Key pairs for DNS operations
    signing_keys: ?KeyPair = null,
    kem_keys: ?KeyPair = null,
    
    pub fn init(allocator: std.mem.Allocator) !DnsSecurityContext {
        return DnsSecurityContext{
            .allocator = allocator,
            .ml_kem = zcrypto.ml_kem.MlKem768.init(),
            .ml_dsa = zcrypto.ml_dsa.MlDsa65.init(),
            .sha3 = zcrypto.sha3.Sha3_256.init(),
        };
    }
    
    pub fn deinit(self: *DnsSecurityContext) void {
        // Clean up sensitive data
        if (self.signing_keys) |keys| {
            std.crypto.utils.secureZero(u8, keys.secret_key);
            self.allocator.free(keys.secret_key);
            self.allocator.free(keys.public_key);
        }
        if (self.kem_keys) |keys| {
            std.crypto.utils.secureZero(u8, keys.secret_key);
            self.allocator.free(keys.secret_key);
            self.allocator.free(keys.public_key);
        }
    }
    
    /// Generate key pair for digital signatures (DNSSEC)
    pub fn generateSigningKeys(self: *DnsSecurityContext) !void {
        const pk = try self.allocator.alloc(u8, zcrypto.ml_dsa.PUBLIC_KEY_BYTES);
        const sk = try self.allocator.alloc(u8, zcrypto.ml_dsa.SECRET_KEY_BYTES);
        
        try self.ml_dsa.generateKeyPair(pk, sk);
        
        self.signing_keys = KeyPair{
            .public_key = pk,
            .secret_key = sk,
        };
    }
    
    /// Generate key pair for key encapsulation (secure channels)
    pub fn generateKemKeys(self: *DnsSecurityContext) !void {
        const pk = try self.allocator.alloc(u8, zcrypto.ml_kem.PUBLIC_KEY_BYTES);
        const sk = try self.allocator.alloc(u8, zcrypto.ml_kem.SECRET_KEY_BYTES);
        
        try self.ml_kem.generateKeyPair(pk, sk);
        
        self.kem_keys = KeyPair{
            .public_key = pk,
            .secret_key = sk,
        };
    }
    
    /// Sign DNS message with post-quantum digital signature
    pub fn signDnsMessage(
        self: *DnsSecurityContext,
        message: []const u8,
    ) ![]u8 {
        if (self.signing_keys == null) {
            try self.generateSigningKeys();
        }
        
        // Hash the message
        var hash: [32]u8 = undefined;
        self.sha3.hash(message, &hash);
        
        // Sign with ML-DSA
        const signature = try self.allocator.alloc(u8, zcrypto.ml_dsa.SIGNATURE_BYTES);
        try self.ml_dsa.sign(signature, &hash, self.signing_keys.?.secret_key);
        
        return signature;
    }
    
    /// Verify DNS message signature
    pub fn verifyDnsMessage(
        self: *DnsSecurityContext,
        message: []const u8,
        signature: []const u8,
        public_key: []const u8,
    ) !bool {
        // Hash the message
        var hash: [32]u8 = undefined;
        self.sha3.hash(message, &hash);
        
        // Verify with ML-DSA
        return self.ml_dsa.verify(signature, &hash, public_key);
    }
    
    /// Encrypt data for secure DNS transport
    pub fn encryptDnsData(
        self: *DnsSecurityContext,
        data: []const u8,
        recipient_public_key: []const u8,
    ) !EncryptedData {
        if (self.kem_keys == null) {
            try self.generateKemKeys();
        }
        
        // Encapsulate shared secret
        const ciphertext = try self.allocator.alloc(u8, zcrypto.ml_kem.CIPHERTEXT_BYTES);
        const shared_secret = try self.allocator.alloc(u8, zcrypto.ml_kem.SHARED_SECRET_BYTES);
        defer {
            std.crypto.utils.secureZero(u8, shared_secret);
            self.allocator.free(shared_secret);
        }
        
        try self.ml_kem.encapsulate(ciphertext, shared_secret, recipient_public_key);
        
        // Use shared secret to encrypt data (AES-GCM)
        const encrypted_data = try self.allocator.alloc(u8, data.len + 16); // +16 for GCM tag
        const key = shared_secret[0..32]; // Use first 32 bytes as AES key
        const nonce = shared_secret[32..44]; // Use next 12 bytes as nonce
        
        const aes = std.crypto.aead.aes_gcm.Aes256Gcm.init(key.*);
        aes.encrypt(encrypted_data[0..data.len], encrypted_data[data.len..], data, "", nonce.*);
        
        return EncryptedData{
            .ciphertext = ciphertext,
            .encrypted_data = encrypted_data,
        };
    }
    
    /// Decrypt DNS data
    pub fn decryptDnsData(
        self: *DnsSecurityContext,
        encrypted: EncryptedData,
    ) ![]u8 {
        if (self.kem_keys == null) {
            return error.NoKeys;
        }
        
        // Decapsulate shared secret
        const shared_secret = try self.allocator.alloc(u8, zcrypto.ml_kem.SHARED_SECRET_BYTES);
        defer {
            std.crypto.utils.secureZero(u8, shared_secret);
            self.allocator.free(shared_secret);
        }
        
        try self.ml_kem.decapsulate(shared_secret, encrypted.ciphertext, self.kem_keys.?.secret_key);
        
        // Decrypt data
        const decrypted_data = try self.allocator.alloc(u8, encrypted.encrypted_data.len - 16);
        const key = shared_secret[0..32];
        const nonce = shared_secret[32..44];
        
        const aes = std.crypto.aead.aes_gcm.Aes256Gcm.init(key.*);
        aes.decrypt(
            decrypted_data,
            encrypted.encrypted_data[0..decrypted_data.len],
            encrypted.encrypted_data[decrypted_data.len..],
            "",
            nonce.*
        ) catch return error.DecryptionFailed;
        
        return decrypted_data;
    }
    
    /// Create secure hash of DNS data
    pub fn hashDnsData(self: *DnsSecurityContext, data: []const u8) [32]u8 {
        var hash: [32]u8 = undefined;
        self.sha3.hash(data, &hash);
        return hash;
    }
};

pub const KeyPair = struct {
    public_key: []u8,
    secret_key: []u8,
};

pub const EncryptedData = struct {
    ciphertext: []u8,        // KEM ciphertext
    encrypted_data: []u8,    // Encrypted payload
};

/// Secure DNS cache with post-quantum signatures
pub const SecureDnsCache = struct {
    ctx: *DnsSecurityContext,
    cache: std.StringHashMap(SecureCacheEntry),
    
    const SecureCacheEntry = struct {
        data: []const u8,
        signature: []const u8,
        timestamp: i64,
        ttl: u32,
    };
    
    pub fn init(ctx: *DnsSecurityContext) SecureDnsCache {
        return SecureDnsCache{
            .ctx = ctx,
            .cache = std.StringHashMap(SecureCacheEntry).init(ctx.allocator),
        };
    }
    
    pub fn deinit(self: *SecureDnsCache) void {
        var iterator = self.cache.iterator();
        while (iterator.next()) |entry| {
            self.ctx.allocator.free(entry.value_ptr.data);
            self.ctx.allocator.free(entry.value_ptr.signature);
        }
        self.cache.deinit();
    }
    
    pub fn store(
        self: *SecureDnsCache,
        key: []const u8,
        data: []const u8,
        ttl: u32,
    ) !void {
        // Sign the data
        const signature = try self.ctx.signDnsMessage(data);
        
        const entry = SecureCacheEntry{
            .data = try self.ctx.allocator.dupe(u8, data),
            .signature = signature,
            .timestamp = std.time.timestamp(),
            .ttl = ttl,
        };
        
        try self.cache.put(key, entry);
    }
    
    pub fn retrieve(
        self: *SecureDnsCache,
        key: []const u8,
    ) !?[]const u8 {
        const entry = self.cache.get(key) orelse return null;
        
        // Check expiry
        const now = std.time.timestamp();
        if (now > entry.timestamp + entry.ttl) {
            _ = self.cache.remove(key);
            return null;
        }
        
        // Verify signature
        const valid = try self.ctx.verifyDnsMessage(
            entry.data,
            entry.signature,
            self.ctx.signing_keys.?.public_key,
        );
        
        if (!valid) {
            _ = self.cache.remove(key);
            return error.InvalidSignature;
        }
        
        return entry.data;
    }
};

/// DNS packet with post-quantum security
pub const SecureDnsPacket = struct {
    original_data: []const u8,
    signature: []const u8,
    timestamp: i64,
    security_level: SecurityLevel,
    
    pub const SecurityLevel = enum {
        none,
        traditional,
        post_quantum,
    };
    
    pub fn create(
        ctx: *DnsSecurityContext,
        data: []const u8,
        level: SecurityLevel,
    ) !SecureDnsPacket {
        const signature = switch (level) {
            .none => &[_]u8{},
            .traditional => &[_]u8{}, // TODO: Implement traditional crypto
            .post_quantum => try ctx.signDnsMessage(data),
        };
        
        return SecureDnsPacket{
            .original_data = data,
            .signature = signature,
            .timestamp = std.time.timestamp(),
            .security_level = level,
        };
    }
    
    pub fn verify(
        self: *const SecureDnsPacket,
        ctx: *DnsSecurityContext,
        public_key: []const u8,
    ) !bool {
        return switch (self.security_level) {
            .none => true,
            .traditional => true, // TODO: Implement traditional verification
            .post_quantum => ctx.verifyDnsMessage(
                self.original_data,
                self.signature,
                public_key,
            ),
        };
    }
};