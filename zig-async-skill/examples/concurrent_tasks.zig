const std = @import("std");

// Concurrent tasks example demonstrating io.concurrent() for producer-consumer patterns
// Zig 0.16.0+ required

/// Producer function - generates items and puts them in queue
fn producer(io: *std.Io, queue: *std.Io.Queue(i32), count: usize) !void {
    std.debug.print("[Producer] Starting, will produce {d} items\n", .{count});

    for (0..count) |i| {
        const item: i32 = @intCast(i);
        std.debug.print("[Producer] Producing item {d}\n", .{item});

        // This blocks until consumer takes the item (unbuffered queue)
        try queue.putOne(item);

        std.time.sleep(50 * std.time.ns_per_ms);
    }

    std.debug.print("[Producer] Finished\n", .{});
}

/// Consumer function - takes items from queue and processes them
fn consumer(io: *std.Io, queue: *std.Io.Queue(i32), count: usize) !void {
    std.debug.print("[Consumer] Starting, will consume {d} items\n", .{count});

    var consumed: usize = 0;
    while (consumed < count) {
        // This blocks until producer puts an item
        const item = try queue.getOne();

        std.debug.print("[Consumer] Consumed item {d}\n", .{item});
        consumed += 1;

        std.time.sleep(75 * std.time.ns_per_ms);
    }

    std.debug.print("[Consumer] Finished\n", .{});
}

/// Example 1: Basic producer-consumer pattern
fn producerConsumerExample(io: *std.Io) !void {
    std.debug.print("\n=== Producer-Consumer Example ===\n", .{});

    var queue = io.Queue(i32).init();
    const item_count = 5;

    // These MUST run concurrently or we deadlock!
    var prod = try io.concurrent(producer, .{ io, &queue, item_count });
    var cons = try io.concurrent(consumer, .{ io, &queue, item_count });

    // Wait for both to complete
    try prod.await(io);
    try cons.await(io);

    std.debug.print("Producer-Consumer completed successfully\n", .{});
}

/// Example 2: Multiple producers and consumers
fn multiProducer(io: *std.Io, queue: *std.Io.Queue(i32), id: u32, count: usize) !void {
    std.debug.print("[Producer {d}] Starting\n", .{id});

    for (0..count) |i| {
        const item: i32 = @intCast(id * 1000 + i);
        std.debug.print("[Producer {d}] Producing {d}\n", .{ id, item });
        try queue.putOne(item);
        std.time.sleep(30 * std.time.ns_per_ms);
    }

    std.debug.print("[Producer {d}] Finished\n", .{id});
}

fn multiConsumer(io: *std.Io, queue: *std.Io.Queue(i32), id: u32, count: usize) !void {
    std.debug.print("[Consumer {d}] Starting\n", .{id});

    var consumed: usize = 0;
    while (consumed < count) {
        const item = try queue.getOne();
        std.debug.print("[Consumer {d}] Consumed {d}\n", .{ id, item });
        consumed += 1;
        std.time.sleep(40 * std.time.ns_per_ms);
    }

    std.debug.print("[Consumer {d}] Finished\n", .{id});
}

fn multiProducerConsumer(io: *std.Io) !void {
    std.debug.print("\n=== Multiple Producers/Consumers ===\n", .{});

    var queue = io.Queue(i32).init();
    const items_per_worker = 3;

    // Spawn 2 producers and 2 consumers
    var prod1 = try io.concurrent(multiProducer, .{ io, &queue, 1, items_per_worker });
    var prod2 = try io.concurrent(multiProducer, .{ io, &queue, 2, items_per_worker });
    var cons1 = try io.concurrent(multiConsumer, .{ io, &queue, 1, items_per_worker });
    var cons2 = try io.concurrent(multiConsumer, .{ io, &queue, 2, items_per_worker });

    // Wait for all to complete
    try prod1.await(io);
    try prod2.await(io);
    try cons1.await(io);
    try cons2.await(io);

    std.debug.print("Multi-producer-consumer completed\n", .{});
}

/// Example 3: Worker pool pattern
const Task = struct {
    id: u32,
    data: []const u8,
};

fn taskProducer(io: *std.Io, queue: *std.Io.Queue(Task), tasks: []const Task) !void {
    std.debug.print("[Task Producer] Submitting {d} tasks\n", .{tasks.len});

    for (tasks) |task| {
        std.debug.print("[Task Producer] Submitting task {d}\n", .{task.id});
        try queue.putOne(task);
    }

    std.debug.print("[Task Producer] Finished\n", .{});
}

fn worker(io: *std.Io, queue: *std.Io.Queue(Task), id: u32, task_count: usize) !void {
    std.debug.print("[Worker {d}] Starting\n", .{id});

    var processed: usize = 0;
    while (processed < task_count) {
        const task = try queue.getOne();
        std.debug.print("[Worker {d}] Processing task {d}: {s}\n", .{ id, task.id, task.data });

        // Simulate work
        std.time.sleep(100 * std.time.ns_per_ms);

        processed += 1;
    }

    std.debug.print("[Worker {d}] Finished\n", .{id});
}

fn workerPoolExample(io: *std.Io, allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== Worker Pool Example ===\n", .{});

    var queue = io.Queue(Task).init();

    // Create tasks
    const tasks = [_]Task{
        .{ .id = 1, .data = "Process data A" },
        .{ .id = 2, .data = "Process data B" },
        .{ .id = 3, .data = "Process data C" },
        .{ .id = 4, .data = "Process data D" },
    };

    const worker_count = 2;
    const tasks_per_worker = tasks.len / worker_count;

    // Spawn producer
    var prod = try io.concurrent(taskProducer, .{ io, &queue, &tasks });

    // Spawn workers
    var workers: [worker_count]std.Io.Future = undefined;
    for (0..worker_count) |i| {
        workers[i] = try io.concurrent(worker, .{ io, &queue, @as(u32, @intCast(i)), tasks_per_worker });
    }

    // Wait for producer
    try prod.await(io);

    // Wait for all workers
    for (workers) |*w| {
        try w.await(io);
    }

    std.debug.print("Worker pool completed\n", .{});
}

/// Example 4: Handling ConcurrencyUnavailable error
fn tryWithFallback(io: *std.Io) !void {
    std.debug.print("\n=== Concurrent with Fallback ===\n", .{});

    var queue = io.Queue(i32).init();

    // Try concurrent execution
    const prod = io.concurrent(producer, .{ io, &queue, 3 }) catch |err| {
        if (err == error.ConcurrencyUnavailable) {
            std.debug.print("Concurrency unavailable (blocking I/O?)\n", .{});
            std.debug.print("This would deadlock - cannot proceed!\n", .{});
            return;
        }
        return err;
    };

    const cons = io.concurrent(consumer, .{ io, &queue, 3 }) catch |err| {
        if (err == error.ConcurrencyUnavailable) {
            std.debug.print("Concurrency unavailable\n", .{});
            _ = prod.cancel(io) catch {};
            return;
        }
        return err;
    };

    try prod.await(io);
    try cons.await(io);
}

/// Example 5: Bidirectional communication
const Message = struct {
    id: u32,
    content: []const u8,
};

fn sender(io: *std.Io, outbox: *std.Io.Queue(Message), inbox: *std.Io.Queue(Message)) !void {
    std.debug.print("[Sender] Starting\n", .{});

    // Send messages
    for (0..3) |i| {
        const msg = Message{
            .id = @intCast(i),
            .content = "Request",
        };
        std.debug.print("[Sender] Sending message {d}\n", .{msg.id});
        try outbox.putOne(msg);

        // Wait for response
        const response = try inbox.getOne();
        std.debug.print("[Sender] Received response {d}: {s}\n", .{ response.id, response.content });
    }

    std.debug.print("[Sender] Finished\n", .{});
}

fn receiver(io: *std.Io, inbox: *std.Io.Queue(Message), outbox: *std.Io.Queue(Message)) !void {
    std.debug.print("[Receiver] Starting\n", .{});

    for (0..3) |_| {
        // Wait for message
        const msg = try inbox.getOne();
        std.debug.print("[Receiver] Received message {d}: {s}\n", .{ msg.id, msg.content });

        // Send response
        const response = Message{
            .id = msg.id,
            .content = "Response",
        };
        std.debug.print("[Receiver] Sending response {d}\n", .{response.id});
        try outbox.putOne(response);
    }

    std.debug.print("[Receiver] Finished\n", .{});
}

fn bidirectionalExample(io: *std.Io) !void {
    std.debug.print("\n=== Bidirectional Communication ===\n", .{});

    var to_receiver = io.Queue(Message).init();
    var to_sender = io.Queue(Message).init();

    // Must run concurrently for bidirectional communication
    var send = try io.concurrent(sender, .{ io, &to_receiver, &to_sender });
    var recv = try io.concurrent(receiver, .{ io, &to_receiver, &to_sender });

    try send.await(io);
    try recv.await(io);

    std.debug.print("Bidirectional communication completed\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Zig 0.16.0 Concurrent Tasks Examples ===\n", .{});

    // Initialize thread pool I/O (required for concurrent operations)
    var io = std.Io.Threaded.init(allocator, .{}) catch {
        std.debug.print("ERROR: Thread pool required for concurrent examples\n", .{});
        std.debug.print("Concurrent operations need parallelism\n", .{});
        return error.ConcurrencyUnavailable;
    };
    defer io.deinit();

    try producerConsumerExample(&io);
    try multiProducerConsumer(&io);
    try workerPoolExample(&io, allocator);
    try bidirectionalExample(&io);

    std.debug.print("\n=== Summary ===\n", .{});
    std.debug.print("- io.concurrent() requires parallelism\n", .{});
    std.debug.print("- Use for producer-consumer patterns\n", .{});
    std.debug.print("- Use for bidirectional communication\n", .{});
    std.debug.print("- Io.Queue for message passing\n", .{});
    std.debug.print("- Fails with blocking I/O (prevents deadlock)\n", .{});
}

// Tests
const testing = std.testing;

test "concurrent operations require thread pool" {
    var io = std.Io.Blocking.init();
    var queue = io.Queue(i32).init();

    // Should fail with blocking I/O
    const result = io.concurrent(producer, .{ &io, &queue, 5 });
    try testing.expectError(error.ConcurrencyUnavailable, result);
}

test "producer consumer with thread pool" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var io = try std.Io.Threaded.init(gpa.allocator(), .{});
    defer io.deinit();

    var queue = io.Queue(i32).init();

    var prod = try io.concurrent(producer, .{ &io, &queue, 3 });
    var cons = try io.concurrent(consumer, .{ &io, &queue, 3 });

    try prod.await(&io);
    try cons.await(&io);
}
