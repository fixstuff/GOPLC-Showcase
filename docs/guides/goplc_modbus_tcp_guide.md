# GoPLC Modbus TCP Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC implements a complete **Modbus TCP** stack — both client and server — callable directly from IEC 61131-3 Structured Text. No external libraries, no configuration files, no code generation. You create connections, read/write registers, and manage servers with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `MBClientCreate` / `MBClientRead*` / `MBClientWrite*` | Poll remote devices: VFDs, power meters, remote I/O, other PLCs |
| **Server** | `MBServerCreate` / `MBServerSet*` / `MBServerGet*` | Expose GoPLC data to SCADA, HMI, or other Modbus masters |

Both roles can run simultaneously. A single GoPLC instance can poll five VFDs as a client while serving register data to a SCADA system — all from the same ST program.

### System Diagram

```
┌──────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)              │
│                                                          │
│  ┌──────────────────────┐  ┌──────────────────────────┐  │
│  │ ST Program (Client)  │  │ ST Program (Server)      │  │
│  │                      │  │                          │  │
│  │ MBClientCreate()     │  │ MBServerCreate()         │  │
│  │ MBClientConnect()    │  │ MBServerStart()          │  │
│  │ MBClientReadHolding  │  │ MBServerSetHoldingReg()  │  │
│  │   Registers()        │  │ MBServerGetCoil()        │  │
│  │ MBClientWriteCoil()  │  │ MBServerGetConnections() │  │
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

> **Addressing Note:** GoPLC uses zero-based addressing. Modbus address 0 in GoPLC corresponds to register 1 (40001) in traditional Modbus documentation. If a VFD manual says "register 40100," use address 99 in your `MBClientReadHoldingRegisters` call.

---

## 2. Client Functions

The Modbus TCP client connects to remote servers (VFDs, meters, remote I/O) and performs read/write operations using standard Modbus function codes.

### 2.1 Connection Management

#### MBClientCreate — Create Named Connection

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique connection name |
| `host` | STRING | Yes | IP address or hostname of the Modbus server |
| `port` | INT | Yes | TCP port (typically 502) |
| `slave_id` | INT | No | Modbus unit ID (default 1) |

Returns: `BOOL` — TRUE if the connection was created successfully.

```iecst
(* Create a connection to a VFD at 10.0.0.50 *)
ok := MBClientCreate('vfd1', '10.0.0.50', 502);

(* Create with explicit slave ID for multi-drop gateways *)
ok := MBClientCreate('meter3', '10.0.0.60', 502, 3);
```

> **Named connections:** Every Modbus client connection has a unique string name. This name is used in all subsequent calls. You can create as many connections as you need — one per device is the typical pattern.

#### MBClientConnect — Establish TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from MBClientCreate |

Returns: `BOOL` — TRUE if connected successfully.

```iecst
ok := MBClientConnect('vfd1');
```

#### MBClientDisconnect — Close TCP Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully.

```iecst
ok := MBClientDisconnect('vfd1');
```

#### MBClientIsConnected — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the TCP connection is active.

```iecst
IF NOT MBClientIsConnected('vfd1') THEN
    MBClientConnect('vfd1');
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
        ok := MBClientCreate('vfd1', '10.0.0.50', 502);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := MBClientConnect('vfd1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT MBClientIsConnected('vfd1') THEN
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.2 Read Functions

#### MBClientReadCoils — FC01: Read Coils

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting coil address (0-based) |
| `count` | INT | Number of coils to read (1-2000) |

Returns: `[]BOOL` — Array of coil states.

```iecst
(* Read 8 coils starting at address 0 *)
coils := MBClientReadCoils('vfd1', 0, 8);
(* coils[0] = TRUE/FALSE, coils[1] = TRUE/FALSE, ... *)
```

#### MBClientReadDiscreteInputs — FC02: Read Discrete Inputs

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting input address (0-based) |
| `count` | INT | Number of inputs to read (1-2000) |

Returns: `[]BOOL` — Array of input states.

```iecst
(* Read 16 discrete inputs starting at address 0 *)
inputs := MBClientReadDiscreteInputs('vfd1', 0, 16);
```

#### MBClientReadHoldingRegisters — FC03: Read Holding Registers

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address (0-based) |
| `count` | INT | Number of registers to read (1-125) |

Returns: `[]INT` — Array of 16-bit register values.

```iecst
(* Read 10 holding registers starting at address 0 *)
regs := MBClientReadHoldingRegisters('vfd1', 0, 10);
(* regs[0] = first register value, regs[1] = second, ... *)

(* Read VFD output frequency — typically at a specific register *)
freq_regs := MBClientReadHoldingRegisters('vfd1', 8451, 1);
```

> **Register limit:** The Modbus spec allows a maximum of 125 holding registers per read request. If you need more, split into multiple reads.

#### MBClientReadInputRegisters — FC04: Read Input Registers

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address (0-based) |
| `count` | INT | Number of registers to read (1-125) |

Returns: `[]INT` — Array of 16-bit register values.

```iecst
(* Read 4 input registers — process values from a meter *)
measurements := MBClientReadInputRegisters('meter3', 0, 4);
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
regs := MBClientReadHoldingRegisters('vfd1', 8451, 3);

speed_hz := regs[0];       (* Output frequency x10 *)
current_amps := regs[1];   (* Output current x10 *)
voltage_v := regs[2];      (* DC bus voltage *)
END_PROGRAM
```

---

### 2.3 Write Functions

#### MBClientWriteCoil — FC05: Write Single Coil

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Coil address (0-based) |
| `value` | BOOL | TRUE = ON, FALSE = OFF |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Turn on coil at address 0 *)
ok := MBClientWriteCoil('vfd1', 0, TRUE);

(* Turn off coil at address 0 *)
ok := MBClientWriteCoil('vfd1', 0, FALSE);
```

#### MBClientWriteRegister — FC06: Write Single Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit register value |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Write speed setpoint to VFD — 3000 = 30.00 Hz *)
ok := MBClientWriteRegister('vfd1', 8192, 3000);

(* Write run command *)
ok := MBClientWriteRegister('vfd1', 8448, 1);
```

#### MBClientWriteCoils — FC15: Write Multiple Coils

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting coil address (0-based) |
| `values` | []BOOL | Array of coil values |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Write 4 coils starting at address 0 *)
coil_values : ARRAY[0..3] OF BOOL := [TRUE, FALSE, TRUE, TRUE];
ok := MBClientWriteCoils('vfd1', 0, coil_values);
```

#### MBClientWriteRegisters — FC16: Write Multiple Registers

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address (0-based) |
| `values` | []INT | Array of 16-bit register values |

Returns: `BOOL` — TRUE if write succeeded.

```iecst
(* Write 3 registers starting at address 100 *)
reg_values : ARRAY[0..2] OF INT := [1500, 3000, 6000];
ok := MBClientWriteRegisters('vfd1', 100, reg_values);
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
ok := MBClientWriteRegister('vfd1', 8192, target_speed);

(* Write run/stop command *)
IF run_cmd THEN
    ok := MBClientWriteRegister('vfd1', 8448, 1);   (* Run forward *)
ELSE
    ok := MBClientWriteRegister('vfd1', 8448, 0);   (* Stop *)
END_IF;
END_PROGRAM
```

---

### 2.4 Diagnostics and Management

#### MBClientGetStats — Connection Statistics

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `MAP` — Statistics including request count, response count, and error count.

```iecst
stats := MBClientGetStats('vfd1');
(* Returns: {"requests": 1542, "responses": 1540, "errors": 2} *)
```

> **Error tracking:** Compare requests vs. responses to detect communication problems. A growing error count may indicate cabling issues, device overload, or network congestion.

#### MBClientDelete — Remove Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the connection was deleted.

```iecst
(* Disconnect and remove *)
MBClientDisconnect('vfd1');
ok := MBClientDelete('vfd1');
```

#### MBClientList — List All Connections

Returns: `[]STRING` — Array of all client connection names.

```iecst
clients := MBClientList();
(* Returns: ['vfd1', 'meter3', 'remote_io'] *)
```

---

## 3. Server Functions

The Modbus TCP server listens for incoming connections and exposes four standard Modbus data areas. Remote SCADA systems, HMIs, or other Modbus masters can read and write GoPLC data.

### 3.1 Server Management

#### MBServerCreate — Create Named Server

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique server name |
| `port` | INT | Yes | TCP listen port |
| `slave_id` | INT | No | Modbus unit ID (default 1) |

Returns: `BOOL` — TRUE if the server was created.

```iecst
(* Create a server on the standard Modbus port *)
ok := MBServerCreate('plc_server', 502);

(* Create on a non-standard port with explicit slave ID *)
ok := MBServerCreate('line2_server', 5020, 2);
```

> **Port selection:** Port 502 is the standard Modbus TCP port and may require root/admin privileges on some systems. Using a port above 1024 (e.g., 5020) avoids permission issues during development.

#### MBServerStart — Begin Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server started listening.

```iecst
ok := MBServerStart('plc_server');
```

#### MBServerStop — Stop Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server stopped.

```iecst
ok := MBServerStop('plc_server');
```

#### MBServerIsRunning — Check Server State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server is actively listening.

```iecst
IF NOT MBServerIsRunning('plc_server') THEN
    MBServerStart('plc_server');
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
        ok := MBServerCreate('plc_server', 502);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Start listening *)
        ok := MBServerStart('plc_server');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — update registers in other programs *)
        IF NOT MBServerIsRunning('plc_server') THEN
            state := 1;  (* Restart *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 3.2 Coil Access (Read/Write Booleans)

#### MBServerSetCoil — Write a Coil Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Coil address (0-based) |
| `value` | BOOL | TRUE = ON, FALSE = OFF |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Set coil 0 to ON — visible to any connected Modbus client *)
ok := MBServerSetCoil('plc_server', 0, TRUE);
```

#### MBServerGetCoil — Read a Coil Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Coil address (0-based) |

Returns: `BOOL` — Current coil state.

```iecst
(* Read coil 0 — may have been written by a remote SCADA master *)
run_cmd := MBServerGetCoil('plc_server', 0);
```

> **Bidirectional data flow:** Remote Modbus clients can write coils (FC05/FC15) and holding registers (FC06/FC16) on your server. Use `MBServerGetCoil` and `MBServerGetHoldingRegister` to read values that remote masters have written. This is how SCADA systems send commands to GoPLC.

#### Example: Coil-Based Remote Control

```iecst
PROGRAM POU_CoilControl
VAR
    remote_run : BOOL;
    remote_reset : BOOL;
    motor_running : BOOL;
END_VAR

(* Read commands from SCADA via coils *)
remote_run := MBServerGetCoil('plc_server', 0);
remote_reset := MBServerGetCoil('plc_server', 1);

(* Execute commands *)
IF remote_run AND NOT motor_running THEN
    motor_running := TRUE;
END_IF;

IF remote_reset THEN
    motor_running := FALSE;
    MBServerSetCoil('plc_server', 1, FALSE);  (* Auto-clear reset *)
END_IF;

(* Report status back *)
MBServerSetCoil('plc_server', 10, motor_running);
END_PROGRAM
```

---

### 3.3 Discrete Input Access (Read-Only Booleans)

#### MBServerSetDiscreteInput — Set a Discrete Input Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Input address (0-based) |
| `value` | BOOL | TRUE = ON, FALSE = OFF |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Expose sensor states as discrete inputs *)
ok := MBServerSetDiscreteInput('plc_server', 0, limit_switch_1);
ok := MBServerSetDiscreteInput('plc_server', 1, limit_switch_2);
ok := MBServerSetDiscreteInput('plc_server', 2, e_stop_ok);
```

> **Read-only to clients:** Remote Modbus masters can only read discrete inputs (FC02). They cannot write them. Use this area for status and sensor data that should not be overwritten remotely.

---

### 3.4 Holding Register Access (Read/Write Integers)

#### MBServerSetHoldingRegister — Write a Holding Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit register value |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Expose process values as holding registers *)
ok := MBServerSetHoldingRegister('plc_server', 0, motor_speed);
ok := MBServerSetHoldingRegister('plc_server', 1, motor_current);
ok := MBServerSetHoldingRegister('plc_server', 2, temperature);
```

#### MBServerGetHoldingRegister — Read a Holding Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |

Returns: `INT` — Current register value.

```iecst
(* Read setpoint written by remote SCADA *)
speed_setpoint := MBServerGetHoldingRegister('plc_server', 100);
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
speed_setpoint := MBServerGetHoldingRegister('plc_server', 100);

(* GoPLC publishes actual speed to register 0 *)
actual_speed := 2950;  (* From VFD feedback *)
ok := MBServerSetHoldingRegister('plc_server', 0, actual_speed);
END_PROGRAM
```

---

### 3.5 Input Register Access (Read-Only Integers)

#### MBServerSetInputRegister — Set an Input Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit register value |

Returns: `BOOL` — TRUE if the value was set.

```iecst
(* Expose analog measurements as input registers *)
ok := MBServerSetInputRegister('plc_server', 0, pressure_psi);
ok := MBServerSetInputRegister('plc_server', 1, flow_gpm);
ok := MBServerSetInputRegister('plc_server', 2, level_percent);
```

#### MBServerGetInputRegister — Read an Input Register

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `address` | INT | Register address (0-based) |

Returns: `INT` — Current register value.

```iecst
value := MBServerGetInputRegister('plc_server', 0);
```

> **Input registers vs. holding registers:** Use input registers (FC04) for sensor data and measured values. Use holding registers (FC03/FC06) for setpoints and bidirectional data. This follows the Modbus convention and makes your register map intuitive to integrators.

---

### 3.6 Server Diagnostics and Management

#### MBServerGetStats — Server Statistics

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `MAP` — Statistics including request count, response count, and error count.

```iecst
stats := MBServerGetStats('plc_server');
(* Returns: {"requests": 8420, "responses": 8420, "errors": 0} *)
```

#### MBServerGetConnections — List Connected Clients

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `[]MAP` — Array of connected client information.

```iecst
connections := MBServerGetConnections('plc_server');
(* Returns: [{"remote_addr": "10.0.0.100:49832", "connected_at": "2026-04-03T10:15:00Z"},
             {"remote_addr": "10.0.0.101:52100", "connected_at": "2026-04-03T10:16:30Z"}] *)
```

> **Security awareness:** Any device on the network can connect to your Modbus server. Use `MBServerGetConnections` to audit who is connected. For production systems, consider placing the Modbus server on a dedicated VLAN or using firewall rules.

#### MBServerDelete — Remove Server

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server was deleted.

```iecst
MBServerStop('plc_server');
ok := MBServerDelete('plc_server');
```

#### MBServerList — List All Servers

Returns: `[]STRING` — Array of all server names.

```iecst
servers := MBServerList();
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
        ok := MBClientCreate('acs355', '10.0.0.50', 502, 1);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := MBClientConnect('acs355');
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
        IF NOT MBClientIsConnected('acs355') THEN
            state := 1;   (* Reconnect *)
        END_IF;

        (* Read 5 status registers starting at address 1 *)
        status_regs := MBClientReadHoldingRegisters('acs355', 1, 5);

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

        ok := MBClientWriteRegister('acs355', 0, control_word);
        ok := MBClientWriteRegister('acs355', 1, speed_setpoint);

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
        ok := MBServerCreate('scada', 502);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Start listening *)
        ok := MBServerStart('scada');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — update all data areas every scan *)
        scan_count := scan_count + 1;

        (* === Write process values to holding registers === *)
        MBServerSetHoldingRegister('scada', 0, line_speed);
        MBServerSetHoldingRegister('scada', 1, motor_current);
        MBServerSetHoldingRegister('scada', 2, temperature);
        MBServerSetHoldingRegister('scada', 3, pressure);
        MBServerSetHoldingRegister('scada', 4, batch_count);

        (* === Write input registers === *)
        MBServerSetInputRegister('scada', 0, DINT_TO_INT(uptime_sec));
        MBServerSetInputRegister('scada', 1, DINT_TO_INT(scan_count));

        (* === Write discrete inputs === *)
        MBServerSetDiscreteInput('scada', 0, e_stop_ok);
        MBServerSetDiscreteInput('scada', 1, guard_closed);
        MBServerSetDiscreteInput('scada', 2, system_running);

        (* === Write coil status === *)
        MBServerSetCoil('scada', 10, system_running);
        MBServerSetCoil('scada', 11, fault_active);

        (* === Read commands from SCADA === *)
        scada_start := MBServerGetCoil('scada', 0);
        scada_stop := MBServerGetCoil('scada', 1);
        scada_setpoint := MBServerGetHoldingRegister('scada', 100);
        scada_mode := MBServerGetHoldingRegister('scada', 101);

        (* Process commands *)
        IF scada_start AND NOT system_running THEN
            system_running := TRUE;
            MBServerSetCoil('scada', 0, FALSE);  (* Auto-clear *)
        END_IF;

        IF scada_stop AND system_running THEN
            system_running := FALSE;
            MBServerSetCoil('scada', 1, FALSE);  (* Auto-clear *)
        END_IF;

        (* Health check *)
        IF NOT MBServerIsRunning('scada') THEN
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
        ok := MBClientCreate('meter', '10.0.0.70', 502, 1);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect Modbus *)
        ok := MBClientConnect('meter');
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
        IF NOT MBClientIsConnected('meter') THEN
            MBClientConnect('meter');
        END_IF;

        (* Read 10 registers from power meter *)
        regs := MBClientReadHoldingRegisters('meter', 0, 10);

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
                        MBClientGetStats('meter'));
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
regs := MBClientReadHoldingRegisters(devices[poll_index], 0, 5);

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
regs := MBClientReadHoldingRegisters('meter', 0, 2);

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
        ok := MBClientCreate('vfd', '10.0.0.50', 502);
        ok := MBServerCreate('scada', 5020);
        IF ok THEN state := 1; END_IF;

    1: (* Connect/Start *)
        MBClientConnect('vfd');
        MBServerStart('scada');
        state := 10;

    10: (* Running — bridge VFD data to SCADA *)
        (* Read from VFD (client role) *)
        regs := MBClientReadHoldingRegisters('vfd', 0, 2);
        vfd_speed := regs[0];
        vfd_current := regs[1];

        (* Expose to SCADA (server role) *)
        MBServerSetHoldingRegister('scada', 0, vfd_speed);
        MBServerSetHoldingRegister('scada', 1, vfd_current);

        (* Read setpoint from SCADA, forward to VFD *)
        MBClientWriteRegister('vfd', 10,
            MBServerGetHoldingRegister('scada', 100));
END_CASE;
END_PROGRAM
```

---

## Appendix A: Modbus Function Code Reference

| FC | Name | GoPLC Client Function | Max Items |
|----|------|-----------------------|-----------|
| 01 | Read Coils | `MBClientReadCoils` | 2000 |
| 02 | Read Discrete Inputs | `MBClientReadDiscreteInputs` | 2000 |
| 03 | Read Holding Registers | `MBClientReadHoldingRegisters` | 125 |
| 04 | Read Input Registers | `MBClientReadInputRegisters` | 125 |
| 05 | Write Single Coil | `MBClientWriteCoil` | 1 |
| 06 | Write Single Register | `MBClientWriteRegister` | 1 |
| 15 | Write Multiple Coils | `MBClientWriteCoils` | 1968 |
| 16 | Write Multiple Registers | `MBClientWriteRegisters` | 123 |

---

## Appendix B: Quick Reference — All 30 Functions

### Client Functions (15)

| Function | Returns | Description |
|----------|---------|-------------|
| `MBClientCreate(name, host, port [, slave_id])` | BOOL | Create named connection |
| `MBClientConnect(name)` | BOOL | Establish TCP connection |
| `MBClientDisconnect(name)` | BOOL | Close TCP connection |
| `MBClientIsConnected(name)` | BOOL | Check connection state |
| `MBClientReadCoils(name, address, count)` | []BOOL | FC01: Read coils |
| `MBClientReadDiscreteInputs(name, address, count)` | []BOOL | FC02: Read discrete inputs |
| `MBClientReadHoldingRegisters(name, address, count)` | []INT | FC03: Read holding registers |
| `MBClientReadInputRegisters(name, address, count)` | []INT | FC04: Read input registers |
| `MBClientWriteCoil(name, address, value)` | BOOL | FC05: Write single coil |
| `MBClientWriteRegister(name, address, value)` | BOOL | FC06: Write single register |
| `MBClientWriteCoils(name, address, values)` | BOOL | FC15: Write multiple coils |
| `MBClientWriteRegisters(name, address, values)` | BOOL | FC16: Write multiple registers |
| `MBClientGetStats(name)` | MAP | Request/response/error counts |
| `MBClientDelete(name)` | BOOL | Remove connection |
| `MBClientList()` | []STRING | List all connections |

### Server Functions (15)

| Function | Returns | Description |
|----------|---------|-------------|
| `MBServerCreate(name, port [, slave_id])` | BOOL | Create named server |
| `MBServerStart(name)` | BOOL | Begin listening |
| `MBServerStop(name)` | BOOL | Stop listening |
| `MBServerIsRunning(name)` | BOOL | Check server state |
| `MBServerSetCoil(name, address, value)` | BOOL | Write coil value |
| `MBServerGetCoil(name, address)` | BOOL | Read coil value |
| `MBServerSetDiscreteInput(name, address, value)` | BOOL | Set discrete input |
| `MBServerSetHoldingRegister(name, address, value)` | BOOL | Write holding register |
| `MBServerGetHoldingRegister(name, address)` | INT | Read holding register |
| `MBServerSetInputRegister(name, address, value)` | BOOL | Set input register |
| `MBServerGetInputRegister(name, address)` | INT | Read input register |
| `MBServerGetStats(name)` | MAP | Request/response/error counts |
| `MBServerGetConnections(name)` | []MAP | List connected clients |
| `MBServerDelete(name)` | BOOL | Remove server |
| `MBServerList()` | []STRING | List all servers |

---

*GoPLC v1.0.520 | Modbus TCP Client + Server | IEC 61131-3 Structured Text*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
