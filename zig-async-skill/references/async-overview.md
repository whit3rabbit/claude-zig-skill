# Zig Async I/O Design Overview

## Philosophy

Zig 0.16.0's async I/O design follows a fundamental principle: **decouple concurrency expression from execution implementation**.

### The Problem with Old Async

The original async/await system (pre-0.11) tightly coupled async operations to stackless coroutines:

**Issues**:
- **Execution model virality** - Once a function was async, all callers became async
- **Function coloring** - Hard boundary between sync and async code
- **Implementation lock-in** - Async always meant stackless coroutines
- **Runtime overhead** - Even when parallelism wasn't needed

These issues led to the removal of async/await in Zig 0.11.

## The New Design: std.Io Interface

The redesign treats I/O implementation like memory allocation - as a **runtime parameter** rather than a compile-time decision.

### Key Innovation

```zig
pub fn processData(io: *std.Io, allocator: Allocator, data: []const u8) !void {
    // Just like we pass allocator, we pass io
    var future = io.async(helper, .{io, data});
    try future.await(io);
}
```

The same code works optimally whether `io` is:
- **Blocking I/O** - Executes synchronously with zero overhead
- **Thread Pool** - Distributes work across OS threads
- **Event Loop** - Uses io_uring/kqueue for async I/O
- **Stackless** - Rewrites to state machines (future)

## Design Goals

### 1. Eliminate Function Coloring

**Before (old async)**:
```zig
async fn foo() !void { ... }  // Async function
fn bar() !void { ... }         // Sync function
// Cannot mix freely - different "colors"
```

**After (new async)**:
```zig
fn foo(io: *Io) !void { ... }
fn bar(io: *Io) !void { ... }
// Both can use async or not - same "color"
```

No source-level or runtime virality.

### 2. Code Reusability

Libraries written once work across:
- CLI tools (blocking I/O)
- Servers (thread pools or event loops)
- Embedded systems (custom I/O implementations)

### 3. Optimal Performance

- **De-virtualization** - When single implementation is known, calls are devirtualized
- **No overhead for sync** - Blocking I/O maps directly to syscalls
- **Buffering at right layer** - Moved to Reader/Writer, not I/O layer

### 4. Progressive Enhancement

Start with simple blocking I/O, upgrade to async later:

```zig
// Development - simple blocking I/O
var io = std.Io.Blocking.init();

// Production - thread pool
var io = std.Io.Threaded.init(allocator, .{});

// Performance-critical - event loop
var io = std.Io.EventLoop.init(allocator);
```

Same application code works with all three.

## Core Concepts

### Asynchrony vs. Concurrency

**Critical distinction**: These are NOT the same thing.

**Asynchrony** - Operations can proceed out-of-order:
```zig
var fut1 = io.async(work1, .{});
var fut2 = io.async(work2, .{});
// Can await sequentially - that's fine!
try fut1.await(io);
try fut2.await(io);
```

With blocking I/O, both execute immediately in sequence. With event loop, they may be scheduled asynchronously.

**Concurrency** - Operations MUST proceed simultaneously:
```zig
var fut1 = try io.concurrent(producer, .{&queue});
var fut2 = try io.concurrent(consumer, .{&queue});
// MUST run simultaneously or deadlock occurs
try fut1.await(io);
try fut2.await(io);
```

Returns `error.ConcurrencyUnavailable` if I/O implementation can't provide parallelism.

### The Io Interface

Non-generic interface using vtables:

```zig
pub const Io = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        async_fn: *const fn(*anyopaque, func: anytype, args: anytype) Future,
        concurrent_fn: *const fn(*anyopaque, func: anytype, args: anytype) !Future,
        // ... other methods
    };

    pub fn async(self: *Io, func: anytype, args: anytype) Future {
        return self.vtable.async_fn(self.ptr, func, args);
    }

    pub fn concurrent(self: *Io, func: anytype, args: anytype) !Future {
        return self.vtable.concurrent_fn(self.ptr, func, args);
    }
};
```

Benefits:
- **Runtime polymorphism** - Choose implementation at runtime
- **De-virtualization** - Compiler optimizes when type is known
- **No generics** - Simpler API, faster compilation

### Future Type

```zig
pub const Future = struct {
    handle: *anyopaque,
    io: *Io,

    /// Wait for completion (idempotent)
    pub fn await(self: *Future, io: *Io) !T {
        return io.vtable.await_fn(self.handle);
    }

    /// Cancel and retrieve result (idempotent)
    pub fn cancel(self: *Future, io: *Io) !T {
        return io.vtable.cancel_fn(self.handle);
    }
};
```

**Idempotency**: Both `await` and `cancel` can be called multiple times with same result.

## Design Rationale

### Why Not Just Callbacks?

Callbacks invert control flow, making code hard to reason about:

```zig
// Callback hell
readFile("a.txt", fn(a_data) {
    readFile("b.txt", fn(b_data) {
        process(a_data, b_data, fn(result) {
            writeFile("out.txt", result, fn() {
                // done!
            });
        });
    });
});
```

vs. async/await style:

```zig
const a_data = try readFile(io, "a.txt").await(io);
const b_data = try readFile(io, "b.txt").await(io);
const result = try process(io, a_data, b_data).await(io);
try writeFile(io, "out.txt", result).await(io);
```

### Why Not Language-Level Async/Await?

Language-level async:
- Forces specific execution model
- Creates function coloring
- Adds complexity to language

Runtime-level async (Io interface):
- Flexibility in execution model
- No function coloring
- Simpler language, richer runtime

### Why Explicit Io Parameter?

Following Zig's philosophy:
- **No hidden state** - I/O strategy is explicit
- **No globals** - Pass as parameter like allocator
- **Testability** - Easy to inject test implementations
- **Composability** - Libraries can accept any I/O implementation

## Benefits Summary

| Aspect | Old Async | New Async |
|--------|-----------|-----------|
| Function coloring | Yes | No |
| Execution model | Compile-time | Runtime |
| Overhead (sync) | State machine | Zero |
| Code reuse | Limited | Universal |
| Implementation choice | Fixed | Pluggable |
| Testability | Difficult | Easy |

## Design Influences

Inspired by:
- **Zig's Allocator interface** - Runtime polymorphism via vtables
- **Go's io.Reader/Writer** - Simple, composable interfaces
- **Rust's async ecosystem** - Lessons on what to avoid (coloring)
- **POSIX I/O primitives** - sendfile, vectorized I/O

## Future Enhancements

Planned additions:
- **Stackless coroutine implementation** - Automatic state machine generation
- **More I/O implementations** - KQueue, IOCP, io_uring optimized versions
- **Async iterators** - For stream processing
- **Timeout combinators** - Built-in timeout handling
- **Select/race operations** - Wait for first of many futures

## Conclusion

The new async I/O design achieves what the old async/await couldn't:
- **Universal code** - Works in sync and async contexts
- **Zero overhead** - When async isn't needed
- **Maximum flexibility** - Choose execution model at runtime
- **Zig philosophy** - Explicit, composable, no hidden control flow

This represents a fundamental rethinking of async I/O that prioritizes **programmer control** over **magic**.
