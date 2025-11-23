# Async vs. Concurrent: The Critical Distinction

## The Core Difference

**Asynchrony**: Code *can* execute out-of-order
**Concurrency**: Code *must* execute simultaneously

This distinction is fundamental to understanding Zig's new async I/O.

## Asynchrony: Out-of-Order Execution

### Definition

Async allows you to express that operations are **independent** and *could* proceed in any order, but doesn't guarantee they *will*.

### Example: Async File Saves

```zig
fn saveFiles(io: *Io, data: []const u8) !void {
    var fut_a = io.async(saveFile, .{io, data, "a.txt"});
    var fut_b = io.async(saveFile, .{io, data, "b.txt"});

    // Sequential awaiting is VALID
    try fut_a.await(io);
    try fut_b.await(io);
}
```

### Behavior with Different I/O Implementations

**Blocking I/O**:
```
1. Execute saveFile("a.txt") immediately
2. Execute saveFile("b.txt") immediately
3. First await returns immediately (already done)
4. Second await returns immediately (already done)
```

**Thread Pool I/O**:
```
1. Schedule saveFile("a.txt") on thread pool
2. Schedule saveFile("b.txt") on thread pool
3. First await waits for thread to complete
4. Second await waits for thread to complete
```

**Event Loop I/O**:
```
1. Submit saveFile("a.txt") to event loop
2. Submit saveFile("b.txt") to event loop
3. First await processes events until a.txt done
4. Second await processes events until b.txt done
```

### Key Insight

The code works correctly in all cases because **the operations don't depend on each other**. They can execute in sequence or in parallel - both are valid.

## Concurrency: Simultaneous Execution

### Definition

Concurrent operations *must* run at the same time because they **depend on each other** running simultaneously.

### Example: Producer-Consumer

```zig
fn producerConsumer(io: *Io) !void {
    var queue = io.Queue(Task).init();

    // These MUST run concurrently or we deadlock!
    var producer = try io.concurrent(produce, .{io, &queue});
    var consumer = try io.concurrent(consume, .{io, &queue});

    try producer.await(io);
    try consumer.await(io);
}

fn produce(io: *Io, queue: *Io.Queue(Task)) !void {
    for (tasks) |task| {
        try queue.putOne(task); // Blocks until consumer takes item
    }
}

fn consume(io: *Io, queue: *Io.Queue(Task)) !void {
    while (queue.getOne()) |task| { // Blocks until producer puts item
        try processTask(task);
    }
}
```

### The Deadlock Problem

If we used `io.async()` instead:

**With Blocking I/O**:
```
1. Execute producer
2. producer calls queue.putOne()
3. Queue is full (unbuffered), putOne() blocks
4. Waiting for consumer to take item
5. But consumer hasn't started yet!
6. DEADLOCK
```

### Why concurrent() Exists

`io.concurrent()` explicitly requires parallelism:

**Blocking I/O**: Returns `error.ConcurrencyUnavailable` immediately
**Thread Pool**: Executes on separate threads
**Event Loop**: Schedules as independent tasks

This makes the requirement explicit and fails fast when not met.

## Decision Matrix

### Use io.async() When:

**Independent Operations**:
```zig
// Reading multiple files - order doesn't matter
var fut1 = io.async(readFile, .{io, "a.txt"});
var fut2 = io.async(readFile, .{io, "b.txt"});
var fut3 = io.async(readFile, .{io, "c.txt"});
```

**Opportunistic Parallelism**:
```zig
// Could run in parallel, but sequential is fine too
var fut = io.async(expensiveComputation, .{io, data});
doOtherWork();
const result = try fut.await(io);
```

**Pipeline Processing**:
```zig
// Each stage can start before previous finishes
var decode = io.async(decodeData, .{io, raw});
var validate = io.async(validateData, .{io, decoded});
var process = io.async(processData, .{io, validated});
```

### Use io.concurrent() When:

**Producer-Consumer Patterns**:
```zig
// Producer must run while consumer consumes
var prod = try io.concurrent(producer, .{io, &queue});
var cons = try io.concurrent(consumer, .{io, &queue});
```

**Bidirectional Communication**:
```zig
// Client and server must both run simultaneously
var client = try io.concurrent(runClient, .{io, &pipe});
var server = try io.concurrent(runServer, .{io, &pipe});
```

**Deadlock Prevention**:
```zig
// Operations block on each other
var writer = try io.concurrent(writeLoop, .{io, &channel});
var reader = try io.concurrent(readLoop, .{io, &channel});
```

## Common Mistakes

### Mistake 1: Using async for Dependent Operations

```zig
// WRONG - Can deadlock with blocking I/O!
var sender = io.async(sendMessages, .{io, &pipe});
var receiver = io.async(receiveMessages, .{io, &pipe});
```

**Fix**: Use `concurrent()`
```zig
// CORRECT
var sender = try io.concurrent(sendMessages, .{io, &pipe});
var receiver = try io.concurrent(receiveMessages, .{io, &pipe});
```

### Mistake 2: Using concurrent for Independent Operations

```zig
// WASTEFUL - Requires parallelism when not needed
var fut1 = try io.concurrent(readFile, .{io, "a.txt"});
var fut2 = try io.concurrent(readFile, .{io, "b.txt"});
```

**Fix**: Use `async()`
```zig
// BETTER - Works with blocking I/O too
var fut1 = io.async(readFile, .{io, "a.txt"});
var fut2 = io.async(readFile, .{io, "b.txt"});
```

### Mistake 3: Ignoring ConcurrencyUnavailable Error

```zig
// WRONG - Silently fails with blocking I/O
var fut = io.concurrent(work, .{io}) catch io.async(work, .{io});
```

**Fix**: Handle the error properly
```zig
// CORRECT - Fail fast or use different approach
var fut = try io.concurrent(work, .{io}); // Explicit requirement
```

## Testing Strategy

### Test with Blocking I/O

Always test your async code with blocking I/O first:

```zig
test "works with blocking I/O" {
    var io = std.Io.Blocking.init();

    // If this hangs, you need concurrent() not async()
    try myAsyncFunction(&io);
}
```

**If it hangs**: You need `concurrent()` because operations depend on each other.
**If it works**: `async()` is correct, operations are independent.

### Test with Thread Pool

Test that concurrent operations actually work in parallel:

```zig
test "concurrent operations run in parallel" {
    var io = try std.Io.Threaded.init(allocator, .{});
    defer io.deinit();

    const start = std.time.milliTimestamp();
    try myAsyncFunction(&io);
    const duration = std.time.milliTimestamp() - start;

    // If operations run in parallel, should be ~1000ms, not 3000ms
    try testing.expect(duration < 1500);
}
```

## Real-World Examples

### Example 1: HTTP Server (Async)

```zig
fn handleRequest(io: *Io, request: Request) !Response {
    // These can run in any order
    var auth = io.async(checkAuth, .{io, request.headers});
    var data = io.async(fetchData, .{io, request.params});

    // Await sequentially - that's fine!
    const user = try auth.await(io);
    const payload = try data.await(io);

    return buildResponse(user, payload);
}
```

Independent operations - `async()` is correct.

### Example 2: WebSocket (Concurrent)

```zig
fn handleWebSocket(io: *Io, conn: Connection) !void {
    var inbox = io.Queue(Message).init();
    var outbox = io.Queue(Message).init();

    // MUST run simultaneously!
    var reader = try io.concurrent(readMessages, .{io, conn, &inbox});
    var writer = try io.concurrent(writeMessages, .{io, conn, &outbox});
    var handler = try io.concurrent(processMessages, .{io, &inbox, &outbox});

    try reader.await(io);
    try writer.await(io);
    try handler.await(io);
}
```

Bidirectional communication - `concurrent()` is required.

### Example 3: Data Pipeline (Async)

```zig
fn processPipeline(io: *Io, input: []const u8) ![]u8 {
    // Each stage can start when data available
    var stage1 = io.async(decode, .{io, input});
    var stage2 = io.async(validate, .{io, &stage1});
    var stage3 = io.async(transform, .{io, &stage2});

    return try stage3.await(io);
}
```

Pipeline stages are independent - `async()` works.

## Summary Table

| Scenario | Use async() | Use concurrent() |
|----------|-------------|------------------|
| Multiple file reads | ✓ | |
| HTTP requests in parallel | ✓ | |
| Producer-consumer | | ✓ |
| Bidirectional I/O | | ✓ |
| Optional parallelism | ✓ | |
| Required parallelism | | ✓ |
| Works with blocking I/O | ✓ | |
| May fail with blocking I/O | | ✓ |

## Key Takeaways

1. **Async = optional parallelism** - *Can* run out-of-order
2. **Concurrent = required parallelism** - *Must* run simultaneously
3. **Test with blocking I/O first** - Reveals dependency issues
4. **Default to async** - Use concurrent only when necessary
5. **Handle ConcurrencyUnavailable** - Don't silently fall back to async
6. **Think about dependencies** - Do operations block on each other?

The distinction prevents subtle bugs and makes I/O requirements explicit in code.
