const std = @import("std");

// Async Function Template
// Template for writing async-compatible functions using std.Io interface
// Zig 0.16.0+ required

/// Template for a simple async function
/// Replace T with your return type
fn asyncFunction(io: *std.Io, allocator: std.mem.Allocator, arg: anytype) !T {
    // TODO: Implement your async logic here

    // Example: Spawn async work
    var future = io.async(helperFunction, .{ io, allocator, arg });

    // Use defer for cleanup
    defer _ = future.cancel(io) catch {};

    // Await the result
    const result = try future.await(io);

    return result;
}

/// Template for a helper function (can be called async)
fn helperFunction(io: *std.Io, allocator: std.mem.Allocator, arg: anytype) !T {
    _ = io; // Remove if using io

    // TODO: Implement helper logic

    // Example resource allocation
    const resource = try allocator.alloc(u8, 1024);
    defer allocator.free(resource);

    // Your processing here

    return result;
}

/// Template for async function with multiple parallel operations
fn parallelAsyncFunction(io: *std.Io, allocator: std.mem.Allocator) !void {
    // Spawn multiple async operations
    var future1 = io.async(operation1, .{ io, allocator });
    var future2 = io.async(operation2, .{ io, allocator });
    var future3 = io.async(operation3, .{ io, allocator });

    // Cleanup on scope exit
    defer {
        _ = future1.cancel(io) catch {};
        _ = future2.cancel(io) catch {};
        _ = future3.cancel(io) catch {};
    }

    // Await all results
    const result1 = try future1.await(io);
    const result2 = try future2.await(io);
    const result3 = try future3.await(io);

    // TODO: Process results
    _ = result1;
    _ = result2;
    _ = result3;
}

/// Template for concurrent function (requires parallelism)
fn concurrentFunction(io: *std.Io, allocator: std.mem.Allocator) !void {
    var queue = io.Queue(Task).init();

    // Spawn concurrent operations (MUST run simultaneously)
    var producer_future = try io.concurrent(producer, .{ io, &queue });
    var consumer_future = try io.concurrent(consumer, .{ io, &queue });

    defer {
        _ = producer_future.cancel(io) catch {};
        _ = consumer_future.cancel(io) catch {};
    }

    try producer_future.await(io);
    try consumer_future.await(io);
}

/// Template for producer function
fn producer(io: *std.Io, queue: *std.Io.Queue(Task)) !void {
    // TODO: Implement producer logic

    for (tasks) |task| {
        try queue.putOne(task);
    }
}

/// Template for consumer function
fn consumer(io: *std.Io, queue: *std.Io.Queue(Task)) !void {
    // TODO: Implement consumer logic

    while (queue.getOne()) |task| {
        try processTask(task);
    }
}

/// Template for async function with timeout
fn asyncWithTimeout(io: *std.Io, timeout_ms: u64) !T {
    var work = io.async(longOperation, .{io});
    defer _ = work.cancel(io) catch {};

    // Simulate timeout check
    std.time.sleep(timeout_ms * std.time.ns_per_ms);

    // Cancel if not completed
    const result = work.cancel(io) catch |err| {
        if (err == error.Canceled) {
            return error.Timeout;
        }
        return err;
    };

    return result;
}

/// Template for async function with error handling
fn asyncWithErrorHandling(io: *std.Io, allocator: std.mem.Allocator, input: Input) !Output {
    var future = io.async(process, .{ io, allocator, input });
    defer _ = future.cancel(io) catch {};

    const result = future.await(io) catch |err| {
        // Handle specific errors
        switch (err) {
            error.InvalidInput => {
                std.debug.print("Invalid input provided\n", .{});
                return error.InvalidInput;
            },
            error.OutOfMemory => {
                std.debug.print("Out of memory\n", .{});
                return error.OutOfMemory;
            },
            else => return err,
        }
    };

    return result;
}

/// Template for async function that returns a Future
/// (Useful for composable async operations)
fn createFuture(io: *std.Io, allocator: std.mem.Allocator, input: Input) std.Io.Future {
    return io.async(process, .{ io, allocator, input });
}

/// Template for chaining async operations
fn chainedAsync(io: *std.Io, allocator: std.mem.Allocator, input: Input) !Output {
    // Step 1: Fetch data
    var fetch_future = io.async(fetchData, .{ io, input });
    const data = try fetch_future.await(io);
    defer freeData(allocator, data);

    // Step 2: Process data
    var process_future = io.async(processData, .{ io, allocator, data });
    const processed = try process_future.await(io);
    defer freeProcessed(allocator, processed);

    // Step 3: Save result
    var save_future = io.async(saveData, .{ io, allocator, processed });
    try save_future.await(io);

    return output;
}

/// Template for async function with resource cleanup
fn asyncWithResource(io: *std.Io, allocator: std.mem.Allocator) !Result {
    // Acquire resource
    var resource_future = io.async(acquireResource, .{ io, allocator });
    defer if (resource_future.cancel(io)) |resource| {
        // Cleanup acquired resource
        resource.deinit();
    } else |_| {
        // Resource was not acquired or error occurred
    };

    const resource = try resource_future.await(io);

    // Use resource
    var work_future = io.async(useResource, .{ io, &resource });
    const result = try work_future.await(io);

    return result;
}

/// Template for graceful shutdown
fn runWithShutdown(io: *std.Io, allocator: std.mem.Allocator, shutdown_signal: *std.atomic.Value(bool)) !void {
    var server = Server.init(allocator);
    defer server.deinit();

    var server_future = io.async(Server.run, .{ &server, io });
    defer _ = server_future.cancel(io) catch {};

    // Wait for shutdown signal
    while (!shutdown_signal.load(.seq_cst)) {
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    // Graceful shutdown
    server.stop();
    try server_future.await(io);
}

// =============================================================================
// Usage Examples
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize I/O implementation
    var io = std.Io.Threaded.init(allocator, .{}) catch {
        var blocking = std.Io.Blocking.init();
        // Use blocking I/O as fallback
        _ = blocking;
        return;
    };
    defer io.deinit();

    // Example usage of template functions
    // TODO: Replace with your actual function calls

    // Example 1: Simple async
    _ = try asyncFunction(&io, allocator, input);

    // Example 2: Parallel operations
    try parallelAsyncFunction(&io, allocator);

    // Example 3: Concurrent operations
    try concurrentFunction(&io, allocator);

    // Example 4: With timeout
    const result = try asyncWithTimeout(&io, 5000);
    _ = result;
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "async function completes" {
    var io = std.Io.Blocking.init();
    const allocator = testing.allocator;

    // TODO: Test your async function
    _ = try asyncFunction(&io, allocator, test_input);
}

test "parallel operations" {
    var io = std.Io.Blocking.init();
    const allocator = testing.allocator;

    try parallelAsyncFunction(&io, allocator);
}

test "concurrent with thread pool" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var io = try std.Io.Threaded.init(gpa.allocator(), .{});
    defer io.deinit();

    try concurrentFunction(&io, gpa.allocator());
}

// =============================================================================
// Helper Type Definitions (Customize for your use case)
// =============================================================================

const T = void; // Replace with your return type
const Input = struct {}; // Replace with your input type
const Output = struct {}; // Replace with your output type
const Result = struct {}; // Replace with your result type
const Task = struct {}; // Replace with your task type

fn operation1(io: *std.Io, allocator: std.mem.Allocator) !void {
    _ = io;
    _ = allocator;
}

fn operation2(io: *std.Io, allocator: std.mem.Allocator) !void {
    _ = io;
    _ = allocator;
}

fn operation3(io: *std.Io, allocator: std.mem.Allocator) !void {
    _ = io;
    _ = allocator;
}

fn longOperation(io: *std.Io) !T {
    _ = io;
}

fn process(io: *std.Io, allocator: std.mem.Allocator, input: Input) !Output {
    _ = io;
    _ = allocator;
    _ = input;
}

fn fetchData(io: *std.Io, input: Input) ![]const u8 {
    _ = io;
    _ = input;
    return "";
}

fn processData(io: *std.Io, allocator: std.mem.Allocator, data: []const u8) ![]const u8 {
    _ = io;
    _ = allocator;
    _ = data;
    return "";
}

fn saveData(io: *std.Io, allocator: std.mem.Allocator, data: []const u8) !void {
    _ = io;
    _ = allocator;
    _ = data;
}

fn freeData(allocator: std.mem.Allocator, data: []const u8) void {
    _ = allocator;
    _ = data;
}

fn freeProcessed(allocator: std.mem.Allocator, data: []const u8) void {
    _ = allocator;
    _ = data;
}

fn processTask(task: Task) !void {
    _ = task;
}

const Resource = struct {
    fn deinit(self: *Resource) void {
        _ = self;
    }
};

fn acquireResource(io: *std.Io, allocator: std.mem.Allocator) !Resource {
    _ = io;
    _ = allocator;
    return Resource{};
}

fn useResource(io: *std.Io, resource: *Resource) !Result {
    _ = io;
    _ = resource;
    return Result{};
}

const Server = struct {
    fn init(allocator: std.mem.Allocator) Server {
        _ = allocator;
        return Server{};
    }

    fn deinit(self: *Server) void {
        _ = self;
    }

    fn run(self: *Server, io: *std.Io) !void {
        _ = self;
        _ = io;
    }

    fn stop(self: *Server) void {
        _ = self;
    }
};
