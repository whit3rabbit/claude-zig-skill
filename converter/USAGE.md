# Zig Documentation Converter - Usage Guide

## Overview

This Python script converts the official Zig documentation from HTML to organized markdown files, split by major sections. It supports downloading multiple versions and automatically organizing them into version-specific directories.

## Installation

1. **Create a virtual environment (recommended):**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On macOS/Linux
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## Quick Start

### Download Latest (Master) Documentation

Simply run without arguments:
```bash
python zig_docs_converter.py
```
Output: `docs-master/` directory

### Download Specific Version

```bash
python zig_docs_converter.py --version 0.15.2
```
Output: `docs-0.15.2/` directory

### Download All Versions

```bash
python zig_docs_converter.py --all
```
Output: `docs-0.1.1/`, `docs-0.2.0/`, ..., `docs-master/`

## Available Versions

- `0.1.1`, `0.2.0`, `0.3.0`, `0.4.0`, `0.5.0`, `0.6.0`
- `0.7.1`, `0.8.1`, `0.9.1`, `0.10.1`, `0.11.0`, `0.12.1`
- `0.13.0`, `0.14.1`, `0.15.2`
- `master` (latest development version)

## All Options

### Version-Based Downloads

```bash
# Default: Download master
python zig_docs_converter.py

# Specific version
python zig_docs_converter.py --version 0.15.2
python zig_docs_converter.py -v 0.14.1

# All versions
python zig_docs_converter.py --all
```

### Local File Conversion

```bash
python zig_docs_converter.py --file "Documentation - The Zig Programming Language.html"
```
Output: `docs/` directory (default)

### Custom URL

```bash
python zig_docs_converter.py --url https://ziglang.org/documentation/0.14.1/
```

### Custom Output Directory

```bash
# With version download
python zig_docs_converter.py --version 0.15.2 --output my-custom-dir

# With local file
python zig_docs_converter.py --file docs.html --output my-docs
```

## Command Reference

```
Options:
  --version, -v VERSION     Download specific Zig version
  --all                     Download all available versions
  --file PATH               Convert local HTML file
  --url URL                 Fetch from custom URL
  --output, -o DIR          Custom output directory
  -h, --help               Show help message
```

**Note:** `--version`, `--all`, `--file`, and `--url` are mutually exclusive.

## Output Structure

### Single Version

When downloading a single version (e.g., `--version 0.15.2`):

```
docs-0.15.2/
├── README.md                      # Table of contents with version info
├── 01-introduction.md             # Introduction section
├── 02-zig-standard-library.md     # Zig Standard Library section
├── 03-hello-world.md              # Hello World section
├── ...
├── 37-builtin-functions.md        # All 118 @builtin functions
├── ...
└── 51-appendix.md                 # Appendix section
```

### All Versions

When using `--all`:

```
zig-docs/
├── docs-0.1.1/
│   ├── README.md
│   ├── 01-introduction.md
│   └── ...
├── docs-0.2.0/
│   ├── README.md
│   ├── 01-introduction.md
│   └── ...
├── ...
├── docs-0.15.2/
│   ├── README.md
│   ├── 01-introduction.md
│   └── ...
└── docs-master/
    ├── README.md
    ├── 01-introduction.md
    └── ...
```

## Features

✓ **Version Management** - Download specific versions or all versions at once
✓ **16 Zig versions** - Support for all releases from 0.1.1 to master
✓ **Auto-organized** - Each version in its own directory (e.g., `docs-0.15.2/`)
✓ **51 separate files** - One per major documentation section
✓ **Preserved formatting** - Code blocks with syntax types (zig, shell, c, etc.)
✓ **Cross-file links** - Internal links automatically updated to point to correct files
✓ **Clean markdown** - Tables, lists, and inline code properly converted
✓ **Filenames preserved** - Code examples show original filenames
✓ **Navigation README** - Generated table of contents with version info

## For Claude Skills

The output is optimized for creating Claude skills:

1. Each version in separate directory for version-specific skills
2. Each section is a separate file for modular loading
3. Files are numbered for logical ordering
4. Cross-references between sections are maintained
5. Clean markdown format for better parsing
6. Version info included in README for context

## Example Output

**Input HTML:**
```html
<h2 id="Hello-World">Hello World</h2>
<figure><figcaption class="zig-cap"><cite>hello.zig</cite></figcaption>
<pre><code><span class="tok-kw">const</span> std = ...</code></pre>
</figure>
```

**Output Markdown:**
```markdown
## Hello World

**`hello.zig`:**
```zig
const std = @import("std");
\```
```

## Updating Documentation

### Keep Up-to-Date with Master

```bash
# Just run without arguments to get latest master
python zig_docs_converter.py
```

### Download Specific Versions

```bash
# Latest stable release
python zig_docs_converter.py --version 0.15.2

# Older version
python zig_docs_converter.py --version 0.14.1
```

### Download Everything

```bash
# Get all versions for comparison or archival
python zig_docs_converter.py --all
```

## Statistics

From the 1MB HTML file, the script generates:
- **51 markdown files** (one per major section)
- **~15,600 total lines** of markdown
- **574 code examples** properly formatted
- **100% of internal links** updated for cross-file navigation

## Requirements

- Python 3.7+
- beautifulsoup4
- markdownify
- requests (for URL fetching)
- lxml

See `requirements.txt` for exact versions.
