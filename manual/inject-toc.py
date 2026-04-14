#!/usr/bin/env python3
"""
Inject a table of contents into the generated complete manual.

Reads docs/guides/goplc_complete_manual.md in place, parses every h2
(## Part X) and h3 (### Chapter) heading, emits a nested markdown TOC
with github-style anchor slugs, and writes the TOC back into the file
between the preamble and the first "## Part" divider.

This is idempotent: any previous TOC block (marked by the sentinel
"<!-- toc-start -->" / "<!-- toc-end -->") is removed before the new
one is inserted.

Called automatically by manual/build-md.sh after the chapter walk.
"""
from __future__ import annotations

import pathlib
import re
import sys


TOC_START = "<!-- toc-start -->"
TOC_END = "<!-- toc-end -->"

HEADING_RE = re.compile(r"^(#{2,3}) (.+?)\s*$")
CODE_FENCE_RE = re.compile(r"^```")


def slug(text: str) -> str:
    """GitHub/Astro-compatible anchor slug.

    Lowercase, strip punctuation (keep alphanumeric/spaces/hyphens),
    collapse whitespace to single hyphens, collapse duplicate hyphens.
    Matches the JS slug() function in web/guides/viewer.html so the
    same anchor links resolve across GitHub, Astro, and the in-IDE
    regex renderer.
    """
    s = text.lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = s.strip()
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s)
    return s


def extract_headings(lines: list[str]) -> list[tuple[int, str]]:
    """Return [(level, text), ...] for every h2/h3 outside code fences."""
    headings: list[tuple[int, str]] = []
    in_fence = False
    for line in lines:
        if CODE_FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = HEADING_RE.match(line)
        if not m:
            continue
        level = len(m.group(1))
        text = m.group(2).strip()
        headings.append((level, text))
    return headings


def build_toc(headings: list[tuple[int, str]]) -> list[str]:
    """Build the TOC markdown block (without sentinels)."""
    out: list[str] = ["## Table of Contents", ""]
    for level, text in headings:
        if level == 2:
            out.append(f"- [{text}](#{slug(text)})")
        elif level == 3:
            out.append(f"    - [{text}](#{slug(text)})")
    out.append("")
    return out


def strip_old_toc(lines: list[str]) -> list[str]:
    """Remove any previous <!-- toc-start --> ... <!-- toc-end --> block."""
    out: list[str] = []
    skipping = False
    for line in lines:
        if line.strip() == TOC_START:
            skipping = True
            continue
        if line.strip() == TOC_END:
            skipping = False
            continue
        if not skipping:
            out.append(line)
    return out


def insert_toc(lines: list[str], toc: list[str]) -> list[str]:
    """Insert the TOC block immediately before the first '## Part' heading."""
    block = [TOC_START] + toc + [TOC_END, ""]
    for i, line in enumerate(lines):
        if re.match(r"^## Part ", line):
            return lines[:i] + block + lines[i:]
    # Fallback: append to end if no Part divider was found.
    return lines + [""] + block


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: inject-toc.py <path-to-manual.md>", file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    if not path.is_file():
        print(f"error: {path} not found", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    lines = strip_old_toc(lines)
    headings = extract_headings(lines)
    toc = build_toc(headings)
    lines = insert_toc(lines, toc)

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    n_parts = sum(1 for h in headings if h[0] == 2)
    n_chapters = sum(1 for h in headings if h[0] == 3)
    print(f"TOC injected: {n_parts} parts, {n_chapters} chapters")
    return 0


if __name__ == "__main__":
    sys.exit(main())
