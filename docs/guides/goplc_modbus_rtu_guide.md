# GoPLC Modbus RTU Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC provides a full Modbus RTU implementation covering both **client** (master) and **server** (slave) roles over serial ports. The driver handles framing, CRC-16, inter-character timing (t1.5/t3.5), and automatic retransmission — your ST code works with named connections and typed registers, never raw bytes.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client (Master)** | `MB_RTU_CONNECT` / `MB_RTU_READ_*` / `MB_RTU_WRITE_*` | Poll field devices — VFDs, power meters, sensors |
| **Server (Slave)** | `MB_RTU_SERVER_CREATE` / `MB_RTU_SERVER_SET_*` / `MB_RTU_SERVER_GET_*` | Expose GoPLC data to SCADA, HMI, or other masters |

Both roles support **RTU-over-TCP** for long-distance serial tunneling (serial device servers, Moxa gateways, etc.).

### System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                 │
│                                                             │
│  ┌──────────────────────┐   ┌────────────────────────────┐  │
│  │ ST Program (Client)  │   │ ST Program (Server)        │  │
│  │                      │   │                            │  │
│  │ MB_RTU_CONNECT()       │   │ MB_RTU_SERVER_CREATE()        │  │
│  │ MB_RTU_READ_HOLDING()   │   │ MB_RTU_SERVER_START_SERIAL()   │  │
│  │ MB_RTU_WRITE_REGISTER() │   │ MB_RTU_SERVER_SET_HOLDING()    │  │
│  │ MB_RTU_SCAN_BUS()       │   │ MB_RTU_SERVER_START_TCP()      │  │
│  └──────────┬───────────┘   └──────────┬─────────────────┘  │
│             │                          │                    │
│             │  RS-485 / USB-Serial     │  RS-485 / TCP      │
└─────────────┼──────────────────────────┼────────────────────┘
              │                          │
              ▼                          ▼
┌─────────────────────┐    ┌──────────────────────────────┐
│  Modbus RTU Bus     │    │  External Master / SCADA     │
│                     │    │                              │
│  ┌───┐ ┌───┐ ┌───┐ │    │  Reads holding registers     │
│  │ID1│ │ID2│ │ID3│ │    │  exposed by GoPLC server     │
│  │VFD│ │MTR│ │TMP│ │    │                              │
│  └───┘ └───┘ └───┘ │    └──────────────────────────────┘
└─────────────────────┘
```

### RS-485 Wiring

GoPLC uses standard RS-485 half-duplex wiring via USB-to-RS485 adapters (FTDI, CH340, etc.):

| Signal | Description |
|--------|-------------|
| **A (D-)** | Inverting — negative when idle |
| **B (D+)** | Non-inverting — positive when idle |
| **GND** | Signal ground — always connect between devices |

> **Termination:** Add a 120-ohm resistor across A/B at both ends of the bus for runs over 10 meters or baud rates above 19200.

> **Bias:** If the bus floats when no device is transmitting, add 680-ohm pull-up on B and pull-down on A to prevent ghost frames. Most USB adapters include on-board bias resistors.

---

## 2. Client Functions

### 2.1 Connection Management

#### MB_RTU_CONNECT — Open Serial Connection

```iecst
ok := MB_RTU_CONNECT(name, device, baud);
ok := MB_RTU_CONNECT(name, device, baud, slave_id);
ok := MB_RTU_CONNECT(name, device, baud, slave_id, parity);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection identifier (used by all subsequent calls) |
| `device` | STRING | Serial port path: `/dev/ttyUSB0`, `/dev/ttyS1`, `COM3` |
| `baud` | INT | Baud rate: 9600, 19200, 38400, 57600, 115200 |
| `slave_id` | INT | Default slave address 1-247 (optional, default 1) |
| `parity` | STRING | `'N'` = none, `'E'` = even, `'O'` = odd (optional, default `'E'`) |

Returns `TRUE` on success.

```iecst
(* Connect to a VFD on /dev/ttyUSB0 at 9600 baud, slave 1, even parity *)
ok := MB_RTU_CONNECT('vfd', '/dev/ttyUSB0', 9600, 1, 'E');

(* Minimal form — defaults to slave 1, even parity *)
ok := MB_RTU_CONNECT('meter', '/dev/ttyUSB1', 19200);
```

> **Parity convention:** Most Modbus RTU devices default to 8E1 (8 data bits, even parity, 1 stop bit). If the device uses 8N2 (no parity, 2 stop bits), pass `'N'`. Both formats produce 11-bit character frames per the Modbus specification.

#### MB_RTU_CLOSE — Close Connection

```iecst
ok := MB_RTU_CLOSE('vfd');
```

Releases the serial port. Returns `TRUE` on success.

#### MB_RTU_CONNECTED — Check Connection

```iecst
connected := MB_RTU_CONNECTED('vfd');
```

Returns `TRUE` if the named connection is open and the serial port is accessible.

#### MB_RTU_SET_SLAVE — Change Target Slave

```iecst
ok := MB_RTU_SET_SLAVE('bus', 3);
```

Changes the target slave address for subsequent read/write calls on the named connection. Use this when polling multiple devices on the same RS-485 bus through a single serial port.

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `slaveID` | INT | New target slave address 1-247 |

#### MB_RTU_LIST — List Active Connections

```iecst
names := MB_RTU_LIST();
(* Returns: ['vfd', 'meter'] *)
```

Returns an array of all active client connection names.

---

### 2.2 Read Functions

All read functions take a connection name, a starting register address, and a count. They return typed arrays.

#### MB_RTU_READ_HOLDING — FC03 Read Holding Registers

```iecst
values := MB_RTU_READ_HOLDING(name, address, count);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address (0-based, 0-65535) |
| `count` | INT | Number of registers to read (1-125) |

Returns `[]INT` — array of 16-bit unsigned register values.

```iecst
(* Read 10 holding registers starting at address 0 *)
regs := MB_RTU_READ_HOLDING('vfd', 0, 10);

(* Read single register *)
speed := MB_RTU_READ_HOLDING('vfd', 8451, 1);
```

#### MB_RTU_READ_INPUT — FC04 Read Input Registers

```iecst
values := MB_RTU_READ_INPUT(name, address, count);
```

Same signature as `MB_RTU_READ_HOLDING`. Input registers are read-only sensor/status values maintained by the device.

```iecst
(* Read motor current from input register 0 *)
current := MB_RTU_READ_INPUT('vfd', 0, 1);
```

#### MB_RTU_READ_COILS — FC01 Read Coils

```iecst
coils := MB_RTU_READ_COILS(name, address, count);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting coil address (0-based, 0-65535) |
| `count` | INT | Number of coils to read (1-2000) |

Returns `[]BOOL` — array of coil states.

```iecst
(* Read 8 coils starting at address 0 *)
coils := MB_RTU_READ_COILS('plc', 0, 8);
running := coils[0];
fault := coils[1];
```

#### MB_RTU_READ_DISCRETE — FC02 Read Discrete Inputs

```iecst
inputs := MB_RTU_READ_DISCRETE(name, address, count);
```

Same signature as `MB_RTU_READ_COILS`. Discrete inputs are read-only digital status bits maintained by the device.

```iecst
(* Read 16 discrete inputs *)
inputs := MB_RTU_READ_DISCRETE('io_module', 0, 16);
```

---

### 2.3 Write Functions

#### MB_RTU_WRITE_REGISTER — FC06 Write Single Register

```iecst
ok := MB_RTU_WRITE_REGISTER(name, address, value);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit value to write (0-65535) |

```iecst
(* Set VFD frequency setpoint to 3000 = 30.00 Hz *)
ok := MB_RTU_WRITE_REGISTER('vfd', 8451, 3000);
```

#### MB_RTU_WRITE_COIL — FC05 Write Single Coil

```iecst
ok := MB_RTU_WRITE_COIL(name, address, value);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Coil address (0-based) |
| `value` | BOOL | `TRUE` = ON (0xFF00), `FALSE` = OFF (0x0000) |

```iecst
(* Start VFD — write coil 0 ON *)
ok := MB_RTU_WRITE_COIL('vfd', 0, TRUE);
```

#### MB_RTU_WRITE_REGISTERS — FC16 Write Multiple Registers

```iecst
ok := MB_RTU_WRITE_REGISTERS(name, address, values);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting register address |
| `values` | []INT | Array of 16-bit values to write (max 123) |

```iecst
(* Write PID parameters: Kp=100, Ki=50, Kd=25 *)
ok := MB_RTU_WRITE_REGISTERS('controller', 100, [100, 50, 25]);
```

#### MB_RTU_WRITE_COILS — FC15 Write Multiple Coils

```iecst
ok := MB_RTU_WRITE_COILS(name, address, values);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `address` | INT | Starting coil address |
| `values` | []BOOL | Array of coil states |

```iecst
(* Set outputs 0-3: ON, OFF, ON, ON *)
ok := MB_RTU_WRITE_COILS('io_module', 0, [TRUE, FALSE, TRUE, TRUE]);
```

---

### 2.4 Diagnostics

#### MB_RTU_STATS — Connection Statistics

```iecst
stats := MB_RTU_STATS('vfd');
```

Returns a MAP with:

| Key | Type | Description |
|-----|------|-------------|
| `requests` | INT | Total requests sent |
| `responses` | INT | Successful responses received |
| `errors` | INT | CRC errors + timeouts + exception responses |
| `crc_errors` | INT | Frames with bad CRC-16 |
| `timeouts` | INT | No response within timeout |
| `last_error` | STRING | Most recent error description |
| `avg_response_ms` | REAL | Average round-trip time |

```iecst
stats := MB_RTU_STATS('vfd');
(* stats['errors'] = 3, stats['avg_response_ms'] = 12.4 *)
```

#### MB_RTU_SCAN_BUS — Discover Devices

```iecst
devices := MB_RTU_SCAN_BUS(name, startID, endID);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name (must be open) |
| `startID` | INT | First slave ID to probe (1-247) |
| `endID` | INT | Last slave ID to probe (1-247) |

Returns `[]INT` — array of slave IDs that responded. Sends a read request to each address and waits for a response.

```iecst
(* Scan entire bus *)
devices := MB_RTU_SCAN_BUS('bus', 1, 247);
(* Returns: [1, 3, 17] — three devices found *)
```

> **Timing:** A full 1-247 scan takes 30-60 seconds depending on timeout settings. Use narrower ranges when you know the expected address range.

---

## 3. Server Functions

The server role turns GoPLC into a Modbus slave device. External masters (SCADA, HMI, other PLCs) can read and write GoPLC's register tables. The server supports three transport modes: serial, RTU-over-TCP listener, and RTU-over-TCP client.

### 3.1 Server Lifecycle

#### MB_RTU_SERVER_CREATE — Create Server Instance

```iecst
ok := MB_RTU_SERVER_CREATE(name, slave_id);
ok := MB_RTU_SERVER_CREATE(name, slave_id, baud);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server instance name |
| `slave_id` | INT | This server's slave address (1-247) |
| `baud` | INT | Baud rate for serial mode (optional, default 9600) |

```iecst
ok := MB_RTU_SERVER_CREATE('srv', 1, 19200);
```

#### MB_RTU_SERVER_START_SERIAL — Listen on Serial Port

```iecst
ok := MB_RTU_SERVER_START_SERIAL(name, device);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server instance name |
| `device` | STRING | Serial port path |

Starts listening for master requests on the specified serial port.

```iecst
ok := MB_RTU_SERVER_START_SERIAL('srv', '/dev/ttyUSB0');
```

#### MB_RTU_SERVER_START_TCP — Listen on TCP (RTU-over-TCP)

```iecst
ok := MB_RTU_SERVER_START_TCP(name, addr);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server instance name |
| `addr` | STRING | Listen address — `host:port` or `:port` |

Starts a TCP listener that accepts RTU-framed connections. This is standard RTU framing (slave ID + function + data + CRC) transported over TCP instead of serial.

```iecst
(* Listen on all interfaces, port 5020 *)
ok := MB_RTU_SERVER_START_TCP('srv', ':5020');
```

#### MB_RTU_SERVER_CONNECT_TCP — RTU-over-TCP Client

```iecst
ok := MB_RTU_SERVER_CONNECT_TCP(name, addr);
```

Connects as a client to a remote RTU-over-TCP endpoint. The server responds to requests received over this TCP connection as if it were on a serial bus.

```iecst
(* Connect to remote serial device server *)
ok := MB_RTU_SERVER_CONNECT_TCP('srv', '10.0.0.50:8502');
```

#### MB_RTU_SERVER_STOP — Stop Server

```iecst
ok := MB_RTU_SERVER_STOP('srv');
```

Stops the server. Closes the serial port or TCP listener/connection.

#### MB_RTU_SERVER_IS_RUNNING — Check Server Status

```iecst
running := MB_RTU_SERVER_IS_RUNNING('srv');
```

Returns `TRUE` if the server is actively listening for requests.

#### MB_RTU_SERVER_DELETE — Delete Server Instance

```iecst
ok := MB_RTU_SERVER_DELETE('srv');
```

Stops (if running) and removes the server instance. Frees all associated register memory.

#### MB_RTU_SERVER_LIST — List Active Servers

```iecst
servers := MB_RTU_SERVER_LIST();
(* Returns: ['srv', 'bridge'] *)
```

---

### 3.2 Register Access

The server maintains four register tables per the Modbus specification:

| Table | Address Range | Type | Access | Functions |
|-------|--------------|------|--------|-----------|
| **Holding Registers** | 40001-49999 | 16-bit INT | Read/Write | `SetHolding`, `GetHolding` |
| **Input Registers** | 30001-39999 | 16-bit INT | Read Only | `SetInput` |
| **Coils** | 00001-09999 | BOOL | Read/Write | `SetCoil`, `GetCoil` |
| **Discrete Inputs** | 10001-19999 | BOOL | Read Only | `SetDiscrete` |

> **Addressing:** All GoPLC functions use 0-based addressing. Register 40001 in Modbus documentation = address 0 in GoPLC. The driver handles the offset translation.

#### MB_RTU_SERVER_SET_HOLDING / GetHolding — Holding Registers

```iecst
ok := MB_RTU_SERVER_SET_HOLDING(name, address, value);
val := MB_RTU_SERVER_GET_HOLDING(name, address);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server instance name |
| `address` | INT | Register address (0-based) |
| `value` | INT | 16-bit value (0-65535) |

```iecst
(* Expose motor speed to SCADA *)
MB_RTU_SERVER_SET_HOLDING('srv', 0, motor_rpm);

(* Read setpoint written by SCADA *)
target_rpm := MB_RTU_SERVER_GET_HOLDING('srv', 1);
```

#### MB_RTU_SERVER_SET_INPUT — Input Registers

```iecst
ok := MB_RTU_SERVER_SET_INPUT(name, address, value);
```

Input registers are read-only from the master's perspective. Your ST code populates them; the master reads them via FC04.

```iecst
(* Expose temperature reading *)
MB_RTU_SERVER_SET_INPUT('srv', 0, temp_raw);
MB_RTU_SERVER_SET_INPUT('srv', 1, pressure_raw);
```

#### MB_RTU_SERVER_SET_COIL / GetCoil — Coils

```iecst
ok := MB_RTU_SERVER_SET_COIL(name, address, value);
state := MB_RTU_SERVER_GET_COIL(name, address);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server instance name |
| `address` | INT | Coil address (0-based) |
| `value` | BOOL | `TRUE` or `FALSE` |

```iecst
(* Expose pump running status *)
MB_RTU_SERVER_SET_COIL('srv', 0, pump_running);

(* Check if SCADA wrote a start command *)
start_cmd := MB_RTU_SERVER_GET_COIL('srv', 10);
```

#### MB_RTU_SERVER_SET_DISCRETE — Discrete Inputs

```iecst
ok := MB_RTU_SERVER_SET_DISCRETE(name, address, value);
```

Discrete inputs are read-only from the master's perspective (FC02). Your ST code updates them.

```iecst
(* Expose digital input states *)
MB_RTU_SERVER_SET_DISCRETE('srv', 0, limit_switch_1);
MB_RTU_SERVER_SET_DISCRETE('srv', 1, limit_switch_2);
```

---

### 3.3 Server Diagnostics

#### MB_RTU_SERVER_STATS — Server Statistics

```iecst
stats := MB_RTU_SERVER_STATS('srv');
```

Returns a MAP with:

| Key | Type | Description |
|-----|------|-------------|
| `requests` | INT | Total requests received from master |
| `responses` | INT | Successful responses sent |
| `errors` | INT | Malformed requests + CRC errors |
| `slave_id` | INT | Configured slave address |
| `transport` | STRING | `"serial"`, `"tcp_listen"`, or `"tcp_connect"` |

---

## 4. Examples

### 4.1 Bus Scanning — Discovering Devices

Before writing polling logic, scan the bus to find what is connected:

```iecst
PROGRAM POU_BusScan
VAR
    ok : BOOL;
    devices : ARRAY[0..246] OF INT;
    device_count : INT;
    scan_done : BOOL := FALSE;
    state : INT := 0;
    i : INT;
END_VAR

CASE state OF
    0: (* Open connection on the RS-485 port *)
        ok := MB_RTU_CONNECT('scan', '/dev/ttyUSB0', 9600, 1, 'E');
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Scan the bus — probe addresses 1 through 32 *)
        devices := MB_RTU_SCAN_BUS('scan', 1, 32);
        state := 2;

    2: (* Log results *)
        device_count := LEN(devices);
        FOR i := 0 TO device_count - 1 DO
            LOG('Found device at slave ID: ' + INT_TO_STRING(devices[i]));
        END_FOR;
        scan_done := TRUE;
        state := 3;

    3: (* Done — close or keep connection for polling *)
        MB_RTU_CLOSE('scan');
        state := 99;

    99: (* Idle *)
        ;
END_CASE;
END_PROGRAM
```

> **Tip:** Run the scan program once from the IDE, check the log output, then remove it. Scanning is a commissioning tool, not something to run every scan cycle.

---

### 4.2 Multi-Slave Polling — VFD + Power Meter on One Bus

This example polls two devices on the same RS-485 bus using `MB_RTU_SET_SLAVE` to switch between them each scan cycle:

```iecst
PROGRAM POU_MultiSlavePoll
VAR
    ok : BOOL;
    connected : BOOL := FALSE;
    state : INT := 0;

    (* VFD data — slave ID 1 *)
    vfd_speed_hz : INT;       (* x0.01 Hz *)
    vfd_current_a : INT;      (* x0.1 A *)
    vfd_fault : BOOL;

    (* Power meter data — slave ID 3 *)
    meter_voltage : INT;      (* x0.1 V *)
    meter_power_w : INT;

    (* Polling state *)
    poll_target : INT := 0;   (* 0 = VFD, 1 = meter *)
    stats : MAP;
    regs : ARRAY[0..9] OF INT;
END_VAR

CASE state OF
    0: (* Initialize — open serial port *)
        ok := MB_RTU_CONNECT('bus', '/dev/ttyUSB0', 19200, 1, 'E');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Alternate between devices each scan *)
        IF poll_target = 0 THEN
            (* ---- Poll VFD (slave 1) ---- *)
            MB_RTU_SET_SLAVE('bus', 1);

            (* Read output frequency and current *)
            regs := MB_RTU_READ_HOLDING('bus', 8451, 2);
            vfd_speed_hz := regs[0];
            vfd_current_a := regs[1];

            (* Read fault coil *)
            vfd_fault := MB_RTU_READ_COILS('bus', 0, 1)[0];

            poll_target := 1;
        ELSE
            (* ---- Poll meter (slave 3) ---- *)
            MB_RTU_SET_SLAVE('bus', 3);

            (* Read voltage and power *)
            regs := MB_RTU_READ_INPUT('bus', 0, 2);
            meter_voltage := regs[0];
            meter_power_w := regs[1];

            poll_target := 0;
        END_IF;
        state := 10;  (* loop *)

END_CASE;
END_PROGRAM
```

> **Scan time impact:** Each Modbus transaction takes 10-50ms depending on baud rate and device response time. Polling two devices per cycle doubles your effective scan time. For faster updates, use a longer task interval and batch reads.

---

### 4.3 RTU-over-TCP Bridge — Serial to Network

This example creates a bridge between a physical RS-485 bus and a remote SCADA system. The GoPLC server exposes local device data over TCP, allowing a remote Modbus master to read the same registers without direct serial access.

```iecst
PROGRAM POU_RtuBridge
VAR
    ok : BOOL;
    state : INT := 0;

    (* Client — reads from local RS-485 devices *)
    sensor_temp : INT;
    sensor_pressure : INT;
    pump_running : BOOL;

    (* Server — exposes data over TCP *)
    scada_setpoint : INT;
    scada_start_cmd : BOOL;
END_VAR

CASE state OF
    0: (* Initialize client — read from RS-485 bus *)
        ok := MB_RTU_CONNECT('field', '/dev/ttyUSB0', 9600, 1, 'E');
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Initialize server — expose data over TCP *)
        ok := MB_RTU_SERVER_CREATE('bridge', 1, 9600);
        IF ok THEN
            ok := MB_RTU_SERVER_START_TCP('bridge', ':5020');
            IF ok THEN
                state := 10;
            END_IF;
        END_IF;

    10: (* Running — poll field devices *)
        (* Read temperature sensor at slave 1 *)
        MB_RTU_SET_SLAVE('field', 1);
        sensor_temp := MB_RTU_READ_INPUT('field', 0, 1)[0];

        (* Read pressure sensor at slave 2 *)
        MB_RTU_SET_SLAVE('field', 2);
        sensor_pressure := MB_RTU_READ_INPUT('field', 0, 1)[0];

        (* Read pump status coil at slave 3 *)
        MB_RTU_SET_SLAVE('field', 3);
        pump_running := MB_RTU_READ_COILS('field', 0, 1)[0];

        state := 20;

    20: (* Update server registers — SCADA reads these *)
        MB_RTU_SERVER_SET_INPUT('bridge', 0, sensor_temp);
        MB_RTU_SERVER_SET_INPUT('bridge', 1, sensor_pressure);
        MB_RTU_SERVER_SET_COIL('bridge', 0, pump_running);

        (* Read commands written by SCADA *)
        scada_setpoint := MB_RTU_SERVER_GET_HOLDING('bridge', 0);
        scada_start_cmd := MB_RTU_SERVER_GET_COIL('bridge', 10);

        (* Apply SCADA commands to field devices *)
        IF scada_start_cmd THEN
            MB_RTU_SET_SLAVE('field', 3);
            MB_RTU_WRITE_COIL('field', 0, TRUE);
        END_IF;

        state := 10;  (* loop *)

END_CASE;
END_PROGRAM
```

> **RTU-over-TCP vs Modbus TCP:** RTU-over-TCP wraps the exact same RTU frame (slave ID + function + data + CRC-16) inside a TCP stream. It is **not** Modbus TCP (which uses a MBAP header and no CRC). Many serial device servers (Moxa, USR, Waveshare) use RTU-over-TCP mode. If your master speaks Modbus TCP, use the `MBTcp*` functions instead.

---

### 4.4 Server-Only — Exposing GoPLC Data to HMI

A minimal server that exposes process values for an HMI to read:

```iecst
PROGRAM POU_HmiServer
VAR
    ok : BOOL;
    state : INT := 0;

    (* Process values updated elsewhere *)
    tank_level : INT;          (* 0-10000 = 0.0-100.0% *)
    flow_rate : INT;           (* x0.1 L/min *)
    valve_pos : INT;           (* 0-10000 = 0.0-100.0% *)
    alarm_high : BOOL;
    alarm_low : BOOL;
    pump_enable : BOOL;
END_VAR

CASE state OF
    0: (* Create and start server *)
        ok := MB_RTU_SERVER_CREATE('hmi', 1, 19200);
        IF ok THEN
            ok := MB_RTU_SERVER_START_SERIAL('hmi', '/dev/ttyUSB1');
            IF ok THEN
                state := 10;
            END_IF;
        END_IF;

    10: (* Update server registers every scan *)
        (* Input registers — HMI reads these (FC04) *)
        MB_RTU_SERVER_SET_INPUT('hmi', 0, tank_level);
        MB_RTU_SERVER_SET_INPUT('hmi', 1, flow_rate);
        MB_RTU_SERVER_SET_INPUT('hmi', 2, valve_pos);

        (* Discrete inputs — HMI reads alarm states (FC02) *)
        MB_RTU_SERVER_SET_DISCRETE('hmi', 0, alarm_high);
        MB_RTU_SERVER_SET_DISCRETE('hmi', 1, alarm_low);

        (* Coils — HMI can read and write pump enable (FC01/FC05) *)
        pump_enable := MB_RTU_SERVER_GET_COIL('hmi', 0);

        state := 10;  (* loop *)

END_CASE;
END_PROGRAM
```

---

## 5. Modbus RTU Protocol Notes

### 5.1 Framing

Every Modbus RTU frame on the wire:

```
┌──────────┬──────────┬───────────────┬──────────┐
│ Slave ID │ Function │ Data (0-252)  │ CRC-16   │
│   1 byte │  1 byte  │   N bytes     │  2 bytes │
└──────────┴──────────┴───────────────┴──────────┘
```

- **CRC-16** (polynomial 0xA001) is appended LSB first
- **Inter-frame gap:** 3.5 character times of silence delimits frames
- **Inter-character timeout:** 1.5 character times max between bytes within a frame
- GoPLC handles all timing, CRC generation, and validation automatically

### 5.2 Function Code Summary

| FC | Name | Client Function | Direction |
|----|------|----------------|-----------|
| 01 | Read Coils | `MB_RTU_READ_COILS` | Master reads slave coils |
| 02 | Read Discrete Inputs | `MB_RTU_READ_DISCRETE` | Master reads slave inputs |
| 03 | Read Holding Registers | `MB_RTU_READ_HOLDING` | Master reads slave registers |
| 04 | Read Input Registers | `MB_RTU_READ_INPUT` | Master reads slave registers |
| 05 | Write Single Coil | `MB_RTU_WRITE_COIL` | Master writes slave coil |
| 06 | Write Single Register | `MB_RTU_WRITE_REGISTER` | Master writes slave register |
| 15 | Write Multiple Coils | `MB_RTU_WRITE_COILS` | Master writes slave coils |
| 16 | Write Multiple Registers | `MB_RTU_WRITE_REGISTERS` | Master writes slave registers |

### 5.3 Exception Responses

When a slave cannot fulfill a request, it returns an exception response (function code + 0x80):

| Code | Name | Meaning |
|------|------|---------|
| 0x01 | Illegal Function | Function code not supported |
| 0x02 | Illegal Data Address | Register address out of range |
| 0x03 | Illegal Data Value | Value outside allowed range |
| 0x04 | Slave Device Failure | Unrecoverable error on the device |
| 0x06 | Slave Device Busy | Device is processing a long-running command |

GoPLC logs exception responses and increments the `errors` counter in `MB_RTU_STATS`. The `last_error` field contains the decoded exception name.

### 5.4 Addressing Conventions

Modbus documentation uses 1-based register numbers with a leading digit indicating the table:

| Documentation | Table | GoPLC Address | Function |
|---------------|-------|---------------|----------|
| 00001-09999 | Coils | 0-9998 | `MB_RTU_READ_COILS` / `MB_RTU_WRITE_COIL` |
| 10001-19999 | Discrete Inputs | 0-9998 | `MB_RTU_READ_DISCRETE` |
| 30001-39999 | Input Registers | 0-9998 | `MB_RTU_READ_INPUT` |
| 40001-49999 | Holding Registers | 0-9998 | `MB_RTU_READ_HOLDING` / `MB_RTU_WRITE_REGISTER` |

> **Always subtract the table prefix and 1.** Documentation register 40001 = GoPLC address 0. Register 40100 = address 99. This is the most common source of off-by-one errors.

### 5.5 32-Bit Values

Modbus registers are 16 bits. 32-bit values (IEEE 754 float, DINT) occupy two consecutive registers. Word order varies by manufacturer:

```iecst
(* Big-endian word order (most common): high word first *)
regs := MB_RTU_READ_HOLDING('meter', 0, 2);
value_32 := regs[0] * 65536 + regs[1];

(* Little-endian word order (some devices): low word first *)
regs := MB_RTU_READ_HOLDING('meter', 0, 2);
value_32 := regs[1] * 65536 + regs[0];
```

> **Check the device manual.** There is no standard for 32-bit word order. Some devices use big-endian (AB CD), others use little-endian (CD AB), and a few use byte-swapped (BA DC or DC BA). Get it wrong and your floats will read as garbage.

---

## 6. Troubleshooting

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| All reads timeout | Wrong baud rate or parity | Match device settings exactly — check with `MB_RTU_SCAN_BUS` |
| CRC errors in stats | Electrical noise, wrong parity | Add termination resistors, verify wiring, check parity setting |
| Intermittent timeouts | Bus contention, slow device | Increase timeout, reduce poll frequency |
| Wrong register values | Address offset error | Subtract table prefix and 1 from documentation address |
| "Illegal Data Address" | Register out of device range | Check device register map |
| Reads work, writes fail | Device in read-only mode | Check device write-enable DIP switch or configuration register |

### Diagnostic Workflow

```iecst
(* Step 1: Check if connected *)
IF NOT MB_RTU_CONNECTED('dev') THEN
    LOG('Serial port not open');
END_IF;

(* Step 2: Check error stats *)
stats := MB_RTU_STATS('dev');
LOG('Requests: ' + INT_TO_STRING(stats['requests']));
LOG('Errors: ' + INT_TO_STRING(stats['errors']));
LOG('CRC Errors: ' + INT_TO_STRING(stats['crc_errors']));
LOG('Timeouts: ' + INT_TO_STRING(stats['timeouts']));
LOG('Last Error: ' + stats['last_error']);
LOG('Avg Response: ' + REAL_TO_STRING(stats['avg_response_ms']) + ' ms');

(* Step 3: Scan bus to verify device is responding *)
devices := MB_RTU_SCAN_BUS('dev', 1, 10);
LOG('Devices found: ' + INT_TO_STRING(LEN(devices)));
```

### Linux Serial Port Permissions

If `MB_RTU_CONNECT` fails on Linux, the GoPLC process needs access to the serial device:

```bash
# Add user to dialout group (persistent)
sudo usermod -a -G dialout goplc

# Or set permissions directly (resets on reboot)
sudo chmod 666 /dev/ttyUSB0
```

> **udev rules:** For production deployments, create a udev rule to assign a stable device name and permissions. USB serial adapters can change between `/dev/ttyUSB0` and `/dev/ttyUSB1` on reboot.

---

## Appendix A: Client Function Quick Reference

| Function | Returns | FC | Description |
|----------|---------|-----|-------------|
| `MB_RTU_CONNECT(name, device, baud [, slave_id] [, parity])` | BOOL | — | Open serial connection |
| `MB_RTU_CLOSE(name)` | BOOL | — | Close connection |
| `MB_RTU_CONNECTED(name)` | BOOL | — | Check connection status |
| `MB_RTU_SET_SLAVE(name, slaveID)` | BOOL | — | Change target slave address |
| `MB_RTU_READ_COILS(name, addr, count)` | []BOOL | 01 | Read coil outputs |
| `MB_RTU_READ_DISCRETE(name, addr, count)` | []BOOL | 02 | Read discrete inputs |
| `MB_RTU_READ_HOLDING(name, addr, count)` | []INT | 03 | Read holding registers |
| `MB_RTU_READ_INPUT(name, addr, count)` | []INT | 04 | Read input registers |
| `MB_RTU_WRITE_COIL(name, addr, value)` | BOOL | 05 | Write single coil |
| `MB_RTU_WRITE_REGISTER(name, addr, value)` | BOOL | 06 | Write single register |
| `MB_RTU_WRITE_COILS(name, addr, values)` | BOOL | 15 | Write multiple coils |
| `MB_RTU_WRITE_REGISTERS(name, addr, values)` | BOOL | 16 | Write multiple registers |
| `MB_RTU_STATS(name)` | MAP | — | Connection statistics |
| `MB_RTU_SCAN_BUS(name, startID, endID)` | []INT | — | Discover devices on bus |
| `MB_RTU_LIST()` | []STRING | — | List active connections |

## Appendix B: Server Function Quick Reference

| Function | Returns | Description |
|----------|---------|-------------|
| `MB_RTU_SERVER_CREATE(name, slave_id [, baud])` | BOOL | Create server instance |
| `MB_RTU_SERVER_START_SERIAL(name, device)` | BOOL | Listen on serial port |
| `MB_RTU_SERVER_START_TCP(name, addr)` | BOOL | Listen on TCP (RTU-over-TCP) |
| `MB_RTU_SERVER_CONNECT_TCP(name, addr)` | BOOL | Connect as RTU-over-TCP client |
| `MB_RTU_SERVER_STOP(name)` | BOOL | Stop server |
| `MB_RTU_SERVER_IS_RUNNING(name)` | BOOL | Check server status |
| `MB_RTU_SERVER_SET_HOLDING(name, addr, value)` | BOOL | Write holding register |
| `MB_RTU_SERVER_GET_HOLDING(name, addr)` | INT | Read holding register |
| `MB_RTU_SERVER_SET_INPUT(name, addr, value)` | BOOL | Write input register |
| `MB_RTU_SERVER_SET_COIL(name, addr, value)` | BOOL | Write coil |
| `MB_RTU_SERVER_GET_COIL(name, addr)` | BOOL | Read coil |
| `MB_RTU_SERVER_SET_DISCRETE(name, addr, value)` | BOOL | Write discrete input |
| `MB_RTU_SERVER_STATS(name)` | MAP | Server statistics |
| `MB_RTU_SERVER_DELETE(name)` | BOOL | Delete server instance |
| `MB_RTU_SERVER_LIST()` | []STRING | List active servers |

---

*GoPLC v1.0.533 | Modbus RTU: Client (15 functions) + Server (15 functions)*
*Supports: RS-485 serial, USB-serial adapters, RTU-over-TCP*

*(c) 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
