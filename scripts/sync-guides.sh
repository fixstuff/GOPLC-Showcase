#!/usr/bin/env bash
# Sync guides between GOPLC-Showcase (canonical) and GOPLC (web/guides/ embedded).
#
# GOPLC-Showcase is the source of truth — it's what feeds the public websites.
# GOPLC/web/guides/ embeds these same .md files into the binary via go:embed,
# so we keep them in sync without losing newer edits on either side.
#
# Strategy: bidirectional rsync with --update (newer mtime wins).
#   1. GOPLC -> Showcase first — picks up any brand-new guides added on the
#      GOPLC side (new protocol guides tend to land there first).
#   2. Showcase -> GOPLC last — re-asserts showcase as canonical for ties and
#      propagates any edits made directly in the public repo.
# Assets (images/, *.svg) sync both ways the same way.
#
# Never touches index.html / viewer.html (GOPLC IDE shell, not content).

set -euo pipefail

SHOWCASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOPLC_DIR="$(cd "$SHOWCASE_DIR/../GOPLC" && pwd)"

SHOWCASE="$SHOWCASE_DIR/docs/guides/"
GOPLC="$GOPLC_DIR/web/guides/"

if [[ ! -d "$SHOWCASE" ]]; then
  echo "error: showcase guides dir not found: $SHOWCASE" >&2
  exit 1
fi
if [[ ! -d "$GOPLC" ]]; then
  echo "error: goplc guides dir not found: $GOPLC" >&2
  exit 1
fi

echo "Showcase (canonical): $SHOWCASE"
echo "GOPLC (embedded):     $GOPLC"
echo

# rsync flags:
#   -a  archive (preserve times — critical for --update to work)
#   -u  update: skip files newer on the receiving side
#   -i  itemize: print what changed
#   -c  checksum compare (catches same-mtime content drift)
RSYNC_OPTS=(-aui)

# Pass 1: pick up new files from GOPLC (new guides often land there first).
echo "== pass 1: GOPLC -> Showcase (new guides, newer edits) =="
rsync "${RSYNC_OPTS[@]}" --include='*.md' --exclude='*/' --exclude='*' "$GOPLC" "$SHOWCASE"
if [[ -d "$GOPLC/images" ]]; then
  rsync "${RSYNC_OPTS[@]}" "$GOPLC/images/" "$SHOWCASE/images/"
fi
rsync "${RSYNC_OPTS[@]}" --include='*.svg' --exclude='*/' --exclude='*' "$GOPLC" "$SHOWCASE"

# Pass 2: showcase is canonical — re-assert it for everything newer on its side.
echo
echo "== pass 2: Showcase -> GOPLC (canonical back-fill) =="
rsync "${RSYNC_OPTS[@]}" --include='*.md' --exclude='*/' --exclude='*' "$SHOWCASE" "$GOPLC"
if [[ -d "$SHOWCASE/images" ]]; then
  rsync "${RSYNC_OPTS[@]}" "$SHOWCASE/images/" "$GOPLC/images/"
fi
rsync "${RSYNC_OPTS[@]}" --include='*.svg' --exclude='*/' --exclude='*' "$SHOWCASE" "$GOPLC"

# Summary
echo
echo "== showcase git status =="
git -C "$SHOWCASE_DIR" status --short docs/guides/ || true

echo
echo "== goplc git status =="
git -C "$GOPLC_DIR" status --short web/guides/ || true

echo
echo "Done. Review diffs and commit each repo separately."
