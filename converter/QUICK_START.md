# Zig Documentation Converter - Quick Start

## TL;DR - Most Common Commands

```bash
# 1. Navigate to converter directory
cd converter

# 2. Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Download latest documentation
python zig_docs_converter.py

# 4. Find your docs in ../docs-master/
```

## Usage Examples

All commands should be run from the `converter/` directory.

### Get Latest Zig Documentation (Master)

```bash
cd converter
python zig_docs_converter.py
```

Output: `../docs-master/` with 51 markdown files

### Get Specific Version

```bash
cd converter
python zig_docs_converter.py --version 0.15.2
```

Output: `../docs-0.15.2/` with 51 markdown files

### Get All Versions (Creates 16 Directories)

```bash
cd converter
python zig_docs_converter.py --all
```

Output:
- `../docs-0.1.1/`
- `../docs-0.2.0/`
- ...
- `../docs-0.15.2/`
- `../docs-master/`

**Note:** This will download ~16MB of documentation and may take several minutes.

### Convert Existing HTML File

```bash
cd converter
python zig_docs_converter.py --file "Documentation - The Zig Programming Language.html"
```

Output: `../docs/` directory

## What You Get

Each version directory contains:

```
docs-0.15.2/
├── README.md                      # Navigation with version info
├── 01-introduction.md             # ~1KB
├── 02-zig-standard-library.md     # ~0.5KB
├── 03-hello-world.md              # ~1KB
├── 04-comments.md                 # ~3.5KB
├── 05-values.md                   # ~13KB
├── 06-zig-test.md                 # ~11KB
├── 07-variables.md                # ~6KB
├── ...
├── 37-builtin-functions.md        # ~90KB (118 @functions)
├── ...
└── 51-appendix.md                 # ~30KB (grammar, zen)
```

**Total per version:** ~600KB, 51 files, ~15,000 lines

## Directory Structure After Running

```bash
# After: cd converter && python zig_docs_converter.py --version 0.15.2
zig-docs/
├── converter/
│   ├── venv/             # Python virtual environment
│   ├── zig_docs_converter.py
│   ├── requirements.txt
│   └── ...
├── docs-0.15.2/          # ← 51 markdown files
└── README files...

# After: cd converter && python zig_docs_converter.py --all
zig-docs/
├── converter/
│   ├── venv/
│   └── ...
├── docs-0.1.1/           # ← 51 markdown files
├── docs-0.2.0/           # ← 51 markdown files
├── ...
├── docs-0.15.2/          # ← 51 markdown files
├── docs-master/          # ← 51 markdown files
└── ...
```

## Version List

| Version | Release Date | Notes |
|---------|--------------|-------|
| master  | Rolling | Latest development version |
| 0.15.2  | 2025 | Latest stable |
| 0.14.1  | 2024 | |
| 0.13.0  | 2024 | |
| 0.12.1  | 2024 | |
| 0.11.0  | 2023 | |
| 0.10.1  | 2023 | |
| 0.9.1   | 2022 | |
| 0.8.1   | 2021 | |
| 0.7.1   | 2021 | |
| 0.6.0   | 2020 | |
| 0.5.0   | 2019 | |
| 0.4.0   | 2019 | |
| 0.3.0   | 2018 | |
| 0.2.0   | 2018 | |
| 0.1.1   | 2017 | First documented version |

## Troubleshooting

### Virtual Environment Issues (macOS)

```bash
# If you get externally-managed-environment error:
cd converter
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Network Issues

If download fails, try again or use a local file:

```bash
# Download manually first
curl -o zig-docs.html https://ziglang.org/documentation/master/

# Then convert
cd converter
python zig_docs_converter.py --file ../zig-docs.html
```

### Missing Dependencies

```bash
# Install manually
cd converter
pip install beautifulsoup4 markdownify requests lxml
```

## For Claude Skills

To create a Claude skill from the output:

1. Download the version you want:
   ```bash
   cd converter
   python zig_docs_converter.py --version 0.15.2
   ```

2. The `../docs-0.15.2/` directory is ready to use:
   - Each `.md` file is a separate context source
   - `README.md` provides navigation
   - Cross-references are preserved

3. Point your Claude skill to the `../docs-0.15.2/` directory

## Advanced Usage

### Custom Output Directory

```bash
cd converter
python zig_docs_converter.py --version 0.15.2 --output ../my-zig-docs
```

### Multiple Versions for Comparison

```bash
# Get two versions to compare
cd converter
python zig_docs_converter.py --version 0.14.1
python zig_docs_converter.py --version 0.15.2

# Now you can diff them
cd ..
diff docs-0.14.1/03-hello-world.md docs-0.15.2/03-hello-world.md
# Or use compare script
converter/compare_versions.sh 0.14.1 0.15.2 03-hello-world.md
```

### Custom URL (Beta/Nightly Builds)

```bash
cd converter
python zig_docs_converter.py --url https://ziglang.org/documentation/master/
```

## Performance

- Single version: ~30-60 seconds
- All versions (--all): ~8-15 minutes
- Disk space per version: ~600KB

## Next Steps

- See [converter/USAGE.md](converter/USAGE.md) for detailed converter options
- Check [README.md](README.md) for full documentation
- View example output in `docs-test/`, `docs-master/`, or `docs-0.15.2/`
- Explore [zig-programming/README.md](zig-programming/README.md) for the Zig programming skill
