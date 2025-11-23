const std = @import("std");

// Cancellation patterns example demonstrating Future.cancel()
// Zig 0.16.0+ required

/// Long-running operation that can be cancelled
fn longOperation(io: *std.Io, duration_ms: u64) ![]const u8 {
    _ = io;
    std.debug.print("[Operation] Starting (duration: {d}ms)\n", .{duration_ms});

    std.time.sleep(duration_ms * std.time.ns_per_ms);

    std.debug.print("[Operation] Completed\n", .{});
    return "Operation result";
}

/// Example 1: Basic cancellation with defer
fn basicCancellation(io: *std.Io) !void {
    std.debug.print("\n=== Basic Cancellation ===\n", .{});

    var future = io.async(longOperation, .{ io, 100 });

    // Use defer to ensure cleanup
    defer _ = future.cancel(io) catch {};

    // If an error occurs here, cancel is still called
    // try somethingThatMightFail();

    // Await the result
    const result = try future.await(io);
    std.debug.print("Result: {s}\n", .{result});
}

/// Example 2: Cancellation with resource cleanup
const Resource = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, size: usize) !Resource {
        const data = try allocator.alloc(u8, size);
        return .{ .data = data, .allocator = allocator };
    }

    fn deinit(self: Resource) void {
        self.allocator.free(self.data);
    }
};

fn allocateResource(io: *std.Io, allocator: std.mem.Allocator, size: usize) !Resource {
    _ = io;
    std.debug.print("[Allocate] Creating resource of {d} bytes\n", .{size});
    std.time.sleep(50 * std.time.ns_per_ms);
    return try Resource.init(allocator, size);
}

fn cancellationWithCleanup(io: *std.Io, allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== Cancellation with Cleanup ===\n", .{});

    var future = io.async(allocateResource, .{ io, allocator, 1024 });

    // Defer handles both success and cancellation
    defer if (future.cancel(io)) |resource| {
        std.debug.print("[Cleanup] Resource acquired, freeing\n", .{});
        resource.deinit();
    } else |_| {
        std.debug.print("[Cleanup] Resource not acquired or error\n", .{});
    };

    // Await the result
    const resource = try future.await(io);
    std.debug.print("Resource allocated: {d} bytes\n", .{resource.data.len});
}

/// Example 3: Timeout pattern using cancellation
fn timeoutPattern(io: *std.Io) !void {
    std.debug.print("\n=== Timeout Pattern ===\n", .{});

    // Start long operation
    var work = io.async(longOperation, .{ io, 500 });
    defer _ = work.cancel(io) catch {};

    // Simulate timeout check
    const timeout_ms = 200;
    std.time.sleep(timeout_ms * std.time.ns_per_ms);

    // Check if completed within timeout
    const result = work.cancel(io) catch |err| {
        if (err == error.Canceled) {
            std.debug.print("Operation timed out after {d}ms\n", .{timeout_ms});
            return error.Timeout;
        }
        return err;
    };

    std.debug.print("Completed within timeout: {s}\n", .{result});
}

/// Example 4: Cancelling multiple operations
fn cancelMultiple(io: *std.Io) !void {
    std.debug.print("\n=== Cancel Multiple Operations ===\n", .{});

    // Start multiple operations
    var futures: [5]std.Io.Future = undefined;
    for (0..5) |i| {
        futures[i] = io.async(longOperation, .{ io, (i + 1) * 100 });
    }

    // Cancel all on cleanup
    defer {
        for (futures) |*fut| {
            _ = fut.cancel(io) catch {};
        }
    }

    // Wait for first three only
    for (futures[0..3]) |*fut| {
        _ = try fut.await(io);
    }

    std.debug.print("First 3 completed, cancelling rest\n", .{});
    // Defer will cancel the remaining 2
}

/// Example 5: Idempotent cancellation
fn idempotentCancellation(io: *std.Io) !void {
    std.debug.print("\n=== Idempotent Cancellation ===\n", .{});

    var future = io.async(longOperation, .{ io, 100 });

    // Cancel multiple times - this is safe!
    const result1 = try future.cancel(io);
    std.debug.print("First cancel: {s}\n", .{result1});

    const result2 = try future.cancel(io);
    std.debug.print("Second cancel: {s}\n", .{result2});

    // Await after cancel also works
    const result3 = try future.await(io);
    std.debug.print("Await after cancel: {s}\n", .{result3});

    std.debug.print("All operations returned same result (idempotent)\n", .{});
}

/// Example 6: Conditional cancellation
fn conditionalCancellation(io: *std.Io, should_cancel: bool) !void {
    std.debug.print("\n=== Conditional Cancellation (cancel={}) ===\n", .{should_cancel});

    var future = io.async(longOperation, .{ io, 100 });

    if (should_cancel) {
        std.debug.print("Cancelling operation\n", .{});
        const result = try future.cancel(io);
        std.debug.print("Cancelled, got result: {s}\n", .{result});
    } else {
        std.debug.print("Awaiting operation\n", .{});
        const result = try future.await(io);
        std.debug.print("Completed, got result: {s}\n", .{result});
    }
}

/// Example 7: Cancellation in error paths
fn operationThatFails(io: *std.Io, should_fail: bool) ![]const u8 {
    _ = io;
    std.time.sleep(50 * std.time.ns_per_ms);

    if (should_fail) {
        return error.OperationFailed;
    }

    return "Success";
}

fn errorPathCancellation(io: *std.Io) !void {
    std.debug.print("\n=== Error Path Cancellation ===\n", .{});

    // Test with failure
    {
        var future = io.async(operationThatFails, .{ io, true });
        defer _ = future.cancel(io) catch {};

        const result = future.await(io) catch |err| {
            std.debug.print("Operation failed: {s}\n", .{@errorName(err)});
            // Defer still calls cancel for cleanup
            return;
        };

        std.debug.print("Result: {s}\n", .{result});
    }

    // Test with success
    {
        var future = io.async(operationThatFails, .{ io, false });
        defer _ = future.cancel(io) catch {};

        const result = try future.await(io);
        std.debug.print("Result: {s}\n", .{result});
    }
}

/// Example 8: Graceful shutdown pattern
const Server = struct {
    running: std.atomic.Value(bool),

    fn init() Server {
        return .{ .running = std.atomic.Value(bool).init(true) };
    }

    fn run(self: *Server, io: *std.Io) !void {
        _ = io;
        std.debug.print("[Server] Starting\n", .{});

        while (self.running.load(.seq_cst)) {
            std.debug.print("[Server] Processing requests...\n", .{});
            std.time.sleep(100 * std.time.ns_per_ms);
        }

        std.debug.print("[Server] Stopped\n", .{});
    }

    fn stop(self: *Server) void {
        std.debug.print("[Server] Shutdown requested\n", .{});
        self.running.store(false, .seq_cst);
    }
};

fn gracefulShutdown(io: *std.Io) !void {
    std.debug.print("\n=== Graceful Shutdown ===\n", .{});

    var server = Server.init();

    var server_future = io.async(Server.run, .{ &server, io });
    defer _ = server_future.cancel(io) catch {};

    // Let server run for a bit
    std.time.sleep(250 * std.time.ns_per_ms);

    // Initiate shutdown
    server.stop();

    // Wait for graceful shutdown
    try server_future.await(io);

    std.debug.print("Server shutdown complete\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Zig 0.16.0 Cancellation Patterns ===\n", .{});

    // Use thread pool or blocking I/O
    var io = std.Io.Threaded.init(allocator, .{}) catch blk: {
        std.debug.print("Using blocking I/O\n", .{});
        break :blk std.Io.Blocking.init();
    };
    defer if (@TypeOf(io) == std.Io.Threaded) io.deinit();

    try basicCancellation(&io);
    try cancellationWithCleanup(&io, allocator);
    try timeoutPattern(&io);
    try cancelMultiple(&io);
    try idempotentCancellation(&io);
    try conditionalCancellation(&io, false);
    try conditionalCancellation(&io, true);
    try errorPathCancellation(&io);
    try gracefulShutdown(&io);

    std.debug.print("\n=== Summary ===\n", .{});
    std.debug.print("- future.cancel(io) retrieves result and cleans up\n", .{});
    std.debug.print("- Use defer for automatic cleanup\n", .{});
    std.debug.print("- cancel() and await() are idempotent\n", .{});
    std.debug.print("- Perfect for timeout patterns\n", .{});
    std.debug.print("- Handles both success and error cases\n", .{});
    std.debug.print("- cancel() is your best friend!\n", .{});
}

// Tests
const testing = std.testing;

test "cancellation returns result" {
    var io = std.Io.Blocking.init();

    var future = io.async(longOperation, .{ &io, 10 });
    const result = try future.cancel(&io);

    try testing.expectEqualStrings("Operation result", result);
}

test "idempotent cancel and await" {
    var io = std.Io.Blocking.init();

    var future = io.async(longOperation, .{ &io, 10 });

    const result1 = try future.cancel(&io);
    const result2 = try future.cancel(&io);
    const result3 = try future.await(&io);

    try testing.expectEqualStrings(result1, result2);
    try testing.expectEqualStrings(result2, result3);
}

test "defer pattern with resource" {
    const allocator = testing.allocator;
    var io = std.Io.Blocking.init();

    var future = io.async(allocateResource, .{ &io, allocator, 100 });
    defer if (future.cancel(&io)) |resource| {
        resource.deinit();
    } else |_| {};

    const resource = try future.await(&io);
    try testing.expectEqual(@as(usize, 100), resource.data.len);
}

test "cancel handles errors" {
    var io = std.Io.Blocking.init();

    var future = io.async(operationThatFails, .{ &io, true });

    const result = future.cancel(&io);
    try testing.expectError(error.OperationFailed, result);
}
