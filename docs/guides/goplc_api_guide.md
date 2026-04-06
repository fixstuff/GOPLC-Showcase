# GoPLC REST API & Swagger Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC exposes **254 REST API endpoints** for full control of the PLC runtime — programs, tasks, variables, protocols, diagnostics, clustering, fleet management, and more. Every operation available in the IDE is also available via HTTP.

### Access Points

| URL | Service |
|-----|---------|
| `http://host:port/swagger/index.html` | Interactive Swagger UI |
| `http://host:port/api/*` | REST API |
| `ws://host:port/ws` | WebSocket (real-time variable push) |
| `http://host:port/ide/` | Web IDE |
| `http://host:port/nodered/` | Node-RED (if enabled) |

### Swagger UI

Open `http://localhost:8082/swagger/index.html` in a browser. Every endpoint is documented with request/response schemas, parameter descriptions, and a "Try it out" button for live testing.

The Swagger spec is auto-generated from the Go source code annotations and served by the gin-swagger middleware.

---

## 2. API Endpoint Groups

### Programs (10)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/programs` | List all programs |
| POST | `/api/programs` | Create or update program |
| GET | `/api/programs/{name}` | Get program source |
| DELETE | `/api/programs/{name}` | Delete program |
| POST | `/api/programs/{name}/validate` | Syntax check without deploy |
| POST | `/api/programs/reload` | Reload all programs |
| POST | `/api/programs/clear` | Remove all programs |
| GET | `/api/programs/export` | Export all as JSON |
| POST | `/api/programs/import` | Import from JSON |
| GET | `/api/programs/hash` | Current program hash |

### Tasks (9)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | List all tasks with metrics |
| POST | `/api/tasks` | Create task |
| GET | `/api/tasks/{name}` | Task detail + scan stats |
| PUT | `/api/tasks/{name}` | Update task config |
| DELETE | `/api/tasks/{name}` | Delete task |
| POST | `/api/tasks/{name}/start` | Start task |
| POST | `/api/tasks/{name}/stop` | Stop task |
| POST | `/api/tasks/{name}/reload` | Reload task programs |
| POST | `/api/tasks/{name}/download` | Download task project |

### Variables (5)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/variables` | List all variables with values |
| GET | `/api/variables/{name}` | Read single variable |
| PUT | `/api/variables/{name}` | Write variable (`{"value": ...}`) |
| POST | `/api/variables/bulk` | Bulk read (`{"names": [...]}`) |
| GET | `/api/variables/meta` | List variables with metadata |

### Runtime (10)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/runtime` | Runtime status |
| GET | `/api/runtime/status` | Detailed status |
| POST | `/api/runtime/start` | Start runtime |
| POST | `/api/runtime/stop` | Stop runtime |
| POST | `/api/runtime/pause` | Pause execution |
| POST | `/api/runtime/resume` | Resume execution |
| POST | `/api/runtime/restart` | Stop + reload + start |
| GET | `/api/runtime/download` | Download project as .goplc |
| POST | `/api/runtime/upload` | Upload and apply .goplc |
| GET | `/api/runtime/scan-stats` | Scan performance metrics |

### System (8)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/info` | Version, hostname, OS, uptime |
| GET | `/api/stats` | Memory, goroutines |
| GET | `/api/diagnostics` | Full diagnostic dump |
| GET | `/api/faults` | Active task faults |
| GET | `/api/capabilities` | Language features and data types |
| POST | `/api/system/shutdown` | Graceful shutdown (SIGTERM) |
| POST | `/api/system/restart` | Re-exec process |
| GET | `/api/health` | Health check (returns 200) |

### AI (5)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/ai/status` | AI availability, provider, model |
| POST | `/api/ai/chat` | Chat with AI assistant |
| POST | `/api/ai/control` | Autonomous tool-calling (blocking) |
| POST | `/api/ai/control/stream` | Autonomous tool-calling (SSE) |
| GET | `/api/ai/capabilities` | System prompt stats |

### HMI (6)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/hmi/pages` | List HMI pages |
| POST | `/api/hmi/pages` | Create HMI page |
| GET | `/api/hmi/pages/{name}` | Get page content |
| PUT | `/api/hmi/pages/{name}` | Update page |
| DELETE | `/api/hmi/pages/{name}` | Delete page |
| GET | `/hmi/{name}` | Serve HMI page to browser |

### Debug (41)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/debug/modules` | List debug modules and levels |
| POST | `/api/debug/level` | Set module log level |
| GET | `/api/debug/buffer` | Read log ring buffer |
| POST | `/api/debug/file` | Enable file logging |
| DELETE | `/api/debug/file` | Disable file logging |
| POST | `/api/debug/db/sqlite` | Enable SQLite logging |
| POST | `/api/debug/db/postgres` | Enable PostgreSQL logging |
| GET | `/api/debug/db/query` | Query log database |
| POST | `/api/debug/influx` | Enable InfluxDB logging |
| GET/POST/DELETE | `/api/debug/step/*` | Statement-level debugger (breakpoints, step, state) |
| ... | ... | (41 total debug endpoints) |

### Cluster (9) + Cluster Ops (10)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/cluster/members` | List cluster members |
| POST | `/api/cluster/enable` | Promote to boss |
| POST | `/api/cluster/disable` | Revert to standalone |
| POST | `/api/cluster/minions` | Spawn minion |
| DELETE | `/api/cluster/minions/{name}` | Remove minion |
| GET | `/api/cluster/dynamic` | Cluster status |
| ANY | `/api/cluster/{name}/*` | Proxy to minion API |
| POST | `/api/cluster-ops/export` | Export cluster bundle |
| POST | `/api/cluster-ops/import` | Import cluster bundle |
| POST | `/api/cluster-ops/reload-all` | Reload all nodes |

### Fleet (16)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/fleet/discover` | mDNS discovery scan |
| GET | `/api/fleet/nodes` | List fleet nodes |
| PUT | `/api/fleet/nodes/{id}` | Add/update node |
| DELETE | `/api/fleet/nodes/{id}` | Remove node |
| POST | `/api/fleet/nodes/{id}/poll` | Poll node |
| POST | `/api/fleet/nodes/{id}/config` | Push config |
| GET | `/api/fleet/nodes/{id}/snapshots` | Node snapshots |
| POST | `/api/fleet/nodes/{id}/push` | Push snapshot |
| POST | `/api/fleet/push-bulk` | Push to multiple nodes |
| GET | `/api/fleet/drift` | Drift detection |
| POST | `/api/fleet/snapshots/collect` | Collect from all nodes |
| POST | `/api/fleet/snapshots/export` | Export snapshots |
| POST | `/api/fleet/snapshots/purge` | Purge old snapshots |
| POST | `/api/fleet/template/render` | Render config template |

### Snapshots (4)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/snapshots` | List snapshots |
| GET | `/api/snapshots/history` | Snapshot history |
| GET | `/api/snapshots/{hash}` | Get specific snapshot |
| DELETE | `/api/snapshots/{hash}` | Delete snapshot |
| POST | `/api/snapshots/{hash}/restore` | Restore from snapshot |

### Protocol Analyzer (9)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/analyzer` | Capture status |
| POST | `/api/analyzer/start` | Start capture |
| POST | `/api/analyzer/stop` | Stop capture |
| GET | `/api/analyzer/transactions` | List captured packets |
| DELETE | `/api/analyzer/transactions` | Clear buffer |
| GET | `/api/analyzer/stats` | Capture statistics |
| POST | `/api/analyzer/decode` | Decode hex packet |
| GET | `/api/analyzer/export/pcap` | Download PCAP |
| GET | `/api/analyzer/protocols` | Supported protocols |

### Store-and-Forward (10)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/storeforward/status` | Queue status |
| POST | `/api/storeforward/store` | Store message |
| POST | `/api/storeforward/forward` | Forward pending |
| GET | `/api/storeforward/pending` | View pending |
| DELETE | `/api/storeforward/clear` | Clear queue |
| GET | `/api/storeforward/stats` | Queue statistics |
| POST | `/api/storeforward/init` | Initialize subsystem |
| POST | `/api/storeforward/close` | Shutdown subsystem |
| POST | `/api/storeforward/online` | Set network state |
| POST | `/api/storeforward/forward-http` | Forward via HTTP |

### Other Groups

| Group | Count | Description |
|-------|-------|-------------|
| `/api/docs/*` | 2 | Function docs and guides |
| `/api/config/*` | 4 | Runtime config read/write |
| `/api/nodered/*` | 4 | Node-RED management (start/stop/restart/status) |
| `/api/license/*` | 5 | License activation and status |
| `/api/libraries/*` | 5 | ST library management |
| `/api/io/*` | 5 | I/O mapping configuration |
| `/api/drivers/*` | 7 | Protocol driver management |
| `/api/serial/*` | 6 | Serial port discovery and management |
| `/api/wizard/*` | 5 | Configuration wizard |
| `/api/project/*` | 7 | Project file management |
| `/api/files/*` | 2 | File upload/download |
| `/api/tags/*` | 3 | Tag browsing |
| `/api/watch/*` | 2 | Variable watch lists |
| `/api/l5x/*` | 3 | Rockwell L5X import/export |
| `/api/logs/*` | 2 | Log ring buffer access |
| `/api/datalayer/*` | 2 | DataLayer status |
| `/api/dl-bridge/*` | 2 | ctrlX Data Layer bridge |
| `/api/pubsub` | 1 | PubSub configuration |
| `/api/agent/deploy` | 1 | AI agent deploy |
| `/api/devices/import-map` | 1 | Device map import |
| `/api/auth/*` | 1 | Authentication status |
| `/api/fuxa/*` | 1 | FUXA SCADA proxy |

---

## 3. Authentication

Authentication is optional. When enabled, all API requests require a Bearer token.

### Get Token

```bash
curl -X POST http://localhost:8082/api/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'
```

Response:

```json
{"token": "eyJhbGciOiJIUzI1NiIs..."}
```

### Use Token

```bash
curl http://localhost:8082/api/variables \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

### Configuration

```yaml
api:
  auth:
    enabled: true
    jwt_secret: ""             # Auto-generated if empty
    token_expiry_hours: 24
    users:
      - username: admin
        password_hash: "$2a$10$..."    # bcrypt hash
```

When auth is disabled (default), all endpoints are accessible without a token.

---

## 4. WebSocket — Real-Time Variables

Connect to `ws://host:port/ws` for real-time variable push updates.

### Connection

```javascript
const ws = new WebSocket('ws://localhost:8082/ws');

ws.onopen = () => {
    // Subscribe to specific variables
    ws.send(JSON.stringify({
        subscribe: ['temperature', 'pressure', 'motor_running']
    }));
};
```

### Server Messages

**Connected:**
```json
{
    "type": "connected",
    "client_id": "ws-001",
    "message": "Send {\"subscribe\": [\"var1\"]} to subscribe"
}
```

**Subscribed confirmation:**
```json
{"type": "subscribed", "tags": ["temperature", "pressure"], "timestamp": "..."}
```

**Variable updates (every 100ms default):**
```json
{
    "type": "update",
    "data": {
        "temperature": 72.5,
        "pressure": 45.3,
        "motor_running": true
    },
    "timestamp": "2026-04-05T10:30:00Z"
}
```

### Client Commands

| Command | Example | Description |
|---------|---------|-------------|
| Subscribe | `{"subscribe": ["var1", "var2"]}` | Add variable subscriptions |
| Unsubscribe | `{"unsubscribe": ["var1"]}` | Remove subscriptions |

Broadcast interval is configurable via `api.broadcast_interval` in config (default: 100ms).

---

## 5. Common Patterns

### Read and Write Variables

```bash
# Read all variables
curl http://localhost:8082/api/variables

# Read single variable
curl http://localhost:8082/api/variables/temperature

# Write a variable
curl -X PUT http://localhost:8082/api/variables/setpoint \
  -H "Content-Type: application/json" \
  -d '{"value": 75.0}'

# Bulk read
curl -X POST http://localhost:8082/api/variables/bulk \
  -H "Content-Type: application/json" \
  -d '{"names": ["temperature", "pressure", "flow"]}'
```

### Deploy a Program

```bash
# Upload ST code
curl -X POST http://localhost:8082/api/programs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "POU_Control",
    "source": "PROGRAM POU_Control\nVAR\n  counter : INT := 0;\nEND_VAR\n  counter := counter + 1;\nEND_PROGRAM"
  }'

# Reload and start
curl -X POST http://localhost:8082/api/programs/reload
curl -X POST http://localhost:8082/api/runtime/start
```

### Download / Upload Project

```bash
# Download current project
curl http://localhost:8082/api/runtime/download -o project.goplc

# Upload project
curl -X POST http://localhost:8082/api/runtime/upload \
  -F "file=@project.goplc"
```

### Check Health

```bash
# Simple health check (returns 200 if running)
curl http://localhost:8082/api/health

# Full diagnostics
curl http://localhost:8082/api/diagnostics
```

---

## 6. Response Formats

### Success

```json
{"status": "ok", "message": "Program created"}
```

### Error

```json
{"error": "Program not found: POU_Missing"}
```

### Variable

```json
{
    "name": "temperature",
    "type": "REAL",
    "value": 72.5,
    "scope": "global"
}
```

### Task

```json
{
    "name": "MainTask",
    "state": "running",
    "priority": 1,
    "scan_time_ms": 50,
    "scan_count": 123456,
    "last_scan_us": 45,
    "avg_scan_us": 42,
    "max_scan_us": 312,
    "faulted": false,
    "watchdog_trips": 0
}
```

### Runtime Info

```json
{
    "version": "1.0.535",
    "hostname": "goplc-plant1",
    "os": "linux",
    "arch": "amd64",
    "uptime_seconds": 86400,
    "state": "Running"
}
```

---

## Appendix A: Endpoint Count by Group

| Group | Count |
|-------|-------|
| Debug | 41 |
| Fleet | 16 |
| Store-Forward | 10 |
| Runtime | 10 |
| Programs | 10 |
| Cluster Ops | 10 |
| Tasks | 9 |
| Cluster | 9 |
| Analyzer | 9 |
| System | 8 |
| Project | 7 |
| Drivers | 7 |
| Serial | 6 |
| HMI | 6 |
| Wizard | 5 |
| Variables | 5 |
| License | 5 |
| Libraries | 5 |
| I/O | 5 |
| AI | 5 |
| Snapshots | 5 |
| Config | 4 |
| Node-RED | 4 |
| Tags | 3 |
| L5X | 3 |
| All others | 21 |
| **Total** | **254** |

---

*GoPLC v1.0.535 | 254 REST Endpoints | Swagger UI | WebSocket Real-Time*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
