# GoPLC Modbus TCP Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements a complete **Modbus TCP** stack — both client and server — callable directly from IEC 61131-3 Structured Text. No external libraries, no configuration files, no code generation. You create connections, read/write registers, and manage servers with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `MB_CLIENT_CREATE` / `MB_READ_*` / `MB_WRITE_*` | Poll remote devices: VFDs, power meters, remote I/O, other PLCs |
| **Server** | `MB_SERVER_CREATE` / `MB_SERVER_SET_*` / `MB_SERVER_GET_*` | Expose GoPLC data to SCADA, HMI, or other Modbus masters |

Both roles can run simultaneously. A single GoPLC instance can poll five VFDs as a client while serving register data to a SCADA system — all from the same ST program.

### System Diagram

```
┌──────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)              │
│                                                          │
│  ┌──────────────────────┐  ┌──────────────────────────┐  │
│  │ ST Program (Client)  │  │ ST Program (Server)      │  │
│  │                      │  │                          │  │
│  │ MB_CLIENT_CREATE()     │  │ MB_SERVER_CREATE()         │  │
│  │ MB_CLIENT_CONNECT()    │  │ MB_SERVER_START()          │  │
│  │ MB_READ_HOLDING()    │  │ MB_SERVER_SET_HOLDING()  │  │
│  │ MB_READ_COILS()      │  │ MB_SERVER_GET_COIL()     │  │
│  │ MB_WRITE_COIL()  │  │ MB_SERVER_CONNECTIONS() │  │
│  └──────────┬───────────┘  └──────────┬───────────────┘  │
│             │                         │                  │
│             │  TCP Client             │  TCP Server      │
│             │  (connects out)         │  (listens)       │
└─────────────┼─────────────────────────┼──────────────────┘
              │                         │
              │  Modbus TCP/IP          │  Modbus TCP/IP
              │  (Port 502 default)     │  (configurable)
              ▼                         ▼
┌─────────────────────────┐   ┌─────────────────────────────┐
│  Remote Modbus Server   │   │  Remote Modbus Client        │
│                         │   │                               │
│  VFD, Power Meter,      │   │  SCADA, HMI, Node-RED,       │
│  Remote I/O, PLC        │   │  Another PLC, Python script   │
└─────────────────────────┘   └───────────────────────────────┘
```

### Modbus Data Model

All Modbus devices share the same four data areas:

| Area | Address Range | Access | Type | Modbus Term |
|------|--------------|--------|------|-------------|
| **Coils** | 0-65535 | Read/Write | BOOL | Discrete outputs |
| **Discrete Inputs** | 0-65535 | Read-Only | BOOL | Discrete inputs |
| **Holding Registers** | 0-65535 | Read/Write | INT (16-bit) | Analog outputs |
| **Input Registers** | 0-65535 | Read-Only | INT (16-bit) | Analog inputs |

> **Addressing Note:** GoPLC uses zero-based addressing. Modbus address 0 in GoPLC corresponds to register 1 (40001) in traditional Modbus documentation. If a VFD manual says "register 40100," use address 99 in your `MB_READ_HOLDING` call.

---

## 2. Client Functions

The Modbus TCP client connects to remote servers (VFDs, meters, remote I/O) and performs read/write operations using standard Modbus function codes.

### 2.1 Connection Management

#### MB_CLIENT_CREATE — Create Named Connection

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique connection name |
| `host` | STRING | Yes | IP address or hostname of the Modbus server |
| `port` | INT | Yes | TCP port (typically 502) |
| `slave_id` | INT | No | Modbus unit ID (default 1) |

Returns: `BOOL` — TRUE if the connection was created successfully.

```iecst
(* Create a connection to a VFD at 10.0.0.50 *)
ok := MB_CLIENT_CREATE('vfd1', '10.0.0.50', 502);

(* Create with explicit slave ID for multi-drop gateways *)
ok := MB_CLIENT_CREATE('meter3', '10.0.0.60', 502, 3);
```

> **Named connections:** Every Modbus client connection has a unique string name. This name is used in all subsequent calls. You can create as many connections as you need — one per device is the typical pattern.

#### MB_CLIENT_CONNECT — Establish TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from MB_CLIENT_CREATE |

Returns: `BOOL` — TRUE if connected successfully.

```iecst
ok := MB_CLIENT_CONNECT('vfd1');
```

#### MB_CLIENT_DISCONNECT — Close TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully.

```iecst
ok := MB_CLIENT_DISCONNECT('vfd1');
```

#### MB_CLIENT_CONNECTED — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the TCP connection is active.

```iecst
IF NOT MB_CLIENT_CONNECTED('vfd1') THEN
    MB_CLIENT_CONNECT('vfd1');
END_IF;
```

#### Example: Connection Lifecycle

```iecst
PROGRAM POU_ModbusInit
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create connection *)
        ok := MB_CLIENT_CREATE('vfd1', '10.0.0.50', 502);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := MB_CLIENT_CONNECT('vfd1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT MB_CLIENT_CONNECTED('vfd1') THEN
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.2 Read Functions

#### MB_READ_COILS — FC01: Read Coils

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting coil address (0-based) |
| `count` | INT | Number of coils to read (1-2000) |

Returns: `[]BOOL` — Array of coil states.

```iecst
(* Read 8 coils starting at address 0 *)
coils := MB_READ_COILS('vfd1', 0, 8);
(* coils[0] = TRUE/FALSE, coils[1] = TRUE/FALSE, ... *)
```

#### MB_READ_DISCRETE — FC02: Read Discrete Inputs

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting input address (0-based) |
| `count` | INT | Number of inputs to read (1-2000) |

Returns: `[]BOOL` — Array of input states.

```iecst
(* Read 16 discrete inputs starting at address 0 *)
inputs := MB_READ_DISCRETE('vfd1', 0, 16);
```

#### MB_READ_HOLDING — FC03: Read Holding Registers

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address (0-based) |
| `count` | INT | Number of registers to read (1-125) |

Returns: `[]INT` — Array of 16-bit register values.

```iecst
(* Read 10 holding registers starting at address 0 *)
regs := MB_READ_HOLDING('vfd1', 0, 10);
(* regs[0] = first register value, regs[1] = second, ... *)

(* Read VFD output frequency — typically at a specific register *)
freq_regs := MB_READ_HOLDING('vfd1', 8451, 1);
```

> **Register limit:** The Modbus spec allows a maximum of 125 holding registers per read request. If you need more, split into multiple reads.

#### MB_READ_INPUT — FC04: Read Input Registers

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address (0-based) |
| `count` | INT | Number of registers to read (1-125) |

Returns: `[]INT` — Array of 16-bit register values.

```iecst
(* Read 4 input registers — process values from a meter *)
measurements := MB_READ_INPUT('meter3', 0, 4);
```

#### Example: Periodic Register Poll

```iecst
PROGRAM POU_ReadRegisters
VAR
    regs : ARRAY[0..9] OF INT;
    speed_hz : INT;
    current_amps : INT;
    voltage_v : INT;
END_VAR

(* Read VFD status registers every scan *)
regs := MB_READ_HOLDING('vfd1', 8451, 3);

speed_hz := regs[0];       (* Output frequency x10 *)
current_amps := regs[1];   (* Output current x10 *)
voltage_v := regs[2];      (* DC bus voltage *)
END_PROGRAM
```

---

### 2.3 Write Functions

#### MB_WRITE_COIL — FC05: Write Single Coil

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Coil address (0-based) |
| `value` | BOOL | TRUE = ON, FALSE = OFF |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Turn on coil at address 0 *)
ok := MB_WRITE_COIL('vfd1', 0, TRUE);

(* Turn off coil at address 0 *)
ok := MB_WRITE_COIL('vfd1', 0, FALSE);
```

#### MB_WRITE_REGISTER — FC06: Write Single Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit register value |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Write speed setpoint to VFD — 3000 = 30.00 Hz *)
ok := MB_WRITE_REGISTER('vfd1', 8192, 3000);

(* Write run command *)
ok := MB_WRITE_REGISTER('vfd1', 8448, 1);
```

#### MB_WRITE_COILS — FC15: Write Multiple Coils

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting coil address (0-based) |
| `values` | []BOOL | Array of coil values |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Write 4 coils starting at address 0 *)
coil_values : ARRAY[0..3] OF BOOL := [TRUE, FALSE, TRUE, TRUE];
ok := MB_WRITE_COILS('vfd1', 0, coil_values);
```

#### MB_WRITE_REGISTERS — FC16: Write Multiple Registers

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address (0-based) |
| `values` | []INT | Array of 16-bit register values |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Write 3 registers starting at address 100 *)
reg_values : ARRAY[0..2] OF INT := [1500, 3000, 6000];
ok := MB_WRITE_REGISTERS('vfd1', 100, reg_values);
```

#### Example: VFD Speed Command

```iecst
PROGRAM POU_WriteVFD
VAR
    target_speed : INT := 3000;    (* 30.00 Hz *)
    run_cmd : BOOL := FALSE;
    ok : BOOL;
END_VAR

(* Write frequency setpoint *)
ok := MB_WRITE_REGISTER('vfd1', 8192, target_speed);

(* Write run/stop command *)
IF run_cmd THEN
    ok := MB_WRITE_REGISTER('vfd1', 8448, 1);   (* Run forward *)
ELSE
    ok := MB_WRITE_REGISTER('vfd1', 8448, 0);   (* Stop *)
END_IF;
END_PROGRAM
```

---

### 2.4 Diagnostics and Management

#### MB_CLIENT_STATS — Connection Statistics

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `MAP` — Statistics including request count, response count, and error count.

```iecst
stats := MB_CLIENT_STATS('vfd1');
(* Returns: {"requests": 1542, "responses": 1540, "errors": 2} *)
```

> **Error tracking:** Compare requests vs. responses to detect communication problems. A growing error count may indicate cabling issues, device overload, or network congestion.

#### MB_CLIENT_DELETE — Remove Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the connection was deleted.

```iecst
(* Disconnect and remove *)
MB_CLIENT_DISCONNECT('vfd1');
ok := MB_CLIENT_DELETE('vfd1');
```

#### MB_CLIENT_LIST — List All Connections

Returns: `[]STRING` — Array of all client connection names.

```iecst
clients := MB_CLIENT_LIST();
(* Returns: ['vfd1', 'meter3', 'remote_io'] *)
```

---

## 3. Server Functions

The Modbus TCP server listens for incoming connections and exposes four standard Modbus data areas. Remote SCADA systems, HMIs, or other Modbus masters can read and write GoPLC data.

### 3.1 Server Management

#### MB_SERVER_CREATE — Create Named Server

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique server name |
| `port` | INT | Yes | TCP listen port |
| `slave_id` | INT | No | Modbus unit ID (default 1) |

Returns: `BOOL` — TRUE if the server was created.

```iecst
(* Create a server on the standard Modbus port *)
ok := MB_SERVER_CREATE('plc_server', 502);

(* Create on a non-standard port with explicit slave ID *)
ok := MB_SERVER_CREATE('line2_server', 5020, 2);
```

> **Port selection:** Port 502 is the standard Modbus TCP port and may require root/admin privileges on some systems. Using a port above 1024 (e.g., 5020) avoids permission issues during development.

#### MB_SERVER_START — Begin Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server started listening.

```iecst
ok := MB_SERVER_START('plc_server');
```

#### MB_SERVER_STOP — Stop Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server stopped.

```iecst
ok := MB_SERVER_STOP('plc_server');
```

#### MB_SERVER_IS_RUNNING — Check Server State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server is actively listening.

```iecst
IF NOT MB_SERVER_IS_RUNNING('plc_server') THEN
    MB_SERVER_START('plc_server');
END_IF;
```

#### Example: Server Lifecycle

```iecst
PROGRAM POU_ModbusServer
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create server *)
        ok := MB_SERVER_CREATE('plc_server', 502);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Start listening *)
        ok := MB_SERVER_START('plc_server');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — update registers in other programs *)
        IF NOT MB_SERVER_IS_RUNNING('plc_server') THEN
            state := 1;  (* Restart *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 3.2 Coil Access (Read/Write Booleans)

#### MB_SERVER_SET_COIL — Write a Coil Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Coil address (0-based) |
| `value` | BOOL | TRUE = ON, FALSE = OFF |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Set coil 0 to ON — visible to any connected Modbus client *)
ok := MB_SERVER_SET_COIL('plc_server', 0, TRUE);
```

#### MB_SERVER_GET_COIL — Read a Coil Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Coil address (0-based) |

Returns: `BOOL` — Current coil state.

```iecst
(* Read coil 0 — may have been written by a remote SCADA master *)
run_cmd := MB_SERVER_GET_COIL('plc_server', 0);
```

> **Bidirectional data flow:** Remote Modbus clients can write coils (FC05/FC15) and holding registers (FC06/FC16) on your server. Use `MB_SERVER_GET_COIL` and `MB_SERVER_GET_HOLDING` to read values that remote masters have written. This is how SCADA systems send commands to GoPLC.

#### Example: Coil-Based Remote Control

```iecst
PROGRAM POU_CoilControl
VAR
    remote_run : BOOL;
    remote_reset : BOOL;
    motor_running : BOOL;
END_VAR

(* Read commands from SCADA via coils *)
remote_run := MB_SERVER_GET_COIL('plc_server', 0);
remote_reset := MB_SERVER_GET_COIL('plc_server', 1);

(* Execute commands *)
IF remote_run AND NOT motor_running THEN
    motor_running := TRUE;
END_IF;

IF remote_reset THEN
    motor_running := FALSE;
    MB_SERVER_SET_COIL('plc_server', 1, FALSE);  (* Auto-clear reset *)
END_IF;

(* Report status back *)
MB_SERVER_SET_COIL('plc_server', 10, motor_running);
END_PROGRAM
```

---

### 3.3 Discrete Input Access (Read-Only Booleans)

#### MB_SERVER_SET_DISCRETE — Set a Discrete Input Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Input address (0-based) |
| `value` | BOOL | TRUE = ON, FALSE = OFF |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Expose sensor states as discrete inputs *)
ok := MB_SERVER_SET_DISCRETE('plc_server', 0, limit_switch_1);
ok := MB_SERVER_SET_DISCRETE('plc_server', 1, limit_switch_2);
ok := MB_SERVER_SET_DISCRETE('plc_server', 2, e_stop_ok);
```

#### MB_SERVER_GET_DISCRETE — Read a Discrete Input Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Input address (0-based) |

Returns: `BOOL` — Current discrete input state.

```iecst
value := MB_SERVER_GET_DISCRETE('plc_server', 0);
```

> **Read-only to clients:** Remote Modbus masters can only read discrete inputs (FC02). They cannot write them. Use this area for status and sensor data that should not be overwritten remotely.

---

### 3.4 Holding Register Access (Read/Write Integers)

#### MB_SERVER_SET_HOLDING — Write a Holding Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit register value |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Expose process values as holding registers *)
ok := MB_SERVER_SET_HOLDING('plc_server', 0, motor_speed);
ok := MB_SERVER_SET_HOLDING('plc_server', 1, motor_current);
ok := MB_SERVER_SET_HOLDING('plc_server', 2, temperature);
```

#### MB_SERVER_GET_HOLDING — Read a Holding Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |

Returns: `INT` — Current register value.

```iecst
(* Read setpoint written by remote SCADA *)
speed_setpoint := MB_SERVER_GET_HOLDING('plc_server', 100);
```

#### Example: Bidirectional Holding Registers

```iecst
PROGRAM POU_RegisterExchange
VAR
    speed_setpoint : INT;
    actual_speed : INT;
    ok : BOOL;
END_VAR

(* SCADA writes setpoint to register 100 *)
speed_setpoint := MB_SERVER_GET_HOLDING('plc_server', 100);

(* GoPLC publishes actual speed to register 0 *)
actual_speed := 2950;  (* From VFD feedback *)
ok := MB_SERVER_SET_HOLDING('plc_server', 0, actual_speed);
END_PROGRAM
```

---

### 3.5 Input Register Access (Read-Only Integers)

#### MB_SERVER_SET_INPUT — Set an Input Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit register value |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Expose analog measurements as input registers *)
ok := MB_SERVER_SET_INPUT('plc_server', 0, pressure_psi);
ok := MB_SERVER_SET_INPUT('plc_server', 1, flow_gpm);
ok := MB_SERVER_SET_INPUT('plc_server', 2, level_percent);
```

#### MB_SERVER_GET_INPUT — Read an Input Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |

Returns: `INT` — Current register value.

```iecst
value := MB_SERVER_GET_INPUT('plc_server', 0);
```

> **Input registers vs. holding registers:** Use input registers (FC04) for sensor data and measured values. Use holding registers (FC03/FC06) for setpoints and bidirectional data. This follows the Modbus convention and makes your register map intuitive to integrators.

---

### 3.6 Server Diagnostics and Management

#### MB_SERVER_STATS — Server Statistics

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `MAP` — Statistics including request count, response count, and error count.

```iecst
stats := MB_SERVER_STATS('plc_server');
(* Returns: {"requests": 8420, "responses": 8420, "errors": 0} *)
```

#### MB_SERVER_CONNECTIONS — List Connected Clients

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `[]MAP` — Array of connected client information.

```iecst
connections := MB_SERVER_CONNECTIONS('plc_server');
(* Returns: [{"remote_addr": "10.0.0.100:49832", "connected_at": "2026-04-03T10:15:00Z"},
             {"remote_addr": "10.0.0.101:52100", "connected_at": "2026-04-03T10:16:30Z"}] *)
```

> **Security awareness:** Any device on the network can connect to your Modbus server. Use `MB_SERVER_CONNECTIONS` to audit who is connected. For production systems, consider placing the Modbus server on a dedicated VLAN or using firewall rules.

#### MB_SERVER_DELETE — Remove Server

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server was deleted.

```iecst
MB_SERVER_STOP('plc_server');
ok := MB_SERVER_DELETE('plc_server');
```

#### MB_SERVER_LIST — List All Servers

Returns: `[]STRING` — Array of all server names.

```iecst
servers := MB_SERVER_LIST();
(* Returns: ['plc_server', 'line2_server'] *)
```

---

## 4. Complete Example: Polling a VFD Over Modbus TCP Client

This example connects to an ABB ACS355 variable frequency drive, reads status registers, and writes speed commands. The register addresses follow ABB's Modbus register map — adapt them for your specific VFD model.

```iecst
PROGRAM POU_VFD_Control
VAR
    (* Connection state *)
    state : INT := 0;
    ok : BOOL;
    retry_count : INT := 0;

    (* VFD feedback *)
    status_regs : ARRAY[0..4] OF INT;
    output_freq : REAL;       (* Hz *)
    output_current : REAL;    (* Amps *)
    dc_bus_voltage : INT;     (* Volts *)
    drive_status : INT;
    fault_code : INT;

    (* VFD commands *)
    speed_setpoint : INT := 3000;   (* 30.00 Hz x100 *)
    run_forward : BOOL := FALSE;
    run_reverse : BOOL := FALSE;
    control_word : INT;
END_VAR

CASE state OF
    0: (* Create connection to VFD *)
        ok := MB_CLIENT_CREATE('acs355', '10.0.0.50', 502, 1);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := MB_CLIENT_CONNECT('acs355');
        IF ok THEN
            retry_count := 0;
            state := 10;
        ELSE
            retry_count := retry_count + 1;
            IF retry_count > 5 THEN
                state := 99;   (* Fault *)
            END_IF;
        END_IF;

    10: (* Running — read status registers *)
        IF NOT MB_CLIENT_CONNECTED('acs355') THEN
            state := 1;   (* Reconnect *)
        END_IF;

        (* Read 5 status registers starting at address 1 *)
        status_regs := MB_READ_HOLDING('acs355', 1, 5);

        output_freq := INT_TO_REAL(status_regs[0]) / 100.0;
        output_current := INT_TO_REAL(status_regs[1]) / 100.0;
        dc_bus_voltage := status_regs[2];
        drive_status := status_regs[3];
        fault_code := status_regs[4];

        state := 11;

    11: (* Write command registers *)
        (* Build control word *)
        control_word := 0;
        IF run_forward THEN
            control_word := 1;     (* Run forward *)
        ELSIF run_reverse THEN
            control_word := 2;     (* Run reverse *)
        END_IF;

        ok := MB_WRITE_REGISTER('acs355', 0, control_word);
        ok := MB_WRITE_REGISTER('acs355', 1, speed_setpoint);

        state := 10;   (* Loop back to read *)

    99: (* Fault — connection failed *)
        (* Log error, wait for operator intervention *)
END_CASE;
END_PROGRAM
```

> **Scan time consideration:** Each Modbus transaction (read or write) takes 5-50 ms depending on network latency and device response time. Avoid reading hundreds of registers every scan. Group related registers into single reads, and stagger reads across multiple scans if needed.

---

## 5. Complete Example: Exposing GoPLC Data as a Modbus TCP Server

This example creates a Modbus server that exposes process data to a SCADA system. The register map is documented so integrators know where to find each value.

### Register Map

| Address | Area | Description | Units | Scale |
|---------|------|-------------|-------|-------|
| HR 0 | Holding | Line speed | RPM | x1 |
| HR 1 | Holding | Motor current | Amps | x10 |
| HR 2 | Holding | Temperature | Deg F | x10 |
| HR 3 | Holding | Pressure | PSI | x10 |
| HR 4 | Holding | Batch count | Count | x1 |
| HR 100 | Holding | Speed setpoint (SCADA writes) | RPM | x1 |
| HR 101 | Holding | Mode select (SCADA writes) | Enum | x1 |
| IR 0 | Input | Uptime | Seconds | x1 |
| IR 1 | Input | Scan count | Count | x1 |
| DI 0 | Discrete | E-Stop OK | — | — |
| DI 1 | Discrete | Guard door closed | — | — |
| DI 2 | Discrete | System running | — | — |
| Coil 0 | Coil | Start command (SCADA writes) | — | — |
| Coil 1 | Coil | Stop command (SCADA writes) | — | — |
| Coil 10 | Coil | Running status | — | — |
| Coil 11 | Coil | Fault active | — | — |

```iecst
PROGRAM POU_SCADA_Server
VAR
    (* Server state *)
    state : INT := 0;
    ok : BOOL;

    (* Process data (from other programs or I/O) *)
    line_speed : INT := 1750;
    motor_current : INT := 125;       (* 12.5 A x10 *)
    temperature : INT := 1680;        (* 168.0 F x10 *)
    pressure : INT := 450;            (* 45.0 PSI x10 *)
    batch_count : INT := 0;
    uptime_sec : DINT := 0;
    scan_count : DINT := 0;

    (* Discrete status *)
    e_stop_ok : BOOL := TRUE;
    guard_closed : BOOL := TRUE;
    system_running : BOOL := FALSE;
    fault_active : BOOL := FALSE;

    (* Commands from SCADA *)
    scada_start : BOOL;
    scada_stop : BOOL;
    scada_setpoint : INT;
    scada_mode : INT;
END_VAR

CASE state OF
    0: (* Create and start server *)
        ok := MB_SERVER_CREATE('scada', 502);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Start listening *)
        ok := MB_SERVER_START('scada');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — update all data areas every scan *)
        scan_count := scan_count + 1;

        (* === Write process values to holding registers === *)
        MB_SERVER_SET_HOLDING('scada', 0, line_speed);
        MB_SERVER_SET_HOLDING('scada', 1, motor_current);
        MB_SERVER_SET_HOLDING('scada', 2, temperature);
        MB_SERVER_SET_HOLDING('scada', 3, pressure);
        MB_SERVER_SET_HOLDING('scada', 4, batch_count);

        (* === Write input registers === *)
        MB_SERVER_SET_INPUT('scada', 0, DINT_TO_INT(uptime_sec));
        MB_SERVER_SET_INPUT('scada', 1, DINT_TO_INT(scan_count));

        (* === Write discrete inputs (read-only to SCADA) === *)
        MB_SERVER_SET_DISCRETE('scada', 0, e_stop_ok);
        MB_SERVER_SET_DISCRETE('scada', 1, guard_closed);
        MB_SERVER_SET_DISCRETE('scada', 2, system_running);

        (* === Write coil status === *)
        MB_SERVER_SET_COIL('scada', 10, system_running);
        MB_SERVER_SET_COIL('scada', 11, fault_active);

        (* === Read commands from SCADA === *)
        scada_start := MB_SERVER_GET_COIL('scada', 0);
        scada_stop := MB_SERVER_GET_COIL('scada', 1);
        scada_setpoint := MB_SERVER_GET_HOLDING('scada', 100);
        scada_mode := MB_SERVER_GET_HOLDING('scada', 101);

        (* Process commands *)
        IF scada_start AND NOT system_running THEN
            system_running := TRUE;
            MB_SERVER_SET_COIL('scada', 0, FALSE);  (* Auto-clear *)
        END_IF;

        IF scada_stop AND system_running THEN
            system_running := FALSE;
            MB_SERVER_SET_COIL('scada', 1, FALSE);  (* Auto-clear *)
        END_IF;

        (* Health check *)
        IF NOT MB_SERVER_IS_RUNNING('scada') THEN
            state := 1;   (* Restart *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 6. Gateway Example: Modbus TCP to MQTT Bridge

This example reads holding registers from a remote Modbus device and publishes them to an MQTT broker. GoPLC acts as a protocol gateway — bridging the OT (Modbus) and IT (MQTT) worlds.

```iecst
PROGRAM POU_Modbus_MQTT_Gateway
VAR
    (* State machine *)
    state : INT := 0;
    ok : BOOL;
    scan_count : DINT := 0;
    publish_interval : DINT := 10;    (* Publish every 10 scans *)

    (* Modbus data *)
    regs : ARRAY[0..9] OF INT;
    voltage : REAL;
    current : REAL;
    power : REAL;
    energy : DINT;

    (* MQTT *)
    mqtt_connected : BOOL;
    payload : STRING;
END_VAR

CASE state OF
    0: (* Initialize Modbus client *)
        ok := MB_CLIENT_CREATE('meter', '10.0.0.70', 502, 1);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect Modbus *)
        ok := MB_CLIENT_CONNECT('meter');
        IF ok THEN
            state := 2;
        END_IF;

    2: (* Initialize MQTT *)
        ok := MQTTConnect('mqtt_gw', '10.0.0.144', 1883);
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read and publish *)
        scan_count := scan_count + 1;

        (* Reconnect if needed *)
        IF NOT MB_CLIENT_CONNECTED('meter') THEN
            MB_CLIENT_CONNECT('meter');
        END_IF;

        (* Read 10 registers from power meter *)
        regs := MB_READ_HOLDING('meter', 0, 10);

        (* Scale to engineering units *)
        voltage := INT_TO_REAL(regs[0]) / 10.0;
        current := INT_TO_REAL(regs[1]) / 100.0;
        power := INT_TO_REAL(regs[2]) / 10.0;
        energy := INT_TO_DINT(regs[4]) * 65536 + INT_TO_DINT(regs[5]);

        (* Publish at reduced rate *)
        IF (scan_count MOD publish_interval) = 0 THEN
            payload := CONCAT('{"voltage":', REAL_TO_STRING(voltage),
                              ',"current":', REAL_TO_STRING(current),
                              ',"power":', REAL_TO_STRING(power),
                              ',"energy":', DINT_TO_STRING(energy), '}');

            MQTTPublish('mqtt_gw', 'plant/meter1/data', payload);
        END_IF;

        (* Publish Modbus stats periodically *)
        IF (scan_count MOD 100) = 0 THEN
            MQTTPublish('mqtt_gw', 'plant/meter1/stats',
                        MB_CLIENT_STATS('meter'));
        END_IF;
END_CASE;
END_PROGRAM
```

> **Rate limiting:** Modbus devices typically handle 10-50 requests per second. MQTT brokers can handle thousands of messages per second. Use the `publish_interval` to decouple the read rate from the publish rate. Read every scan for responsive control; publish at a slower rate for trending and logging.

---

## 7. Advanced Patterns

### 7.1 Multi-Device Polling

```iecst
PROGRAM POU_MultiDevice
VAR
    poll_index : INT := 0;
    devices : ARRAY[0..3] OF STRING := ['vfd1', 'vfd2', 'meter1', 'meter2'];
    regs : ARRAY[0..4] OF INT;
END_VAR

(* Round-robin: poll one device per scan to distribute bus load *)
regs := MB_READ_HOLDING(devices[poll_index], 0, 5);

poll_index := poll_index + 1;
IF poll_index > 3 THEN
    poll_index := 0;
END_IF;
END_PROGRAM
```

> **Why round-robin?** Each Modbus read blocks for the duration of the TCP transaction (5-50 ms). Polling four devices sequentially every scan adds 20-200 ms to your scan time. Round-robin keeps scan time consistent.

### 7.2 32-Bit Values Across Two Registers

Modbus registers are 16-bit. For 32-bit values (REAL, DINT), devices use two consecutive registers. The byte order varies by manufacturer.

```iecst
PROGRAM POU_32Bit
VAR
    regs : ARRAY[0..1] OF INT;
    float_val : REAL;
    dint_val : DINT;
END_VAR

(* Read two consecutive registers *)
regs := MB_READ_HOLDING('meter', 0, 2);

(* Big-endian (most common): high word first *)
dint_val := INT_TO_DINT(regs[0]) * 65536 + INT_TO_DINT(regs[1]);

(* Little-endian (some devices): low word first *)
dint_val := INT_TO_DINT(regs[1]) * 65536 + INT_TO_DINT(regs[0]);
END_PROGRAM
```

> **Word order matters:** There is no standard for 32-bit value byte order in Modbus. ABB uses big-endian. Schneider uses big-endian. Some devices use little-endian or mid-endian (byte-swapped). Always check the device manual and verify with a known value.

### 7.3 Dual Role: Client and Server Simultaneously

```iecst
PROGRAM POU_DualRole
VAR
    state : INT := 0;
    ok : BOOL;
    vfd_speed : INT;
    vfd_current : INT;
    regs : ARRAY[0..1] OF INT;
END_VAR

CASE state OF
    0: (* Initialize both roles *)
        ok := MB_CLIENT_CREATE('vfd', '10.0.0.50', 502);
        ok := MB_SERVER_CREATE('scada', 5020);
        IF ok THEN state := 1; END_IF;

    1: (* Connect/Start *)
        MB_CLIENT_CONNECT('vfd');
        MB_SERVER_START('scada');
        state := 10;

    10: (* Running — bridge VFD data to SCADA *)
        (* Read from VFD (client role) *)
        regs := MB_READ_HOLDING('vfd', 0, 2);
        vfd_speed := regs[0];
        vfd_current := regs[1];

        (* Expose to SCADA (server role) *)
        MB_SERVER_SET_HOLDING('scada', 0, vfd_speed);
        MB_SERVER_SET_HOLDING('scada', 1, vfd_current);

        (* Read setpoint from SCADA, forward to VFD *)
        MB_WRITE_REGISTER('vfd', 10,
            MB_SERVER_GET_HOLDING('scada', 100));
END_CASE;
END_PROGRAM
```

---

## Appendix A: Modbus Function Code Reference

| FC | Name | GoPLC Client Function | Max Items |
|----|------|-----------------------|-----------|
| 01 | Read Coils | `MB_READ_COILS` | 2000 |
| 02 | Read Discrete Inputs | `MB_READ_DISCRETE` | 2000 |
| 03 | Read Holding Registers | `MB_READ_HOLDING` | 125 |
| 04 | Read Input Registers | `MB_READ_INPUT` | 125 |
| 05 | Write Single Coil | `MB_WRITE_COIL` | 1 |
| 06 | Write Single Register | `MB_WRITE_REGISTER` | 1 |
| 15 | Write Multiple Coils | `MB_WRITE_COILS` | 1968 |
| 16 | Write Multiple Registers | `MB_WRITE_REGISTERS` | 123 |

---

## Appendix B: Quick Reference — All 31 Functions

### Client Functions (15)

| Function | Returns | Description |
|----------|---------|-------------|
| `MB_CLIENT_CREATE(name, host, port [, slave_id])` | BOOL | Create named connection |
| `MB_CLIENT_CONNECT(name)` | BOOL | Establish TCP connection |
| `MB_CLIENT_DISCONNECT(name)` | BOOL | Close TCP connection |
| `MB_CLIENT_CONNECTED(name)` | BOOL | Check connection state |
| `MB_READ_COILS(name, address, count)` | []BOOL | FC01: Read coils |
| `MB_READ_DISCRETE(name, address, count)` | []BOOL | FC02: Read discrete inputs |
| `MB_READ_HOLDING(name, address, count)` | []INT | FC03: Read holding registers |
| `MB_READ_INPUT(name, address, count)` | []INT | FC04: Read input registers |
| `MB_WRITE_COIL(name, address, value)` | BOOL | FC05: Write single coil |
| `MB_WRITE_REGISTER(name, address, value)` | BOOL | FC06: Write single register |
| `MB_WRITE_COILS(name, address, values)` | BOOL | FC15: Write multiple coils |
| `MB_WRITE_REGISTERS(name, address, values)` | BOOL | FC16: Write multiple registers |
| `MB_CLIENT_STATS(name)` | MAP | Request/response/error counts |
| `MB_CLIENT_DELETE(name)` | BOOL | Remove connection |
| `MB_CLIENT_LIST()` | []STRING | List all connections |

### Server Functions (16)

| Function | Returns | Description |
|----------|---------|-------------|
| `MB_SERVER_CREATE(name, port [, slave_id])` | BOOL | Create named server |
| `MB_SERVER_START(name)` | BOOL | Begin listening |
| `MB_SERVER_STOP(name)` | BOOL | Stop listening |
| `MB_SERVER_IS_RUNNING(name)` | BOOL | Check server state |
| `MB_SERVER_SET_COIL(name, address, value)` | BOOL | Write coil value |
| `MB_SERVER_GET_COIL(name, address)` | BOOL | Read coil value |
| `MB_SERVER_SET_DISCRETE(name, address, value)` | BOOL | Set discrete input |
| `MB_SERVER_GET_DISCRETE(name, address)` | BOOL | Read discrete input |
| `MB_SERVER_SET_HOLDING(name, address, value)` | BOOL | Write holding register |
| `MB_SERVER_GET_HOLDING(name, address)` | INT | Read holding register |
| `MB_SERVER_SET_INPUT(name, address, value)` | BOOL | Set input register |
| `MB_SERVER_GET_INPUT(name, address)` | INT | Read input register |
| `MB_SERVER_STATS(name)` | MAP | Request/response/error counts |
| `MB_SERVER_CONNECTIONS(name)` | []MAP | List connected clients |
| `MB_SERVER_DELETE(name)` | BOOL | Remove server |
| `MB_SERVER_LIST()` | []STRING | List all servers |

---

*GoPLC v1.0.533 | Modbus TCP Client + Server | IEC 61131-3 Structured Text*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
