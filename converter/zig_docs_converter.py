#!/usr/bin/env python3
"""
Zig Documentation Converter
Converts Zig HTML documentation to organized markdown files split by sections.
"""

import argparse
import html
import logging
import re
import sys
from pathlib import Path
from typing import Dict, List

import requests
from bs4 import BeautifulSoup, Tag
from markdownify import MarkdownConverter

# Configure logging
logger = logging.getLogger(__name__)


class ZigMarkdownConverter(MarkdownConverter):
    """Custom markdown converter for Zig documentation."""

    def convert_figure(self, el, text, **kwargs):
        """Handle <figure> elements containing code blocks."""
        figcaption = el.find('figcaption')
        code_block = el.find('pre')

        if not code_block:
            return text

        # Determine language from caption class
        language = 'zig'
        filename = None

        if figcaption:
            if 'zig-cap' in figcaption.get('class', []):
                language = 'zig'
                cite = figcaption.find('cite')
                if cite:
                    filename = cite.get_text()
            elif 'shell-cap' in figcaption.get('class', []):
                language = 'shell'
            elif 'c-cap' in figcaption.get('class', []):
                language = 'c'
            elif 'peg-cap' in figcaption.get('class', []):
                language = 'peg'
            elif 'javascript-cap' in figcaption.get('class', []):
                language = 'javascript'

        # Extract code, stripping all span tags for syntax highlighting
        code_text = code_block.get_text()

        # Build markdown
        result = '\n'
        if filename:
            result += f'**`{filename}`:**\n'
        elif figcaption and figcaption.get_text().strip():
            result += f'**{figcaption.get_text().strip()}:**\n'

        # Fix: Ensure closing ``` is on its own line
        result += f'```{language}\n{code_text}\n```\n\n'
        return result

    def convert_aside(self, el, text, **kwargs):
        """Handle <aside> elements as blockquotes."""
        return f'\n> **Note:** {text}\n\n'

    def convert_dl(self, el, text, **kwargs):
        """Handle definition lists."""
        result = '\n'
        for child in el.children:
            if isinstance(child, Tag):
                if child.name == 'dt':
                    result += f'\n**{child.get_text().strip()}**\n'
                elif child.name == 'dd':
                    result += f': {child.get_text().strip()}\n'
        return result + '\n'

    def convert_pre(self, el, text, **kwargs):
        """Handle <pre> elements that aren't in figures."""
        # Check if this pre is inside a figure (already handled)
        # Traverse up the DOM tree to check all ancestors
        parent = el.parent
        while parent:
            if parent.name == 'figure':
                # Let convert_figure handle this to avoid duplicate processing
                return super().convert_pre(el, text, **kwargs)
            parent = parent.parent

        # Check if this is in a table cell (should be inline code)
        # Table cells need inline formatting, not code blocks
        parent = el.parent
        if parent and parent.name in ('td', 'th'):
            # In tables, convert to inline code
            code_elem = el.find('code')
            if code_elem:
                code_text = code_elem.get_text()
                # Remove extra whitespace/newlines for table cells
                code_text = ' '.join(code_text.split())
                return f'`{code_text}`'

        # Standalone pre block (versions 0.2.0-0.3.0 use this for code examples)
        code_elem = el.find('code')
        if code_elem:
            code_text = code_elem.get_text()

            # Detect language from code element's class attribute (legacy versions)
            # e.g., <code class="zig"> or <code class="shell">
            language = ''
            code_classes = code_elem.get('class', [])
            if code_classes:
                # Look for common language classes
                for lang in ['zig', 'shell', 'c', 'javascript', 'peg']:
                    if lang in code_classes:
                        language = lang
                        break

            # Check for preceding <p class="file"> sibling (legacy file labels)
            # In 0.2.0-0.3.0, file names appear as <p class="file">filename.zig</p>
            prev_sibling = el.find_previous_sibling()
            file_label = ''
            if prev_sibling and prev_sibling.name == 'p':
                p_classes = prev_sibling.get('class', [])
                if 'file' in p_classes:
                    filename = prev_sibling.get_text().strip()
                    file_label = f'**`{filename}`:**\n\n'

            # Check if it looks like a signature (single line with backticks)
            # Some builtin signatures are wrapped in backticks already
            if code_text.strip().startswith('`') and code_text.strip().endswith('`'):
                # Remove the extra backticks to prevent double-wrapping
                code_text = code_text.strip()[1:-1]
                return f'\n```\n{code_text}\n```\n'

            # Return formatted code block with language tag and optional file label
            return f'\n{file_label}```{language}\n{code_text}\n```\n'

        return text

    def convert_code(self, el, text, **kwargs):
        """Handle inline code, stripping syntax highlighting spans."""
        # Check if this code is inside a pre tag
        parent = el.parent
        if parent and parent.name == 'pre':
            # Let convert_pre handle this
            return text

        # Remove any remaining HTML entities
        clean_text = html.unescape(text)
        return f'`{clean_text}`'

    def convert_a(self, el, text, **kwargs):
        """Handle links, filtering out section markers."""
        # Skip the § section markers
        if 'hdr' in el.get('class', []):
            return ''

        href = el.get('href', '')
        if not href or not text.strip():
            return text

        # Keep internal anchors as-is for now (will be fixed later)
        return f'[{text}]({href})'

    def convert_caption(self, el, text, **kwargs):
        """Handle table captions - skip them since heading provides context."""
        # Table captions duplicate the section heading, so omit them
        return ''

    def convert_p(self, el, text, **kwargs):
        """Handle paragraph elements, with special handling for file labels."""
        # Check if this is a file label paragraph (legacy versions 0.2.0-0.3.0)
        # e.g., <p class="file">filename.zig</p>
        p_classes = el.get('class', [])
        if 'file' in p_classes:
            # Check if the next sibling is a <pre> block
            next_sibling = el.find_next_sibling()
            if next_sibling and next_sibling.name == 'pre':
                # Skip this paragraph - it will be handled by convert_pre
                return ''

        # Normal paragraph processing
        return super().convert_p(el, text, **kwargs)


def create_markdown_converter():
    """Create a configured markdown converter."""
    return ZigMarkdownConverter(
        heading_style='ATX',
        bullets='-',
        strip=['script', 'style'],
        escape_asterisks=False,
        escape_underscores=False,
    )


def fetch_html(url: str) -> str:
    """Fetch HTML content from URL.

    Args:
        url: The URL to fetch HTML from

    Returns:
        The HTML content as a string

    Raises:
        SystemExit: If the HTTP request fails
    """
    logger.info("Fetching documentation from %s...", url)
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        logger.debug("Successfully fetched %d bytes", len(response.text))
        return response.text
    except requests.Timeout:
        logger.error("Request timed out after 30 seconds")
        sys.exit(1)
    except requests.HTTPError as e:
        logger.error("HTTP error occurred: %s", e)
        sys.exit(1)
    except requests.RequestException as e:
        logger.error("Error fetching URL: %s", e)
        sys.exit(1)


def read_local_file(filepath: str) -> str:
    """Read HTML content from local file.

    Args:
        filepath: Path to the local HTML file

    Returns:
        The HTML content as a string

    Raises:
        SystemExit: If the file cannot be read
    """
    logger.info("Reading local file: %s...", filepath)
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        logger.debug("Successfully read %d bytes from file", len(content))
        return content
    except FileNotFoundError:
        logger.error("File not found: %s", filepath)
        sys.exit(1)
    except PermissionError:
        logger.error("Permission denied when reading file: %s", filepath)
        sys.exit(1)
    except IOError as e:
        logger.error("Error reading file: %s", e)
        sys.exit(1)


def slugify(text: str) -> str:
    """Convert text to a URL-safe slug."""
    # Remove special characters and convert to lowercase
    slug = re.sub(r'[^\w\s-]', '', text.lower())
    # Replace whitespace with hyphens
    slug = re.sub(r'[-\s]+', '-', slug)
    return slug.strip('-')


def parse_toc(soup: BeautifulSoup) -> List[Dict]:
    """Parse the table of contents to extract section structure.

    Supports both modern (0.9.1+) and legacy (0.2.0-0.8.1) HTML structures.

    Args:
        soup: BeautifulSoup parsed HTML document

    Returns:
        List of dictionaries containing section metadata (number, id, title, filename)
    """
    logger.info("Parsing table of contents...")

    toc_sections = []

    # Try modern format first (versions 0.9.1+)
    # Modern docs use: <nav aria-labelledby='table-of-contents'>
    toc_nav = soup.find('nav', attrs={'aria-labelledby': 'table-of-contents'})

    # Fall back to legacy format (versions 0.7.1-0.8.1)
    # Legacy docs use: <div id="toc">
    if not toc_nav:
        logger.debug("Modern TOC format not found, trying legacy format with id='toc'...")
        toc_nav = soup.find('div', id='toc')
        if toc_nav:
            logger.info("Found legacy TOC structure with id='toc' (version 0.7.1-0.8.1)")

    # Fall back to even older legacy format (versions 0.3.0-0.6.0)
    # Very old docs use: <div id="index">
    if not toc_nav:
        logger.debug("Trying older legacy format with id='index'...")
        toc_nav = soup.find('div', id='index')
        if toc_nav:
            logger.info("Found older legacy TOC structure with id='index' (version 0.3.0-0.6.0)")

    # Fall back to oldest legacy format (version 0.2.0)
    # Ancient docs use: <div id="nav">
    if not toc_nav:
        logger.debug("Trying oldest legacy format with id='nav'...")
        toc_nav = soup.find('div', id='nav')
        if toc_nav:
            logger.info("Found oldest legacy TOC structure with id='nav' (version 0.2.0)")

    if not toc_nav:
        logger.warning("Could not find TOC navigation (tried modern and all legacy formats)")
        return toc_sections

    # Find all top-level list items (h2 sections only, not nested h3/h4)
    toc_list = toc_nav.find('ul')
    if not toc_list:
        logger.warning("Could not find TOC list")
        return toc_sections

    section_num = 1
    # recursive=False ensures we only get top-level sections
    for li in toc_list.find_all('li', recursive=False):
        link = li.find('a')
        if not link:
            continue

        # Get the section ID from href (e.g., #Introduction)
        href = link.get('href', '')
        if not href.startswith('#'):
            continue

        section_id = href[1:]  # Remove '#' prefix
        section_title = link.get_text().strip()

        toc_sections.append({
            'number': section_num,
            'id': section_id,
            'title': section_title,
            'filename': f"{section_num:02d}-{slugify(section_title)}.md"
        })
        section_num += 1

    logger.info("Found %d top-level sections", len(toc_sections))
    return toc_sections


def extract_section_content(soup: BeautifulSoup, section_id: str) -> Tag:
    """Extract content for a specific section.

    Supports both modern (0.9.1+) and legacy (0.2.0-0.8.1) HTML structures.

    Args:
        soup: BeautifulSoup parsed HTML document
        section_id: The ID of the section to extract

    Returns:
        A Tag containing the section content, or None if not found
    """
    # Try modern format first (versions 0.9.1+)
    # Modern docs use: <h2 id="SectionName">
    section_header = soup.find('h2', id=section_id)

    # Fall back to legacy format with toc- prefix (versions 0.2.0-0.8.1)
    # Legacy docs use: <h2 id="toc-SectionName">
    if not section_header:
        logger.debug("Modern section ID not found, trying legacy format with toc- prefix...")
        section_header = soup.find('h2', id=f'toc-{section_id}')
        if section_header:
            logger.debug("Found legacy section header for: %s", section_id)

    # Some legacy versions use h1 instead of h2 (e.g., 0.8.1, 0.7.1)
    if not section_header:
        logger.debug("Trying h1 tags for legacy versions...")
        # First try h1 with direct ID attribute
        section_header = soup.find('h1', id=section_id)
        if section_header:
            logger.debug("Found h1 with direct ID for: %s", section_id)
        else:
            # Try with toc- prefix
            section_header = soup.find('h1', id=f'toc-{section_id}')
            if section_header:
                logger.debug("Found h1 with toc- prefix for: %s", section_id)
            else:
                # Last resort: search for h1 containing anchor with matching href
                for h1 in soup.find_all('h1'):
                    link = h1.find('a', href=f'#{section_id}')
                    if not link:
                        link = h1.find('a', href=f'#toc-{section_id}')
                    if link:
                        section_header = h1
                        logger.debug("Found h1 with anchor link for: %s", section_id)
                        break

    if not section_header:
        logger.warning("Could not find section with ID: %s (tried modern, legacy, and h1 formats)", section_id)
        return None

    # Create a container for this section's content
    section_content = soup.new_tag('div')

    # Collect all content elements before extracting to avoid mutation issues
    # We gather all siblings until we hit the next section header
    elements_to_extract = [section_header]

    # Determine what tag to stop at based on current section header type
    # If we found an h1 header, stop at the next h1; if h2, stop at next h2
    stop_tag = section_header.name  # Will be 'h1' or 'h2'

    # Get all siblings until the next section header
    sibling = section_header.find_next_sibling()
    while sibling:
        # Stop if we hit the next section header of the same level
        if sibling.name == stop_tag:
            break
        # Also stop if we hit a higher-level header (e.g., h1 when we're in h2)
        if sibling.name == 'h1':
            break

        elements_to_extract.append(sibling)
        sibling = sibling.find_next_sibling()

    # Now extract and append all elements
    # This prevents the sibling chain from breaking during iteration
    for element in elements_to_extract:
        section_content.append(element.extract())

    return section_content


def clean_markdown(content: str) -> str:
    """Clean up markdown content by fixing common formatting issues.

    Args:
        content: Raw markdown content to clean

    Returns:
        Cleaned markdown content with consistent formatting
    """
    # Unescape HTML entities (e.g., &lt; → <, &amp; → &)
    content = html.unescape(content)

    # Remove excessive blank lines (more than 2 consecutive)
    # Pattern: 4+ newlines → 3 newlines (2 blank lines max)
    content = re.sub(r'\n{4,}', '\n\n\n', content)

    # Fix code blocks with extra blank lines and backtick wrapping
    # Pattern: ``` \n\n `code` \n\n ``` → ```\ncode\n```
    # This catches builtin function signatures that were double-wrapped
    content = re.sub(r'```\s*\n\s*\n\s*`([^`]+)`\s*\n\s*\n\s*```', r'```\n\1\n```', content)

    # Remove double wrapping in code blocks
    # Pattern: ``` `code` ``` → `code`
    # This converts incorrectly formatted code blocks to inline code
    content = re.sub(r'```\s*`([^`]+)`\s*```', r'`\1`', content)

    # Fix code block formatting (ensure blank line before/after)
    # Pattern 1: text\n``` → text\n\n```
    content = re.sub(r'([^\n])\n```', r'\1\n\n```', content)
    # Pattern 2: ```\ntext → ```\n\ntext
    content = re.sub(r'```\n([^\n])', r'```\n\n\1', content)

    # Clean up list formatting (remove excessive blank lines before lists)
    # Pattern: 3+ newlines before list marker → 2 newlines
    content = re.sub(r'\n{3,}(\* |\- |\d+\. )', r'\n\n\1', content)

    # Remove TOC links from headers
    # Pattern: ## [Introduction](#toc-Introduction) → ## Introduction
    # The [text](#toc-*) links are artifacts from the HTML conversion
    content = re.sub(r'^(#{1,6})\s*\[(.*?)\]\(#toc-.*?\)', r'\1 \2', content, flags=re.MULTILINE)

    return content.strip() + '\n'


def build_section_map(toc_sections: List[Dict]) -> Dict[str, str]:
    """Build a map of section IDs to filenames for link fixing."""
    section_map = {}
    for section in toc_sections:
        section_map[section['id']] = section['filename']
    return section_map


def fix_internal_links(content: str, current_file: str, section_map: Dict[str, str]) -> str:
    """Fix internal links to point to the correct markdown files.

    Since we split the documentation into multiple files, internal links
    need to be updated to include the target filename when they reference
    a section in a different file.

    Args:
        content: Markdown content with links to fix
        current_file: The filename of the current section
        section_map: Dictionary mapping section IDs to filenames

    Returns:
        Markdown content with fixed cross-file links
    """

    def replace_link(match):
        """Replace function for regex substitution."""
        link_text = match.group(1)
        anchor = match.group(2)

        # Skip external links (http/https URLs)
        if anchor.startswith('http'):
            return match.group(0)

        # Handle anchor-only links (internal references)
        if anchor.startswith('#'):
            section_id = anchor[1:]  # Remove '#' prefix

            # Check if this anchor points to a different file
            target_file = None

            # Check if it's a TOC link (starts with toc- prefix)
            # The HTML has both #Section and #toc-Section anchors
            if section_id.startswith('toc-'):
                section_id = section_id[4:]  # Remove 'toc-' prefix

            # Find the target file by matching section IDs
            # We check both exact matches and prefix matches (for subsections)
            for sid, filename in section_map.items():
                if sid == section_id or section_id.startswith(sid):
                    target_file = filename
                    break

            # If target is in different file, update the link with filename
            # [text](#anchor) → [text](other-file.md#anchor)
            if target_file and target_file != current_file:
                return f'[{link_text}]({target_file}#{section_id})'
            else:
                # Same file, keep as anchor-only link
                return f'[{link_text}](#{section_id})'

        return match.group(0)

    # Replace markdown links [text](#anchor) or [text](url)
    # Regex captures: group(1) = link text, group(2) = anchor
    content = re.sub(r'\[(.*?)\]\((#[^\)]+)\)', replace_link, content)

    return content


def generate_readme(toc_sections: List[Dict], output_dir: Path, version: str = 'master') -> None:
    """Generate a README.md with full table of contents.

    Args:
        toc_sections: List of section metadata dictionaries
        output_dir: Path to the output directory
        version: Zig version string

    Raises:
        IOError: If README.md cannot be written
    """
    logger.info("Generating README.md...")

    version_display = f"Version {version}" if version != 'master' else "Master Branch"
    source_url = f"https://ziglang.org/documentation/{version}/"

    readme_content = f"""# Zig Programming Language Documentation ({version_display})

This documentation has been automatically converted from the official Zig documentation at {source_url}

## Table of Contents

"""

    for section in toc_sections:
        readme_content += f"{section['number']}. [{section['title']}]({section['filename']})\n"

    readme_content += f"""
## About This Documentation

This is a structured, split version of the Zig documentation optimized for navigation and reference.
Each major section has been extracted into its own markdown file for easier browsing.

**Version:** {version_display}

**Source:** [Official Zig Documentation]({source_url})

**Generated with:** zig_docs_converter.py
"""

    readme_path = output_dir / 'README.md'
    try:
        readme_path.write_text(readme_content, encoding='utf-8')
        logger.info("Created: %s", readme_path)
    except IOError as e:
        logger.error("Failed to write README.md: %s", e)
        raise


def convert_html_to_markdown(html_content: str, output_dir: Path, version: str = 'master') -> None:
    """Main conversion function that orchestrates the HTML to Markdown conversion.

    Args:
        html_content: Raw HTML content to convert
        output_dir: Directory to write markdown files to
        version: Zig version string for documentation

    Raises:
        SystemExit: If no sections are found or conversion fails
    """
    # Parse HTML with BeautifulSoup
    logger.info("Parsing HTML...")
    try:
        soup = BeautifulSoup(html_content, 'lxml')
    except Exception as e:
        logger.error("Failed to parse HTML: %s", e)
        sys.exit(1)

    # Parse table of contents to get section structure
    toc_sections = parse_toc(soup)

    if not toc_sections:
        logger.error("No sections found in TOC - cannot continue")
        sys.exit(1)

    # Build section map for cross-file link resolution
    section_map = build_section_map(toc_sections)

    # Create output directory structure
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
        logger.info("Output directory: %s", output_dir)
    except OSError as e:
        logger.error("Failed to create output directory: %s", e)
        sys.exit(1)

    # Create markdown converter with custom handlers
    converter = create_markdown_converter()

    # Process each section
    logger.info("Converting %d sections...", len(toc_sections))
    for i, section in enumerate(toc_sections):
        logger.info("  [%d/%d] %s...", i + 1, len(toc_sections), section['title'])

        # Extract section content from the HTML
        section_html = extract_section_content(soup, section['id'])

        if not section_html:
            logger.warning("    No content found for section: %s", section['title'])
            continue

        # Convert HTML to markdown
        markdown_content = converter.convert_soup(section_html)

        # Clean up markdown formatting
        markdown_content = clean_markdown(markdown_content)

        # Fix internal cross-file links
        markdown_content = fix_internal_links(markdown_content, section['filename'], section_map)

        # Write markdown to file
        output_file = output_dir / section['filename']
        try:
            output_file.write_text(markdown_content, encoding='utf-8')
            logger.debug("    Created: %s", output_file)
        except OSError as e:
            logger.error("    Failed to write file %s: %s", output_file, e)
            continue

    # Generate README with table of contents
    generate_readme(toc_sections, output_dir, version)

    logger.info("✓ Conversion complete! %d files created in %s", len(toc_sections), output_dir)


# Available Zig versions
# Legacy versions (0.2.0-0.8.1): Use various legacy HTML structures
#   - 0.2.0-0.3.0: <div id="nav"> with unwrapped TOC list
#   - 0.4.0-0.5.0: Non-standard structure (not supported)
#   - 0.6.0: <div id="index">
#   - 0.7.1-0.8.1: <div id="toc">
# Modern versions (0.9.1+): Use <nav aria-labelledby> and id="SectionName" format
# Note: 0.1.1, 0.4.0, 0.5.0 not included due to non-standard HTML structure
AVAILABLE_VERSIONS = [
    # Legacy versions (different HTML structures, now supported)
    '0.2.0', '0.3.0', '0.6.0', '0.7.1', '0.8.1',
    # Modern versions (current HTML structure)
    '0.9.1', '0.10.1', '0.11.0', '0.12.1',
    '0.13.0', '0.14.1', '0.15.2', 'master'
]

ZIG_DOCS_BASE_URL = 'https://ziglang.org/documentation/'


def main():
    """Main entry point for the Zig documentation converter."""
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='Convert Zig HTML documentation to organized markdown files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Examples:
  # Download latest (master) documentation
  python {sys.argv[0]}

  # Download specific version
  python {sys.argv[0]} --version 0.15.2

  # Download all versions (13 versions: 0.2.0-0.3.0, 0.6.0-0.8.1, 0.9.1-master)
  python {sys.argv[0]} --all

  # Convert local file
  python {sys.argv[0]} --file "Documentation - The Zig Programming Language.html"

  # Custom URL
  python {sys.argv[0]} --url https://ziglang.org/documentation/0.14.1/

  # Enable verbose logging
  python {sys.argv[0]} --verbose

Available versions: {', '.join(AVAILABLE_VERSIONS)}

Note: Legacy versions (0.2.0-0.3.0, 0.6.0-0.8.1) use different HTML structures (auto-detected)
Note: Versions 0.1.1, 0.4.0, 0.5.0 are not supported due to non-standard HTML format
        """
    )

    # Source options (mutually exclusive)
    source_group = parser.add_mutually_exclusive_group()
    source_group.add_argument(
        '--url',
        help='Custom URL to fetch Zig documentation from'
    )
    source_group.add_argument(
        '--file',
        help='Local HTML file to convert'
    )
    source_group.add_argument(
        '--version',
        '-v',
        choices=AVAILABLE_VERSIONS,
        help='Zig version to download (default: master)'
    )
    source_group.add_argument(
        '--all',
        action='store_true',
        help='Download all available versions'
    )

    # Output and logging options
    parser.add_argument(
        '--output',
        '-o',
        help='Output directory (default: auto-generated based on version)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging (DEBUG level)'
    )

    args = parser.parse_args()

    # Configure logging based on verbosity
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    # ========================================================================
    # Determine what to process based on command-line arguments
    # ========================================================================
    if args.all:
        # Download all available versions
        versions_to_process = AVAILABLE_VERSIONS
    elif args.version:
        # Download a specific version
        versions_to_process = [args.version]
    elif args.file:
        # Process a local HTML file
        versions_to_process = None
    elif args.url:
        # Fetch from a custom URL
        versions_to_process = None
    else:
        # No arguments provided - default to master branch
        versions_to_process = ['master']

    # ========================================================================
    # Process version(s) from URLs
    # ========================================================================
    if versions_to_process:
        for version in versions_to_process:
            logger.info("=" * 60)
            logger.info("Processing Zig Documentation: %s", version)
            logger.info("=" * 60)

            # Build URL for this version
            url = f"{ZIG_DOCS_BASE_URL}{version}/"

            # Determine output directory
            if args.output:
                output_dir = Path(args.output)
            else:
                output_dir = Path(f"../zig-programming/docs-{version}")

            # Fetch and convert
            try:
                html_content = fetch_html(url)
                convert_html_to_markdown(html_content, output_dir, version)
            except KeyboardInterrupt:
                logger.warning("Interrupted by user")
                sys.exit(130)
            except Exception as e:
                logger.error("✗ Error processing %s: %s", version, e)
                if args.verbose:
                    logger.exception("Full traceback:")
                if not args.all:
                    # Exit on error unless processing all versions
                    sys.exit(1)
                continue

    # ========================================================================
    # Process single file or custom URL
    # ========================================================================
    else:
        if args.url:
            # Extract version from URL if possible
            version = 'custom'
            for v in AVAILABLE_VERSIONS:
                if v in args.url:
                    version = v
                    break

            html_content = fetch_html(args.url)
            output_dir = Path(args.output) if args.output else Path(f"../zig-programming/docs-{version}")
            convert_html_to_markdown(html_content, output_dir, version)

        elif args.file:
            # Process local HTML file
            version = 'local'
            html_content = read_local_file(args.file)
            output_dir = Path(args.output) if args.output else Path('../zig-programming/docs')
            convert_html_to_markdown(html_content, output_dir, version)


if __name__ == '__main__':
    main()
