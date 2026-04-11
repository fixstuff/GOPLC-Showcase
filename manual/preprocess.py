#!/usr/bin/env python3
"""Preprocess a GoPLC showcase markdown file for inclusion in the bound manual.

Each guide and whitepaper in GOPLC-Showcase/docs/ is written as a standalone
document with an author block, a horizontal-rule separator, the body, a second
separator, and a version/copyright footer. When stitched into one book those
per-file credit blocks become visual noise and repeat sixty-plus times.

This script rewrites one file to stdout with:
  - the title (first level-1 heading) preserved
  - everything between the title and the first `---` stripped
  - everything from the *last* `---` onward stripped (footer block)
  - a small set of emoji that are missing from DejaVu Sans Mono replaced with
    bracketed stand-ins so xelatex stops whining
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Replacement table for emoji that aren't in DejaVu and would otherwise
# produce "Missing character" warnings or hollow glyphs in the PDF.
EMOJI_REPLACEMENTS = {
    "\U0001F321": "[temp]",   # 🌡
    "\U0001F4A7": "[drop]",   # 💧
    "\U0001F4A1": "[idea]",   # 💡
    "\U0001F4CA": "[chart]",  # 📊
    "\U0001F527": "[tool]",   # 🔧
    "\U0001F6A8": "[alert]",  # 🚨
}


def strip_header(lines: list[str]) -> list[str]:
    """Keep the title line, drop everything up to (and including) the first
    standalone `---` separator. If there is no separator in the first ~20
    lines, assume there is no header block and return lines unchanged."""
    if not lines:
        return lines
    # Find first level-1 heading (the chapter title)
    title_idx = None
    for i, line in enumerate(lines[:5]):
        if line.startswith("# "):
            title_idx = i
            break
    if title_idx is None:
        return lines
    # Scan for the first `---` separator within the next 20 lines
    sep_idx = None
    for i in range(title_idx + 1, min(title_idx + 20, len(lines))):
        if lines[i].strip() == "---":
            sep_idx = i
            break
    if sep_idx is None:
        return lines
    # Keep title + everything after the separator
    return [lines[title_idx], "\n"] + lines[sep_idx + 1 :]


def strip_footer(lines: list[str]) -> list[str]:
    """Drop the last `---` separator and everything after it if what follows
    looks like a version/copyright footer (italic lines). Conservative: only
    strip when the tail really looks like a footer, never touch body content."""
    if not lines:
        return lines
    # Search for the last `---` in the final 15 lines
    last_sep = None
    for i in range(len(lines) - 1, max(-1, len(lines) - 15), -1):
        if lines[i].strip() == "---":
            last_sep = i
            break
    if last_sep is None:
        return lines
    tail = [ln.strip() for ln in lines[last_sep + 1 :] if ln.strip()]
    if not tail:
        return lines
    # Footer heuristic: at least one tail line starts with '*' (italics) AND
    # contains one of: 'GoPLC v', '©', 'Back to'
    looks_like_footer = any(
        ln.startswith("*") and ("GoPLC v" in ln or "©" in ln or "Back to" in ln)
        for ln in tail
    )
    if not looks_like_footer:
        return lines
    return lines[:last_sep]


def replace_emoji(text: str) -> str:
    for emoji, repl in EMOJI_REPLACEMENTS.items():
        text = text.replace(emoji, repl)
    return text


# Many showcase guides already number their own headings like
# "## 10. Rate Limit" or "### 25.12.3 Subsection". Pandoc also auto-numbers
# sections when the book is assembled, which produces duplicated prefixes
# in the TOC ("25.10. 10. Rate Limit"). Strip the manual numbering so only
# pandoc's hierarchical numbering shows through.
_HEADING_NUMBER_RE = re.compile(
    r"^(?P<hashes>#{2,6}\s+)"
    r"(?P<num>\d+(?:\.\d+)*\.?)"
    r"\s+"
    r"(?P<rest>\S.*)$"
)


def strip_heading_numbers(lines: list[str]) -> list[str]:
    out = []
    for line in lines:
        m = _HEADING_NUMBER_RE.match(line.rstrip("\n"))
        if m:
            trailing = "\n" if line.endswith("\n") else ""
            out.append(f"{m.group('hashes')}{m.group('rest')}{trailing}")
        else:
            out.append(line)
    return out


def process(path: Path) -> str:
    raw = path.read_text(encoding="utf-8")
    # Normalize line endings so splitlines + rejoin is lossless
    lines = raw.splitlines(keepends=True)
    lines = strip_header(lines)
    lines = strip_footer(lines)
    lines = strip_heading_numbers(lines)
    out = "".join(lines)
    out = replace_emoji(out)
    # Ensure a trailing newline so chapters don't concatenate on the same line
    if not out.endswith("\n"):
        out += "\n"
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: preprocess.py <path-to-md>", file=sys.stderr)
        return 2
    sys.stdout.write(process(Path(sys.argv[1])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
