#!/bin/bash
# Compare two Zig documentation versions

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version1> <version2>"
    echo ""
    echo "Examples:"
    echo "  $0 0.14.1 0.15.2"
    echo "  $0 0.15.2 master"
    echo ""
    echo "Available versions:"
    echo "  0.1.1, 0.2.0, 0.3.0, 0.4.0, 0.5.0, 0.6.0"
    echo "  0.7.1, 0.8.1, 0.9.1, 0.10.1, 0.11.0, 0.12.1"
    echo "  0.13.0, 0.14.1, 0.15.2, master"
    exit 1
fi

VERSION1=$1
VERSION2=$2
DIR1="docs-$VERSION1"
DIR2="docs-$VERSION2"

# Check if directories exist
if [ ! -d "$DIR1" ]; then
    echo "Error: $DIR1 not found"
    echo "Run: python zig_docs_converter.py --version $VERSION1"
    exit 1
fi

if [ ! -d "$DIR2" ]; then
    echo "Error: $DIR2 not found"
    echo "Run: python zig_docs_converter.py --version $VERSION2"
    exit 1
fi

echo "Comparing Zig Documentation: $VERSION1 vs $VERSION2"
echo "=================================================="
echo ""

# Compare file counts
COUNT1=$(ls -1 "$DIR1"/*.md 2>/dev/null | wc -l | tr -d ' ')
COUNT2=$(ls -1 "$DIR2"/*.md 2>/dev/null | wc -l | tr -d ' ')

echo "File counts:"
echo "  $VERSION1: $COUNT1 files"
echo "  $VERSION2: $COUNT2 files"
echo ""

# Show differences in interesting files
INTERESTING_FILES=(
    "03-hello-world.md"
    "27-functions.md"
    "37-builtin-functions.md"
    "28-errors.md"
    "33-comptime.md"
)

echo "Checking key sections for differences..."
echo ""

for file in "${INTERESTING_FILES[@]}"; do
    if [ -f "$DIR1/$file" ] && [ -f "$DIR2/$file" ]; then
        SIZE1=$(wc -c < "$DIR1/$file" | tr -d ' ')
        SIZE2=$(wc -c < "$DIR2/$file" | tr -d ' ')
        DIFF=$(( SIZE2 - SIZE1 ))

        if [ $DIFF -eq 0 ]; then
            echo "  $file: No size change"
        elif [ $DIFF -gt 0 ]; then
            echo "  $file: +$DIFF bytes (grew)"
        else
            echo "  $file: $DIFF bytes (shrank)"
        fi
    fi
done

echo ""
echo "To see detailed diff of a specific file:"
echo "  diff $DIR1/FILE.md $DIR2/FILE.md"
echo ""
echo "To see side-by-side comparison:"
echo "  diff -y $DIR1/FILE.md $DIR2/FILE.md | less"
echo ""
echo "Popular files to compare:"
for file in "${INTERESTING_FILES[@]}"; do
    echo "  - $file"
done
