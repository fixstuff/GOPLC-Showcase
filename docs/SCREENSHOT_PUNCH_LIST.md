# Showcase Screenshot Punch List

Generated 2026-05-14 against `v1.0.887+` runtime state.

All existing screenshots in `assets/screenshots/` are dated **Jan 27–28, 2026** — ~4 months old, predating ~45 versions of UI work. This list tracks what to refresh and what to add for the new feature sections.

Files use the same naming pattern as existing assets (`assets/screenshots/<slug>.png`). Recommended frame: **1600–2000 px wide**, browser zoomed so text is readable on GitHub at the 700–800 px display width the README uses.

---

## Prep checklist (do once before capturing)

- [ ] Start a fresh `goplc` instance — preferably v1.0.887 or newer, with `--data-dir` pointing at a clean directory
- [ ] Open `projects/demo.goplc` (or any project with multiple tasks + a mix of BOOL/INT/REAL/STRING tags) so screenshots aren't dominated by empty state
- [ ] Make sure the runtime is **running** (not just loaded) so live values populate
- [ ] Browser: Chrome or Edge at 100% zoom, window 1920×1080 minimum, no extensions/sidebars visible
- [ ] Theme: whichever the README screenshots already use — check `web-ide.png` to match
- [ ] Hide any developer tools panel, console, etc.

For the live-data screenshots (trend, alarms, vision), have the runtime running a project that actually exercises those features — `projects/pide_autotune_demo.goplc` is a good starting point.

---

## Group 1 — Refresh existing screenshots (9)

Same filenames, fresh captures. Existing references in `README.md` stay valid — just overwrite the files.

### 1.1 `web-ide.png`
- **Section:** "What is GOPLC?" hero image (top of README)
- **Navigate to:** `/ide/`
- **Show:** Monaco editor with an ST file open, project tree on the left, the new wizard search bar visible, live variable panel showing values
- **Frame width:** 1800 px
- **Must include:** GOPLC logo/header bar, version string somewhere (proves freshness)

### 1.2 `ide-features.png`
- **Section:** "Web IDE" section
- **Navigate to:** `/ide/`
- **Show:** Same as above but with the **autocomplete dropdown open** showing modern function suggestions (e.g. type `ZMQ_` or `NATS_` to prove the new builtins appear)
- **Frame:** 1800 px, focused on the editor area

### 1.3 `monitor-variables.png`
- **Section:** "Web IDE → IDE Screenshots" grid
- **Navigate to:** `/ide/` → Monitor tab
- **Show:** Task/variable view with the new Watch List panel populated with at least 6 mixed-type variables (BOOL, INT, REAL, STRING, FB instance)
- **Frame:** 1400 px

### 1.4 `watch-list.png`
- **Section:** "Web IDE → IDE Screenshots" grid
- **Navigate to:** Watch list right-side panel
- **Show:** Real-time variable monitoring with the click-to-edit behavior demonstrated (one value being edited inline)
- **Frame:** 1000 px (narrower than monitor-variables)

### 1.5 `config-editor.png`
- **Section:** "Web IDE → IDE Screenshots" grid
- **Navigate to:** `/ide/` → Config Editor view
- **Show:** YAML config with the newer sections visible — `nats:`, `mqtt_broker:`, `eventspine:`, `videohist:`, `vision:` blocks
- **Frame:** 1400 px

### 1.6 `xref-search.png`
- **Section:** "Web IDE → IDE Screenshots" grid
- **Navigate to:** `/ide/` → Cross-reference search
- **Show:** Search results spanning multiple programs for a variable name; results panel and the highlighted code on the right
- **Frame:** 1400 px

### 1.7 `datalayer-sync.png`
- **Section:** "Web IDE → IDE Screenshots" grid
- **Navigate to:** Multi-PLC sync view in the cluster IDE
- **Show:** Variables flowing between boss and minions; current cluster UI (not the Jan version which has since been rewritten)
- **Frame:** 1400 px

### 1.8 `esp32-hmi.png`
- **Section:** "Web IDE → IDE Screenshots" grid
- **Show:** ESP32 HMI display device status if you still have the hardware connected. Optional to refresh — hardware screens age slowly. Skip if no hardware available.

### 1.9 `ide-fullsize.png`
- **Referenced from:** Not in current README (file exists but unused); leave or delete

---

## Group 2 — New captures for new sections (the priority set)

These features have no screenshot at all and the README sections will read flat without them. **Highest impact first.**

### 2.1 `trend-with-events.png` ⭐ HIGH PRIORITY
- **Section:** **Trend Component** (new section, biggest gap)
- **Navigate to:** `/hmi/trend-fullscreen.html?tags=pou.eye_x,pou.blinking,pou.motor_rpm&events-kinds=alarm.*,operator.action&events-severity-min=info`
- **Show:** Live trend with:
  - At least 3 pens, one of them a BOOL rendered as pulse ticks
  - **The colored event-marker band visible across the top with at least 5 markers** (this is the new feature — prove it exists)
  - Hover cursor visible with per-pen value readout
  - Legend on the right with the colored pen entries
- **Prep:** Run a project that fires occasional alarms; let it run for 5 min before capture so there's history
- **Frame:** 1800 px wide, full canvas height
- **Place inline at:** start of "Trend Component" section under the H2

### 2.2 `trend-picker.png` ⭐ HIGH PRIORITY
- **Section:** **Trend Component → Variable picker**
- **Navigate to:** Trend page, click the `+` button to open the picker
- **Show:** Picker dropdown open with the search filter active (type "motor" or similar), several checkboxes visible, "Select all matching" button visible
- **Frame:** 1200 px wide, focused on the trend header + picker overlay

### 2.3 `pide-autotune.png` ⭐ HIGH PRIORITY
- **Section:** **Industrial Control — Enhanced PID + Autotune**
- **Navigate to:** Run `projects/pide_autotune_demo.goplc`. Open the trend showing `PV`, `SP`, `CV`. Trigger the autotune (`AT := TRUE`).
- **Show:** Trend with the **relay-feedback square wave visible on the CV trace** while PV oscillates — proves the autotune algorithm is real. Add a sidebar or overlay showing the recovered `KP_TUNE / KI_TUNE / KD_TUNE` values if possible.
- **Frame:** 1800 px wide
- **Prep:** This is the trickiest capture — needs the autotune actually running and converging. Use the `TestRelayAutotune_FOPDT` plant simulator settings as a known-good baseline.

### 2.4 `event-spine.png` ⭐ HIGH PRIORITY
- **Section:** **Events, Event Spine & Webhooks**
- **Navigate to:** Events viewer in the IDE (or build a quick HMI page rendering `/api/spine/events`)
- **Show:** Stream of events with **correlation IDs visible**, severity colors, multiple event kinds (`alarm.*`, `operator.action`, `task.reload`, `auth.login`), timestamps
- **Frame:** 1400 px wide
- **Prep:** Trigger a few events first (start/stop runtime, ack an alarm, run a task reload, log in) so the list has substance

### 2.5 `alarms-panel.png` ⭐ HIGH PRIORITY
- **Section:** **Alarms**
- **Navigate to:** Alarms view in the IDE
- **Show:** Active alarm list with severities color-coded, at least one in each state (ACTIVE / ACKNOWLEDGED / RECENT-NORMAL), area/priority columns visible, ack button visible
- **Frame:** 1400 px wide
- **Prep:** Configure a few threshold rules and let some go active. Ack one of them so all states are represented.

### 2.6 `foundation-cli.png` ⭐ HIGH PRIORITY (developer/AI audience)
- **Section:** **Foundation Registry**
- **Navigate to:** Terminal
- **Run:** `goplc foundation impact events` and let the output scroll
- **Show:** Terminal screenshot of the command + output listing the 16+ packages that depend on `events`, plus another command like `goplc foundation concerns RBAC` showing the auth lookup
- **Frame:** 1200 px wide, monospace
- **Prep:** Set terminal to a dark theme with good font (Cascadia/Fira/JetBrains Mono)

### 2.7 `wizard-feature-search.png`
- **Section:** **Config Wizard** (existing section, no screenshot)
- **Navigate to:** Wizard in the IDE, search box
- **Show:** Search results for a query like `modbus` showing **mixed result types** — topics, functions, and howtos all in one list with the kind labels visible. Proves the unified aggregator at `/api/features/search`.
- **Frame:** 1200 px wide

### 2.8 `video-burst.png`
- **Section:** **Video Historian & Vision Pipeline**
- **Navigate to:** Video burst index page
- **Show:** List of captured bursts with timestamps, reasons, camera names, and at least one **thumbnail** frame visible. Bonus: an event entry with the "view burst" hyperlink visible.
- **Frame:** 1400 px wide

### 2.9 `vision-detection.png` (optional)
- **Section:** **Video Historian & Vision Pipeline**
- **Show:** Vision detection result — a frame with a bounding box drawn from an ONNX inference, or a gauge-reader detection with the recovered value overlaid. Only if you have a vision project running with real frames.
- **Frame:** 1200 px wide

### 2.10 `l5x-import.png`
- **Section:** **L5X / Rockwell Import**
- **Navigate to:** L5X import API endpoint, or trigger via the wizard
- **Show:** Import result panel showing per-program warning counts, with at least one `(* UNSUPPORTED RLL: ... *)` warning visible in the converted ST output below — proves the visible-warning feature is real, not a marketing claim
- **Frame:** 1400 px wide
- **Prep:** Use `IAD550_BOP_Complete.L5X` (the verified-clean test export) so the result looks healthy

### 2.11 `embedded-brokers.png` (optional)
- **Section:** **Embedded Messaging Brokers**
- **Show:** Three terminals or a dashboard showing the embedded MQTT broker on :1883, NATS on :4222 (with JetStream stream visible), and a ZMQ subscriber receiving frames. Or a config screen showing all three enabled.
- **Frame:** 1600 px wide

---

## Group 3 — Diagrams (SVG, not screenshots)

These already exist in `assets/*.svg` and likely don't need refresh, but verify the captions match current architecture:

- [ ] `architecture-overview.svg` — confirm it shows the embedded brokers + foundation registry
- [ ] `multi-plc-clustering.svg` — confirm boss/minion proxy locus is accurate
- [ ] `redundancy-architecture.svg` — confirm hot-standby flow matches `pkg/failover`
- [ ] `architecture-driver-broadcast.svg` — confirm driver registration matches current HAL

If anything's drifted, regenerate from current source. These don't need to be redone unless the architecture they document has actually changed.

---

## Group 4 — How to wire new captures into the README

After capturing, the new screenshots need inline references. The easiest path:

1. Drop captures into `assets/screenshots/<slug>.png`
2. For the new sections (Trend, Event Spine, Alarms, Foundation, etc.), add a `<p align="center"><img src="..." width="800"></p>` right after each section's H2 heading
3. For the IDE Screenshots grid, the existing `<table>` keeps working — just update the `src` to point at new captures with the same names

I'd recommend at minimum: 2.1, 2.3, 2.4, 2.5, 2.6, 2.10 for the highest visibility on the new sections. The "refresh existing" group is lower priority unless they actively misrepresent current UI.

---

## Capture rig tips

- **Browser**: Chrome DevTools → Device Mode → set viewport to exactly 1600×900 → capture full screenshot via DevTools' three-dot menu → "Capture full size screenshot". This gives consistent dimensions without depending on monitor size.
- **CLI captures (terminals)**: Use `script` + `script2html` or screenshot the terminal window directly. Don't use ASCII art — real terminal captures with proper font and colors are more credible.
- **Crop after**: Always crop empty browser chrome and dock space; the README displays at 700–800 px so vertical real estate is precious.
- **PNG vs WebP**: Stay with PNG — GitHub's image rendering is consistent with PNG and the size difference is marginal at these dimensions.

---

*This punch list is generated from the foundation registry. Regenerate periodically as new feature sections land — the README has more surface area than the screenshot inventory.*
