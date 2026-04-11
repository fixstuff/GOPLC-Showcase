# GoPLC DNP3 Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements a complete **DNP3 (IEEE 1815)** stack — both master (client) and outstation (server) — callable directly from IEC 61131-3 Structured Text. No external libraries, no XML configuration files, no code generation. You create masters and outstations, read and write points, and manage connections with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Master** | `DNP3_MASTER_CREATE` / `DNP3_MASTER_READ_*` / `DNP3_MASTER_WRITE_*` | Poll remote outstations: RTUs, protective relays, reclosers, IEDs |
| **Outstation** | `DNP3_OUTSTATION_CREATE` / `DNP3_OUTSTATION_SET_*` / `DNP3_OUTSTATION_GET_*` | Expose GoPLC data to SCADA masters, DCS, or other DNP3 clients |

Both roles can run simultaneously. A single GoPLC instance can poll three field RTUs as a master while serving aggregated point data to a utility SCADA system as an outstation — all from the same ST program.

### System Diagram

```
┌───────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                   │
│                                                               │
│  ┌──────────────────────────┐  ┌────────────────────────────┐ │
│  │ ST Program (Master)      │  │ ST Program (Outstation)    │ │
│  │                          │  │                            │ │
│  │ DNP3_MASTER_CREATE()       │  │ DNP3_OUTSTATION_CREATE()     │ │
│  │ DNP3_MASTER_CONNECT()      │  │ DNP3_OUTSTATION_START()      │ │
│  │ DNP3_MASTER_READ_AI()       │  │ DNP3_OUTSTATION_SET_AI()      │ │
│  │ DNP3_MASTER_READ_BI()       │  │ DNP3_OUTSTATION_SET_BI()      │ │
│  │ DNP3_MASTER_WRITE_BO()      │  │ DNP3_OUTSTATION_GET_BO()      │ │
│  │ DNP3_MASTER_WRITE_AO()      │  │ DNP3_OUTSTATION_GET_AO()      │ │
│  └──────────┬───────────────┘  └──────────┬─────────────────┘ │
│             │                             │                   │
│             │  TCP Client                 │  TCP Server        │
│             │  (connects out)             │  (listens)         │
└─────────────┼─────────────────────────────┼───────────────────┘
              │                             │
              │  DNP3 / TCP                 │  DNP3 / TCP
              │  (Port 20000 default)       │  (configurable)
              ▼                             ▼
┌───────────────────────────┐   ┌───────────────────────────────┐
│  Remote DNP3 Outstation   │   │  Remote DNP3 Master            │
│                           │   │                                 │
│  RTU, Protective Relay,   │   │  Utility SCADA, DCS,            │
│  Recloser, IED, Gateway   │   │  Historian, Control Center      │
└───────────────────────────┘   └─────────────────────────────────┘
```

### Why DNP3?

DNP3 is the dominant SCADA protocol in the electric utility, water/wastewater, and oil & gas industries — particularly in North America. Unlike Modbus, DNP3 provides:

- **Timestamped events** — points carry source timestamps, not just polled snapshots
- **Unsolicited responses** — outstations push changes without waiting for polls
- **Data quality flags** — every point has online/restart/comm-lost/over-range indicators
- **Multiple data types** — binary inputs, binary outputs, analog inputs, analog outputs, counters (and frozen counters)
- **Secure authentication** — SAv5 challenge-response (IEEE 1815-2012)
- **Class-based polling** — poll only changed data (Class 1/2/3) instead of the entire point table

GoPLC abstracts the protocol complexity. Your ST programs read and write typed points by index — the runtime handles framing, transport, polling schedules, and event buffering internally.

### DNP3 Point Types

DNP3 organizes data into five point types. Understanding these is essential for mapping field devices.

| Point Type | DNP3 Group | GoPLC Type | Direction | Typical Use |
|------------|-----------|------------|-----------|-------------|
| **Binary Input (BI)** | Group 1/2 | BOOL | Outstation → Master | Switch status, alarm contacts, equipment state |
| **Binary Output (BO)** | Group 10/12 | BOOL | Master → Outstation | Trip/close commands, start/stop, enable/disable |
| **Analog Input (AI)** | Group 30/32 | REAL | Outstation → Master | Voltage, current, flow, pressure, temperature |
| **Analog Output (AO)** | Group 40/41 | REAL | Master → Outstation | Setpoints, valve position, speed reference |
| **Counter** | Group 20/22 | INT | Outstation → Master | Pulse accumulators, energy totals, event counts |

> **Point Indexing:** All point types use zero-based indexing. Point index 0 is the first point of that type. Each type has its own independent index space — BI index 0 and AI index 0 are different points.

### DNP3 Addressing

Every DNP3 device on a link has a unique **address** (0-65519). In a master-outstation relationship:

| Term | Description | Typical Range |
|------|-------------|---------------|
| **Local Address** | This device's DNP3 address | 1-10 for masters |
| **Remote Address** | The peer device's DNP3 address | 10-65519 for outstations |

When creating a master, you specify *both* addresses so the link layer can route frames correctly — especially important on multi-drop serial links or shared TCP connections.

---

## 2. Master Functions

The DNP3 master connects to remote outstations (RTUs, IEDs, relays) and performs read/write operations. GoPLC handles the polling schedule, event processing, and point caching internally. Your ST code reads cached point values — every read returns the most recent value received from the outstation.

### 2.1 Connection Management

#### DNP3_MASTER_CREATE — Create Named Master Connection

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique connection name |
| `host` | STRING | Yes | IP address or hostname of the outstation |
| `port` | INT | Yes | TCP port (typically 20000) |
| `localAddr` | INT | No | Master's DNP3 address (default 1) |
| `remoteAddr` | INT | No | Outstation's DNP3 address (default 10) |

Returns: `BOOL` — TRUE if the master connection was created successfully.

```iecst
(* Connect to an RTU at 10.0.0.100, default addresses *)
ok := DNP3_MASTER_CREATE('rtu1', '10.0.0.100', 20000);

(* Connect with explicit DNP3 addresses — master=1, outstation=10 *)
ok := DNP3_MASTER_CREATE('rtu1', '10.0.0.100', 20000, 1, 10);

(* Multiple outstations on different addresses *)
ok := DNP3_MASTER_CREATE('sub_north', '10.0.1.50', 20000, 1, 11);
ok := DNP3_MASTER_CREATE('sub_south', '10.0.1.51', 20000, 1, 12);
```

> **Named connections:** Every master connection has a unique string name. This name is used in all subsequent calls. Create one connection per outstation — the typical pattern for utility SCADA polling.

#### DNP3_MASTER_CONNECT — Establish TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from DNP3_MASTER_CREATE |

Returns: `BOOL` — TRUE if connected successfully.

```iecst
ok := DNP3_MASTER_CONNECT('rtu1');
```

#### DNP3_MASTER_DISCONNECT — Close TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully.

```iecst
ok := DNP3_MASTER_DISCONNECT('rtu1');
```

#### DNP3_MASTER_IS_CONNECTED — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the TCP connection is active and the DNP3 link layer is up.

```iecst
IF NOT DNP3_MASTER_IS_CONNECTED('rtu1') THEN
    DNP3_MASTER_CONNECT('rtu1');
END_IF;
```

#### Example: Connection Lifecycle

```iecst
PROGRAM POU_DNP3Init
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create master connection *)
        ok := DNP3_MASTER_CREATE('rtu1', '10.0.0.100', 20000, 1, 10);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := DNP3_MASTER_CONNECT('rtu1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT DNP3_MASTER_IS_CONNECTED('rtu1') THEN
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.2 Read Functions

All read functions return the **most recent cached value** from the outstation. GoPLC polls the outstation automatically in the background and processes unsolicited responses. Reads never block.

#### DNP3_MASTER_READ_BI — Read Binary Input

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `index` | INT | Binary input point index (0-based) |

Returns: `BOOL` — Current state of the binary input.

```iecst
(* Read switch status — BI index 0 *)
breaker_closed := DNP3_MASTER_READ_BI('rtu1', 0);

(* Read alarm contact — BI index 5 *)
hi_level_alarm := DNP3_MASTER_READ_BI('rtu1', 5);
```

> **Binary Inputs** represent discrete field status: breaker position, door contacts, level switches, equipment running indications. These are read-only from the master's perspective — the outstation reports them.

#### DNP3_MASTER_READ_BO — Read Binary Output

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `index` | INT | Binary output point index (0-based) |

Returns: `BOOL` — Current state of the binary output.

```iecst
(* Read back the current state of a control output *)
pump_running := DNP3_MASTER_READ_BO('rtu1', 0);
```

> **Binary Output readback:** This reads the current *feedback state* of a binary output point on the outstation. Use this to verify that a command was executed — compare the readback against the commanded value.

#### DNP3_MASTER_READ_AI — Read Analog Input

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `index` | INT | Analog input point index (0-based) |

Returns: `REAL` — Current value of the analog input.

```iecst
(* Read field measurements *)
bus_voltage := DNP3_MASTER_READ_AI('rtu1', 0);    (* Volts *)
line_current := DNP3_MASTER_READ_AI('rtu1', 1);   (* Amps *)
active_power := DNP3_MASTER_READ_AI('rtu1', 2);   (* kW *)
frequency := DNP3_MASTER_READ_AI('rtu1', 3);      (* Hz *)
```

> **Analog Inputs** represent continuously varying field measurements: voltage, current, power, flow, pressure, temperature, tank level. The outstation typically scales raw instrument readings into engineering units before reporting.

#### DNP3_MASTER_READ_AO — Read Analog Output

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `index` | INT | Analog output point index (0-based) |

Returns: `REAL` — Current value of the analog output.

```iecst
(* Read back the current setpoint *)
current_setpoint := DNP3_MASTER_READ_AO('rtu1', 0);
```

#### DNP3_MASTER_READ_COUNTER — Read Counter

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `index` | INT | Counter point index (0-based) |

Returns: `INT` — Current counter value.

```iecst
(* Read pulse accumulator — energy meter *)
kwh_total := DNP3_MASTER_READ_COUNTER('rtu1', 0);

(* Read event count *)
operations := DNP3_MASTER_READ_COUNTER('rtu1', 1);
```

> **Counters** accumulate events or pulses: kWh totals, breaker operations, flow totalizer pulses. They only increment (or reset). DNP3 also supports *frozen counters* — a snapshot of the counter value at a specific time — which the runtime handles internally.

---

### 2.3 Write Functions

Write functions send control commands to the outstation. DNP3 uses a **Select-Before-Operate (SBO)** or **Direct Operate** model for commands. GoPLC uses Direct Operate by default for simplicity.

#### DNP3_MASTER_WRITE_BO — Write Binary Output (Control)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `index` | INT | Binary output point index (0-based) |
| `value` | BOOL | TRUE = energize/close, FALSE = de-energize/trip |

Returns: `BOOL` — TRUE if the command was acknowledged by the outstation.

```iecst
(* Close breaker *)
ok := DNP3_MASTER_WRITE_BO('rtu1', 0, TRUE);

(* Open breaker *)
ok := DNP3_MASTER_WRITE_BO('rtu1', 0, FALSE);

(* Start pump *)
ok := DNP3_MASTER_WRITE_BO('rtu1', 1, TRUE);
```

> **Control operations** in DNP3 are fundamentally different from Modbus register writes. Each BO command is a discrete, timestamped event that the outstation validates before executing. The outstation may reject commands based on interlocks, local/remote switch position, or authentication requirements.

#### DNP3_MASTER_WRITE_AO — Write Analog Output (Setpoint)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `index` | INT | Analog output point index (0-based) |
| `value` | REAL | Setpoint value |

Returns: `BOOL` — TRUE if the setpoint was acknowledged by the outstation.

```iecst
(* Set voltage regulator tap position *)
ok := DNP3_MASTER_WRITE_AO('rtu1', 0, 122.5);

(* Set flow setpoint *)
ok := DNP3_MASTER_WRITE_AO('rtu1', 1, 150.0);
```

---

### 2.4 Lifecycle Management

#### DNP3_MASTER_DELETE — Remove Master Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if deleted. Automatically disconnects if connected.

```iecst
ok := DNP3_MASTER_DELETE('rtu1');
```

#### DNP3_MASTER_LIST — List All Master Connections

Returns: `[]STRING` — Array of all master connection names.

```iecst
masters := DNP3_MASTER_LIST();
(* Returns: ['rtu1', 'sub_north', 'sub_south'] *)
```

---

## 3. Outstation Functions

The DNP3 outstation acts as a server — it listens for incoming master connections and serves point data. GoPLC outstations support unsolicited responses, class-based event buffering, and multiple simultaneous master connections.

### 3.1 Connection Management

#### DNP3_OUTSTATION_CREATE — Create Named Outstation

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique outstation name |
| `port` | INT | Yes | TCP listen port (typically 20000) |
| `address` | INT | No | Outstation's DNP3 address (default 10) |

Returns: `BOOL` — TRUE if the outstation was created successfully.

```iecst
(* Create outstation on default port *)
ok := DNP3_OUTSTATION_CREATE('sub1', 20000);

(* Create with explicit DNP3 address *)
ok := DNP3_OUTSTATION_CREATE('sub1', 20000, 10);

(* Create second outstation on a different port *)
ok := DNP3_OUTSTATION_CREATE('sub2', 20001, 11);
```

> **Multiple masters:** A single outstation can accept connections from multiple masters simultaneously. This is standard practice — a primary SCADA master and a backup/disaster-recovery master both connect to the same outstation.

#### DNP3_OUTSTATION_START — Begin Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name from DNP3_OUTSTATION_CREATE |

Returns: `BOOL` — TRUE if the outstation started listening.

```iecst
ok := DNP3_OUTSTATION_START('sub1');
```

#### DNP3_OUTSTATION_STOP — Stop Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |

Returns: `BOOL` — TRUE if stopped. Disconnects all connected masters.

```iecst
ok := DNP3_OUTSTATION_STOP('sub1');
```

#### DNP3_OUTSTATION_IS_CONNECTED — Check If Any Master Is Connected

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |

Returns: `BOOL` — TRUE if at least one master is connected.

```iecst
IF DNP3_OUTSTATION_IS_CONNECTED('sub1') THEN
    (* At least one SCADA master is polling us *)
END_IF;
```

---

### 3.2 Set Functions (Outstation → Master)

Set functions update the outstation's point table. When a master polls (or the outstation sends an unsolicited response), it receives these values. Call these from your ST program to publish field data.

#### DNP3_OUTSTATION_SET_BI — Set Binary Input

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |
| `index` | INT | Binary input point index (0-based) |
| `value` | BOOL | Point value |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report equipment status to SCADA *)
DNP3_OUTSTATION_SET_BI('sub1', 0, breaker_closed);
DNP3_OUTSTATION_SET_BI('sub1', 1, transformer_alarm);
DNP3_OUTSTATION_SET_BI('sub1', 2, door_open);
```

> **Event generation:** When a binary input changes state, the outstation automatically generates a change event with a timestamp. The master retrieves these events via class polling — ensuring no state transitions are missed, even between integrity polls.

#### DNP3_OUTSTATION_SET_AI — Set Analog Input

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |
| `index` | INT | Analog input point index (0-based) |
| `value` | REAL | Point value in engineering units |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report field measurements to SCADA *)
DNP3_OUTSTATION_SET_AI('sub1', 0, bus_voltage);     (* 13.8 kV *)
DNP3_OUTSTATION_SET_AI('sub1', 1, line_current);    (* 245.6 A *)
DNP3_OUTSTATION_SET_AI('sub1', 2, active_power);    (* 3200.0 kW *)
DNP3_OUTSTATION_SET_AI('sub1', 3, ambient_temp);    (* 35.2 C *)
```

> **Deadband:** Analog events are generated when the value changes by more than the configured deadband. The runtime applies a default deadband appropriate for the point's scale. This prevents the event buffer from filling with noise on fluctuating measurements.

#### DNP3_OUTSTATION_SET_COUNTER — Set Counter

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |
| `index` | INT | Counter point index (0-based) |
| `value` | INT | Counter value |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report accumulated energy *)
DNP3_OUTSTATION_SET_COUNTER('sub1', 0, kwh_total);

(* Report breaker operations count *)
DNP3_OUTSTATION_SET_COUNTER('sub1', 1, breaker_ops);
```

---

### 3.3 Get Functions (Master → Outstation)

Get functions read command values that a master has written to the outstation. Use these to receive control commands and setpoints from the SCADA system.

#### DNP3_OUTSTATION_GET_BO — Get Binary Output (Control Command)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |
| `index` | INT | Binary output point index (0-based) |

Returns: `BOOL` — The last commanded value from the master.

```iecst
(* Check if SCADA commanded breaker close *)
close_cmd := DNP3_OUTSTATION_GET_BO('sub1', 0);
IF close_cmd THEN
    (* Execute close sequence on local equipment *)
END_IF;
```

#### DNP3_OUTSTATION_GET_AO — Get Analog Output (Setpoint)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |
| `index` | INT | Analog output point index (0-based) |

Returns: `REAL` — The last setpoint value from the master.

```iecst
(* Read voltage setpoint from SCADA *)
voltage_sp := DNP3_OUTSTATION_GET_AO('sub1', 0);

(* Read flow setpoint from SCADA *)
flow_sp := DNP3_OUTSTATION_GET_AO('sub1', 1);
```

---

### 3.4 Diagnostics and Lifecycle

#### DNP3_OUTSTATION_GET_STATS — Outstation Statistics

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |

Returns: `MAP` — Connection and protocol statistics.

```iecst
stats := DNP3_OUTSTATION_GET_STATS('sub1');
(* Returns: {"connected_masters": 2, "requests": 15432,
             "responses": 15432, "events_queued": 12,
             "unsolicited_sent": 847} *)
```

#### DNP3_OUTSTATION_DELETE — Remove Outstation

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Outstation name |

Returns: `BOOL` — TRUE if deleted. Automatically stops if running.

```iecst
ok := DNP3_OUTSTATION_DELETE('sub1');
```

#### DNP3_OUTSTATION_LIST — List All Outstations

Returns: `[]STRING` — Array of all outstation names.

```iecst
outstations := DNP3_OUTSTATION_LIST();
(* Returns: ['sub1', 'sub2'] *)
```

---

## 4. Use Case: SCADA Master Polling RTUs

The most common DNP3 deployment — a GoPLC instance acts as the SCADA master, polling multiple field RTUs across a utility network.

### Architecture

```
                    ┌──────────────────────────────┐
                    │  GoPLC (SCADA Master)         │
                    │                              │
                    │  Polls 3 RTUs cyclically      │
                    │  Logs to historian            │
                    │  Runs control logic           │
                    └──┬─────────┬─────────┬───────┘
                       │         │         │
              DNP3/TCP │  DNP3/TCP│  DNP3/TCP│
                       │         │         │
                       ▼         ▼         ▼
              ┌────────────┐ ┌────────────┐ ┌────────────┐
              │ RTU Site A │ │ RTU Site B │ │ RTU Site C │
              │ Pump Stn   │ │ Tank Farm  │ │ Treatment  │
              │ Addr: 10   │ │ Addr: 11   │ │ Addr: 12   │
              └────────────┘ └────────────┘ └────────────┘
```

### Complete Example

```iecst
PROGRAM POU_ScadaMaster
VAR
    state : INT := 0;
    ok : BOOL;

    (* Site A — Pump Station *)
    siteA_pump_run : BOOL;
    siteA_discharge_psi : REAL;
    siteA_flow_gpm : REAL;
    siteA_runtime_hrs : INT;

    (* Site B — Tank Farm *)
    siteB_tank_level : REAL;
    siteB_hi_level : BOOL;
    siteB_lo_level : BOOL;

    (* Site C — Treatment Plant *)
    siteC_cl2_residual : REAL;
    siteC_turbidity : REAL;
    siteC_flow_mgd : REAL;

    (* Control *)
    pump_start_cmd : BOOL := FALSE;
    cl2_setpoint : REAL := 1.5;
END_VAR

CASE state OF
    0: (* Create all master connections *)
        ok := DNP3_MASTER_CREATE('siteA', '10.0.1.10', 20000, 1, 10);
        ok := DNP3_MASTER_CREATE('siteB', '10.0.1.11', 20000, 1, 11);
        ok := DNP3_MASTER_CREATE('siteC', '10.0.1.12', 20000, 1, 12);
        state := 1;

    1: (* Connect all *)
        DNP3_MASTER_CONNECT('siteA');
        DNP3_MASTER_CONNECT('siteB');
        DNP3_MASTER_CONNECT('siteC');
        state := 10;

    10: (* Poll and control *)
        (* --- Site A: Pump Station --- *)
        IF DNP3_MASTER_IS_CONNECTED('siteA') THEN
            siteA_pump_run := DNP3_MASTER_READ_BI('siteA', 0);
            siteA_discharge_psi := DNP3_MASTER_READ_AI('siteA', 0);
            siteA_flow_gpm := DNP3_MASTER_READ_AI('siteA', 1);
            siteA_runtime_hrs := DNP3_MASTER_READ_COUNTER('siteA', 0);

            (* Send pump command *)
            IF pump_start_cmd THEN
                DNP3_MASTER_WRITE_BO('siteA', 0, TRUE);
            END_IF;
        ELSE
            DNP3_MASTER_CONNECT('siteA');
        END_IF;

        (* --- Site B: Tank Farm --- *)
        IF DNP3_MASTER_IS_CONNECTED('siteB') THEN
            siteB_tank_level := DNP3_MASTER_READ_AI('siteB', 0);
            siteB_hi_level := DNP3_MASTER_READ_BI('siteB', 0);
            siteB_lo_level := DNP3_MASTER_READ_BI('siteB', 1);
        ELSE
            DNP3_MASTER_CONNECT('siteB');
        END_IF;

        (* --- Site C: Treatment Plant --- *)
        IF DNP3_MASTER_IS_CONNECTED('siteC') THEN
            siteC_cl2_residual := DNP3_MASTER_READ_AI('siteC', 0);
            siteC_turbidity := DNP3_MASTER_READ_AI('siteC', 1);
            siteC_flow_mgd := DNP3_MASTER_READ_AI('siteC', 2);

            (* Send chlorine dosing setpoint *)
            DNP3_MASTER_WRITE_AO('siteC', 0, cl2_setpoint);
        ELSE
            DNP3_MASTER_CONNECT('siteC');
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 5. Use Case: Substation Gateway (Outstation)

GoPLC acts as a DNP3 outstation at a substation, aggregating local I/O and instrument data, then serving it to the utility SCADA master over the WAN link.

### Architecture

```
┌────────────────────────────────────────────────────────────┐
│  Substation                                                │
│                                                            │
│  ┌────────────────────────────────────────────────────┐    │
│  │  GoPLC (Outstation, Addr 10)                       │    │
│  │                                                    │    │
│  │  Reads local I/O → Maps to DNP3 points             │    │
│  │  Receives commands → Drives local outputs          │    │
│  │                                                    │    │
│  │  Modbus RTU ──→ Protective Relay (SEL-751)         │    │
│  │  Modbus TCP ──→ Power Meter (ION-7650)             │    │
│  │  Digital I/O ──→ Breaker aux contacts              │    │
│  └──────────┬─────────────────────────────────────────┘    │
│             │                                              │
└─────────────┼──────────────────────────────────────────────┘
              │  DNP3/TCP (WAN)
              │
              ▼
┌────────────────────────────┐
│  Utility SCADA Master      │
│  (Control Center)          │
└────────────────────────────┘
```

### Complete Example

```iecst
PROGRAM POU_SubstationGateway
VAR
    state : INT := 0;
    ok : BOOL;

    (* Local measurements — read from Modbus instruments *)
    bus_kv : REAL;
    feeder_amps : REAL;
    active_kw : REAL;
    reactive_kvar : REAL;
    power_factor : REAL;
    xfmr_temp_c : REAL;

    (* Local status — read from digital I/O *)
    breaker_52a : BOOL;  (* Breaker closed contact *)
    breaker_52b : BOOL;  (* Breaker open contact *)
    lockout_86 : BOOL;   (* Lockout relay *)
    door_alarm : BOOL;
    dc_supply_ok : BOOL;

    (* Commands from SCADA master *)
    breaker_close_cmd : BOOL;
    breaker_trip_cmd : BOOL;
    tap_setpoint : REAL;

    (* Accumulated *)
    kwh_delivered : INT;
    breaker_ops : INT;
END_VAR

CASE state OF
    0: (* Create outstation *)
        ok := DNP3_OUTSTATION_CREATE('sub1', 20000, 10);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Start listening *)
        ok := DNP3_OUTSTATION_START('sub1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — map local data to DNP3 points *)

        (* === Binary Inputs: Equipment Status === *)
        DNP3_OUTSTATION_SET_BI('sub1', 0, breaker_52a);    (* Breaker closed *)
        DNP3_OUTSTATION_SET_BI('sub1', 1, breaker_52b);    (* Breaker open *)
        DNP3_OUTSTATION_SET_BI('sub1', 2, lockout_86);     (* Lockout active *)
        DNP3_OUTSTATION_SET_BI('sub1', 3, door_alarm);     (* Door open *)
        DNP3_OUTSTATION_SET_BI('sub1', 4, dc_supply_ok);   (* DC OK *)

        (* === Analog Inputs: Measurements === *)
        DNP3_OUTSTATION_SET_AI('sub1', 0, bus_kv);         (* Bus voltage kV *)
        DNP3_OUTSTATION_SET_AI('sub1', 1, feeder_amps);    (* Feeder current A *)
        DNP3_OUTSTATION_SET_AI('sub1', 2, active_kw);      (* Active power kW *)
        DNP3_OUTSTATION_SET_AI('sub1', 3, reactive_kvar);  (* Reactive power kVAR *)
        DNP3_OUTSTATION_SET_AI('sub1', 4, power_factor);   (* Power factor *)
        DNP3_OUTSTATION_SET_AI('sub1', 5, xfmr_temp_c);   (* Transformer temp C *)

        (* === Counters === *)
        DNP3_OUTSTATION_SET_COUNTER('sub1', 0, kwh_delivered);
        DNP3_OUTSTATION_SET_COUNTER('sub1', 1, breaker_ops);

        (* === Read Commands from SCADA Master === *)
        breaker_close_cmd := DNP3_OUTSTATION_GET_BO('sub1', 0);
        breaker_trip_cmd := DNP3_OUTSTATION_GET_BO('sub1', 1);
        tap_setpoint := DNP3_OUTSTATION_GET_AO('sub1', 0);

        (* Execute commands locally *)
        IF breaker_close_cmd THEN
            (* Drive close output to breaker control circuit *)
        END_IF;
        IF breaker_trip_cmd THEN
            (* Drive trip output to breaker control circuit *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 6. Use Case: Dual-Role Protocol Gateway

GoPLC simultaneously acts as a DNP3 master (polling field RTUs) and a DNP3 outstation (serving aggregated data upstream to SCADA). This is the classic **data concentrator** or **protocol gateway** pattern used in utility substations and water districts.

```iecst
PROGRAM POU_DataConcentrator
VAR
    state : INT := 0;
    ok : BOOL;

    (* Field data from RTU polls *)
    well_1_flow : REAL;
    well_1_running : BOOL;
    well_2_flow : REAL;
    well_2_running : BOOL;
    reservoir_level : REAL;

    (* Aggregate calculations *)
    total_flow : REAL;
    wells_online : INT;
END_VAR

CASE state OF
    0: (* Create master connections to field RTUs *)
        DNP3_MASTER_CREATE('well1', '10.0.2.10', 20000, 1, 20);
        DNP3_MASTER_CREATE('well2', '10.0.2.11', 20000, 1, 21);

        (* Create outstation for upstream SCADA *)
        DNP3_OUTSTATION_CREATE('scada_feed', 20000, 10);
        state := 1;

    1: (* Connect and start *)
        DNP3_MASTER_CONNECT('well1');
        DNP3_MASTER_CONNECT('well2');
        DNP3_OUTSTATION_START('scada_feed');
        state := 10;

    10: (* Running — poll, aggregate, serve *)

        (* Poll field RTUs *)
        well_1_flow := DNP3_MASTER_READ_AI('well1', 0);
        well_1_running := DNP3_MASTER_READ_BI('well1', 0);
        well_2_flow := DNP3_MASTER_READ_AI('well2', 0);
        well_2_running := DNP3_MASTER_READ_BI('well2', 0);
        reservoir_level := DNP3_MASTER_READ_AI('well1', 1);

        (* Aggregate *)
        total_flow := well_1_flow + well_2_flow;
        wells_online := 0;
        IF well_1_running THEN wells_online := wells_online + 1; END_IF;
        IF well_2_running THEN wells_online := wells_online + 1; END_IF;

        (* Serve aggregated data to upstream SCADA *)
        DNP3_OUTSTATION_SET_AI('scada_feed', 0, total_flow);
        DNP3_OUTSTATION_SET_AI('scada_feed', 1, reservoir_level);
        DNP3_OUTSTATION_SET_AI('scada_feed', 2, well_1_flow);
        DNP3_OUTSTATION_SET_AI('scada_feed', 3, well_2_flow);
        DNP3_OUTSTATION_SET_BI('scada_feed', 0, well_1_running);
        DNP3_OUTSTATION_SET_BI('scada_feed', 1, well_2_running);
        DNP3_OUTSTATION_SET_COUNTER('scada_feed', 0, wells_online);

        (* Reconnect if needed *)
        IF NOT DNP3_MASTER_IS_CONNECTED('well1') THEN
            DNP3_MASTER_CONNECT('well1');
        END_IF;
        IF NOT DNP3_MASTER_IS_CONNECTED('well2') THEN
            DNP3_MASTER_CONNECT('well2');
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 7. DNP3 vs. Modbus: When to Use What

| Criteria | DNP3 | Modbus TCP |
|----------|------|------------|
| **Event-driven data** | Yes — timestamped change events, class polling | No — poll-only, snapshot values |
| **Unsolicited responses** | Yes — outstation pushes changes | No — master must poll |
| **Data quality** | Per-point quality flags (online, restart, comm-lost) | No built-in quality |
| **Timestamps** | Source timestamps on events | No timestamps |
| **WAN suitability** | Designed for low-bandwidth, high-latency links | Poor on WAN — chatty polling |
| **Point types** | 5 types with separate index spaces | 4 register areas (coils, DI, HR, IR) |
| **Security** | SAv5 authentication (IEEE 1815-2012) | None built-in |
| **Industry** | Electric utility, water/wastewater, oil & gas | Manufacturing, building automation, general industrial |
| **Complexity** | Higher — more features, more configuration | Lower — simpler data model |
| **GoPLC function count** | 25 (13 master + 12 outstation) | 30 (15 client + 15 server) |

**Rule of thumb:** If you are in a utility or critical infrastructure environment and need event-driven data with timestamps, use DNP3. If you are polling industrial devices on a LAN and just need register values, use Modbus.

---

## 8. Typical Point Maps

### Water/Wastewater Pump Station

| Type | Index | Description | Units |
|------|-------|-------------|-------|
| BI 0 | 0 | Pump 1 Running | — |
| BI 1 | 1 | Pump 2 Running | — |
| BI 2 | 2 | High Level Alarm | — |
| BI 3 | 3 | Low Level Alarm | — |
| BI 4 | 4 | Power Failure | — |
| AI 0 | 0 | Wet Well Level | feet |
| AI 1 | 1 | Discharge Pressure | PSI |
| AI 2 | 2 | Flow Rate | GPM |
| AI 3 | 3 | Pump 1 Current | Amps |
| AI 4 | 4 | Pump 2 Current | Amps |
| BO 0 | 0 | Pump 1 Start/Stop | — |
| BO 1 | 1 | Pump 2 Start/Stop | — |
| AO 0 | 0 | Level Setpoint | feet |
| Counter 0 | 0 | Pump 1 Starts | count |
| Counter 1 | 1 | Pump 2 Starts | count |
| Counter 2 | 2 | Total Flow | gallons |

### Electric Substation

| Type | Index | Description | Units |
|------|-------|-------------|-------|
| BI 0 | 0 | Breaker 52a (Closed) | — |
| BI 1 | 1 | Breaker 52b (Open) | — |
| BI 2 | 2 | Lockout Relay 86 | — |
| BI 3 | 3 | Recloser Enabled | — |
| BI 4 | 4 | Ground Fault | — |
| BI 5 | 5 | DC Supply OK | — |
| AI 0 | 0 | Bus Voltage | kV |
| AI 1 | 1 | Phase A Current | A |
| AI 2 | 2 | Phase B Current | A |
| AI 3 | 3 | Phase C Current | A |
| AI 4 | 4 | Active Power | MW |
| AI 5 | 5 | Reactive Power | MVAR |
| AI 6 | 6 | Power Factor | — |
| AI 7 | 7 | Frequency | Hz |
| AI 8 | 8 | Transformer Temp | C |
| BO 0 | 0 | Breaker Close | — |
| BO 1 | 1 | Breaker Trip | — |
| BO 2 | 2 | Recloser Enable | — |
| AO 0 | 0 | Tap Position | — |
| Counter 0 | 0 | kWh Delivered | kWh |
| Counter 1 | 1 | Breaker Operations | count |

---

## 9. Gotchas and Best Practices

### DNP3 Address Planning

- **Reserve address 0** — some implementations use it as a broadcast address.
- **Use consistent addressing** — masters at 1-9, outstations at 10+. Document your address table.
- **Multi-drop serial:** If you are using serial (not TCP), multiple outstations share a link. Each must have a unique address. GoPLC's TCP implementation uses one connection per outstation, but the addressing still matters for link-layer routing.

### Connection Management

- **Always check `IsConnected` before reads/writes.** Reads on a disconnected master return stale cached values (the last known good value). Your logic must distinguish between "connected and reading 0.0" and "disconnected and stale."
- **Reconnect in a state machine.** DNP3 connections over WAN links will drop. Use the `CASE` state machine pattern shown in the examples — never just call `Connect` unconditionally every scan.
- **Do not create connections every scan.** `DNP3_MASTER_CREATE` and `DNP3_OUTSTATION_CREATE` are one-time setup calls. Guard them with a state variable.

### Point Index Ranges

- Point indices are zero-based in GoPLC.
- There is no relationship between BI index 0 and AI index 0 — each type has its own index space.
- If an outstation exposes 16 BIs and 8 AIs, valid reads are BI 0-15 and AI 0-7. Reading beyond the outstation's configured range returns the default value (FALSE for BOOL, 0.0 for REAL, 0 for INT).

### Timing

- **Master reads are non-blocking.** They return the cached value immediately. The runtime polls the outstation in the background at the configured class poll interval.
- **Master writes are blocking.** `DNP3_MASTER_WRITE_BO` and `DNP3_MASTER_WRITE_AO` wait for the outstation's acknowledgment before returning. Keep write frequency reasonable — do not command every scan cycle.
- **Outstation sets are immediate.** `DNP3_OUTSTATION_SET_BI/AI/Counter` update the point table instantly. The master sees the new value on its next poll or via unsolicited response.

### Security Considerations

- **DNP3 carries control commands.** Unlike Modbus read-only monitoring, DNP3 masters can trip breakers and change setpoints. Secure the network.
- **Use VPN or private WAN** for DNP3 links that traverse untrusted networks.
- **NERC CIP compliance** may apply if you are operating bulk electric system assets. Consult your compliance team.
- **Firewall port 20000** (or your configured port) — allow only known master IP addresses to connect to outstations.

---

## Appendix A: Quick Reference — All 25 Functions

### Master Functions (13)

| Function | Returns | Description |
|----------|---------|-------------|
| `DNP3_MASTER_CREATE(name, host, port [, localAddr] [, remoteAddr])` | BOOL | Create named master connection |
| `DNP3_MASTER_CONNECT(name)` | BOOL | Establish TCP connection |
| `DNP3_MASTER_DISCONNECT(name)` | BOOL | Close TCP connection |
| `DNP3_MASTER_IS_CONNECTED(name)` | BOOL | Check connection state |
| `DNP3_MASTER_READ_BI(name, index)` | BOOL | Read binary input |
| `DNP3_MASTER_READ_BO(name, index)` | BOOL | Read binary output |
| `DNP3_MASTER_READ_AI(name, index)` | REAL | Read analog input |
| `DNP3_MASTER_READ_AO(name, index)` | REAL | Read analog output |
| `DNP3_MASTER_READ_COUNTER(name, index)` | INT | Read counter |
| `DNP3_MASTER_WRITE_BO(name, index, value)` | BOOL | Write binary output (control) |
| `DNP3_MASTER_WRITE_AO(name, index, value)` | BOOL | Write analog output (setpoint) |
| `DNP3_MASTER_DELETE(name)` | BOOL | Remove master connection |
| `DNP3_MASTER_LIST()` | []STRING | List all master connections |

### Outstation Functions (12)

| Function | Returns | Description |
|----------|---------|-------------|
| `DNP3_OUTSTATION_CREATE(name, port [, address])` | BOOL | Create named outstation |
| `DNP3_OUTSTATION_START(name)` | BOOL | Begin listening for masters |
| `DNP3_OUTSTATION_STOP(name)` | BOOL | Stop listening |
| `DNP3_OUTSTATION_IS_CONNECTED(name)` | BOOL | Check if any master is connected |
| `DNP3_OUTSTATION_SET_BI(name, index, value)` | BOOL | Set binary input point |
| `DNP3_OUTSTATION_SET_AI(name, index, value)` | BOOL | Set analog input point |
| `DNP3_OUTSTATION_SET_COUNTER(name, index, value)` | BOOL | Set counter point |
| `DNP3_OUTSTATION_GET_BO(name, index)` | BOOL | Get binary output (command from master) |
| `DNP3_OUTSTATION_GET_AO(name, index)` | REAL | Get analog output (setpoint from master) |
| `DNP3_OUTSTATION_GET_STATS(name)` | MAP | Connection and protocol statistics |
| `DNP3_OUTSTATION_DELETE(name)` | BOOL | Remove outstation |
| `DNP3_OUTSTATION_LIST()` | []STRING | List all outstations |

---

## Appendix B: DNP3 Object Groups Used

| Group | Variation | Description | GoPLC Point Type |
|-------|-----------|-------------|-----------------|
| 1 | 1-2 | Binary Input — static | BI (read) |
| 2 | 1-3 | Binary Input — event | BI (event) |
| 10 | 1-2 | Binary Output — static | BO (read) |
| 12 | 1 | Binary Output — CROB command | BO (write) |
| 20 | 1-2 | Counter — static | Counter (read) |
| 22 | 1-2 | Counter — event | Counter (event) |
| 30 | 1-6 | Analog Input — static | AI (read) |
| 32 | 1-8 | Analog Input — event | AI (event) |
| 40 | 1-4 | Analog Output — static | AO (read) |
| 41 | 1-4 | Analog Output — command | AO (write) |
| 60 | 1-4 | Class Data — integrity/class 0/1/2/3 | (polling) |

---

*GoPLC v1.0.533 | DNP3 Master + Outstation | IEC 61131-3 Structured Text*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
