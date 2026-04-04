# GoPLC Omron FINS Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC implements an Omron FINS (Factory Interface Network Service) **client** — callable directly from IEC 61131-3 Structured Text. No external libraries, no configuration files, no code generation. You create connections, read/write PLC memory areas, configure background polling, and manage clients with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `FINSClientCreate` / `FINSClientRead*` / `FINSClientWrite*` / `FINSClientAdd*Poll` | Read/write memory areas on Omron CJ, NJ, NX series PLCs |

This is a client-only protocol in GoPLC. The FINS client connects to Omron PLCs over UDP (default port 9600) using the FINS/UDP transport, reading and writing the PLC's Data Memory (DM), Core I/O (CIO), and other memory areas.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ST Program (IEC 61131-3 Structured Text)               │  │
│  │                                                        │  │
│  │ FINSClientCreate('omron1', '10.0.0.34', 9600,          │  │
│  │                   0, 10, 100);                         │  │
│  │ FINSClientConnect('omron1');                            │  │
│  │ FINSClientAddDMPoll('omron1', 0, 100);                 │  │
│  │                                                        │  │
│  │ dm_vals := FINSClientReadDM('omron1', 0, 10);          │  │
│  │ FINSClientWriteDMWord('omron1', 100, 1234);            │  │
│  └──────────────────────────┬─────────────────────────────┘  │
│                             │                                │
│                             │  FINS/UDP                      │
│                             │  (Port 9600 default)           │
└─────────────────────────────┼────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│  Omron PLC                                                   │
│                                                              │
│  CJ2M, CJ2H, NJ501, NX102, NX1P2, etc.                     │
│                                                              │
│  Memory Areas:                                               │
│    DM (Data Memory)    — D0..D32767   (16-bit words)         │
│    CIO (Core I/O)      — CIO0..CIO6143 (16-bit words)       │
│    WR (Work Area)      — W0..W511                            │
│    HR (Holding Area)   — H0..H511                            │
│    AR (Auxiliary Area)  — A0..A959                            │
│                                                              │
│  FINS/UDP Server listening on port 9600                      │
└──────────────────────────────────────────────────────────────┘
```

### Omron Memory Areas

Omron PLCs organize data into named memory areas. GoPLC's FINS client provides direct access to the two most commonly used areas:

| Area | FINS Code | Address Range | Description |
|------|-----------|---------------|-------------|
| **DM** (Data Memory) | 0x82 | D0 - D32767 | General-purpose storage. Recipes, setpoints, configuration parameters. Retentive by default on most CPUs. |
| **CIO** (Core I/O) | 0xB0 | CIO 0 - CIO 6143 | Physical I/O image, internal relays, and inter-unit communication. Bits map directly to I/O terminals. |

> **Addressing Note:** GoPLC uses zero-based word addressing. Address `0` reads D0 (or CIO 0). A count of `10` reads 10 consecutive 16-bit words. This matches CX-Programmer and Sysmac Studio conventions.

### FINS Node Addressing

FINS uses a source/destination node model to route messages across Omron networks. Every FINS frame carries a destination node address (the PLC) and a source node address (GoPLC).

| Parameter | Description | Typical Value |
|-----------|-------------|---------------|
| `destNode` | PLC's FINS node address — usually the last octet of its IP address | `34` (for 10.0.0.34) |
| `srcNode` | GoPLC's FINS node address — usually the last octet of its IP address | `196` (for 10.0.0.196) |

> **Auto-addressing:** On Ethernet, Omron PLCs typically derive the FINS node address from the last octet of the IP address. If the PLC is at `10.0.0.34`, its node address is `34`. Set `destNode` accordingly. If you leave the node addresses at their defaults (`0`), the FINS/UDP automatic node negotiation will resolve them during the initial handshake — but explicit addressing is more reliable and avoids the negotiation round-trip.

---

## 2. Client Functions

The FINS client connects to an Omron PLC over UDP and performs read/write operations on PLC memory areas. It also supports background polling to keep local copies of memory ranges current.

### 2.1 Connection Management

#### FINSClientCreate — Create Named Connection

```iecst
FINSClientCreate(name: STRING, host: STRING [, port: INT] [, destNode: INT]
                 [, srcNode: INT] [, pollRateMs: INT]) : BOOL
```

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | STRING | Yes | — | Unique connection name |
| `host` | STRING | Yes | — | IP address or hostname of the Omron PLC |
| `port` | INT | No | 9600 | FINS/UDP port |
| `destNode` | INT | No | 0 | PLC's FINS node address (0 = auto-negotiate) |
| `srcNode` | INT | No | 0 | GoPLC's FINS node address (0 = auto-negotiate) |
| `pollRateMs` | INT | No | 100 | Background poll interval in milliseconds |

Returns: `BOOL` — TRUE if the client was created successfully.

```iecst
(* Minimal — auto-negotiate nodes, default port and poll rate *)
ok := FINSClientCreate('omron1', '10.0.0.34');

(* Explicit node addressing — recommended for production *)
ok := FINSClientCreate('omron1', '10.0.0.34', 9600, 34, 196);

(* Explicit everything — 50ms poll rate for fast I/O *)
ok := FINSClientCreate('omron1', '10.0.0.34', 9600, 34, 196, 50);
```

> **Named connections:** Every FINS client connection has a unique string name. This name is used in all subsequent calls. You can create as many connections as you need — one per PLC is the typical pattern.

#### FINSClientConnect — Open UDP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from FINSClientCreate |

Returns: `BOOL` — TRUE if connected successfully.

```iecst
ok := FINSClientConnect('omron1');
```

> **UDP connection:** Unlike TCP-based protocols, FINS uses UDP. "Connecting" establishes the local socket, performs FINS node address negotiation (if nodes are set to 0), and starts the background poll loop if any poll items have been registered.

#### FINSClientDisconnect — Close Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully.

```iecst
ok := FINSClientDisconnect('omron1');
```

#### FINSClientIsConnected — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the connection is active.

```iecst
IF NOT FINSClientIsConnected('omron1') THEN
    FINSClientConnect('omron1');
END_IF;
```

#### FINSClientDelete — Remove Client

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the client was removed.

Disconnects (if connected) and removes the client instance, including all poll items.

```iecst
ok := FINSClientDelete('omron1');
```

#### FINSClientList — List All Clients

Returns: `[]STRING` — Array of client instance names.

```iecst
clients := FINSClientList();
(* Returns: ['omron1', 'omron2'] *)
```

#### Example: Connection Lifecycle

```iecst
PROGRAM POU_FINSInit
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create connection with explicit node addresses *)
        ok := FINSClientCreate('omron1', '10.0.0.34', 9600, 34, 196, 100);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Register poll items before connecting *)
        FINSClientAddDMPoll('omron1', 0, 100);     (* D0-D99 *)
        FINSClientAddCIOPoll('omron1', 0, 32);     (* CIO 0-31 *)
        state := 2;

    2: (* Connect — starts polling *)
        ok := FINSClientConnect('omron1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT FINSClientIsConnected('omron1') THEN
            state := 2;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.2 Reading Memory Areas

#### FINSClientReadDM — Read Data Memory (Multiple Words)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting DM address (0-based) |
| `count` | INT | Number of 16-bit words to read |

Returns: `[]INT` — Array of 16-bit word values.

```iecst
(* Read 10 words starting at D0 *)
dm_vals := FINSClientReadDM('omron1', 0, 10);
(* dm_vals[0] = D0, dm_vals[1] = D1, ..., dm_vals[9] = D9 *)

(* Read recipe parameters at D1000-D1019 *)
recipe := FINSClientReadDM('omron1', 1000, 20);
```

#### FINSClientReadDMWord — Read Single DM Word

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | DM address (0-based) |

Returns: `INT` — Single 16-bit word value.

```iecst
(* Read setpoint from D100 *)
setpoint := FINSClientReadDMWord('omron1', 100);
```

> **When to use which:** Use `FINSClientReadDMWord` for reading a single register (e.g., a setpoint or status word). Use `FINSClientReadDM` when you need a contiguous block (e.g., recipe data, array values). Reading a block in one call is significantly more efficient than reading words individually in a loop.

#### FINSClientReadCIO — Read Core I/O Area (Multiple Words)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting CIO address (0-based) |
| `count` | INT | Number of 16-bit words to read |

Returns: `[]INT` — Array of 16-bit word values.

```iecst
(* Read 16 words of I/O image starting at CIO 0 *)
io_image := FINSClientReadCIO('omron1', 0, 16);

(* Check bit 3 of CIO word 0 — physical input terminal 0.03 *)
input_03 := (io_image[0] AND 16#0008) <> 0;
```

#### FINSClientReadCIOWord — Read Single CIO Word

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | CIO address (0-based) |

Returns: `INT` — Single 16-bit word value.

```iecst
(* Read CIO word 100 — internal relay area *)
relay_word := FINSClientReadCIOWord('omron1', 100);
```

#### Example: Reading Mixed Areas

```iecst
PROGRAM POU_FINSRead
VAR
    setpoint : INT;
    actual_temp : INT;
    io_status : INT;
    input_bit_5 : BOOL;
    dm_block : ARRAY[0..9] OF INT;
    i : INT;
END_VAR

IF FINSClientIsConnected('omron1') THEN
    (* Read individual values *)
    setpoint := FINSClientReadDMWord('omron1', 100);
    actual_temp := FINSClientReadDMWord('omron1', 101);

    (* Read I/O status word *)
    io_status := FINSClientReadCIOWord('omron1', 0);
    input_bit_5 := (io_status AND 16#0020) <> 0;

    (* Read a block of DM registers *)
    dm_block := FINSClientReadDM('omron1', 200, 10);
END_IF;
END_PROGRAM
```

---

### 2.3 Writing Memory Areas

#### FINSClientWriteDM — Write Data Memory (Multiple Words)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting DM address (0-based) |
| `values` | []INT | Array of 16-bit word values to write |

Returns: `BOOL` — TRUE if the write was acknowledged by the PLC.

```iecst
(* Write 5 recipe values starting at D500 *)
ok := FINSClientWriteDM('omron1', 500, [1000, 2000, 500, 100, 50]);

(* Zero out a range *)
ok := FINSClientWriteDM('omron1', 600, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
```

#### FINSClientWriteDMWord — Write Single DM Word

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | DM address (0-based) |
| `value` | INT | 16-bit word value to write |

Returns: `BOOL` — TRUE if the write was acknowledged by the PLC.

```iecst
(* Write setpoint to D100 *)
ok := FINSClientWriteDMWord('omron1', 100, 1500);

(* Set command word *)
ok := FINSClientWriteDMWord('omron1', 200, 16#0001);
```

#### Example: Read-Modify-Write Pattern

```iecst
PROGRAM POU_FINSWrite
VAR
    state : INT := 0;
    ok : BOOL;
    current_val : INT;
    new_setpoint : INT := 2500;
END_VAR

IF FINSClientIsConnected('omron1') THEN
    CASE state OF
        0: (* Write a new setpoint to the PLC *)
            ok := FINSClientWriteDMWord('omron1', 100, new_setpoint);
            IF ok THEN
                state := 1;
            END_IF;

        1: (* Verify the write by reading back *)
            current_val := FINSClientReadDMWord('omron1', 100);
            IF current_val = new_setpoint THEN
                state := 10;  (* Success *)
            ELSE
                state := 0;   (* Retry *)
            END_IF;

        10: (* Done — normal operation *)
            (* ... *)
    END_CASE;
END_IF;
END_PROGRAM
```

---

### 2.4 Background Polling

The FINS client supports automatic background polling of memory ranges. Registered poll items are read at the configured `pollRateMs` interval, keeping a local cache current. On-demand `FINSClientReadDM` / `FINSClientReadCIO` calls return cached values when the requested range falls within a polled region, avoiding redundant network traffic.

```
Poll cycle (every pollRateMs):
  For each registered poll item:
    Build FINS Memory Area Read frame
                    ↓
            UDP to PLC (port 9600)
                    ↓
    PLC responds with word data
                    ↓
    GoPLC updates local cache
                    ↓
  ST code reads latest values (from cache, zero-latency)
```

#### FINSClientAddPollItem — Add Generic Poll Item

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `area` | STRING | Memory area identifier: `'DM'` or `'CIO'` |
| `address` | INT | Starting address |
| `count` | INT | Number of 16-bit words to poll |

Returns: `BOOL` — TRUE if the poll item was registered.

```iecst
(* Poll D0-D99 every cycle *)
ok := FINSClientAddPollItem('omron1', 'DM', 0, 100);

(* Poll CIO 0-31 every cycle *)
ok := FINSClientAddPollItem('omron1', 'CIO', 0, 32);
```

#### FINSClientAddDMPoll — Convenience DM Poll

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting DM address |
| `count` | INT | Number of DM words to poll |

Returns: `BOOL` — TRUE if the poll item was registered.

Equivalent to `FINSClientAddPollItem(name, 'DM', address, count)`.

```iecst
(* Poll D0-D99 *)
ok := FINSClientAddDMPoll('omron1', 0, 100);

(* Poll recipe area D1000-D1099 *)
ok := FINSClientAddDMPoll('omron1', 1000, 100);
```

#### FINSClientAddCIOPoll — Convenience CIO Poll

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting CIO address |
| `count` | INT | Number of CIO words to poll |

Returns: `BOOL` — TRUE if the poll item was registered.

Equivalent to `FINSClientAddPollItem(name, 'CIO', address, count)`.

```iecst
(* Poll CIO 0-31 — physical I/O image *)
ok := FINSClientAddCIOPoll('omron1', 0, 32);
```

> **Register poll items before connecting.** Add all your poll items after `FINSClientCreate` but before `FINSClientConnect`. The poll loop starts when the connection is established. You can add poll items after connecting, but they take effect on the next poll cycle.

> **Max payload:** A single FINS Memory Area Read response can carry up to 999 words (1998 bytes). If your poll count exceeds 999, GoPLC splits it into multiple FINS requests automatically. For best performance, keep individual poll ranges under 999 words.

#### Example: Polled Data with On-Demand Reads

```iecst
PROGRAM POU_FINSPolling
VAR
    state : INT := 0;
    ok : BOOL;
    dm_block : ARRAY[0..9] OF INT;
    setpoint : INT;
    io_word : INT;
    motor_running : BOOL;
END_VAR

CASE state OF
    0: (* Create and configure *)
        ok := FINSClientCreate('omron1', '10.0.0.34', 9600, 34, 196, 100);
        IF ok THEN
            (* Register poll ranges *)
            FINSClientAddDMPoll('omron1', 0, 200);     (* D0-D199 polled *)
            FINSClientAddCIOPoll('omron1', 0, 32);     (* CIO 0-31 polled *)
            state := 1;
        END_IF;

    1: (* Connect — polling starts *)
        ok := FINSClientConnect('omron1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Normal operation — reads come from cache *)
        IF FINSClientIsConnected('omron1') THEN
            (* These reads are served from the poll cache *)
            dm_block := FINSClientReadDM('omron1', 0, 10);
            setpoint := FINSClientReadDMWord('omron1', 100);

            (* CIO reads also from cache *)
            io_word := FINSClientReadCIOWord('omron1', 0);
            motor_running := (io_word AND 16#0001) <> 0;
        ELSE
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 3. Supported PLC Series

GoPLC's FINS client is compatible with any Omron PLC that supports FINS/UDP. This includes the following series:

| Series | Models | Notes |
|--------|--------|-------|
| **CJ1** | CJ1M, CJ1H, CJ1G | Older series. FINS over Ethernet via ETN21 unit. |
| **CJ2** | CJ2M, CJ2H | Built-in Ethernet on CPU. Most common in brownfield installations. |
| **NJ** | NJ101, NJ301, NJ501 | Sysmac series. FINS supported alongside EtherNet/IP. |
| **NX** | NX1P2, NX102, NX502, NX701 | Latest generation. FINS supported by default. Enable in Sysmac Studio under PLC > Built-in EtherNet/IP Port Settings > FINS. |
| **CP** | CP1L, CP1H, CP1E | Compact PLCs. FINS via optional Ethernet adapter (CP1W-CIF41). |
| **CS** | CS1G, CS1H, CS1D | Legacy rack PLCs. FINS over Ethernet via ETN21 unit. |

> **NX/NJ Series:** On Sysmac controllers, FINS is disabled by default. In Sysmac Studio, navigate to **Controller Setup > Built-in EtherNet/IP Port > FINS Settings** and set **FINS/UDP: Enable**. Also confirm the FINS node address matches the last octet of the IP or set it explicitly.

---

## 4. FINS Protocol Notes

### 4.1 Transport

FINS/UDP uses port **9600** by default. GoPLC sends FINS commands as UDP datagrams. Each request/response is a single UDP packet containing a FINS header and command payload.

```
┌──────────────────────────────────────────┐
│  UDP Datagram (Port 9600)                │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │  FINS Header (10 bytes)           │  │
│  │                                    │  │
│  │  ICF  RSV  GCT  DNA  DA1  DA2     │  │
│  │  SNA  SA1  SA2  SID               │  │
│  ├────────────────────────────────────┤  │
│  │  FINS Command (2 bytes)           │  │
│  │                                    │  │
│  │  MRC  SRC                          │  │
│  ├────────────────────────────────────┤  │
│  │  Command Data (variable)          │  │
│  │                                    │  │
│  │  Area code, start address, count   │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

| Field | Size | Description |
|-------|------|-------------|
| ICF | 1 byte | Information Control Field (0x80 = command, 0xC0 = response) |
| RSV | 1 byte | Reserved (0x00) |
| GCT | 1 byte | Gateway Count (0x02 default) |
| DNA | 1 byte | Destination Network Address (0x00 = local) |
| DA1 | 1 byte | Destination Node Address (`destNode`) |
| DA2 | 1 byte | Destination Unit Address (0x00 = CPU unit) |
| SNA | 1 byte | Source Network Address (0x00 = local) |
| SA1 | 1 byte | Source Node Address (`srcNode`) |
| SA2 | 1 byte | Source Unit Address (0x00) |
| SID | 1 byte | Service ID (sequence number, 0x00-0xFF) |

You never build FINS frames manually — `FINSClientReadDM`, `FINSClientWriteDM`, and the other functions handle all framing, sequencing, and error checking.

### 4.2 FINS Commands Used

| Operation | MRC | SRC | Description |
|-----------|-----|-----|-------------|
| Memory Area Read | 01 | 01 | Read words from DM, CIO, WR, HR, AR |
| Memory Area Write | 01 | 02 | Write words to DM, CIO, WR, HR, AR |

### 4.3 Error Handling

FINS responses include a 2-byte end code. GoPLC interprets these and surfaces them as function return values:

| End Code | Meaning | GoPLC Behavior |
|----------|---------|----------------|
| 0x0000 | Normal completion | Function returns requested data |
| 0x0001 | Service canceled | Retry on next poll cycle |
| 0x0105 | Node address out of range | Check destNode/srcNode settings |
| 0x0204 | Address out of range | Check DM/CIO address bounds |
| 0x0401 | Aborted due to unit error | PLC CPU error — check PLC status |

Read functions return zero values on error. Write functions return FALSE. Check `FINSClientIsConnected` to distinguish between a communication failure and a PLC-side error.

### 4.4 Timing

| Parameter | Typical Value | Notes |
|-----------|---------------|-------|
| UDP round-trip | 1-5 ms | Local network, switched Ethernet |
| Poll cycle (default) | 100 ms | Configurable via `pollRateMs` |
| FINS response timeout | 2 seconds | GoPLC internal timeout before marking connection lost |
| Reconnect backoff | 1-10 seconds | Exponential backoff on repeated failures |

---

## 5. Practical Examples

### 5.1 Temperature Monitoring (CJ2M)

A CJ2M PLC reads thermocouples via an analog input unit. Temperature values (scaled to 0.1 degC) are stored in D100-D103. GoPLC polls these values and exposes them to other systems.

```iecst
PROGRAM POU_TempMonitor
VAR
    state : INT := 0;
    ok : BOOL;
    temps : ARRAY[0..3] OF INT;
    zone1_degC : REAL;
    zone2_degC : REAL;
    zone3_degC : REAL;
    zone4_degC : REAL;
    alarm : BOOL;
    HIGH_LIMIT : REAL := 85.0;
END_VAR

CASE state OF
    0: (* Initialize *)
        ok := FINSClientCreate('cj2m', '10.0.0.34', 9600, 34, 196, 100);
        IF ok THEN
            FINSClientAddDMPoll('cj2m', 100, 4);  (* D100-D103 *)
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := FINSClientConnect('cj2m');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running *)
        IF FINSClientIsConnected('cj2m') THEN
            temps := FINSClientReadDM('cj2m', 100, 4);

            (* Scale from 0.1 degC to degC *)
            zone1_degC := INT_TO_REAL(temps[0]) / 10.0;
            zone2_degC := INT_TO_REAL(temps[1]) / 10.0;
            zone3_degC := INT_TO_REAL(temps[2]) / 10.0;
            zone4_degC := INT_TO_REAL(temps[3]) / 10.0;

            (* High temperature alarm *)
            alarm := (zone1_degC > HIGH_LIMIT) OR
                     (zone2_degC > HIGH_LIMIT) OR
                     (zone3_degC > HIGH_LIMIT) OR
                     (zone4_degC > HIGH_LIMIT);
        ELSE
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

### 5.2 Motor Control via CIO Bits

Read physical I/O status from CIO and write command words to DM registers used by the PLC's motor control logic.

```iecst
PROGRAM POU_MotorControl
VAR
    state : INT := 0;
    ok : BOOL;
    io_word : INT;
    start_button : BOOL;
    stop_button : BOOL;
    motor_feedback : BOOL;
    cmd_run : INT := 0;
END_VAR

CASE state OF
    0: (* Initialize *)
        ok := FINSClientCreate('line1', '10.0.0.34', 9600, 34, 196, 50);
        IF ok THEN
            FINSClientAddCIOPoll('line1', 0, 4);   (* CIO 0-3: input terminals *)
            FINSClientAddDMPoll('line1', 200, 10);  (* D200-D209: status area *)
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := FINSClientConnect('line1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running *)
        IF FINSClientIsConnected('line1') THEN
            (* Read physical inputs from CIO *)
            io_word := FINSClientReadCIOWord('line1', 0);
            start_button := (io_word AND 16#0001) <> 0;   (* CIO 0.00 *)
            stop_button := (io_word AND 16#0002) <> 0;    (* CIO 0.01 *)
            motor_feedback := (io_word AND 16#0004) <> 0;  (* CIO 0.02 *)

            (* Motor control logic *)
            IF start_button AND NOT stop_button THEN
                cmd_run := 1;
            ELSIF stop_button THEN
                cmd_run := 0;
            END_IF;

            (* Write command to PLC *)
            FINSClientWriteDMWord('line1', 300, cmd_run);
        ELSE
            state := 1;
        END_IF;
END_CASE;
END_PROGRAM
```

### 5.3 Multi-PLC Communication

GoPLC can communicate with multiple Omron PLCs simultaneously. Each gets its own named connection.

```iecst
PROGRAM POU_MultiPLC
VAR
    state : INT := 0;
    ok : BOOL;
    mixer_speed : INT;
    conveyor_status : INT;
    fill_level : INT;
END_VAR

CASE state OF
    0: (* Create connections to three PLCs *)
        ok := FINSClientCreate('mixer', '10.0.0.34', 9600, 34, 196, 100);
        ok := FINSClientCreate('conveyor', '10.0.0.35', 9600, 35, 196, 100);
        ok := FINSClientCreate('filler', '10.0.0.36', 9600, 36, 196, 100);

        (* Register polls *)
        FINSClientAddDMPoll('mixer', 0, 50);
        FINSClientAddDMPoll('conveyor', 0, 50);
        FINSClientAddDMPoll('filler', 0, 50);
        state := 1;

    1: (* Connect all *)
        FINSClientConnect('mixer');
        FINSClientConnect('conveyor');
        FINSClientConnect('filler');
        state := 10;

    10: (* Running — read from each PLC *)
        mixer_speed := FINSClientReadDMWord('mixer', 10);
        conveyor_status := FINSClientReadDMWord('conveyor', 20);
        fill_level := FINSClientReadDMWord('filler', 30);

        (* Cross-PLC coordination: send mixer speed to filler *)
        FINSClientWriteDMWord('filler', 100, mixer_speed);
END_CASE;
END_PROGRAM
```

> **Source node sharing:** When connecting to multiple PLCs, all connections use the same `srcNode` (GoPLC's node address). Each PLC identifies GoPLC by this source node. The `destNode` is different for each PLC.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Connect returns FALSE | PLC not reachable on network | Verify IP with `ping`. Check that FINS/UDP is enabled on PLC. Confirm port 9600 is not firewalled. |
| Reads return all zeros | Wrong node addresses | Set `destNode` to the last octet of the PLC's IP. Set `srcNode` to the last octet of GoPLC's IP. |
| Reads return all zeros | Address out of range | Verify the DM/CIO addresses exist in the PLC program. CJ2M supports D0-D32767, CIO 0-6143. |
| Intermittent timeouts | Network congestion or poll rate too fast | Increase `pollRateMs`. Check for UDP packet loss with `netstat -su`. |
| Connection drops after PLC mode change | PLC switched to PROGRAM mode | Some PLCs reject FINS in PROGRAM mode. Switch PLC to RUN or MONITOR mode. |
| "Node address out of range" error | destNode or srcNode > 254 | Node addresses must be 1-254. Check PLC IP and FINS settings. |
| NX/NJ PLC does not respond | FINS disabled on Sysmac controller | In Sysmac Studio: Controller Setup > Built-in EtherNet/IP Port > FINS Settings > Enable FINS/UDP. |
| Writes succeed but PLC does not act | Writing to wrong DM area | Confirm which DM addresses the PLC program reads for commands. Check CX-Programmer or Sysmac Studio. |

---

## Appendix A: Function Quick Reference

### Client Functions (15)

| Function | Returns | Description |
|----------|---------|-------------|
| `FINSClientCreate(name, host [, port] [, destNode] [, srcNode] [, pollRateMs])` | BOOL | Create named connection to Omron PLC |
| `FINSClientConnect(name)` | BOOL | Open UDP connection and start polling |
| `FINSClientDisconnect(name)` | BOOL | Close connection |
| `FINSClientIsConnected(name)` | BOOL | Check connection state |
| `FINSClientReadDM(name, address, count)` | []INT | Read DM words (Data Memory) |
| `FINSClientWriteDM(name, address, values)` | BOOL | Write DM words |
| `FINSClientReadDMWord(name, address)` | INT | Read single DM word |
| `FINSClientWriteDMWord(name, address, value)` | BOOL | Write single DM word |
| `FINSClientReadCIO(name, address, count)` | []INT | Read CIO words (Core I/O) |
| `FINSClientReadCIOWord(name, address)` | INT | Read single CIO word |
| `FINSClientAddPollItem(name, area, address, count)` | BOOL | Add generic memory area to poll list |
| `FINSClientAddDMPoll(name, address, count)` | BOOL | Add DM range to poll list |
| `FINSClientAddCIOPoll(name, address, count)` | BOOL | Add CIO range to poll list |
| `FINSClientDelete(name)` | BOOL | Remove client and all poll items |
| `FINSClientList()` | []STRING | List all client instance names |

---

*GoPLC v1.0.520 | FINS/UDP Client | Omron CJ/NJ/NX Series | IEC 61131-3 Structured Text*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
