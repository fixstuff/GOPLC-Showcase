#!/usr/bin/env bash
# Build the GoPLC Complete Manual as a single markdown document from
# chapters.txt. Output is written to docs/guides/goplc_complete_manual.md so
# the existing guide-sync infrastructure (sync-guides.sh) propagates it into
# GOPLC/web/guides/ for the embedded IDE viewer and into the public site.
#
# Heading scheme:
#   # GoPLC Complete Manual            (document title)
#   ## Part I: Getting Started         (part divider)
#   ### Original chapter h1            (each guide demoted by 2)
#   #### Original chapter h2
#   ...

set -euo pipefail

MANUAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$MANUAL_DIR/.." && pwd)"
CHAPTERS="$MANUAL_DIR/chapters.txt"
PREPROCESS="$MANUAL_DIR/preprocess.py"
OUTPUT="$REPO_DIR/docs/guides/goplc_complete_manual.md"

if [[ ! -f "$CHAPTERS" ]]; then
  echo "error: chapters.txt not found at $CHAPTERS" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

# Title + brief preamble.
{
  cat <<'EOF'
# GoPLC Complete Manual

The complete GoPLC documentation in a single document — every getting-started
walkthrough, every platform guide, every protocol driver, every ST library, in
one searchable page. This is the same content as the per-topic guides,
concatenated for offline reading and full-text search.

For a navigable index of the same material as separate pages, see the
individual guides in this folder.

EOF
} > "$OUTPUT"

PART_NUM=0
CHAP_NUM=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
    PART_NUM=$((PART_NUM + 1))
    PART_NAME="${BASH_REMATCH[1]}"
    {
      echo
      echo "## ${PART_NAME}"
      echo
    } >> "$OUTPUT"
    continue
  fi
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  src="$REPO_DIR/$line"
  if [[ ! -f "$src" ]]; then
    echo "error: missing chapter source: $src" >&2
    exit 1
  fi
  CHAP_NUM=$((CHAP_NUM + 1))
  python3 "$PREPROCESS" --demote 2 "$src" >> "$OUTPUT"
  echo >> "$OUTPUT"
done < "$CHAPTERS"

LINES=$(wc -l < "$OUTPUT")
BYTES=$(wc -c < "$OUTPUT")
WORDS=$(wc -w < "$OUTPUT")
echo "Wrote $OUTPUT"
echo "  chapters: $CHAP_NUM   parts: $PART_NUM"
echo "  lines: $LINES   words: $WORDS   bytes: $BYTES"
