# GoPLC MCP Server Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.540

---

## 1. Overview

GoPLC includes a built-in **MCP (Model Context Protocol) server** that gives AI assistants like Claude Code, Cursor, Windsurf, and other MCP-compatible tools direct access to all PLC functionality. With 80 tools covering programs, tasks, variables, HMI, debugging, protocol analysis, fleet management, and more — an AI assistant can build, deploy, and debug complete PLC applications without touching the IDE.

The MCP server is built into the GoPLC binary. No external dependencies, no separate installation, no Node.js required.

### What Can an AI Do With These Tools?

| Capability | Tools Used |
|-----------|-----------|
| Learn the system | `goplc_coding_rules`, `goplc_capabilities`, `goplc_guides`, `goplc_functions` |
| Write and validate ST code | `goplc_functions` (verify), `goplc_program_validate`, `goplc_program_create` |
| Deploy programs | `goplc_deploy` (one-call), or `goplc_program_create` → `goplc_task_set_programs` → `goplc_task_reload` |
| Build HMI dashboards | `goplc_hmi_template`, `goplc_hmi_create`, `goplc_hmi_update` |
| Monitor variables | `goplc_variable_list`, `goplc_variable_get`, `goplc_variable_set`, `goplc_watch_create` |
| Debug programs | `goplc_debug_enable`, `goplc_debug_set_breakpoint`, `goplc_debug_step_over` |
| Analyze protocols | `goplc_analyzer_start`, `goplc_analyzer_transactions`, `goplc_analyzer_decode` |
| Manage fleet | `goplc_fleet_discover`, `goplc_fleet_list` |
| Configure the system | `goplc_config_get`, `goplc_config_update`, `goplc_nodered_status` |

---

## 2. Quick Start

### 2.1 Start GoPLC

```bash
./goplc project.goplc --api-port 8082
```

### 2.2 Add the MCP Server to Claude Code

```bash
claude mcp add goplc -- /path/to/goplc mcp
```

That's it. Next time you start Claude Code, all 80 tools will be available. The MCP server connects to your running GoPLC instance over HTTP.

### 2.3 Add to Other MCP Clients

For any MCP-compatible client, configure a stdio transport:

```json
{
  "mcpServers": {
    "goplc": {
      "command": "/path/to/goplc",
      "args": ["mcp"]
    }
  }
}
```

### 2.4 Authentication

If your GoPLC instance has JWT authentication enabled, set the token as an environment variable:

```bash
export GOPLC_AUTH_TOKEN="your-jwt-token-here"
```

The MCP server reads `GOPLC_AUTH_TOKEN` at runtime and includes it as a Bearer header on every request.

---

## 3. How It Works

The MCP server uses JSON-RPC 2.0 over stdio. It acts as a lightweight HTTP client — translating MCP tool calls into REST API requests against a running GoPLC instance.

```
AI Assistant ──stdio──> ./goplc mcp ──HTTP──> GoPLC runtime (:8082)
```

Every tool accepts `host` and `port` parameters, so a single MCP session can manage multiple GoPLC instances. The `host` parameter supports shorthand: `"45"` expands to `"10.0.0.45"`.

---

## 4. Complete Tool Reference

### 4.1 Documentation & Learning (5 tools)

| Tool | Description |
|------|------------|
| `goplc_coding_rules` | **Read this first.** Mandatory ST coding rules — function verification, code style, GVL patterns, common mistakes. No parameters needed. |
| `goplc_capabilities` | Supported IEC 61131-3 features, data types, and limits |
| `goplc_functions` | Search available ST functions by name or category. **Authoritative source** — if a function isn't returned here, it doesn't exist. Supports `search`, `category`, `limit`, `names_only` filters. |
| `goplc_function_blocks` | List all function blocks (TON, TOF, CTU, PID, etc.) — stateful blocks requiring instance variables |
| `goplc_guides` | Programming guides — GVL, cross-task communication, hardware I/O patterns |

**Example: Search for Modbus functions**
```
goplc_functions(host="localhost", port=8082, search="modbus", limit=10)
```

### 4.2 Programs (7 tools)

| Tool | Description |
|------|------------|
| `goplc_program_list` | List all programs |
| `goplc_program_get` | Get source code and metadata for a program |
| `goplc_program_create` | Create a new program or GVL |
| `goplc_program_update` | Update an existing program's source |
| `goplc_program_delete` | Delete a program |
| `goplc_program_validate` | Validate ST source without saving — catches syntax errors before deploy |
| `goplc_deploy` | **One-call deploy** — validates, creates programs, assigns to task, and reloads. Collects all errors so you can fix them in one pass. |

**Example: Deploy a temperature controller**
```
goplc_deploy(
  host="localhost", port=8082,
  task="MainTask",
  programs=[
    {name: "GVL_Temp", source: "VAR_GLOBAL (GVL_Temp)\n  temp : REAL := 22.5;\n  setpoint : REAL := 25.0;\nEND_VAR"},
    {name: "POU_TempCtrl", source: "PROGRAM POU_TempCtrl\nVAR\n  error : REAL;\nEND_VAR\n  error := GVL_Temp.setpoint - GVL_Temp.temp;\nEND_PROGRAM"}
  ]
)
```

### 4.3 Tasks (8 tools)

| Tool | Description |
|------|------------|
| `goplc_task_list` | List all tasks with scan times, programs, and stats |
| `goplc_task_get` | Get task details (config + runtime state) |
| `goplc_task_create` | Create a new task (cyclic execution container) |
| `goplc_task_update` | Update scan time, priority, or watchdog settings |
| `goplc_task_set_programs` | Set which programs/GVLs run in a task |
| `goplc_task_reload` | Hot-reload a single task without stopping others |
| `goplc_task_start` | Start a specific task |
| `goplc_task_stop` | Stop a specific task |

### 4.4 Variables (5 tools)

| Tool | Description |
|------|------------|
| `goplc_variable_list` | List all variables with current values |
| `goplc_variable_get` | Read a single variable by name |
| `goplc_variable_set` | Write a value to a variable |
| `goplc_variable_bulk_get` | Read multiple variables in one call |
| `goplc_tag_list` | List I/O tags (driver-mapped variables) |

### 4.5 HMI Pages (6 tools)

| Tool | Description |
|------|------------|
| `goplc_hmi_template` | Get a starter HTML template with `goplc-hmi.js` wired up |
| `goplc_hmi_list` | List all HMI pages |
| `goplc_hmi_get` | Get a page's HTML source |
| `goplc_hmi_create` | Create a new HMI page (served at `/hmi/<name>`) |
| `goplc_hmi_update` | Update a page's HTML |
| `goplc_hmi_delete` | Delete a page |

HMI pages are full HTML documents that use the `goplc-hmi.js` helper library:

```javascript
// Include in your HMI page
<script src="/hmi/goplc-hmi.js"></script>

// Read/write variables
goplc.read("GVL_IO.temperature")
goplc.write("GVL_IO.setpoint", 25.0)

// Poll all variables every 500ms
goplc.subscribe(function(vars) {
  // vars = { "program.varname": { value: ..., type: "..." }, ... }
}, 500)

// Poll specific variables
goplc.subscribeTo(["GVL_IO.temp", "GVL_IO.pressure"], callback, 500)

// WebSocket for real-time updates
goplc.connect(function(data) { /* real-time push */ })

// System info
goplc.info()     // version, platform, etc.
goplc.runtime()  // state, uptime, scan time
```

### 4.6 Runtime Control (7 tools)

| Tool | Description |
|------|------------|
| `goplc_runtime_status` | Get runtime state, uptime, scan time |
| `goplc_info` | Get server info (version, platform) |
| `goplc_runtime_start` | Start the runtime — begins executing all tasks |
| `goplc_runtime_stop` | Stop the runtime |
| `goplc_runtime_pause` | Pause execution (can resume) |
| `goplc_runtime_resume` | Resume from pause |
| `goplc_runtime_reload` | Reload all programs without full restart |

### 4.7 Step Debugger (9 tools)

| Tool | Description |
|------|------------|
| `goplc_debug_enable` | Enable the step debugger |
| `goplc_debug_disable` | Disable the step debugger |
| `goplc_debug_state` | Get debugger state — stopped line, call stack, variables |
| `goplc_debug_set_breakpoint` | Set a breakpoint at a program:line |
| `goplc_debug_list_breakpoints` | List all breakpoints |
| `goplc_debug_continue` | Continue to next breakpoint |
| `goplc_debug_step_into` | Step into function/FB call |
| `goplc_debug_step_over` | Step over (execute without entering) |
| `goplc_debug_step_out` | Step out of current function/FB |

**Example: Debug a program**
```
goplc_debug_enable(host="localhost", port=8082)
goplc_debug_set_breakpoint(host="localhost", port=8082, program="POU_Main", line=15)
goplc_debug_continue(host="localhost", port=8082)
goplc_debug_state(host="localhost", port=8082)  // see where it stopped
goplc_debug_step_over(host="localhost", port=8082)
```

### 4.8 Watch Windows (4 tools)

| Tool | Description |
|------|------------|
| `goplc_watch_list` | List all watch windows |
| `goplc_watch_create` | Create a watch window for a set of variables |
| `goplc_watch_get` | Poll current values for a watch window |
| `goplc_watch_delete` | Delete a watch window |

### 4.9 Diagnostics (4 tools)

| Tool | Description |
|------|------------|
| `goplc_faults` | Get active faults and error conditions |
| `goplc_diagnostics` | Get scan times, memory usage, task stats |
| `goplc_logs` | Get recent log entries |
| `goplc_drivers` | List I/O drivers and their connection status |

### 4.10 Integrations (8 tools)

| Tool | Description |
|------|------------|
| `goplc_nodered_status` | Check if Node-RED is running |
| `goplc_nodered_start` | Start Node-RED subprocess |
| `goplc_nodered_stop` | Stop Node-RED |
| `goplc_nodered_restart` | Restart Node-RED |
| `goplc_fuxa_status` | Check if FUXA SCADA is reachable |
| `goplc_config_get` | Get current runtime configuration (YAML) |
| `goplc_config_update` | Update runtime configuration |
| `goplc_config_export` | Export configuration as YAML file |

### 4.11 Libraries (2 tools)

| Tool | Description |
|------|------------|
| `goplc_library_list` | List loaded ST libraries and their functions |
| `goplc_library_get` | Get a library's metadata and source |

### 4.12 Fleet Management (2 tools)

| Tool | Description |
|------|------------|
| `goplc_fleet_discover` | Scan local network for GoPLC instances via mDNS |
| `goplc_fleet_list` | List known fleet nodes (filter by role, tier, family) |

### 4.13 Protocol Analyzer (5 tools)

| Tool | Description |
|------|------------|
| `goplc_analyzer_status` | Get capture status and statistics |
| `goplc_analyzer_start` | Start capturing protocol traffic (filter by protocol, device, direction) |
| `goplc_analyzer_stop` | Stop capture |
| `goplc_analyzer_transactions` | Get captured transactions with decoded fields |
| `goplc_analyzer_decode` | Decode a raw hex packet offline |

**Supported protocols:** Modbus TCP/RTU, FINS TCP/UDP, EtherNet/IP, S7, OPC UA, DNP3, BACnet, SEL

### 4.14 L5X Import/Export (2 tools)

| Tool | Description |
|------|------------|
| `goplc_l5x_import` | Import Rockwell L5X file → ST programs |
| `goplc_l5x_export` | Export ST program → L5X XML for Studio 5000 |

### 4.15 Store-and-Forward (2 tools)

| Tool | Description |
|------|------------|
| `goplc_saf_status` | Get offline buffering stats |
| `goplc_saf_pending` | Get pending messages not yet forwarded |

### 4.16 I/O Mappings (2 tools)

| Tool | Description |
|------|------------|
| `goplc_io_list` | List all I/O point mappings (%IX, %QX, %IW, %QW, %MW) |
| `goplc_io_create` | Create a new I/O point mapping |

### 4.17 Project (2 tools)

| Tool | Description |
|------|------------|
| `goplc_project_save` | Save project to disk |
| `goplc_cluster_status` | Get cluster status for all connected nodes |

---

## 5. Recommended Workflow for AI Assistants

When building a PLC application from scratch, follow this order:

### Step 1: Learn the System
```
goplc_coding_rules()           // Mandatory — learn the rules
goplc_capabilities(host, port) // What data types and features exist
goplc_guides(host, port)       // GVL patterns, cross-task, hardware I/O
```

### Step 2: Search for Functions
```
goplc_functions(host, port, search="modbus")  // Verify EVERY function before using it
goplc_function_blocks(host, port)              // Check available FBs (TON, PID, etc.)
```

### Step 3: Write and Validate Code
```
goplc_program_validate(host, port, source="...")  // Check syntax before deploying
```

### Step 4: Deploy
```
goplc_deploy(host, port, task="MainTask", programs=[...])  // One call does it all
```

### Step 5: Monitor
```
goplc_variable_list(host, port)             // See all variables
goplc_variable_get(host, port, name="...")  // Read specific values
goplc_watch_create(host, port, tags=[...])  // Set up monitoring
```

### Step 6: Build HMI
```
goplc_hmi_template()                                    // Get starter HTML
goplc_hmi_create(host, port, name="dashboard", content="...", title="My Dashboard")
```

### Step 7: Debug (if needed)
```
goplc_debug_enable(host, port)
goplc_debug_set_breakpoint(host, port, program="POU_Main", line=15)
goplc_debug_state(host, port)  // Inspect stopped state
```

---

## 6. Testing the MCP Server

A comprehensive test suite is included:

```bash
# Build the binary
go build -o goplc-dev ./cmd/goplc

# Start a GoPLC instance
./goplc-dev project.goplc --api-port 8082

# Run the test suite (in another terminal)
python3 tests/mcp_test.py

# Run specific test groups
python3 tests/mcp_test.py --group debug,hmi,deploy

# Target a remote instance
python3 tests/mcp_test.py --host 10.0.0.34 --port 8302

# List available test groups
python3 tests/mcp_test.py --list
```

The test suite exercises all 80 tools in 18 groups and typically completes in under 5 seconds.

---

## 7. Troubleshooting

### MCP server not responding
- Ensure the binary is built: `go build -o goplc ./cmd/goplc`
- Test directly: `echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | ./goplc mcp 2>/dev/null`

### Tools return "connection error"
- Ensure a GoPLC instance is running on the target host:port
- Check firewall: `sudo ufw allow 8082/tcp`
- Verify with curl: `curl http://localhost:8082/api/info`

### Authentication errors
- Set `export GOPLC_AUTH_TOKEN="your-token"` before starting the MCP client
- The token is read from the environment on every request

### Tool not found
- Run `tools/list` to see all registered tools
- Ensure you're running the latest binary (check version with `goplc_info`)
