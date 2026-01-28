# GOPLC REST API Reference

## Overview

GOPLC exposes a comprehensive REST API for integration with SCADA, MES, and custom applications. The API is available at `http://<host>:<port>/api/`.

**Base URL:** `http://localhost:8082/api/`

## Authentication

Currently, the API does not require authentication. For production deployments, use a reverse proxy with authentication.

---

## Runtime Control

### Start Runtime
```http
POST /api/runtime/start
```
Starts the PLC runtime and all configured tasks.

**Response:**
```json
{
  "status": "running",
  "tasks_started": 3
}
```

### Stop Runtime
```http
POST /api/runtime/stop
```
Stops all tasks and the runtime.

### Reset Runtime
```http
POST /api/runtime/reset
```
Resets all variables to initial values.

### Hot Reload
```http
POST /api/runtime/reload
```
Reloads programs without stopping the runtime (bumpless transfer).

---

## Variables & Tags

### List All Variables
```http
GET /api/variables
```

**Response:**
```json
{
  "variables": {
    "Temperature": {"value": 25.5, "type": "REAL"},
    "Pressure": {"value": 101.3, "type": "REAL"},
    "PumpRunning": {"value": true, "type": "BOOL"}
  }
}
```

### Read Variable
```http
GET /api/variables/:name
```

**Example:**
```bash
curl http://localhost:8082/api/variables/Temperature
```

**Response:**
```json
{
  "name": "Temperature",
  "value": 25.5,
  "type": "REAL"
}
```

### Write Variable
```http
PUT /api/variables/:name
Content-Type: application/json

{
  "value": 30.0
}
```

### List All Tags (Modbus-mapped)
```http
GET /api/tags
```

Returns all tags with their current values and Modbus addresses.

---

## Tasks & Programs

### List Tasks
```http
GET /api/tasks
```

**Response:**
```json
{
  "tasks": [
    {
      "name": "FastTask",
      "type": "periodic",
      "scan_time_us": 100,
      "priority": 1,
      "status": "running",
      "programs": ["motion_control.st"]
    },
    {
      "name": "SlowTask",
      "type": "periodic",
      "scan_time_ms": 100,
      "priority": 10,
      "status": "running",
      "programs": ["monitoring.st"]
    }
  ]
}
```

### Get Task Details
```http
GET /api/tasks/:name
```

### Create Task
```http
POST /api/tasks
Content-Type: application/json

{
  "name": "NewTask",
  "type": "periodic",
  "scan_time_ms": 50,
  "priority": 5,
  "watchdog_ms": 250
}
```

### Assign Programs to Task
```http
PUT /api/tasks/:name/programs
Content-Type: application/json

{
  "programs": ["program1.st", "program2.st"]
}
```

### List Programs
```http
GET /api/programs
```

### Upload Program
```http
POST /api/programs
Content-Type: application/json

{
  "name": "MyProgram",
  "source": "PROGRAM MyProgram\nVAR\n  x : INT;\nEND_VAR\nx := x + 1;\nEND_PROGRAM"
}
```

### Validate ST Code
```http
POST /api/programs/validate
Content-Type: application/json

{
  "source": "PROGRAM Test\nVAR x : INT;\nEND_VAR\nEND_PROGRAM"
}
```

**Response:**
```json
{
  "valid": true,
  "errors": []
}
```

### Deploy Programs
```http
POST /api/programs/reload
```
Applies all program changes to the runtime.

---

## I/O Memory

### Read I/O Memory
```http
GET /api/iomemory
```

**Response:**
```json
{
  "inputs": {
    "%IX0.0": true,
    "%IW0": 1234
  },
  "outputs": {
    "%QX0.0": false,
    "%QW0": 5678
  },
  "memory": {
    "%MW0": 100
  }
}
```

### Write I/O Address
```http
PUT /api/iomemory/%QW0
Content-Type: application/json

{
  "value": 5000
}
```

---

## Diagnostics

### Full Diagnostics
```http
GET /api/diagnostics
```

**Response:**
```json
{
  "runtime": {
    "status": "running",
    "uptime_seconds": 3600,
    "scan_count": 36000000
  },
  "tasks": [...],
  "memory": {
    "heap_mb": 45.2,
    "goroutines": 12
  },
  "protocols": {
    "modbus": {"connections": 3, "requests": 50000},
    "opcua": {"sessions": 1}
  }
}
```

### Runtime Statistics
```http
GET /api/stats
```

### List Faults
```http
GET /api/faults
```

### Clear Task Fault
```http
POST /api/faults/:task/clear
```

### List Capabilities
```http
GET /api/capabilities
```
Returns all available features and their status.

### List ST Functions
```http
GET /api/docs/functions
```
Returns documentation for all 1,450+ built-in functions.

---

## Protocol Analyzer

### Get Analyzer Status
```http
GET /api/analyzer
```

### Start Capture
```http
POST /api/analyzer/start
Content-Type: application/json

{
  "protocols": ["modbus-tcp", "opcua"],
  "max_transactions": 10000
}
```

### Stop Capture
```http
POST /api/analyzer/stop
```

### Get Transactions
```http
GET /api/analyzer/transactions?limit=100&offset=0
```

### Export to PCAP
```http
GET /api/analyzer/export/pcap
```
Returns a PCAP file for Wireshark analysis.

### Decode Raw Packet
```http
POST /api/analyzer/decode
Content-Type: application/json

{
  "protocol": "modbus-tcp",
  "raw_hex": "00 01 00 00 00 06 01 03 00 00 00 0A"
}
```

**Response:**
```json
{
  "protocol": "modbus-tcp",
  "decoded": {
    "transaction_id": 1,
    "unit_id": 1,
    "function": "Read Holding Registers",
    "start_address": 0,
    "quantity": 10
  }
}
```

---

## WebSocket Streaming

### Real-time Variable Updates
```http
WS /ws
```

Connect via WebSocket to receive real-time variable updates.

**Subscribe to variables:**
```json
{"action": "subscribe", "variables": ["Temperature", "Pressure"]}
```

**Receive updates:**
```json
{"variable": "Temperature", "value": 25.6, "timestamp": 1706400000000}
```

---

## Debug System

### Get Debug Log
```http
GET /api/debug/log?module=modbus&limit=100
```

### Set Module Log Level
```http
PUT /api/debug/runtime/modules/modbus
Content-Type: application/json

{
  "level": "debug"
}
```

**Available levels:** `off`, `error`, `warn`, `info`, `debug`, `trace`

### Enable File Logging
```http
POST /api/debug/file
Content-Type: application/json

{
  "path": "/var/log/goplc.log",
  "append": true
}
```

### Enable InfluxDB Logging
```http
POST /api/debug/influx
Content-Type: application/json

{
  "url": "http://influxdb:8086",
  "token": "your-token",
  "org": "your-org",
  "bucket": "goplc-debug"
}
```

---

## Latency Statistics

### Get Latency Stats
```http
GET /api/latency/stats
```

**Response:**
```json
{
  "client_to_server": {
    "samples": 10000,
    "min_us": 10,
    "avg_us": 1040,
    "p50_us": 1263,
    "p95_us": 2815,
    "p99_us": 3078,
    "max_us": 3297
  },
  "server_to_client": {...}
}
```

---

## Cluster API (Boss Mode)

### List Minions
```http
GET /api/cluster/minions
```

### Proxy to Minion
```http
GET /api/cluster/:minion/api/...
```

**Example:**
```bash
curl http://localhost:8082/api/cluster/minion-0/api/variables
```

---

## Error Responses

All errors return JSON with an `error` field:

```json
{
  "error": "Task not found: InvalidTask"
}
```

**HTTP Status Codes:**
- `200` - Success
- `400` - Bad request (invalid parameters)
- `404` - Resource not found
- `500` - Internal server error
