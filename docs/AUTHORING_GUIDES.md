# GoPLC Guide Authoring Standard

**Audience:** contributors writing or editing guides for GoPLC.
**Canonical template:** [`docs/guides/goplc_events_guide.md`](guides/goplc_events_guide.md) — copy this structure.

This doc is the single reference for how guides are written, validated, mirrored, registered, and rendered inside GoPLC's built-in help viewer. Follow it and new guides will land in the IDE with zero layout fights and zero broken ST snippets.

---

## 1. The pipeline at a glance

A guide is a single `.md` file that lives in **three** places. All three must be kept byte-identical. Each destination renders the same source through a different pipeline for a different audience.

```
                     ┌──────────────────────────────┐
                     │  GOPLC-Showcase              │
                     │  docs/guides/*.md            │
                     │  (source of truth — edit     │
                     │   here first, always)        │
                     └──────────┬───────────────────┘
                                │ sync (byte-identical copies)
         ┌──────────────────────┼──────────────────────┐
         ▼                      ▼                      ▼
┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────┐
│ GOPLC            │  │ goplc.app        │  │ GOPLC-Showcase        │
│ web/guides/*.md  │  │ src/content/     │  │ manual/ (PDF build)   │
│                  │  │   guides/*.md    │  │                       │
│ //go:embed       │  │                  │  │ build-md.sh →         │
│ baked into       │  │ Astro content    │  │ pandoc → PDF          │
│ binary           │  │ collection       │  │                       │
│                  │  │                  │  │ goplc_complete_       │
│ Rendered by      │  │ Rendered by      │  │ manual.pdf            │
│ tiny in-viewer   │  │ Astro/remark     │  │                       │
│ regex (SUBSET)   │  │ (full CommonMark)│  │ For whitepapers,      │
│                  │  │                  │  │ physical docs         │
│ Audience:        │  │ Audience:        │  │                       │
│ IDE user reading │  │ public web       │  │ Audience:             │
│ help in the      │  │ reader,          │  │ offline / sales /     │
│ running PLC      │  │ SEO indexed      │  │ print                 │
└────────┬─────────┘  └─────────┬────────┘  └────────────┬──────────┘
         │                      │                        │
         ▼                      ▼                        ▼
   /api/docs/howtos/:name   https://goplc.app/     releases/.../manual.pdf
                            guides/<slug>/
```

Three things to internalize:

1. **Showcase is the source of truth.** Always edit there first. The other two locations are byproducts.
2. **The in-IDE viewer is the lowest common denominator.** Its markdown renderer (`GOPLC/web/guides/viewer.html:renderMarkdown()`) is a hand-rolled regex parser supporting a **strict subset** of Markdown (§5). Astro on `goplc.app` will happily render everything CommonMark supports, but if you use a feature the in-IDE viewer doesn't handle, you'll ship a broken guide to every PLC user. **Write to the subset.**
3. **The GOPLC binary embeds guides at compile time.** The `//go:embed … guides` directive in `GOPLC/web/embed.go` bakes the `.md` files in. Editing a guide without rebuilding `goplc` ships nothing to the running runtime. The `goplc.app` Astro site, by contrast, rebuilds on every `npm run build` and doesn't need a GOPLC binary rebuild.

## 2. Where to put the file

| File | Path | Purpose | Required |
|------|------|---------|----------|
| Source of truth | `GOPLC-Showcase/docs/guides/goplc_<topic>_guide.md` | Edit point | yes |
| IDE mirror | `GOPLC/web/guides/goplc_<topic>_guide.md` | Embedded in binary, in-IDE help | yes (identical bytes) |
| Web mirror | `goplc.app/src/content/guides/goplc_<topic>_guide.md` | Public Astro site, real CommonMark render | yes (identical bytes) |
| Category registration | `GOPLC/pkg/api/handlers/docs.go` in `guideCategories` map | In-IDE index | yes |
| Title map | `goplc.app/src/pages/guides/[slug].astro` `titleMap` | Pretty title on public site | yes |
| Screenshots / diagrams | `docs/guides/images/` in Showcase, mirrored to the other two | Binary assets | if used |
| Manual inclusion | `GOPLC-Showcase/manual/chapters.txt` | PDF manual build (optional) | optional |

Naming: lowercase, underscores, `goplc_<topic>_guide.md`. The base name (without `.md`) is what appears in the URL (`/api/docs/howtos/<name>` in the IDE, `/guides/<name>/` on the public site) and in both registration maps.

## 3. The canonical template

Copy [`goplc_events_guide.md`](guides/goplc_events_guide.md) as your starting point. At the top every guide must have:

```markdown
# <Title>

**<Author Name>**
<Role/Company>
<Month Year> | GoPLC v<X.Y.Z>

---

<Lede paragraph — one to four sentences explaining what the feature is, what problems it
solves, and how it fits into GoPLC. This paragraph becomes the description in the guide
index, so keep it self-contained and over 20 characters. Do not start it with a heading,
list marker, blockquote, code fence, image, or HTML tag — the extractor skips those.>

## 1. <First numbered section>
```

Two things the title/description extractor in `pkg/api/handlers/docs.go:loadHowtoIndex` cares about:

- **Title** is pulled from the *first* `# heading` line.
- **Description** is pulled from the *first* substantial paragraph after the *first* `---` horizontal rule. Before the `---` is considered front-matter (author + date + version). The paragraph must be >20 characters and cannot start with `#`, `|`, `-`, `>`, ` ``` `, `!`, or `<`.

If you skip the `---`, the extractor never advances past the preamble and the description stays empty.

### 3.1 Recommended section order

The events guide uses this outline and it's a good default:

1. **Architecture** — ASCII block diagram inside ` ``` ` that shows subsystems, bus, destinations.
2. **<Feature> Anatomy** — the data model: what a "thing" looks like. Field table.
3. **Reference tables** — event types / command codes / parameter enums, whatever applies.
4. **Configuration** — YAML block showing every knob with comments.
5. **Feature subsections** — one `##` per independently-configurable subsystem.
6. **ST Functions** — one `###` per function with signature + working example.
7. **REST API** — curl examples for every endpoint, response shape in JSON.
8. **Recipes** — short, complete programs showing real use cases.
9. **Performance Notes** — latency, memory, goroutine cost, scaling limits.
10. **Related** — links to sibling guides.

Not every guide needs all of them. A hardware driver guide may not have a REST API section; a pure ST library guide may not need Architecture. Keep the numbering continuous (`## 1.`, `## 2.`, …) so readers can jump.

## 4. Fenced code block languages

The client renderer passes the language as a `language-<lang>` class on the `<code>` element. There is no syntax highlighter bundled, so the language tag is purely for CSS targeting and future highlighter hook-up. Use these consistently:

| Language | Use for |
|----------|---------|
| ` ```iec ` | IEC 61131-3 Structured Text (ST) code |
| ` ```yaml ` | YAML configuration (`config.yaml`, `events:`, etc.) |
| ` ```bash ` | Shell commands (`curl`, `mosquitto_sub`, `systemctl`) |
| ` ```json ` | REST API request/response bodies, event payloads |
| ` ```python ` | Receiver-side reference code (webhook verifiers, etc.) |
| ` ```javascript ` | Browser / Node.js reference code |
| ` ``` ` (no language) | ASCII architecture diagrams, plain trees, SQL dumps |

**Do not** use `` ```st ``, `` ```structuredtext ``, or `` ```pascal `` for ST. The codebase has standardized on `iec`.

## 5. The markdown subset — what the viewer can render

`web/guides/viewer.html:renderMarkdown()` is a hand-rolled regex renderer, not a full CommonMark parser. Here's exactly what it handles and what it silently drops:

### Supported

- `# Heading`, `## Heading`, `### Heading`, `#### Heading` (h1–h4 only)
- `---` horizontal rule on its own line
- `**bold**`, `*italic*`, `` `inline code` ``
- `[link text](url)` inline links
- `![alt](image.png)` — image `src` is rewritten to `/docs/guides/image.png`, so put images beside the `.md`
- Fenced code blocks with or without a language tag (handled before other regex → content is safe)
- Unordered lists: lines starting with `- ` (one level only)
- Ordered lists: lines starting with `1. `, `2. ` etc. (one level only)
- Blockquotes: consecutive lines starting with `> `, merged into one `<blockquote>`
- Tables: standard pipe tables **with the `|---|---|` separator row** — the renderer's regex requires that row to recognize a table
- Paragraphs: blank-line separated, single newlines inside become `<br>`

### Not supported — avoid these

- `#####` or `######` headers (h5, h6) — will render as literal text
- Nested lists (indented `  -`) — indentation is ignored, everything flattens
- Task lists (`- [ ]`, `- [x]`) — the `[ ]` will appear in the output as text
- Reference-style links (`[text][ref]` + `[ref]: url`) — not resolved
- Footnotes (`[^1]`)
- Strikethrough (`~~text~~`)
- Bare autolinks (`https://example.com`) — wrap in `[url](url)`
- Raw HTML — technically passes through if a block starts with `<`, but brittle; avoid
- Tables without a `---` separator row
- Definition lists
- Setext headings (`===` or `---` under a line of text — the `---` will become an `<hr>`)

### Rendering gotchas

- **Blank lines matter.** Paragraphs are split on `\n\n`. If you want two paragraphs, leave a blank line between them.
- **Tables need a blank line before and after** or they'll get glued to the surrounding paragraph.
- **Code fences must start at column 0**, not indented.
- **Don't mix `-` lists and `1.` lists in the same block** without a blank line between them — the regex treats consecutive lines as one list.
- **ASCII diagrams** go inside an unlabeled ` ``` ` block. They preserve indentation. Use box-drawing characters (`┌`, `│`, `└`, `─`, `▼`, `┘`, `├`) for visual weight; they render fine in the browser's monospace font.

## 6. Verification — never fabricate ST functions or capabilities

This is non-negotiable. A guide that references a function that doesn't exist wastes the reader's time worse than no guide at all. Before writing *any* ST code snippet:

### 6.1 Verify every builtin you plan to use

Query the **running target's** live registry:

```bash
# Direct HTTP
curl 'http://<host>:<port>/api/docs/functions?search=EVENT_EMIT'

# Or via MCP (preferred when available)
mcp__goplc__goplc_functions(search="EVENT_EMIT")
mcp__goplc__goplc_function_blocks                   # for TON/TOF/CTU/PID/etc.
mcp__goplc__goplc_capabilities                      # for language features
```

If a function isn't in the live registry, **it does not exist**. Do not:

- Invent function names based on patterns (`MB_CLIENT_READ_FLOAT` doesn't exist just because `MB_CLIENT_READ_COILS` does).
- Assume OSCAT functions are available without checking.
- Trust function signatures from your training data — this runtime has its own library with its own signatures.

### 6.2 Verify signatures

Even when a function exists, parameter count/order/types and the return type are frequently not what you'd guess. Pull the signature from the live registry and match it exactly. Watch specifically for:

- Optional parameters that exist on some functions but not others.
- Return type variations (some return `DINT`, some `REAL`, some `STRING`, some arrays).
- Byte order / base conventions (1-based vs 0-based, big vs little endian).

### 6.3 Validate whole snippets end-to-end

Before committing a guide, pass every ST snippet through the validator:

```
mcp__goplc__goplc_program_validate(source="...")
```

If the snippet is part of a larger structure (requires a VAR block, a PROGRAM wrapper, etc.), wrap it so it's self-contained before validating. The validator returns syntactic + semantic errors; don't ship a guide until everything validates clean.

### 6.4 YAML config keys

Verify every `foo:` key you put in a YAML example actually exists on the runtime. Grep the handler that reads the config block, or check `configs/` for a reference config that uses it. Don't invent config keys.

## 7. Workflow checklist

Follow this every time you add or edit a guide. Commits land in **three** repos, in this order.

### Phase A — write in Showcase
1. **Branch** off master in the Showcase repo: `git checkout -b docs/<topic>-guide`.
2. **Pick the template** — copy `docs/guides/goplc_events_guide.md` to `docs/guides/goplc_<topic>_guide.md`.
3. **Strip the content** down to section headings and write your own.
4. **Verify every ST function and config key** against a running target (§6).
5. **Validate every ST snippet** through `goplc_program_validate` (§6.3).
6. **Stay inside the markdown subset** — §5. Even though Astro will render CommonMark, the in-IDE viewer is lowest common denominator.
7. **Local render-check via Astro** — by far the fastest way to eyeball the rendered HTML (§8.1).

### Phase B — mirror to GOPLC (for in-IDE help)
8. **Copy** `docs/guides/goplc_<topic>_guide.md` → `GOPLC/web/guides/goplc_<topic>_guide.md` (byte-identical).
9. **Register** the category in `GOPLC/pkg/api/handlers/docs.go` `guideCategories` map. Pick from: `Getting Started`, `How-To Projects`, `Platform`, `Protocols`, `Hardware`, `Programming`, `Specialty`.
10. **Bump VERSION** in `GOPLC/cmd/goplc/VERSION` (mandatory on every build).
11. **Build** `goplc-dev` (never overwrite the running `goplc` binary): `go build -o goplc-dev ./cmd/goplc`.
12. **Smoke-test** in-IDE render: run the dev binary on a spare port, open `http://localhost:<port>/guides/viewer.html?name=goplc_<topic>_guide`, confirm title, description, every code block, every table, every image. If anything renders wrong here, it's almost always a §5 subset violation.

### Phase C — mirror to goplc.app (for public web site)
13. **Copy** `docs/guides/goplc_<topic>_guide.md` → `goplc.app/src/content/guides/goplc_<topic>_guide.md`.
14. **Add a title** to the `titleMap` in `goplc.app/src/pages/guides/[slug].astro` — the key is the filename without `.md`, the value is the pretty title shown in the index.
15. **Build** the public site: `cd goplc.app && npm run build`. The rendered HTML lands in `dist/guides/<slug>/index.html`. Open it directly or run `npm run preview` and check the guide at `http://localhost:4321/guides/<slug>/`.
16. **Confirm** the guide appears on the `/guides` index page with the correct title and a description pulled from the lede paragraph.

### Phase D — commit and push
17. **Commit Showcase first** — it's the canonical source, reviewers look here.
18. **Commit GOPLC** with a message that references the Showcase commit hash.
19. **Commit goplc.app** similarly.
20. **Push all three.** The Cloudflare Pages deploy of goplc.app will auto-rebuild on the push; the GOPLC binary change ships with the next release build.

## 8. Render-check without rebuilding

You have two renderers to check: Astro (full CommonMark) for the public site, and the in-IDE regex renderer for the embedded help viewer. Astro is the faster iteration loop; the in-IDE viewer is the one more likely to expose subset violations.

### 8.1 Astro (fastest, best fidelity)

Astro's dev server hot-reloads on save. This is the fastest way to see a nicely-styled rendered version of the guide.

```bash
cd ~/projects/Websites/goplc.app
npm run dev
# then open http://localhost:4321/guides/goplc_<topic>_guide/
```

Edit the file at `goplc.app/src/content/guides/goplc_<topic>_guide.md` while the dev server runs and the browser hot-reloads. When the content is final, back-port it into `GOPLC-Showcase/docs/guides/` (the source of truth) before committing — do not forget this step or the next contributor will see a stale Showcase.

Alternatively, point the Astro dev server at the Showcase directory with a symlink and edit Showcase directly:

```bash
cd ~/projects/Websites/goplc.app/src/content/guides
ln -sf ~/projects/GOPLC-Showcase/docs/guides/goplc_<topic>_guide.md .
npm run dev
# Edit in ~/projects/GOPLC-Showcase/docs/guides/ — Astro picks it up live
```

Just remember to replace the symlink with a real copy before committing goplc.app.

### 8.2 In-IDE viewer (lowest common denominator)

Astro will happily render features the in-IDE viewer silently drops. A guide that looks perfect on `goplc.app` can be broken inside the running PLC. Always do a second render-check against the in-IDE viewer before committing.

Options, in order of speed:

- **Fastest** — edit `GOPLC/web/guides/goplc_<topic>_guide.md` (the mirror copy) directly, then reload the viewer in any already-running goplc instance at `http://<host>:<port>/guides/viewer.html?name=goplc_<topic>_guide`. Back-port the edit into Showcase before committing.
- **Static serve** — run `python3 -m http.server 9000` in `GOPLC/web/guides/` and browse `http://localhost:9000/viewer.html?name=goplc_<topic>_guide&src=./`. Filesystem-only, no API needed.
- **Full rebuild** — bump VERSION, build `goplc-dev`, run on spare port. Use this for the final smoke test before committing.

If a code fence or table isn't rendering right here but looks fine in Astro, it's almost always a §5 subset violation — missing blank line, nested list, table without the `---` separator row, or a feature (task list, nested emphasis, footnote) that the regex renderer doesn't recognize.

## 9. Mirroring Showcase → GOPLC + goplc.app

All three copies must be **byte-identical**. There is no transformation on the way in. Any divergence means one audience sees a stale copy. Known historical drift: as of this writing, 8 guides in Showcase were not yet present in `goplc.app/src/content/guides/` (events, HAL, MCP gateway, complete manual, and the home-automation/washing-machine how-tos). The sync script below is how we close those gaps.

### 9.1 Manual single-file copy

Use this when you're editing one guide and already on a branch:

```bash
# Edit in Showcase first, then fan out
cp ~/projects/GOPLC-Showcase/docs/guides/goplc_<topic>_guide.md \
   ~/projects/GOPLC/web/guides/goplc_<topic>_guide.md

cp ~/projects/GOPLC-Showcase/docs/guides/goplc_<topic>_guide.md \
   ~/projects/Websites/goplc.app/src/content/guides/goplc_<topic>_guide.md
```

Commit Showcase first, then GOPLC, then goplc.app — each commit referencing the Showcase commit hash so reviewers can confirm the copy is faithful.

### 9.2 Bulk three-way sync

When changing many guides at once, or when closing gaps between the three locations:

```bash
# From the Showcase repo root
SRC=~/projects/GOPLC-Showcase/docs/guides

# Fan out to the embedded IDE mirror (preserve images/)
rsync -av --delete \
  "$SRC/" \
  ~/projects/GOPLC/web/guides/

# Fan out to the public Astro site
rsync -av --delete \
  "$SRC/" \
  ~/projects/Websites/goplc.app/src/content/guides/ \
  --exclude 'README.md' \
  --exclude 'getting-started.md' \
  --exclude 'home-automation.md' \
  --exclude 'washing-machine-controller.md' \
  --exclude 'goplc_complete_manual.md'
```

The `goplc.app` excludes drop Showcase-only files that don't belong on the public site (internal README, landing pages, the full combined manual which is a separate deliverable).

`--delete` prunes guides that were removed from Showcase; drop it if you only want to add. Every bulk sync should be followed by `npm run build` in `goplc.app` to verify the Astro site still builds clean.

### 9.3 Drift detection

Before committing, diff the three copies to make sure you haven't forgotten a fan-out:

```bash
diff -rq ~/projects/GOPLC-Showcase/docs/guides/ ~/projects/GOPLC/web/guides/ | grep -v images
diff -rq ~/projects/GOPLC-Showcase/docs/guides/ ~/projects/Websites/goplc.app/src/content/guides/ | grep -v images
```

Any "differ" or "only in" line for a `goplc_*_guide.md` file is a drift you need to resolve. Showcase wins.

**Never** edit the GOPLC or goplc.app copies without back-porting to Showcase. Showcase is the canonical source; the other two exist because their respective build pipelines can't reach outside their own repos.

## 10. Registration — both sides

### 10.1 GOPLC in-IDE category

A guide that isn't in `guideCategories` shows up under `"Other"` in the IDE. Add your entry in the right section of the map:

```go
// GOPLC/pkg/api/handlers/docs.go
var guideCategories = map[string]string{
    // ...
    "goplc_<topic>_guide": "Platform",   // or Protocols, Hardware, Programming, Specialty
}
```

The key is the **filename without the `.md` suffix**. The value must match one of the entries in `categoryOrder` (otherwise it won't appear in the indexed sections).

### 10.2 goplc.app public title

Astro automatically discovers the new `.md` file in the content collection — no schema registration needed. What you **do** need to add is a pretty title in the title map used by the public guide pages:

```ts
// goplc.app/src/pages/guides/[slug].astro
const titleMap: Record<string, string> = {
  // ...
  'goplc_<topic>_guide': 'My Topic Guide',
};
```

If you skip this, the page still renders but the title shown in the index and the browser tab falls back to the slug. Keep the titles terse — they appear on cards in a grid.

## 11. Things that feel helpful but aren't

- **Auto-generated TOCs.** The viewer doesn't have a TOC renderer. If you want a TOC, either add explicit links or don't bother — readers use browser find.
- **Anchor links across sections.** The renderer doesn't add `id` attributes to headings. Inter-section links (`[see §4](#4)`) don't work. If you need to reference another section, say "see §4".
- **Frontmatter YAML (`---\ntitle:\n---`).** The viewer treats the first `---` as a horizontal rule. A YAML frontmatter block will render as a blockquote with random text and kill the description extractor. The author/version lines go *above* the `---` as plain text, not as YAML.
- **Bash here-docs with backticks.** Backticks inside a bash fence will collide with the closing fence if there's a literal backtick in the script. Use `$(cmd)` instead of `` `cmd` `` inside fenced examples.
- **Very long lines.** The renderer does not wrap `<pre>` content. Lines over ~100 chars will overflow and trigger a horizontal scrollbar on narrow IDE panels. Wrap manually.

## 12. Voice and tone

Guides are written in **declarative, direct prose**, not marketing copy. Read `goplc_events_guide.md` for the house style:

- Explain the *what* and the *why* before the *how*. The lede paragraph should be able to answer "what is this thing and when would I reach for it" for a reader who's never heard of it.
- Describe limitations honestly. If a feature has a performance ceiling, say so. If two features can interact badly, say so. Readers trust guides that admit trade-offs.
- Use second person ("you") when describing what the reader does; third person ("the runtime", "the bus") when describing what the system does.
- Short sentences beat long ones. Cut every word that doesn't carry weight.
- No emojis. No exclamation marks (except inside code, where they're operators).
- Never describe GoPLC as "free", "open source", "zero cost", "community edition", etc. It's commercial, source-available, per-instance licensed. If a guide references OSCAT specifically, it's fine to mention OSCAT is LGPL — that's true and applies only to OSCAT.

## 13. Troubleshooting

| Symptom | Fix |
|--------|------|
| Guide doesn't appear in the index | Not registered in `guideCategories`, or filename doesn't match key, or not rebuilt after adding. |
| Guide appears under "Other" | Missing from `guideCategories` map — add it. |
| Description is empty in the index | No `---` after the byline, or the first paragraph after `---` is too short, or starts with `|`/`-`/`#`/`>`. |
| Title shows the filename | No `# Title` line at the top of the file. |
| Table renders as literal text | Missing the `|---|---|` separator row, or missing a blank line above/below. |
| Lists not rendering | Nested indentation (flatten them), or mixed `-` and `1.` without a blank line break. |
| Code block rendering wrong | Fence line isn't at column 0, or language tag has a typo (`iec` not `st`). |
| Edit not showing up | You edited the Showcase copy but didn't mirror + rebuild the GOPLC binary. Or you're looking at a stale browser cache — hard-reload (Ctrl-Shift-R). |
| Image broken | Image file not copied into `GOPLC/web/guides/` alongside the `.md`, or not referenced with `![alt](file.png)` (no path prefix). |

## 14. Related

- [`docs/guides/goplc_events_guide.md`](guides/goplc_events_guide.md) — canonical template.
- `GOPLC/pkg/api/handlers/docs.go` — the description extractor, category map, and index logic for the in-IDE help.
- `GOPLC/web/guides/viewer.html` — the minimal regex markdown renderer. Read this if you're unsure whether a feature is supported in-IDE.
- `GOPLC/web/embed.go` — the `//go:embed` directive that bakes guides into the binary.
- `goplc.app/src/pages/guides/[slug].astro` — Astro page that renders each guide via `astro:content`, plus the `titleMap` for pretty titles.
- `goplc.app/src/pages/guides/index.astro` — the public guide index page.
- `goplc.app/astro.config.mjs` — Astro config (Tailwind, sitemap — no custom remark plugins, so it's stock CommonMark).
