# GoPLC IDE & Runtime Reference Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC is a browser-based soft PLC that combines an IEC 61131-3 Structured Text runtime with a modern development environment. The system is built on four pillars:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **IDE** | Monaco Editor (VS Code engine) | ST editing, syntax highlighting, IntelliSense, error markers |
| **REST API** | 253 endpoints | Full CRUD for programs, tasks, variables, HMI, diagnostics |
| **WebSocket** | Real-time push | Variable subscriptions, scan metrics, debug events, HMI binding |
| **Project Files** | `.goplc` (JSON v1.7) | Portable project snapshots — programs, tasks, I/O, HMI, metadata |

### System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│  Browser (IDE Client)                                            │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │ Monaco Editor │  │ HMI Builder  │  │ Debug / Diagnostics    │  │
│  │ (ST code)     │  │ (Vue.js)     │  │ (breakpoints, watch)   │  │
│  └──────┬────────┘  └──────┬───────┘  └──────────┬─────────────┘  │
│         │ REST              │ REST + WS            │ REST + WS     │
└─────────┼──────────────────┼──────────────────────┼───────────────┘
          │                  │                      │
          ▼                  ▼                      ▼
┌──────────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, Linux/Windows/macOS)                         │
│                                                                  │
│  ┌────────────┐  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │
│  │ Task       │  │ Program    │  │ Variable │  │ Protocol    │  │
│  │ Scheduler  │  │ Manager    │  │ Store    │  │ Drivers     │  │
│  │ (priority, │  │ (POUs,     │  │ (atomic, │  │ (Modbus,    │  │
│  │  periodic, │  │  FBs, FCs, │  │  typed,  │  │  OPC UA,    │  │
│  │  watchdog) │  │  GVLs)     │  │  scoped) │  │  MQTT, ...) │  │
│  └────────────┘  └────────────┘  └──────────┘  └─────────────┘  │
│                                                                  │
│  ┌────────────┐  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │
│  │ AI         │  │ Debugger   │  │ HMI      │  │ Project     │  │
│  │ Assistant  │  │ (step,     │  │ Server   │  │ Manager     │  │
│  │ (Claude,   │  │  break,    │  │ (Vue.js, │  │ (.goplc,    │  │
│  │  OpenAI,   │  │  watch)    │  │  WS      │  │  snapshots) │  │
│  │  Ollama)   │  │            │  │  bind)   │  │             │  │
│  └────────────┘  └────────────┘  └──────────┘  └─────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

The runtime is a single Go binary. All configuration, code, and state are accessible through the REST API — there are no configuration files to hand-edit.

---

## 2. Task Scheduler

Tasks are the execution containers in GoPLC. Each task runs one or more programs in a periodic scan loop with configurable priority, timing, and fault behavior.

### 2.1 Task Configuration

| Field | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique task identifier |
| `type` | STRING | Execution model — `periodic` (only supported type) |
| `priority` | INT | 1 (highest) to 100 (lowest) — controls Go goroutine scheduling weight |
| `scan_time_ms` | INT | Target scan interval in milliseconds |
| `programs` | ARRAY | Ordered list of program names to execute per scan |
| `watchdog_ms` | INT | Maximum allowed scan duration before watchdog triggers |
| `watchdog_fault` | BOOL | If TRUE, task enters faulted state on watchdog trip |
| `watchdog_halt` | BOOL | If TRUE, task stops entirely on watchdog trip |
| `cpu_affinity` | INT | Pin task goroutine to specific CPU core (-1 = any) |

### 2.2 Runtime Metrics

Every task exposes real-time performance counters:

| Metric | Type | Description |
|--------|------|-------------|
| `scan_count` | DINT | Total scans since task start |
| `last_scan_time_us` | DINT | Most recent scan duration in microseconds |
| `max_scan_time_us` | DINT | Worst-case scan time since start |
| `min_scan_time_us` | DINT | Best-case scan time since start |
| `avg_scan_time_us` | REAL | Running average scan time |
| `errors` | DINT | Cumulative scan errors |
| `faulted` | BOOL | TRUE if task is in faulted state |
| `watchdog_trips` | DINT | Number of times watchdog has fired |

### 2.3 API

```
POST   /api/tasks              — Create task
GET    /api/tasks              — List all tasks
GET    /api/tasks/{name}       — Get task detail + metrics
PUT    /api/tasks/{name}       — Update task configuration
DELETE /api/tasks/{name}       — Delete task
POST   /api/tasks/{name}/start — Start task
POST   /api/tasks/{name}/stop  — Stop task
POST   /api/tasks/{name}/reload — Hot reload (no downtime)
```

### 2.4 Hot Reload

```
POST /api/tasks/{name}/reload
```

Hot reload re-compiles and swaps programs in a running task **without stopping execution**. Variable values are retained across the reload. The sequence:

1. Compile new program versions
2. Pause task at scan boundary
3. Swap program references
4. Resume task — next scan runs new code

This enables live code updates in production without losing state or interrupting I/O.

### 2.5 Example: Create a 100ms Task

```iecst
(* This is configured via API, not ST — shown here for reference *)
(*
POST /api/tasks
{
    "name": "MainTask",
    "type": "periodic",
    "priority": 10,
    "scan_time_ms": 100,
    "programs": ["POU_Control", "POU_Comms"],
    "watchdog_ms": 500,
    "watchdog_fault": true,
    "watchdog_halt": false,
    "cpu_affinity": -1
}
*)
```

> **Priority vs. Scan Time:** Priority determines which task gets CPU time when multiple tasks compete. A priority-1 task with a 10ms scan will preempt a priority-50 task even if both are overdue. Set critical control loops to low priority numbers and HMI/logging tasks to high numbers.

---

## 3. Program Management

GoPLC implements the IEC 61131-3 Program Organization Unit (POU) model. All code is written in Structured Text and managed through the REST API.

### 3.1 POU Types

| Type | Prefix | Description |
|------|--------|-------------|
| **PROGRAM** | `POU_` | Top-level executable unit — assigned to tasks, retains state between scans |
| **FUNCTION_BLOCK** | `FB_` | Reusable logic with instance data — called from programs or other FBs |
| **FUNCTION** | `FC_` | Stateless — returns a single value, no persistent variables |
| **Global Variable List** | `GVL_` | Shared variables accessible across all programs |
| **Type Definition** | `TYPE_` | User-defined data types (structs, enums, aliases) |

GoPLC auto-detects the POU type from the prefix when creating programs. No manual type annotation is needed.

### 3.2 API

```
POST   /api/programs              — Create or update program (auto-detects type)
GET    /api/programs              — List all programs
GET    /api/programs/{name}       — Get program source + metadata
DELETE /api/programs/{name}       — Delete program
POST   /api/programs/{name}/validate — Syntax check without deploying
```

### 3.3 Validation

The `/validate` endpoint compiles the program and returns errors without deploying to the runtime. This is what the IDE calls on every save to populate error markers in the editor.

```
POST /api/programs/POU_Control/validate

Response (success):
{ "valid": true, "errors": [] }

Response (failure):
{ "valid": false, "errors": [
    {"line": 12, "column": 5, "message": "Undeclared variable 'sesnor_value'"}
]}
```

### 3.4 Example: Program, Function Block, and Function

```iecst
(* TYPE definition — user-defined struct *)
TYPE TYPE_PIDParams
STRUCT
    kp : REAL := 1.0;
    ki : REAL := 0.1;
    kd : REAL := 0.05;
    setpoint : REAL;
    output_min : REAL := 0.0;
    output_max : REAL := 100.0;
END_STRUCT
END_TYPE
```

```iecst
(* Function — stateless, returns scaled value *)
FUNCTION FC_ScaleInput : REAL
VAR_INPUT
    raw : INT;
    in_min : INT;
    in_max : INT;
    out_min : REAL;
    out_max : REAL;
END_VAR

FC_ScaleInput := out_min + (INT_TO_REAL(raw - in_min) /
    INT_TO_REAL(in_max - in_min)) * (out_max - out_min);
END_FUNCTION
```

```iecst
(* Function Block — PID controller with state *)
FUNCTION_BLOCK FB_PID
VAR_INPUT
    pv : REAL;           (* process variable *)
    params : TYPE_PIDParams;
END_VAR
VAR_OUTPUT
    cv : REAL;           (* control variable *)
END_VAR
VAR
    integral : REAL;
    prev_error : REAL;
END_VAR

VAR_TEMP
    error : REAL;
    derivative : REAL;
END_VAR

error := params.setpoint - pv;
integral := integral + error;
derivative := error - prev_error;

cv := params.kp * error +
      params.ki * integral +
      params.kd * derivative;

(* Clamp output *)
IF cv < params.output_min THEN
    cv := params.output_min;
    integral := integral - error;   (* anti-windup *)
ELSIF cv > params.output_max THEN
    cv := params.output_max;
    integral := integral - error;
END_IF;

prev_error := error;
END_FUNCTION_BLOCK
```

```iecst
(* Global Variable List — shared across all programs *)
VAR_GLOBAL
    temperature_raw : INT;
    temperature_scaled : REAL;
    heater_output : REAL;
    system_running : BOOL := FALSE;
END_VAR
```

```iecst
(* Main Program — uses all of the above *)
PROGRAM POU_Control
VAR
    pid : FB_PID;
    pid_params : TYPE_PIDParams := (
        kp := 2.0,
        ki := 0.5,
        kd := 0.1,
        setpoint := 72.0,
        output_min := 0.0,
        output_max := 100.0
    );
END_VAR

IF system_running THEN
    (* Scale raw ADC to temperature *)
    temperature_scaled := FC_ScaleInput(
        temperature_raw, 0, 4095, 32.0, 212.0
    );

    (* Run PID *)
    pid(pv := temperature_scaled, params := pid_params);
    heater_output := pid.cv;
ELSE
    heater_output := 0.0;
END_IF;
END_PROGRAM
```

---

## 4. Statement-Level Debugger

GoPLC includes a full statement-level debugger accessible through the REST API and IDE. It supports breakpoints, stepping, call stack inspection, and variable watching — all while the runtime continues to serve other tasks.

### 4.1 Breakpoints

Breakpoints are set at a specific program and line number. When a task's scan reaches a breakpoint, that task pauses while other tasks continue running.

```
POST /api/debug/step/breakpoints
{
    "program": "POU_Control",
    "line": 15,
    "enabled": true,
    "condition": "temperature_scaled > 200.0"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `program` | STRING | Program name where breakpoint is set |
| `line` | INT | Line number (1-based) |
| `enabled` | BOOL | Toggle without removing |
| `condition` | STRING | Optional — ST expression that must evaluate TRUE to break |

### 4.2 Step Modes

| Mode | API Endpoint | Behavior |
|------|-------------|----------|
| **Step Into** | `POST /api/debug/step/into` | Enter function block or function calls |
| **Step Over** | `POST /api/debug/step/over` | Execute FB/FC calls as a single step |
| **Step Out** | `POST /api/debug/step/out` | Run until the current FB/FC returns |
| **Continue** | `POST /api/debug/step/continue` | Run until the next breakpoint |

### 4.3 Enable / Disable

The debugger must be explicitly enabled. When disabled, breakpoints are ignored and there is zero overhead on the scan loop.

```
POST /api/debug/step/enable    — Activate debugger
POST /api/debug/step/disable   — Deactivate (removes all pauses)
```

### 4.4 State Inspection

```
GET /api/debug/step/state
```

Returns the current debugger state:

```json
{
    "enabled": true,
    "paused": true,
    "program": "POU_Control",
    "line": 15,
    "statement": "temperature_scaled := FC_ScaleInput(...);",
    "call_stack": [
        {"program": "POU_Control", "line": 15, "function": "POU_Control"}
    ],
    "locals": {
        "pid_params.setpoint": 72.0,
        "pid_params.kp": 2.0
    },
    "globals": {
        "temperature_raw": 2048,
        "temperature_scaled": 122.5,
        "heater_output": 45.3
    }
}
```

```
GET /api/debug/step/breakpoints
```

Returns all configured breakpoints with hit counts.

### 4.5 Debugger API Summary

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/debug/step/enable` | POST | Enable debugger |
| `/api/debug/step/disable` | POST | Disable debugger |
| `/api/debug/step/into` | POST | Step into FB/FC |
| `/api/debug/step/over` | POST | Step over FB/FC |
| `/api/debug/step/out` | POST | Step out of current FB/FC |
| `/api/debug/step/continue` | POST | Continue to next breakpoint |
| `/api/debug/step/state` | GET | Current position, stack, variables |
| `/api/debug/step/breakpoints` | GET/POST/DELETE | Manage breakpoints |

> **Production Safety:** The debugger only pauses the task that hits a breakpoint. All other tasks continue running at full speed. This means you can debug an HMI task without stopping a critical control loop — but be careful debugging control tasks on live equipment.

---

## 5. Debug Logging

GoPLC provides structured logging from within ST programs. Log messages can be routed to multiple simultaneous targets — file, database, time-series, syslog, and an in-memory ring buffer.

### 5.1 Log Functions

| Function | Description |
|----------|-------------|
| `DEBUG_LOG(message)` | Log at DEBUG level |
| `DEBUG_TRACE(message)` | Log at TRACE level |
| `DEBUG_INFO(message)` | Log at INFO level |
| `DEBUG_WARN(message)` | Log at WARN level |
| `DEBUG_ERROR(message)` | Log at ERROR level |
| `DEBUG_ENABLE()` | Enable logging globally |
| `DEBUG_DISABLE()` | Disable logging globally |
| `DEBUG_SET_LEVEL(level)` | Set minimum log level: `'TRACE'`, `'DEBUG'`, `'INFO'`, `'WARN'`, `'ERROR'` |

### 5.2 Log Targets

#### File Target

```iecst
(* Log to file with automatic rotation *)
DEBUG_TO_FILE('/var/log/goplc/control.log');
(* 10 MB max file size, 3 backup files retained *)
(* Produces: control.log, control.log.1, control.log.2, control.log.3 *)
```

#### SQLite Target

```iecst
(* Log to local SQLite database *)
DEBUG_TO_SQLITE('/var/lib/goplc/logs.db');
```

Creates a `logs` table with columns: `id`, `timestamp`, `level`, `program`, `task`, `message`.

#### PostgreSQL Target

```iecst
(* Log to PostgreSQL *)
DEBUG_TO_POSTGRES('host=10.0.0.144 port=5432 dbname=goplc user=goplc password=secret');
```

#### InfluxDB Target

```iecst
(* Log to InfluxDB for time-series analysis *)
DEBUG_TO_INFLUX('http://10.0.0.144:8086', 'goplc_logs');
```

Writes log entries as InfluxDB points with tags for `level`, `program`, and `task`.

#### Syslog Target

Logs are forwarded via UDP using RFC 3164 format. Configure the syslog destination through the API:

```
POST /api/config/logging
{
    "syslog": {
        "enabled": true,
        "host": "10.0.0.144",
        "port": 514,
        "facility": "local0"
    }
}
```

#### Ring Buffer (In-Memory)

All log messages are always stored in an in-memory ring buffer regardless of other targets. The buffer is queryable through the API:

```
GET /api/logs?level=WARN&limit=50&program=POU_Control
```

### 5.3 Example: Multi-Target Logging

```iecst
PROGRAM POU_Diagnostics
VAR
    init_done : BOOL := FALSE;
    cycle_count : DINT := 0;
    temperature : REAL;
END_VAR

IF NOT init_done THEN
    DEBUG_ENABLE();
    DEBUG_SET_LEVEL('INFO');
    DEBUG_TO_FILE('/var/log/goplc/diagnostics.log');
    DEBUG_TO_SQLITE('/var/lib/goplc/diagnostics.db');
    DEBUG_TO_INFLUX('http://10.0.0.144:8086', 'plc_logs');
    DEBUG_INFO('Diagnostics program initialized');
    init_done := TRUE;
END_IF;

cycle_count := cycle_count + 1;

(* Periodic status *)
IF (cycle_count MOD 600) = 0 THEN
    DEBUG_INFO(CONCAT('Heartbeat — cycle: ', DINT_TO_STRING(cycle_count)));
END_IF;

(* Alarm conditions *)
IF temperature > 180.0 THEN
    DEBUG_ERROR(CONCAT('OVER-TEMP: ', REAL_TO_STRING(temperature), ' F'));
ELSIF temperature > 150.0 THEN
    DEBUG_WARN(CONCAT('High temp warning: ', REAL_TO_STRING(temperature), ' F'));
END_IF;
END_PROGRAM
```

---

## 6. AI Assistant

GoPLC includes a built-in AI assistant that understands the runtime context — variables, tasks, programs, faults, and protocols. It supports three provider backends and two interaction modes.

### 6.1 Providers

| Provider | Model | Configuration |
|----------|-------|---------------|
| **Claude** (default) | claude-sonnet-4-20250514 | API key in runtime config |
| **OpenAI** | gpt-4o | API key in runtime config |
| **Ollama** | Any local model | URL (e.g., `http://10.0.0.196:11434`) |

### 6.2 Chat Mode

```
POST /api/ai/chat
{
    "message": "Write a PID loop for temperature control with anti-windup",
    "context": "auto"
}
```

When `context` is `"auto"`, the runtime automatically includes:

- All variable names, types, and current values
- Task configuration and scan metrics
- Program names and source code
- Active faults and diagnostics
- Connected protocol drivers

The AI responds with structured output:

```json
{
    "message": "Here's a PID controller with anti-windup clamping...",
    "code": "FUNCTION_BLOCK FB_PID\nVAR_INPUT\n  ...\nEND_FUNCTION_BLOCK",
    "hmi": "<div class=\"pid-panel\">...</div>",
    "flow": null
}
```

| Response Field | Type | Description |
|----------------|------|-------------|
| `message` | STRING | Natural language explanation |
| `code` | STRING | IEC 61131-3 Structured Text (ready to deploy) |
| `hmi` | STRING | HTML + Vue.js (ready for HMI builder) |
| `flow` | STRING | Node-RED JSON (importable flow) |

### 6.3 Control Mode (Agent)

Control mode gives the AI direct access to the runtime through tool calls. The AI can read variables, write outputs, start/stop tasks, deploy code, and run diagnostics autonomously.

```
POST /api/ai/control
{
    "message": "The heater is overshooting. Diagnose and fix it.",
    "allow_writes": true,
    "allow_deploy": true
}
```

Available tool calls in control mode:

| Tool | Description |
|------|-------------|
| `read_variable(name)` | Read any variable value |
| `write_variable(name, value)` | Write a variable (requires `allow_writes`) |
| `start_task(name)` | Start a stopped task |
| `stop_task(name)` | Stop a running task |
| `deploy_program(name, code)` | Compile and deploy ST code (requires `allow_deploy`) |
| `get_diagnostics()` | Full runtime diagnostic snapshot |
| `get_faults()` | Active fault list |
| `list_variables(filter)` | Search variables by name pattern |

> **Safety:** Control mode requires explicit `allow_writes` and `allow_deploy` flags. Without them, the AI can only observe. This prevents accidental writes to live outputs from a casual chat prompt.

### 6.4 Example: AI-Assisted Troubleshooting

```
POST /api/ai/control
{
    "message": "Check the Modbus connection to the VFD and report its status",
    "allow_writes": false,
    "allow_deploy": false
}
```

The AI will autonomously:

1. Call `list_variables('*modbus*')` to find Modbus-related tags
2. Call `read_variable('modbus_vfd_connected')` to check connection state
3. Call `get_diagnostics()` to review Modbus driver stats
4. Return a summary: *"The Modbus TCP connection to 10.0.0.50:502 is healthy. 12,847 successful polls, 0 timeouts in the last hour. VFD reports 1782 RPM, 4.2A draw."*

---

## 7. HMI Builder

GoPLC serves HMI pages as HTML + Vue.js applications with real-time variable binding over WebSocket. Pages are created, edited, and deployed entirely through the API.

### 7.1 API

```
GET    /api/hmi/pages           — List all HMI pages
POST   /api/hmi/pages           — Create new page
GET    /api/hmi/pages/{name}    — Get page source
PUT    /api/hmi/pages/{name}    — Update page
DELETE /api/hmi/pages/{name}    — Delete page
```

Pages are served at:

```
http://<host>:8300/hmi/{pageName}
```

### 7.2 Variable Binding

HMI pages connect to the GoPLC WebSocket for live variable updates. The Vue.js runtime handles subscription management automatically.

```html
<!-- Example HMI page with real-time binding -->
<div id="app">
    <h1>Temperature Control</h1>

    <!-- Read-only display -->
    <goplc-gauge
        variable="temperature_scaled"
        min="32" max="212"
        label="Process Temp"
        units="°F"
        :ranges="[
            {min: 32, max: 100, color: '#2196F3'},
            {min: 100, max: 150, color: '#4CAF50'},
            {min: 150, max: 180, color: '#FF9800'},
            {min: 180, max: 212, color: '#F44336'}
        ]">
    </goplc-gauge>

    <!-- Writable control -->
    <goplc-numeric
        variable="pid_params.setpoint"
        label="Setpoint"
        min="50" max="200" step="0.5"
        units="°F">
    </goplc-numeric>

    <!-- Boolean toggle -->
    <goplc-button
        variable="system_running"
        label="System Enable"
        type="toggle"
        on-color="#4CAF50"
        off-color="#F44336">
    </goplc-button>

    <!-- Trend chart -->
    <goplc-chart
        :variables="['temperature_scaled', 'heater_output']"
        :labels="['Temperature (°F)', 'Heater (%)']"
        time-range="300"
        height="300">
    </goplc-chart>

    <!-- Tank level visualization -->
    <goplc-tank
        variable="tank_level_pct"
        label="Feed Tank"
        min="0" max="100"
        units="%"
        low-alarm="10"
        high-alarm="90">
    </goplc-tank>
</div>
```

### 7.3 Built-in Components

| Component | Element | Description |
|-----------|---------|-------------|
| **Gauge** | `<goplc-gauge>` | Radial gauge with color ranges |
| **Button** | `<goplc-button>` | Momentary or toggle, writes BOOL |
| **Numeric Input** | `<goplc-numeric>` | Number entry with min/max/step, writes REAL/INT |
| **Chart** | `<goplc-chart>` | Time-series trend, multiple variables |
| **Tank** | `<goplc-tank>` | Vertical tank level with alarm bands |
| **Text** | `<goplc-text>` | Formatted text display, reads any variable |
| **LED** | `<goplc-led>` | Status indicator, reads BOOL |
| **Slider** | `<goplc-slider>` | Horizontal/vertical range input |

All components automatically subscribe to their bound variable via WebSocket. Write-capable components send updates through the REST API on user interaction.

---

## 8. Project Files (.goplc)

A `.goplc` file is a JSON document (schema version 1.7) that contains the entire project state. It is the unit of portability — download from one runtime, upload to another.

### 8.1 Structure

```json
{
    "version": "1.7",
    "metadata": {
        "name": "TemperatureControl",
        "description": "PID-based temperature control system",
        "author": "jbelcher",
        "created": "2026-04-01T10:00:00Z",
        "modified": "2026-04-03T14:30:00Z",
        "goplc_version": "1.0.520"
    },
    "programs": [
        {
            "name": "POU_Control",
            "type": "PROGRAM",
            "source": "PROGRAM POU_Control\nVAR\n  ...\nEND_PROGRAM"
        },
        {
            "name": "FB_PID",
            "type": "FUNCTION_BLOCK",
            "source": "FUNCTION_BLOCK FB_PID\n  ..."
        },
        {
            "name": "GVL_Shared",
            "type": "GVL",
            "source": "VAR_GLOBAL\n  ..."
        }
    ],
    "tasks": [
        {
            "name": "MainTask",
            "type": "periodic",
            "priority": 10,
            "scan_time_ms": 100,
            "programs": ["POU_Control"],
            "watchdog_ms": 500,
            "watchdog_fault": true,
            "watchdog_halt": false,
            "cpu_affinity": -1
        }
    ],
    "io_mapping": {
        "modbus_tcp": [ ... ],
        "opcua": [ ... ]
    },
    "protocols": {
        "modbus_tcp": { "host": "10.0.0.50", "port": 502 },
        "mqtt": { "broker": "tcp://10.0.0.144:1883" }
    },
    "hmi_pages": [
        {
            "name": "overview",
            "title": "System Overview",
            "html": "<div id=\"app\">...</div>"
        }
    ],
    "snapshot": {
        "variables": {
            "temperature_scaled": 72.3,
            "heater_output": 0.0,
            "system_running": false
        }
    }
}
```

### 8.2 API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/runtime/download` | GET | Download current project as `.goplc` file |
| `/api/runtime/upload` | POST | Upload and apply a `.goplc` file (replaces current project) |
| `/api/snapshots` | GET | List all saved snapshots |
| `/api/snapshots` | POST | Create a new snapshot of current state |
| `/api/snapshots/{id}/restore` | POST | Restore project from a snapshot |

### 8.3 Snapshots

Snapshots capture the full project state at a point in time — programs, tasks, variables, HMI pages, and configuration. They are stored on the runtime and can be restored instantly.

```
POST /api/snapshots
{ "name": "pre-tuning", "description": "Before PID parameter changes" }

Response:
{ "id": "snap_20260403_143000", "name": "pre-tuning", "created": "2026-04-03T14:30:00Z" }
```

```
POST /api/snapshots/snap_20260403_143000/restore
```

> **Upload Behavior:** Uploading a `.goplc` file replaces the entire project — programs, tasks, and configuration. Running tasks are stopped, the new project is applied, and tasks are restarted. Variable values from the `snapshot` section are restored if present.

---

## 9. Variable Access

Variables are the shared data layer in GoPLC. Every variable declared in a program, function block, or GVL is accessible through the API and WebSocket for reading, writing, and subscribing.

### 9.1 REST API

```
GET  /api/variables/{name}       — Read single variable
PUT  /api/variables/{name}       — Write single variable
POST /api/variables/bulk         — Read/write multiple variables
GET  /api/variables              — List all variables (with optional filter)
```

#### Read

```
GET /api/variables/temperature_scaled

Response:
{ "name": "temperature_scaled", "type": "REAL", "value": 122.5, "scope": "global" }
```

#### Write

```
PUT /api/variables/pid_params.setpoint
{ "value": 85.0 }
```

#### Bulk Operations

```
POST /api/variables/bulk
{
    "read": ["temperature_scaled", "heater_output", "system_running"],
    "write": {
        "pid_params.setpoint": 85.0,
        "system_running": true
    }
}

Response:
{
    "values": {
        "temperature_scaled": 122.5,
        "heater_output": 45.3,
        "system_running": true
    },
    "written": ["pid_params.setpoint", "system_running"]
}
```

### 9.2 WebSocket Subscription

Connect to `ws://<host>:8300/ws` and subscribe to variables for real-time push updates:

```json
{"action": "subscribe", "variables": ["temperature_scaled", "heater_output"]}
```

The server pushes updates on every scan:

```json
{"variable": "temperature_scaled", "value": 123.1, "timestamp": 1743700200000}
{"variable": "heater_output", "value": 46.7, "timestamp": 1743700200000}
```

Unsubscribe:

```json
{"action": "unsubscribe", "variables": ["heater_output"]}
```

### 9.3 Example: External System Reading Variables

```iecst
(* Variables defined in ST are automatically exposed via API *)
VAR_GLOBAL
    tank_level_pct : REAL;      (* GET /api/variables/tank_level_pct *)
    pump_running : BOOL;        (* GET /api/variables/pump_running *)
    batch_count : DINT;         (* GET /api/variables/batch_count *)
    recipe_name : STRING;       (* GET /api/variables/recipe_name *)
END_VAR
```

Any external system — Node-RED, Grafana, a Python script, a mobile app — can read and write these variables through the REST API or WebSocket without any additional configuration.

---

## 10. Configuration Wizard

The configuration wizard provides guided setup flows for common GoPLC configurations. It supports static forms, AI-assisted setup, and hardware manifest deployment.

### 10.1 API

```
GET  /api/wizard/topics         — List available wizard topics
POST /api/wizard/apply          — Apply a wizard configuration
```

### 10.2 Topics

```
GET /api/wizard/topics

Response:
[
    {"id": "modbus_tcp", "name": "Modbus TCP Client", "category": "protocols"},
    {"id": "modbus_rtu", "name": "Modbus RTU Serial", "category": "protocols"},
    {"id": "opcua_client", "name": "OPC UA Client", "category": "protocols"},
    {"id": "mqtt_publish", "name": "MQTT Publisher", "category": "protocols"},
    {"id": "pid_loop", "name": "PID Control Loop", "category": "control"},
    {"id": "hmi_basic", "name": "Basic HMI Dashboard", "category": "hmi"},
    {"id": "data_logger", "name": "Data Logger", "category": "logging"},
    {"id": "hardware_manifest", "name": "Hardware Manifest", "category": "system"}
]
```

### 10.3 Static Form Wizard

Each wizard topic defines a form schema with fields, defaults, and validation rules. The IDE renders the form and submits the result:

```
POST /api/wizard/apply
{
    "topic": "modbus_tcp",
    "config": {
        "host": "10.0.0.50",
        "port": 502,
        "unit_id": 1,
        "scan_rate_ms": 1000,
        "registers": [
            {"name": "vfd_speed", "address": 40001, "type": "HOLDING", "data_type": "INT"},
            {"name": "vfd_current", "address": 40002, "type": "HOLDING", "data_type": "REAL"}
        ]
    }
}
```

The wizard generates: ST program, GVL, task configuration, and I/O mapping — then deploys them to the runtime.

### 10.4 AI-Assisted Setup

When the AI assistant is configured, the wizard can use it to generate configurations from natural language:

```
POST /api/wizard/apply
{
    "topic": "pid_loop",
    "ai_prompt": "I need a PID loop to control a boiler temperature. The thermocouple is on Modbus register 40001, the control valve is on register 40010. Target is 180°F."
}
```

The AI generates all necessary programs, variables, task configuration, and HMI page — then passes them through the wizard's validation pipeline before deploying.

### 10.5 Hardware Manifest

The hardware manifest wizard deploys a complete project for a specific hardware configuration:

```
POST /api/wizard/apply
{
    "topic": "hardware_manifest",
    "manifest": {
        "io_modules": [
            {"type": "modbus_tcp", "host": "10.0.0.50", "model": "ABB_ACS580"},
            {"type": "p2", "port": "/dev/ttyUSB2", "servos": 8}
        ],
        "protocols": ["mqtt", "influxdb"],
        "hmi": true
    }
}
```

---

## 11. Protocol Analyzer

GoPLC includes a built-in packet capture and analysis engine for industrial protocols. Captures are performed in ST code and can be exported to standard PCAP format for analysis in Wireshark.

### 11.1 ST Functions

| Function | Description |
|----------|-------------|
| `AN_INIT(name, protocol)` | Initialize analyzer for a protocol (`'modbus'`, `'opcua'`, `'s7'`, `'fins'`, etc.) |
| `AN_START(name)` | Begin capturing packets |
| `AN_STOP(name)` | Stop capturing |
| `AN_RECORD(name)` | Record a single snapshot (manual trigger) |
| `AN_FILTER(name, filter)` | Set capture filter expression |
| `AN_DECODE(name)` | Decode captured packets into human-readable format |
| `AN_EXPORT_PCAP(name, path)` | Export capture buffer to PCAP file |

### 11.2 Example: Capture Modbus Traffic

```iecst
PROGRAM POU_Analyzer
VAR
    init_done : BOOL := FALSE;
    capture_active : BOOL := FALSE;
    capture_timer : DINT := 0;
    decoded : STRING;
END_VAR

IF NOT init_done THEN
    (* Initialize analyzer for Modbus TCP *)
    AN_INIT('mb_cap', 'modbus');

    (* Filter: only capture traffic to/from the VFD *)
    AN_FILTER('mb_cap', 'host=10.0.0.50 AND port=502');

    init_done := TRUE;
END_IF;

(* Start/stop capture from HMI button *)
IF capture_active AND capture_timer = 0 THEN
    AN_START('mb_cap');
    DEBUG_INFO('Modbus capture started');
END_IF;

IF capture_active THEN
    capture_timer := capture_timer + 1;
END_IF;

(* Auto-stop after 3000 scans (~5 minutes at 100ms) *)
IF capture_timer >= 3000 THEN
    AN_STOP('mb_cap');
    decoded := AN_DECODE('mb_cap');
    AN_EXPORT_PCAP('mb_cap', '/tmp/modbus_capture.pcap');
    DEBUG_INFO('Capture exported to /tmp/modbus_capture.pcap');
    capture_active := FALSE;
    capture_timer := 0;
END_IF;
END_PROGRAM
```

### 11.3 Filter Syntax

Filters use a simple expression syntax:

| Filter | Example | Description |
|--------|---------|-------------|
| `host` | `host=10.0.0.50` | Match source or destination IP |
| `port` | `port=502` | Match source or destination port |
| `func` | `func=3` | Match Modbus function code |
| `unit` | `unit=1` | Match Modbus unit ID |
| `AND` / `OR` | `host=10.0.0.50 AND func=3` | Combine filters |

### 11.4 PCAP Export

The exported `.pcap` file is compatible with Wireshark, `tcpdump`, and other standard packet analysis tools. Each captured frame includes the full protocol payload with timestamps.

```
GET /api/analyzer/{name}/download    — Download PCAP via browser
GET /api/analyzer/{name}/stats       — Capture statistics
```

---

## 12. Store-and-Forward

The store-and-forward subsystem provides an offline message queue for unreliable network connections. Messages are persisted locally and forwarded when connectivity is restored — no data loss on network interruptions.

### 12.1 ST Functions

| Function | Description |
|----------|-------------|
| `SF_INIT(name, path)` | Initialize a store-and-forward queue with local storage path |
| `SF_STORE(name, topic, payload)` | Queue a text message |
| `SF_STORE_JSON(name, topic, json)` | Queue a JSON message |
| `SF_FORWARD(name, target)` | Set forwarding target (`'mqtt'`, `'influx'`, `'http'`, URL) |
| `SF_ONLINE(name)` | Returns TRUE if the forwarding target is reachable |
| `SF_STATS(name)` | Returns JSON string with queue statistics |
| `SF_COUNT(name)` | Returns number of messages currently queued |

### 12.2 Example: Resilient MQTT Telemetry

```iecst
PROGRAM POU_Telemetry
VAR
    init_done : BOOL := FALSE;
    cycle_count : DINT := 0;
    queue_depth : DINT;
    is_online : BOOL;
    payload : STRING;
END_VAR

IF NOT init_done THEN
    (* Initialize queue with local SQLite storage *)
    SF_INIT('telemetry', '/var/lib/goplc/telemetry_queue.db');

    (* Forward to MQTT when online *)
    SF_FORWARD('telemetry', 'mqtt');

    DEBUG_INFO('Store-and-forward initialized');
    init_done := TRUE;
END_IF;

cycle_count := cycle_count + 1;

(* Publish telemetry every 10 seconds (100 scans at 100ms) *)
IF (cycle_count MOD 100) = 0 THEN
    payload := CONCAT(
        '{"temp":', REAL_TO_STRING(temperature_scaled),
        ',"heater":', REAL_TO_STRING(heater_output),
        ',"running":', BOOL_TO_STRING(system_running),
        '}'
    );

    SF_STORE_JSON('telemetry', 'plant/zone1/telemetry', payload);
END_IF;

(* Monitor queue health *)
is_online := SF_ONLINE('telemetry');
queue_depth := SF_COUNT('telemetry');

IF queue_depth > 1000 THEN
    DEBUG_WARN(CONCAT('Telemetry queue depth: ', DINT_TO_STRING(queue_depth)));
END_IF;
END_PROGRAM
```

### 12.3 Forwarding Targets

| Target | SF_FORWARD Syntax | Description |
|--------|-------------------|-------------|
| **MQTT** | `'mqtt'` | Uses the runtime's configured MQTT connection |
| **InfluxDB** | `'influx'` | Uses the runtime's configured InfluxDB connection |
| **HTTP POST** | `'http://host:port/path'` | Forwards as HTTP POST with JSON body |
| **Custom** | `'custom:handler_name'` | Routes to a user-defined forwarding handler |

### 12.4 Queue Behavior

- **Persistence:** Messages are stored in a local SQLite database. The queue survives runtime restarts.
- **Ordering:** FIFO — messages are forwarded in the order they were stored.
- **Retry:** Failed forwards are retried with exponential backoff (1s, 2s, 4s, ... up to 60s).
- **Capacity:** Limited only by disk space. The `SF_STATS` function reports storage usage.
- **Backpressure:** When the queue exceeds a configurable threshold, `SF_STORE` returns FALSE and the calling program can decide whether to drop or block.

### 12.5 Queue Statistics

```iecst
stats := SF_STATS('telemetry');
(* Returns: {"queued":42,"forwarded":12847,"failed":3,
             "oldest_age_s":126,"storage_mb":1.2,"target":"mqtt",
             "online":false} *)
```

---

*GoPLC v1.0.520 | 253 REST endpoints | WebSocket real-time | IEC 61131-3 Structured Text*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
