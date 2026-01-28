<p align="center">
  <img src="assets/goplc-logo.svg" alt="GOPLC Logo" width="400">
</p>

<h1 align="center">GOPLC</h1>

<p align="center">
  <strong>Industrial-Grade PLC Runtime in Go</strong><br>
  IEC 61131-3 Structured Text | 12+ Protocol Drivers | Web IDE | 160,000+ Lines of Code
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go 1.21+">
  <img src="https://img.shields.io/badge/IEC_61131--3-Structured_Text-blue?style=for-the-badge" alt="IEC 61131-3">
  <img src="https://img.shields.io/badge/Protocols-12+-green?style=for-the-badge" alt="12+ Protocols">
  <img src="https://img.shields.io/badge/Functions-1,450+-orange?style=for-the-badge" alt="1,450+ Functions">
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#protocols">Protocols</a> •
  <a href="#web-ide">Web IDE</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#examples">Examples</a> •
  <a href="#architecture">Architecture</a>
</p>

---

## What is GOPLC?

GOPLC is a **full-featured PLC runtime** written entirely in Go. It executes IEC 61131-3 Structured Text programs with industrial-grade features:

- **Multi-task scheduler** with priorities, watchdogs, and microsecond-precision scan times
- **12+ industrial protocols** including Modbus, EtherNet/IP, DNP3, BACnet, OPC UA, and FINS
- **Built-in Web IDE** with syntax highlighting, live debugging, and project management
- **1,450+ built-in functions** covering math, strings, crypto, HTTP, databases, and more
- **Real-time capable** with memory locking, CPU affinity, and GC tuning
- **Multi-PLC clustering** for distributed automation systems

<p align="center">
  <img src="assets/screenshots/web-ide.png" alt="GOPLC Web IDE" width="800">
</p>

---

## Features

### Core Runtime

| Feature | Description |
|---------|-------------|
| **ST Parser** | Full IEC 61131-3 Structured Text with extensions |
| **Multi-task Scheduler** | Cooperative scheduling with priorities (1-255) |
| **Scan Times** | From 100μs to hours, configurable per task |
| **Watchdog Protection** | Per-task watchdogs with fault/halt options |
| **Hot Reload** | Update programs without stopping the runtime |
| **Function Blocks** | TON, TOF, TP, RTO, CTU, CTD, CTUD, R_TRIG, F_TRIG, SR, RS, SEMA |

### 1,450+ Built-in Functions

| Category | Count | Highlights |
|----------|-------|------------|
| **Conversion** | 157 | INT_TO_REAL, DWORD_TO_TIME, HEX_TO_INT |
| **Data Structures** | 130 | LIST_*, MAP_*, QUEUE_*, STACK_*, SET_* |
| **Crypto** | 55 | AES_*, SHA*, RSA_*, JWT_*, HMAC_* |
| **Resilience** | 40 | CIRCUIT_BREAKER_*, RATE_LIMIT_*, RETRY_* |
| **Array** | 34 | ARRAY_SORT, ARRAY_FILTER, ARRAY_MAP, ARRAY_REDUCE |
| **Debug** | 30 | DEBUG_TO_FILE, DEBUG_TO_SQLITE, DEBUG_TO_INFLUX |
| **String** | 30 | CONCAT, SPLIT, REGEX_*, FORMAT, JSON_* |
| **HTTP** | 22 | HTTP_GET, HTTP_POST, URL_ENCODE, WEBSOCKET_* |
| **Database** | 18 | DB_CONNECT, DB_QUERY, DB_EXEC, DB_COMMIT |
| **+ OSCAT Library** | 557 | Complete OSCAT Basic library (384 functions + 173 FBs) |

### Real-time Capabilities

```yaml
realtime:
  enabled: true
  mode: container          # container | host | off
  lock_os_thread: true     # Pin goroutines to OS threads
  cpu_affinity: [2, 3]     # Pin to specific CPU cores
  memory_lock: true        # mlockall() to prevent page faults
  gc_percent: 500          # Reduce GC frequency
  rt_priority: 50          # SCHED_FIFO priority (requires privileges)
```

---

## Protocols

GOPLC includes **53,000+ lines** of industrial protocol code for seamless integration with existing automation systems.

### Industrial Protocols (11 Total)

| Protocol | Role | Transport | Lines | Target Systems |
|----------|------|-----------|-------|----------------|
| **Modbus TCP/RTU** | Server + Client | TCP, UDP, Serial | 7,241 | Universal - PLCs, VFDs, meters, sensors |
| **DNP3** | Master + Outstation | TCP, UDP, Serial | 13,354 | SCADA - Electric, water, gas utilities |
| **BACnet/IP & MSTP** | Server + Client | UDP, RS-485 | 7,883 | Building automation - HVAC, fire, access |
| **EtherNet/IP** | Adapter + Scanner | TCP, UDP | 5,388 | Allen-Bradley - CompactLogix, ControlLogix |
| **OPC UA** | Server + Client | TCP | 4,496 | Modern - Cloud integration, MES, SCADA |
| **FINS** | Server + Client | TCP, UDP | 3,565 | Omron - NX, NY, CP, CJ series PLCs |
| **S7comm** | Server + Client | TCP (TPKT/COTP) | 2,441 | Siemens - S7-300, S7-400, S7-1200, S7-1500 |
| **PROFINET** | Server + Client | TCP, UDP | 1,997 | Siemens - Real-time industrial Ethernet |
| **SEL** | Server + Client | Serial | 1,758 | Protective relays - Power system monitoring |
| **SNMP v1/v2c/v3** | Client + Trap | UDP | 3,597 | Network devices - Switches, UPS, sensors |
| **DF1** | Client | Serial | 1,417 | Allen-Bradley legacy - SLC 500, MicroLogix, PLC-5 |

### Protocol Features

<details>
<summary><strong>Modbus TCP/RTU</strong> - Click to expand</summary>

- Full function code support (FC01-06, FC15-16)
- Coils, discrete inputs, holding registers, input registers
- RTU framing with CRC-16
- RS-485 half-duplex with RTS control
- Connection pooling and retry logic
- Diagnostics counters (FC08)
- Gateway mode (TCP to RTU bridge)

</details>

<details>
<summary><strong>DNP3</strong> - Click to expand</summary>

- Complete Master and Outstation implementation
- Binary/Analog inputs and outputs
- Counters with freeze support
- Event buffering with classes (1, 2, 3)
- Unsolicited responses
- Select-Before-Operate (SBO) control
- Time synchronization
- Serial transport (RS-232/RS-485)
- Data link layer with FCB/FCV

</details>

<details>
<summary><strong>BACnet/IP & MSTP</strong> - Click to expand</summary>

- BACnet/IP over UDP (port 47808)
- BACnet/MSTP over RS-485 (token passing)
- All standard object types (AI, AO, AV, BI, BO, BV, MI, MO, MV)
- COV (Change of Value) subscriptions
- ReadPropertyMultiple for efficient polling
- Priority arrays (1-16) for commandable objects
- Schedule and Calendar objects
- TrendLog objects
- Alarm and Event services
- Segmentation for large responses
- Device discovery (Who-Is/I-Am)

</details>

<details>
<summary><strong>EtherNet/IP</strong> - Click to expand</summary>

- CIP (Common Industrial Protocol) messaging
- Adapter mode (expose tags to scanners)
- Scanner mode (read/write remote tags)
- Explicit messaging (TCP port 44818)
- Implicit I/O (UDP port 2222)
- ForwardOpen/ForwardClose connections
- Unconnected messaging (UCMM)
- Assembly objects for I/O data

</details>

<details>
<summary><strong>OPC UA</strong> - Click to expand</summary>

- Server and Client implementation
- Secure channel management
- Session authentication
- Node browsing
- Read/Write attributes
- Subscriptions with monitored items
- Method calls
- Security policies (None, Basic256Sha256)

</details>

<details>
<summary><strong>SNMP v1/v2c/v3</strong> - Click to expand</summary>

- SNMP v1, v2c, and v3 support
- GET, SET, GETNEXT, GETBULK operations
- WALK for MIB traversal
- Trap receiver
- SNMPv3 authentication (MD5, SHA)
- SNMPv3 privacy (DES, AES)
- ASN.1 BER encoding

</details>

### Communication Layer

| Module | Purpose | Transport | Features |
|--------|---------|-----------|----------|
| **DataLayer** | Multi-PLC sync | TCP, Shared Memory | Real-time variable sharing, <1ms latency, prefix filtering |
| **MQTT** | IoT/Cloud | TCP, TLS | Publish variables, subscribe to commands, QoS 0/1/2 |
| **HTTP/REST** | Integration | TCP | 60+ API endpoints, WebSocket streaming, SSE watch |
| **Store-and-Forward** | Reliability | SQLite | Offline buffering, GZIP compression, AES-256 encryption |
| **Serial** | Legacy | RS-232/485 | Configurable baud, parity, RTS/CTS flow control |

### Hardware Abstraction Layer (HAL)

**Tested & Production Ready:**

| Device | Interface | I/O Type | Use Case |
|--------|-----------|----------|----------|
| **Nextion HMI** | Serial/UART | Touch Display | Local operator interface |
| **USB Camera** | rpicam-still | Vision | Barcode, QC inspection |
| **ESP32 Remote I/O** | Modbus TCP | WiFi I/O Module | Wireless sensors/actuators |
| **Raspberry Pi GPIO** | Direct | Digital I/O | Edge computing, local control |
| **PCF8574** | I2C | 8-bit I/O Expander | Expand GPIO count |
| **Grove ADC** | I2C | Analog Input | Seeed Studio sensors |

**Implemented - Testing Soon:**

| Device | Interface | I/O Type | Use Case |
|--------|-----------|----------|----------|
| **Orange Pi GPIO** | Direct | Digital I/O | Cost-effective edge nodes |
| **ADXL345** | I2C | Accelerometer | Vibration monitoring |
| **DHT11/22** | 1-Wire | Temp/Humidity | Environmental sensing |
| **TFT Display** | SPI | Graphics Display | Custom HMI screens |
| **Propeller 2** | Serial | 8-core MCU | High-speed I/O, motor control |

**Planned:**

| Device | Interface | I/O Type | Use Case |
|--------|-----------|----------|----------|
| **MCP3008** | SPI | 8-ch 10-bit ADC | Analog sensor input |
| **ADS1115** | I2C | 4-ch 16-bit ADC | Precision measurement |
| **MAX31855** | SPI | Thermocouple | High-temp sensing |
| **MCP23017** | I2C | 16-bit I/O Expander | More GPIO |
| **W5500** | SPI | Ethernet | Wired network on MCU |

### Protocol Analyzer

Built-in packet capture and analysis with support for all protocols:

```bash
# Start capture with filters
curl -X POST http://localhost:8082/api/analyzer/start \
  -d '{"protocols": ["modbus-tcp", "dnp3", "bacnet"]}'

# View captured transactions
curl http://localhost:8082/api/analyzer/transactions?limit=100

# Export to Wireshark
curl http://localhost:8082/api/analyzer/export/pcap -o capture.pcap

# Decode raw packet
curl -X POST http://localhost:8082/api/analyzer/decode \
  -d '{"protocol":"modbus-tcp","raw_hex":"00 01 00 00 00 06 01 03 00 00 00 0A"}'
```

**Supported decoders:** Modbus TCP/RTU, DNP3, BACnet/IP, EtherNet/IP, OPC UA, S7, FINS, SEL

### Protocol Coverage by Industry

| Industry | Protocols |
|----------|-----------|
| **Manufacturing** | Modbus, EtherNet/IP, PROFINET, S7, FINS, OPC UA |
| **Building Automation** | BACnet/IP, BACnet/MSTP, Modbus, SNMP, OPC UA |
| **Utilities/SCADA** | DNP3, Modbus, SEL, OPC UA |
| **Oil & Gas** | Modbus, DNP3, OPC UA, EtherNet/IP |
| **Water/Wastewater** | DNP3, Modbus, OPC UA |
| **Power Generation** | DNP3, Modbus, SEL, IEC 61850 (planned) |
| **Food & Beverage** | EtherNet/IP, Modbus, OPC UA, S7 |
| **Pharmaceutical** | OPC UA, Modbus, S7, EtherNet/IP |
| **Data Centers** | SNMP, Modbus, BACnet |

---

## Web IDE

GOPLC includes a full-featured browser-based IDE:

<p align="center">
  <img src="assets/screenshots/ide-features.png" alt="IDE Features" width="800">
</p>

### IDE Features

- **Monaco Editor** with ST syntax highlighting
- **Project Tree** showing tasks, programs, functions, libraries
- **Live Variable Watch** with real-time updates via WebSocket
- **Runtime Control** - Start/Stop/Reset/Upload/Download
- **Project Management** - New/Open/Save/Export/Import
- **Task Configuration** - Priorities, scan times, watchdogs
- **Multi-Runtime Switch** - Connect to different PLC instances
- **Sync Indicator** - Shows if IDE matches runtime code
- **AI Assistant** - Claude-powered ST code generation

---

## Quick Start

### Run with Docker

```bash
docker run -d --name goplc \
  -p 8082:8082 \
  -p 502:502 \
  -v $(pwd)/configs:/app/configs \
  -v $(pwd)/projects:/app/projects \
  goplc:latest --config /app/configs/default.yaml
```

### Access the Web IDE

Open `http://localhost:8082/ide/` in your browser.

### Configuration Example

```yaml
# config.yaml
runtime:
  log_level: info

tasks:
  - name: FastTask
    type: periodic
    scan_time_us: 100      # 100 microsecond scan
    priority: 1
    watchdog_ms: 10
    programs:
      - fast_control.st

  - name: SlowTask
    type: periodic
    scan_time_ms: 100      # 100ms scan
    priority: 10
    programs:
      - monitoring.st

protocols:
  modbus:
    enabled: true
    port: 502
  opcua:
    enabled: true
    port: 4840

api:
  port: 8082
```

---

## Examples

### Structured Text Programs

See the [`examples/st/`](examples/st/) directory for sample programs:

| Example | Description |
|---------|-------------|
| [`modbus_gateway.st`](examples/st/modbus_gateway.st) | Bridge between Modbus devices |
| [`data_sync.st`](examples/st/data_sync.st) | Multi-PLC data synchronization |
| [`esp32_io.st`](examples/st/esp32_io.st) | ESP32 remote I/O control |
| [`pid_control.st`](examples/st/pid_control.st) | PID loop with anti-windup |
| [`alarm_handler.st`](examples/st/alarm_handler.st) | Alarm management system |

### Configuration Examples

See the [`examples/configs/`](examples/configs/) directory:

| Config | Description |
|--------|-------------|
| [`modbus_server.yaml`](examples/configs/modbus_server.yaml) | Modbus TCP server with I/O mapping |
| [`multi_plc.yaml`](examples/configs/multi_plc.yaml) | DataLayer sync between PLCs |
| [`realtime.yaml`](examples/configs/realtime.yaml) | Real-time container mode |
| [`full_stack.yaml`](examples/configs/full_stack.yaml) | All protocols enabled |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GOPLC Runtime                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  Fast Task  │  │ Medium Task │  │  Slow Task  │  │  Event Task │        │
│  │   100μs     │  │    1ms      │  │   100ms     │  │  On-demand  │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                │                │
│         └────────────────┴────────────────┴────────────────┘                │
│                                  │                                           │
│                    ┌─────────────▼─────────────┐                            │
│                    │     Task Scheduler        │                            │
│                    │  (Priority-based, Co-op)  │                            │
│                    └─────────────┬─────────────┘                            │
│                                  │                                           │
│  ┌───────────────────────────────┼───────────────────────────────┐          │
│  │                          Core Engine                          │          │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐          │          │
│  │  │ Parser  │  │  Eval   │  │ I/O Mem │  │ Globals │          │          │
│  │  │  (ST)   │  │  (AST)  │  │ (IEC)   │  │ (Vars)  │          │          │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘          │          │
│  └───────────────────────────────┬───────────────────────────────┘          │
│                                  │                                           │
├──────────────────────────────────┼──────────────────────────────────────────┤
│                            Protocol Layer                                    │
│                                                                              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│  │ Modbus  │ │ EIP/CIP │ │ OPC UA  │ │  DNP3   │ │ BACnet  │ │  FINS   │  │
│  │TCP/RTU  │ │Adpt/Scan│ │Srv/Cli  │ │Mst/Out  │ │IP/MSTP  │ │ Client  │  │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘  │
│       │          │          │          │          │          │            │
├───────┴──────────┴──────────┴──────────┴──────────┴──────────┴────────────┤
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  DataLayer  │  │    MQTT     │  │  REST API   │  │  WebSocket  │        │
│  │ TCP/SHM     │  │  Pub/Sub    │  │ + Web IDE   │  │  Streaming  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Multi-PLC Clustering

```
                    ┌─────────────────┐
                    │   Boss Node     │
                    │  (Coordinator)  │
                    │   TCP :8082     │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
     ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
     │  Minion 1   │  │  Minion 2   │  │  Minion 3   │
     │  (Unix Sock)│  │  (Unix Sock)│  │  (Unix Sock)│
     │  Area A     │  │  Area B     │  │  Area C     │
     └─────────────┘  └─────────────┘  └─────────────┘
```

---

## Performance

### Live Multi-PLC Benchmark (January 2026)

3 GOPLC instances running simultaneously with DataLayer synchronization:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CLUSTER: 3 PLCs │ 9 Tasks │ 27 Programs │ 13,400+ Lines ST Code        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  PLC1 (DataLayer Server)              Memory: ~100 MB                   │
│  ├── FastTask    (10ms)  avg: 0.77ms  ██████████████░░░░░░░  77% margin │
│  ├── MediumTask  (50ms)  avg: 0.16ms  ██░░░░░░░░░░░░░░░░░░░  99% margin │
│  └── SlowTask   (100ms)  avg: 0.12ms  █░░░░░░░░░░░░░░░░░░░░  99% margin │
│                                                                          │
│  PLC2 (DataLayer Client)              Memory: ~143 MB                   │
│  ├── FastTask    (10ms)  avg: 0.58ms  ██████████░░░░░░░░░░░  94% margin │
│  ├── MediumTask  (50ms)  avg: 0.17ms  ██░░░░░░░░░░░░░░░░░░░  99% margin │
│  └── SlowTask   (100ms)  avg: 0.12ms  █░░░░░░░░░░░░░░░░░░░░  99% margin │
│                                                                          │
│  PLC3 (DataLayer Client)              Memory: ~147 MB                   │
│  ├── FastTask    (10ms)  avg: 0.48ms  ████████░░░░░░░░░░░░░  95% margin │
│  ├── MediumTask  (50ms)  avg: 0.16ms  ██░░░░░░░░░░░░░░░░░░░  99% margin │
│  └── SlowTask   (100ms)  avg: 0.12ms  █░░░░░░░░░░░░░░░░░░░░  99% margin │
│                                                                          │
│  All tasks: 0 faults │ Sub-millisecond avg scan times                   │
└─────────────────────────────────────────────────────────────────────────┘
```

**Test Configuration:**
- 3 PLCs with DataLayer TCP sync (server + 2 clients)
- 9 programs per PLC: math, arrays, strings, JSON, datetime, regex, crypto, datastructures
- Each PLC running ~4,500 lines of Structured Text
- Modbus TCP servers on each PLC (ports 5601-5603)
- Real-time variable synchronization across all nodes

### Modbus Stress Test (January 2026)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  MODBUS TCP BENCHMARK                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Server: GOPLC Modbus TCP with 100 dynamic registers                    │
│  Clients: 100 concurrent connections                                     │
│  Operations: 100-register reads + single-register writes                 │
│  Requests: 400,000 total (2,000 per client)                             │
│                                                                          │
│  Throughput:  89,769 requests/second                                    │
│  Latency:     0.01ms average response time                              │
│  Errors:      0 failed transactions                                     │
│  Data:        Dynamic sin/cos wave values (changes every 10ms)          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Modbus Scalability Test - 500 Servers (January 2026)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  MODBUS TCP SCALABILITY: 500 SERVERS + 500 CLIENTS                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SERVER PLC (500 Modbus TCP servers on ports 7000-7499)                 │
│  ├── Servers:      500 concurrent Modbus TCP listeners                  │
│  ├── Registers:    100 per server (shared %QW0-99)                      │
│  ├── Avg Scan:     0.58ms (generating sin/cos waveforms)                │
│  ├── Scans:        36,000+ completed                                    │
│  └── Errors:       0                                                    │
│                                                                          │
│  CLIENT PLC (500 Modbus TCP clients with PTR_QW pointer writes)         │
│  ├── Clients:      500 concurrent connections                           │
│  ├── Writes/scan:  50,000 registers via PTR_QW pointer arithmetic       │
│  ├── Avg Scan:     167ms (50K SIN calculations + pointer writes)        │
│  ├── Scans:        2,000+ completed                                     │
│  └── Errors:       0                                                    │
│                                                                          │
│  PTR_QW POINTER PERFORMANCE (isolated benchmark):                       │
│  ├── Direct %QW (unrolled):    1.24 µs/write                            │
│  ├── PTR_QW (loop):            1.52 µs/write                            │
│  ├── Array indexing (loop):    1.61 µs/write                            │
│  └── Overhead:                 ~22% vs direct (includes loop)           │
│                                                                          │
│  Effective Rate: ~300,000 register writes/second                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**PTR_QW Feature:** New system constants for pointer arithmetic with I/O memory:
- `PTR_QW` - Base pointer for output words (%QW)
- `PTR_IW` - Base pointer for input words (%IW)
- `PTR_MW` - Base pointer for marker words (%MW)

Enables efficient bulk I/O operations: `(PTR_QW + offset)^ := value`

### Modbus Scalability Test - 5000 Servers (January 2026)

<p align="center">
  <img src="assets/benchmark-5000-servers.svg" alt="5000 Server Benchmark" width="700">
</p>

**Configuration:**
- 5000 concurrent Modbus TCP servers on ports 7000-11999
- ST program: Counter + GSV_TASKSCANTIME() writing to %QW0-1
- All servers receive same PLC outputs via driver broadcast

**Results:**
| Metric | Value |
|--------|-------|
| Scan Execution Time | 20-50µs (avg 30µs) |
| Memory Usage | 780 MB (~156 KB/server) |
| CPU Usage | 50% |
| Stability | 12+ minutes, 0 errors |

<p align="center">
  <img src="assets/scan-time-distribution.svg" alt="Scan Time Distribution" width="550">
</p>

**Driver Broadcast Architecture:**

<p align="center">
  <img src="assets/architecture-driver-broadcast.svg" alt="Driver Broadcast" width="700">
</p>

### Benchmarks

| Metric | Result |
|--------|--------|
| **Scan execution time** | 20-50μs (5000 servers) |
| **Minimum scan interval** | 100μs sustained |
| **Modbus throughput** | 89,769 req/sec (100 connections) |
| **Modbus scalability** | 5000 servers (780 MB), 500 clients (0 errors) |
| **PTR_QW writes** | ~300,000 registers/sec |
| **DataLayer latency** | <1ms P50, <3ms P99 |
| **Memory footprint** | ~65MB typical, ~150MB with DataLayer |
| **ST functions** | 1,450+ available |
| **Lines of code** | 160,000+ Go |

### Latency Distribution (2ms scan, DataLayer TCP)

```
Direction       │ Avg    │ P50    │ P95    │ P99    │ Max
────────────────┼────────┼────────┼────────┼────────┼────────
Client→Server   │ 1.04ms │ 1.26ms │ 2.82ms │ 3.08ms │ 3.30ms
Server→Client   │ 1.08ms │ 1.29ms │ 2.76ms │ 3.14ms │ 5.08ms
```

---

## REST API

Full REST API for integration with SCADA, MES, and custom applications.

### Key Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/tags` | List all tags with values |
| `GET/PUT /api/variables/:name` | Read/write variables |
| `POST /api/runtime/start` | Start PLC runtime |
| `POST /api/runtime/stop` | Stop PLC runtime |
| `GET /api/diagnostics` | Full runtime diagnostics |
| `GET /api/analyzer/transactions` | Protocol capture data |
| `GET /ws` | WebSocket for real-time updates |

See [`docs/API.md`](docs/API.md) for complete API reference.

---

## Use Cases

GOPLC is designed for:

- **Industrial Automation** - Replace or supplement traditional PLCs
- **Protocol Gateway** - Bridge between different protocols
- **Edge Computing** - Run on Raspberry Pi, industrial PCs
- **Simulation** - Test automation logic without hardware
- **Education** - Learn PLC programming with modern tools
- **SCADA Backend** - High-performance data collection

---

## License

GOPLC is proprietary software. Contact for licensing inquiries.

---

<p align="center">
  <strong>Built with Go</strong><br>
  <em>Industrial-grade automation for the modern world</em>
</p>
