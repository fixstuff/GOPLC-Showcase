# GoPLC DF1 Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC implements an **Allen-Bradley DF1 full-duplex** serial client callable directly from IEC 61131-3 Structured Text. No RSLinx, no OPC server, no proprietary drivers. Connect a USB-to-RS-232 adapter to a SLC 500, MicroLogix 1000/1100/1400, or PLC-5 and start reading/writing data files with plain function calls.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `DF1ClientCreate` / `DF1ClientRead*` / `DF1ClientWrite*` | Read/write SLC 500 and MicroLogix data files over RS-232 |
| **Diagnostics** | `DF1ClientEcho` / `DF1ClientGetDiagnosticStatus` / `DF1ClientScanNodes` | Network troubleshooting and device discovery |
| **CPU Control** | `DF1ClientSetCPUMode` | Switch processor between Program, Run, and Test modes |
| **Polling** | `DF1ClientAddPollItem` / `DF1ClientGetStats` | Automatic cyclic data collection with tag mapping |

All functions are controlled entirely from IEC 61131-3 Structured Text in GoPLC's browser-based IDE.

### System Diagram

```
┌──────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)              │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │ ST Program                                       │    │
│  │                                                  │    │
│  │ DF1ClientCreate('slc', '/dev/ttyUSB0')           │    │
│  │ DF1ClientConnect('slc')                          │    │
│  │ DF1ClientReadWords('slc', 'N7:0', 10)            │    │
│  │ DF1ClientWriteWord('slc', 'N7:20', 1234)         │    │
│  │ DF1ClientAddPollItem('slc', 'N7:0', 'speed', 1)  │    │
│  └─────────────────────┬────────────────────────────┘    │
│                        │                                 │
│                        │  DF1 Full-Duplex                │
│                        │  (RS-232, configurable baud)    │
└────────────────────────┼─────────────────────────────────┘
                         │
                         │  RS-232 (USB adapter or native)
                         │  Default: 19200, 8N1
                         ▼
┌──────────────────────────────────────────────────────────┐
│  Allen-Bradley PLC                                       │
│                                                          │
│  SLC 500 (CH0 RS-232)     MicroLogix 1000/1100/1400     │
│  PLC-5 (CH0 RS-232)       MicroLogix 1500               │
│                                                          │
│  Data Files:                                             │
│    N7:0-N7:255    Integer (16-bit signed)                │
│    F8:0-F8:255    Float (32-bit IEEE 754)                │
│    B3:0-B3:255    Bit (16-bit words, bit-addressable)    │
│    T4:0           Timer (3 words: CTL, PRE, ACC)         │
│    C5:0           Counter (3 words: CTL, PRE, ACC)       │
│    S:0            Status file                            │
└──────────────────────────────────────────────────────────┘
```

### DF1 Protocol Background

DF1 is Allen-Bradley's point-to-point serial protocol, introduced in the 1980s and still supported by every SLC 500 and MicroLogix processor. GoPLC implements **DF1 full-duplex** (the default for channel 0 RS-232):

| Feature | Full-Duplex | Half-Duplex |
|---------|-------------|-------------|
| **Topology** | Point-to-point (1:1) | Multi-drop (1:N) |
| **Error Recovery** | CRC + sequence numbers + ACK/NAK | BCC + ENQ polling |
| **GoPLC Support** | Yes | Not yet |
| **Typical Use** | Programming port (CH0) | DH-485 bridging |

### Data File Addressing

Allen-Bradley SLC/MicroLogix use a **file:element** addressing scheme:

| Prefix | File Type | Word Size | Address Example | Description |
|--------|-----------|-----------|-----------------|-------------|
| `N` | Integer | 16-bit signed | `N7:0` | General-purpose integer storage |
| `F` | Float | 32-bit IEEE | `F8:0` | Floating-point storage (2 words per element) |
| `B` | Bit | 16-bit word | `B3:0` | Bit-addressable (B3:0/0 through B3:0/15) |
| `T` | Timer | 3 words | `T4:0` | CTL word + PRE + ACC |
| `C` | Counter | 3 words | `C5:0` | CTL word + PRE + ACC |
| `S` | Status | 16-bit | `S:0` | Processor status file |
| `I` | Input | 16-bit | `I:0` | Physical inputs |
| `O` | Output | 16-bit | `O:0` | Physical outputs |

> **Addressing Note:** The number after the prefix is the **file number** (e.g., N**7** is integer file 7). The number after the colon is the **element** (word offset). `N7:0` means "integer file 7, word 0." Default file numbers: N7, F8, B3, T4, C5, S2 — but user-created files can have any number (N9, N10, F20, etc.).

---

## 2. Connection Management

### 2.1 DF1ClientCreate -- Create Named Connection

```iecst
ok := DF1ClientCreate('slc', '/dev/ttyUSB0');
```

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | STRING | Yes | — | Unique connection name |
| `port` | STRING | Yes | — | Serial port path (`/dev/ttyUSB0`, `COM3`) |
| `baud` | INT | No | 19200 | Baud rate (2400, 4800, 9600, 19200, 38400) |
| `localNode` | INT | No | 0 | DF1 source node address (0-254) |
| `remoteNode` | INT | No | 1 | DF1 destination node address (0-254) |

Returns `TRUE` on success. The connection is created but **not yet connected** -- call `DF1ClientConnect` next.

```iecst
(* Defaults: 19200 baud, local node 0, remote node 1 *)
ok := DF1ClientCreate('slc', '/dev/ttyUSB0');

(* Explicit baud rate for older SLC 500 *)
ok := DF1ClientCreate('slc', '/dev/ttyUSB0', 9600);

(* Full specification — node addresses for multi-drop scenarios *)
ok := DF1ClientCreate('slc', '/dev/ttyUSB0', 19200, 0, 1);
```

> **SLC 500 Channel 0 defaults:** 19200 baud, 8 data bits, no parity, 1 stop bit (8N1), full-duplex. These are the factory defaults and match GoPLC's defaults. Only change baud if you have explicitly reconfigured the SLC channel.

> **MicroLogix 1100/1400:** Support up to 38400 baud on the built-in RS-232 port (CH0). The default is 19200.

### 2.2 DF1ClientConnect / Disconnect / IsConnected

```iecst
(* Open the serial port and establish DF1 session *)
ok := DF1ClientConnect('slc');

(* Check connection state *)
IF DF1ClientIsConnected('slc') THEN
    (* read/write operations *)
END_IF;

(* Graceful disconnect *)
DF1ClientDisconnect('slc');
```

`DF1ClientConnect` opens the serial port, configures the baud rate and framing (8N1), and sends a diagnostic status request to verify the remote node is responding.

> **Linux serial permissions:** The GoPLC process needs read/write access to the serial port. Add the user to the `dialout` group: `sudo usermod -aG dialout goplc`. This persists across reboots.

### 2.3 DF1ClientDelete / DF1ClientList

```iecst
(* Remove a connection *)
DF1ClientDelete('slc');

(* List all DF1 connections *)
names := DF1ClientList();
(* Returns: ['slc', 'micro1', 'plc5'] *)
```

---

## 3. Read / Write Operations

### 3.1 DF1ClientReadWords -- Read Multiple Words

```iecst
values := DF1ClientReadWords('slc', 'N7:0', 10);
(* Returns: [100, 200, 0, -32768, 1234, 0, 0, 0, 42, 999] *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | STRING | Starting file:element address (e.g., `N7:0`, `F8:10`, `B3:0`) |
| `count` | INT | Number of words to read (1-120) |

Returns `[]INT` — an array of 16-bit signed integers. For float files (`F8:*`), two consecutive words form one IEEE 754 float (low word first).

> **Maximum read size:** 120 words per request. This is a DF1 protocol limitation — the maximum command data field is 242 bytes. For larger reads, issue multiple requests with incrementing addresses.

### 3.2 DF1ClientWriteWords -- Write Multiple Words

```iecst
ok := DF1ClientWriteWords('slc', 'N7:20', [100, 200, 300]);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | STRING | Starting file:element address |
| `values` | []INT | Array of 16-bit values to write |

Returns `TRUE` on success.

> **Write protection:** SLC 500 processors in **RUN** mode allow writes to data files (N, F, B, etc.) but not to program files. In **PROGRAM** mode, all files are writable. In **REMOTE RUN**, writes to data files are allowed and the processor can be switched to PROGRAM remotely.

### 3.3 DF1ClientReadWord / WriteWord -- Single Word Operations

```iecst
(* Read a single integer *)
speed := DF1ClientReadWord('slc', 'N7:5');
(* Returns: 1750 *)

(* Write a single integer *)
ok := DF1ClientWriteWord('slc', 'N7:20', 1234);
```

These are convenience wrappers around the multi-word functions. Use them when you need exactly one value — they produce the same DF1 command under the hood.

---

## 4. Diagnostics and CPU Control

### 4.1 DF1ClientEcho -- Diagnostic Echo

```iecst
response := DF1ClientEcho('slc', [16#DEAD, 16#BEEF]);
(* Returns: [16#DEAD, 16#BEEF] — exact echo of sent data *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `data` | []INT | Array of words to echo (1-100) |

Returns the echoed data. This is a DF1 **Diagnostic Status** command (CMD 0x06, FNC 0x00) — the remote node must echo the data verbatim. Use this to verify the serial link without touching PLC data files.

> **Troubleshooting tip:** If `DF1ClientEcho` fails but the serial port opens successfully, check: (1) baud rate mismatch, (2) TX/RX wires swapped, (3) wrong node address, (4) SLC channel not configured for DF1 full-duplex.

### 4.2 DF1ClientGetDiagnosticStatus

```iecst
status := DF1ClientGetDiagnosticStatus('slc');
(* Returns: [status_word1, status_word2, ...] — processor-dependent *)
```

Returns the remote node's diagnostic status counters. The content varies by processor type — SLC 500 returns NAK/ENQ/timeout counters, MicroLogix returns similar but with different offsets.

### 4.3 DF1ClientSetCPUMode -- Change Processor Mode

```iecst
(* Switch to RUN mode *)
ok := DF1ClientSetCPUMode('slc', 1);

(* Switch to PROGRAM mode *)
ok := DF1ClientSetCPUMode('slc', 0);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `mode` | INT | 0 = PROGRAM, 1 = RUN, 2 = TEST |

Returns `TRUE` on success.

> **Safety warning:** Switching a running SLC 500 to PROGRAM mode **immediately stops all outputs**. Outputs go to their configured fault state (typically OFF). Use this only during commissioning or maintenance, never in production without proper safety procedures. The TEST mode runs the program but forces all outputs OFF — useful for logic verification.

### 4.4 DF1ClientScanNodes -- Discover Devices on Link

```iecst
nodes := DF1ClientScanNodes('slc', 0, 31);
(* Returns: [1, 5, 12] — node addresses that responded *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `startNode` | INT | First node address to probe (0-254) |
| `endNode` | INT | Last node address to probe (0-254) |

Returns `[]INT` — an array of node addresses that responded to a diagnostic echo. This sends a minimal echo command to each address in the range and collects responses.

> **Scan time:** Each non-responding node incurs a timeout (~500ms default). Scanning 0-31 with one active node takes ~15 seconds. Narrow your scan range when possible.

---

## 5. Automatic Polling

### 5.1 DF1ClientAddPollItem -- Register Cyclic Read

```iecst
ok := DF1ClientAddPollItem('slc', 'N7:0', 'line_speed', 1);
ok := DF1ClientAddPollItem('slc', 'N7:1', 'motor_temp', 1);
ok := DF1ClientAddPollItem('slc', 'N7:10', 'batch_count', 1);
ok := DF1ClientAddPollItem('slc', 'F8:0', 'pressure', 2);   (* float = 2 words *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | STRING | File:element address to read |
| `tag` | STRING | GoPLC tag name to store the value |
| `count` | INT | Number of words (1 for INT, 2 for FLOAT) |

Returns `TRUE` on success. Once registered, GoPLC automatically reads these addresses on a cyclic schedule and updates the named tags. The poll rate is determined by the task scan time — a 100ms task polls all items every 100ms.

Poll items are coalesced into efficient multi-word reads when addresses are contiguous in the same data file. For example, `N7:0` through `N7:9` as 10 separate poll items will be read with a single 10-word read command.

### 5.2 DF1ClientGetStats -- Connection Statistics

```iecst
stats := DF1ClientGetStats('slc');
(* Returns: {
     "tx_count": 15234,
     "rx_count": 15230,
     "nak_count": 2,
     "timeout_count": 4,
     "crc_error_count": 0,
     "retry_count": 6,
     "avg_response_ms": 12,
     "poll_items": 8
   } *)
```

Returns a `MAP` with connection health metrics. Monitor these in your ST program to detect degrading serial links before they fail completely.

| Stat | Description |
|------|-------------|
| `tx_count` | Total commands sent |
| `rx_count` | Total responses received |
| `nak_count` | NAK responses from remote (command rejected) |
| `timeout_count` | Commands with no response |
| `crc_error_count` | Responses with CRC mismatch |
| `retry_count` | Automatic retransmissions |
| `avg_response_ms` | Average round-trip time |
| `poll_items` | Number of registered poll items |

---

## 6. Complete Example: SLC 500 Data Logger

This example connects to an SLC 500 over RS-232, sets up automatic polling of production data, and writes a setpoint back:

```iecst
PROGRAM POU_SLC500_DataLogger
VAR
    state : INT := 0;
    ok : BOOL;
    speed : INT;
    temp : INT;
    pressure_raw : ARRAY[0..1] OF INT;
    new_setpoint : INT := 1500;
    stats : STRING;
END_VAR

CASE state OF
    0: (* Create connection — SLC 500 on CH0, default 19200 baud *)
        ok := DF1ClientCreate('slc', '/dev/ttyUSB0');
        IF ok THEN state := 1; END_IF;

    1: (* Connect *)
        ok := DF1ClientConnect('slc');
        IF ok THEN state := 2; END_IF;

    2: (* Verify link with echo test *)
        IF DF1ClientIsConnected('slc') THEN
            DF1ClientEcho('slc', [16#1234]);
            state := 3;
        END_IF;

    3: (* Register poll items for automatic cyclic reads *)
        DF1ClientAddPollItem('slc', 'N7:0', 'line_speed', 1);
        DF1ClientAddPollItem('slc', 'N7:1', 'motor_temp', 1);
        DF1ClientAddPollItem('slc', 'N7:2', 'batch_count', 1);
        DF1ClientAddPollItem('slc', 'F8:0', 'pressure', 2);
        DF1ClientAddPollItem('slc', 'B3:0', 'status_bits', 1);
        state := 10;

    10: (* Running — read polled values and write setpoints *)
        speed := DF1ClientReadWord('slc', 'N7:0');
        temp := DF1ClientReadWord('slc', 'N7:1');

        (* Write new setpoint if changed *)
        IF new_setpoint <> speed THEN
            DF1ClientWriteWord('slc', 'N7:20', new_setpoint);
        END_IF;

        (* Monitor connection health *)
        stats := DF1ClientGetStats('slc');
END_CASE;
END_PROGRAM
```

---

## 7. Complete Example: MicroLogix 1400 with Node Scanning

```iecst
PROGRAM POU_MicroLogix_Setup
VAR
    state : INT := 0;
    ok : BOOL;
    nodes : ARRAY[0..31] OF INT;
    int_values : ARRAY[0..9] OF INT;
    float_words : ARRAY[0..3] OF INT;
END_VAR

CASE state OF
    0: (* Create — MicroLogix 1400 supports 38400 baud *)
        ok := DF1ClientCreate('ml', '/dev/ttyUSB1', 38400);
        IF ok THEN state := 1; END_IF;

    1: (* Connect *)
        ok := DF1ClientConnect('ml');
        IF ok THEN state := 2; END_IF;

    2: (* Scan for other nodes on the link *)
        nodes := DF1ClientScanNodes('ml', 0, 15);
        state := 3;

    3: (* Read 10 integers starting at N7:0 *)
        int_values := DF1ClientReadWords('ml', 'N7:0', 10);
        state := 4;

    4: (* Read 2 floats (4 words) starting at F8:0 *)
        float_words := DF1ClientReadWords('ml', 'F8:0', 4);
        (* float_words[0..1] = F8:0, float_words[2..3] = F8:1 *)
        state := 5;

    5: (* Write bit file — set B3:0 word to enable all 16 bits *)
        ok := DF1ClientWriteWord('ml', 'B3:0', 16#FFFF);
        state := 10;

    10: (* Running — cyclic read/write *)
        int_values := DF1ClientReadWords('ml', 'N7:0', 10);
        DF1ClientWriteWords('ml', 'N7:20', [int_values[0] + 1, int_values[1]]);
END_CASE;
END_PROGRAM
```

---

## 8. Wiring and Hardware Setup

### RS-232 Cable Pinout (DB-9)

SLC 500 and MicroLogix use a **null modem** connection on Channel 0:

```
GoPLC Host (USB-RS232)          SLC 500 / MicroLogix (CH0)
┌─────────────────┐             ┌─────────────────┐
│  Pin 2 (RXD) ◄──────────────── Pin 2 (TXD)     │
│  Pin 3 (TXD) ────────────────► Pin 3 (RXD)     │
│  Pin 5 (GND) ──────────────── Pin 5 (GND)      │
└─────────────────┘             └─────────────────┘
```

> **Cable type:** Use a standard **null modem** cable (Allen-Bradley 1761-CBL-PM02 equivalent). Pins 2 and 3 are crossed. If using a straight-through cable, you need a null modem adapter.

> **USB adapters:** FTDI-based adapters (FT232R) are recommended. Prolific PL2303 chipsets have known Linux driver issues. GoPLC auto-detects the adapter and sets the FTDI latency timer to 1ms for responsive communication.

### SLC 500 Channel 0 Configuration

Configure via RSLogix 500 under **Channel Configuration > Channel 0**:

| Parameter | Setting |
|-----------|---------|
| Driver | DF1 Full-Duplex |
| Baud Rate | 19200 (match GoPLC) |
| Parity | None |
| Error Detection | CRC |
| Duplicate Detect | Enabled |
| Source Node | 1 (match `remoteNode` in GoPLC) |

### MicroLogix Channel Configuration

MicroLogix 1100/1400 configure Channel 0 through **RSLogix 500 > Channel Configuration** or via the front panel LCD. The defaults (19200, 8N1, DF1 full-duplex) work with GoPLC out of the box.

---

## 9. Troubleshooting

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Connect` succeeds but reads fail | Baud rate mismatch | Match baud in `DF1ClientCreate` to SLC channel config |
| All reads return timeout | TX/RX wires swapped | Use null modem cable or swap pins 2 and 3 |
| Intermittent CRC errors | Electrical noise on RS-232 | Shorten cable, add ferrites, verify ground |
| NAK responses on writes | Processor in wrong mode | Check CPU mode — data file writes need RUN or REMOTE RUN |
| Echo works, reads fail | Wrong node address | Verify `remoteNode` matches SLC Channel 0 Source Node |
| `Permission denied` on Linux | Serial port access | `sudo usermod -aG dialout $USER`, then log out/in |
| Slow scan rate | Too many poll items | Coalesce contiguous addresses; reduce poll count |

### DF1 Wire Protocol Reference

```
┌──────┬──────┬──────┬──────┬──────┬──────────────────┬───────┬───────┐
│ DLE  │ STX  │ DST  │ SRC  │ CMD  │ STS  │ TNS(2)    │ DATA  │ DLE   │
│ 0x10 │ 0x02 │  1B  │  1B  │  1B  │  1B  │  LE       │ 0-242 │ 0x10  │
├──────┼──────┼──────┼──────┼──────┼──────┼───────────┼───────┼───────┤
│      │      │      │      │      │      │           │       │ ETX   │
│      │      │      │      │      │      │           │       │ 0x03  │
├──────┼──────┼──────┼──────┼──────┼──────┼───────────┼───────┼───────┤
│      │      │      │      │      │      │           │       │ CRC(2)│
└──────┴──────┴──────┴──────┴──────┴──────┴───────────┴───────┴───────┘
```

- **DLE byte stuffing**: Any 0x10 in the data field is sent as 0x10 0x10
- **CRC-16**: Over all bytes between (but not including) DLE/STX and DLE/ETX
- **TNS (Transaction Number)**: 16-bit incrementing sequence number — GoPLC manages this automatically
- **ACK/NAK**: DLE+ACK (0x10 0x06) or DLE+NAK (0x10 0x15) frame acknowledgment

You never build frames manually — GoPLC handles all framing, byte stuffing, CRC calculation, ACK/NAK handshaking, and retransmission.

---

## Appendix A: Function Quick Reference

| Function | Params | Returns | Description |
|----------|--------|---------|-------------|
| `DF1ClientCreate` | `(name, port [, baud] [, localNode] [, remoteNode])` | BOOL | Create connection (default 19200, nodes 0/1) |
| `DF1ClientConnect` | `(name)` | BOOL | Open serial port and establish DF1 session |
| `DF1ClientDisconnect` | `(name)` | BOOL | Close serial port |
| `DF1ClientIsConnected` | `(name)` | BOOL | Check connection state |
| `DF1ClientReadWords` | `(name, address, count)` | []INT | Read multiple 16-bit words from data file |
| `DF1ClientWriteWords` | `(name, address, values)` | BOOL | Write multiple 16-bit words to data file |
| `DF1ClientReadWord` | `(name, address)` | INT | Read single 16-bit word |
| `DF1ClientWriteWord` | `(name, address, value)` | BOOL | Write single 16-bit word |
| `DF1ClientEcho` | `(name, data)` | []INT | Diagnostic echo — verify serial link |
| `DF1ClientGetDiagnosticStatus` | `(name)` | []INT | Remote node diagnostic counters |
| `DF1ClientSetCPUMode` | `(name, mode)` | BOOL | 0=PROGRAM, 1=RUN, 2=TEST |
| `DF1ClientGetStats` | `(name)` | MAP | Connection health metrics |
| `DF1ClientScanNodes` | `(name, startNode, endNode)` | []INT | Discover responding nodes |
| `DF1ClientAddPollItem` | `(name, address, tag, count)` | BOOL | Register cyclic read |
| `DF1ClientDelete` | `(name)` | BOOL | Remove connection |
| `DF1ClientList` | `()` | []STRING | List all DF1 connections |

---

*GoPLC v1.0.520 | Allen-Bradley DF1 Full-Duplex | RS-232 Serial Client*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
