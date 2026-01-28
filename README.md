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

GOPLC includes industrial-grade protocol drivers for seamless integration with existing automation systems.

### Industrial Protocols

| Protocol | Role | Features |
|----------|------|----------|
| **Modbus TCP/RTU** | Server + Client | Coils, registers, RS-485, diagnostics |
| **EtherNet/IP** | Adapter + Scanner | CIP messaging, I/O assemblies |
| **OPC UA** | Server + Client | Browse, read, write, subscriptions |
| **DNP3** | Master + Outstation | Events, unsolicited, SBO, serial |
| **BACnet/IP** | Client | COV, schedules, priority arrays, alarms |
| **BACnet/MSTP** | Client | RS-485 serial, token passing |
| **FINS** | Client | Omron PLC communication |
| **S7** | Client | Siemens S7 protocol |
| **DF1** | Client | Allen-Bradley legacy (SLC 500, MicroLogix) |

### Communication

| Feature | Description |
|---------|-------------|
| **DataLayer** | TCP or shared memory sync between PLCs |
| **MQTT** | Publish variables, receive commands |
| **HTTP/REST** | Full REST API + WebSocket streaming |
| **Store-and-Forward** | SQLite buffer with compression & encryption |

### Protocol Analyzer

Built-in packet capture and analysis for debugging:

```bash
# Start capture
curl -X POST http://localhost:8082/api/analyzer/start

# Export to Wireshark
curl http://localhost:8082/api/analyzer/export/pcap -o capture.pcap

# Decode raw packet
curl -X POST http://localhost:8082/api/analyzer/decode \
  -d '{"protocol":"modbus-tcp","raw_hex":"00 01 00 00 00 06 01 03 00 00 00 0A"}'
```

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

### Benchmarks

| Metric | Result |
|--------|--------|
| **Minimum scan time** | 100μs sustained |
| **Modbus throughput** | 73,000 req/sec (50 connections) |
| **DataLayer latency** | <1ms P50, <3ms P99 |
| **Memory footprint** | ~65MB typical |
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
