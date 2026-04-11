#!/usr/bin/env bash
# Build the GoPLC Manual PDF from chapters.txt + metadata.yaml.
#
# Phase 1: flat chapter list, no parts, no cover art. Validates the pandoc +
# xelatex pipeline end-to-end on a small subset before scaling up.

set -euo pipefail

MANUAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$MANUAL_DIR/.." && pwd)"
BUILD_DIR="$MANUAL_DIR/build"
CHAPTERS="$MANUAL_DIR/chapters.txt"
METADATA="$MANUAL_DIR/metadata.yaml"
OUTPUT="$BUILD_DIR/goplc-manual.pdf"

mkdir -p "$BUILD_DIR"

# Scratch dir for part dividers and preprocessed chapter sources.
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PREPROCESS="$MANUAL_DIR/preprocess.py"
FRONT_DIR="$MANUAL_DIR/frontmatter"
BACK_DIR="$MANUAL_DIR/backmatter"
PARTS_DIR="$MANUAL_DIR/parts"
TITLE_PAGE="$MANUAL_DIR/title-page.tex"

# Start with front matter: copyright page and preface. These go after the
# title page (which is injected via --include-before-body below) and before
# the pandoc-generated table of contents.
FILES=()
if [[ -f "$FRONT_DIR/copyright.md" ]]; then
  FILES+=("$FRONT_DIR/copyright.md")
fi
if [[ -f "$FRONT_DIR/preface.md" ]]; then
  FILES+=("$FRONT_DIR/preface.md")
fi

# Walk chapters.txt:
#   - '## Name'        -> synthesize \part{Name} divider, then inject parts/partN.md if present
#   - path/to/file.md  -> preprocess (strip header/footer/emoji) to temp file
PART_NUM=0
CHAP_NUM=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
    PART_NUM=$((PART_NUM + 1))
    PART_NAME="${BASH_REMATCH[1]}"
    PART_TEX="${PART_NAME//&/\\&}"
    PART_TEX="${PART_TEX//%/\\%}"
    PART_TEX="${PART_TEX//_/\\_}"
    PART_TEX="${PART_TEX//\#/\\#}"
    PART_FILE="$TMPDIR/part_${PART_NUM}.md"
    {
      echo '```{=latex}'
      echo "\\part{${PART_TEX}}"
      echo '```'
    } > "$PART_FILE"
    FILES+=("$PART_FILE")
    # Per-part intro paragraph lives in parts/partN.md if it exists.
    PART_INTRO="$PARTS_DIR/part${PART_NUM}.md"
    if [[ -f "$PART_INTRO" ]]; then
      FILES+=("$PART_INTRO")
    fi
    continue
  fi
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  src="$REPO_DIR/$line"
  if [[ ! -f "$src" ]]; then
    echo "error: missing chapter source: $src" >&2
    exit 1
  fi
  CHAP_NUM=$((CHAP_NUM + 1))
  cleaned=$(printf "%s/chap_%03d.md" "$TMPDIR" "$CHAP_NUM")
  python3 "$PREPROCESS" "$src" > "$cleaned"
  FILES+=("$cleaned")
done < "$CHAPTERS"

# Back matter: LaTeX \appendix switches numbering to A, B, C; then append
# every .md file in backmatter/ in alphabetical order.
if compgen -G "$BACK_DIR/*.md" > /dev/null; then
  APPENDIX_MARKER="$TMPDIR/appendix_marker.md"
  {
    echo '```{=latex}'
    echo '\appendix'
    echo '```'
  } > "$APPENDIX_MARKER"
  FILES+=("$APPENDIX_MARKER")
  for back in "$BACK_DIR"/*.md; do
    FILES+=("$back")
  done
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "error: no chapter files listed in $CHAPTERS" >&2
  exit 1
fi

echo "Building ${#FILES[@]}-chapter PDF..."
echo "Output: $OUTPUT"
echo

PANDOC_OPTS=(
  --metadata-file="$METADATA"
  --pdf-engine=xelatex
  --resource-path="$REPO_DIR:$REPO_DIR/docs:$REPO_DIR/docs/guides:$REPO_DIR/docs/guides/images:$REPO_DIR/docs/diagrams"
)
if [[ -f "$TITLE_PAGE" ]]; then
  PANDOC_OPTS+=(--include-before-body="$TITLE_PAGE")
fi

pandoc "${PANDOC_OPTS[@]}" -o "$OUTPUT" "${FILES[@]}"

echo
echo "Done."
ls -lh "$OUTPUT"
