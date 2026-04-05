# GoPLC IEC 60870-5-104 Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements a complete **IEC 60870-5-104** stack — both controlling station (client/master) and controlled station (server/slave) — callable directly from IEC 61131-3 Structured Text. No external libraries, no XML configuration files, no code generation. You create clients and servers, read and write data objects, and manage connections with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client (Controlling Station)** | `IEC104_CLIENT_CREATE` / `IEC104_CLIENT_READ_*` / `IEC104_CLIENT_WRITE_*` | Poll remote RTUs, protection relays, bay controllers, IEDs |
| **Server (Controlled Station)** | `IEC104_SERVER_CREATE` / `IEC104_SERVER_SET_*` / `IEC104_SERVER_GET_*` | Expose GoPLC data to SCADA masters, control centers, energy management systems |

Both roles can run simultaneously. A single GoPLC instance can poll substation IEDs as a client while serving aggregated data to a utility control center as a server — all from the same ST program.

### System Diagram

```
┌───────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                   │
│                                                               │
│  ┌──────────────────────────┐  ┌────────────────────────────┐ │
│  │ ST Program (Client)      │  │ ST Program (Server)        │ │
│  │                          │  │                            │ │
│  │ IEC104_CLIENT_CREATE()     │  │ IEC104_SERVER_CREATE()       │ │
│  │ IEC104_CLIENT_CONNECT()    │  │ IEC104_SERVER_START()        │ │
│  │ IEC104_CLIENT_READ_SP()     │  │ IEC104_SERVER_SET_SP()        │ │
│  │ IEC104_CLIENT_READ_FLOAT()  │  │ IEC104_SERVER_SET_FLOAT()     │ │
│  │ IEC104_CLIENT_WRITE_SC()    │  │ IEC104_SERVER_GET_SC()        │ │
│  │ IEC104_CLIENT_WRITE_SETPOINT│  │ IEC104_SERVER_GET_SETPOINT()  │ │
│  └──────────┬───────────────┘  └──────────┬─────────────────┘ │
│             │                             │                   │
│             │  TCP Client                 │  TCP Server        │
│             │  (connects out)             │  (listens)         │
└─────────────┼─────────────────────────────┼───────────────────┘
              │                             │
              │  IEC 104 / TCP              │  IEC 104 / TCP
              │  (Port 2404 default)        │  (configurable)
              ▼                             ▼
┌───────────────────────────┐   ┌───────────────────────────────┐
│  Remote Controlled Station│   │  Remote Controlling Station     │
│                           │   │                                 │
│  RTU, Protection Relay,   │   │  Utility SCADA, EMS, DCS,       │
│  Bay Controller, IED,     │   │  Control Center, Historian       │
│  Substation Gateway       │   │                                 │
└───────────────────────────┘   └─────────────────────────────────┘
```

### Why IEC 60870-5-104?

IEC 60870-5-104 (commonly "IEC 104") is the dominant telecontrol protocol for power system SCADA in Europe, Asia, Africa, and South America — the international counterpart to DNP3. It runs over TCP/IP and is the standard protocol for:

- **Transmission SCADA** — communication between control centers and substations
- **Distribution automation** — feeder monitoring, recloser control, capacitor bank switching
- **Generation dispatch** — turbine telemetry and setpoint control from EMS
- **Interconnection metering** — real-time power flow data between grid operators
- **Renewable integration** — wind farm and solar plant monitoring and curtailment

Key protocol features:

- **Application layer (IEC 60870-5-101)** over **TCP/IP transport (IEC 60870-5-104)**
- **Spontaneous transmission** — controlled stations push changes without polling
- **Time-tagged data** — CP56Time2a timestamps with millisecond resolution
- **Cause of transmission** — every ASDU carries why it was sent (spontaneous, interrogated, periodic, etc.)
- **General interrogation** — client can request a full snapshot of all data points
- **Common address (CASDU)** — identifies the station/logical device (1-65534)
- **Information object address (IOA)** — identifies each data point within a station (1-16777215)

GoPLC abstracts the protocol complexity. Your ST programs read and write typed data objects by IOA — the runtime handles APCI framing, I/S/U-format messages, sequence numbering, t1/t2/t3 timers, and connection supervision internally.

### IEC 104 Data Types

IEC 104 organizes data into typed information objects. Understanding these mappings is essential for integrating with utility SCADA systems.

| Data Type | ASDU Type ID | GoPLC Type | Direction | Typical Use |
|-----------|-------------|------------|-----------|-------------|
| **Single Point (SP)** | M_SP_NA_1 (1) / M_SP_TB_1 (30) | BOOL | Server → Client | Breaker status, switch position, alarm flags |
| **Double Point (DP)** | M_DP_NA_1 (3) / M_DP_TB_1 (31) | INT | Server → Client | Breaker position (00=indeterminate, 01=off, 10=on, 11=indeterminate) |
| **Measured Float (MF)** | M_ME_NC_1 (13) / M_ME_TF_1 (36) | REAL | Server → Client | Voltage, current, power, frequency, temperature |
| **Measured Scaled (MS)** | M_ME_NB_1 (11) / M_ME_TE_1 (35) | INT | Server → Client | Tap position, percentage values, scaled measurements |
| **Integrated Total (IT)** | M_IT_NA_1 (15) / M_IT_TB_1 (37) | INT | Server → Client | Energy counters (kWh, MVArh), pulse accumulators |
| **Single Command (SC)** | C_SC_NA_1 (45) / C_SC_TA_1 (58) | BOOL | Client → Server | Trip/close commands, start/stop, enable/disable |
| **Setpoint Command** | C_SE_NC_1 (50) / C_SE_TC_1 (63) | REAL | Client → Server | Voltage setpoint, power setpoint, tap target |

> **Double Point values:** 0 = indeterminate/transit, 1 = OFF/open, 2 = ON/closed, 3 = indeterminate/fault. This encoding is defined by IEC 60870-5-101 and maps directly to breaker and disconnect switch positions.

### IOA Addressing

Every data point in IEC 104 is identified by an **Information Object Address (IOA)** — a 24-bit integer (1-16777215) that is unique within a given common address (station). Unlike DNP3's zero-based type-specific indexing, IEC 104 uses a **flat address space** where every point has a globally unique IOA within the station.

| Concept | Description | Range |
|---------|-------------|-------|
| **Common Address (CASDU)** | Station/device identifier | 1-65534 |
| **IOA** | Point address within the station | 1-16777215 |

Typical IOA allocation follows utility convention:

| IOA Range | Data Type | Example Use |
|-----------|-----------|-------------|
| 1-999 | Single Point (SP) | Breaker status, alarm contacts |
| 1000-1999 | Double Point (DP) | Breaker position, disconnect status |
| 2000-2999 | Measured Float | Voltage, current, power, frequency |
| 3000-3999 | Measured Scaled | Tap position, percentage values |
| 4000-4999 | Integrated Totals | Energy counters |
| 5000-5999 | Single Command | Breaker trip/close |
| 6000-6999 | Setpoint Command | Voltage/power setpoints |

> **Convention only:** IOA ranges are not mandated by the standard — they are engineering conventions. Each utility or system integrator defines their own IOA map. GoPLC does not enforce any mapping; you read and write any IOA with any function.

### IEC 104 vs DNP3

Both protocols serve the same purpose (telecontrol SCADA) but differ in adoption and design philosophy:

| Feature | IEC 60870-5-104 | DNP3 (IEEE 1815) |
|---------|----------------|-------------------|
| **Geography** | Europe, Asia, Africa, South America | North America, Australia |
| **Transport** | TCP only (port 2404) | TCP or serial |
| **Point addressing** | Flat IOA space (1-16M) | Type-specific zero-based index |
| **Double point** | Native (2-bit status) | Binary input pairs (convention) |
| **Time sync** | Clock sync command (C_CS_NA_1) | Time sync over link layer |
| **Standard body** | IEC (Geneva) | IEEE (USA) |
| **GoPLC support** | This guide | See DNP3 guide |

---

## 2. Client Functions (Controlling Station)

The IEC 104 client connects to remote controlled stations (RTUs, IEDs, bay controllers) and performs read/write operations. GoPLC handles general interrogation, spontaneous data reception, and point caching internally. Your ST code reads cached point values — every read returns the most recent value received from the controlled station.

### 2.1 Connection Management

#### IEC104_CLIENT_CREATE — Create Named Client Connection

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique connection name |
| `host` | STRING | Yes | IP address or hostname of the controlled station |
| `port` | INT | Yes | TCP port (typically 2404) |
| `commonAddr` | INT | No | Common address / CASDU (default 1) |

Returns: `BOOL` — TRUE if the client connection was created successfully.

```iecst
(* Connect to a substation RTU at 10.0.0.100, default common address *)
ok := IEC104_CLIENT_CREATE('sub1', '10.0.0.100', 2404);

(* Connect with explicit common address *)
ok := IEC104_CLIENT_CREATE('sub1', '10.0.0.100', 2404, 47);

(* Multiple substations *)
ok := IEC104_CLIENT_CREATE('sub_north', '10.0.1.50', 2404, 1);
ok := IEC104_CLIENT_CREATE('sub_south', '10.0.1.51', 2404, 2);
```

> **Named connections:** Every client connection has a unique string name. This name is used in all subsequent calls. Create one connection per controlled station — the typical pattern for SCADA polling.

#### IEC104_CLIENT_CONNECT — Establish TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from IEC104_CLIENT_CREATE |

Returns: `BOOL` — TRUE if connected successfully. The runtime automatically sends a STARTDT (Start Data Transfer) activation and issues a general interrogation (C_IC_NA_1) to populate the initial point table.

```iecst
ok := IEC104_CLIENT_CONNECT('sub1');
```

#### IEC104_CLIENT_DISCONNECT — Close TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully. Sends a STOPDT (Stop Data Transfer) before closing the TCP connection.

```iecst
ok := IEC104_CLIENT_DISCONNECT('sub1');
```

#### IEC104_CLIENT_IS_CONNECTED — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the TCP connection is active and data transfer is active (STARTDT confirmed).

```iecst
IF NOT IEC104_CLIENT_IS_CONNECTED('sub1') THEN
    IEC104_CLIENT_CONNECT('sub1');
END_IF;
```

#### Example: Connection Lifecycle

```iecst
PROGRAM POU_IEC104Init
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create client connection *)
        ok := IEC104_CLIENT_CREATE('sub1', '10.0.0.100', 2404, 1);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect — triggers STARTDT + general interrogation *)
        ok := IEC104_CLIENT_CONNECT('sub1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT IEC104_CLIENT_IS_CONNECTED('sub1') THEN
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.2 Read Functions

All read functions return the **most recent cached value** from the controlled station. GoPLC receives spontaneous data updates and general interrogation responses automatically in the background. Reads never block.

#### IEC104_CLIENT_READ_SP — Read Single Point

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `ioa` | INT | Information Object Address |

Returns: `BOOL` — The current single point value at the specified IOA.

```iecst
(* Read breaker status — IOA 1 *)
breaker_closed := IEC104_CLIENT_READ_SP('sub1', 1);

(* Read alarm contact — IOA 10 *)
overtemp_alarm := IEC104_CLIENT_READ_SP('sub1', 10);
```

> **ASDU types:** The runtime accepts both M_SP_NA_1 (1) and M_SP_TB_1 (30) — with and without time tags. Time-tagged variants are preferred by the controlled station for spontaneous updates; your read call returns the value regardless of which variant was received.

#### IEC104_CLIENT_READ_DP — Read Double Point

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `ioa` | INT | Information Object Address |

Returns: `INT` — The current double point value (0-3).

| Value | Meaning | IEC Interpretation |
|-------|---------|--------------------|
| 0 | Indeterminate | Transit / not available |
| 1 | OFF | Open / de-energized |
| 2 | ON | Closed / energized |
| 3 | Indeterminate | Fault / inconsistent |

```iecst
(* Read breaker position — IOA 1000 *)
breaker_pos := IEC104_CLIENT_READ_DP('sub1', 1000);

IF breaker_pos = 2 THEN
    (* Breaker is closed *)
ELSIF breaker_pos = 1 THEN
    (* Breaker is open *)
ELSE
    (* Indeterminate — transit or fault *)
END_IF;
```

> **Double point vs single point:** Use double point for equipment that has distinct open and closed feedback contacts (breakers, disconnectors). The 2-bit encoding detects mid-travel and contact disagreement — critical for protection coordination.

#### IEC104_CLIENT_READ_FLOAT — Read Measured Value (Floating Point)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `ioa` | INT | Information Object Address |

Returns: `REAL` — The current measured value in engineering units.

```iecst
(* Read substation measurements *)
bus_voltage := IEC104_CLIENT_READ_FLOAT('sub1', 2000);    (* kV *)
line_current := IEC104_CLIENT_READ_FLOAT('sub1', 2001);   (* A *)
active_power := IEC104_CLIENT_READ_FLOAT('sub1', 2002);   (* MW *)
frequency := IEC104_CLIENT_READ_FLOAT('sub1', 2003);      (* Hz *)
```

> **ASDU types:** Maps to M_ME_NC_1 (13) and M_ME_TF_1 (36) — short floating point with and without time tag. These carry IEEE 754 single-precision values directly, with no scaling required.

#### IEC104_CLIENT_READ_SCALED — Read Measured Value (Scaled)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `ioa` | INT | Information Object Address |

Returns: `INT` — The raw scaled value (-32768 to 32767).

```iecst
(* Read transformer tap position — IOA 3000 *)
tap_pos := IEC104_CLIENT_READ_SCALED('sub1', 3000);

(* Read percentage value — IOA 3010 *)
load_pct := IEC104_CLIENT_READ_SCALED('sub1', 3010);
```

> **Scaling:** Scaled values (M_ME_NB_1 / M_ME_TE_1) are 16-bit signed integers. The engineering unit conversion depends on the point configuration at the controlled station. A tap changer might report position 1-33 directly; a load percentage might use 0-10000 to represent 0.00-100.00%. Consult the station's IOA map for scaling factors.

#### IEC104_CLIENT_READ_COUNTER — Read Integrated Total

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `ioa` | INT | Information Object Address |

Returns: `INT` — The current counter value.

```iecst
(* Read energy counters *)
kwh_import := IEC104_CLIENT_READ_COUNTER('sub1', 4000);
kwh_export := IEC104_CLIENT_READ_COUNTER('sub1', 4001);
mvarh := IEC104_CLIENT_READ_COUNTER('sub1', 4002);
```

> **Counter interrogation:** The runtime can issue counter interrogation commands (C_CI_NA_1) to freeze and read counters atomically. Integrated totals use ASDU types M_IT_NA_1 (15) and M_IT_TB_1 (37).

---

### 2.3 Write Functions (Commands)

Write functions send commands from the controlling station to the controlled station. IEC 104 commands follow a **select-before-operate (SBO)** or **direct execution** model, depending on station configuration. GoPLC uses direct execution by default.

#### IEC104_CLIENT_WRITE_SC — Write Single Command

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `ioa` | INT | Information Object Address of the command point |
| `value` | BOOL | Command value (TRUE = ON, FALSE = OFF) |

Returns: `BOOL` — TRUE if the command was acknowledged by the controlled station.

```iecst
(* Trip breaker — IOA 5000 *)
ok := IEC104_CLIENT_WRITE_SC('sub1', 5000, FALSE);

(* Close breaker — IOA 5000 *)
ok := IEC104_CLIENT_WRITE_SC('sub1', 5000, TRUE);

(* Enable capacitor bank — IOA 5010 *)
ok := IEC104_CLIENT_WRITE_SC('sub1', 5010, TRUE);
```

> **ASDU type:** Sends C_SC_NA_1 (45) — single command. The controlled station validates the command and responds with an activation confirmation or negative acknowledgment. The return value reflects whether the command was accepted.

#### IEC104_CLIENT_WRITE_SETPOINT — Write Setpoint Command

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `ioa` | INT | Information Object Address of the setpoint |
| `value` | REAL | Setpoint value in engineering units |

Returns: `BOOL` — TRUE if the setpoint was acknowledged.

```iecst
(* Set voltage reference — IOA 6000 *)
ok := IEC104_CLIENT_WRITE_SETPOINT('sub1', 6000, 110.5);

(* Set active power setpoint for wind farm curtailment — IOA 6010 *)
ok := IEC104_CLIENT_WRITE_SETPOINT('sub1', 6010, 45.0);

(* Set transformer tap target — IOA 6020 *)
ok := IEC104_CLIENT_WRITE_SETPOINT('sub1', 6020, 15.0);
```

> **ASDU type:** Sends C_SE_NC_1 (50) — setpoint command, short floating point. For scaled setpoints, the runtime converts the REAL value to a scaled integer internally when communicating with stations that expect M_ME_NB_1-style values.

---

### 2.4 Lifecycle Management

#### IEC104_CLIENT_DELETE — Remove Client Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the connection was removed. Disconnects first if still connected.

```iecst
ok := IEC104_CLIENT_DELETE('sub1');
```

#### IEC104_CLIENT_LIST — List All Client Connections

Returns: `[]STRING` — Array of all active client connection names.

```iecst
clients := IEC104_CLIENT_LIST();
(* Returns: ['sub_north', 'sub_south'] *)
```

---

## 3. Server Functions (Controlled Station)

The IEC 104 server listens for incoming connections from controlling stations (SCADA masters, control centers). GoPLC manages connection acceptance, general interrogation responses, spontaneous data transmission, and APCI-level keepalives (TESTFR) automatically. Your ST program sets data point values and reads incoming commands.

### 3.1 Connection Management

#### IEC104_SERVER_CREATE — Create Named Server

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique server name |
| `port` | INT | Yes | TCP listen port (typically 2404) |
| `commonAddr` | INT | No | Common address / CASDU (default 1) |

Returns: `BOOL` — TRUE if the server was created successfully.

```iecst
(* Create server on default IEC 104 port *)
ok := IEC104_SERVER_CREATE('station1', 2404);

(* Create server with explicit common address *)
ok := IEC104_SERVER_CREATE('station1', 2404, 47);

(* Multiple servers for different logical devices *)
ok := IEC104_SERVER_CREATE('bay1', 2404, 1);
ok := IEC104_SERVER_CREATE('bay2', 2405, 2);
```

> **Common address:** The CASDU identifies this controlled station to connecting clients. In a substation with multiple bay controllers, each bay typically has its own common address. Clients filter incoming ASDUs by common address.

#### IEC104_SERVER_START — Begin Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server began listening. Accepts incoming TCP connections and responds to STARTDT, general interrogation, and TESTFR automatically.

```iecst
ok := IEC104_SERVER_START('station1');
```

#### IEC104_SERVER_STOP — Stop Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if stopped. Disconnects all connected controlling stations.

```iecst
ok := IEC104_SERVER_STOP('station1');
```

#### IEC104_SERVER_IS_CONNECTED — Check If Any Client Is Connected

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if at least one controlling station is connected and data transfer is active.

```iecst
IF IEC104_SERVER_IS_CONNECTED('station1') THEN
    (* At least one SCADA master is connected *)
END_IF;
```

#### Example: Server Lifecycle

```iecst
PROGRAM POU_IEC104Server
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create server *)
        ok := IEC104_SERVER_CREATE('station1', 2404, 1);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Start listening *)
        ok := IEC104_SERVER_START('station1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — set data points in other programs *)
        ;
END_CASE;
END_PROGRAM
```

---

### 3.2 Set Functions (Controlled Station → Controlling Station)

Set functions update the server's data point table. When a controlling station sends a general interrogation or the server sends spontaneous data, the client receives these values. Call these from your ST program to publish field data.

#### IEC104_SERVER_SET_SP — Set Single Point

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `ioa` | INT | Information Object Address |
| `value` | BOOL | Point value |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report equipment status to SCADA *)
IEC104_SERVER_SET_SP('station1', 1, breaker_closed);
IEC104_SERVER_SET_SP('station1', 2, transformer_alarm);
IEC104_SERVER_SET_SP('station1', 3, door_open);
IEC104_SERVER_SET_SP('station1', 10, protection_trip);
```

> **Spontaneous transmission:** When a single point changes state, the server automatically generates a spontaneous ASDU (cause of transmission = 3) with a CP56Time2a timestamp. The controlling station receives the change without polling — ensuring no state transitions are missed between general interrogations.

#### IEC104_SERVER_SET_DP — Set Double Point

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `ioa` | INT | Information Object Address |
| `value` | INT | Double point value (0-3) |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report breaker position: 1=OFF/open, 2=ON/closed *)
IEC104_SERVER_SET_DP('station1', 1000, 2);   (* Breaker closed *)
IEC104_SERVER_SET_DP('station1', 1001, 1);   (* Disconnect open *)

(* Report transient state during switching *)
IEC104_SERVER_SET_DP('station1', 1000, 0);   (* In transit *)
```

#### IEC104_SERVER_SET_FLOAT — Set Measured Value (Floating Point)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `ioa` | INT | Information Object Address |
| `value` | REAL | Measured value in engineering units |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report substation measurements to SCADA *)
IEC104_SERVER_SET_FLOAT('station1', 2000, bus_voltage);     (* 110.2 kV *)
IEC104_SERVER_SET_FLOAT('station1', 2001, line_current);    (* 245.6 A *)
IEC104_SERVER_SET_FLOAT('station1', 2002, active_power);    (* 27.1 MW *)
IEC104_SERVER_SET_FLOAT('station1', 2003, reactive_power);  (* 8.4 MVAr *)
IEC104_SERVER_SET_FLOAT('station1', 2004, frequency);       (* 50.01 Hz *)
IEC104_SERVER_SET_FLOAT('station1', 2005, ambient_temp);    (* 35.2 C *)
```

> **Deadband:** Analog spontaneous events are generated when the value changes by more than the configured deadband. The runtime applies a default deadband appropriate for the point's scale, preventing the event buffer from flooding with noise on fluctuating measurements.

#### IEC104_SERVER_SET_SCALED — Set Measured Value (Scaled)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `ioa` | INT | Information Object Address |
| `value` | INT | Scaled value (-32768 to 32767) |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report tap changer position *)
IEC104_SERVER_SET_SCALED('station1', 3000, tap_position);   (* e.g. 17 *)

(* Report load as percentage x100 *)
IEC104_SERVER_SET_SCALED('station1', 3001, load_pct_x100);  (* 8750 = 87.50% *)
```

#### IEC104_SERVER_SET_COUNTER — Set Integrated Total

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `ioa` | INT | Information Object Address |
| `value` | INT | Counter value |

Returns: `BOOL` — TRUE if the point was updated.

```iecst
(* Report energy counters *)
IEC104_SERVER_SET_COUNTER('station1', 4000, kwh_import);
IEC104_SERVER_SET_COUNTER('station1', 4001, kwh_export);
IEC104_SERVER_SET_COUNTER('station1', 4002, mvarh_total);
```

---

### 3.3 Get Functions (Controlling Station → Controlled Station)

Get functions read command values that a controlling station has written to the server. Use these to receive control commands and setpoints from the SCADA system.

#### IEC104_SERVER_GET_SC — Get Single Command

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `ioa` | INT | Information Object Address of the command point |

Returns: `BOOL` — The last commanded value from the controlling station.

```iecst
(* Check if SCADA commanded breaker close *)
close_cmd := IEC104_SERVER_GET_SC('station1', 5000);
IF close_cmd THEN
    (* Execute close sequence on local equipment *)
END_IF;

(* Check capacitor bank command *)
cap_enable := IEC104_SERVER_GET_SC('station1', 5010);
```

#### IEC104_SERVER_GET_SETPOINT — Get Setpoint Command

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `ioa` | INT | Information Object Address of the setpoint |

Returns: `REAL` — The last setpoint value from the controlling station.

```iecst
(* Read voltage setpoint from EMS *)
voltage_sp := IEC104_SERVER_GET_SETPOINT('station1', 6000);

(* Read active power curtailment setpoint *)
power_limit := IEC104_SERVER_GET_SETPOINT('station1', 6010);

(* Read tap position target *)
tap_target := IEC104_SERVER_GET_SETPOINT('station1', 6020);
```

---

### 3.4 Diagnostics and Lifecycle

#### IEC104_SERVER_GET_STATS — Server Statistics

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `STRING` — JSON-formatted connection and protocol statistics.

```iecst
stats := IEC104_SERVER_GET_STATS('station1');
(* Returns: {"connected_clients": 2, "interrogations": 156,
             "spontaneous_sent": 12847, "commands_received": 42,
             "testfr_sent": 3210, "testfr_recv": 3208} *)
```

#### IEC104_SERVER_DELETE — Remove Server

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server was removed. Stops listening and disconnects all clients first.

```iecst
ok := IEC104_SERVER_DELETE('station1');
```

#### IEC104_SERVER_LIST — List All Servers

Returns: `[]STRING` — Array of all active server names.

```iecst
servers := IEC104_SERVER_LIST();
(* Returns: ['station1', 'bay2'] *)
```

---

## 4. Complete Examples

### 4.1 Substation Gateway — Poll IEDs, Serve to SCADA

A common architecture: GoPLC sits at the substation as a data concentrator. It polls bay-level IEDs as an IEC 104 client, aggregates the data, and serves it to the utility control center as an IEC 104 server.

```iecst
PROGRAM POU_SubstationGateway
VAR
    init_done : BOOL := FALSE;
    ok : BOOL;

    (* Bay 1 measurements from IED *)
    bay1_breaker : INT;
    bay1_voltage : REAL;
    bay1_current : REAL;
    bay1_power : REAL;

    (* Bay 2 measurements from IED *)
    bay2_breaker : INT;
    bay2_voltage : REAL;
    bay2_current : REAL;
    bay2_power : REAL;

    (* Outgoing command from SCADA *)
    bay1_close_cmd : BOOL;
    bay1_voltage_sp : REAL;
END_VAR

IF NOT init_done THEN
    (* Create client connections to bay IEDs *)
    ok := IEC104_CLIENT_CREATE('bay1_ied', '10.0.10.1', 2404, 1);
    ok := IEC104_CLIENT_CREATE('bay2_ied', '10.0.10.2', 2404, 2);
    ok := IEC104_CLIENT_CONNECT('bay1_ied');
    ok := IEC104_CLIENT_CONNECT('bay2_ied');

    (* Create server for SCADA uplink *)
    ok := IEC104_SERVER_CREATE('scada_uplink', 2404, 47);
    ok := IEC104_SERVER_START('scada_uplink');

    init_done := TRUE;
END_IF;

(* === Read from bay IEDs === *)
bay1_breaker := IEC104_CLIENT_READ_DP('bay1_ied', 1000);
bay1_voltage := IEC104_CLIENT_READ_FLOAT('bay1_ied', 2000);
bay1_current := IEC104_CLIENT_READ_FLOAT('bay1_ied', 2001);
bay1_power := IEC104_CLIENT_READ_FLOAT('bay1_ied', 2002);

bay2_breaker := IEC104_CLIENT_READ_DP('bay2_ied', 1000);
bay2_voltage := IEC104_CLIENT_READ_FLOAT('bay2_ied', 2000);
bay2_current := IEC104_CLIENT_READ_FLOAT('bay2_ied', 2001);
bay2_power := IEC104_CLIENT_READ_FLOAT('bay2_ied', 2002);

(* === Publish aggregated data to SCADA === *)
IEC104_SERVER_SET_DP('scada_uplink', 1000, bay1_breaker);
IEC104_SERVER_SET_FLOAT('scada_uplink', 2000, bay1_voltage);
IEC104_SERVER_SET_FLOAT('scada_uplink', 2001, bay1_current);
IEC104_SERVER_SET_FLOAT('scada_uplink', 2002, bay1_power);

IEC104_SERVER_SET_DP('scada_uplink', 1100, bay2_breaker);
IEC104_SERVER_SET_FLOAT('scada_uplink', 2100, bay2_voltage);
IEC104_SERVER_SET_FLOAT('scada_uplink', 2101, bay2_current);
IEC104_SERVER_SET_FLOAT('scada_uplink', 2102, bay2_power);

(* === Forward SCADA commands to bay IED === *)
bay1_close_cmd := IEC104_SERVER_GET_SC('scada_uplink', 5000);
IF bay1_close_cmd THEN
    IEC104_CLIENT_WRITE_SC('bay1_ied', 5000, TRUE);
END_IF;

bay1_voltage_sp := IEC104_SERVER_GET_SETPOINT('scada_uplink', 6000);
IF bay1_voltage_sp > 0.0 THEN
    IEC104_CLIENT_WRITE_SETPOINT('bay1_ied', 6000, bay1_voltage_sp);
END_IF;
END_PROGRAM
```

### 4.2 Wind Farm SCADA Interface

A wind farm controller exposes turbine data to the grid operator's EMS via IEC 104 and accepts curtailment setpoints.

```iecst
PROGRAM POU_WindFarmSCADA
VAR
    init_done : BOOL := FALSE;
    ok : BOOL;
    i : INT;

    (* Turbine telemetry (from internal Modbus polling — not shown) *)
    turbine_active : ARRAY[1..20] OF BOOL;
    turbine_power : ARRAY[1..20] OF REAL;
    turbine_wind : ARRAY[1..20] OF REAL;
    total_power : REAL;
    total_energy : INT;

    (* Grid operator commands *)
    curtail_cmd : BOOL;
    power_limit : REAL;
END_VAR

IF NOT init_done THEN
    ok := IEC104_SERVER_CREATE('grid_ems', 2404, 100);
    ok := IEC104_SERVER_START('grid_ems');
    init_done := TRUE;
END_IF;

(* === Publish farm-level data === *)
total_power := 0.0;
FOR i := 1 TO 20 DO
    (* Per-turbine status: IOA 1..20 *)
    IEC104_SERVER_SET_SP('grid_ems', i, turbine_active[i]);

    (* Per-turbine power: IOA 2000..2019 *)
    IEC104_SERVER_SET_FLOAT('grid_ems', 1999 + i, turbine_power[i]);

    (* Per-turbine wind speed: IOA 2100..2119 *)
    IEC104_SERVER_SET_FLOAT('grid_ems', 2099 + i, turbine_wind[i]);

    IF turbine_active[i] THEN
        total_power := total_power + turbine_power[i];
    END_IF;
END_FOR;

(* Farm total power: IOA 2500 *)
IEC104_SERVER_SET_FLOAT('grid_ems', 2500, total_power);

(* Cumulative energy: IOA 4000 *)
IEC104_SERVER_SET_COUNTER('grid_ems', 4000, total_energy);

(* === Receive grid operator commands === *)
curtail_cmd := IEC104_SERVER_GET_SC('grid_ems', 5000);
power_limit := IEC104_SERVER_GET_SETPOINT('grid_ems', 6000);

IF curtail_cmd AND power_limit > 0.0 THEN
    (* Apply curtailment to turbine controllers *)
END_IF;
END_PROGRAM
```

### 4.3 Redundant SCADA Polling with Failover

Two GoPLC instances poll the same substation. The primary handles commands; the secondary monitors and takes over if the primary disconnects.

```iecst
PROGRAM POU_RedundantPoll
VAR
    init_done : BOOL := FALSE;
    ok : BOOL;
    is_primary : BOOL := TRUE;  (* Set by configuration *)

    (* Substation data *)
    breaker_status : INT;
    bus_voltage : REAL;
    line_current : REAL;
END_VAR

IF NOT init_done THEN
    ok := IEC104_CLIENT_CREATE('sub1', '10.0.0.100', 2404, 1);
    ok := IEC104_CLIENT_CONNECT('sub1');
    init_done := TRUE;
END_IF;

IF NOT IEC104_CLIENT_IS_CONNECTED('sub1') THEN
    IEC104_CLIENT_CONNECT('sub1');
END_IF;

(* Read — both primary and secondary receive data *)
breaker_status := IEC104_CLIENT_READ_DP('sub1', 1000);
bus_voltage := IEC104_CLIENT_READ_FLOAT('sub1', 2000);
line_current := IEC104_CLIENT_READ_FLOAT('sub1', 2001);

(* Write — only primary sends commands *)
IF is_primary THEN
    (* Command logic here *)
END_IF;
END_PROGRAM
```

### 4.4 Protocol Translation: IEC 104 to Modbus TCP

Bridge legacy Modbus field devices into an IEC 104 SCADA system. GoPLC reads Modbus registers and publishes them as IEC 104 data objects.

```iecst
PROGRAM POU_IEC104ModbusBridge
VAR
    init_done : BOOL := FALSE;
    ok : BOOL;

    (* Modbus data (from ModbusTCPClientRead — see Modbus guide) *)
    flow_rate : REAL;
    tank_level : REAL;
    pump_running : BOOL;
    total_volume : INT;

    (* SCADA commands *)
    pump_cmd : BOOL;
    flow_sp : REAL;
END_VAR

IF NOT init_done THEN
    (* Modbus client to field device — see Modbus TCP guide *)
    ok := MB_CLIENT_CREATE('flowmeter', '10.0.0.50', 502);
    ok := MB_CLIENT_CONNECT('flowmeter');

    (* IEC 104 server for SCADA *)
    ok := IEC104_SERVER_CREATE('water_scada', 2404, 10);
    ok := IEC104_SERVER_START('water_scada');

    init_done := TRUE;
END_IF;

(* === Read Modbus, publish IEC 104 === *)
IEC104_SERVER_SET_SP('water_scada', 1, pump_running);
IEC104_SERVER_SET_FLOAT('water_scada', 2000, flow_rate);
IEC104_SERVER_SET_FLOAT('water_scada', 2001, tank_level);
IEC104_SERVER_SET_COUNTER('water_scada', 4000, total_volume);

(* === Receive SCADA commands, write Modbus === *)
pump_cmd := IEC104_SERVER_GET_SC('water_scada', 5000);
flow_sp := IEC104_SERVER_GET_SETPOINT('water_scada', 6000);
END_PROGRAM
```

---

## 5. Protocol Details

### 5.1 APCI (Application Protocol Control Information)

IEC 104 wraps every ASDU in an APCI frame over TCP. The runtime manages all APCI framing automatically — you never build frames manually.

```
┌──────┬──────┬───────────────────────┬────────────────────┐
│ 0x68 │ LEN  │ Control Field (4B)    │ ASDU (variable)    │
│ start│      │                       │                    │
└──────┴──────┴───────────────────────┴────────────────────┘
```

Three frame formats:

| Format | Purpose | Control Field |
|--------|---------|---------------|
| **I-format** | Data transfer (numbered) | Send seq + Recv seq |
| **S-format** | Supervisory (ACK only) | Recv seq |
| **U-format** | Unnumbered control | STARTDT / STOPDT / TESTFR |

### 5.2 Connection Supervision Timers

The runtime manages the four IEC 104 timers automatically:

| Timer | Default | Purpose |
|-------|---------|---------|
| **t0** | 30 s | TCP connection establishment timeout |
| **t1** | 15 s | Send/test APDU timeout |
| **t2** | 10 s | Acknowledgment timeout (triggers S-format) |
| **t3** | 20 s | Idle timeout (triggers TESTFR) |

> **No configuration needed.** The defaults conform to IEC 60870-5-104 Section 10 and work with all major SCADA vendors (ABB, Siemens, GE, Schneider, Hitachi Energy). The runtime sends TESTFR keepalives automatically.

### 5.3 General Interrogation

When a client connects (or reconnects), the runtime automatically issues a general interrogation command (C_IC_NA_1, type 100) to populate the complete point table. The controlled station responds with all configured data points. Subsequent updates arrive as spontaneous transmissions.

### 5.4 Cause of Transmission (COT)

Every ASDU carries a reason code. The runtime handles these internally, but understanding them aids debugging:

| COT | Value | Meaning |
|-----|-------|---------|
| Periodic | 1 | Cyclic transmission |
| Background | 2 | Background scan |
| Spontaneous | 3 | Value changed |
| Initialized | 4 | Station initialized |
| Request | 5 | Requested by client |
| Activation | 6 | Command activation |
| ActivationCon | 7 | Command confirmed |
| Deactivation | 8 | Command deactivation |
| DeactivationCon | 9 | Deactivation confirmed |
| ActivationTerm | 10 | Command terminated |
| Interrogated | 20 | Response to GI (station) |

---

## 6. Troubleshooting

### Connection fails immediately

- Verify the controlled station is reachable: `ping 10.0.0.100`
- Confirm port 2404 is open: `nc -zv 10.0.0.100 2404`
- Check the common address matches the station configuration — mismatched CASDU causes silent rejection

### Connected but no data

- The runtime sends general interrogation automatically on connect. If the controlled station ignores GI, verify the common address matches.
- Some stations require a specific originator address — the default (0) works with most implementations.

### Commands rejected

- Check the ASDU type expected by the controlled station. Some stations require time-tagged commands (type 58/63 instead of 45/50).
- Verify the IOA is configured as a command point at the controlled station. Writing to a monitoring IOA is rejected.
- Confirm select-before-operate (SBO) is not required. If SBO is mandatory, the direct execute command will be rejected.

### Spontaneous data not arriving

- Ensure STARTDT was confirmed. Check `IEC104_CLIENT_IS_CONNECTED` returns TRUE.
- The controlled station may have spontaneous transmission disabled for some points — verify station configuration.
- Check that t3 keepalives are working — a firewall may be dropping idle TCP connections.

### Double point stuck at 0 or 3

- Value 0 (indeterminate) during switching is normal and transient.
- Value 3 (indeterminate/fault) means the open and close contacts disagree — check the field wiring and auxiliary contacts on the switchgear.

---

## Appendix A: Quick Reference

### Client Functions (13)

| Function | Returns | Description |
|----------|---------|-------------|
| `IEC104_CLIENT_CREATE(name, host, port [, commonAddr])` | BOOL | Create named client connection |
| `IEC104_CLIENT_CONNECT(name)` | BOOL | Establish TCP + STARTDT + GI |
| `IEC104_CLIENT_DISCONNECT(name)` | BOOL | STOPDT + close TCP |
| `IEC104_CLIENT_IS_CONNECTED(name)` | BOOL | Check connection and data transfer state |
| `IEC104_CLIENT_READ_SP(name, ioa)` | BOOL | Read single point |
| `IEC104_CLIENT_READ_DP(name, ioa)` | INT | Read double point (0-3) |
| `IEC104_CLIENT_READ_FLOAT(name, ioa)` | REAL | Read measured float |
| `IEC104_CLIENT_READ_SCALED(name, ioa)` | INT | Read measured scaled |
| `IEC104_CLIENT_READ_COUNTER(name, ioa)` | INT | Read integrated total |
| `IEC104_CLIENT_WRITE_SC(name, ioa, value)` | BOOL | Send single command |
| `IEC104_CLIENT_WRITE_SETPOINT(name, ioa, value)` | BOOL | Send setpoint command |
| `IEC104_CLIENT_DELETE(name)` | BOOL | Remove client connection |
| `IEC104_CLIENT_LIST()` | []STRING | List all client connections |

### Server Functions (14)

| Function | Returns | Description |
|----------|---------|-------------|
| `IEC104_SERVER_CREATE(name, port [, commonAddr])` | BOOL | Create named server |
| `IEC104_SERVER_START(name)` | BOOL | Begin listening for clients |
| `IEC104_SERVER_STOP(name)` | BOOL | Stop listening |
| `IEC104_SERVER_IS_CONNECTED(name)` | BOOL | Check if any client is connected |
| `IEC104_SERVER_SET_SP(name, ioa, value)` | BOOL | Set single point |
| `IEC104_SERVER_SET_DP(name, ioa, value)` | BOOL | Set double point (0-3) |
| `IEC104_SERVER_SET_FLOAT(name, ioa, value)` | BOOL | Set measured float |
| `IEC104_SERVER_SET_SCALED(name, ioa, value)` | BOOL | Set measured scaled |
| `IEC104_SERVER_SET_COUNTER(name, ioa, value)` | BOOL | Set integrated total |
| `IEC104_SERVER_GET_SC(name, ioa)` | BOOL | Get single command from client |
| `IEC104_SERVER_GET_SETPOINT(name, ioa)` | REAL | Get setpoint from client |
| `IEC104_SERVER_GET_STATS(name)` | STRING | Connection/protocol statistics (JSON) |
| `IEC104_SERVER_DELETE(name)` | BOOL | Remove server |
| `IEC104_SERVER_LIST()` | []STRING | List all servers |

---

## Appendix B: ASDU Types Used

| Type ID | Name | Description | GoPLC Function |
|---------|------|-------------|----------------|
| 1 | M_SP_NA_1 | Single point — static | ReadSP / SetSP |
| 3 | M_DP_NA_1 | Double point — static | ReadDP / SetDP |
| 11 | M_ME_NB_1 | Measured scaled — static | ReadScaled / SetScaled |
| 13 | M_ME_NC_1 | Measured float — static | ReadFloat / SetFloat |
| 15 | M_IT_NA_1 | Integrated total — static | ReadCounter / SetCounter |
| 30 | M_SP_TB_1 | Single point — time-tagged | ReadSP / SetSP |
| 31 | M_DP_TB_1 | Double point — time-tagged | ReadDP / SetDP |
| 35 | M_ME_TE_1 | Measured scaled — time-tagged | ReadScaled / SetScaled |
| 36 | M_ME_TF_1 | Measured float — time-tagged | ReadFloat / SetFloat |
| 37 | M_IT_TB_1 | Integrated total — time-tagged | ReadCounter / SetCounter |
| 45 | C_SC_NA_1 | Single command | WriteSC / GetSC |
| 50 | C_SE_NC_1 | Setpoint command (float) | WriteSetpoint / GetSetpoint |
| 58 | C_SC_TA_1 | Single command — time-tagged | WriteSC / GetSC |
| 63 | C_SE_TC_1 | Setpoint command (float) — time-tagged | WriteSetpoint / GetSetpoint |
| 100 | C_IC_NA_1 | General interrogation | (automatic on connect) |
| 101 | C_CI_NA_1 | Counter interrogation | (automatic for counters) |
| 103 | C_CS_NA_1 | Clock sync command | (automatic) |

---

*GoPLC v1.0.533 | IEC 60870-5-104 Client + Server | IEC 61131-3 Structured Text*

*(c) 2026 JMB Technical Services LLC. All rights reserved.*
