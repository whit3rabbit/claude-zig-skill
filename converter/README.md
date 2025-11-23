# Zig Documentation Converter

Convert official Zig documentation from HTML to organized markdown files. Downloads any version from ziglang.org and splits it into 51 numbered markdown files, perfect for version control, offline reading, or building tools like the Zig Programming Skill.

## Recommended: Use the Unified Build Pipeline

**If you're updating the Zig Programming Skill**, use the unified build pipeline instead of running this converter directly:

```bash
cd ../zig-programming
python scripts/build_references.py --version 0.15.2
```

This automatically handles conversion, consolidation, and cleanup in one command. See [Integration with Zig Programming Skill](#integration-with-zig-programming-skill) below.

## Standalone Quick Start

For standalone usage or advanced scenarios:

```bash
# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Download latest documentation
python zig_docs_converter.py

# Find output in ../zig-programming/docs-master/
```

## Installation

### Requirements

- Python 3.7+
- beautifulsoup4
- markdownify
- requests
- lxml

### Setup

```bash
cd converter

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate  # On Windows

# Install dependencies
pip install -r requirements.txt
```

## Usage

### Basic Commands

```bash
# Download latest (master branch)
python zig_docs_converter.py

# Download specific version
python zig_docs_converter.py --version 0.15.2

# Download all versions (takes 8-15 minutes)
python zig_docs_converter.py --all

# Convert local HTML file
python zig_docs_converter.py --file "Documentation - The Zig Programming Language.html"

# Custom output directory
python zig_docs_converter.py --version 0.15.2 --output ../my-docs

# Enable verbose logging
python zig_docs_converter.py --verbose
```

### Advanced Usage

**Download multiple specific versions:**
```bash
for version in 0.13.0 0.14.1 0.15.2 master; do
    python zig_docs_converter.py --version $version
done
```

**Batch processing with error handling:**
```bash
python zig_docs_converter.py --all --verbose 2>&1 | tee conversion.log
```

**Use with local HTML backup:**
```bash
# Download HTML first (useful for slow connections)
curl -o zig-master.html https://ziglang.org/documentation/master/
python zig_docs_converter.py --file zig-master.html
```

## Features

- **16 Zig versions supported** - From 0.1.1 to master
- **51 files per version** - One markdown file per major section
- **Smart link resolution** - Cross-file references automatically fixed
- **Clean markdown output** - Code blocks, tables, and lists properly formatted
- **Fast processing** - 30-60 seconds per version
- **Batch downloads** - Download all versions with `--all` flag
- **Local file support** - Convert downloaded HTML files offline
- **Version auto-detection** - Automatically extracts version from HTML

## Output Structure

**Standalone converter** creates a directory `../zig-programming/docs-{version}/` containing:

**Unified build pipeline** uses `.temp/docs-{version}/` (auto-cleaned after consolidation).

```
docs-0.15.2/
├── README.md                    # Table of contents with version info
├── 01-introduction.md           # Introduction and overview
├── 02-zig-standard-library.md   # Standard library overview
├── 03-hello-world.md            # Getting started
├── 04-comments.md               # Comment syntax
├── 05-values.md                 # Values and literals
...
├── 27-functions.md              # Function definitions
├── 28-errors.md                 # Error handling
...
├── 37-builtin-functions.md      # All @builtin functions
├── 38-build-system.md           # Build.zig reference
...
└── 51-appendix.md               # Grammar, Zen of Zig, style guide
```

**Per version statistics:**
- 51 markdown files
- ~15,000 lines of documentation
- ~600KB total size
- 574 code examples (varies by version)
- Full table of contents with cross-links

## Available Versions

**Stable Releases:**
`0.1.1` | `0.2.0` | `0.3.0` | `0.4.0` | `0.5.0` | `0.6.0` | `0.7.1` | `0.8.1` | `0.9.1` | `0.10.1` | `0.11.0` | `0.12.1` | `0.13.0` | `0.14.1` | `0.15.2`

**Development:**
`master`

**Note:** Versions 0.1.1, 0.4.0, and 0.5.0 have non-standard HTML structure and may require special handling.

## Version Comparison

Compare changes between Zig versions:

```bash
# Using the compare script
./compare_versions.sh 0.14.1 0.15.2 27-functions.md

# Using diff directly
cd ..
diff -u zig-programming/docs-0.14.1/27-functions.md zig-programming/docs-0.15.2/27-functions.md

# Compare entire versions
diff -ru zig-programming/docs-0.14.1/ zig-programming/docs-0.15.2/

# Find what changed in builtin functions
diff zig-programming/docs-0.14.1/37-builtin-functions.md zig-programming/docs-0.15.2/37-builtin-functions.md | grep "^[<>]" | head -20
```

## How It Works

### Conversion Pipeline

1. **Fetch HTML** - Downloads from ziglang.org or reads local file
2. **Parse Table of Contents** - Extracts navigation structure (handles both modern and legacy formats)
3. **Extract Sections** - Pulls content for each documentation section
4. **Convert to Markdown** - Transforms HTML to clean markdown
5. **Clean Formatting** - Removes excessive blank lines and fixes spacing
6. **Fix Internal Links** - Updates cross-file references (e.g., `#Values` → `05-values.md#Values`)
7. **Generate README** - Creates navigation table of contents

### Link Resolution

Internal documentation links are automatically rewritten for the multi-file structure:

**Original (single-file HTML):**
```markdown
[Values](#Values)
[See @import](#import)
```

**Fixed (multi-file markdown):**
```markdown
[Values](05-values.md#Values)
[See @import](37-builtin-functions.md#import)
```

The converter maintains a section map that tracks which heading IDs belong to which output files.

### Preserved Elements

The converter carefully preserves:

- **Code blocks** with language tags (zig, shell, c, etc.)
- **File citations** in code examples (e.g., `shell_hello_world.sh`)
- **Tables** converted to markdown format
- **Definition lists** (`<dl>`, `<dt>`, `<dd>`)
- **Note blocks** (`<aside>`) converted to blockquotes
- **Inline code** with proper escaping of special characters

### HTML Structure Variations

The converter handles different HTML formats across Zig versions:

**Modern (0.9.1+):**
- Uses `<nav aria-labelledby='table-of-contents'>`
- Headings use `<h2 id="Section">`
- Clean semantic HTML

**Legacy (0.7.1-0.8.1):**
- Uses `<div id="toc">`
- Headings use `<h2 id="toc-Section">`
- Requires prefix stripping

**Older (0.3.0-0.6.0):**
- Uses `<div id="index">`
- Various heading formats
- More complex parsing

**Ancient (0.2.0):**
- Uses `<div id="nav">`
- Mixed `<h1>` and `<h2>` structure
- Legacy code block handling

## Performance

| Operation | Time | Disk Space | Network |
|-----------|------|------------|---------|
| Single version | 30-60s | ~600KB | ~1MB |
| All versions (16) | 8-15m | ~10MB | ~16MB |
| Local file conversion | 5-10s | ~600KB | None |

**Factors affecting speed:**
- Network latency to ziglang.org
- HTML size (varies by version)
- Number of sections being processed
- Local disk I/O performance

## Troubleshooting

### Virtual Environment Error (macOS)

```bash
cd converter
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**If you see "command not found: python"**, try `python3` instead of `python`.

### Network Timeout

```bash
# Download HTML first
curl -o zig-docs.html https://ziglang.org/documentation/master/

# Convert offline
python zig_docs_converter.py --file zig-docs.html
```

### Missing Dependencies

```bash
# Install all dependencies
pip install beautifulsoup4 markdownify requests lxml

# Or use requirements file
pip install -r requirements.txt
```

### Permission Errors

```bash
# Ensure output directory is writable
chmod 755 ../zig-programming/docs-*

# Or specify a different output directory
python zig_docs_converter.py --output ~/my-zig-docs
```

### Conversion Errors for Specific Versions

Some older versions (0.1.1, 0.4.0, 0.5.0) have non-standard HTML structure:

```bash
# Try with verbose logging to see errors
python zig_docs_converter.py --version 0.4.0 --verbose

# Use local file and manually inspect HTML
curl -o zig-0.4.0.html https://ziglang.org/documentation/0.4.0/
# Open in browser to check structure
```

### Output Files Not Created

Check:
1. Virtual environment is activated
2. Dependencies are installed: `pip list | grep -E "beautifulsoup4|markdownify"`
3. Output directory exists and is writable
4. No firewall blocking ziglang.org

## Integration with Zig Programming Skill

The converter is part of an automated build pipeline for the Zig Programming Skill.

### Recommended: Unified Build Pipeline

**Use this one-command approach for skill maintenance:**

```bash
cd ../zig-programming
python scripts/build_references.py --version 0.15.2
```

This unified pipeline automatically:
1. Downloads and converts HTML to markdown (→ `.temp/docs-{version}/`)
2. Consolidates markdown into themed references (→ `skill/references/v{version}/`)
3. Cleans up temporary files

**Benefits:**
- Single command instead of multi-step manual process
- Automatic cleanup of intermediate files (saves ~7MB per version)
- Error handling and progress tracking
- Consistent output locations

See `../zig-programming/scripts/README.md` for detailed documentation.

### Advanced: Standalone Converter Usage

**For advanced scenarios or debugging**, you can run the converter standalone:

```bash
# Run converter directly (creates files in ../zig-programming/docs-{version}/)
cd converter
python zig_docs_converter.py --version 0.15.2

# Then manually consolidate if needed
cd ../zig-programming
python scripts/consolidator.py ../converter/docs-0.15.2 skill/references/v0.15.2 --version 0.15.2
```

**When to use standalone mode:**
- Testing converter changes
- Debugging conversion issues with `--verbose`
- Converting documentation for non-skill purposes
- Inspecting intermediate markdown before consolidation

**Output Structure:**
- Converter creates: `../zig-programming/docs-{version}/` (51 markdown files)
- Build pipeline uses: `.temp/docs-{version}/` (auto-cleaned)
- Final output: `skill/references/v{version}/` (19 consolidated reference files)

## Contributing

### Adding Support for New Zig Versions

When a new Zig version is released:

1. **Add version to the list:**

Edit `zig_docs_converter.py` (around line 680):
```python
AVAILABLE_VERSIONS = [
    '0.1.1', '0.2.0', ..., '0.15.2', '0.16.0', 'master'
]
```

2. **Test conversion using unified pipeline (recommended):**
```bash
cd ../zig-programming
python scripts/build_references.py --version 0.16.0 --keep-temp --verbose
```

Or test converter standalone:
```bash
cd converter
python zig_docs_converter.py --version 0.16.0 --verbose
```

3. **Check for HTML structure changes:**
- If conversion fails, inspect the HTML at https://ziglang.org/documentation/0.16.0/
- Look for changes in TOC structure, heading formats, or code block styles
- Update parser logic if needed

4. **Verify output:**
```bash
# If using unified pipeline
ls -lah ../zig-programming/skill/references/v0.16.0/
# Should have 19 consolidated reference files

# If using standalone converter
ls -lah ../zig-programming/docs-0.16.0/
# Should have 51 markdown files

# Check cross-links work
grep -r "\[.*\](.*\.md" ../zig-programming/.temp/docs-0.16.0/ | head
```

5. **Update documentation:**
- Add version to this README
- Update main project README
- Add migration notes to `skill/references/version-differences.md` if there are breaking changes
- Update `scripts/build_references.py` SUPPORTED_VERSIONS list

### Improving the Converter

**Code structure:**
- `ZigMarkdownConverter` - Custom HTML to markdown converter
  - `convert_figure()` - Handles code blocks with captions
  - `convert_pre()` - Legacy code blocks
  - `convert_code()` - Inline code
  - `convert_aside()` - Note blocks
  - `convert_dl()` - Definition lists

**Key functions:**
- `fetch_html()` - Downloads from URL
- `read_local_file()` - Reads local HTML
- `parse_toc()` - Extracts table of contents
- `extract_section_content()` - Pulls section HTML
- `convert_soup()` - HTML to markdown conversion
- `clean_markdown()` - Post-processing cleanup
- `fix_internal_links()` - Updates cross-references
- `generate_readme()` - Creates TOC file

**Testing changes:**
```bash
# Test on multiple versions
for v in 0.11.0 0.13.0 0.15.2 master; do
    echo "Testing $v..."
    python zig_docs_converter.py --version $v --verbose
done

# Verify no regressions
./compare_versions.sh 0.15.2 0.15.2 37-builtin-functions.md
# Should show no differences
```

## Related Documentation

- **[USAGE.md](USAGE.md)** - Detailed command-line reference and examples
- **[../README.md](../README.md)** - Main project documentation
- **[../CLAUDE.md](../CLAUDE.md)** - Developer guidance for working with this codebase

## License

Converter tool is MIT licensed. Zig documentation content is subject to Zig's license.

## See Also

- [Official Zig Documentation](https://ziglang.org/documentation/)
- [Zig GitHub Repository](https://github.com/ziglang/zig)
- [Zig Programming Skill](../zig-programming/README.md)

---

**For help:** `python zig_docs_converter.py --help`
