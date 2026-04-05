# GoPLC G-code: CNC, Laser & 3D Printer Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC treats CNC machines, laser cutters, and 3D printers as **G-code targets** — devices that accept standard G-code commands over a transport link. GoPLC handles connection management, protocol quirks, flow control, and progress reporting while your ST code controls the logic.

There are **two modes** of operation:

| Mode | Interface | Best For |
|------|-----------|----------|
| **ST Functions** | `GCODE_CONNECT` / `GCODE_SEND_CMD` | Full control — parse files, modify G-code on the fly, coordinate with sensors and I/O |
| **CLI Streaming** | `./goplc --gcode file.gcode --target ...` | Quick jobs — stream a file to a machine with no ST code required (free, no license) |

### Supported Transports

| Transport | URL Format | Machines |
|-----------|-----------|----------|
| **xTool HTTP** | `http://192.168.1.100:8080` | xTool D1, D1 Pro, other WiFi laser engravers |
| **GRBL Serial** | `serial:///dev/ttyUSB0:115200` | CNC routers, hobby lasers, GRBL-based controllers |
| **Marlin Serial** | `marlin:///dev/ttyUSB0:115200` | 3D printers — Ender, Prusa, Creality, any Marlin firmware |

The transport is auto-detected from the URL prefix. All 41 ST functions work identically across transports — GoPLC translates commands to the appropriate protocol internally.

### System Diagram

```
┌─────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)             │
│                                                         │
│  ┌───────────────────┐  ┌────────────────────────────┐  │
│  │ ST Program         │  │ CLI Mode (--gcode)         │  │
│  │                    │  │                            │  │
│  │ GCODE_OPEN()       │  │ ParseGcodeFile()           │  │
│  │ GCODE_CONNECT()    │  │ Stream line-by-line        │  │
│  │ GCODE_SEND_CMD()   │  │ Progress bar               │  │
│  │ GCODE_GET_X/Y/Z()  │  │ Ctrl+C graceful stop       │  │
│  └──────┬─────────────┘  └──────────┬─────────────────┘  │
│         │                           │                    │
│         ▼                           ▼                    │
│  ┌──────────────────────────────────────────────────┐    │
│  │ Transport Layer                                   │    │
│  │                                                   │    │
│  │  xTool HTTP         GRBL Serial    Marlin Serial  │    │
│  │  GET /cmd?cmd=...   line + \n      line + \n      │    │
│  │  WS keepalive       wait "ok"      wait "ok"      │    │
│  │  GET /status         ? query       M114 query     │    │
│  └──────────────────────────────────────────────────┘    │
└─────────┼──────────────────┼───────────────┼─────────────┘
          │  WiFi/Ethernet   │  USB Serial    │  USB Serial
          ▼                  ▼                ▼
     ┌─────────┐      ┌──────────┐     ┌──────────┐
     │ xTool   │      │ GRBL     │     │ Marlin   │
     │ Laser   │      │ CNC/     │     │ 3D       │
     │ Cutter  │      │ Laser    │     │ Printer  │
     └─────────┘      └──────────┘     └──────────┘
```

---

## 2. CLI Streaming Mode

The fastest way to send a G-code file to a machine — no ST code, no license required.

```bash
# Laser cutter via WiFi (xTool)
./goplc --gcode engrave.gcode --target http://192.168.1.100:8080

# CNC router via USB (GRBL)
./goplc --gcode toolpath.gcode --target serial:///dev/ttyUSB0:115200

# 3D printer via USB (Marlin)
./goplc --gcode print.gcode --target marlin:///dev/ttyACM0:115200
```

Features:
- Real-time progress bar with line count and percentage
- Ctrl+C graceful stop (sends appropriate stop command per transport)
- Comment stripping, blank line removal, auto-uppercase
- Flow control — waits for "ok" from GRBL/Marlin before sending next line

---

## 3. ST Function Reference

### 3.1 File I/O

Handle-based pattern: `GCODE_OPEN` parses a `.gcode` file into memory, then you iterate lines with `GCODE_NEXT`. Comments and blank lines are stripped automatically; all commands are uppercased.

#### GCODE_OPEN — Load G-code File

```iecst
file := GCODE_OPEN('/home/james/jobs/part1.gcode');
(* Returns handle string like 'gc_1', or '' on failure *)
```

> **License:** `GCODE_OPEN` and all `GCODE_*` ST functions require a license. CLI mode (`--gcode`) is free.

#### GCODE_NEXT — Read Next Line

```iecst
line := GCODE_NEXT(file);
(* Returns next G-code line (e.g. 'G1 X50 Y20 F1000'), '' when done *)
```

#### GCODE_PEEK — Look Ahead Without Advancing

```iecst
next_line := GCODE_PEEK(file);
(* Same as NEXT but doesn't advance the position *)
```

#### GCODE_DONE — Check If File Complete

```iecst
IF GCODE_DONE(file) THEN
    (* All lines have been read *)
END_IF;
```

#### GCODE_PROGRESS — Completion Percentage

```iecst
pct := GCODE_PROGRESS(file);
(* Returns: 0.0 to 100.0 *)
```

#### GCODE_LINE_NUM / GCODE_TOTAL — Position Tracking

```iecst
current := GCODE_LINE_NUM(file);    (* 1-based current line *)
total := GCODE_TOTAL(file);          (* total parsed lines *)
```

#### GCODE_RESET — Restart From Beginning

```iecst
GCODE_RESET(file);
(* Position reset to first line — useful for re-running a job *)
```

#### GCODE_CLOSE — Free Resources

```iecst
GCODE_CLOSE(file);
```

#### Example: Stream a G-code File

```iecst
PROGRAM POU_GcodeStream
VAR
    file : STRING;
    machine : STRING;
    line : STRING;
    resp : STRING;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Open file and connect *)
        file := GCODE_OPEN('/home/james/jobs/part1.gcode');
        machine := GCODE_CONNECT('serial:///dev/ttyUSB0:115200');
        IF file <> '' AND machine <> '' THEN
            GCODE_HOME(machine);
            state := 1;
        END_IF;

    1: (* Stream line by line *)
        IF NOT GCODE_DONE(file) THEN
            line := GCODE_NEXT(file);
            resp := GCODE_SEND_CMD(machine, line);
        ELSE
            state := 2;
        END_IF;

    2: (* Done *)
        GCODE_CLOSE(file);
        GCODE_DISCONNECT(machine);
        state := 99;
END_CASE;
END_PROGRAM
```

---

### 3.2 Line Parser & Modifier

Pure string operations on individual G-code lines — no handles, no state. Extract axis values, modify parameters, check command types.

#### Getters — Extract Values

| Function | Signature | Returns | Example |
|----------|-----------|---------|---------|
| `GCODE_GET_CODE` | `(line)` | STRING | `'G1 X50 Y20'` → `'G1'` |
| `GCODE_GET_X` | `(line)` | REAL | `'G1 X50.5 Y20'` → `50.5` |
| `GCODE_GET_Y` | `(line)` | REAL | `'G1 X50 Y20.3'` → `20.3` |
| `GCODE_GET_Z` | `(line)` | REAL | `'G1 Z5.0'` → `5.0` |
| `GCODE_GET_F` | `(line)` | REAL | `'G1 X50 F1000'` → `1000.0` |
| `GCODE_GET_S` | `(line)` | REAL | `'M3 S800'` → `800.0` (spindle/laser power) |
| `GCODE_GET_E` | `(line)` | REAL | `'G1 X50 E12.5'` → `12.5` (extruder) |
| `GCODE_GET_PARAM` | `(line, param)` | REAL | `('G1 X50 I10', 'I')` → `10.0` (any letter) |

```iecst
line := GCODE_NEXT(file);
code := GCODE_GET_CODE(line);       (* 'G1' *)
x := GCODE_GET_X(line);             (* 50.5 *)
feed := GCODE_GET_F(line);          (* 1000.0 *)
arc_i := GCODE_GET_PARAM(line, 'I');  (* arc center offset *)
```

#### Setters — Modify Values

Each setter returns a **new string** with the parameter replaced (or appended if it didn't exist).

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_SET_X` | `(line, value)` | STRING |
| `GCODE_SET_Y` | `(line, value)` | STRING |
| `GCODE_SET_Z` | `(line, value)` | STRING |
| `GCODE_SET_F` | `(line, value)` | STRING |
| `GCODE_SET_S` | `(line, value)` | STRING |
| `GCODE_SET_E` | `(line, value)` | STRING |
| `GCODE_SET_PARAM` | `(line, param, value)` | STRING |

```iecst
(* Clamp feed rate to 2000 mm/min *)
line := GCODE_NEXT(file);
IF GCODE_GET_F(line) > 2000.0 THEN
    line := GCODE_SET_F(line, 2000.0);
END_IF;
GCODE_SEND_CMD(machine, line);
```

#### Checkers

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_HAS_PARAM` | `(line, param)` | BOOL — TRUE if parameter letter exists |
| `GCODE_IS_MOVE` | `(line)` | BOOL — TRUE for G0, G1, G2, G3 (and G00-G03) |

```iecst
IF GCODE_IS_MOVE(line) AND GCODE_HAS_PARAM(line, 'Z') THEN
    (* This is a Z-axis move — check for plunge depth *)
    IF GCODE_GET_Z(line) < -10.0 THEN
        line := GCODE_SET_Z(line, -10.0);    (* clamp depth *)
    END_IF;
END_IF;
```

#### Example: Feed Rate Override

```iecst
PROGRAM POU_FeedOverride
VAR
    file : STRING;
    machine : STRING;
    line : STRING;
    override_pct : REAL := 80.0;    (* 80% feed rate *)
    original_f : REAL;
    state : INT := 0;
END_VAR

CASE state OF
    0:
        file := GCODE_OPEN('/home/james/jobs/toolpath.gcode');
        machine := GCODE_CONNECT('serial:///dev/ttyUSB0:115200');
        IF file <> '' AND machine <> '' THEN
            GCODE_HOME(machine);
            state := 1;
        END_IF;

    1:
        IF NOT GCODE_DONE(file) THEN
            line := GCODE_NEXT(file);

            (* Scale feed rate on motion commands *)
            IF GCODE_IS_MOVE(line) AND GCODE_HAS_PARAM(line, 'F') THEN
                original_f := GCODE_GET_F(line);
                line := GCODE_SET_F(line, original_f * override_pct / 100.0);
            END_IF;

            GCODE_SEND_CMD(machine, line);
        ELSE
            state := 2;
        END_IF;

    2:
        GCODE_CLOSE(file);
        GCODE_DISCONNECT(machine);
        state := 99;
END_CASE;
END_PROGRAM
```

---

### 3.3 Machine Connection

#### GCODE_CONNECT — Open Connection

Transport is auto-detected from the URL prefix.

```iecst
(* xTool laser cutter via WiFi *)
machine := GCODE_CONNECT('http://192.168.1.100:8080');

(* GRBL CNC router via USB serial *)
machine := GCODE_CONNECT('serial:///dev/ttyUSB0:115200');

(* Marlin 3D printer via USB serial *)
machine := GCODE_CONNECT('marlin:///dev/ttyACM0:115200');
```

Returns a handle string (e.g. `'gm_1'`) on success, `''` on failure.

**Transport details:**

| Transport | Connect Behavior |
|-----------|-----------------|
| **xTool** | Opens HTTP client + WebSocket on port+1 for keepalive (2-second ping) |
| **GRBL** | Opens serial port, waits up to 5s for GRBL init banner, sets 30s read timeout |
| **Marlin** | Opens serial port, waits up to 5s for Marlin/start banner, sets 30s read timeout |

#### GCODE_SEND_CMD — Send G-code Command

```iecst
resp := GCODE_SEND_CMD(machine, 'G1 X50 Y20 F1000');
(* xTool: HTTP response body *)
(* GRBL/Marlin: 'ok' or 'error:N' *)
```

Returns `''` on failure or if the machine is disconnected.

#### GCODE_CONNECTED — Check Connection

```iecst
IF NOT GCODE_CONNECTED(machine) THEN
    (* Machine disconnected — handle error *)
END_IF;
```

> **Auto-disconnect:** If a serial read times out (30 seconds) or an HTTP request fails, GoPLC marks the machine as disconnected automatically.

#### GCODE_DISCONNECT — Close Connection

```iecst
GCODE_DISCONNECT(machine);
(* xTool: closes WebSocket + HTTP client *)
(* GRBL/Marlin: closes serial port *)
```

---

### 3.4 Machine Status & Position

#### GCODE_STATUS — Machine Status

```iecst
status := GCODE_STATUS(machine);
```

| Transport | Response Format |
|-----------|----------------|
| **xTool** | JSON from GET /status — `{"mode":"P_IDLE",...}` |
| **GRBL** | Status line from `?` query — `<Idle\|MPos:0.000,0.000,0.000\|...>` |
| **Marlin** | M114 position response — `X:10.00 Y:20.00 Z:0.00 E:0.00` |

#### GCODE_POSITION — Full Position String

```iecst
pos := GCODE_POSITION(machine);
(* Returns: '10.000,20.000,0.000' — X,Y,Z as comma-separated string *)
```

#### GCODE_POS_X / GCODE_POS_Y / GCODE_POS_Z — Individual Axes

```iecst
x := GCODE_POS_X(machine);    (* REAL — current X position *)
y := GCODE_POS_Y(machine);    (* REAL — current Y position *)
z := GCODE_POS_Z(machine);    (* REAL — current Z position *)
```

> **GRBL position:** Reports MPos (machine position) by default. If MPos is not available, falls back to WPos (work position).

---

### 3.5 Machine Control

#### GCODE_HOME — Home All Axes

```iecst
GCODE_HOME(machine);
```

| Transport | Command Sent |
|-----------|-------------|
| **xTool** | `G28` via HTTP |
| **GRBL** | `$H` (GRBL homing cycle) |
| **Marlin** | `G28` |

#### GCODE_PAUSE — Pause Operation

```iecst
GCODE_PAUSE(machine);
```

| Transport | Command Sent |
|-----------|-------------|
| **xTool** | GET `/cnc/data?action=pause` |
| **GRBL** | `!` (feed hold, real-time character) |
| **Marlin** | `M25` |

#### GCODE_RESUME — Resume Operation

```iecst
GCODE_RESUME(machine);
```

| Transport | Command Sent |
|-----------|-------------|
| **xTool** | GET `/cnc/data?action=resume` |
| **GRBL** | `~` (cycle start, real-time character) |
| **Marlin** | `M24` |

#### GCODE_STOP — Emergency Stop

```iecst
GCODE_STOP(machine);
```

| Transport | Command Sent |
|-----------|-------------|
| **xTool** | GET `/cnc/data?action=stop` |
| **GRBL** | `0x18` (soft reset) |
| **Marlin** | `M112` (emergency stop) |

> **Warning:** `GCODE_STOP` is an emergency stop — it resets the controller. The machine will need to be re-homed after a stop.

---

## 4. Transport Notes

### xTool HTTP

- The xTool firmware exposes a REST API on port 8080 (configurable)
- A WebSocket connection on port+1 keeps the machine alive — without it, the xTool may auto-sleep
- GoPLC sends 2-second WebSocket pings and drains incoming messages to prevent buffer overflow
- Commands are URL-encoded and sent via `GET /cmd?cmd=<encoded>`
- If the WebSocket fails to connect, GoPLC warns but continues — some xTool models may not require it

### GRBL Serial

- Standard GRBL protocol: send line + newline, wait for `ok` or `error:N`
- Real-time commands (`?`, `!`, `~`, `0x18`) are single characters sent without waiting for response
- GRBL 1.1 status format: `<State|MPos:x,y,z|FS:f,s|...>`
- Default baud rate: 115200
- 30-second read timeout — if the machine doesn't respond, connection is marked dead

### Marlin Serial

- Same serial protocol as GRBL (line + newline, wait for `ok`)
- Status via `M114` (returns `X:10.00 Y:20.00 Z:0.00 E:0.00`)
- Pause/resume via `M25`/`M24` (SD card / host-managed print)
- Emergency stop via `M112`
- Homing via `G28` (same as standard G-code)
- Marlin init banner includes `Marlin` or `start` keyword — GoPLC waits up to 5 seconds for it

---

## 5. Complete Example: Laser Engraving with Safety

```iecst
PROGRAM POU_LaserJob
VAR
    file : STRING;
    machine : STRING;
    line : STRING;
    resp : STRING;
    code : STRING;
    max_power : REAL := 600.0;      (* safety limit *)
    state : INT := 0;
    progress : REAL;
END_VAR

CASE state OF
    0: (* Connect *)
        file := GCODE_OPEN('/home/james/jobs/engrave.gcode');
        machine := GCODE_CONNECT('http://192.168.1.100:8080');
        IF file <> '' AND machine <> '' THEN
            GCODE_HOME(machine);
            state := 1;
        END_IF;

    1: (* Stream with power clamping *)
        IF NOT GCODE_DONE(file) THEN
            line := GCODE_NEXT(file);

            (* Clamp laser power for safety *)
            IF GCODE_HAS_PARAM(line, 'S') THEN
                IF GCODE_GET_S(line) > max_power THEN
                    line := GCODE_SET_S(line, max_power);
                END_IF;
            END_IF;

            resp := GCODE_SEND_CMD(machine, line);
            progress := GCODE_PROGRESS(file);
        ELSE
            state := 2;
        END_IF;

    1000: (* Emergency — called from external trigger *)
        GCODE_STOP(machine);
        state := 99;

    2: (* Complete *)
        GCODE_SEND_CMD(machine, 'M5');    (* laser off *)
        GCODE_SEND_CMD(machine, 'G28');   (* home *)
        GCODE_CLOSE(file);
        GCODE_DISCONNECT(machine);
        state := 99;
END_CASE;
END_PROGRAM
```

---

## 6. Complete Example: 3D Print with Progress Monitoring

```iecst
PROGRAM POU_3DPrint
VAR
    file : STRING;
    printer : STRING;
    line : STRING;
    state : INT := 0;
    progress : REAL;
    current_z : REAL;
    layer_count : DINT := 0;
END_VAR

CASE state OF
    0: (* Connect to Marlin printer *)
        file := GCODE_OPEN('/home/james/prints/benchy.gcode');
        printer := GCODE_CONNECT('marlin:///dev/ttyACM0:115200');
        IF file <> '' AND printer <> '' THEN
            GCODE_HOME(printer);
            (* Preheat: bed 60C, hotend 200C *)
            GCODE_SEND_CMD(printer, 'M140 S60');
            GCODE_SEND_CMD(printer, 'M104 S200');
            (* Wait for temps *)
            GCODE_SEND_CMD(printer, 'M190 S60');
            GCODE_SEND_CMD(printer, 'M109 S200');
            state := 1;
        END_IF;

    1: (* Stream G-code *)
        IF NOT GCODE_DONE(file) THEN
            line := GCODE_NEXT(file);

            (* Track layer changes *)
            IF GCODE_IS_MOVE(line) AND GCODE_HAS_PARAM(line, 'Z') THEN
                IF GCODE_GET_Z(line) > current_z THEN
                    current_z := GCODE_GET_Z(line);
                    layer_count := layer_count + 1;
                END_IF;
            END_IF;

            GCODE_SEND_CMD(printer, line);
            progress := GCODE_PROGRESS(file);
        ELSE
            state := 2;
        END_IF;

    2: (* Cooldown and park *)
        GCODE_SEND_CMD(printer, 'M104 S0');    (* hotend off *)
        GCODE_SEND_CMD(printer, 'M140 S0');    (* bed off *)
        GCODE_SEND_CMD(printer, 'G28 X Y');    (* park XY *)
        GCODE_SEND_CMD(printer, 'M84');        (* motors off *)
        GCODE_CLOSE(file);
        GCODE_DISCONNECT(printer);
        state := 99;
END_CASE;
END_PROGRAM
```

---

## Appendix: Complete Function Quick Reference

### File I/O (9 functions)

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_OPEN` | `(path)` | STRING — file handle, `''` on failure |
| `GCODE_NEXT` | `(handle)` | STRING — next line, `''` when done |
| `GCODE_PEEK` | `(handle)` | STRING — next line without advancing |
| `GCODE_DONE` | `(handle)` | BOOL — TRUE when all lines read |
| `GCODE_PROGRESS` | `(handle)` | REAL — 0.0 to 100.0 |
| `GCODE_LINE_NUM` | `(handle)` | DINT — current line (1-based) |
| `GCODE_TOTAL` | `(handle)` | DINT — total parsed lines |
| `GCODE_RESET` | `(handle)` | BOOL — rewind to start |
| `GCODE_CLOSE` | `(handle)` | BOOL |

### Line Parser (10 functions)

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_GET_CODE` | `(line)` | STRING — G/M code (`'G1'`, `'M3'`) |
| `GCODE_GET_X` | `(line)` | REAL |
| `GCODE_GET_Y` | `(line)` | REAL |
| `GCODE_GET_Z` | `(line)` | REAL |
| `GCODE_GET_F` | `(line)` | REAL — feed rate |
| `GCODE_GET_S` | `(line)` | REAL — spindle/laser power |
| `GCODE_GET_E` | `(line)` | REAL — extruder |
| `GCODE_GET_PARAM` | `(line, param)` | REAL — any parameter letter |
| `GCODE_HAS_PARAM` | `(line, param)` | BOOL |
| `GCODE_IS_MOVE` | `(line)` | BOOL — G0/G1/G2/G3 |

### Line Modifier (7 functions)

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_SET_X` | `(line, value)` | STRING — modified line |
| `GCODE_SET_Y` | `(line, value)` | STRING |
| `GCODE_SET_Z` | `(line, value)` | STRING |
| `GCODE_SET_F` | `(line, value)` | STRING |
| `GCODE_SET_S` | `(line, value)` | STRING |
| `GCODE_SET_E` | `(line, value)` | STRING |
| `GCODE_SET_PARAM` | `(line, param, value)` | STRING |

### Machine Connection (3 functions)

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_CONNECT` | `(target)` | STRING — machine handle |
| `GCODE_SEND_CMD` | `(handle, command)` | STRING — response |
| `GCODE_DISCONNECT` | `(handle)` | BOOL |

### Machine Status (5 functions)

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_CONNECTED` | `(handle)` | BOOL |
| `GCODE_STATUS` | `(handle)` | STRING — transport-specific status |
| `GCODE_POSITION` | `(handle)` | STRING — `'X,Y,Z'` |
| `GCODE_POS_X` | `(handle)` | REAL |
| `GCODE_POS_Y` | `(handle)` | REAL |
| `GCODE_POS_Z` | `(handle)` | REAL |

### Machine Control (4 functions)

| Function | Signature | Returns |
|----------|-----------|---------|
| `GCODE_HOME` | `(handle)` | BOOL — home all axes |
| `GCODE_PAUSE` | `(handle)` | BOOL |
| `GCODE_RESUME` | `(handle)` | BOOL |
| `GCODE_STOP` | `(handle)` | BOOL — emergency stop |

**41 functions total** across file I/O, parsing, connection, status, and control.

---

*GoPLC v1.0.533 | Transports: xTool HTTP, GRBL serial, Marlin serial*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
