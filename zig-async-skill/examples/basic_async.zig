const std = @import("std");

// Basic async I/O example demonstrating io.async() and Future.await()
// Zig 0.16.0+ required

/// Simulate async file save operation
fn saveFile(io: *std.Io, data: []const u8, filename: []const u8) !void {
    std.debug.print("Saving {d} bytes to {s}\n", .{ data.len, filename });

    // Simulate I/O delay
    std.time.sleep(100 * std.time.ns_per_ms);

    std.debug.print("Completed: {s}\n", .{filename});
}

/// Example 1: Sequential async operations
fn sequentialAsync(io: *std.Io) !void {
    std.debug.print("\n=== Sequential Async ===\n", .{});

    const data = "Hello, Async World!";

    // Spawn async operations
    var fut_a = io.async(saveFile, .{ io, data, "file_a.txt" });
    var fut_b = io.async(saveFile, .{ io, data, "file_b.txt" });

    // Await sequentially - this is valid!
    try fut_a.await(io);
    try fut_b.await(io);

    std.debug.print("Both files saved\n", .{});
}

/// Example 2: Concurrent async operations (parallel when possible)
fn parallelAsync(io: *std.Io) !void {
    std.debug.print("\n=== Parallel Async ===\n", .{});

    const data = "Parallel data";

    const start = std.time.milliTimestamp();

    // Spawn multiple async operations
    var futures: [5]std.Io.Future = undefined;
    inline for (0..5) |i| {
        const filename = std.fmt.allocPrint(
            std.heap.page_allocator,
            "file_{d}.txt",
            .{i},
        ) catch unreachable;
        futures[i] = io.async(saveFile, .{ io, data, filename });
    }

    // Await all
    for (futures) |*fut| {
        try fut.await(io);
    }

    const duration = std.time.milliTimestamp() - start;
    std.debug.print("Completed in {d}ms\n", .{duration});
}

/// Example 3: Async with error handling
fn processWithErrors(io: *std.Io, value: i32) !i32 {
    if (value < 0) return error.InvalidValue;
    if (value > 100) return error.ValueTooLarge;

    std.time.sleep(50 * std.time.ns_per_ms);
    return value * 2;
}

fn asyncErrorHandling(io: *std.Io) !void {
    std.debug.print("\n=== Async Error Handling ===\n", .{});

    const values = [_]i32{ 10, -5, 150, 42 };

    for (values) |val| {
        var future = io.async(processWithErrors, .{ io, val });

        const result = future.await(io) catch |err| {
            std.debug.print("Value {d} -> Error: {s}\n", .{ val, @errorName(err) });
            continue;
        };

        std.debug.print("Value {d} -> Result: {d}\n", .{ val, result });
    }
}

/// Example 4: Async with defer and cleanup
fn asyncWithCleanup(io: *std.Io, allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== Async with Cleanup ===\n", .{});

    // Allocate resource
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer);

    // Spawn async work
    var future = io.async(processBuffer, .{ io, buffer });

    // Always cleanup, even if error occurs
    defer _ = future.cancel(io) catch {};

    try future.await(io);
}

fn processBuffer(io: *std.Io, buffer: []u8) !void {
    _ = io;
    std.debug.print("Processing buffer of {d} bytes\n", .{buffer.len});
    std.time.sleep(50 * std.time.ns_per_ms);
}

/// Example 5: Chaining async operations
fn fetchData(io: *std.Io, id: u32) ![]const u8 {
    _ = io;
    std.time.sleep(100 * std.time.ns_per_ms);
    return std.fmt.allocPrint(std.heap.page_allocator, "data_{d}", .{id}) catch unreachable;
}

fn transformData(io: *std.Io, data: []const u8) ![]const u8 {
    _ = io;
    std.time.sleep(50 * std.time.ns_per_ms);
    return std.fmt.allocPrint(
        std.heap.page_allocator,
        "transformed_{s}",
        .{data},
    ) catch unreachable;
}

fn chainedAsync(io: *std.Io) !void {
    std.debug.print("\n=== Chained Async ===\n", .{});

    // Fetch data
    var fetch_future = io.async(fetchData, .{ io, 123 });
    const data = try fetch_future.await(io);
    defer std.heap.page_allocator.free(data);

    std.debug.print("Fetched: {s}\n", .{data});

    // Transform data
    var transform_future = io.async(transformData, .{ io, data });
    const transformed = try transform_future.await(io);
    defer std.heap.page_allocator.free(transformed);

    std.debug.print("Transformed: {s}\n", .{transformed});
}

/// Example 6: Working with different I/O implementations
fn testIoImplementation(comptime name: []const u8, io: *std.Io) !void {
    std.debug.print("\n=== Testing with {s} ===\n", .{name});

    const start = std.time.milliTimestamp();

    var fut1 = io.async(saveFile, .{ io, "test", "a.txt" });
    var fut2 = io.async(saveFile, .{ io, "test", "b.txt" });

    try fut1.await(io);
    try fut2.await(io);

    const duration = std.time.milliTimestamp() - start;
    std.debug.print("{s} completed in {d}ms\n", .{ name, duration });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Zig 0.16.0 Async I/O Examples ===\n", .{});

    // Initialize I/O implementation
    // Note: This is conceptual - actual API may differ in 0.16.0
    var io = std.Io.Threaded.init(allocator, .{}) catch {
        std.debug.print("Thread pool initialization failed, using blocking I/O\n", .{});
        var blocking_io = std.Io.Blocking.init();
        try runExamples(&blocking_io, allocator);
        return;
    };
    defer io.deinit();

    try runExamples(&io, allocator);
}

fn runExamples(io: *std.Io, allocator: std.mem.Allocator) !void {
    try sequentialAsync(io);
    try parallelAsync(io);
    try asyncErrorHandling(io);
    try asyncWithCleanup(io, allocator);
    try chainedAsync(io);

    std.debug.print("\n=== Summary ===\n", .{});
    std.debug.print("- io.async() spawns async work\n", .{});
    std.debug.print("- future.await(io) waits for completion\n", .{});
    std.debug.print("- Sequential awaiting is valid\n", .{});
    std.debug.print("- Use defer for cleanup\n", .{});
    std.debug.print("- Same code works with different I/O implementations\n", .{});
}

// Tests
const testing = std.testing;

test "async operations complete" {
    var io = std.Io.Blocking.init();

    var future = io.async(processWithErrors, .{ &io, 42 });
    const result = try future.await(&io);

    try testing.expectEqual(@as(i32, 84), result);
}

test "async error propagation" {
    var io = std.Io.Blocking.init();

    var future = io.async(processWithErrors, .{ &io, -5 });
    const result = future.await(&io);

    try testing.expectError(error.InvalidValue, result);
}

test "multiple async operations" {
    var io = std.Io.Blocking.init();

    var fut1 = io.async(processWithErrors, .{ &io, 10 });
    var fut2 = io.async(processWithErrors, .{ &io, 20 });

    const result1 = try fut1.await(&io);
    const result2 = try fut2.await(&io);

    try testing.expectEqual(@as(i32, 20), result1);
    try testing.expectEqual(@as(i32, 40), result2);
}

test "async with cancellation" {
    var io = std.Io.Blocking.init();

    var future = io.async(processWithErrors, .{ &io, 50 });

    // Cancel before await
    const result = try future.cancel(&io);
    try testing.expectEqual(@as(i32, 100), result);

    // Await after cancel still works (idempotent)
    const result2 = try future.await(&io);
    try testing.expectEqual(@as(i32, 100), result2);
}
