#!/bin/bash
#
# build-skills.sh - Create distributable zip files for Claude Code skills
#
# Usage:
#   ./build-skills.sh           # Build all skills
#   ./build-skills.sh zig       # Build only zig-programming
#   ./build-skills.sh async     # Build only zig-async-skill
#
# Output:
#   zig-programming.zip   (~1.8MB) - Main Zig programming skill
#   zig-async-skill.zip   (~80KB)  - Async I/O skill (Zig 0.16+)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Common exclusions based on .gitignore patterns
EXCLUDE_PATTERNS=(
    "build/*"
    "*/__pycache__/*"
    "*.pyc"
    "*.pyo"
    ".temp/*"
    ".DS_Store"
    "*/.DS_Store"
    "._*"
    "build-log.txt"
    "*.log"
    "*.zip"
    ".claude/*"
    "zig-out/*"
    "zig-cache/*"
    ".zig-cache/*"
    "book/*"
    "venv/*"
    ".venv/*"
    ".git/*"
    ".gitignore"
)

# Build exclusion arguments for zip
build_excludes() {
    local excludes=""
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        excludes="$excludes -x \"$pattern\""
    done
    echo "$excludes"
}

# Build a skill zip file
build_skill() {
    local skill_dir="$1"
    local zip_name="$2"

    if [[ ! -d "$skill_dir" ]]; then
        echo "Error: Directory '$skill_dir' not found"
        return 1
    fi

    echo "Building $zip_name..."

    # Remove existing zip if present
    rm -f "$zip_name"

    # Create zip from skill directory
    # The zip will contain files at root level, so when extracted to
    # ~/.claude/skills/skill-name/ the structure is correct
    cd "$skill_dir"

    # Use find to get list of files, excluding unwanted directories
    find . -type f \
        ! -path "./build/*" \
        ! -path "./.temp/*" \
        ! -path "./*/__pycache__/*" \
        ! -path "./zig-out/*" \
        ! -path "./zig-cache/*" \
        ! -path "./.zig-cache/*" \
        ! -path "./book/*" \
        ! -path "./venv/*" \
        ! -path "./.venv/*" \
        ! -path "./.git/*" \
        ! -path "./scripts/zig-programming/*" \
        ! -name "*.pyc" \
        ! -name "*.pyo" \
        ! -name ".DS_Store" \
        ! -name "._*" \
        ! -name "build-log.txt" \
        ! -name "*.log" \
        ! -name "*.zip" \
        ! -name ".gitignore" \
        -print0 | xargs -0 zip "../$zip_name"

    cd "$SCRIPT_DIR"

    # Show result
    local size=$(du -h "$zip_name" | cut -f1)
    echo "Created $zip_name ($size)"
    echo ""
}

# Main
echo "========================================"
echo "Claude Code Skills Packager"
echo "========================================"
echo ""

case "${1:-all}" in
    zig|zig-programming)
        build_skill "zig-programming" "zig-programming.zip"
        ;;
    async|zig-async|zig-async-skill)
        build_skill "zig-async-skill" "zig-async-skill.zip"
        ;;
    all|"")
        build_skill "zig-programming" "zig-programming.zip"
        build_skill "zig-async-skill" "zig-async-skill.zip"
        ;;
    *)
        echo "Usage: $0 [zig|async|all]"
        echo ""
        echo "  zig   - Build zig-programming.zip only"
        echo "  async - Build zig-async-skill.zip only"
        echo "  all   - Build both (default)"
        exit 1
        ;;
esac

echo "========================================"
echo "Done! Zip files created in repo root:"
ls -lh *.zip 2>/dev/null || echo "No zip files found"
echo ""
echo "Installation:"
echo "  unzip zig-programming.zip -d ~/.claude/skills/zig-programming/"
echo "  unzip zig-async-skill.zip -d ~/.claude/skills/zig-async-skill/"
echo "========================================"
