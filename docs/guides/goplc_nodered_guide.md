# GoPLC Node-RED Integration Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC manages Node-RED as an **integrated subprocess** -- not a loosely-coupled external tool. When Node-RED is enabled, GoPLC handles the entire lifecycle: binary detection, settings generation, custom node installation, Dashboard 2.0 provisioning, process supervision with crash recovery, and reverse proxying through a single port. The result is a unified system where PLC logic runs in Structured Text while Node-RED provides visual data flow programming, operator dashboards, and hundreds of community integration nodes.

There are **three communication channels** between GoPLC and Node-RED:

| Channel | Transport | Direction | Best For |
|---------|-----------|-----------|----------|
| **REST API** | HTTP | Request/Response | Reading/writing individual variables, runtime control, task management |
| **WebSocket** | WS | Server-push | Real-time variable subscriptions, on-change filtering |
| **Cluster Proxy** | HTTP (proxied) | Request/Response | Accessing minion nodes through the boss |

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                     │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │ ST Programs  │  │ REST API     │  │ WebSocket Server      │  │
│  │ (scan loop)  │  │ /api/*       │  │ /ws                   │  │
│  └──────────────┘  └──────┬───────┘  └──────────┬────────────┘  │
│                           │                     │               │
│  ┌────────────────────────┴─────────────────────┴────────────┐  │
│  │  Reverse Proxy: /nodered/* → localhost:{ephemeral_port}   │  │
│  └────────────────────────┬──────────────────────────────────┘  │
│                           │                                     │
│  ┌────────────────────────┴──────────────────────────────────┐  │
│  │  Node-RED Process Manager                                 │  │
│  │  - Auto-start, crash recovery, exponential backoff        │  │
│  │  - settings.js generation, custom node installation       │  │
│  │  - Dashboard 2.0 auto-provisioning                        │  │
│  └────────────────────────┬──────────────────────────────────┘  │
└───────────────────────────┼─────────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────────┐
│  Node-RED (managed subprocess, localhost only)                   │
│                                                                 │
│  ┌────────────────────┐  ┌──────────────────────────────────┐   │
│  │  7 Custom GOPLC    │  │  Dashboard 2.0                   │   │
│  │  Nodes (palette)   │  │  (@flowfuse/node-red-dashboard)  │   │
│  │                    │  │                                  │   │
│  │  goplc-connection  │  │  Gauges, Charts, Templates,     │   │
│  │  goplc-read        │  │  Controls, Notifications        │   │
│  │  goplc-write       │  │                                  │   │
│  │  goplc-subscribe   │  │  Access: /nodered/dashboard/     │   │
│  │  goplc-runtime     │  └──────────────────────────────────┘   │
│  │  goplc-task        │                                         │
│  │  goplc-cluster     │  ┌──────────────────────────────────┐   │
│  └────────────────────┘  │  Community Nodes                 │   │
│                          │  node-red-contrib-influxdb        │   │
│                          │  node-red-contrib-modbus          │   │
│                          │  node-red-contrib-s7              │   │
│                          │  node-red-contrib-opcua           │   │
│                          │  ...hundreds more                 │   │
│                          └──────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### URL Map (Single Port)

All services are accessible through the GoPLC API port (default 8082):

| URL | Service |
|-----|---------|
| `http://host:8082/ide/` | GoPLC Web IDE |
| `http://host:8082/api/*` | GoPLC REST API |
| `http://host:8082/nodered/` | Node-RED flow editor |
| `http://host:8082/nodered/dashboard/` | Dashboard 2.0 HMI |
| `http://host:8082/hmi/*` | GoPLC built-in HMI pages |
| `http://host:8082/ws` | WebSocket variable stream |

> **Important:** Node-RED binds to `127.0.0.1` on an ephemeral port. Always access it through the GoPLC reverse proxy at `/nodered/`, never directly.

---

## 2. Configuration and Setup

### 2.1 YAML Configuration

Enable Node-RED by adding a `nodered` section to your GoPLC config file:

```yaml
# Minimal — just enable it
nodered:
  enabled: true

# Full configuration with all options
nodered:
  enabled: true
  port: 1880                          # Preferred port (auto-selects if busy)
  user_dir: data/nodered              # Node-RED user directory (flows, nodes)
  flow_file: flows.json               # Flow file name
  auto_start: true                    # Start when GoPLC starts
  restart_on_crash: true              # Auto-restart on crash
  max_restarts: 5                     # Max restart attempts before giving up
  restart_backoff_ms: 2000            # Initial backoff between restarts (doubles each time)
  # binary_path: /usr/local/bin/node-red  # Auto-detected if omitted
  # credential_secret: "my-secret"    # Encrypt Node-RED credentials (recommended for production)
  # extra_modules:                    # Additional npm packages to install
  #   - node-red-contrib-influxdb
  #   - node-red-contrib-modbus
```

### 2.2 NodeREDConfig Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `false` | Enable Node-RED subprocess management |
| `port` | int | `1880` | Preferred port (ephemeral if unavailable) |
| `user_dir` | string | `data/nodered` | Flows, credentials, installed nodes |
| `flow_file` | string | `flows.json` | Name of the flow file |
| `binary_path` | string | auto-detect | Path to `node-red` binary |
| `auto_start` | bool | `true` (when enabled) | Start Node-RED when GoPLC starts |
| `restart_on_crash` | bool | `true` (when enabled) | Auto-restart with exponential backoff |
| `max_restarts` | int | `5` | Give up after N restart attempts |
| `restart_backoff_ms` | int | `2000` | Initial retry delay (caps at 30s) |
| `extra_modules` | []string | `[]` | Additional npm packages to install at startup |
| `credential_secret` | string | `""` | Encryption key for Node-RED credential store |

### 2.3 CLI Flag

The Node-RED port can also be set via command-line flag:

```bash
goplc --nodered-port 1880
```

All other Node-RED settings are configured through the YAML config file.

### 2.4 Accessing Node-RED

Node-RED binds to `127.0.0.1` on an internal port and is only accessible through the GoPLC reverse proxy:

```
http://<host>:<goplc-port>/nodered/
```

Never connect to Node-RED's internal port directly. The proxy handles path rewriting, CORS, and keeps everything on a single port.

### 2.5 What Happens at Startup

When GoPLC starts with Node-RED enabled:

1. **Binary detection** -- searches PATH, `/usr/bin`, `/usr/local/bin`, `~/.npm-global/bin`
2. **User directory creation** -- ensures `user_dir` exists
3. **settings.js generation** -- writes auto-configured settings (UI port, GOPLC host/port in `functionGlobalContext`, dark theme, disabled projects)
4. **Custom node installation** -- creates `node-red-contrib-goplc` package with all 7 nodes, runs `npm install` for WebSocket dependency
5. **Dashboard 2.0 installation** -- installs `@flowfuse/node-red-dashboard` plus any `extra_modules`
6. **Delayed start** -- waits 2 seconds for GoPLC API to be ready, then launches Node-RED
7. **Reverse proxy activation** -- `/nodered/*` routes to the subprocess, `/dashboard/*` redirects to `/nodered/dashboard/`

### 2.6 Auto-Generated settings.js

GoPLC generates `settings.js` automatically in the user directory. Key settings:

```javascript
module.exports = {
    uiPort: 46583,                    // Ephemeral port, proxied by GoPLC
    uiHost: "127.0.0.1",             // Localhost only -- GoPLC handles external access

    functionGlobalContext: {
        goplcHost: "localhost",       // Available in Function nodes
        goplcPort: 8082              // as global.get('goplcHost')
    },

    functionExternalModules: true,    // Allow require() in Function nodes
    adminAuth: null,                  // Auth handled by GoPLC proxy

    editorTheme: {
        page: { title: "GOPLC Node-RED" },
        projects: { enabled: false }  // Use GoPLC project management
    },

    contextStorage: {
        default: { module: "localfilesystem" }
    }
};
```

> **Note:** Manual edits to `settings.js` will be overwritten when GoPLC restarts. Configure through the YAML config file instead.

---

## 3. The 7 Custom GOPLC Nodes

GoPLC installs the `node-red-contrib-goplc` palette automatically. All nodes appear in the **GOPLC** category (teal color, `#3FADB5`) in the Node-RED editor sidebar.

### 3.1 goplc-connection (Config Node)

A shared configuration node that other GOPLC nodes reference. Provides the GoPLC host and port.

| Property | Default | Description |
|----------|---------|-------------|
| Name | `GOPLC` | Display name in the editor |
| Host | auto-detect | GoPLC hostname (blank = use `functionGlobalContext.goplcHost`) |
| Port | auto-detect | GoPLC API port (blank = use `functionGlobalContext.goplcPort`) |

**When to leave blank:** When Node-RED is managed by GoPLC (the typical case), leave Host and Port empty. The auto-detect reads from `settings.js`, which GoPLC generates with the correct values. Only set explicit values when Node-RED connects to a remote GoPLC instance.

---

### 3.2 goplc-read

Reads one or all PLC variables via the REST API. Triggered by an input message.

| Property | Description |
|----------|-------------|
| Connection | Reference to a `goplc-connection` config node |
| Mode | `single` (one variable) or `all` (all variables) |
| Variable | Variable name (e.g., `temperature`). Can also come from `msg.topic` |

**REST Endpoint:** `GET /api/variables` (all) or `GET /api/variables/{name}` (single)

**Output:**
- Single mode: `msg.payload` = variable value, `msg.variable` = full metadata object
- All mode: `msg.payload` = `{variables: {name: {value, type, ...}, ...}}`

**Status indicator:** Green dot with variable name on success, red ring on error.

```
[inject: 1s] → [goplc-read: temperature] → [gauge: Temperature]
```

---

### 3.3 goplc-write

Writes a value to a PLC variable via the REST API.

| Property | Description |
|----------|-------------|
| Connection | Reference to a `goplc-connection` config node |
| Variable | Target variable name (or use `msg.topic`) |

**REST Endpoint:** `PUT /api/variables/{name}` with `{"value": msg.payload}`

**Input:** `msg.payload` contains the value to write. Variable name comes from the node property or `msg.topic`.

**Output:** Passes through the original message on success.

```
[slider: Setpoint] → [goplc-write: setpoint]
```

---

### 3.4 goplc-subscribe

Subscribes to real-time variable updates via WebSocket. This is a **headless node** (no input) -- it connects automatically and emits messages whenever variables change.

| Property | Default | Description |
|----------|---------|-------------|
| Connection | required | Reference to a `goplc-connection` config node |
| Variables | empty (all) | Comma-separated list of variable names to filter |
| On Change Only | `true` | Only emit when values actually change |
| Reconnect (ms) | `5000` | Reconnect delay after disconnect |

**WebSocket Endpoint:** `ws://{host}:{port}/ws`

**Protocol:** GoPLC broadcasts `{"type": "update", "data": {"var1": val1, "var2": val2, ...}, "timestamp": "..."}` over the WebSocket. The subscribe node:
1. Connects to the WebSocket
2. Filters to the specified variables (or passes all if empty)
3. Applies on-change detection (optional)
4. Emits `{payload: {changed_vars}, topic: "goplc/variables", timestamp: "..."}`

**Status indicators:**
- Yellow ring: connecting
- Green dot: connected
- Red ring: disconnected (auto-reconnects)

```
[goplc-subscribe: temperature, pressure] → [Dashboard gauge]
```

> **When to use subscribe vs. read:** Use `goplc-subscribe` for dashboards and real-time displays. Use `goplc-read` for on-demand queries, logging at specific intervals, or when you only need data in response to an event.

---

### 3.5 goplc-runtime

Controls the GoPLC runtime (start, stop, pause, resume) and reads runtime status.

| Property | Description |
|----------|-------------|
| Connection | Reference to a `goplc-connection` config node |
| Action | `status`, `start`, `stop`, `pause`, or `resume` |

**REST Endpoints:**
- `GET /api/runtime` (status)
- `POST /api/runtime/start`
- `POST /api/runtime/stop`
- `POST /api/runtime/pause`
- `POST /api/runtime/resume`

**Override via message:** Set `msg.action` to override the configured action.

**Output:** `msg.payload` = runtime status JSON, `msg.action` = action that was performed.

```
[button: Stop PLC] → [goplc-runtime: stop] → [notification: "PLC Stopped"]
```

---

### 3.6 goplc-task

Gets task information or controls individual tasks (start, stop, reload).

| Property | Description |
|----------|-------------|
| Connection | Reference to a `goplc-connection` config node |
| Task Name | Target task (empty = list all tasks) |
| Action | `status`, `start`, `stop`, or `reload` |

**REST Endpoints:**
- `GET /api/tasks` (list all)
- `GET /api/tasks/{name}` (single task status)
- `POST /api/tasks/{name}/start`
- `POST /api/tasks/{name}/stop`
- `POST /api/tasks/{name}/reload`

**Override via message:** `msg.task` overrides task name, `msg.action` overrides action.

```
[inject: 5s] → [goplc-task: MainTask status] → [function: check scan time] → [alarm]
```

---

### 3.7 goplc-cluster

Reads from or writes to cluster minions through the boss proxy. This is how Node-RED (running on the boss) interacts with remote GoPLC instances.

| Property | Description |
|----------|-------------|
| Connection | Reference to a `goplc-connection` config node |
| Minion | Minion name (e.g., `minion1`) |
| Mode | `read` or `write` |
| Endpoint | `variables`, `runtime`, `tasks`, or `info` |
| Variable | Variable name (for write mode) |

**REST Endpoint:** `GET/PUT /api/cluster/{member}/api/{endpoint}`

**Override via message:** `msg.member`, `msg.endpoint`, `msg.mode`, `msg.variable`

For write mode, the value comes from `msg.payload`:

```
[inject] → [goplc-cluster: minion1, read, variables] → [debug]
[slider] → [goplc-cluster: minion2, write, variables, setpoint]
```

---

## 4. Variable Read/Write from Node-RED

### 4.1 Using Custom Nodes (Recommended)

The simplest approach uses the GOPLC palette nodes:

**Read a single variable every second:**
```
[inject: repeat 1s] → [goplc-read: temperature] → [debug]
```

**Write a setpoint from a dashboard slider:**
```
[ui-slider: Setpoint] → [goplc-write: setpoint]
```

**Subscribe to real-time changes:**
```
[goplc-subscribe: level, temperature] → [function: split] → [ui-gauge]
```

### 4.2 Using HTTP Request Nodes (Alternative)

For more control, use standard `http request` nodes against the GoPLC REST API:

**Read all variables:**
```
URL:    GET http://localhost:8082/api/variables
Return: a parsed JSON object
```

**Read a single variable:**
```
URL:    GET http://localhost:8082/api/variables/temperature
Return: {"name": "temperature", "type": "REAL", "value": 22.5, ...}
```

**Write a variable:**
```
URL:    PUT http://localhost:8082/api/variables/setpoint
Body:   {"value": 75.0}
Headers: Content-Type: application/json
```

**Bulk read specific variables:**
```
URL:    POST http://localhost:8082/api/variables/bulk
Body:   {"names": ["temperature", "pressure", "level"]}
```

### 4.3 Using Function Nodes with the API

For complex logic, a Function node can call the GoPLC API directly:

```javascript
// Read a variable using the auto-configured connection info
const host = global.get('goplcHost') || 'localhost';
const port = global.get('goplcPort') || 8082;

const http = require('http');
http.get(`http://${host}:${port}/api/variables/temperature`, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
        const data = JSON.parse(body);
        msg.payload = data.value;
        node.send(msg);
    });
});
```

### 4.4 Using WebSocket Nodes (Native)

You can also use the built-in `websocket in` node:

```
Connect to: ws://localhost:8082/ws
```

The WebSocket broadcasts JSON messages:
```json
{
    "type": "update",
    "data": {
        "temperature": 22.5,
        "pressure": 101.3,
        "motor_running": true
    },
    "timestamp": "2026-04-03T10:30:00Z"
}
```

---

## 5. Dashboard 2.0 Integration

GoPLC automatically installs `@flowfuse/node-red-dashboard` (Dashboard 2.0) when Node-RED first starts. Dashboard 2.0 is a Vue.js-based framework that replaces the legacy node-red-dashboard, providing modern responsive layouts suitable for industrial HMI applications.

### 5.1 Accessing the Dashboard

```
http://host:8082/nodered/dashboard/
```

GoPLC also redirects `/dashboard/*` to `/nodered/dashboard/*` for convenience.

### 5.2 Dashboard 2.0 Architecture

Dashboard 2.0 uses a hierarchy:

```
ui-base          → Base config (path, app icon)
  └─ ui-theme    → Colors, fonts, sizing
      └─ ui-page → Individual pages (with icon, layout)
          └─ ui-group → Widget containers
              └─ ui-gauge, ui-chart, ui-slider, etc.
```

### 5.3 Industrial Theme Configuration

GoPLC ships with an industrial dark theme optimized for control room displays:

```json
{
    "type": "ui-theme",
    "name": "Industrial Dark",
    "colors": {
        "surface": "#1a1a2e",
        "primary": "#00d4aa",
        "bgPage": "#0f0f1a",
        "groupBg": "#16213e",
        "groupOutline": "#0f3460"
    },
    "sizes": {
        "pagePadding": "12px",
        "groupGap": "12px",
        "groupBorderRadius": "8px",
        "widgetGap": "6px"
    }
}
```

Customize the CSS globally using a `ui-template` node:

```css
:root {
    --hmi-accent-cyan: #00d4ff;
    --hmi-accent-green: #00ff88;
    --hmi-accent-red: #ff3366;
    --hmi-accent-yellow: #ffcc00;
    --hmi-bg-dark: #0a0a14;
}
```

### 5.4 Dashboard Widget Nodes

Commonly used Dashboard 2.0 widgets for PLC applications:

| Widget | Node Type | Typical Use |
|--------|-----------|-------------|
| Gauge | `ui-gauge` | Process values (temperature, pressure, level) |
| Chart | `ui-chart` | Trend lines over time |
| Slider | `ui-slider` | Setpoint entry |
| Button | `ui-button` | Start/stop commands |
| Switch | `ui-switch` | Manual/auto toggle |
| Text | `ui-text` | Display labels and values |
| Notification | `ui-notification` | Alarm pop-ups |
| Template | `ui-template` | Custom HTML/CSS/Vue components |
| Table | `ui-table` | Alarm lists, tag tables |
| Dropdown | `ui-dropdown` | Mode selection |

---

## 6. Practical Flow Examples

### 6.1 Process Monitor Dashboard

Read PLC variables every second and display on gauges:

```json
[
    {
        "id": "tab-process",
        "type": "tab",
        "label": "Process Monitor"
    },
    {
        "id": "poll-inject",
        "type": "inject",
        "z": "tab-process",
        "name": "1s Poll",
        "repeat": "1",
        "once": true,
        "onceDelay": "1",
        "x": 110,
        "y": 80,
        "wires": [["read-vars"]]
    },
    {
        "id": "read-vars",
        "type": "http request",
        "z": "tab-process",
        "name": "Read Variables",
        "method": "GET",
        "ret": "obj",
        "url": "http://localhost:8082/api/variables",
        "x": 290,
        "y": 80,
        "wires": [["parse-vars"]]
    },
    {
        "id": "parse-vars",
        "type": "function",
        "z": "tab-process",
        "name": "Extract Values",
        "func": "var v = msg.payload.variables || msg.payload;\nvar out = [];\nout.push({topic: 'Temperature', payload: v.temperature || 0});\nout.push({topic: 'Pressure', payload: v.pressure || 0});\nout.push({topic: 'Level', payload: v.level || 0});\nout.push({topic: 'Flow', payload: v.flow_rate || 0});\nreturn [out];",
        "outputs": 1,
        "x": 480,
        "y": 80,
        "wires": [["gauge-temp", "gauge-pressure", "gauge-level", "gauge-flow"]]
    }
]
```

Wire each output to a `ui-gauge` widget configured with appropriate ranges (e.g., Temperature: 0-100 C, Pressure: 0-200 kPa).

### 6.2 Writing Setpoints from Node-RED

Dashboard slider writing to a GoPLC variable:

```
Flow:
  [ui-slider: "Temperature SP" (0-100)] → [goplc-write: setpoint_temp]

Or with rate limiting:
  [ui-slider] → [delay: rate limit 1 msg/s] → [goplc-write: setpoint_temp]
```

Using an HTTP request node for the write:

```json
[
    {
        "id": "write-sp",
        "type": "http request",
        "name": "Write Setpoint",
        "method": "PUT",
        "ret": "obj",
        "url": "http://localhost:8082/api/variables/setpoint_temp",
        "paytoqs": "ignore",
        "headers": [
            {"keyType": "Content-Type", "keyValue": "application/json"}
        ]
    }
]
```

The Function node before the write formats the payload:

```javascript
msg.payload = { value: msg.payload };  // Wrap slider value
msg.headers = { "Content-Type": "application/json" };
return msg;
```

### 6.3 Alarm Notification Flow

Monitor a PLC alarm variable and send notifications:

```
[goplc-subscribe: alarm_active, alarm_high, alarm_low]
  → [function: Check Alarms]
    → [ui-notification: Alarm Banner]
    → [email: operator@plant.com]  (node-red-node-email)
    → [mqtt out: alerts/alarms]
```

The alarm check Function node:

```javascript
var alarms = msg.payload;
var alerts = [];

if (alarms.alarm_active === true) {
    alerts.push({
        severity: "critical",
        text: "ALARM: Process alarm active",
        timestamp: new Date().toISOString()
    });
}
if (alarms.alarm_high === true) {
    alerts.push({
        severity: "warning",
        text: "HIGH: Variable exceeded high limit",
        timestamp: new Date().toISOString()
    });
}

if (alerts.length > 0) {
    msg.payload = alerts;
    msg.topic = "goplc/alarms";
    return msg;
}
return null;  // No alarms, suppress output
```

### 6.4 Data Logging to InfluxDB

Log PLC variables to InfluxDB for historical trending:

```
[goplc-subscribe: temperature, pressure, level, flow_rate]
  → [function: Format for InfluxDB]
    → [influxdb out: plc_data]  (node-red-contrib-influxdb)
```

The formatting Function node:

```javascript
var v = msg.payload;
msg.payload = [];

for (var key in v) {
    msg.payload.push({
        measurement: "process_data",
        tags: { variable: key },
        fields: { value: parseFloat(v[key]) || 0 },
        timestamp: new Date()
    });
}
return msg;
```

### 6.5 Cluster Aggregation Dashboard

Read variables from multiple minions and display on a single dashboard:

```
[inject: 2s]
  ├→ [goplc-cluster: minion1, read, variables] → [function: tag "Site A"]
  ├→ [goplc-cluster: minion2, read, variables] → [function: tag "Site B"]
  └→ [goplc-cluster: minion3, read, variables] → [function: tag "Site C"]
       all three → [join: combine] → [ui-table: Multi-Site Overview]
```

### 6.6 Protocol Bridge (Modbus to Dashboard)

When GoPLC runs protocol servers, Node-RED community nodes can read data through the protocol layer as well as the REST API:

```
[node-red-contrib-modbus: Read Holding Registers]
  → [function: Scale values]
    → [ui-gauge: Motor Speed]

Or via GoPLC REST API (recommended -- same data, simpler):
[goplc-subscribe: motor_speed, motor_current]
  → [ui-gauge]
```

---

## 7. AI-Assisted Flow Generation

GoPLC's built-in AI assistant (Claude, OpenAI, or Ollama) can generate complete Node-RED flows from natural language descriptions.

### 7.1 How It Works

1. Open the **AI** tab in the GoPLC IDE
2. Describe the flow you want in plain English
3. The AI generates a JSON flow wrapped in a ` ```json ``` ` code block
4. Click the **"Import to Node-RED"** button that appears below the response
5. GoPLC merges the new flow with existing flows and deploys via the Node-RED API

### 7.2 What Happens Behind the Scenes

The IDE's `ai.js` module:
1. Detects JSON code blocks in the AI response via `extractBlock(response, 'json')`
2. Shows an "Import to Node-RED" button
3. On click, calls `importNodeREDFlow()` which:
   - Checks if Node-RED is running (offers to start it if not)
   - Parses the new flow JSON
   - Fetches existing flows via `GET /nodered/flows`
   - Merges (appends) the new nodes
   - Deploys via `POST /nodered/flows` with `Node-RED-Deployment-Type: full`
   - Offers to open the Node-RED editor

### 7.3 Example Prompts

| Prompt | Result |
|--------|--------|
| "Create a Node-RED dashboard with gauges for temperature and pressure" | Dashboard 2.0 flow with ui-gauge nodes, polling via HTTP |
| "Build a flow that logs all variables to InfluxDB every 10 seconds" | Inject + HTTP request + InfluxDB out flow |
| "Make an alarm notification flow that emails when temperature exceeds 80" | Subscribe + function + email flow |
| "Create a multi-site dashboard showing data from 4 minions" | Cluster read nodes + join + table/gauge flow |

### 7.4 The AI Also Generates ST Code and HMI Pages

The same AI chat can produce:
- **ST code** -- "Create New Program" / "Insert at Cursor" buttons
- **HMI pages** -- "Preview HMI" / "Save as HMI Page" buttons
- **Node-RED flows** -- "Import to Node-RED" / "Copy Flow JSON" buttons
- **YAML config** -- "Apply Config Snippet" button

All detected automatically from fenced code blocks in the AI response.

---

## 8. Docker Deployment

### 8.1 Standalone (Node-RED Included)

Use `Dockerfile.nodered` which bundles Node.js + Node-RED + GoPLC in a single image:

```bash
docker compose -f docker-compose.nodered.yml up -d
```

**Ports exposed:**
| Port | Service |
|------|---------|
| 8082 | GoPLC API + IDE + Node-RED proxy |
| 1882 (optional) | Direct Node-RED access (can be removed) |
| 5022 | Modbus TCP |
| 4840 | OPC UA |

**Volumes:**
```yaml
volumes:
  - ./data/projects:/app/projects      # GoPLC config and project files
  - ./data/st_code:/app/st_code        # ST source files
  - ./data/nodered:/app/data/nodered   # Node-RED flows, credentials, custom nodes
  - /etc/localtime:/etc/localtime:ro   # Timezone sync
```

### 8.2 Cluster (Boss + Minions)

In a cluster deployment, the **boss** runs the `goplc-nodered` image (with Node-RED), while **minions** run the slim `goplc` image (no Node-RED):

```yaml
# docker-compose.cluster.yml (simplified)
services:
  boss:
    image: goplc-nodered:latest
    ports:
      - "8083:8082"        # All services through one port
    # Node-RED runs on boss, accesses minions via /api/cluster/:name/

  minion1:
    image: goplc:latest    # Slim image, no Node-RED
  minion2:
    image: goplc:latest
  minion3:
    image: goplc:latest
```

Build and deploy:
```bash
docker compose -f docker-compose.cluster.yml build --no-cache
docker compose -f docker-compose.cluster.yml up -d
```

> **Build rule:** Always build through `docker compose`. A standalone `docker build` does NOT update compose-managed images. Similarly, `docker restart` does NOT pick up new images -- you must `down` and `up`.

### 8.3 Dockerfile.nodered Internals

The multi-stage build:
1. **Builder stage** (`golang:1.24-alpine`): compiles GoPLC binary, generates Swagger docs
2. **Runtime stage** (`node:20-alpine`): installs Node-RED globally, copies binary + web assets + libraries, runs as non-root `node` user

```dockerfile
FROM node:20-alpine
RUN npm install -g --unsafe-perm node-red
# ... copy goplc binary, web files, libraries ...
ENV NODERED_ENABLED=true
EXPOSE 8082 1880 502 4840
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget -qO- http://localhost:8082/health || exit 1
ENTRYPOINT ["goplc"]
```

---

## 9. Node-RED Management API

GoPLC exposes 5 API endpoints for managing the Node-RED subprocess:

### 9.1 GET /api/nodered/status

Returns the current state of Node-RED.

**Response:**
```json
{
    "configured": true,
    "running": true,
    "state": "running",
    "pid": 12345,
    "port": 46583,
    "uptime": "2h15m",
    "uptime_seconds": 8100,
    "start_time": "2026-04-03T08:15:00Z",
    "restart_count": 0,
    "last_error": "",
    "binary_path": "/usr/local/bin/node-red",
    "user_dir": "/app/data/nodered"
}
```

**States:** `stopped`, `starting`, `running`, `stopping`, `error`

### 9.2 POST /api/nodered/start

Start the Node-RED subprocess.

### 9.3 POST /api/nodered/stop

Stop Node-RED gracefully (SIGTERM, then SIGKILL after 5 seconds).

### 9.4 POST /api/nodered/restart

Stop then start Node-RED (500ms delay between).

### 9.5 /nodered/* (Reverse Proxy)

All requests to `/nodered/*` are forwarded to the Node-RED subprocess with:
- Path prefix `/nodered` stripped
- `X-Forwarded-Host` and `X-Forwarded-Prefix` headers set
- `Origin` header removed (prevents CORS issues)
- `Location` headers rewritten on redirects

---

## 10. IDE Integration

The GoPLC Web IDE includes a Node-RED section in the **Config** tab:

### 10.1 Status Display

When Node-RED is configured, the Config tab shows:
- **Status badge**: Running (green) / Stopped (red)
- **PID**: Process ID of the Node-RED subprocess
- **Port**: Internal port (informational; always access via proxy)
- **Uptime**: How long Node-RED has been running
- **Restart count**: Number of automatic restarts since last manual start

### 10.2 Controls

- **Start** button: starts Node-RED (disabled when already running)
- **Stop** button: stops Node-RED gracefully
- **Restart** button: full stop + start cycle
- **Open Node-RED** link: opens `/nodered/` in a new tab

The status display polls every 5 seconds while the Config tab is visible and stops polling when you navigate away.

---

## 11. Working with Community Nodes

One of Node-RED's greatest strengths is its ecosystem of 5,000+ community-contributed nodes. Here are the most relevant for PLC integration:

### 11.1 Protocol Integration Nodes

| Package | Protocol | Tested with GoPLC |
|---------|----------|--------------------|
| `node-red-contrib-modbus` | Modbus TCP/RTU | Working -- live dynamic data |
| `node-red-contrib-s7` | Siemens S7 | Protocol OK, NR node needs TSAP tuning |
| `node-red-contrib-opcua` | OPC UA | Security policy mismatch (needs None endpoint) |
| `node-red-contrib-cip-ethernet-ip` | EtherNet/IP | TCP connected, tag reading in progress |
| MQTT (built-in) | MQTT | Working (requires external broker) |

### 11.2 Database and Cloud Nodes

| Package | Purpose |
|---------|---------|
| `node-red-contrib-influxdb` | Time-series logging to InfluxDB |
| `node-red-node-mysql` | MySQL/MariaDB logging |
| `node-red-contrib-postgresql` | PostgreSQL logging |
| `node-red-contrib-aws` | AWS IoT, S3, Lambda |
| `node-red-contrib-azure-iot-hub` | Azure IoT Hub |
| `node-red-contrib-google-cloud` | Google Cloud IoT |

### 11.3 Installing Additional Nodes

**Via the palette manager** (recommended):
1. Open Node-RED at `/nodered/`
2. Menu > Manage Palette > Install tab
3. Search and install

**Via config file** (installed at startup):
```yaml
nodered:
  enabled: true
  extra_modules:
    - node-red-contrib-influxdb
    - node-red-contrib-modbus
    - node-red-node-email
```

---

## 12. GoPLC REST API Quick Reference

These are the most commonly used API endpoints from Node-RED:

### Variables

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/variables` | List all variables with values |
| GET | `/api/variables/{name}` | Read single variable |
| PUT | `/api/variables/{name}` | Write variable (`{"value": ...}`) |
| POST | `/api/variables/bulk` | Bulk read (`{"names": [...]}`) |
| GET | `/api/variables/meta` | List all variables with metadata (type, scope) |

### Runtime

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/runtime` | Runtime status (state, scan time, uptime) |
| POST | `/api/runtime/start` | Start the PLC runtime |
| POST | `/api/runtime/stop` | Stop the PLC runtime |
| POST | `/api/runtime/pause` | Pause execution |
| POST | `/api/runtime/resume` | Resume execution |

### Tasks

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | List all tasks |
| GET | `/api/tasks/{name}` | Task status and performance |
| POST | `/api/tasks/{name}/start` | Start a task |
| POST | `/api/tasks/{name}/stop` | Stop a task |
| POST | `/api/tasks/{name}/reload` | Reload task programs |

### System

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/info` | System information (version, hostname, OS) |
| GET | `/api/stats` | Runtime statistics (memory, goroutines) |
| GET | `/api/faults` | Active faults |
| GET | `/api/diagnostics` | Full diagnostic dump |

### Cluster (Boss Only)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/cluster/members` | List all cluster members |
| GET | `/api/cluster/{name}/api/*` | Proxy to minion API |

---

## 13. Example ST Program for Node-RED Testing

This Structured Text program generates simulated process data with realistic dynamics -- useful for testing Node-RED dashboards without physical I/O:

```iecst
PROGRAM PRG_DriverTest
VAR
    tick : DINT := 0;
    sine_wave : REAL := 0.0;
    cosine_wave : REAL := 0.0;
    ramp : REAL := 0.0;
    ramp_dir : BOOL := TRUE;
    temperature : REAL := 22.5;
    pressure : REAL := 101.3;
    flow_rate : REAL := 50.0;
    level : REAL := 75.0;
    motor_running : BOOL := FALSE;
    alarm_active : BOOL := FALSE;
    setpoint : REAL := 100.0;
    valve_pos : REAL := 50.0;
    speed_rpm : DINT := 1750;
    power_kw : REAL := 15.5;
END_VAR

    tick := tick + 1;

    (* Generate wave signals *)
    sine_wave := SIN(DINT_TO_REAL(tick) * 0.0628318);
    cosine_wave := COS(DINT_TO_REAL(tick) * 0.0628318);

    (* Ramp generator *)
    IF ramp_dir THEN
        ramp := ramp + 0.5;
        IF ramp >= 100.0 THEN ramp_dir := FALSE; END_IF;
    ELSE
        ramp := ramp - 0.5;
        IF ramp <= 0.0 THEN ramp_dir := TRUE; END_IF;
    END_IF;

    (* Simulated process values *)
    temperature := 22.5 + sine_wave * 3.0;
    pressure := 101.3 + cosine_wave * 5.0;
    flow_rate := 50.0 + ramp * 0.5;
    level := 75.0 + sine_wave * 10.0;
    power_kw := 15.5 + ABS(cosine_wave) * 4.0;
    speed_rpm := 1750 + REAL_TO_DINT(sine_wave * 50.0);
    valve_pos := ramp;
    motor_running := (tick MOD 50) < 25;
    alarm_active := temperature > 24.5;

END_PROGRAM
```

All variables declared in this program are automatically available through the REST API and WebSocket -- no additional mapping required.

---

## 14. Troubleshooting

### Node-RED won't start

```bash
# Check GoPLC logs for Node-RED output
GET /api/nodered/status
# Look at last_error field

# Common causes:
# - node-red binary not found → npm install -g node-red
# - Port conflict → GoPLC auto-selects ephemeral port; check logs
# - npm install failure → check network connectivity (catalogue.nodered.org)
```

### Custom nodes not appearing

The `node-red-contrib-goplc` package is generated in `{user_dir}/node_modules/node-red-contrib-goplc/`. If nodes are missing:
1. Stop Node-RED via the API
2. Delete `{user_dir}/node_modules/node-red-contrib-goplc/`
3. Start Node-RED -- GoPLC will regenerate the nodes

### Dashboard 2.0 gauges show as text on ARM

On some ARM devices (e.g., ctrlX CORE X3), Dashboard 2.0 gauge rendering may fall back to text. Dashboard 1.0 works correctly on those platforms.

### WebSocket subscribe node disconnects

- Check that GoPLC is running and the WebSocket endpoint (`/ws`) is accessible
- Increase the reconnect interval if the network is unreliable
- The subscribe node auto-reconnects with the configured interval

### Flows not persisting across restarts

Ensure the `user_dir` volume is mounted correctly in Docker:
```yaml
volumes:
  - ./data/nodered:/app/data/nodered
```

### "Node-RED is not running" when accessing /nodered/

The reverse proxy returns HTTP 503 if Node-RED is down. Start it via:
```
POST /api/nodered/start
```
Or from the IDE Config tab.

---

## 15. Best Practices

1. **Use goplc-subscribe for dashboards** -- WebSocket updates are more efficient than polling the REST API every second.

2. **Rate-limit writes** -- If a dashboard slider is connected to `goplc-write`, add a `delay` node set to rate-limit mode (e.g., 1 msg/sec) to avoid flooding the PLC.

3. **Named GVLs for shared data** -- When multiple PLC tasks produce data for Node-RED, use named Global Variable Lists:
   ```iecst
   VAR_GLOBAL (GVL_ProcessData)
       temperature : REAL;
       pressure : REAL;
   END_VAR
   ```

4. **Let GoPLC manage Node-RED** -- Don't start Node-RED manually or via systemd. Let GoPLC handle the lifecycle for proper crash recovery and settings generation.

5. **Access through the proxy** -- Always use `http://host:8082/nodered/`, not direct port access. The proxy handles path rewriting, CORS, and authentication.

6. **Use extra_modules for production** -- Rather than installing packages manually through the Palette Manager, list them in `extra_modules` so they survive container rebuilds.

7. **Keep flows in version control** -- Export flows from Node-RED (Menu > Export > All Flows) and save the JSON alongside your `.goplc` project files.

8. **Use the AI to bootstrap** -- Ask the AI assistant to generate a starter flow, then customize in the Node-RED editor. It is faster than building from scratch.
