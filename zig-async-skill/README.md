# Zig Async I/O Skill (0.16.0+)

A comprehensive Claude skill for Zig's new async I/O design planned for version 0.16.0.

## Overview

This skill provides expertise in Zig's redesigned async I/O system based on the `std.Io` interface. Unlike the old async/await (removed in 0.11), the new design **decouples concurrency expression from execution models**, allowing code to work optimally across synchronous, multi-threaded, and event-driven contexts.

## Key Concepts

**Critical Distinction: Asynchrony ≠ Concurrency**
- **Async** (`io.async()`): Operations *can* proceed out-of-order
- **Concurrent** (`io.concurrent()`): Operations *must* proceed simultaneously

## What's Included

### References (2 files)
- `async-overview.md` - Complete design philosophy and rationale
- `async-vs-concurrent.md` - Critical distinction explained with examples

### Examples (3 complete programs)
- `basic_async.zig` - Simple async operations with io.async()
- `concurrent_tasks.zig` - Producer-consumer patterns with io.concurrent()
- `cancellation.zig` - Proper task cancellation and resource cleanup

### Templates (1 comprehensive template)
- `async-function.zig` - Multiple async function patterns and best practices

## Quick Start

1. **Load the skill** in Claude Code:
   ```
   Copy zig-async-io directory to ~/.claude/skills/
   ```

2. **Start using async patterns**:
   ```zig
   const std = @import("std");

   fn processFiles(io: *std.Io, data: []const u8) !void {
       // Spawn async operations
       var fut_a = io.async(saveFile, .{io, data, "a.txt"});
       var fut_b = io.async(saveFile, .{io, data, "b.txt"});

       // Await results
       try fut_a.await(io);
       try fut_b.await(io);
   }
   ```

## Design Philosophy

The new async I/O follows these principles:

1. **No function coloring** - Same code works in sync and async contexts
2. **Runtime polymorphism** - Choose execution model at runtime
3. **Zero overhead for sync** - Blocking I/O maps directly to syscalls
4. **Explicit dependencies** - `concurrent()` makes parallelism requirements clear
5. **Progressive enhancement** - Start with blocking, upgrade to async later

## Core API

```zig
const Io = struct {
    // Spawn async work (may execute immediately or be scheduled)
    fn async(self: *Io, func: anytype, args: anytype) Future

    // Spawn concurrent work (requires parallelism)
    fn concurrent(self: *Io, func: anytype, args: anytype) !Future

    // Message passing primitive
    fn Queue(comptime T: type) type
};

const Future = struct {
    // Wait for result (idempotent)
    fn await(self: *Future, io: *Io) !T

    // Cancel and retrieve result (idempotent)
    fn cancel(self: *Future, io: *Io) !T
};
```

## I/O Implementations

1. **Blocking I/O** - Standard syscalls, zero overhead
2. **Thread Pool** (`std.Io.Threaded`) - Multiplexes across OS threads
3. **Event Loop** - io_uring/kqueue with green threads (future)
4. **Stackless Coroutines** - State machine rewriting (future)

## When to Use What

### Use `io.async()` for:
- Independent operations that can run in any order
- Optional parallelism
- Code that should work with blocking I/O

### Use `io.concurrent()` for:
- Producer-consumer patterns
- Bidirectional communication
- Operations that MUST run simultaneously

## Common Patterns

### Pattern 1: Parallel File Operations
```zig
var fut_a = io.async(saveFile, .{io, data, "a.txt"});
var fut_b = io.async(saveFile, .{io, data, "b.txt"});
try fut_a.await(io);
try fut_b.await(io);
```

### Pattern 2: Resource Cleanup with Defer
```zig
var future = io.async(operation, .{io});
defer if (future.cancel(io)) |result| {
    cleanup(result);
} else |_| {};

try future.await(io);
```

### Pattern 3: Producer-Consumer
```zig
var queue = io.Queue(Task).init();

var prod = try io.concurrent(producer, .{io, &queue});
var cons = try io.concurrent(consumer, .{io, &queue});

try prod.await(io);
try cons.await(io);
```

## Version Information

**Target Version**: Zig 0.16.0 (unreleased)
**Status**: Implementation in progress, API subject to change

Based on:
- Loris Cro's blog post: "Zig's New Async I/O"
- Andrew Kelley's post: "Zig's New Async I/O (Text Version)"

## Migration from Old Async

**Old (pre-0.11)**:
```zig
var frame_a = async saveFile(data, "a.txt");
try await frame_a;
```

**New (0.16.0+)**:
```zig
var fut_a = io.async(saveFile, .{io, data, "a.txt"});
try fut_a.await(io);
```

## Best Practices

1. **Pass Io explicitly** - Like allocators, pass as parameter not global
2. **Default to async** - Use `io.async()` unless concurrent truly needed
3. **Always handle cancellation** - Use defer pattern for cleanup
4. **Test with blocking I/O first** - Reveals dependency issues early
5. **Understand async ≠ concurrent** - Critical for correct code

## Examples Included

### basic_async.zig
Demonstrates:
- Sequential and parallel async operations
- Error handling in async code
- Cleanup with defer
- Chaining async operations
- Working with different I/O implementations

### concurrent_tasks.zig
Demonstrates:
- Producer-consumer patterns
- Multiple producers/consumers
- Worker pool pattern
- Bidirectional communication
- Io.Queue for message passing

### cancellation.zig
Demonstrates:
- Basic cancellation with defer
- Resource cleanup on cancellation
- Timeout patterns
- Idempotent cancel/await
- Graceful shutdown
- Error path cancellation

## References

### async-overview.md (100+ lines)
Complete design philosophy covering:
- Problems with old async
- The new Io interface design
- Design goals and rationale
- Comparison with other approaches
- Future enhancements

### async-vs-concurrent.md (200+ lines)
Deep dive into the critical distinction:
- Definition and examples
- Decision matrix
- Common mistakes
- Testing strategies
- Real-world examples

## Using the Skill

When you activate this skill in Claude Code, ask questions like:

- "How do I write async functions in Zig 0.16?"
- "What's the difference between async and concurrent?"
- "Show me a producer-consumer pattern"
- "How do I handle cancellation properly?"
- "How do I migrate from old async to new async?"

The skill provides context-aware assistance based on your needs.

## Contributing

This skill is based on publicly available blog posts about Zig 0.16.0's planned async design. As the implementation evolves, this skill will be updated to reflect the actual API.

## License

This skill is provided as-is for educational purposes. Zig and its documentation are subject to their own licenses.

## Additional Resources

- [Zig's New Async I/O - Loris Cro](https://kristoff.it/blog/zig-new-async-io/)
- [Zig's New Async I/O (Text) - Andrew Kelley](https://andrewkelley.me/post/zig-new-async-io-text-version.html)
- [Zig GitHub Discussions](https://github.com/ziglang/zig/discussions)

## Status

⚠️ **Pre-release**: This skill targets Zig 0.16.0 which is not yet released. API details may change.

The skill is ready to use for:
- Learning the new async design
- Understanding async/concurrent distinction
- Preparing for 0.16.0 release
- Writing forward-compatible async patterns

## File Structure

```
zig-async-skill/
├── SKILL.md                      # Main skill file (200 lines)
├── README.md                     # This file
├── references/
│   ├── async-overview.md         # Design philosophy (150 lines)
│   └── async-vs-concurrent.md    # Critical distinction (250 lines)
├── examples/
│   ├── basic_async.zig          # Basic async patterns (230 lines)
│   ├── concurrent_tasks.zig     # Concurrent patterns (280 lines)
│   └── cancellation.zig         # Cancellation patterns (300 lines)
└── assets/
    └── templates/
        └── async-function.zig    # Function templates (280 lines)
```

**Total**: ~1,700 lines of documentation and code examples

---

Built with insights from the Zig community and core team blog posts.
