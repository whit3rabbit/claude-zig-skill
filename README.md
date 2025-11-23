# Zig Skills for Claude Code

Two comprehensive Zig programming skills for Claude Code:

| Skill | Description | Size | Zig Version |
|-------|-------------|------|-------------|
| **zig-programming** | Complete Zig expertise with 223 recipes, multi-version docs, templates | ~1.8MB | 0.11 - 0.15.2 (stable) |
| **zig-async** | Async I/O patterns with io_uring integration | ~24KB | 0.16+ (nightly only) |

> **Most users should only install `zig-programming`.** The `zig-async` skill is for Zig 0.16+ nightly builds which reintroduce async I/O. It is not compatible with stable Zig 0.15.2.

## Quick Installation

### Option 1: Zip File (Easiest)

Download from repository root and extract:

```bash
# Main Zig skill (recommended for all users)
curl -LO https://github.com/whit3rabbit/claude-zig-skill/raw/main/zig-programming.zip
unzip zig-programming.zip -d ~/.claude/skills/zig-programming/
```

<details>
<summary>Async skill (Zig 0.16+ nightly only - not for stable 0.15.2)</summary>

```bash
# Only install if using Zig 0.16+ nightly builds
curl -LO https://github.com/whit3rabbit/claude-zig-skill/raw/main/zig-async-skill.zip
unzip zig-async-skill.zip -d ~/.claude/skills/zig-async-skill/
```
</details>

Restart Claude Code after installation.

### Option 2: Plugin Installation (Claude Code)

```bash
# Add this repo as a marketplace
/plugin marketplace add whit3rabbit/claude-zig-skill

# Install main skill (recommended for all users)
/plugin install zig-programming@whit3rabbit-claude-zig-skill

# Optional: Install async skill (only for Zig 0.16+ nightly)
# /plugin install zig-async@whit3rabbit-claude-zig-skill
```

For team distribution, add to `.claude/settings.json`:
```json
{
  "permissions": {
    "additionalPluginMarketplaces": ["whit3rabbit/claude-zig-skill"]
  }
}
```

### Verify Installation

```bash
ls ~/.claude/skills/zig-programming/SKILL.md
```

---

## zig-programming Skill

The main skill for all Zig programming needs.

### What's Included

| Component | Count | Description |
|-----------|-------|-------------|
| **Recipes** | 223 | Tested code recipes from [BBQ Cookbook](https://github.com/whit3rabbit/zig-bbq-cookbook) |
| **Reference Docs** | 13 versions | Zig 0.2.0 through master |
| **Templates** | 6 | CLI app, library, build.zig, tests, C interop |
| **Examples** | 6 | Complete working programs |

### Recipe Topics

- Fundamentals (19) - Philosophy, basics, getting started
- Data Structures (20) - Arrays, hashmaps, sets, sorting
- Strings & Text (14) - Parsing, manipulation, Unicode
- Memory & Allocators (6) - Arena, GPA, custom allocators
- Comptime (24) - Metaprogramming, generics, type reflection
- Networking (18) - HTTP, sockets, REST APIs
- Concurrency (8) - Threading, atomics, synchronization
- And 8 more topics...

### Supported Zig Versions

| Version | Status |
|---------|--------|
| 0.15.2 | Current stable (default) |
| 0.14.1, 0.13.0, 0.12.1, 0.11.0 | Fully supported |
| 0.10.1, 0.9.1, 0.8.1, 0.7.1 | Legacy support |
| 0.6.0, 0.3.0, 0.2.0 | Historical |
| master | Development |

---

## zig-async Skill

> **Warning: Nightly Only** - This skill is for Zig 0.16+ nightly builds only. Do NOT install if you're using stable Zig 0.15.2 or earlier. The async I/O model in 0.16+ is completely different from the removed async/suspend/resume in older versions.

Specialized skill for Zig's new async I/O model being developed for version 0.16+.

### What's Included

| Component | Description |
|-----------|-------------|
| **References** | async-overview.md, async-vs-concurrent.md |
| **Examples** | basic_async.zig, concurrent_tasks.zig, cancellation.zig |
| **Templates** | async-function.zig |

### Topics Covered

- io_uring integration and event loops
- Async/await patterns (new model, not the removed async/suspend/resume)
- Concurrent task management
- Cancellation and timeouts
- Error handling in async contexts

### When to Use This Skill

| Zig Version | Use This Skill? |
|-------------|-----------------|
| 0.15.2 (current stable) | No - use `zig-programming` only |
| 0.14.x and earlier | No - use `zig-programming` only |
| 0.16+ nightly | Yes - async I/O is available |

---

## Usage Examples

The skills activate automatically when working with Zig code:

```
You: "How do I iterate with an index in Zig 0.13?"
Claude: [Provides version-specific for loop syntax]

You: "Show me how to use ArenaAllocator"
Claude: [Loads Recipe 18.2 with tested code]

You: "How does async I/O work in Zig 0.16?"
Claude: [Uses zig-async skill for io_uring patterns - requires 0.16+ nightly]
```

> **Note:** For stable Zig (0.15.2 and earlier), only the `zig-programming` skill is needed. Async I/O patterns are only available in Zig 0.16+ nightly builds.

---

## Developer Guide

### Repository Structure

```
claude-zig-skill/
├── README.md                    # This file
├── CLAUDE.md                    # Claude Code project instructions
├── build-skills.sh              # Creates both zip files
├── zig-programming.zip          # Distributable (~1.8MB)
├── zig-async-skill.zip          # Distributable (~80KB)
│
├── .claude-plugin/
│   └── marketplace.json         # Plugin marketplace (lists both skills)
│
├── zig-programming/             # Main Zig skill source
│   ├── SKILL.md
│   ├── .claude-plugin/plugin.json
│   ├── references/              # Multi-version docs
│   ├── recipes/                 # 223 BBQ Cookbook recipes
│   ├── examples/
│   ├── assets/templates/
│   ├── scripts/                 # Runtime scripts
│   └── build/                   # Build tools (not distributed)
│
├── zig-async-skill/             # Async I/O skill source
│   ├── SKILL.md
│   ├── .claude-plugin/plugin.json
│   ├── references/
│   ├── examples/
│   └── assets/templates/
│
├── converter/                   # Zig HTML docs converter
│   └── zig_docs_converter.py
│
└── docs-test/                   # Test output
```

### Building Zip Files

Use the included script to create distributable zips:

```bash
# Build both skills
./build-skills.sh

# Build only zig-programming
./build-skills.sh zig

# Build only zig-async
./build-skills.sh async
```

Output files are created in the repository root.

### Key Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| `build-skills.sh` | Root | Create distributable zip files |
| `cookbook_converter.py` | `zig-programming/build/` | Pull recipes from git |
| `build_references.py` | `zig-programming/build/` | Build version docs |
| `zig_docs_converter.py` | `converter/` | Convert Zig HTML docs |

### Updating Recipes

```bash
cd zig-programming
python build/cookbook_converter.py --verbose
```

### Adding a New Zig Version

```bash
cd zig-programming
python build/build_references.py --version 0.16.0 --verbose
```

---

## Troubleshooting

### Skill Not Activating

```bash
ls -la ~/.claude/skills/zig-programming/SKILL.md
head -20 ~/.claude/skills/zig-programming/SKILL.md
```

Restart Claude Code after changes.

### Version Detection Issues

Add to your project's `CLAUDE.md`:
```markdown
This project targets Zig 0.15.2
```

---

## Links

- **This Repository**: [github.com/whit3rabbit/claude-zig-skill](https://github.com/whit3rabbit/claude-zig-skill)
- **BBQ Cookbook**: [github.com/whit3rabbit/zig-bbq-cookbook](https://github.com/whit3rabbit/zig-bbq-cookbook)
- **Official Zig Docs**: [ziglang.org/documentation](https://ziglang.org/documentation/)
- **Claude Code Skills**: [docs.claude.com/en/docs/claude-code/skills](https://docs.claude.com/en/docs/claude-code/skills)

## License

MIT License. Zig documentation content follows Zig project licensing.

---

**Version:** 1.1.0 | **Skills:** zig-programming, zig-async | **Recipes:** 223
