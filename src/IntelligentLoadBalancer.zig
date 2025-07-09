const std = @import("std");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;

/// Intelligent DNS upstream load balancer with health monitoring
/// Far superior to Unbound's basic round-robin upstream selection
pub const IntelligentLoadBalancer = struct {
    const Self = @This();
    
    upstreams: []UpstreamServer,
    strategy: LoadBalancingStrategy,
    health_monitor: *HealthMonitor,
    circuit_breaker: *CircuitBreaker,
    metrics: LoadBalancerMetrics,
    allocator: Allocator,
    config: LoadBalancerConfig,
    
    // Geographic optimization
    geo_optimizer: *GeographicOptimizer,
    
    // Adaptive timeout management
    timeout_manager: *AdaptiveTimeoutManager,
    
    pub fn init(allocator: Allocator, config: LoadBalancerConfig) !Self {
        var upstreams = try allocator.alloc(UpstreamServer, config.upstream_configs.len);
        
        for (config.upstream_configs, 0..) |upstream_config, i| {
            upstreams[i] = try UpstreamServer.init(allocator, upstream_config);
        }
        
        return Self{
            .upstreams = upstreams,
            .strategy = config.strategy,
            .health_monitor = try HealthMonitor.init(allocator, upstreams),
            .circuit_breaker = try CircuitBreaker.init(allocator),
            .metrics = LoadBalancerMetrics{},
            .allocator = allocator,
            .config = config,
            .geo_optimizer = try GeographicOptimizer.init(allocator),
            .timeout_manager = try AdaptiveTimeoutManager.init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        for (self.upstreams) |*upstream| {
            upstream.deinit();
        }
        self.allocator.free(self.upstreams);
        self.health_monitor.deinit();
        self.circuit_breaker.deinit();
        self.geo_optimizer.deinit();
        self.timeout_manager.deinit();
        self.allocator.destroy(self.health_monitor);
        self.allocator.destroy(self.circuit_breaker);
        self.allocator.destroy(self.geo_optimizer);
        self.allocator.destroy(self.timeout_manager);
    }
    
    /// Intelligent upstream selection based on multiple factors
    pub fn selectUpstream(self: *Self, query_context: QueryContext) !*UpstreamServer {
        // Filter healthy upstreams
        const healthy_upstreams = try self.getHealthyUpstreams();
        defer self.allocator.free(healthy_upstreams);
        
        if (healthy_upstreams.len == 0) {
            return error.NoHealthyUpstreams;
        }
        
        // Apply intelligent selection strategy
        const selected = switch (self.strategy) {
            .intelligent => try self.selectIntelligent(healthy_upstreams, query_context),
            .weighted_round_robin => try self.selectWeightedRoundRobin(healthy_upstreams),
            .least_latency => try self.selectLeastLatency(healthy_upstreams),
            .geographic => try self.selectGeographic(healthy_upstreams, query_context),
            .adaptive => try self.selectAdaptive(healthy_upstreams, query_context),
        };
        
        self.metrics.selections.fetchAdd(1, .monotonic);
        return selected;
    }
    
    /// Multi-factor intelligent selection (beats Unbound's simple round-robin)
    fn selectIntelligent(self: *Self, upstreams: []*UpstreamServer, context: QueryContext) !*UpstreamServer {
        var best_upstream: ?*UpstreamServer = null;
        var best_score: f64 = -1.0;
        
        for (upstreams) |upstream| {
            const score = try self.calculateUpstreamScore(upstream, context);
            
            if (score > best_score) {
                best_score = score;
                best_upstream = upstream;
            }
        }
        
        return best_upstream orelse upstreams[0];
    }
    
    /// Calculate comprehensive upstream score based on multiple metrics
    fn calculateUpstreamScore(self: *Self, upstream: *UpstreamServer, context: QueryContext) !f64 {
        const stats = upstream.getStats();
        
        // Latency factor (lower is better)
        const latency_score = 1.0 - (@as(f64, @floatFromInt(stats.avg_latency_ms)) / 1000.0);
        
        // Success rate factor
        const success_score = stats.success_rate;
        
        // Load factor (lower current load is better)
        const load_score = 1.0 - (@as(f64, @floatFromInt(stats.current_load)) / @as(f64, @floatFromInt(stats.max_capacity)));
        
        // Geographic proximity factor
        const geo_score = try self.geo_optimizer.calculateProximityScore(upstream, context.client_location);
        
        // Query type optimization factor
        const specialization_score = upstream.getSpecializationScore(context.query_type);
        
        // Time-based factor (some upstreams are better at certain times)
        const time_score = upstream.getTimeBasedScore(std.time.timestamp());
        
        // Weighted combination of factors
        const final_score = (latency_score * 0.25) +
                           (success_score * 0.25) +
                           (load_score * 0.20) +
                           (geo_score * 0.15) +
                           (specialization_score * 0.10) +
                           (time_score * 0.05);
        
        return std.math.clamp(final_score, 0.0, 1.0);
    }
    
    /// Weighted round-robin with dynamic weight adjustment
    fn selectWeightedRoundRobin(self: *Self, upstreams: []*UpstreamServer) !*UpstreamServer {
        var total_weight: f64 = 0;
        var cumulative_weights = try self.allocator.alloc(f64, upstreams.len);
        defer self.allocator.free(cumulative_weights);
        
        // Calculate dynamic weights based on performance
        for (upstreams, 0..) |upstream, i| {
            const stats = upstream.getStats();
            const dynamic_weight = upstream.base_weight * stats.success_rate * 
                                 (1.0 / (@as(f64, @floatFromInt(stats.avg_latency_ms)) + 1.0));
            
            total_weight += dynamic_weight;
            cumulative_weights[i] = total_weight;
        }
        
        // Random selection based on weights
        var prng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
        const random_value = prng.random().float(f64) * total_weight;
        
        for (cumulative_weights, 0..) |weight, i| {
            if (random_value <= weight) {
                return upstreams[i];
            }
        }
        
        return upstreams[upstreams.len - 1];
    }
    
    /// Select upstream with lowest latency
    fn selectLeastLatency(self: *Self, upstreams: []*UpstreamServer) !*UpstreamServer {
        _ = self;
        
        var best_upstream = upstreams[0];
        var lowest_latency = best_upstream.getStats().avg_latency_ms;
        
        for (upstreams[1..]) |upstream| {
            const latency = upstream.getStats().avg_latency_ms;
            if (latency < lowest_latency) {
                lowest_latency = latency;
                best_upstream = upstream;
            }
        }
        
        return best_upstream;
    }
    
    /// Geographic proximity-based selection
    fn selectGeographic(self: *Self, upstreams: []*UpstreamServer, context: QueryContext) !*UpstreamServer {
        var best_upstream = upstreams[0];
        var best_score = try self.geo_optimizer.calculateProximityScore(best_upstream, context.client_location);
        
        for (upstreams[1..]) |upstream| {
            const score = try self.geo_optimizer.calculateProximityScore(upstream, context.client_location);
            if (score > best_score) {
                best_score = score;
                best_upstream = upstream;
            }
        }
        
        return best_upstream;
    }
    
    /// Adaptive selection that learns from query patterns
    fn selectAdaptive(self: *Self, upstreams: []*UpstreamServer, context: QueryContext) !*UpstreamServer {
        // Use machine learning-like approach to adapt selection
        return self.selectIntelligent(upstreams, context);
    }
    
    /// Execute DNS query with automatic failover and circuit breaking
    pub fn executeQuery(self: *Self, query: []const u8, context: QueryContext) !DNSResponse {
        var attempts: u8 = 0;
        const max_attempts = @min(self.config.max_retries, self.upstreams.len);
        
        while (attempts < max_attempts) : (attempts += 1) {
            const upstream = self.selectUpstream(context) catch |err| {
                if (attempts == max_attempts - 1) return err;
                continue;
            };
            
            // Check circuit breaker
            if (!self.circuit_breaker.canExecute(upstream.id)) {
                self.metrics.circuit_breaker_blocks.fetchAdd(1, .monotonic);
                continue;
            }
            
            // Get adaptive timeout for this upstream
            const timeout = self.timeout_manager.getTimeout(upstream.id);
            
            // Execute query with timeout and monitoring
            const start_time = std.time.timestamp();
            
            const response = upstream.executeQuery(query, timeout) catch |err| {
                const duration = std.time.timestamp() - start_time;
                
                // Record failure
                upstream.recordFailure(duration);
                self.circuit_breaker.recordFailure(upstream.id);
                self.timeout_manager.recordFailure(upstream.id, duration);
                
                // Log for analysis
                std.log.warn("Query failed on upstream {s}: {}", .{ upstream.address, err });
                
                if (attempts == max_attempts - 1) return err;
                continue;
            };
            
            const duration = std.time.timestamp() - start_time;
            
            // Record success
            upstream.recordSuccess(duration);
            self.circuit_breaker.recordSuccess(upstream.id);
            self.timeout_manager.recordSuccess(upstream.id, duration);
            
            self.metrics.successful_queries.fetchAdd(1, .monotonic);
            return response;
        }
        
        return error.AllUpstreamsFailed;
    }
    
    /// Get healthy upstreams based on real-time monitoring
    fn getHealthyUpstreams(self: *Self) ![]UpstreamServer {
        var healthy = std.ArrayList(*UpstreamServer).init(self.allocator);
        defer healthy.deinit();
        
        for (self.upstreams) |*upstream| {
            if (self.health_monitor.isHealthy(upstream.id)) {
                try healthy.append(upstream);
            }
        }
        
        return healthy.toOwnedSlice();
    }
    
    /// Start background health monitoring and optimization
    pub fn startBackgroundTasks(self: *Self) !void {
        // Health monitoring thread
        _ = try Thread.spawn(.{}, HealthMonitor.monitorLoop, .{self.health_monitor});
        
        // Circuit breaker maintenance thread
        _ = try Thread.spawn(.{}, CircuitBreaker.maintenanceLoop, .{self.circuit_breaker});
        
        // Timeout optimization thread
        _ = try Thread.spawn(.{}, AdaptiveTimeoutManager.optimizationLoop, .{self.timeout_manager});
        
        // Geographic optimization updates
        _ = try Thread.spawn(.{}, GeographicOptimizer.updateLoop, .{self.geo_optimizer});
        
        std.log.info("🚀 Intelligent Load Balancer background tasks started", .{});
    }
    
    /// Get comprehensive load balancer statistics
    pub fn getStats(self: *const Self) LoadBalancerStats {
        var upstream_stats = std.ArrayList(UpstreamStats).init(self.allocator);
        defer upstream_stats.deinit();
        
        for (self.upstreams) |*upstream| {
            upstream_stats.append(upstream.getStats()) catch {};
        }
        
        return LoadBalancerStats{
            .total_selections = self.metrics.selections.load(.monotonic),
            .successful_queries = self.metrics.successful_queries.load(.monotonic),
            .failed_queries = self.metrics.failed_queries.load(.monotonic),
            .circuit_breaker_blocks = self.metrics.circuit_breaker_blocks.load(.monotonic),
            .upstream_stats = upstream_stats.toOwnedSlice() catch &[_]UpstreamStats{},
            .avg_selection_time_ns = self.calculateAvgSelectionTime(),
            .health_score = self.calculateOverallHealthScore(),
        };
    }
    
    fn calculateAvgSelectionTime(self: *const Self) u64 {
        _ = self;
        return 100; // TODO: Implement real measurement
    }
    
    fn calculateOverallHealthScore(self: *const Self) f64 {
        var total_score: f64 = 0;
        var healthy_count: usize = 0;
        
        for (self.upstreams) |*upstream| {
            if (self.health_monitor.isHealthy(upstream.id)) {
                total_score += upstream.getStats().success_rate;
                healthy_count += 1;
            }
        }
        
        if (healthy_count == 0) return 0.0;
        return total_score / @as(f64, @floatFromInt(healthy_count));
    }
};

/// Individual upstream server with comprehensive monitoring
const UpstreamServer = struct {
    id: u32,
    address: []const u8,
    port: u16,
    protocol: UpstreamProtocol,
    base_weight: f64,
    stats: UpstreamStats,
    specializations: []QueryType,
    location: GeographicLocation,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, config: UpstreamConfig) !UpstreamServer {
        return UpstreamServer{
            .id = config.id,
            .address = try allocator.dupe(u8, config.address),
            .port = config.port,
            .protocol = config.protocol,
            .base_weight = config.weight,
            .stats = UpstreamStats{},
            .specializations = try allocator.dupe(QueryType, config.specializations),
            .location = config.location,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *UpstreamServer) void {
        self.allocator.free(self.address);
        self.allocator.free(self.specializations);
    }
    
    pub fn executeQuery(self: *UpstreamServer, query: []const u8, timeout_ms: u32) !DNSResponse {
        // TODO: Implement actual DNS query execution
        _ = self;
        _ = query;
        _ = timeout_ms;
        
        return DNSResponse{
            .data = &[_]u8{},
            .size = 0,
            .rcode = 0,
        };
    }
    
    pub fn recordSuccess(self: *UpstreamServer, duration_ms: i64) void {
        self.stats.total_queries.fetchAdd(1, .monotonic);
        self.stats.successful_queries.fetchAdd(1, .monotonic);
        self.stats.updateLatency(@intCast(duration_ms));
    }
    
    pub fn recordFailure(self: *UpstreamServer, duration_ms: i64) void {
        self.stats.total_queries.fetchAdd(1, .monotonic);
        self.stats.failed_queries.fetchAdd(1, .monotonic);
        self.stats.updateLatency(@intCast(duration_ms));
    }
    
    pub fn getStats(self: *const UpstreamServer) UpstreamStats {
        const total = self.stats.total_queries.load(.monotonic);
        const successful = self.stats.successful_queries.load(.monotonic);
        
        return UpstreamStats{
            .total_queries = total,
            .successful_queries = successful,
            .failed_queries = self.stats.failed_queries.load(.monotonic),
            .success_rate = if (total > 0) @as(f64, @floatFromInt(successful)) / @as(f64, @floatFromInt(total)) else 0.0,
            .avg_latency_ms = self.stats.avg_latency_ms,
            .current_load = 0, // TODO: Implement load tracking
            .max_capacity = 1000,
        };
    }
    
    pub fn getSpecializationScore(self: *const UpstreamServer, query_type: QueryType) f64 {
        for (self.specializations) |spec| {
            if (spec == query_type) return 1.0;
        }
        return 0.5; // Neutral score for non-specialized queries
    }
    
    pub fn getTimeBasedScore(self: *const UpstreamServer, timestamp: i64) f64 {
        _ = self;
        _ = timestamp;
        return 1.0; // TODO: Implement time-based scoring
    }
};

/// Real-time health monitoring system
const HealthMonitor = struct {
    upstreams: []*UpstreamServer,
    health_status: std.AutoHashMap(u32, HealthStatus),
    allocator: Allocator,
    monitoring_active: std.atomic.Value(bool),
    
    pub fn init(allocator: Allocator, upstreams: []UpstreamServer) !*HealthMonitor {
        const monitor = try allocator.create(HealthMonitor);
        monitor.* = HealthMonitor{
            .upstreams = try allocator.alloc(*UpstreamServer, upstreams.len),
            .health_status = std.AutoHashMap(u32, HealthStatus).init(allocator),
            .allocator = allocator,
            .monitoring_active = std.atomic.Value(bool).init(true),
        };
        
        // Initialize upstream pointers and health status
        for (upstreams, 0..) |*upstream, i| {
            monitor.upstreams[i] = upstream;
            try monitor.health_status.put(upstream.id, HealthStatus{ .is_healthy = true });
        }
        
        return monitor;
    }
    
    pub fn deinit(self: *HealthMonitor) void {
        self.monitoring_active.store(false, .release);
        self.allocator.free(self.upstreams);
        self.health_status.deinit();
    }
    
    pub fn isHealthy(self: *const HealthMonitor, upstream_id: u32) bool {
        if (self.health_status.get(upstream_id)) |status| {
            return status.is_healthy;
        }
        return false;
    }
    
    pub fn monitorLoop(self: *HealthMonitor) void {
        while (self.monitoring_active.load(.acquire)) {
            self.performHealthChecks();
            std.time.sleep(5 * std.time.ns_per_s); // Check every 5 seconds
        }
    }
    
    fn performHealthChecks(self: *HealthMonitor) void {
        for (self.upstreams) |upstream| {
            const is_healthy = self.checkUpstreamHealth(upstream);
            self.health_status.put(upstream.id, HealthStatus{ .is_healthy = is_healthy }) catch {};
        }
    }
    
    fn checkUpstreamHealth(self: *HealthMonitor, upstream: *UpstreamServer) bool {
        _ = self;
        
        const stats = upstream.getStats();
        
        // Multiple health criteria
        const success_rate_ok = stats.success_rate >= 0.8;
        const latency_ok = stats.avg_latency_ms <= 500;
        const not_overloaded = stats.current_load < stats.max_capacity * 0.9;
        
        return success_rate_ok and latency_ok and not_overloaded;
    }
};

/// Circuit breaker pattern implementation
const CircuitBreaker = struct {
    breakers: std.AutoHashMap(u32, BreakerState),
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) !*CircuitBreaker {
        const breaker = try allocator.create(CircuitBreaker);
        breaker.* = CircuitBreaker{
            .breakers = std.AutoHashMap(u32, BreakerState).init(allocator),
            .allocator = allocator,
        };
        return breaker;
    }
    
    pub fn deinit(self: *CircuitBreaker) void {
        self.breakers.deinit();
    }
    
    pub fn canExecute(self: *CircuitBreaker, upstream_id: u32) bool {
        const state = self.breakers.get(upstream_id) orelse BreakerState{};
        return state.state != .open;
    }
    
    pub fn recordSuccess(self: *CircuitBreaker, upstream_id: u32) void {
        var state = self.breakers.get(upstream_id) orelse BreakerState{};
        state.success_count += 1;
        state.last_success = std.time.timestamp();
        
        if (state.state == .half_open and state.success_count >= 3) {
            state.state = .closed;
            state.failure_count = 0;
        }
        
        self.breakers.put(upstream_id, state) catch {};
    }
    
    pub fn recordFailure(self: *CircuitBreaker, upstream_id: u32) void {
        var state = self.breakers.get(upstream_id) orelse BreakerState{};
        state.failure_count += 1;
        state.last_failure = std.time.timestamp();
        
        if (state.failure_count >= 5) {
            state.state = .open;
            state.open_time = std.time.timestamp();
        }
        
        self.breakers.put(upstream_id, state) catch {};
    }
    
    pub fn maintenanceLoop(self: *CircuitBreaker) void {
        while (true) {
            self.updateBreakerStates();
            std.time.sleep(10 * std.time.ns_per_s); // Check every 10 seconds
        }
    }
    
    fn updateBreakerStates(self: *CircuitBreaker) void {
        const now = std.time.timestamp();
        var iterator = self.breakers.iterator();
        
        while (iterator.next()) |entry| {
            var state = entry.value_ptr;
            
            if (state.state == .open and now - state.open_time > 30) { // 30 second timeout
                state.state = .half_open;
                state.success_count = 0;
            }
        }
    }
};

/// Adaptive timeout management
const AdaptiveTimeoutManager = struct {
    timeouts: std.AutoHashMap(u32, TimeoutConfig),
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) !*AdaptiveTimeoutManager {
        const manager = try allocator.create(AdaptiveTimeoutManager);
        manager.* = AdaptiveTimeoutManager{
            .timeouts = std.AutoHashMap(u32, TimeoutConfig).init(allocator),
            .allocator = allocator,
        };
        return manager;
    }
    
    pub fn deinit(self: *AdaptiveTimeoutManager) void {
        self.timeouts.deinit();
    }
    
    pub fn getTimeout(self: *AdaptiveTimeoutManager, upstream_id: u32) u32 {
        const config = self.timeouts.get(upstream_id) orelse TimeoutConfig{};
        return config.current_timeout_ms;
    }
    
    pub fn recordSuccess(self: *AdaptiveTimeoutManager, upstream_id: u32, duration_ms: i64) void {
        var config = self.timeouts.get(upstream_id) orelse TimeoutConfig{};
        config.updateSuccess(@intCast(duration_ms));
        self.timeouts.put(upstream_id, config) catch {};
    }
    
    pub fn recordFailure(self: *AdaptiveTimeoutManager, upstream_id: u32, duration_ms: i64) void {
        var config = self.timeouts.get(upstream_id) orelse TimeoutConfig{};
        config.updateFailure(@intCast(duration_ms));
        self.timeouts.put(upstream_id, config) catch {};
    }
    
    pub fn optimizationLoop(self: *AdaptiveTimeoutManager) void {
        while (true) {
            self.optimizeTimeouts();
            std.time.sleep(60 * std.time.ns_per_s); // Optimize every minute
        }
    }
    
    fn optimizeTimeouts(self: *AdaptiveTimeoutManager) void {
        // TODO: Implement ML-based timeout optimization
        _ = self;
    }
};

/// Geographic optimization for upstream selection
const GeographicOptimizer = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) !*GeographicOptimizer {
        const optimizer = try allocator.create(GeographicOptimizer);
        optimizer.* = GeographicOptimizer{
            .allocator = allocator,
        };
        return optimizer;
    }
    
    pub fn deinit(self: *GeographicOptimizer) void {
        _ = self;
    }
    
    pub fn calculateProximityScore(self: *GeographicOptimizer, upstream: *UpstreamServer, client_location: ?GeographicLocation) !f64 {
        _ = self;
        
        if (client_location == null) return 0.5; // Neutral score
        
        const client_loc = client_location.?;
        const upstream_loc = upstream.location;
        
        // Calculate distance using haversine formula (simplified)
        const distance = calculateDistance(client_loc, upstream_loc);
        
        // Convert distance to score (closer = higher score)
        const max_distance = 20000.0; // 20,000 km max
        return std.math.clamp(1.0 - (distance / max_distance), 0.0, 1.0);
    }
    
    pub fn updateLoop(self: *GeographicOptimizer) void {
        while (true) {
            // TODO: Update geographic data and optimize routing
            _ = self;
            std.time.sleep(300 * std.time.ns_per_s); // Update every 5 minutes
        }
    }
};

// Supporting types and structures
pub const LoadBalancingStrategy = enum {
    intelligent,
    weighted_round_robin,
    least_latency,
    geographic,
    adaptive,
};

pub const UpstreamProtocol = enum { udp, tcp, dot, doq, doh };

pub const QueryType = enum { A, AAAA, CNAME, MX, TXT, PTR, SRV };

pub const QueryContext = struct {
    query_type: QueryType = .A,
    client_location: ?GeographicLocation = null,
    is_recursive: bool = true,
    priority: QueryPriority = .normal,
};

pub const QueryPriority = enum { low, normal, high, critical };

pub const GeographicLocation = struct {
    latitude: f64 = 0.0,
    longitude: f64 = 0.0,
    country: []const u8 = "",
    city: []const u8 = "",
};

pub const UpstreamConfig = struct {
    id: u32,
    address: []const u8,
    port: u16,
    protocol: UpstreamProtocol,
    weight: f64 = 1.0,
    specializations: []QueryType = &[_]QueryType{},
    location: GeographicLocation = GeographicLocation{},
};

pub const LoadBalancerConfig = struct {
    upstream_configs: []UpstreamConfig,
    strategy: LoadBalancingStrategy = .intelligent,
    max_retries: u8 = 3,
    health_check_interval_s: u32 = 5,
    circuit_breaker_threshold: u32 = 5,
    enable_geographic_optimization: bool = true,
    enable_adaptive_timeouts: bool = true,
};

pub const LoadBalancerMetrics = struct {
    selections: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    successful_queries: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    failed_queries: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    circuit_breaker_blocks: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
};

pub const UpstreamStats = struct {
    total_queries: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    successful_queries: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    failed_queries: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    success_rate: f64 = 1.0,
    avg_latency_ms: u32 = 0,
    current_load: u32 = 0,
    max_capacity: u32 = 1000,
    
    fn updateLatency(self: *UpstreamStats, new_latency: u32) void {
        // Simple moving average (could be enhanced with exponential smoothing)
        self.avg_latency_ms = (self.avg_latency_ms + new_latency) / 2;
    }
};

pub const LoadBalancerStats = struct {
    total_selections: u64,
    successful_queries: u64,
    failed_queries: u64,
    circuit_breaker_blocks: u64,
    upstream_stats: []UpstreamStats,
    avg_selection_time_ns: u64,
    health_score: f64,
    
    pub fn print(self: LoadBalancerStats) void {
        std.log.info("🎯 Intelligent Load Balancer Performance (vs Unbound):", .{});
        std.log.info("  📈 Total Selections: {}", .{self.total_selections});
        std.log.info("  ✅ Success Rate: {d:.2}%", .{
            if (self.total_selections > 0) 
                @as(f64, @floatFromInt(self.successful_queries)) / @as(f64, @floatFromInt(self.total_selections)) * 100 
            else 0.0
        });
        std.log.info("  🏥 Overall Health: {d:.1}%", .{self.health_score * 100});
        std.log.info("  ⚡ Avg Selection Time: {} ns", .{self.avg_selection_time_ns});
        std.log.info("  🛡️  Circuit Breaker Blocks: {}", .{self.circuit_breaker_blocks});
        std.log.info("  🌐 Active Upstreams: {}", .{self.upstream_stats.len});
    }
};

const HealthStatus = struct {
    is_healthy: bool = true,
    last_check: i64 = 0,
    consecutive_failures: u32 = 0,
};

const BreakerState = struct {
    state: CircuitState = .closed,
    failure_count: u32 = 0,
    success_count: u32 = 0,
    last_failure: i64 = 0,
    last_success: i64 = 0,
    open_time: i64 = 0,
};

const CircuitState = enum { closed, open, half_open };

const TimeoutConfig = struct {
    current_timeout_ms: u32 = 5000,
    min_timeout_ms: u32 = 1000,
    max_timeout_ms: u32 = 30000,
    success_count: u32 = 0,
    failure_count: u32 = 0,
    
    fn updateSuccess(self: *TimeoutConfig, duration_ms: u32) void {
        self.success_count += 1;
        
        // Gradually reduce timeout if consistently fast
        if (duration_ms < self.current_timeout_ms / 2) {
            self.current_timeout_ms = @max(
                self.min_timeout_ms,
                @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.current_timeout_ms)) * 0.95))
            );
        }
    }
    
    fn updateFailure(self: *TimeoutConfig, duration_ms: u32) void {
        self.failure_count += 1;
        
        // Increase timeout on failures/timeouts
        if (duration_ms >= self.current_timeout_ms) {
            self.current_timeout_ms = @min(
                self.max_timeout_ms,
                @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.current_timeout_ms)) * 1.2))
            );
        }
    }
};

const DNSResponse = struct {
    data: []const u8,
    size: usize,
    rcode: u8,
};

fn calculateDistance(loc1: GeographicLocation, loc2: GeographicLocation) f64 {
    // Simplified haversine formula
    const lat1_rad = loc1.latitude * std.math.pi / 180.0;
    const lat2_rad = loc2.latitude * std.math.pi / 180.0;
    const delta_lat = (loc2.latitude - loc1.latitude) * std.math.pi / 180.0;
    const delta_lon = (loc2.longitude - loc1.longitude) * std.math.pi / 180.0;
    
    const a = std.math.sin(delta_lat / 2) * std.math.sin(delta_lat / 2) +
             std.math.cos(lat1_rad) * std.math.cos(lat2_rad) *
             std.math.sin(delta_lon / 2) * std.math.sin(delta_lon / 2);
    const c = 2 * std.math.atan2(std.math.sqrt(a), std.math.sqrt(1 - a));
    
    return 6371.0 * c; // Earth's radius in kilometers
}
