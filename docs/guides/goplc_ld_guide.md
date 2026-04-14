# GoPLC Visual Ladder Diagram Editor

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.607

---

GoPLC ships with a browser-based visual ladder diagram (LD) editor that compiles IEC 61131-3 ladder logic into the same ST code the runtime executes. Drag contacts and coils onto rungs, wire timers in line, click **Compile**, and the generated ST appears in a panel below the canvas. Click **Deploy** and the rung goes live on the PLC in under a second — no file uploads, no rebuild step. Click **Online** and every contact and coil turns into a live-state indicator with click-to-force, giving you a runtime-accurate ladder view that an Allen-Bradley technician can read without explanation.

## 1. What It Is (and What It Isn't)

This is a **rung-based** ladder editor. Elements auto-place onto horizontal rungs: contacts flow left-to-right from the left power rail, coils and function blocks anchor to the right rail with a symmetric gap, and the canvas grows a new empty rung every time you drop an element onto the bottom rung. There is no free-form canvas, no pan and zoom, no drag-drop-anywhere — every element has a rung and a position on that rung, and the layout is enforced.

That constraint is deliberate. Free-form ladder canvases are the reason 90 % of visual PLC editors look like mind-maps by the third page of logic. A strict rung layout keeps the diagram readable, the compiled ST deterministic, and the online-mode overlay easy to reason about.

**Use the visual LD editor when:**

- You want to prototype logic quickly with contacts, coils, and timers
- You want to hand a running program to someone who reads ladder but not ST
- You're teaching IEC 61131-3 and want students to see the contact/coil metaphor translate to structured text in real time
- You're iterating on a small state machine and want one-click deploy + online visualization

**Don't use it for:**

- Large programs (more than ~20 rungs per file — it works, but you'll be happier in ST)
- Parallel branches, counters, or any logic that isn't pure contacts / coils / timers (the current palette has XIC, XIO, OTE, OTL, OTU, TON, TOF, TP and nothing else)
- Round-trip editing of hand-written ST — the editor does not parse ST back into rungs, so once you leave the visual editor for a program, it stays in ST

## 2. Opening the Editor

The editor is served from the same web server that hosts the main IDE:

```
http://<host>:<port>/visual-test.html
```

For a standard dev instance on port 8302: `http://localhost:8302/visual-test.html`. For a deployed runtime with the IDE on the snap channel: `http://goplc.local:8082/visual-test.html`. There is no authentication gate on this URL today — if your runtime requires login, drop the editor behind the same reverse proxy that gates the rest of `/ide/`.

The page loads with an empty LD canvas, a palette on the left, a generated-ST panel on the right, and a toolbar across the top.

## 3. Mode Selection

The dropdown in the top toolbar toggles between two visual languages:

| Mode | What it builds | When to use it |
|---|---|---|
| **LD** | Ladder diagram with contacts, coils, and timer blocks | Combinational logic, timers, basic state transitions |
| **SFC** | Sequential function chart with steps, transitions, actions, divergences, convergences | Multi-phase sequences, recipe control, sequential machine logic |

SFC is outside the scope of this guide — it's a separate visual language with its own palette and semantics. This document covers LD only. If you dropped an SFC step into an LD file by accident, delete it and switch the mode selector; the palette filters by mode automatically.

## 4. The LD Palette

Six element types:

| Palette entry | Symbol | Compiles to | Typical use |
|---|---|---|---|
| **Contact (XIC)** | `─┤ ├─` | `varname` | Normally open input — true when the variable is true |
| **Contact (XIO)** | `─┤/├─` | `NOT varname` | Normally closed input — true when the variable is false |
| **Coil (OTE)** | `─( )─` | `varname := <rung>;` | Output coil — drives the variable with the rung state |
| **Coil (OTL set)** | `─(L)─` | `IF <rung> THEN varname := TRUE; END_IF;` | Latch — sets the variable and leaves it set |
| **Coil (OTU rst)** | `─(U)─` | `IF <rung> THEN varname := FALSE; END_IF;` | Unlatch — resets a previously-set latch |
| **Timer (TON)** / **TOF** / **TP** | `┤TON├` | `instance(IN := <rung>, PT := T#250ms);` | Delay-on / delay-off / pulse timer |

Each element is a draggable tile in the palette sidebar. Drop one into the canvas and it attaches to the nearest rung. Click it to set the variable name or (for timers) the instance name and preset time.

## 5. Building a Rung

The canvas starts with two empty rungs, a left power rail, and a right power rail. To build the classic "start/stop with motor output" rung:

1. Drag **Contact (XIC)** onto rung 1. Click it, type `start_btn` in the Variable Name field.
2. Drag **Contact (XIO)** onto rung 1. Click it, type `stop_btn`.
3. Drag **Coil (OTE)** onto rung 1. Click it, type `motor_run`.
4. Click **Compile to ST** in the toolbar.

The generated ST panel shows:

```
motor_run := start_btn AND NOT stop_btn;
```

The compiler reads contacts in rung order from the left rail, ANDs them together for the rung state expression, and assigns the expression to whatever coil sits at the right rail.

### Adding a seal-in

To make the motor stay on after `start_btn` is released, add a seal-in contact. Drag a second **Contact (XIC)** onto rung 1 and set its variable to `motor_run` — the motor's own state becomes a hold-in. The visual editor does not render parallel branches (that's a known limitation), so you'd normally write:

```iec
motor_run := (start_btn OR motor_run) AND NOT stop_btn;
```

In the current visual editor you would express this by using two rungs — one for the OR and one for the AND — or by hand-editing the generated ST. The roadmap includes parallel branch support; until it lands, single-path rungs are the supported pattern.

### Adding a timer

Drag **Timer (TON)** onto rung 2. Click it to set:

- **Instance name**: `MotorDelay` (each timer needs a unique instance name — TON is a function block)
- **PT preset**: `T#500ms`

Drop an XIC upstream of the timer and set it to `start_btn`. Compile again:

```iec
MotorDelay(IN := start_btn, PT := T#500ms);
```

To use the timer's output, add another rung that references `MotorDelay.Q` as an XIC contact driving a coil.

## 6. Compile, Validate, Deploy

The toolbar has four action buttons:

| Button | What it does |
|---|---|
| **Compile to ST** | Runs the LD → ST translator in the browser, shows output in the ST panel |
| **Validate** | Sends the generated ST to `POST /api/programs/validate` on the target runtime |
| **Deploy** | Creates (or updates) the program on the target, assigns it to MainTask, reloads, and starts the runtime |
| **Online** | Enters live mode — contacts and coils become runtime-state indicators |

The target host and port default to the page URL. If you load the editor from `http://10.0.0.12:8302/visual-test.html`, the deploy target is `10.0.0.12:8302`. To deploy to a different target, use the target selector in the toolbar.

### Deploy internals

The **Deploy** button runs a short sequence of REST calls you can reproduce with `curl` if you want to script it:

```bash
# 1. Create or update the program
curl -X POST -H 'Content-Type: application/json' \
     -d '{"name":"Pulser","source":"...","mode":"st","task":"MainTask"}' \
     http://localhost:8302/api/programs

# 2. Assign it to MainTask (or create MainTask if it doesn't exist)
curl -X PUT -H 'Content-Type: application/json' \
     -d '{"programs":["Pulser"]}' \
     http://localhost:8302/api/tasks/MainTask/programs

# 3. Reload the task so the new source is compiled and running
curl -X POST http://localhost:8302/api/tasks/MainTask/reload

# 4. Make sure the runtime is actually running
curl -X POST http://localhost:8302/api/runtime/start
```

Every step is idempotent. If the program already exists, step 1 falls back to `PUT /api/programs/:name` to update it in place. If `MainTask` doesn't exist yet, step 2's failure triggers a `POST /api/tasks` with scan time 25 ms. The whole sequence typically runs in under 200 ms end-to-end.

Once the deploy completes, the status line shows `DEPLOYED + RELOADED: "<name>" running on MainTask` and the generated ST is live on the PLC.

## 7. Online Mode

Click **Online** and the canvas changes in four visible ways:

1. **Power rails turn green.** They're always green in online mode — a visual reminder that you're looking at live state, not edit state.
2. **Contacts fill.** An XIC contact with an energized variable fills its gap with solid green. XIO does the opposite — it fills when the variable is false.
3. **Coils fill and glow.** An active OTE / OTL / OTU coil fills its circle with green.
4. **Click-to-force.** Clicking any contact or coil issues `PUT /api/variables/<name>` with the inverted value — instant manual forcing with no dialog, no selection, no intermediate step.

The state polling runs at about 10 Hz, so you see discrete state transitions clearly. The energized rung path is implied by the adjacency of filled contacts — there are no explicit "wire" animations, because in a single-path rung any contact that's filled is on the energized path up to the next unfilled contact.

To exit online mode, click **Online** again. The rails return to dim and the editor goes back to edit mode.

### Use case: commissioning

Online mode's click-to-force is the single most useful feature in the editor. During commissioning you can:

1. Deploy the logic
2. Enter online mode
3. Click an XIC contact representing an input to simulate a sensor closing
4. Watch the downstream coil energize
5. Click the XIC again to release the simulated input
6. Verify the coil deenergizes

You get a complete input-to-output trace without wiring up the actual sensors — exactly the workflow you'd get from a real PLC's forcing panel, but in a browser tab.

## 8. The Built-In Demo

Click **Load Demo** in the toolbar to drop a pre-built two-TON ping-pong oscillator onto the canvas. The demo builds two rungs:

```
Rung 1:  ─[/PulseOFF.Q]──┤TON PulseON  PT=T#100ms├─
Rung 2:  ─[ PulseON.Q ]──┤TON PulseOFF PT=T#900ms├─
```

Compiled ST:

```iec
PulseON(IN := NOT PulseOFF.Q, PT := T#100ms);
PulseOFF(IN := PulseON.Q,     PT := T#900ms);
```

Deploy it, go online, and watch `PulseON.Q` pulse high for 100 ms every second. The demo is useful for three things: sanity-checking that the editor talks to your target, verifying that online mode correctly reflects timer state, and teaching the LD → ST translation with a minimal example that still does something interesting.

`PulseON.Q` is the signal to watch — it's high for 100 ms out of every 1000 ms. `PulseOFF.Q` is high only for the single scan where `PulseON` resets, so you won't see it in the live variables feed unless your poll rate is fast enough.

## 9. LD to ST Translation Reference

The in-browser compiler is a one-to-one translator from visual rungs to ST. Understanding the translation helps when you need to hand-edit the generated ST or debug a rung that isn't behaving as expected.

### Contacts (inputs)

A contact's position on the rung determines its logical role — contacts flow left-to-right and AND together to form the rung state expression.

| Rung | Compiled ST fragment |
|---|---|
| `─┤ A ├──────┤ B ├──` | `A AND B` |
| `─┤/A ├──────┤ B ├──` | `NOT A AND B` |
| `─┤ A ├──────┤/B ├──` | `A AND NOT B` |

### Coils (outputs)

A coil anchored at the right rail assigns the rung state expression to its variable. Latch and unlatch coils guard the assignment behind an `IF`.

| Rung | Compiled ST |
|---|---|
| `─┤ A ├──( M )─` | `M := A;` |
| `─┤ A ├──(L M )─` | `IF A THEN M := TRUE; END_IF;` |
| `─┤ A ├──(U M )─` | `IF A THEN M := FALSE; END_IF;` |

### Timers (function block calls)

Timer blocks take the rung state as their `IN` parameter and produce a standard IEC 61131-3 function block instance call. The instance name is the variable name you set on the block; the PT preset comes from the timer's **PT** field.

| Rung | Compiled ST |
|---|---|
| `─┤ start ├──┤ TON T1 PT=T#500ms ├─` | `T1(IN := start, PT := T#500ms);` |
| `─┤ active ├──┤ TOF T2 PT=T#1s ├─` | `T2(IN := active, PT := T#1s);` |
| `─┤ trig ├────┤ TP  T3 PT=T#200ms ├─` | `T3(IN := trig, PT := T#200ms);` |

After the call, any downstream rung can reference `T1.Q`, `T1.ET`, `T1.DN`, etc. as input contacts — the runtime exposes timer function block members as addressable variables, and the FB struct expansion in the main IDE's Live Variables panel shows them automatically.

## 10. Variables and Scope

The editor creates one program per visual file, named in the page title bar (default `SFC_Program`, overridable via the properties panel). Every contact, coil, and timer you drop onto the canvas adds an implicit variable declaration to the generated ST program header:

```iec
PROGRAM Pulser
VAR
    PulseON  : TON;
    PulseOFF : TON;
END_VAR

PulseON(IN := NOT PulseOFF.Q, PT := T#100ms);
PulseOFF(IN := PulseON.Q,     PT := T#900ms);
END_PROGRAM
```

For BOOL contacts and coils you typically want the variables declared at the global level (so other programs can read/write them) — use the properties panel's **VAR section** field to paste in your own declarations, or leave the field empty and let the editor auto-declare everything local. Timers should always be local — TON / TOF / TP instances have internal state that doesn't survive moving between programs.

## 11. Known Limitations

This editor is a work in progress. Current gaps, tracked against the ladder roadmap:

- **No parallel branches.** Every rung is a single series path. OR logic must be split across multiple rungs or hand-edited in ST.
- **No counters.** CTU / CTD / CTUD are not yet in the palette. Use ST for counting.
- **No comparison blocks.** `GEQ`, `LEQ`, `EQU` etc. are not in the palette. Use ST for numeric comparisons and reference the result as a BOOL contact.
- **No round-trip parser.** The editor compiles LD → ST one-way. Hand-edited ST cannot be re-opened in the visual editor — the rung layout is lost the moment you leave.
- **Task assignment is hardcoded to MainTask.** The Deploy button always targets `MainTask`. To deploy into a different task, edit the generated ST in the main IDE and assign it there.
- **No main IDE integration.** The visual editor is a standalone page, not yet embedded in the primary IDE's program list. You reach it via the `/visual-test.html` URL.
- **Demo models use hardcoded coordinates.** The built-in LD demo bypasses the rung auto-layout because it was written before rung mode existed. Custom programs you build from scratch use the rung system.

The roadmap for the next visual LD iteration includes parallel branches, CTU/CTD/CTUD, a compare-block palette, main IDE integration, and — eventually — round-trip parsing so ST generated by the editor can be re-opened visually.

## 12. Tips

**Keep programs small.** The editor scales to about 20 rungs per file before the canvas gets unwieldy. Split large logic into multiple programs and call them from a coordinating ST program.

**Use timer instance names that describe purpose, not hardware.** `HeaterOffDelay` is better than `TON1`. The FB struct expansion in the IDE's Live Variables panel shows the instance name verbatim, and `HeaterOffDelay.ET` is self-documenting; `TON1.ET` is not.

**Deploy often.** The round trip is fast (< 200 ms) and the runtime reloads the task in place without disrupting other tasks. Don't batch changes — deploy after every visible edit and catch errors early.

**Use online mode as a smoke test.** Every new program deserves one full click-to-force cycle in online mode before you trust it on a real machine. Energize each input path, watch the output respond, and unwind. Five minutes of online-mode testing saves an hour of hardware debugging later.

**Generate the ST first, then switch to the main IDE for heavy edits.** The visual editor is for prototyping and visualizing simple ladder logic. Once a program exceeds what the rung-based layout can express cleanly, compile it to ST once and move it into the main IDE — don't try to force ladder patterns onto logic that wants to be imperative code.

## 13. What's Next

The visual ladder editor is the first of several visual languages on the GoPLC roadmap. Shipping order:

1. **LD rung editor** (shipped — this guide)
2. **Parallel branches** (in progress — branches and OR networks)
3. **CTU / CTD / CTUD counters** (planned)
4. **Compare blocks** (`>`, `<`, `=`, `>=`, `<=`, `<>` — planned)
5. **SFC step editor** (separate mode — in progress)
6. **FBD canvas** (function block diagram — future)
7. **Round-trip ST parser** (LD ↔ ST bidirectional — future)

Everything compiles to ST under the hood, so a program authored in any visual language runs on the same interpreter as hand-written ST and interoperates with the full ST function library — all 1600+ built-ins, every protocol driver, every subsystem covered by the other guides in this directory.
