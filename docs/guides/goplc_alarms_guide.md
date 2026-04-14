# GoPLC Alarm Management (ISA-18.2)

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.594

---

GoPLC ships an ISA-18.2 alarm management engine that runs beside the scan loop. You declare alarms in YAML or create them at runtime from ST, the engine evaluates the tag condition on its own cadence (default 100 ms), drives each alarm through a four-state machine, and emits every transition onto the event bus as `alarm.active` / `alarm.clear` / `alarm.ack`. Because transitions are bus events, you get Slack, Teams, PagerDuty, MQTT fan-out, SQLite history, and the live WebSocket stream for free — the alarm engine reuses the same pipeline documented in the events guide. Eight alarm types (HI / LO / HIHI / LOLO / DEV / ROC / BOOL / BAND), four priorities, deadband, delay, shelving with expiry, and an auth-aware acknowledgment path round out the feature.

## 1. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime                                               │
│                                                              │
│  ┌────────────────────┐     ┌──────────────────────────────┐ │
│  │  Scan loop         │     │  YAML config                 │ │
│  │  writes tag values ├────►│  alarms.definitions[]        │ │
│  │  into executor     │     │  loaded at boot              │ │
│  └─────────┬──────────┘     └──────────────┬───────────────┘ │
│            │                               │                 │
│            │ GetVariable(tag)              │ CreateAlarm()   │
│            ▼                               ▼                 │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                 Alarm Engine (pkg/alarms)                ││
│  │                                                          ││
│  │    eval ticker (evaluation_interval_ms, default 100 ms)  ││
│  │             │                                            ││
│  │             ▼                                            ││
│  │    for each alarm:                                       ││
│  │      read tag → check condition → deadband → delay       ││
│  │             │                                            ││
│  │             ▼                                            ││
│  │    ISA-18.2 state machine                                ││
│  │    NORM / ACTIVE_UNACK / ACTIVE_ACK / CLEAR_UNACK        ││
│  │             │                                            ││
│  │             ▼ on transition                              ││
│  │    events.Emit("alarm.active"|"clear"|"ack", ...)        ││
│  │    alarm_history.INSERT (SQLite, indexed user+note)      ││
│  └────────────────────────────┬─────────────────────────────┘│
│                               │                              │
│                               ▼                              │
│                      pkg/events.Bus                          │
│                               │                              │
│              ┌────────────────┼─────────────┬─────────────┐  │
│              │                │             │             │  │
│         Webhook            MQTT         SQLite        WebSocket│
│         (Slack/Teams/      goplc/       events.db    /api/events│
│          PagerDuty/         events/                  /stream  │
│          generic)           alarm.*                           │
└──────────────────────────────────────────────────────────────┘
```

The alarm engine is a state machine + a bus emitter. Notification routing, MQTT publishing, HMI banner streaming, and the webhook retry / dedup / HMAC / rate-limit pipeline are inherited from `pkg/events/` — the alarm engine does not reimplement any of that. Authoritative alarm history for audit and compliance queries is kept in a dedicated `alarm_history` SQLite table with indexed `user` and `note` columns, separate from the bus's `events.db` store.

## 2. ISA-18.2 State Machine

Every alarm is always in exactly one of four states:

| State | Meaning | ISA-18.2 label |
|-------|---------|----------------|
| `NORM` | Condition clear, acknowledged (or never tripped) | Normal |
| `ACTIVE_UNACK` | Condition currently true, operator has not acknowledged | Alarm |
| `ACTIVE_ACK` | Condition currently true, operator acknowledged — still active | Acknowledged |
| `CLEAR_UNACK` | Condition returned to clear, but operator never acknowledged the original trip | Return-to-normal |

```
                 ┌──────────┐
        ┌───────►│  NORM    │◄────────────┐
        │        └────┬─────┘             │ condition clears
        │             │ condition true    │ (already acked)
        │             ▼                   │
        │   ┌──────────────────┐    ┌─────┴──────────┐
        │   │  ACTIVE_UNACK    │───►│  ACTIVE_ACK    │
        │   └────┬─────────────┘ ack└─────┬──────────┘
        │        │ condition clears       │ condition clears
        │        ▼                        ▼
        │   ┌──────────────────┐       NORM
        └───│  CLEAR_UNACK     │──ack─────►
            └──────────────────┘
```

Two consequences matter in practice:

- **An alarm that tripped and cleared while nobody was looking still demands acknowledgment.** `CLEAR_UNACK` exists precisely so that a momentary excursion doesn't silently vanish from the operator's attention.
- **`ALARM_IS_ACTIVE` returns TRUE for any non-`NORM` state**, not just `ACTIVE_UNACK`. An acknowledged-but-not-yet-cleared alarm (`ACTIVE_ACK`) is still active for banner and HMI purposes; a cleared-but-not-yet-acked alarm (`CLEAR_UNACK`) is still active until someone clears it from the alarm list.

Shelving suppresses an alarm regardless of state. A shelved alarm does not evaluate its condition and does not emit events until unshelved or until the shelve expiry elapses.

## 3. Alarm Types

| Type | Trigger | Setpoint fields | Use case |
|------|---------|-----------------|----------|
| `HI` | `value > setpoint` | `setpoint` | High temperature, over-pressure, upper limit |
| `LO` | `value < setpoint` | `setpoint` | Low level, under-pressure, lower limit |
| `HIHI` | `value > setpoint` (critical) | `setpoint` | Emergency high — typically priority 1, second alarm above `HI` |
| `LOLO` | `value < setpoint` (critical) | `setpoint` | Emergency low — typically priority 1, second alarm below `LO` |
| `DEV` | `abs(value - setpoint) > deadband` | `setpoint`, `deadband` | PID deviation from target |
| `ROC` | rate of change > threshold per second | `setpoint` (as rate) | Rapid change detection — runaway process |
| `BOOL` | `value == TRUE` | (none) | Digital fault bits, trip flags, pump-running inverted for fault |
| `BAND` | `value < setpoint_lo OR value > setpoint` | `setpoint_lo` (low), `setpoint` (high), `deadband` | Out-of-range for a tolerance window |

`HIHI` and `LOLO` are not separate state machines — they are ordinary `HI` / `LO` alarms with a more aggressive setpoint and a higher priority. You typically create both for the same tag (`high_temp` at 80 °C priority 3, `hihi_temp` at 95 °C priority 1) so the operator gets an early warning before the emergency trip.

Type strings are case-insensitive in both YAML and ST calls; the engine uppercases them internally. Unrecognized types are rejected at creation time.

## 4. Priority Levels

| Priority | Name | Convention | Behavior |
|----------|------|------------|----------|
| 1 | critical | red | Emergency — must be acknowledged by an operator, usually routed to a pager. Cannot be auto-acknowledged. |
| 2 | high | orange | Notification within seconds. Routes to Slack / Teams / operator console. |
| 3 | medium | yellow | Logged and banner-displayed, no push notification by default. |
| 4 | low | blue | Informational. Auto-acknowledge is available via `auto_ack_priority`. |

The engine does not itself choose which priorities get notified — that's a bus-level decision configured per webhook (see the events guide's §6 Filtering). A typical setup is a PagerDuty webhook with `min_severity: critical`, a Slack webhook with `min_severity: warning`, and an MQTT fan-out of everything.

Priority is a `DINT` field on every alarm definition. It defaults to `3` (medium) if unset. The `auto_ack_priority` config knob suppresses the `ACTIVE_UNACK` state for alarms at or below (numerically greater than) that priority — a value of `4` auto-acks all low-priority alarms, `0` disables auto-ack entirely.

## 5. Configuration

The alarm engine is driven by the `alarms:` block in your GoPLC YAML config. Nothing in the engine turns on until `enabled: true`.

```yaml
alarms:
  enabled: true
  history_db: "data/alarms.db"         # SQLite path for alarm_definitions + alarm_history
  max_history_days: 365                 # auto-prune older rows (default: 365)
  evaluation_interval_ms: 100           # how often the eval loop runs (default: 100)
  default_deadband: 1.0                 # applied when an alarm has no deadband set
  auto_ack_priority: 4                  # alarms with priority >= 4 auto-acknowledge (0 disables)

  # Declarative alarm definitions — alternative to ALARM_CREATE from ST.
  # These load at boot. You can still create/delete alarms at runtime from ST or the REST API.
  definitions:
    - name: "high_temp"
      tag: "main_task.boiler_temp_c"
      type: HI
      setpoint: 80.0
      deadband: 1.0                     # trip at 80.0, clear at 79.0
      priority: 3                       # medium
      delay_ms: 2000                    # must be >80.0 for 2 seconds before tripping

    - name: "hihi_temp"
      tag: "main_task.boiler_temp_c"
      type: HI
      setpoint: 95.0
      priority: 1                       # critical
      delay_ms: 500

    - name: "pump_fault"
      tag: "main_task.pump_fault_bit"
      type: BOOL
      priority: 1

    - name: "pressure_band"
      tag: "main_task.header_pressure"
      type: BAND
      setpoint_lo: 3.2                  # trip if < 3.2
      setpoint: 4.8                     # trip if > 4.8
      deadband: 0.1
      priority: 2
```

All time fields are milliseconds. `tag` is the lowercase scoped variable name — the same string you would pass to `GET /api/variables/:name`. The scheduler normalizes variable names to lowercase internally, so `MainTask.BoilerTempC` and `maintask.boilertempc` resolve to the same tag, but the lowercase form is the one the alarm engine logs and returns in API responses.

Changing `alarms.definitions` and reloading the config rebuilds the declarative definitions only — runtime-created alarms (from ST or POST /api/alarms) are preserved. If you want to remove a declarative alarm, delete it from the config *and* either restart the engine or call `ALARM_DELETE` / `DELETE /api/alarms/:name`.

## 6. Deadband, Delay, and Chatter Suppression

Three independent mechanisms keep a noisy signal from flooding the alarm list with repeat transitions:

**Deadband** changes the clear threshold. A `HI` alarm with `setpoint: 80, deadband: 1.0` trips at `value > 80` and clears at `value < 79`. Without a deadband, a value oscillating within a sensor tick of 80.0 would flap every scan. The default deadband from `default_deadband` is applied when a per-alarm deadband is zero.

**Delay** (`delay_ms`) forces the condition to hold continuously for the specified duration before the alarm transitions out of `NORM`. A `delay_ms: 5000` on a `HI` alarm requires the value to stay above the setpoint for five seconds — any dip below the setpoint in that window resets the delay timer. Delay is applied on the trip edge only; clears are immediate.

**Bus dedup bypass.** The event bus's dedup window (default 1 second, configurable) would coalesce back-to-back `alarm.active` emissions for the same alarm if the engine emitted them with an identical `(type, source)` key. The engine sidesteps this by putting a monotonic sequence counter into the event source: `alarm:high_temp:seq=42`, `alarm:high_temp:seq=43`, … This makes each transition a distinct key so the bus dedup can still catch true duplicates from a code bug while letting legitimate re-trips through.

If despite all three you still see an alarm chattering, the root cause is almost always sensor noise below the deadband. Widen the deadband first, lengthen the delay second, and bump the evaluation interval last (slower eval = lower CPU but also slower first-detection of real trips).

## 7. ST Functions

Nineteen builtins let ST code create, manage, query, and retrieve alarm state. They all return quickly — the engine's eval loop runs on its own goroutine, so these calls only touch the alarm registry map (`RLock` for reads, `Lock` for writes), never blocking on I/O. All functions return `FALSE` / `0` / `'[]'` silently if the alarm engine isn't enabled, so guard-free usage is safe.

### 7.1 Creation

#### `ALARM_CREATE(name, tag, type, setpoint, deadband, priority, delay_ms) : BOOL`

```iec
(* High-temperature alarm, priority 3, 2 s delay, 1 °C deadband *)
ok := ALARM_CREATE('high_temp', 'main_task.boiler_temp_c', 'HI',
                   80.0, 1.0, 3, 2000);

(* Minimum args — type + setpoint only *)
ALARM_CREATE('low_level', 'main_task.tank_level', 'LO', 10.0);
```

Creates a scalar alarm (HI, LO, HIHI, LOLO, DEV, ROC). `deadband`, `priority`, and `delay_ms` are optional; omitted values default to `0`, `3` (medium), and `0`. Returns `TRUE` if the alarm was created, `FALSE` if the name already exists or the engine is disabled.

Create alarms once per name — typically in a "first scan" guard. Calling `ALARM_CREATE` with a name that already exists returns `FALSE`; it does not update the existing alarm. To change parameters, delete and recreate:

```iec
IF NOT alarm_created THEN
    ALARM_DELETE('high_temp');
    ALARM_CREATE('high_temp', 'main_task.boiler_temp_c', 'HI', 80.0, 1.0, 3, 2000);
    alarm_created := TRUE;
END_IF;
```

#### `ALARM_CREATE_BOOL(name, tag, priority) : BOOL`

```iec
ALARM_CREATE_BOOL('pump_fault', 'main_task.pump_fault_bit', 1);
```

Creates a digital alarm that trips when the tag is `TRUE`. `priority` is optional and defaults to `3`. For the inverse ("trip when FALSE"), mirror the bit into a BOOL variable in your scan and alarm on the mirror.

#### `ALARM_CREATE_BAND(name, tag, lo, hi, deadband, priority) : BOOL`

```iec
ALARM_CREATE_BAND('pressure_band', 'main_task.header_pressure',
                  3.2, 4.8, 0.1, 2);
```

Creates a band alarm that trips when the value is outside `[lo, hi]`. `deadband` and `priority` are optional.

#### `ALARM_DELETE(name) : BOOL`

```iec
ALARM_DELETE('high_temp');
```

Removes the alarm from the registry and deletes its row from `alarm_definitions`. History rows in `alarm_history` are preserved — deleting an alarm does not wipe its audit trail.

### 7.2 Management

#### `ALARM_ACK(name) : BOOL`

```iec
IF op_pressed_ack_button THEN
    ALARM_ACK('high_temp');
END_IF;
```

Acknowledges a single alarm. Transitions `ACTIVE_UNACK` → `ACTIVE_ACK` or `CLEAR_UNACK` → `NORM`. The user field in the alarm history row is `'st_program'` when acked from ST; API acks record the authenticated username.

#### `ALARM_ACK_ALL() : DINT`

```iec
acked := ALARM_ACK_ALL();   (* returns count of alarms transitioned *)
```

Acknowledges every unacknowledged alarm. Returns the number of alarms that changed state.

#### `ALARM_SHELVE(name, duration_s) : BOOL`

```iec
(* Suppress during known maintenance window — 2 hours *)
ALARM_SHELVE('compressor_vibration', 7200);
```

Shelves an alarm for `duration_s` seconds. A shelved alarm is not evaluated and emits no events. When the expiry elapses, the next eval cycle automatically unshelves it. Shelving resets condition tracking — a shelved alarm that unshelves onto a still-active condition re-tests delay from scratch.

#### `ALARM_UNSHELVE(name) : BOOL`

```iec
ALARM_UNSHELVE('compressor_vibration');
```

Explicit unshelve. Same effect as waiting for the expiry.

#### `ALARM_ENABLE(name) : BOOL` / `ALARM_DISABLE(name) : BOOL`

```iec
ALARM_DISABLE('hihi_temp');   (* temporarily — maintenance override *)
(* ... later ... *)
ALARM_ENABLE('hihi_temp');
```

Enable is the default state for a newly-created alarm. Disabled alarms are preserved in `alarm_definitions` but not evaluated; they emit no events until re-enabled. Use disable for long-term overrides and shelve for bounded maintenance windows.

### 7.3 Status queries

```iec
VAR
    state       : DINT;
    is_active   : BOOL;
    is_shelved  : BOOL;
    priority    : DINT;
    active_n    : DINT;
    unacked_n   : DINT;
END_VAR

state      := ALARM_STATE('high_temp');
    (* 0 = NORM, 1 = ACTIVE_UNACK, 2 = ACTIVE_ACK, 3 = CLEAR_UNACK, -1 = unknown *)
is_active  := ALARM_IS_ACTIVE('high_temp');    (* TRUE for any non-NORM state unless shelved *)
is_shelved := ALARM_IS_SHELVED('high_temp');
priority   := ALARM_PRIORITY('high_temp');     (* 1..4, or 0 if not found *)
active_n   := ALARM_ACTIVE_COUNT();
unacked_n  := ALARM_UNACK_COUNT();
```

`ALARM_STATE` returns `-1` when the alarm does not exist, so you can distinguish "alarm not found" from "alarm is in NORM". `ALARM_PRIORITY` returns `0` for unknown alarms.

### 7.4 Information / history

```iec
VAR
    active_json  : STRING;
    shelved_json : STRING;
    history_json : STRING;
END_VAR

active_json  := ALARM_LIST_ACTIVE();            (* JSON array of ActiveAlarm records *)
shelved_json := ALARM_LIST_SHELVED();
history_json := ALARM_HISTORY('high_temp', 20); (* last 20 transitions *)
```

All three return JSON strings. `ALARM_HISTORY` with an empty name (`''`) returns history across every alarm.

You can feed these straight into the JSON parser if you need to drive a decision from the current alarm list:

```iec
count := JSON_ARRAY_LENGTH(ALARM_LIST_ACTIVE());
IF count > 5 THEN
    EVENT_EMIT('control.shed_load', 'warning',
               'More than 5 active alarms — shedding non-critical load');
END_IF;
```

## 8. REST API

Fifteen endpoints, all under `/api/alarms/*`. All return JSON. `GET` endpoints require read permission; mutating endpoints require `alarms:admin` or `alarms:ack` depending on the action, once RBAC is enabled (see the auth guide).

### 8.1 Listing

```bash
# Every alarm, any state
curl http://host:port/api/alarms

# Only alarms in a non-NORM state (ACTIVE_UNACK, ACTIVE_ACK, CLEAR_UNACK)
curl http://host:port/api/alarms/active

# Unacknowledged (ACTIVE_UNACK + CLEAR_UNACK)
curl http://host:port/api/alarms/unacknowledged

# Currently shelved
curl http://host:port/api/alarms/shelved

# Counts by state and priority
curl http://host:port/api/alarms/summary

# Detail on one alarm
curl http://host:port/api/alarms/high_temp
```

Response shape for the listing endpoints:

```json
{
  "count": 2,
  "alarms": [
    {
      "name": "high_temp",
      "tag": "main_task.boiler_temp_c",
      "type": "HI",
      "state": "ACTIVE_UNACK",
      "priority": 3,
      "priority_name": "medium",
      "value": 82.4,
      "setpoint": 80.0,
      "last_transition": "2026-04-13T09:14:22Z",
      "shelved": false,
      "acked_by": ""
    },
    {
      "name": "hihi_temp",
      "tag": "main_task.boiler_temp_c",
      "type": "HI",
      "state": "NORM",
      "priority": 1,
      "priority_name": "critical",
      "value": 82.4,
      "setpoint": 95.0,
      "last_transition": "",
      "shelved": false,
      "acked_by": ""
    }
  ]
}
```

### 8.2 Create / delete

```bash
# Create from JSON — alternative to YAML definitions or ST ALARM_CREATE
curl -X POST http://host:port/api/alarms \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "compressor_fault",
    "tag": "main_task.compressor_running",
    "type": "BOOL",
    "priority": 2
  }'

# Delete
curl -X DELETE http://host:port/api/alarms/compressor_fault
```

A create with a duplicate name returns `409 Conflict`. `name`, `tag`, and `type` are required; everything else is optional.

### 8.3 Acknowledge

```bash
# Single alarm with an operator note
curl -X POST http://host:port/api/alarms/high_temp/ack \
  -H 'Content-Type: application/json' \
  -d '{"note":"Checked — gauge drift, PM scheduled"}'

# Everything unacked, in one request
curl -X POST http://host:port/api/alarms/ack-all
```

The acknowledging user is taken from the auth context — when RBAC is enabled the username comes from the JWT subject. Without auth, the user field is empty. Both the user and the note are written to the indexed `alarm_history` columns.

### 8.4 Shelve / unshelve / enable / disable

```bash
# Shelve for 1 hour
curl -X POST http://host:port/api/alarms/compressor_vibration/shelve \
  -H 'Content-Type: application/json' \
  -d '{"duration_s":3600}'

curl -X POST http://host:port/api/alarms/compressor_vibration/unshelve

# Long-term override
curl -X POST http://host:port/api/alarms/hihi_temp/disable
curl -X POST http://host:port/api/alarms/hihi_temp/enable
```

Omitting `duration_s` on shelve shelves indefinitely (until explicit unshelve).

### 8.5 History

```bash
# Last 100 transitions for one alarm
curl 'http://host:port/api/alarms/history?name=high_temp&limit=100'

# All alarms, last 24 hours
curl 'http://host:port/api/alarms/history?start=2026-04-12T00:00:00Z&limit=500'
```

Query params: `name` (optional, empty = all alarms), `limit` (default 100), `start` and `end` (RFC3339). Response is a `history` array plus a `count`:

```json
{
  "count": 3,
  "history": [
    {
      "id": 417,
      "alarm_name": "high_temp",
      "timestamp": "2026-04-13T09:14:22Z",
      "prev_state": "NORM",
      "new_state": "ACTIVE_UNACK",
      "value": 82.4,
      "user": "",
      "note": ""
    },
    {
      "id": 418,
      "alarm_name": "high_temp",
      "timestamp": "2026-04-13T09:15:08Z",
      "prev_state": "ACTIVE_UNACK",
      "new_state": "ACTIVE_ACK",
      "value": 82.6,
      "user": "alice",
      "note": "Checked — gauge drift, PM scheduled"
    },
    {
      "id": 419,
      "alarm_name": "high_temp",
      "timestamp": "2026-04-13T09:22:41Z",
      "prev_state": "ACTIVE_ACK",
      "new_state": "NORM",
      "value": 79.8,
      "user": "",
      "note": ""
    }
  ]
}
```

## 9. Event Bus Integration

Every alarm state transition emits to the event bus. Subscribers (webhooks, MQTT, the WebSocket stream, the SQLite events log) pick them up with no alarm-specific code.

| Bus event type | Emitted on | Severity | Source |
|----------------|------------|----------|--------|
| `alarm.active` | `NORM` → `ACTIVE_UNACK` or `CLEAR_UNACK` → `ACTIVE_UNACK`, `ACTIVE_ACK` | `warning` | `alarm:<name>:seq=<n>` |
| `alarm.clear` | `ACTIVE_*` → `CLEAR_UNACK` or `ACTIVE_*` → `NORM` | `info` | `alarm:<name>:seq=<n>` |
| `alarm.ack` | `ALARM_ACK`, `ALARM_ACK_ALL`, `POST /api/alarms/:name/ack` | `info` | `alarm:<name>` |

The event `data` payload for `alarm.active` and `alarm.clear` contains the alarm name, tag, type, priority, current value, setpoint, and the previous/new state. `alarm.ack` includes the user and note.

Two consequences of piggybacking on the bus:

**All webhook format conversions apply.** Routing an alarm to Slack gets the events-guide Slack format (colored attachment, severity map), PagerDuty gets the `enqueue` format, Teams gets MessageCard. The alarm engine does not own any of those formats.

**Dedup bypass matters.** The bus's `(type, source)` dedup window would otherwise coalesce rapid re-trips. The alarm engine embeds a monotonic `seq=N` in the source precisely so every transition is a distinct key. True double-emits (same sequence) are still caught and suppressed.

Subscribe to every alarm from the command line for testing:

```bash
# All alarm events via the bus's built-in MQTT broker
mosquitto_sub -h 127.0.0.1 -p 1883 -t 'goplc/events/alarm.#' -v

# Or the WebSocket stream
wscat -c 'ws://host:port/api/events/stream'
```

To route only critical alarms to PagerDuty:

```yaml
events:
  enabled: true
  webhooks:
    - name: "pagerduty-critical"
      url: "https://events.pagerduty.com/v2/enqueue"
      format: "pagerduty"
      routing_key: "R0UTINGKEY..."
      event_types: ["alarm.active"]
      min_severity: "critical"
```

A priority-1 alarm is emitted at `warning` severity, not `critical`, because severity is a bus-level concept (info/warning/error/critical) and alarm priority is a display-and-routing concept (1-4). To map alarm priority onto bus severity, filter by `data.priority` at the receiver side, or use the `event_types` filter combined with a wildcard and a receiver that inspects the payload.

## 10. Recipes

### 10.1 First-scan alarm bootstrap

Alarms live in an in-memory registry at runtime and a `alarm_definitions` table on disk. Restarting the process reloads declarative definitions from YAML but does not restore ST-created alarms. The idiomatic pattern is a `once` guard at the top of your scan:

```iec
PROGRAM AlarmBootstrap
VAR
    alarms_ready : BOOL := FALSE;
END_VAR

    IF NOT alarms_ready THEN
        (* Scalar alarms *)
        ALARM_CREATE('high_temp',  'main_task.boiler_temp_c', 'HI',
                     80.0, 1.0, 3, 2000);
        ALARM_CREATE('hihi_temp',  'main_task.boiler_temp_c', 'HI',
                     95.0, 1.0, 1, 500);
        ALARM_CREATE('low_level',  'main_task.tank_level',    'LO',
                     10.0, 0.5, 2, 0);

        (* Digital alarms *)
        ALARM_CREATE_BOOL('pump_fault',   'main_task.pump_fault',   1);
        ALARM_CREATE_BOOL('estop_active', 'main_task.estop_bit',    1);

        (* Band alarm *)
        ALARM_CREATE_BAND('press_band', 'main_task.header_press',
                          3.2, 4.8, 0.1, 2);

        alarms_ready := TRUE;
    END_IF;
END_PROGRAM
```

For permanent alarms, prefer YAML declarative definitions in `alarms.definitions` — they reload on config change, they're versioned with the config, and they don't need a bootstrap program.

### 10.2 Maintenance shelving from a button

```iec
PROGRAM MaintenanceMode
VAR
    maint_button     : BOOL;         (* HMI pushbutton *)
    maint_prev       : BOOL;
    maint_duration_s : DINT := 3600; (* 1 hour default *)
END_VAR

    (* Rising-edge: shelve a set of alarms for the configured duration *)
    IF maint_button AND NOT maint_prev THEN
        ALARM_SHELVE('compressor_vibration', maint_duration_s);
        ALARM_SHELVE('motor_temp',           maint_duration_s);
        NOTIFY('ops-slack', 'Maintenance shelving engaged for 1 h');
    END_IF;
    maint_prev := maint_button;
END_PROGRAM
```

Shelving expiry is automatic — the next eval cycle after `ShelveExpiry` has passed will unshelve and resume evaluating. There's no need to arm a timer.

### 10.3 Trip counter + burst log on alarm activation

Use a latched bit to detect the rising edge from `NORM` into any active state, then increment a counter and push a burst of context onto the event bus:

```iec
PROGRAM HighTempMonitor
VAR
    was_active   : BOOL := FALSE;
    is_active    : BOOL := FALSE;
    trip_count   : DINT := 0;
END_VAR

    is_active := ALARM_IS_ACTIVE('high_temp');

    IF is_active AND NOT was_active THEN
        trip_count := trip_count + 1;
        EVENT_EMIT_DATA('alarm.context', 'warning',
            'high_temp tripped — trip 5-minute context below',
            '{"trip_count":0,"boiler_temp":0,"ambient":0,"burner_state":0}');
    END_IF;
    was_active := is_active;
END_PROGRAM
```

Pair this with an events-guide burst capture in YAML so the last 5 minutes of telemetry are automatically written to the historian whenever `alarm.active` fires:

```yaml
historian:
  enabled: true
  bursts:
    - trigger: "alarm.active"
      filter: "alarm:high_temp:*"
      tags: "main_task.*"
      duration_s: 300
      interval_ms: 200
```

### 10.4 Watchdog-style fault bit

ST's `TON` function block lets you build a "fault if X hasn't happened in N seconds" without touching the alarm engine directly — expose the fault bit as a variable, then point a `BOOL` alarm at it:

```iec
PROGRAM WatchdogHeartbeat
VAR
    heartbeat_in   : BOOL;       (* pulses once per second from the sensor *)
    heartbeat_prev : BOOL;
    missed_timer   : TON;
    sensor_fault   : BOOL;       (* alarm tag *)
END_VAR

    (* Reset the timer on every heartbeat edge *)
    missed_timer(IN := NOT heartbeat_in, PT := T#5S);
    sensor_fault := missed_timer.Q;
    heartbeat_prev := heartbeat_in;
END_PROGRAM
```

```yaml
alarms:
  definitions:
    - name: "sensor_watchdog"
      tag: "watchdog_heartbeat.sensor_fault"
      type: BOOL
      priority: 1
```

Five seconds with no heartbeat → `sensor_fault` goes `TRUE` → the `BOOL` alarm trips at priority 1 → the bus emits `alarm.active` → PagerDuty or Slack picks it up.

## 11. Performance Notes

The alarm engine's eval loop is a single goroutine that locks the registry once per tick, iterates every enabled alarm, reads the tag via the scheduler's `GetVariable` (read-locked, deep-copied), evaluates the condition, and writes back the updated instance state under a per-instance mutex. Event emission is non-blocking — the bus's per-subscriber channel buffers absorb bursts.

- **Per-tick cost is O(N)** in the number of enabled alarms. The scheduler's `GetVariable` is the dominant cost; condition checks are a single float compare plus deadband arithmetic.
- **100 alarms at 100 ms eval interval** costs low single-digit microseconds per tick on a modern Linux x86-64 host. Scaling is linear.
- **History writes are batched** through the same WAL-mode SQLite path as `pkg/events/store.go`. A burst of transitions in one tick produces one `INSERT` per transition, flushed on the next batch tick.
- **Shelved alarms are free** — the eval loop skips them before reading the tag.
- **Disabled alarms are also free** — same skip.
- **Bus fan-out cost is not in the alarm engine's budget** — it rides the events package's worker goroutines.

If you're running thousands of alarms and seeing scan jitter, the first thing to check is evaluation interval. Raising `evaluation_interval_ms` to 250 or 500 cuts CPU four- or five-fold at the cost of slower trip detection; for temperatures and pressures this is almost always acceptable, for interlock logic it is not.

## 12. Relationship to Task Faults

GoPLC's existing `GET /api/faults` endpoint reports task watchdog trips and execution errors. These will eventually become a subset of alarms: the alarm engine auto-creates a BOOL alarm for each task's fault flag and the HMI alarm banner becomes the single unified surface. Until then, treat `/api/faults` and `/api/alarms/active` as two independent reporting paths:

- Task faults (watchdog trips, eval errors) → `/api/faults` and `task.fault` bus events.
- Process alarms (HI/LO/DEV/etc.) → `/api/alarms/*` and `alarm.*` bus events.

Both funnel into the events bus, so a single webhook subscribing to `task.fault` and `alarm.*` catches everything operators need to see.

## 13. Related

- [`goplc_events_guide.md`](goplc_events_guide.md) — event bus, webhooks, MQTT fan-out, dedup window, rate limits. Alarms inherit all of it.
- [`goplc_influxdb_guide.md`](goplc_influxdb_guide.md) — stream alarm transitions into a historian for long-term reporting.
- [`goplc_mqtt_guide.md`](goplc_mqtt_guide.md) — the embedded broker used for `goplc/events/alarm.*` fan-out.
- [`goplc_api_guide.md`](goplc_api_guide.md) — REST and WebSocket fundamentals for the `/api/alarms/*` endpoints.
- [`goplc_hal_guide.md`](goplc_hal_guide.md) — GPIO-based digital inputs that typically back BOOL alarms.
