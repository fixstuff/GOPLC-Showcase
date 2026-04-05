# GoPLC EtherNet/IP Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements EtherNet/IP (EIP) natively in two complementary roles:

| Role | Functions | Best For |
|------|-----------|----------|
| **Scanner (Client)** | `ENIP_SCANNER_*` | Reading/writing tags on Allen-Bradley CompactLogix, ControlLogix, Micro800, or any CIP device |
| **Adapter (Server)** | `ENIP_ADAPTER_*` | Exposing GoPLC tags to RSLogix 5000/Studio 5000, FactoryTalk, or other EIP scanners |

Both roles use CIP (Common Industrial Protocol) over EtherNet/IP and can run simultaneously. A single GoPLC instance can scan multiple PLCs while also serving tags to upstream systems.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                  │
│                                                              │
│  ┌───────────────────────┐  ┌────────────────────────────┐   │
│  │ ENIP Scanner (Client) │  │ ENIP Adapter (Server)      │   │
│  │                       │  │                            │   │
│  │ Poll tags from AB PLC │  │ Expose tags to RSLogix     │   │
│  │ Read/Write cached     │  │ Set/Get from ST logic      │   │
│  │ Auto-register tags    │  │ Listen on TCP 44818        │   │
│  └───────────┬───────────┘  └──────────────┬─────────────┘   │
│              │                             │                 │
│  ┌───────────┴──────────────────────────────┴─────────────┐  │
│  │  ST Program (IEC 61131-3 Structured Text)              │  │
│  │                                                        │  │
│  │  temp := ENIP_SCANNER_READ_REAL('plc1', 'Temp', 0);   │  │
│  │  ENIP_ADAPTER_SET_REAL('svr', 'PV_Temp', 0, temp);    │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────┬───────────────────────┬───────────────────┘
                   │                       │
          EtherNet/IP (TCP 44818)          │  EtherNet/IP (TCP 44818)
                   │                       │
                   ▼                       ▼
┌──────────────────────────┐  ┌──────────────────────────────┐
│  Allen-Bradley PLC       │  │  RSLogix 5000 / Studio 5000  │
│  CompactLogix / CLX      │  │  FactoryTalk View            │
│  1769-L33ER, 5380, etc.  │  │  Any EIP Scanner             │
│                          │  │                              │
│  Tags:                   │  │  Reads GoPLC tags as         │
│    Temp : REAL           │  │  Generic Ethernet Module     │
│    RunCmd : BOOL         │  │                              │
│    Speed : DINT          │  │  PV_Temp : REAL              │
└──────────────────────────┘  │  Status  : DINT              │
                              └──────────────────────────────┘
```

### CIP Data Types

GoPLC maps CIP type codes to IEC 61131-3 types:

| CIP Type | Code | IEC Type | Size | Range |
|----------|------|----------|------|-------|
| BOOL | 0xC1 | BOOL | 1 bit | TRUE / FALSE |
| INT | 0xC3 | INT | 16-bit signed | -32768 to 32767 |
| DINT | 0xC4 | DINT | 32-bit signed | -2^31 to 2^31-1 |
| REAL | 0xCA | REAL | 32-bit float | IEEE 754 |
| STRING | 0xD0 | STRING | Variable | Rockwell 82-byte STRING |

---

## 2. Scanner (Client) — Reading/Writing PLC Tags

The scanner connects to an EtherNet/IP device, registers tags for polling, and maintains a local cache updated at a configurable rate. Your ST program reads from and writes to this cache -- the scanner handles all CIP messaging in the background.

### 2.1 Lifecycle

```
CREATE  →  ADD TAGS  →  CONNECT  →  READ/WRITE  →  DISCONNECT  →  DELETE
                           ↑                            │
                           └────── RECONNECT ───────────┘
                              (automatic on failure)
```

### 2.2 Scanner Functions

#### ENIP_SCANNER_CREATE — Create Scanner Instance

```iecst
ENIP_SCANNER_CREATE(name: STRING, host: STRING, port: INT, [poll_rate_ms: INT]) : BOOL
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique instance name |
| `host` | STRING | PLC IP address or hostname |
| `port` | INT | TCP port (44818 standard) |
| `poll_rate_ms` | INT | *(Optional)* Poll interval in milliseconds (default: 100) |

```iecst
(* Connect to CompactLogix at 10.0.0.50 *)
ok := ENIP_SCANNER_CREATE('plc1', '10.0.0.50', 44818);

(* Fast polling at 50ms *)
ok := ENIP_SCANNER_CREATE('plc1', '10.0.0.50', 44818, 50);
```

> **Port 44818** is the EtherNet/IP standard. Every Rockwell PLC uses this port. Only change it if you are connecting through a NAT or port-forwarded tunnel.

#### ENIP_SCANNER_CONNECT — Start Polling

```iecst
ENIP_SCANNER_CONNECT(name: STRING) : BOOL
```

Opens the CIP session, registers tags, and starts the background poll loop. Add all tags **before** calling connect.

```iecst
ok := ENIP_SCANNER_CONNECT('plc1');
```

#### ENIP_SCANNER_CONNECTED — Check Connection State

```iecst
ENIP_SCANNER_CONNECTED(name: STRING) : BOOL
```

Returns TRUE if the scanner has an active CIP session and is polling.

```iecst
IF ENIP_SCANNER_CONNECTED('plc1') THEN
    (* Safe to read/write *)
END_IF;
```

#### ENIP_SCANNER_DISCONNECT — Stop Polling

```iecst
ENIP_SCANNER_DISCONNECT(name: STRING) : BOOL
```

Closes the CIP session and stops polling. The tag list is preserved -- call `ENIP_SCANNER_CONNECT` to resume.

```iecst
ok := ENIP_SCANNER_DISCONNECT('plc1');
```

#### ENIP_SCANNER_DELETE — Remove Scanner

```iecst
ENIP_SCANNER_DELETE(name: STRING) : BOOL
```

Disconnects (if connected) and removes the scanner instance and all its tags.

```iecst
ok := ENIP_SCANNER_DELETE('plc1');
```

#### ENIP_SCANNER_LIST — List All Scanners

```iecst
ENIP_SCANNER_LIST() : ARRAY
```

Returns an array of scanner instance names.

```iecst
scanners := ENIP_SCANNER_LIST();
(* Returns: ['plc1', 'plc2'] *)
```

---

### 2.3 Tag Registration

Tags must be registered before the scanner connects. Each registered tag is polled every cycle.

#### ENIP_SCANNER_ADD_TAG — Generic Tag Registration

```iecst
ENIP_SCANNER_ADD_TAG(name: STRING, tag: STRING, dataType: INT, count: INT) : BOOL
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Scanner instance name |
| `tag` | STRING | PLC tag name (case-sensitive, must match PLC exactly) |
| `dataType` | INT | CIP type code (0xC1=BOOL, 0xC3=INT, 0xC4=DINT, 0xCA=REAL, 0xD0=STRING) |
| `count` | INT | Number of elements (1 for scalar, N for array) |

```iecst
(* Register a REAL scalar *)
ok := ENIP_SCANNER_ADD_TAG('plc1', 'ProcessTemp', 16#CA, 1);

(* Register a 10-element DINT array *)
ok := ENIP_SCANNER_ADD_TAG('plc1', 'BatchCounts', 16#C4, 10);
```

#### Typed Convenience Functions

These call `ENIP_SCANNER_ADD_TAG` with the correct CIP type code:

```iecst
ENIP_SCANNER_ADD_BOOL_TAG(name: STRING, tag: STRING, count: INT) : BOOL
ENIP_SCANNER_ADD_INT_TAG(name: STRING, tag: STRING, count: INT) : BOOL
ENIP_SCANNER_ADD_DINT_TAG(name: STRING, tag: STRING, count: INT) : BOOL
ENIP_SCANNER_ADD_REAL_TAG(name: STRING, tag: STRING, count: INT) : BOOL
ENIP_SCANNER_ADD_STRING_TAG(name: STRING, tag: STRING, count: INT) : BOOL
```

```iecst
(* Register tags using typed helpers *)
ENIP_SCANNER_ADD_BOOL_TAG('plc1', 'RunCmd', 1);
ENIP_SCANNER_ADD_INT_TAG('plc1', 'SpeedRef', 1);
ENIP_SCANNER_ADD_DINT_TAG('plc1', 'TotalCount', 1);
ENIP_SCANNER_ADD_REAL_TAG('plc1', 'Temperature', 1);
ENIP_SCANNER_ADD_STRING_TAG('plc1', 'RecipeName', 1);

(* Array of 8 REAL values *)
ENIP_SCANNER_ADD_REAL_TAG('plc1', 'ZoneTemps', 8);
```

> **Tag names are case-sensitive.** `Temperature` and `temperature` are different tags. The tag name must match the PLC program exactly, including structure member paths like `HMI.StartButton`.

#### ENIP_SCANNER_AUTO_REGISTER — Discover and Register All Tags

```iecst
ENIP_SCANNER_AUTO_REGISTER(name: STRING) : DINT
```

Browses the PLC's tag database and automatically registers every discovered tag (BOOL, INT, DINT, REAL, STRING, arrays). Returns the number of tags registered.

```iecst
(* Auto-discover all tags from the PLC *)
tag_count := ENIP_SCANNER_AUTO_REGISTER('plc1');
(* Returns: 47 — registered 47 tags *)
```

> **Use with care on large programs.** A ControlLogix with thousands of tags will register them all. For production, prefer explicit tag registration with `ADD_*_TAG` to poll only what you need.

---

### 2.4 Reading Tags

Read functions return the last polled value from the local cache. They do **not** trigger a CIP read -- the background poll loop keeps the cache current at the configured `poll_rate_ms`.

```iecst
ENIP_SCANNER_READ_BOOL(name: STRING, tag: STRING, index: INT) : BOOL
ENIP_SCANNER_READ_INT(name: STRING, tag: STRING, index: INT) : INT
ENIP_SCANNER_READ_DINT(name: STRING, tag: STRING, index: INT) : DINT
ENIP_SCANNER_READ_REAL(name: STRING, tag: STRING, index: INT) : REAL
ENIP_SCANNER_READ_STRING(name: STRING, tag: STRING, index: INT) : STRING
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Scanner instance name |
| `tag` | STRING | Tag name (must be previously registered) |
| `index` | INT | Element index (0 for scalars, 0..N-1 for arrays) |

```iecst
(* Read scalar values *)
running := ENIP_SCANNER_READ_BOOL('plc1', 'RunCmd', 0);
speed   := ENIP_SCANNER_READ_INT('plc1', 'SpeedRef', 0);
count   := ENIP_SCANNER_READ_DINT('plc1', 'TotalCount', 0);
temp    := ENIP_SCANNER_READ_REAL('plc1', 'Temperature', 0);
recipe  := ENIP_SCANNER_READ_STRING('plc1', 'RecipeName', 0);

(* Read array element *)
zone3_temp := ENIP_SCANNER_READ_REAL('plc1', 'ZoneTemps', 2);
```

> **Index 0 for scalars.** Even for single-element tags, you must pass index 0.

---

### 2.5 Writing Tags

Write functions queue a value for the next poll cycle. The scanner sends the CIP write on its next pass.

```iecst
ENIP_SCANNER_WRITE_BOOL(name: STRING, tag: STRING, index: INT, value: BOOL) : BOOL
ENIP_SCANNER_WRITE_INT(name: STRING, tag: STRING, index: INT, value: INT) : BOOL
ENIP_SCANNER_WRITE_DINT(name: STRING, tag: STRING, index: INT, value: DINT) : BOOL
ENIP_SCANNER_WRITE_REAL(name: STRING, tag: STRING, index: INT, value: REAL) : BOOL
ENIP_SCANNER_WRITE_STRING(name: STRING, tag: STRING, index: INT, value: STRING) : BOOL
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Scanner instance name |
| `tag` | STRING | Tag name (must be previously registered) |
| `index` | INT | Element index (0 for scalars) |
| `value` | typed | Value to write |

Returns TRUE if the write was queued successfully.

```iecst
(* Write scalar values *)
ENIP_SCANNER_WRITE_BOOL('plc1', 'RunCmd', 0, TRUE);
ENIP_SCANNER_WRITE_INT('plc1', 'SpeedRef', 0, 1750);
ENIP_SCANNER_WRITE_DINT('plc1', 'TotalCount', 0, 0);
ENIP_SCANNER_WRITE_REAL('plc1', 'Setpoint', 0, 72.5);
ENIP_SCANNER_WRITE_STRING('plc1', 'RecipeName', 0, 'BATCH_42');

(* Write array element *)
ENIP_SCANNER_WRITE_REAL('plc1', 'ZoneSetpoints', 2, 185.0);
```

> **Writes are queued, not immediate.** The value is sent on the scanner's next poll cycle. At 100ms poll rate, worst-case write latency is ~100ms.

---

### 2.6 Example: Read from CompactLogix

Complete program that connects to a CompactLogix, registers tags, and reads process data every scan.

```iecst
PROGRAM POU_ScannerDemo
VAR
    state : INT := 0;
    ok : BOOL;
    connected : BOOL;

    (* Process values *)
    temperature : REAL;
    pressure : REAL;
    running : BOOL;
    fault_code : DINT;
    recipe : STRING;
END_VAR

CASE state OF
    0: (* Create scanner *)
        ok := ENIP_SCANNER_CREATE('plc1', '10.0.0.50', 44818, 100);
        IF ok THEN state := 1; END_IF;

    1: (* Register tags *)
        ENIP_SCANNER_ADD_REAL_TAG('plc1', 'ProcessTemp', 1);
        ENIP_SCANNER_ADD_REAL_TAG('plc1', 'ProcessPressure', 1);
        ENIP_SCANNER_ADD_BOOL_TAG('plc1', 'MotorRunning', 1);
        ENIP_SCANNER_ADD_DINT_TAG('plc1', 'FaultCode', 1);
        ENIP_SCANNER_ADD_STRING_TAG('plc1', 'ActiveRecipe', 1);
        state := 2;

    2: (* Connect *)
        ok := ENIP_SCANNER_CONNECT('plc1');
        IF ok THEN state := 10; END_IF;

    10: (* Running — read cached values every scan *)
        connected := ENIP_SCANNER_CONNECTED('plc1');
        IF NOT connected THEN
            state := 2;    (* Reconnect *)
        ELSE
            temperature := ENIP_SCANNER_READ_REAL('plc1', 'ProcessTemp', 0);
            pressure    := ENIP_SCANNER_READ_REAL('plc1', 'ProcessPressure', 0);
            running     := ENIP_SCANNER_READ_BOOL('plc1', 'MotorRunning', 0);
            fault_code  := ENIP_SCANNER_READ_DINT('plc1', 'FaultCode', 0);
            recipe      := ENIP_SCANNER_READ_STRING('plc1', 'ActiveRecipe', 0);
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.7 Example: Tag Browsing with Auto-Register

When you don't know the tag layout of a PLC, use auto-register to discover everything, then read what you need.

```iecst
PROGRAM POU_BrowseDemo
VAR
    state : INT := 0;
    ok : BOOL;
    tag_count : DINT;

    (* Read whatever we discover *)
    val_real : REAL;
    val_dint : DINT;
END_VAR

CASE state OF
    0: (* Create scanner *)
        ok := ENIP_SCANNER_CREATE('plc1', '10.0.0.50', 44818);
        IF ok THEN state := 1; END_IF;

    1: (* Auto-discover all tags *)
        tag_count := ENIP_SCANNER_AUTO_REGISTER('plc1');
        (* tag_count = number of tags found and registered *)
        state := 2;

    2: (* Connect — all discovered tags will be polled *)
        ok := ENIP_SCANNER_CONNECT('plc1');
        IF ok THEN state := 10; END_IF;

    10: (* Read discovered tags by name *)
        IF ENIP_SCANNER_CONNECTED('plc1') THEN
            val_real := ENIP_SCANNER_READ_REAL('plc1', 'ProcessTemp', 0);
            val_dint := ENIP_SCANNER_READ_DINT('plc1', 'BatchCount', 0);
        END_IF;
END_CASE;
END_PROGRAM
```

> **Auto-register then connect.** `ENIP_SCANNER_AUTO_REGISTER` must be called before `ENIP_SCANNER_CONNECT`. It performs a CIP browse (List All Tags service) and registers each tag with the appropriate data type.

---

## 3. Adapter (Server) — Exposing Tags to External Systems

The adapter makes GoPLC act as an EtherNet/IP target device. RSLogix 5000, FactoryTalk View, Ignition, or any EIP scanner can read and write GoPLC tags over the network.

### 3.1 Lifecycle

```
CREATE  →  ADD TAGS  →  START  →  SET/GET values  →  STOP  →  DELETE
                          ↑          (from ST logic)    │
                          └─────────────────────────────┘
```

### 3.2 Adapter Functions

#### ENIP_ADAPTER_CREATE — Create Adapter Instance

```iecst
ENIP_ADAPTER_CREATE(name: STRING, [port: INT]) : BOOL
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique instance name |
| `port` | INT | *(Optional)* TCP listen port (default: 44818) |

```iecst
(* Create adapter on default port 44818 *)
ok := ENIP_ADAPTER_CREATE('svr');

(* Create adapter on alternate port *)
ok := ENIP_ADAPTER_CREATE('svr', 44819);
```

> **One adapter per port.** If you need multiple adapters (e.g., for network segmentation), assign each a different port.

#### ENIP_ADAPTER_START — Start Listening

```iecst
ENIP_ADAPTER_START(name: STRING) : BOOL
```

Begins accepting EtherNet/IP connections. Add all tags **before** starting.

```iecst
ok := ENIP_ADAPTER_START('svr');
```

#### ENIP_ADAPTER_STOP — Stop Listening

```iecst
ENIP_ADAPTER_STOP(name: STRING) : BOOL
```

Closes all client connections and stops the listener. Tags are preserved.

```iecst
ok := ENIP_ADAPTER_STOP('svr');
```

#### ENIP_ADAPTER_IS_RUNNING — Check Adapter State

```iecst
ENIP_ADAPTER_IS_RUNNING(name: STRING) : BOOL
```

```iecst
IF ENIP_ADAPTER_IS_RUNNING('svr') THEN
    (* Adapter is active and accepting connections *)
END_IF;
```

#### ENIP_ADAPTER_DELETE — Remove Adapter

```iecst
ENIP_ADAPTER_DELETE(name: STRING) : BOOL
```

Stops the adapter (if running) and removes the instance and all tags.

```iecst
ok := ENIP_ADAPTER_DELETE('svr');
```

#### ENIP_ADAPTER_LIST — List All Adapters

```iecst
ENIP_ADAPTER_LIST() : ARRAY
```

```iecst
adapters := ENIP_ADAPTER_LIST();
(* Returns: ['svr'] *)
```

#### ENIP_ADAPTER_GET_STATS — Adapter Statistics

```iecst
ENIP_ADAPTER_GET_STATS(name: STRING) : MAP
```

Returns a map of connection and performance statistics.

```iecst
stats := ENIP_ADAPTER_GET_STATS('svr');
(* Returns: {
     "active_connections": 2,
     "total_reads": 14523,
     "total_writes": 891,
     "tags_registered": 12,
     ...
   } *)
```

---

### 3.3 Tag Registration

#### ENIP_ADAPTER_ADD_TAG — Generic Tag Registration

```iecst
ENIP_ADAPTER_ADD_TAG(name: STRING, tag: STRING, type: INT, count: INT) : BOOL
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Adapter instance name |
| `tag` | STRING | Tag name (visible to remote scanners) |
| `type` | INT | CIP type code (0xC1=BOOL, 0xC3=INT, 0xC4=DINT, 0xCA=REAL) |
| `count` | INT | Number of elements (1 for scalar, N for array) |

```iecst
(* Register a REAL array with 4 elements *)
ok := ENIP_ADAPTER_ADD_TAG('svr', 'ZoneTemps', 16#CA, 4);
```

#### Typed Convenience Functions

```iecst
ENIP_ADAPTER_ADD_BOOL_TAG(name: STRING, tag: STRING, count: INT) : BOOL
ENIP_ADAPTER_ADD_INT_TAG(name: STRING, tag: STRING, count: INT) : BOOL
ENIP_ADAPTER_ADD_DINT_TAG(name: STRING, tag: STRING, count: INT) : BOOL
ENIP_ADAPTER_ADD_REAL_TAG(name: STRING, tag: STRING, count: INT) : BOOL
```

```iecst
ENIP_ADAPTER_ADD_BOOL_TAG('svr', 'SystemReady', 1);
ENIP_ADAPTER_ADD_INT_TAG('svr', 'AlarmCount', 1);
ENIP_ADAPTER_ADD_DINT_TAG('svr', 'ProductionTotal', 1);
ENIP_ADAPTER_ADD_REAL_TAG('svr', 'PV_Temperature', 1);

(* Array: 8-zone temperature readback *)
ENIP_ADAPTER_ADD_REAL_TAG('svr', 'ZoneTemps', 8);
```

---

### 3.4 Setting Tag Values (ST to Network)

Your ST program writes values into adapter tags. Remote scanners (RSLogix, etc.) read these values over CIP.

```iecst
ENIP_ADAPTER_SET_BOOL(name: STRING, tag: STRING, index: INT, value: BOOL) : BOOL
ENIP_ADAPTER_SET_INT(name: STRING, tag: STRING, index: INT, value: INT) : BOOL
ENIP_ADAPTER_SET_DINT(name: STRING, tag: STRING, index: INT, value: DINT) : BOOL
ENIP_ADAPTER_SET_REAL(name: STRING, tag: STRING, index: INT, value: REAL) : BOOL
```

```iecst
(* Update values for remote scanners to read *)
ENIP_ADAPTER_SET_BOOL('svr', 'SystemReady', 0, TRUE);
ENIP_ADAPTER_SET_DINT('svr', 'ProductionTotal', 0, 42850);
ENIP_ADAPTER_SET_REAL('svr', 'PV_Temperature', 0, 185.3);

(* Update array elements *)
ENIP_ADAPTER_SET_REAL('svr', 'ZoneTemps', 0, 182.1);
ENIP_ADAPTER_SET_REAL('svr', 'ZoneTemps', 1, 185.3);
ENIP_ADAPTER_SET_REAL('svr', 'ZoneTemps', 2, 184.7);
```

### 3.5 Getting Tag Values (Network to ST)

When a remote scanner writes to an adapter tag, your ST program reads the updated value with the GET functions.

```iecst
ENIP_ADAPTER_GET_BOOL(name: STRING, tag: STRING, index: INT) : BOOL
ENIP_ADAPTER_GET_INT(name: STRING, tag: STRING, index: INT) : INT
ENIP_ADAPTER_GET_DINT(name: STRING, tag: STRING, index: INT) : DINT
ENIP_ADAPTER_GET_REAL(name: STRING, tag: STRING, index: INT) : REAL
```

```iecst
(* Read values written by RSLogix or HMI *)
start_cmd := ENIP_ADAPTER_GET_BOOL('svr', 'RemoteStart', 0);
setpoint  := ENIP_ADAPTER_GET_REAL('svr', 'SP_Temperature', 0);
mode      := ENIP_ADAPTER_GET_INT('svr', 'OperatingMode', 0);
```

---

### 3.6 Example: GoPLC as EIP Adapter for RSLogix

Complete program that exposes process data and accepts commands from an upstream PLC or HMI.

```iecst
PROGRAM POU_AdapterDemo
VAR
    state : INT := 0;
    ok : BOOL;

    (* Local process values *)
    actual_temp : REAL := 72.0;
    production_count : DINT := 0;
    system_running : BOOL := FALSE;

    (* Remote commands (written by RSLogix/HMI) *)
    remote_start : BOOL;
    remote_setpoint : REAL;
END_VAR

CASE state OF
    0: (* Create adapter on default port *)
        ok := ENIP_ADAPTER_CREATE('svr');
        IF ok THEN state := 1; END_IF;

    1: (* Register tags — these appear in RSLogix *)
        (* Tags that GoPLC writes (PLC/HMI reads) *)
        ENIP_ADAPTER_ADD_REAL_TAG('svr', 'PV_Temperature', 1);
        ENIP_ADAPTER_ADD_DINT_TAG('svr', 'ProductionCount', 1);
        ENIP_ADAPTER_ADD_BOOL_TAG('svr', 'SystemRunning', 1);

        (* Tags that RSLogix/HMI writes (GoPLC reads) *)
        ENIP_ADAPTER_ADD_BOOL_TAG('svr', 'RemoteStart', 1);
        ENIP_ADAPTER_ADD_REAL_TAG('svr', 'SP_Temperature', 1);
        state := 2;

    2: (* Start adapter *)
        ok := ENIP_ADAPTER_START('svr');
        IF ok THEN state := 10; END_IF;

    10: (* Running — update tags every scan *)
        IF NOT ENIP_ADAPTER_IS_RUNNING('svr') THEN
            state := 2;    (* Restart *)
        END_IF;

        (* Push local values to network *)
        ENIP_ADAPTER_SET_REAL('svr', 'PV_Temperature', 0, actual_temp);
        ENIP_ADAPTER_SET_DINT('svr', 'ProductionCount', 0, production_count);
        ENIP_ADAPTER_SET_BOOL('svr', 'SystemRunning', 0, system_running);

        (* Read remote commands *)
        remote_start    := ENIP_ADAPTER_GET_BOOL('svr', 'RemoteStart', 0);
        remote_setpoint := ENIP_ADAPTER_GET_REAL('svr', 'SP_Temperature', 0);

        (* Process logic *)
        IF remote_start AND NOT system_running THEN
            system_running := TRUE;
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 4. Connecting to Allen-Bradley CompactLogix / ControlLogix

This section covers the practical details of connecting GoPLC to Rockwell Automation PLCs.

### 4.1 Supported Controllers

GoPLC's EtherNet/IP scanner has been tested with:

| Controller Family | Example Part Numbers | Notes |
|-------------------|---------------------|-------|
| **CompactLogix 5370** | 1769-L33ER, 1769-L36ERM | Most common target |
| **CompactLogix 5380** | 5069-L306ER, 5069-L340ERM | Newer platform |
| **ControlLogix 5570** | 1756-L73, 1756-L83E | Rack-mount, large I/O |
| **ControlLogix 5580** | 1756-L8SP | High-performance |
| **Micro850/870** | 2080-LC50-48QWB | Limited tag support |

### 4.2 PLC-Side Configuration

No special configuration is needed on the PLC to allow GoPLC scanner access. EtherNet/IP CIP implicit messaging is enabled by default. Just ensure:

1. **The PLC has an IP address** — configured via RSLinx or the front-panel LCD
2. **Port 44818 is reachable** — no firewall between GoPLC and the PLC
3. **Tags exist in the controller scope** — GoPLC reads controller-scoped tags by default

> **Program-scoped tags:** To access tags inside a specific program, use the full path: `Program:MainProgram.MyTag`.

### 4.3 Tag Path Syntax

```iecst
(* Controller-scoped tag *)
ENIP_SCANNER_ADD_REAL_TAG('plc1', 'Temperature', 1);

(* Program-scoped tag *)
ENIP_SCANNER_ADD_REAL_TAG('plc1', 'Program:MainProgram.Temperature', 1);

(* Structure member *)
ENIP_SCANNER_ADD_BOOL_TAG('plc1', 'HMI_Data.StartButton', 1);

(* Array element — register the whole array, read by index *)
ENIP_SCANNER_ADD_DINT_TAG('plc1', 'BatchData', 10);
val := ENIP_SCANNER_READ_DINT('plc1', 'BatchData', 3);    (* element [3] *)
```

### 4.4 Complete CompactLogix Integration Example

```iecst
PROGRAM POU_CompactLogix
VAR
    state : INT := 0;
    ok : BOOL;

    (* PLC data *)
    motor_running : BOOL;
    motor_speed : REAL;
    drive_fault : DINT;
    zone_temps : ARRAY[0..7] OF REAL;
    i : INT;

    (* Commands to PLC *)
    start_cmd : BOOL := FALSE;
    speed_sp : REAL := 0.0;
END_VAR

CASE state OF
    0: (* Create scanner — CompactLogix at 10.0.0.50 *)
        ok := ENIP_SCANNER_CREATE('clx', '10.0.0.50', 44818, 100);
        IF ok THEN state := 1; END_IF;

    1: (* Register tags matching the PLC program *)
        ENIP_SCANNER_ADD_BOOL_TAG('clx', 'Motor_Running', 1);
        ENIP_SCANNER_ADD_REAL_TAG('clx', 'Motor_Speed_Actual', 1);
        ENIP_SCANNER_ADD_DINT_TAG('clx', 'Drive_Fault_Code', 1);
        ENIP_SCANNER_ADD_REAL_TAG('clx', 'Zone_Temperatures', 8);
        ENIP_SCANNER_ADD_BOOL_TAG('clx', 'Motor_Start_Cmd', 1);
        ENIP_SCANNER_ADD_REAL_TAG('clx', 'Speed_Setpoint', 1);
        state := 2;

    2: (* Connect *)
        ok := ENIP_SCANNER_CONNECT('clx');
        IF ok THEN state := 10; END_IF;

    10: (* Running *)
        IF NOT ENIP_SCANNER_CONNECTED('clx') THEN
            state := 2;
        END_IF;

        (* Read process data *)
        motor_running := ENIP_SCANNER_READ_BOOL('clx', 'Motor_Running', 0);
        motor_speed   := ENIP_SCANNER_READ_REAL('clx', 'Motor_Speed_Actual', 0);
        drive_fault   := ENIP_SCANNER_READ_DINT('clx', 'Drive_Fault_Code', 0);

        (* Read zone temperature array *)
        FOR i := 0 TO 7 DO
            zone_temps[i] := ENIP_SCANNER_READ_REAL('clx', 'Zone_Temperatures', i);
        END_FOR;

        (* Write commands to PLC *)
        ENIP_SCANNER_WRITE_BOOL('clx', 'Motor_Start_Cmd', 0, start_cmd);
        ENIP_SCANNER_WRITE_REAL('clx', 'Speed_Setpoint', 0, speed_sp);
END_CASE;
END_PROGRAM
```

---

## 5. Exposing GoPLC as an EIP Adapter to RSLogix 5000

This section walks through configuring RSLogix 5000 / Studio 5000 to read GoPLC adapter tags.

### 5.1 RSLogix Configuration Steps

1. **Add a Generic Ethernet Module** to your I/O tree:
   - Right-click the Ethernet port -> New Module -> "ETHERNET-MODULE" (Generic)

2. **Configure the module:**
   - **Name:** `GoPLC` (or any descriptive name)
   - **IP Address:** IP of the machine running GoPLC
   - **Connection Parameters:**
     - Comm Format: Data - DINT (or Data - REAL depending on your tag types)
     - Input Assembly Instance: 100
     - Input Size: match your tag count
     - Output Assembly Instance: 101
     - Output Size: match your tag count
     - Configuration Assembly Instance: 102
     - RPI (Requested Packet Interval): 100ms or as needed

3. **Map tags** in your RSLogix program using the module's input/output data.

> **Alternative: MSG instruction.** For tag-name-based access (rather than assembly-based), use a CIP Generic MSG instruction in RSLogix. Set the service to "Read Tag" (0x4C) or "Write Tag" (0x4D) and specify the tag name. This reads GoPLC adapter tags by name.

### 5.2 GoPLC Adapter Setup for RSLogix

```iecst
PROGRAM POU_RSLogixAdapter
VAR
    state : INT := 0;
    ok : BOOL;

    (* Local sensor data to expose *)
    tank_level : REAL := 0.0;
    pump_status : BOOL := FALSE;
    alarm_word : DINT := 0;

    (* Commands from RSLogix *)
    pump_cmd : BOOL;
    level_sp : REAL;
END_VAR

CASE state OF
    0: (* Create adapter *)
        ok := ENIP_ADAPTER_CREATE('rslogix');
        IF ok THEN state := 1; END_IF;

    1: (* Define tags visible to RSLogix *)
        (* Status tags — RSLogix reads these *)
        ENIP_ADAPTER_ADD_REAL_TAG('rslogix', 'TankLevel', 1);
        ENIP_ADAPTER_ADD_BOOL_TAG('rslogix', 'PumpRunning', 1);
        ENIP_ADAPTER_ADD_DINT_TAG('rslogix', 'AlarmWord', 1);

        (* Command tags — RSLogix writes these *)
        ENIP_ADAPTER_ADD_BOOL_TAG('rslogix', 'PumpCommand', 1);
        ENIP_ADAPTER_ADD_REAL_TAG('rslogix', 'LevelSetpoint', 1);
        state := 2;

    2: (* Start listening *)
        ok := ENIP_ADAPTER_START('rslogix');
        IF ok THEN state := 10; END_IF;

    10: (* Running — bidirectional data exchange *)
        (* Push local data to RSLogix *)
        ENIP_ADAPTER_SET_REAL('rslogix', 'TankLevel', 0, tank_level);
        ENIP_ADAPTER_SET_BOOL('rslogix', 'PumpRunning', 0, pump_status);
        ENIP_ADAPTER_SET_DINT('rslogix', 'AlarmWord', 0, alarm_word);

        (* Receive commands from RSLogix *)
        pump_cmd := ENIP_ADAPTER_GET_BOOL('rslogix', 'PumpCommand', 0);
        level_sp := ENIP_ADAPTER_GET_REAL('rslogix', 'LevelSetpoint', 0);

        (* Implement pump control *)
        pump_status := pump_cmd AND (tank_level < 95.0);
END_CASE;
END_PROGRAM
```

---

## 6. Scanner + Adapter Combined: Gateway Pattern

A powerful pattern is using GoPLC as a protocol gateway -- scanning one PLC and exposing data to another system (or vice versa).

### 6.1 Example: Bridge CompactLogix to FactoryTalk

```iecst
PROGRAM POU_Gateway
VAR
    state : INT := 0;
    ok : BOOL;

    (* Data flowing through *)
    temp : REAL;
    pressure : REAL;
    running : BOOL;
    fault : DINT;
END_VAR

CASE state OF
    0: (* Create scanner for CompactLogix *)
        ok := ENIP_SCANNER_CREATE('field_plc', '10.0.1.50', 44818, 100);
        IF ok THEN state := 1; END_IF;

    1: (* Create adapter for upstream access *)
        ok := ENIP_ADAPTER_CREATE('gateway', 44818);
        IF ok THEN state := 2; END_IF;

    2: (* Register scanner tags *)
        ENIP_SCANNER_ADD_REAL_TAG('field_plc', 'ProcessTemp', 1);
        ENIP_SCANNER_ADD_REAL_TAG('field_plc', 'ProcessPressure', 1);
        ENIP_SCANNER_ADD_BOOL_TAG('field_plc', 'SystemRunning', 1);
        ENIP_SCANNER_ADD_DINT_TAG('field_plc', 'FaultCode', 1);
        state := 3;

    3: (* Register adapter tags — same names or different *)
        ENIP_ADAPTER_ADD_REAL_TAG('gateway', 'Field_Temp', 1);
        ENIP_ADAPTER_ADD_REAL_TAG('gateway', 'Field_Pressure', 1);
        ENIP_ADAPTER_ADD_BOOL_TAG('gateway', 'Field_Running', 1);
        ENIP_ADAPTER_ADD_DINT_TAG('gateway', 'Field_Fault', 1);
        state := 4;

    4: (* Start both *)
        ENIP_SCANNER_CONNECT('field_plc');
        ENIP_ADAPTER_START('gateway');
        state := 10;

    5: (* ... *)

    10: (* Running — bridge data *)
        IF ENIP_SCANNER_CONNECTED('field_plc') THEN
            temp     := ENIP_SCANNER_READ_REAL('field_plc', 'ProcessTemp', 0);
            pressure := ENIP_SCANNER_READ_REAL('field_plc', 'ProcessPressure', 0);
            running  := ENIP_SCANNER_READ_BOOL('field_plc', 'SystemRunning', 0);
            fault    := ENIP_SCANNER_READ_DINT('field_plc', 'FaultCode', 0);

            ENIP_ADAPTER_SET_REAL('gateway', 'Field_Temp', 0, temp);
            ENIP_ADAPTER_SET_REAL('gateway', 'Field_Pressure', 0, pressure);
            ENIP_ADAPTER_SET_BOOL('gateway', 'Field_Running', 0, running);
            ENIP_ADAPTER_SET_DINT('gateway', 'Field_Fault', 0, fault);
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 7. Multi-PLC Scanning

GoPLC can manage multiple scanner instances simultaneously, each polling a different PLC independently.

```iecst
PROGRAM POU_MultiPLC
VAR
    state : INT := 0;
    ok : BOOL;

    (* PLC 1 — Packaging line *)
    pkg_speed : REAL;
    pkg_count : DINT;

    (* PLC 2 — Palletizer *)
    pal_position : DINT;
    pal_fault : BOOL;

    (* PLC 3 — Stretch wrapper *)
    wrap_cycles : DINT;
END_VAR

CASE state OF
    0: (* Create all scanners *)
        ENIP_SCANNER_CREATE('packaging', '10.0.1.10', 44818, 100);
        ENIP_SCANNER_CREATE('palletizer', '10.0.1.11', 44818, 200);
        ENIP_SCANNER_CREATE('wrapper', '10.0.1.12', 44818, 500);
        state := 1;

    1: (* Register tags for each *)
        ENIP_SCANNER_ADD_REAL_TAG('packaging', 'LineSpeed', 1);
        ENIP_SCANNER_ADD_DINT_TAG('packaging', 'CaseCount', 1);

        ENIP_SCANNER_ADD_DINT_TAG('palletizer', 'Position', 1);
        ENIP_SCANNER_ADD_BOOL_TAG('palletizer', 'FaultActive', 1);

        ENIP_SCANNER_ADD_DINT_TAG('wrapper', 'WrapCycles', 1);
        state := 2;

    2: (* Connect all *)
        ENIP_SCANNER_CONNECT('packaging');
        ENIP_SCANNER_CONNECT('palletizer');
        ENIP_SCANNER_CONNECT('wrapper');
        state := 10;

    10: (* Read all PLCs *)
        pkg_speed    := ENIP_SCANNER_READ_REAL('packaging', 'LineSpeed', 0);
        pkg_count    := ENIP_SCANNER_READ_DINT('packaging', 'CaseCount', 0);
        pal_position := ENIP_SCANNER_READ_DINT('palletizer', 'Position', 0);
        pal_fault    := ENIP_SCANNER_READ_BOOL('palletizer', 'FaultActive', 0);
        wrap_cycles  := ENIP_SCANNER_READ_DINT('wrapper', 'WrapCycles', 0);
END_CASE;
END_PROGRAM
```

> **Independent poll rates.** Each scanner runs its own goroutine with its own poll timer. A slow PLC on a 500ms cycle does not block a fast PLC on a 100ms cycle.

---

## 8. Timing and Performance

### 8.1 Scanner Timing

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| Poll rate | 100ms | 10ms - 60,000ms | Per-scanner, set at create time |
| CIP timeout | 5,000ms | — | Per-request timeout |
| Reconnect delay | 5,000ms | — | Wait before reconnecting after failure |

The scanner poll loop:
1. Read all registered tags (one CIP Read Tag Service per tag)
2. Process any queued writes (one CIP Write Tag Service per pending write)
3. Sleep until next poll interval

### 8.2 Adapter Timing

The adapter is event-driven -- it responds to incoming CIP requests as they arrive. There is no polling loop on the server side. Response latency is typically sub-millisecond for tag reads.

### 8.3 Data Freshness

| Scenario | Worst-Case Latency |
|----------|-------------------|
| Scanner read (cached) | 0ms (last polled value) |
| Scanner data age | poll_rate_ms (one poll cycle) |
| Scanner write delivery | poll_rate_ms (queued for next cycle) |
| Adapter read response | < 1ms (immediate from memory) |
| Adapter write notification | Next ST scan cycle |
| Round-trip (write PLC, read back) | 2 x poll_rate_ms |

---

## 9. Troubleshooting

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ENIP_SCANNER_CONNECT` returns FALSE | PLC unreachable | Verify IP, ping PLC, check port 44818 |
| `ENIP_SCANNER_CONNECTED` flaps TRUE/FALSE | Network instability | Check cables, switch, reduce poll rate |
| Read returns 0 / FALSE for all tags | Tag name mismatch | Tag names are case-sensitive; verify in RSLogix |
| Read returns stale data | Poll rate too slow | Decrease `poll_rate_ms` at create time |
| Write appears to have no effect | Tag is controller-written | Check PLC logic isn't overwriting the tag every scan |
| Adapter not visible on network | Firewall blocking port | Open TCP 44818 inbound on GoPLC host |
| Multiple adapters fail | Port conflict | Each adapter needs a unique port |

### Verifying Connectivity

```iecst
(* Quick connection test *)
PROGRAM POU_ConnTest
VAR
    state : INT := 0;
    ok : BOOL;
    connected : BOOL;
    tag_count : DINT;
END_VAR

CASE state OF
    0:
        ok := ENIP_SCANNER_CREATE('test', '10.0.0.50', 44818);
        IF ok THEN state := 1; END_IF;

    1: (* Auto-register to verify we can browse *)
        tag_count := ENIP_SCANNER_AUTO_REGISTER('test');
        (* tag_count > 0 means we successfully browsed the PLC *)
        state := 2;

    2:
        ok := ENIP_SCANNER_CONNECT('test');
        IF ok THEN state := 3; END_IF;

    3:
        connected := ENIP_SCANNER_CONNECTED('test');
        (* TRUE = full communication established *)
        (* Clean up *)
        ENIP_SCANNER_DELETE('test');
        state := 99;

    99: (* Done *) ;
END_CASE;
END_PROGRAM
```

---

## Appendix A: Scanner Function Quick Reference

| Function | Signature | Returns |
|----------|-----------|---------|
| `ENIP_SCANNER_CREATE` | `(name, host, port, [poll_rate_ms])` | BOOL |
| `ENIP_SCANNER_CONNECT` | `(name)` | BOOL |
| `ENIP_SCANNER_CONNECTED` | `(name)` | BOOL |
| `ENIP_SCANNER_DISCONNECT` | `(name)` | BOOL |
| `ENIP_SCANNER_DELETE` | `(name)` | BOOL |
| `ENIP_SCANNER_LIST` | `()` | ARRAY |
| `ENIP_SCANNER_ADD_TAG` | `(name, tag, dataType, count)` | BOOL |
| `ENIP_SCANNER_ADD_BOOL_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_SCANNER_ADD_INT_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_SCANNER_ADD_DINT_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_SCANNER_ADD_REAL_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_SCANNER_ADD_STRING_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_SCANNER_AUTO_REGISTER` | `(name)` | DINT |
| `ENIP_SCANNER_READ_BOOL` | `(name, tag, index)` | BOOL |
| `ENIP_SCANNER_READ_INT` | `(name, tag, index)` | INT |
| `ENIP_SCANNER_READ_DINT` | `(name, tag, index)` | DINT |
| `ENIP_SCANNER_READ_REAL` | `(name, tag, index)` | REAL |
| `ENIP_SCANNER_READ_STRING` | `(name, tag, index)` | STRING |
| `ENIP_SCANNER_WRITE_BOOL` | `(name, tag, index, value)` | BOOL |
| `ENIP_SCANNER_WRITE_INT` | `(name, tag, index, value)` | BOOL |
| `ENIP_SCANNER_WRITE_DINT` | `(name, tag, index, value)` | BOOL |
| `ENIP_SCANNER_WRITE_REAL` | `(name, tag, index, value)` | BOOL |
| `ENIP_SCANNER_WRITE_STRING` | `(name, tag, index, value)` | BOOL |

## Appendix B: Adapter Function Quick Reference

| Function | Signature | Returns |
|----------|-----------|---------|
| `ENIP_ADAPTER_CREATE` | `(name, [port])` | BOOL |
| `ENIP_ADAPTER_START` | `(name)` | BOOL |
| `ENIP_ADAPTER_STOP` | `(name)` | BOOL |
| `ENIP_ADAPTER_IS_RUNNING` | `(name)` | BOOL |
| `ENIP_ADAPTER_DELETE` | `(name)` | BOOL |
| `ENIP_ADAPTER_LIST` | `()` | ARRAY |
| `ENIP_ADAPTER_GET_STATS` | `(name)` | MAP |
| `ENIP_ADAPTER_ADD_TAG` | `(name, tag, type, count)` | BOOL |
| `ENIP_ADAPTER_ADD_BOOL_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_ADAPTER_ADD_INT_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_ADAPTER_ADD_DINT_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_ADAPTER_ADD_REAL_TAG` | `(name, tag, count)` | BOOL |
| `ENIP_ADAPTER_SET_BOOL` | `(name, tag, index, value)` | BOOL |
| `ENIP_ADAPTER_SET_INT` | `(name, tag, index, value)` | BOOL |
| `ENIP_ADAPTER_SET_DINT` | `(name, tag, index, value)` | BOOL |
| `ENIP_ADAPTER_SET_REAL` | `(name, tag, index, value)` | BOOL |
| `ENIP_ADAPTER_GET_BOOL` | `(name, tag, index)` | BOOL |
| `ENIP_ADAPTER_GET_INT` | `(name, tag, index)` | INT |
| `ENIP_ADAPTER_GET_DINT` | `(name, tag, index)` | DINT |
| `ENIP_ADAPTER_GET_REAL` | `(name, tag, index)` | REAL |

---

*GoPLC v1.0.533 | 43 EtherNet/IP functions (23 scanner + 20 adapter)*
*CIP over EtherNet/IP | TCP port 44818 | Allen-Bradley compatible*

*(c) 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
