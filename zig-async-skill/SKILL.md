---
name: zig-async-io
description: >
  Zig 0.16.0 async I/O programming with the new std.Io interface. Covers async/concurrent
  primitives, Future handling, cancellation patterns, and I/O implementation strategies.
  Use when working with Zig 0.16.0+ async code, event loops, concurrent tasks, or non-blocking I/O.
---

# Zig Async I/O Skill (0.16.0+)

## Overview

Zig 0.16.0 introduces a redesigned async I/O system based on the `std.Io` interface. Unlike the old async/await (removed in 0.11), the new design **decouples concurrency expression from execution models**, allowing code to work optimally across synchronous, multi-threaded, and event-driven contexts.

**Critical Concept**: **Asynchrony ≠ Concurrency**
- `async`: Operations *can* proceed out-of-order (sequential awaiting is valid)
- `concurrent`: Operations *must* proceed simultaneously (requires parallelism)

## Table of Contents

- [Bundled Resources](#bundled-resources)
- [Core Concepts](#core-concepts)
- [Workflows](#workflows)
- [Common Patterns](#common-patterns)

## Bundled Resources

### References

**Fundamentals**:
- `references/async-overview.md` - New async I/O design philosophy
- `references/io-interface.md` - std.Io interface and primitives
- `references/async-vs-concurrent.md` - Critical distinction explained

**Patterns**:
- `references/future-handling.md` - Future.await() and Future.cancel()
- `references/resource-management.md` - Defer patterns for async resources
- `references/io-implementations.md` - Blocking, ThreadPool, EventLoop, Stackless

**Advanced**:
- `references/message-passing.md` - Io.Queue for synchronization
- `references/vectorized-io.md` - sendFile() and drain() operations
- `references/migration-guide.md` - From old async or sync code

### Examples

Complete async I/O demonstrations:
- `examples/basic_async.zig` - Simple async operations with io.async()
- `examples/concurrent_tasks.zig` - True concurrency with io.concurrent()
- `examples/file_operations.zig` - Async file I/O patterns
- `examples/http_server.zig` - Async HTTP server with event loop
- `examples/producer_consumer.zig` - Message passing with Io.Queue
- `examples/cancellation.zig` - Proper task cancellation patterns

### Templates

Starting points for async code:
- `assets/templates/async-function.zig` - Async function template
- `assets/templates/async-server.zig` - Async server template
- `assets/templates/async-client.zig` - Async client template
- `assets/templates/threaded-io.zig` - Thread pool I/O setup

## Core Concepts

### The std.Io Interface

```zig
const Io = struct {
    /// Spawn async work (may execute immediately or be scheduled)
    fn async(self: *Io, func: anytype, args: anytype) Future

    /// Spawn concurrent work (fails if parallelism unavailable)
    fn concurrent(self: *Io, func: anytype, args: anytype) !Future

    /// Message passing primitive
    fn Queue(comptime T: type) type
};
```

### Future Operations

```zig
const Future = struct {
    /// Wait for result (idempotent)
    fn await(self: *Future, io: *Io) !T

    /// Cancel and retrieve result (idempotent)
    fn cancel(self: *Future, io: *Io) !T
};
```

### I/O Implementations

1. **Blocking I/O** - Standard syscalls, zero overhead
2. **Thread Pool** - `std.Io.Threaded` multiplexes across OS threads
3. **Event Loop** - `io_uring`/`kqueue` with green threads (future)
4. **Stackless Coroutines** - State machine rewriting (future)

## Workflows

### Writing Async Code

1. **Accept Io parameter** - Functions take `io: *std.Io` like allocators
2. **Spawn async work** - Use `io.async()` for potentially concurrent operations
3. **Await results** - Call `future.await(io)` when needed
4. **Handle cancellation** - Use `defer future.cancel(io)` for cleanup
5. **Choose concurrent carefully** - Only use `io.concurrent()` when simultaneous execution required

### Async vs Concurrent Decision

**Use `io.async()` when:**
- Operations can proceed in any order
- Sequential awaiting is acceptable
- Want to work with blocking I/O implementations

**Use `io.concurrent()` when:**
- Operations MUST run simultaneously
- Solving producer-consumer deadlocks
- Require true parallelism

### Resource Management Pattern

```zig
var future = io.async(operation, .{io, args});
defer if (future.cancel(io)) |result| {
    cleanup(result);
} else |_| {};

// Use future...
try future.await(io);
```

This single pattern handles both success and failure cases.

## Common Patterns

### Pattern 1: Parallel File Operations

```zig
fn saveFiles(io: *std.Io, data: []const u8) !void {
    var fut_a = io.async(saveFile, .{io, data, "a.txt"});
    var fut_b = io.async(saveFile, .{io, data, "b.txt"});

    try fut_a.await(io);
    try fut_b.await(io);
}
```

### Pattern 2: Producer-Consumer with Queue

```zig
var queue = io.Queue(Task).init();

// Producer
var producer = try io.concurrent(produce, .{io, &queue});

// Consumer
var consumer = try io.concurrent(consume, .{io, &queue});

try producer.await(io);
try consumer.await(io);
```

### Pattern 3: Cancellation on Timeout

```zig
var work = io.async(longOperation, .{io});
var timeout = io.async(sleep, .{io, 5000});

const result = io.race(&.{work, timeout});
if (result == 1) { // timeout won
    _ = work.cancel(io) catch {};
    return error.Timeout;
}
```

### Pattern 4: Passing Io Like Allocator

```zig
pub fn processData(io: *std.Io, allocator: Allocator, data: []const u8) !void {
    // Use io just like allocator
    var future = io.async(helper, .{io, allocator, data});
    try future.await(io);
}
```

## Key Differences from Old Async

**Old Model (0.10.x and earlier)**:
- `async` and `await` keywords
- Stackless coroutines baked into language
- Execution model virality
- Removed in 0.11 for redesign

**New Model (0.16.0+)**:
- `io.async()` and `future.await(io)` methods
- Execution model as runtime parameter
- No function coloring
- Works with synchronous code

## Migration Guide

**From synchronous code:**
```zig
// Before (sync)
try saveFile(data, "a.txt");
try saveFile(data, "b.txt");

// After (async)
var fut_a = io.async(saveFile, .{io, data, "a.txt"});
var fut_b = io.async(saveFile, .{io, data, "b.txt"});
try fut_a.await(io);
try fut_b.await(io);
```

**From old async/await:**
```zig
// Before (old async - removed)
var frame_a = async saveFile(data, "a.txt");
var frame_b = async saveFile(data, "b.txt");
try await frame_a;
try await frame_b;

// After (new async)
var fut_a = io.async(saveFile, .{io, data, "a.txt"});
var fut_b = io.async(saveFile, .{io, data, "b.txt"});
try fut_a.await(io);
try fut_b.await(io);
```

## Best Practices

1. **Pass Io explicitly** - Like allocators, pass as parameter not global
2. **Default to async** - Use `io.async()` unless concurrent truly needed
3. **Always handle cancellation** - Use defer pattern for resource cleanup
4. **Understand async ≠ concurrent** - Async allows out-of-order, concurrent requires simultaneous
5. **Test with multiple implementations** - Verify code works with Blocking and ThreadPool
6. **Use Queue for synchronization** - Io.Queue handles producer-consumer patterns
7. **Avoid blocking in async** - Don't call blocking syscalls directly in async functions
8. **Leverage idempotency** - await and cancel can be called multiple times safely

## Version Information

**Minimum Zig Version**: 0.16.0 (unreleased as of writing)

This skill targets the new async I/O design planned for Zig 0.16.0 based on:
- Loris Cro's blog post: "Zig's New Async I/O"
- Andrew Kelley's post: "Zig's New Async I/O (Text Version)"

**Status**: Implementation in progress, API subject to change

## Additional Resources

Load references for deep dives:
- `references/async-overview.md` - Complete design philosophy
- `references/io-implementations.md` - Implementation strategies
- `references/message-passing.md` - Advanced synchronization
