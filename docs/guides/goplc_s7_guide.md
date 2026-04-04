# GoPLC Siemens S7 Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC implements a complete **Siemens S7 communication** stack — both client and server — callable directly from IEC 61131-3 Structured Text. No external libraries, no TIA Portal add-ons, no code generation. You create connections, read/write data blocks and process image areas, and run an S7 server for testing — all with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `S7ClientCreate` / `S7ReadDB*` / `S7WriteDB*` / `S7ReadI` / `S7WriteM` | Read/write DB blocks, inputs, outputs, markers on S7-300/400/1200/1500 PLCs |
| **Server** | `S7ServerCreate` / `S7ServerSetDB` / `S7ServerGetM` | Simulate an S7 PLC for TIA Portal testing, HMI development, or protocol bridging |

Both roles can run simultaneously. A single GoPLC instance can poll two S7-1500 PLCs as a client while serving data blocks to a WinCC HMI — all from the same ST program.

### System Diagram

```
┌──────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)              │
│                                                          │
│  ┌──────────────────────┐  ┌──────────────────────────┐  │
│  │ ST Program (Client)  │  │ ST Program (Server)      │  │
│  │                      │  │                          │  │
│  │ S7ClientCreate()     │  │ S7ServerCreate()         │  │
│  │ S7ClientConnect()    │  │ S7ServerStart()          │  │
│  │ S7ReadDBReal()       │  │ S7ServerSetDB()          │  │
│  │ S7WriteDBWord()      │  │ S7ServerGetM()           │  │
│  │ S7ReadI() S7ReadM()  │  │ S7ServerSetI/Q()        │  │
│  └──────────┬───────────┘  └──────────┬───────────────┘  │
│             │                         │                  │
│             │  S7comm (ISO-on-TCP)    │  S7comm Server   │
│             │  (connects out)         │  (listens)       │
└─────────────┼─────────────────────────┼──────────────────┘
              │                         │
              │  TCP Port 102           │  TCP (configurable)
              │  (default)              │
              ▼                         ▼
┌─────────────────────────┐   ┌─────────────────────────────┐
│  Siemens S7 PLC         │   │  Remote S7 Client            │
│                         │   │                               │
│  S7-300, S7-400,        │   │  TIA Portal, WinCC,          │
│  S7-1200, S7-1500       │   │  HMI, another PLC, SCADA     │
└─────────────────────────┘   └───────────────────────────────┘
```

### S7 Data Model

Siemens PLCs organize memory into distinct areas:

| Area | S7 Code | Access | Description |
|------|---------|--------|-------------|
| **Data Blocks (DB)** | 0x84 | Read/Write | User-defined data storage — the primary way to exchange structured data |
| **Inputs (I / PE)** | 0x81 | Read-Only* | Physical input image (sensors, switches) |
| **Outputs (Q / PA)** | 0x82 | Read/Write* | Physical output image (actuators, valves) |
| **Markers (M / Flags)** | 0x83 | Read/Write | Internal memory bits/bytes — often used for HMI exchange |

> **DB blocks are king:** In modern S7 programming, data blocks are the standard interface between PLC and external systems. Inputs and outputs are typically mapped into DBs by the PLC program. Direct I/Q access is useful for diagnostics and simple configurations.

### S7 Connection Parameters

Every S7 connection requires **rack** and **slot** numbers that identify which CPU to talk to:

| PLC Family | Rack | Slot | Notes |
|------------|------|------|-------|
| **S7-300** | 0 | 2 | CPU always in slot 2 |
| **S7-400** | 0 | 2-17 | Check hardware config in STEP 7 |
| **S7-1200** | 0 | 0 | Single slot, rack 0 |
| **S7-1500** | 0 | 0 | Single slot, rack 0 |

> **S7-1200/1500 access:** These PLCs require **PUT/GET** communication to be enabled in TIA Portal: *Device configuration > Protection & Security > Connection mechanisms > Permit access with PUT/GET*. Without this setting, connection attempts will be rejected.

---

## 2. Client Functions

The S7 client connects to Siemens PLCs over ISO-on-TCP (port 102) and performs typed read/write operations on data blocks and process image areas.

### 2.1 Connection Management

#### S7ClientCreate — Create Named Connection

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique connection name |
| `host` | STRING | Yes | IP address or hostname of the S7 PLC |
| `rack` | INT | Yes | PLC rack number |
| `slot` | INT | Yes | PLC slot number |
| `port` | INT | No | TCP port (default 102) |
| `timeout_ms` | INT | No | Connection timeout in milliseconds (default 5000) |
| `poll_rate_ms` | INT | No | Background poll interval in milliseconds (default 100) |

Returns: `BOOL` — TRUE if the connection was created successfully.

```iecst
(* Connect to S7-1500 — rack 0, slot 0 *)
ok := S7ClientCreate('plc1', '10.0.0.34', 0, 0);

(* Connect to S7-300 — rack 0, slot 2, custom timeout *)
ok := S7ClientCreate('plc2', '10.0.0.35', 0, 2, 102, 3000);

(* Connect with fast polling for time-critical data *)
ok := S7ClientCreate('plc3', '10.0.0.36', 0, 0, 102, 5000, 50);
```

> **Named connections:** Every S7 client connection has a unique string name. This name is used in all subsequent calls. Create one connection per PLC — multiple connections to the same PLC waste resources and may hit the PLC's connection limit.

#### S7ClientConnect — Establish S7 Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from S7ClientCreate |

Returns: `BOOL` — TRUE if connected successfully.

```iecst
ok := S7ClientConnect('plc1');
```

> **Connection sequence:** S7 connection involves three steps: TCP connect, ISO-on-TCP COTP negotiation, and S7 session setup. `S7ClientConnect` handles all three. If any step fails, the function returns FALSE.

#### S7ClientDisconnect — Close S7 Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully.

```iecst
ok := S7ClientDisconnect('plc1');
```

#### S7ClientIsConnected — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the S7 session is active.

```iecst
IF NOT S7ClientIsConnected('plc1') THEN
    S7ClientConnect('plc1');
END_IF;
```

#### S7ClientDelete — Remove Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the connection was deleted.

```iecst
S7ClientDisconnect('plc1');
ok := S7ClientDelete('plc1');
```

#### S7ClientList — List All Connections

Returns: `[]STRING` — Array of all client connection names.

```iecst
clients := S7ClientList();
(* Returns: ['plc1', 'plc2'] *)
```

#### S7ClientGetStats — Connection Statistics

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `MAP` — Statistics including request count, response count, error count, and poll metrics.

```iecst
stats := S7ClientGetStats('plc1');
(* Returns: {"requests": 12450, "responses": 12448, "errors": 2,
             "poll_count": 8200, "avg_poll_ms": 12} *)
```

> **Error tracking:** Compare requests vs. responses to detect communication problems. A growing error count may indicate network issues, PLC CPU stop, or resource limits on the PLC.

#### Example: Connection Lifecycle

```iecst
PROGRAM POU_S7Init
VAR
    state : INT := 0;
    ok : BOOL;
    retry_count : INT := 0;
END_VAR

CASE state OF
    0: (* Create connection to S7-1500 *)
        ok := S7ClientCreate('plc1', '10.0.0.34', 0, 0);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := S7ClientConnect('plc1');
        IF ok THEN
            retry_count := 0;
            state := 10;
        ELSE
            retry_count := retry_count + 1;
            IF retry_count > 5 THEN
                state := 99;   (* Fault *)
            END_IF;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT S7ClientIsConnected('plc1') THEN
            state := 1;  (* Reconnect *)
        END_IF;

    99: (* Fault — connection failed *)
        (* Log error, wait for operator intervention *)
END_CASE;
END_PROGRAM
```

---

### 2.2 DB Read Functions

Data block reads are the primary way to get data from an S7 PLC. Each function reads a specific data type at a byte address within a numbered DB.

#### S7ReadDBByte — Read Unsigned Byte (USINT)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset within the DB |

Returns: `INT` — Unsigned 8-bit value (0-255).

```iecst
(* Read byte at DB10.DBB0 *)
value := S7ReadDBByte('plc1', 10, 0);
```

#### S7ReadDBWord — Read Unsigned Word (UINT)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset (must be even for word alignment) |

Returns: `INT` — Unsigned 16-bit value (0-65535).

```iecst
(* Read word at DB10.DBW2 *)
value := S7ReadDBWord('plc1', 10, 2);
```

#### S7ReadDBDword — Read Unsigned Double Word (UDINT)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset (should be 4-byte aligned) |

Returns: `DINT` — Unsigned 32-bit value.

```iecst
(* Read double word at DB10.DBD4 *)
value := S7ReadDBDword('plc1', 10, 4);
```

#### S7ReadDBInt — Read Signed Integer (INT, 16-bit)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset |

Returns: `INT` — Signed 16-bit value (-32768 to 32767).

```iecst
(* Read signed integer at DB10.DBW8 *)
temperature := S7ReadDBInt('plc1', 10, 8);
(* Returns: -15 for a below-zero temperature *)
```

#### S7ReadDBDint — Read Signed Double Integer (DINT, 32-bit)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset |

Returns: `DINT` — Signed 32-bit value.

```iecst
(* Read signed 32-bit integer at DB10.DBD10 *)
encoder_count := S7ReadDBDint('plc1', 10, 10);
(* Returns: -142857 *)
```

#### S7ReadDBReal — Read Floating Point (REAL, 32-bit)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset |

Returns: `REAL` — IEEE 754 single-precision float.

```iecst
(* Read real at DB10.DBD14 — motor speed in RPM *)
speed := S7ReadDBReal('plc1', 10, 14);
(* Returns: 1487.5 *)
```

> **Byte order:** Siemens PLCs use big-endian byte order. GoPLC handles the byte-swapping automatically — you always get native values.

#### S7ReadDBBool — Read Single Bit

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset |
| `bit` | INT | Bit number within the byte (0-7) |

Returns: `BOOL` — TRUE or FALSE.

```iecst
(* Read DB10.DBX0.0 — first bit of first byte *)
motor_running := S7ReadDBBool('plc1', 10, 0, 0);

(* Read DB10.DBX0.3 — fourth bit of first byte *)
alarm_active := S7ReadDBBool('plc1', 10, 0, 3);

(* Read DB10.DBX1.7 — eighth bit of second byte *)
limit_reached := S7ReadDBBool('plc1', 10, 1, 7);
```

> **Bit addressing in S7:** Bit 0 is the least significant bit. `DBX0.0` is byte 0, bit 0. `DBX0.7` is byte 0, bit 7. `DBX1.0` is byte 1, bit 0. This matches the TIA Portal variable table layout exactly.

#### Example: Reading a Complete DB Structure

```iecst
PROGRAM POU_ReadDB
VAR
    (* Mapped to S7 PLC DB10 layout:
       Offset 0:  BOOL  - motor_running   (DBX0.0)
       Offset 0:  BOOL  - fault_active    (DBX0.1)
       Offset 2:  INT   - speed_setpoint  (DBW2)
       Offset 4:  INT   - speed_actual    (DBW4)
       Offset 6:  REAL  - temperature     (DBD6)
       Offset 10: REAL  - pressure        (DBD10)
       Offset 14: DINT  - total_cycles    (DBD14)
    *)
    motor_running : BOOL;
    fault_active : BOOL;
    speed_setpoint : INT;
    speed_actual : INT;
    temperature : REAL;
    pressure : REAL;
    total_cycles : DINT;
END_VAR

(* Read all values from DB10 *)
motor_running := S7ReadDBBool('plc1', 10, 0, 0);
fault_active := S7ReadDBBool('plc1', 10, 0, 1);
speed_setpoint := S7ReadDBInt('plc1', 10, 2);
speed_actual := S7ReadDBInt('plc1', 10, 4);
temperature := S7ReadDBReal('plc1', 10, 6);
pressure := S7ReadDBReal('plc1', 10, 10);
total_cycles := S7ReadDBDint('plc1', 10, 14);
END_PROGRAM
```

---

### 2.3 DB Write Functions

Each write function mirrors its read counterpart. All return `BOOL` — TRUE if the write was acknowledged by the PLC.

#### S7WriteDBByte — Write Unsigned Byte

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset |
| `value` | INT | Value to write (0-255) |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
ok := S7WriteDBByte('plc1', 10, 0, 128);
```

#### S7WriteDBWord — Write Unsigned Word

```iecst
ok := S7WriteDBWord('plc1', 10, 2, 5000);
```

#### S7WriteDBDword — Write Unsigned Double Word

```iecst
ok := S7WriteDBDword('plc1', 10, 4, 1000000);
```

#### S7WriteDBInt — Write Signed Integer (16-bit)

```iecst
(* Write speed setpoint — signed allows negative values *)
ok := S7WriteDBInt('plc1', 10, 2, -500);
```

#### S7WriteDBDint — Write Signed Double Integer (32-bit)

```iecst
ok := S7WriteDBDint('plc1', 10, 10, 142857);
```

#### S7WriteDBReal — Write Floating Point

```iecst
(* Write temperature setpoint *)
ok := S7WriteDBReal('plc1', 10, 14, 72.5);
```

#### S7WriteDBBool — Write Single Bit

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Byte offset |
| `bit` | INT | Bit number (0-7) |
| `value` | BOOL | TRUE or FALSE |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Set motor run command — DB10.DBX0.0 *)
ok := S7WriteDBBool('plc1', 10, 0, 0, TRUE);

(* Clear alarm acknowledge — DB10.DBX0.1 *)
ok := S7WriteDBBool('plc1', 10, 0, 1, FALSE);
```

> **Write atomicity:** Each S7WriteDB call is a separate S7 protocol transaction. If you need to write multiple values atomically (e.g., a setpoint and its enable bit), write them to a staging DB and have the PLC program copy them in a single scan.

#### Example: Writing Commands to a PLC

```iecst
PROGRAM POU_WriteDB
VAR
    ok : BOOL;
    speed_cmd : INT := 1500;
    temp_setpoint : REAL := 72.5;
    start_cmd : BOOL := FALSE;
END_VAR

(* Write command values to DB20 *)
ok := S7WriteDBInt('plc1', 20, 0, speed_cmd);
ok := S7WriteDBReal('plc1', 20, 2, temp_setpoint);
ok := S7WriteDBBool('plc1', 20, 6, 0, start_cmd);
END_PROGRAM
```

---

### 2.4 Area Read Functions (Inputs, Outputs, Markers)

These functions read directly from the PLC's process image areas — inputs (I), outputs (Q), and markers/flags (M). Byte-level reads return arrays for reading multiple consecutive bytes.

#### S7ReadI — Read Input Bytes

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `byteAddr` | INT | Starting byte offset |
| `count` | INT | Number of bytes to read |

Returns: `[]INT` — Array of byte values (0-255 each).

```iecst
(* Read 4 input bytes starting at IB0 *)
inputs := S7ReadI('plc1', 0, 4);
(* inputs[0] = IB0, inputs[1] = IB1, inputs[2] = IB2, inputs[3] = IB3 *)
```

#### S7ReadQ — Read Output Bytes

```iecst
(* Read 2 output bytes starting at QB0 *)
outputs := S7ReadQ('plc1', 0, 2);
```

#### S7ReadM — Read Marker Bytes

```iecst
(* Read 8 marker bytes starting at MB0 *)
markers := S7ReadM('plc1', 0, 8);
```

#### S7ReadIBool — Read Input Bit

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `byteAddr` | INT | Byte offset |
| `bit` | INT | Bit number (0-7) |

Returns: `BOOL` — Input state.

```iecst
(* Read I0.0 — first input bit *)
sensor := S7ReadIBool('plc1', 0, 0);

(* Read I1.5 — second byte, bit 5 *)
limit_sw := S7ReadIBool('plc1', 1, 5);
```

#### S7ReadQBool — Read Output Bit

```iecst
(* Read Q0.0 — first output bit *)
valve_state := S7ReadQBool('plc1', 0, 0);
```

#### S7ReadMBool — Read Marker Bit

```iecst
(* Read M0.0 — first marker bit *)
hmi_flag := S7ReadMBool('plc1', 0, 0);

(* Read M10.3 — commonly used for HMI handshake bits *)
ack_bit := S7ReadMBool('plc1', 10, 3);
```

#### Example: Reading Process Image

```iecst
PROGRAM POU_ReadIO
VAR
    (* Digital inputs *)
    start_button : BOOL;
    stop_button : BOOL;
    e_stop : BOOL;
    guard_door : BOOL;

    (* Markers for HMI exchange *)
    hmi_mode : INT;
    marker_bytes : ARRAY[0..3] OF INT;
END_VAR

(* Read individual input bits *)
start_button := S7ReadIBool('plc1', 0, 0);
stop_button := S7ReadIBool('plc1', 0, 1);
e_stop := S7ReadIBool('plc1', 0, 2);
guard_door := S7ReadIBool('plc1', 0, 3);

(* Read marker area as bytes *)
marker_bytes := S7ReadM('plc1', 0, 4);
END_PROGRAM
```

---

### 2.5 Area Write Functions (Outputs, Markers)

#### S7WriteM — Write Marker Bytes

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `byteAddr` | INT | Starting byte offset |
| `values` | []INT | Array of byte values to write |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Write 2 bytes to MB0 and MB1 *)
ok := S7WriteM('plc1', 0, [255, 128]);
```

#### S7WriteQ — Write Output Bytes

```iecst
(* Write 1 byte to QB0 *)
ok := S7WriteQ('plc1', 0, [16#FF]);
```

> **Direct output writes:** Writing to the output area (Q) directly overrides the PLC program's output image. This can cause unexpected actuator behavior. Use with extreme caution — in production, write to marker or DB areas and let the PLC program control the outputs.

#### S7WriteMBool — Write Marker Bit

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `byteAddr` | INT | Byte offset |
| `bit` | INT | Bit number (0-7) |
| `value` | BOOL | TRUE or FALSE |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Set M0.0 — handshake bit to PLC *)
ok := S7WriteMBool('plc1', 0, 0, TRUE);

(* Clear M10.7 — reset flag *)
ok := S7WriteMBool('plc1', 10, 7, FALSE);
```

#### S7WriteQBool — Write Output Bit

```iecst
(* Set Q0.0 — first output *)
ok := S7WriteQBool('plc1', 0, 0, TRUE);
```

---

### 2.6 Background Polling

#### S7AddPoll — Register a Polled Data Range

Adds a memory area to the background poll list. Polled data is refreshed automatically at the rate specified in `S7ClientCreate` (the `poll_rate_ms` parameter), so subsequent reads return cached values without blocking.

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `area` | STRING | Memory area: `'DB'`, `'I'`, `'Q'`, or `'M'` |
| `dbNumber` | INT | DB number (0 for I/Q/M areas) |
| `byteAddr` | INT | Starting byte offset |
| `byteCount` | INT | Number of bytes to poll |

Returns: `BOOL` — TRUE if the poll entry was added.

```iecst
(* Poll DB10 bytes 0-19 in the background *)
ok := S7AddPoll('plc1', 'DB', 10, 0, 20);

(* Poll input bytes 0-7 *)
ok := S7AddPoll('plc1', 'I', 0, 0, 8);

(* Poll marker bytes 0-15 *)
ok := S7AddPoll('plc1', 'M', 0, 0, 16);
```

> **Polling vs. on-demand reads:** Without polling, each `S7ReadDB*` call generates a network request (5-20 ms round-trip). With polling, a background goroutine refreshes the data at the configured rate, and reads return instantly from the cache. Use polling for frequently-read data; use on-demand reads for infrequent or diagnostic access.

#### Example: Polled Data Access

```iecst
PROGRAM POU_PolledRead
VAR
    state : INT := 0;
    ok : BOOL;
    speed : REAL;
    temp : REAL;
    running : BOOL;
END_VAR

CASE state OF
    0: (* Setup connection and polling *)
        ok := S7ClientCreate('plc1', '10.0.0.34', 0, 0, 102, 5000, 50);
        IF ok THEN state := 1; END_IF;

    1: (* Connect *)
        ok := S7ClientConnect('plc1');
        IF ok THEN state := 2; END_IF;

    2: (* Register poll ranges *)
        S7AddPoll('plc1', 'DB', 10, 0, 20);
        state := 10;

    10: (* Running — reads return cached polled data, zero latency *)
        speed := S7ReadDBReal('plc1', 10, 0);
        temp := S7ReadDBReal('plc1', 10, 4);
        running := S7ReadDBBool('plc1', 10, 8, 0);

        IF NOT S7ClientIsConnected('plc1') THEN
            state := 1;
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 3. Server Functions

The S7 server emulates a Siemens PLC, accepting incoming S7 connections and exposing DB blocks, inputs, outputs, and markers. This is invaluable for testing TIA Portal projects, developing HMI screens, or acting as a protocol bridge.

### 3.1 Server Management

#### S7ServerCreate — Create Named Server

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique server name |
| `port` | INT | Yes | TCP listen port |

Returns: `BOOL` — TRUE if the server was created.

```iecst
(* Create S7 server on the standard S7 port *)
ok := S7ServerCreate('sim', 102);

(* Create on a non-standard port to avoid permission issues *)
ok := S7ServerCreate('sim', 1102);
```

> **Port 102:** The standard ISO-on-TCP port (102) may require root/admin privileges. During development, use a port above 1024. TIA Portal and WinCC can be configured to connect to non-standard ports.

#### S7ServerStart — Begin Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server started listening.

```iecst
ok := S7ServerStart('sim');
```

#### S7ServerStop — Stop Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server stopped.

```iecst
ok := S7ServerStop('sim');
```

#### S7ServerIsRunning — Check Server State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server is actively listening.

```iecst
IF NOT S7ServerIsRunning('sim') THEN
    S7ServerStart('sim');
END_IF;
```

#### S7ServerDelete — Remove Server

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server was deleted.

```iecst
S7ServerStop('sim');
ok := S7ServerDelete('sim');
```

#### S7ServerList — List All Servers

Returns: `[]STRING` — Array of all server names.

```iecst
servers := S7ServerList();
(* Returns: ['sim'] *)
```

---

### 3.2 DB Area Access

#### S7ServerSetDB — Write to Server DB Area

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Starting byte offset |
| `values` | []INT | Array of byte values to write |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Write 4 bytes to DB10 starting at offset 0 *)
ok := S7ServerSetDB('sim', 10, 0, [16#00, 16#FF, 16#12, 16#34]);

(* Pre-populate a REAL value (72.5 = 42 91 00 00 in IEEE 754 big-endian) *)
ok := S7ServerSetDB('sim', 10, 4, [16#42, 16#91, 16#00, 16#00]);
```

#### S7ServerGetDB — Read from Server DB Area

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `db` | INT | Data block number |
| `byteAddr` | INT | Starting byte offset |
| `count` | INT | Number of bytes to read |

Returns: `[]INT` — Array of byte values.

```iecst
(* Read 10 bytes from DB10 *)
data := S7ServerGetDB('sim', 10, 0, 10);
```

> **Server DB storage:** The server automatically allocates DB storage on first access. You don't need to pre-define DB sizes — just write to any DB number and offset.

---

### 3.3 Marker Area Access

#### S7ServerSetM — Write to Server Marker Area

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `byteAddr` | INT | Starting byte offset |
| `values` | []INT | Array of byte values |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Set MB0 = 0xFF, MB1 = 0x00 *)
ok := S7ServerSetM('sim', 0, [16#FF, 16#00]);
```

#### S7ServerGetM — Read from Server Marker Area

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `byteAddr` | INT | Starting byte offset |
| `count` | INT | Number of bytes to read |

Returns: `[]INT` — Array of byte values.

```iecst
markers := S7ServerGetM('sim', 0, 4);
```

---

### 3.4 Input/Output Area Access

#### S7ServerSetI — Write to Server Input Area

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `byteAddr` | INT | Starting byte offset |
| `values` | []INT | Array of byte values |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Simulate input byte IB0 with all bits set *)
ok := S7ServerSetI('sim', 0, [16#FF]);
```

#### S7ServerGetI — Read from Server Input Area

```iecst
inputs := S7ServerGetI('sim', 0, 4);
```

#### S7ServerSetQ — Write to Server Output Area

```iecst
ok := S7ServerSetQ('sim', 0, [16#A5]);
```

#### S7ServerGetQ — Read from Server Output Area

```iecst
outputs := S7ServerGetQ('sim', 0, 2);
```

> **Server areas as simulation:** Use `S7ServerSetI` to simulate sensor inputs for TIA Portal programs. Use `S7ServerGetQ` to verify that the PLC program drives the correct outputs. This creates a hardware-in-the-loop test environment without physical I/O.

#### Example: Server Lifecycle

```iecst
PROGRAM POU_S7Server
VAR
    state : INT := 0;
    ok : BOOL;
    scan_count : DINT := 0;
END_VAR

CASE state OF
    0: (* Create server *)
        ok := S7ServerCreate('sim', 1102);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Start listening *)
        ok := S7ServerStart('sim');
        IF ok THEN
            state := 2;
        END_IF;

    2: (* Pre-populate data blocks *)
        S7ServerSetDB('sim', 10, 0, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                      0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        state := 10;

    10: (* Running — update simulated data *)
        scan_count := scan_count + 1;

        (* Simulate changing process values *)
        S7ServerSetDB('sim', 10, 0, [DINT_TO_INT(scan_count MOD 256)]);

        IF NOT S7ServerIsRunning('sim') THEN
            state := 1;
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 4. Complete Example: Reading Process Data from an S7-1500

This example connects to an S7-1500 PLC running a packaging line, reads process data from DB10, and writes setpoints to DB20. The DB layout matches a typical TIA Portal project structure.

### PLC DB Layout

| DB | Offset | Type | Variable | Description |
|----|--------|------|----------|-------------|
| DB10 | 0.0 | BOOL | line_running | Line status |
| DB10 | 0.1 | BOOL | fault_active | Active fault |
| DB10 | 0.2 | BOOL | infeed_ready | Infeed conveyor ready |
| DB10 | 2 | INT | line_speed | Actual speed (packages/min) |
| DB10 | 4 | INT | reject_count | Rejected packages |
| DB10 | 6 | REAL | temperature | Seal bar temperature (deg C) |
| DB10 | 10 | REAL | pressure | Vacuum pressure (mbar) |
| DB10 | 14 | DINT | total_count | Total packages since reset |
| DB20 | 0.0 | BOOL | start_cmd | Start command |
| DB20 | 0.1 | BOOL | stop_cmd | Stop command |
| DB20 | 2 | INT | speed_setpoint | Speed setpoint (packages/min) |
| DB20 | 4 | REAL | temp_setpoint | Temperature setpoint (deg C) |

```iecst
PROGRAM POU_PackagingLine
VAR
    (* Connection state *)
    state : INT := 0;
    ok : BOOL;
    retry_count : INT := 0;

    (* Process data from DB10 *)
    line_running : BOOL;
    fault_active : BOOL;
    infeed_ready : BOOL;
    line_speed : INT;
    reject_count : INT;
    temperature : REAL;
    pressure : REAL;
    total_count : DINT;

    (* Commands to DB20 *)
    start_cmd : BOOL := FALSE;
    stop_cmd : BOOL := FALSE;
    speed_setpoint : INT := 120;
    temp_setpoint : REAL := 185.0;
END_VAR

CASE state OF
    0: (* Create connection to S7-1500 *)
        ok := S7ClientCreate('pack_plc', '10.0.0.34', 0, 0);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := S7ClientConnect('pack_plc');
        IF ok THEN
            retry_count := 0;
            state := 2;
        ELSE
            retry_count := retry_count + 1;
            IF retry_count > 5 THEN
                state := 99;
            END_IF;
        END_IF;

    2: (* Register poll for fast reads *)
        S7AddPoll('pack_plc', 'DB', 10, 0, 18);
        state := 10;

    10: (* Running — read process data *)
        IF NOT S7ClientIsConnected('pack_plc') THEN
            state := 1;
        END_IF;

        (* Read DB10 — status and feedback *)
        line_running := S7ReadDBBool('pack_plc', 10, 0, 0);
        fault_active := S7ReadDBBool('pack_plc', 10, 0, 1);
        infeed_ready := S7ReadDBBool('pack_plc', 10, 0, 2);
        line_speed := S7ReadDBInt('pack_plc', 10, 2);
        reject_count := S7ReadDBInt('pack_plc', 10, 4);
        temperature := S7ReadDBReal('pack_plc', 10, 6);
        pressure := S7ReadDBReal('pack_plc', 10, 10);
        total_count := S7ReadDBDint('pack_plc', 10, 14);

        state := 11;

    11: (* Write commands to DB20 *)
        ok := S7WriteDBBool('pack_plc', 20, 0, 0, start_cmd);
        ok := S7WriteDBBool('pack_plc', 20, 0, 1, stop_cmd);
        ok := S7WriteDBInt('pack_plc', 20, 2, speed_setpoint);
        ok := S7WriteDBReal('pack_plc', 20, 4, temp_setpoint);

        (* Auto-clear one-shot commands *)
        start_cmd := FALSE;
        stop_cmd := FALSE;

        state := 10;  (* Loop back to read *)

    99: (* Fault *)
        (* Log error, wait for intervention *)
END_CASE;
END_PROGRAM
```

> **DB access optimization:** The S7 protocol allows reading up to 480 bytes per PDU (negotiated at connection time). Grouping reads within a single DB range via `S7AddPoll` is far more efficient than individual typed reads. The background poll fetches all 18 bytes of DB10 in a single S7 transaction, and the typed read functions extract values from the cache.

---

## 5. Complete Example: S7 Server for TIA Portal Testing

This example creates an S7 server that simulates the packaging line PLC from Section 4. A TIA Portal project can connect to this server for HMI development and logic testing without the physical PLC.

```iecst
PROGRAM POU_S7Simulator
VAR
    (* Server state *)
    state : INT := 0;
    ok : BOOL;
    scan_count : DINT := 0;

    (* Simulated process values *)
    sim_running : BOOL := FALSE;
    sim_speed : INT := 0;
    sim_temp : REAL := 25.0;
    sim_pressure : REAL := 1013.0;
    sim_total : DINT := 0;

    (* Commands received from TIA Portal / HMI *)
    cmd_bytes : ARRAY[0..7] OF INT;
    start_received : BOOL;
    stop_received : BOOL;
END_VAR

CASE state OF
    0: (* Create and start server *)
        ok := S7ServerCreate('sim', 1102);
        IF ok THEN state := 1; END_IF;

    1:
        ok := S7ServerStart('sim');
        IF ok THEN state := 2; END_IF;

    2: (* Initialize DB10 with zeros *)
        S7ServerSetDB('sim', 10, 0, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                      0, 0, 0, 0, 0, 0, 0, 0]);
        S7ServerSetDB('sim', 20, 0, [0, 0, 0, 0, 0, 0, 0, 0]);
        state := 10;

    10: (* Running — update simulation every scan *)
        scan_count := scan_count + 1;

        (* Read commands from DB20 (written by TIA Portal / HMI) *)
        cmd_bytes := S7ServerGetDB('sim', 20, 0, 8);
        start_received := (cmd_bytes[0] AND 1) = 1;       (* Bit 0.0 *)
        stop_received := (cmd_bytes[0] AND 2) = 2;        (* Bit 0.1 *)

        (* Process commands *)
        IF start_received AND NOT sim_running THEN
            sim_running := TRUE;
        END_IF;
        IF stop_received THEN
            sim_running := FALSE;
        END_IF;

        (* Simulate process behavior *)
        IF sim_running THEN
            sim_speed := 120;
            sim_temp := sim_temp + 0.1;
            IF sim_temp > 190.0 THEN sim_temp := 185.0; END_IF;
            sim_pressure := 950.0;
            sim_total := sim_total + 1;
        ELSE
            sim_speed := 0;
            sim_temp := sim_temp - 0.05;
            IF sim_temp < 25.0 THEN sim_temp := 25.0; END_IF;
            sim_pressure := 1013.0;
        END_IF;

        (* Write simulated status to DB10 *)
        (* Byte 0: status bits *)
        S7ServerSetDB('sim', 10, 0, [BOOL_TO_INT(sim_running)]);

        (* Bytes 2-3: line speed as INT (big-endian) *)
        S7ServerSetDB('sim', 10, 2, [sim_speed / 256, sim_speed MOD 256]);

        (* Note: REAL and DINT values require IEEE 754 / big-endian
           byte packing. In practice, use helper functions or
           write complete byte arrays from your simulation model. *)

        IF NOT S7ServerIsRunning('sim') THEN
            state := 1;
        END_IF;
END_CASE;
END_PROGRAM
```

> **TIA Portal connection:** In TIA Portal, add an "Unspecified S7 300/400" as a connection partner and configure the IP address and port of the GoPLC server. The S7 server responds to standard S7comm read/write requests — TIA Portal and WinCC treat it like a real PLC.

---

## 6. Gateway Example: S7 to MQTT Bridge

This example reads data from an S7-1500 PLC and publishes it to an MQTT broker, bridging the OT (Siemens) and IT (MQTT/JSON) worlds.

```iecst
PROGRAM POU_S7_MQTT_Gateway
VAR
    (* State machine *)
    state : INT := 0;
    ok : BOOL;
    scan_count : DINT := 0;
    publish_interval : DINT := 10;

    (* S7 data *)
    speed : REAL;
    temp : REAL;
    pressure : REAL;
    running : BOOL;

    (* MQTT *)
    payload : STRING;
END_VAR

CASE state OF
    0: (* Initialize S7 client *)
        ok := S7ClientCreate('plc', '10.0.0.34', 0, 0);
        IF ok THEN state := 1; END_IF;

    1: (* Connect S7 *)
        ok := S7ClientConnect('plc');
        IF ok THEN state := 2; END_IF;

    2: (* Initialize MQTT *)
        ok := MQTTConnect('gw', '10.0.0.144', 1883);
        IF ok THEN state := 3; END_IF;

    3: (* Register polling *)
        S7AddPoll('plc', 'DB', 10, 0, 20);
        state := 10;

    10: (* Running — read and publish *)
        scan_count := scan_count + 1;

        IF NOT S7ClientIsConnected('plc') THEN
            S7ClientConnect('plc');
        END_IF;

        (* Read from polled cache *)
        speed := S7ReadDBReal('plc', 10, 0);
        temp := S7ReadDBReal('plc', 10, 4);
        pressure := S7ReadDBReal('plc', 10, 8);
        running := S7ReadDBBool('plc', 10, 12, 0);

        (* Publish at reduced rate *)
        IF (scan_count MOD publish_interval) = 0 THEN
            payload := CONCAT('{"speed":', REAL_TO_STRING(speed),
                              ',"temp":', REAL_TO_STRING(temp),
                              ',"pressure":', REAL_TO_STRING(pressure),
                              ',"running":', BOOL_TO_STRING(running), '}');

            MQTTPublish('gw', 'plant/line1/data', payload);
        END_IF;

        (* Publish connection stats periodically *)
        IF (scan_count MOD 100) = 0 THEN
            MQTTPublish('gw', 'plant/line1/stats',
                        S7ClientGetStats('plc'));
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 7. Advanced Patterns

### 7.1 Multi-PLC Polling

```iecst
PROGRAM POU_MultiPLC
VAR
    poll_index : INT := 0;
    plcs : ARRAY[0..2] OF STRING := ['plc_line1', 'plc_line2', 'plc_line3'];
    speed : REAL;
END_VAR

(* Round-robin: read one PLC per scan to distribute load *)
speed := S7ReadDBReal(plcs[poll_index], 10, 0);

poll_index := poll_index + 1;
IF poll_index > 2 THEN
    poll_index := 0;
END_IF;
END_PROGRAM
```

> **Why round-robin?** Each S7 read blocks for the round-trip time (5-30 ms on a local network). Reading from three PLCs sequentially every scan adds 15-90 ms. With background polling enabled via `S7AddPoll`, the round-robin pattern is less critical since reads return from cache — but it remains useful for write operations that cannot be cached.

### 7.2 Dual Role: Client and Server Simultaneously

```iecst
PROGRAM POU_DualRole
VAR
    state : INT := 0;
    ok : BOOL;
    speed : REAL;
    temp : REAL;
END_VAR

CASE state OF
    0: (* Initialize both roles *)
        ok := S7ClientCreate('plc', '10.0.0.34', 0, 0);
        ok := S7ServerCreate('mirror', 1102);
        IF ok THEN state := 1; END_IF;

    1: (* Connect/Start *)
        S7ClientConnect('plc');
        S7ServerStart('mirror');
        S7AddPoll('plc', 'DB', 10, 0, 20);
        state := 10;

    10: (* Running — mirror PLC data to server *)
        (* Read from real PLC *)
        speed := S7ReadDBReal('plc', 10, 0);
        temp := S7ReadDBReal('plc', 10, 4);

        (* Mirror to server DB for HMI/SCADA access *)
        (* Write raw bytes — REAL as IEEE 754 big-endian *)
        S7ServerSetDB('mirror', 10, 0, S7ServerGetDB('mirror', 10, 0, 20));

        (* Alternatively, forward entire DB block from client reads *)
END_CASE;
END_PROGRAM
```

### 7.3 Cross-Protocol Bridge: Modbus TCP to S7

```iecst
PROGRAM POU_Modbus_S7_Bridge
VAR
    state : INT := 0;
    ok : BOOL;
    regs : ARRAY[0..9] OF INT;
END_VAR

CASE state OF
    0: (* Initialize both protocols *)
        ok := MBClientCreate('vfd', '10.0.0.50', 502, 1);
        ok := S7ClientCreate('plc', '10.0.0.34', 0, 0);
        IF ok THEN state := 1; END_IF;

    1: (* Connect both *)
        MBClientConnect('vfd');
        S7ClientConnect('plc');
        state := 10;

    10: (* Running — bridge Modbus VFD data into S7 PLC DB *)
        (* Read VFD status over Modbus *)
        regs := MBClientReadHoldingRegisters('vfd', 0, 5);

        (* Write to S7 PLC DB30 as INT values *)
        ok := S7WriteDBInt('plc', 30, 0, regs[0]);   (* Output freq *)
        ok := S7WriteDBInt('plc', 30, 2, regs[1]);   (* Current *)
        ok := S7WriteDBInt('plc', 30, 4, regs[2]);   (* Voltage *)
        ok := S7WriteDBInt('plc', 30, 6, regs[3]);   (* Status word *)
        ok := S7WriteDBInt('plc', 30, 8, regs[4]);   (* Fault code *)

        (* Read speed command from S7 PLC, forward to VFD *)
        ok := MBClientWriteRegister('vfd', 8192,
                  S7ReadDBInt('plc', 30, 10));
END_CASE;
END_PROGRAM
```

> **Protocol bridging:** GoPLC acts as a universal translator. The S7 PLC program reads VFD data from its DB30 as if it were local data — it doesn't know or care that the values originate from a Modbus device. This decouples the PLC program from the field protocol.

---

## 8. PLC Family Notes

### S7-300 / S7-400

- **Rack/Slot:** Typically rack 0, slot 2. Check STEP 7 hardware configuration for multi-rack setups.
- **No special configuration required.** PUT/GET is enabled by default on 300/400 series.
- **Connection limits:** S7-300 supports 12-32 concurrent connections depending on CPU model. S7-400 supports up to 64.
- **DB access:** Standard (non-optimized) DB blocks only. These PLCs do not support optimized block access.

### S7-1200

- **Rack/Slot:** Always rack 0, slot 0.
- **PUT/GET must be enabled** in TIA Portal: *Device configuration > Protection & Security > Connection mechanisms > Permit access with PUT/GET communication*.
- **DB blocks must be non-optimized:** In TIA Portal, open the DB properties and uncheck *Optimized block access*. Optimized DBs use internal addressing that external clients cannot access.
- **Connection limit:** 8 concurrent connections (CPU firmware dependent).
- **Firmware:** Requires firmware V4.0 or later for full PUT/GET support.

### S7-1500

- **Rack/Slot:** Always rack 0, slot 0.
- **PUT/GET must be enabled** — same TIA Portal setting as S7-1200.
- **DB blocks must be non-optimized** for external access. Alternatively, use a dedicated "interface DB" with optimized access disabled while keeping internal DBs optimized.
- **Connection limit:** Up to 32 concurrent connections depending on CPU model.
- **Security:** S7-1500 supports access levels (full access, read access, HMI access, no access). Ensure the access level permits PUT/GET.

> **Optimized vs. standard DB access:** TIA Portal defaults to "optimized block access" for S7-1200/1500 DBs. This reorders variables internally for performance, breaking external byte-offset addressing. For any DB that GoPLC will read/write, disable optimized access. A common pattern is to create dedicated "exchange DBs" (e.g., DB10 for status, DB20 for commands) with optimized access disabled, and use optimized DBs for internal PLC logic.

---

## Appendix A: S7 Address Mapping Quick Reference

| TIA Portal Address | GoPLC Function | Parameters |
|-------------------|----------------|------------|
| `DB10.DBX0.0` | `S7ReadDBBool('c', 10, 0, 0)` | db=10, byte=0, bit=0 |
| `DB10.DBX0.7` | `S7ReadDBBool('c', 10, 0, 7)` | db=10, byte=0, bit=7 |
| `DB10.DBX1.0` | `S7ReadDBBool('c', 10, 1, 0)` | db=10, byte=1, bit=0 |
| `DB10.DBB0` | `S7ReadDBByte('c', 10, 0)` | db=10, byte=0 |
| `DB10.DBW2` | `S7ReadDBWord('c', 10, 2)` | db=10, byte=2 |
| `DB10.DBD4` | `S7ReadDBDword('c', 10, 4)` | db=10, byte=4 |
| `DB10.DBD4` (REAL) | `S7ReadDBReal('c', 10, 4)` | db=10, byte=4 |
| `I0.0` | `S7ReadIBool('c', 0, 0)` | byte=0, bit=0 |
| `IB0` (byte) | `S7ReadI('c', 0, 1)` | byte=0, count=1 |
| `Q0.0` | `S7ReadQBool('c', 0, 0)` | byte=0, bit=0 |
| `M10.3` | `S7ReadMBool('c', 10, 3)` | byte=10, bit=3 |
| `MB0-MB7` | `S7ReadM('c', 0, 8)` | byte=0, count=8 |

---

## Appendix B: Quick Reference — All Functions

### Client Functions (~24)

| Function | Returns | Description |
|----------|---------|-------------|
| `S7ClientCreate(name, host, rack, slot [, port] [, timeout_ms] [, poll_rate_ms])` | BOOL | Create named connection |
| `S7ClientConnect(name)` | BOOL | Establish S7 connection |
| `S7ClientDisconnect(name)` | BOOL | Close S7 connection |
| `S7ClientIsConnected(name)` | BOOL | Check connection state |
| `S7ClientDelete(name)` | BOOL | Remove connection |
| `S7ClientList()` | []STRING | List all connections |
| `S7ClientGetStats(name)` | MAP | Request/response/error/poll counts |
| `S7ReadDBByte(name, db, byteAddr)` | INT | Read unsigned byte (USINT) |
| `S7ReadDBWord(name, db, byteAddr)` | INT | Read unsigned word (UINT) |
| `S7ReadDBDword(name, db, byteAddr)` | DINT | Read unsigned double word (UDINT) |
| `S7ReadDBInt(name, db, byteAddr)` | INT | Read signed 16-bit integer |
| `S7ReadDBDint(name, db, byteAddr)` | DINT | Read signed 32-bit integer |
| `S7ReadDBReal(name, db, byteAddr)` | REAL | Read 32-bit float (IEEE 754) |
| `S7ReadDBBool(name, db, byteAddr, bit)` | BOOL | Read single bit from DB |
| `S7WriteDBByte(name, db, byteAddr, value)` | BOOL | Write unsigned byte |
| `S7WriteDBWord(name, db, byteAddr, value)` | BOOL | Write unsigned word |
| `S7WriteDBDword(name, db, byteAddr, value)` | BOOL | Write unsigned double word |
| `S7WriteDBInt(name, db, byteAddr, value)` | BOOL | Write signed 16-bit integer |
| `S7WriteDBDint(name, db, byteAddr, value)` | BOOL | Write signed 32-bit integer |
| `S7WriteDBReal(name, db, byteAddr, value)` | BOOL | Write 32-bit float |
| `S7WriteDBBool(name, db, byteAddr, bit, value)` | BOOL | Write single bit to DB |
| `S7ReadI(name, byteAddr, count)` | []INT | Read input bytes |
| `S7ReadQ(name, byteAddr, count)` | []INT | Read output bytes |
| `S7ReadM(name, byteAddr, count)` | []INT | Read marker bytes |
| `S7ReadIBool(name, byteAddr, bit)` | BOOL | Read input bit |
| `S7ReadQBool(name, byteAddr, bit)` | BOOL | Read output bit |
| `S7ReadMBool(name, byteAddr, bit)` | BOOL | Read marker bit |
| `S7WriteM(name, byteAddr, values)` | BOOL | Write marker bytes |
| `S7WriteQ(name, byteAddr, values)` | BOOL | Write output bytes |
| `S7WriteMBool(name, byteAddr, bit, value)` | BOOL | Write marker bit |
| `S7WriteQBool(name, byteAddr, bit, value)` | BOOL | Write output bit |
| `S7AddPoll(name, area, dbNumber, byteAddr, byteCount)` | BOOL | Register background poll range |

### Server Functions (~14)

| Function | Returns | Description |
|----------|---------|-------------|
| `S7ServerCreate(name, port)` | BOOL | Create named S7 server |
| `S7ServerStart(name)` | BOOL | Begin listening |
| `S7ServerStop(name)` | BOOL | Stop listening |
| `S7ServerIsRunning(name)` | BOOL | Check server state |
| `S7ServerSetDB(name, db, byteAddr, values)` | BOOL | Write to server DB area |
| `S7ServerGetDB(name, db, byteAddr, count)` | []INT | Read from server DB area |
| `S7ServerSetM(name, byteAddr, values)` | BOOL | Write to server marker area |
| `S7ServerGetM(name, byteAddr, count)` | []INT | Read from server marker area |
| `S7ServerSetI(name, byteAddr, values)` | BOOL | Write to server input area |
| `S7ServerGetI(name, byteAddr, count)` | []INT | Read from server input area |
| `S7ServerSetQ(name, byteAddr, values)` | BOOL | Write to server output area |
| `S7ServerGetQ(name, byteAddr, count)` | []INT | Read from server output area |
| `S7ServerDelete(name)` | BOOL | Remove server |
| `S7ServerList()` | []STRING | List all servers |

---

*GoPLC v1.0.520 | Siemens S7 Client + Server | IEC 61131-3 Structured Text*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
