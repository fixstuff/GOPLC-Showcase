# GoPLC Configuration Reference

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Configuration Files

GoPLC uses YAML configuration files. There are two ways to provide configuration:

| Method | Flag | Description |
|--------|------|-------------|
| **YAML config** | `--config config.yaml` | Full configuration file with all settings |
| **Project file** | `goplc project.goplc` | Positional argument — loads programs, tasks, and config from a `.goplc` JSON file |

When both are provided, the `.goplc` project file takes precedence for programs and tasks. The YAML config provides runtime settings, protocol configuration, and service configuration.

### Minimal Config

```yaml
project:
  auto_start: true

runtime:
  log_level: info

tasks:
  - name: MainTask
    type: periodic
    priority: 1
    scan_time_ms: 50
```

This is all you need. Everything else has sensible defaults.

---

## 2. Runtime

```yaml
runtime:
  log_level: info          # off, error, warn, info, debug, trace
  scan_time_ms: 50         # Legacy: single-task scan time (use tasks[] instead)
  st_files:                # Legacy: ST source files (use project file instead)
    - programs/main.st
  libraries:               # Library files to load at startup
    - oscat               # Short name: loads lib/oscat/LIB_Oscat.st
    - /path/to/custom.st  # Full path also works
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `log_level` | string | `info` | Minimum log level |
| `scan_time_ms` | int | `50` | Legacy single-task scan time |
| `st_files` | []string | `[]` | ST source files to load |
| `libraries` | []string | `[]` | Library files or names to load |

---

## 3. Tasks

Tasks are the execution containers. Each task runs one or more programs in a periodic scan loop.

```yaml
tasks:
  - name: MainTask
    type: periodic
    priority: 1
    scan_time_ms: 50
    programs:
      - POU_Control
      - POU_Comms
    watchdog_ms: 200
    watchdog_fault: true
    watchdog_halt: false
    cpu_affinity: -1

  - name: SlowTask
    type: periodic
    priority: 10
    scan_time_ms: 1000
    programs:
      - POU_Logging
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | Unique task name |
| `type` | string | `periodic` | Execution type (`periodic`) |
| `priority` | int | `1` | 1 (highest) to 100 (lowest) |
| `scan_time_ms` | int | `50` | Scan interval in milliseconds (1-60000) |
| `scan_time_us` | int | `0` | Scan interval in microseconds (overrides ms if set) |
| `programs` | []string | `[]` | Ordered list of programs to execute per scan |
| `watchdog_ms` | int | `scan_time_ms * 2` | Maximum allowed scan duration |
| `watchdog_fault` | bool | `false` | Set fault flag on watchdog timeout |
| `watchdog_halt` | bool | `false` | Stop all tasks on watchdog timeout (safety shutdown) |
| `cpu_affinity` | int | `0` | Pin to CPU core (-1 or 0 = no pinning) |

---

## 4. Project

```yaml
project:
  path: projects/my-project.goplc    # Auto-load a project file
  auto_start: true                   # Start runtime after loading
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `path` | string | `""` | Path to `.goplc` project file |
| `auto_start` | bool | `false` | Auto-deploy and start after loading |

---

## 5. Paths

Override default directory locations. Defaults are relative to the working directory or `--data-dir` flag.

```yaml
paths:
  projects: /opt/goplc/projects      # .goplc project files
  st_code: /opt/goplc/st_code        # .st source files
  lib: /opt/goplc/lib                # Libraries (OSCAT, etc.)
  data: /opt/goplc/data              # Persistence, logs, snapshots
```

---

## 6. API

```yaml
api:
  port: 8082                          # HTTP API port
  socket: /var/run/goplc/plc01.sock   # Unix socket (optional, for cluster)
  broadcast_interval: 100             # WebSocket push interval (ms)
  mdns_name: goplc-plant1             # mDNS service name
  mdns_role: gateway                  # Fleet role: gateway, aggregator, simulator, standalone
  mdns_tier: 1                        # Fleet tier: 1=device, 2=family, 3=site
  mdns_family: crac                   # Fleet family tag
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `port` | int | `8080` | API listen port |
| `socket` | string | `""` | Unix domain socket path (cluster member comms) |
| `broadcast_interval` | int | `100` | WebSocket variable broadcast interval (ms) |
| `mdns_name` | string | auto | mDNS instance name (default: hostname-port) |
| `mdns_role` | string | `""` | Fleet discovery role |
| `mdns_tier` | int | `0` | Fleet tier level |
| `mdns_family` | string | `""` | Fleet family grouping |

> **Port flag:** The API port can also be set via command line: `goplc --api-port 8082`. The flag overrides the config file.

### 6.1 Authentication

```yaml
api:
  auth:
    enabled: true
    jwt_secret: ""                    # Auto-generated if empty
    token_expiry_hours: 24
    trust_proxy: false                # Skip auth for reverse-proxied requests
    ctrlx_auth: false                 # Forward to ctrlX identity manager
    ctrlx_url: https://localhost
    users:
      - username: admin
        password_hash: "$2a$10$..."   # bcrypt hash
```

### 6.2 MQTT Publishing

Automatically publish PLC variables to an MQTT broker:

```yaml
api:
  mqtt:
    enabled: true
    broker: tcp://10.0.0.144:1883
    client_id: goplc-runtime
    username: ""
    password: ""
    topic_prefix: goplc/vars
    qos: 0
    retained: false
    publish_prefixes:                 # Only publish vars with these prefixes
      - DL_
      - MB_
    publish_stats: false
    stats_interval: 1000
    subscribe_topics:                 # Subscribe to external topics
      - goplc/plc2/#
    var_prefix: MQTT_                 # Prefix for subscribed variables
```

### 6.3 Cluster Members

```yaml
api:
  cluster:
    members:
      - name: plc01
        socket: /tmp/goplc-plc01.sock
      - name: plc02
        url: http://10.0.0.51:8082
```

---

## 7. Protocols

Configure protocol servers and clients that start automatically with the runtime. These are in addition to protocols created dynamically from ST code.

```yaml
protocols:
  # Modbus TCP server
  modbus:
    enabled: true
    port: 502

  # Modbus TCP client
  modbus_master:
    enabled: false
    host: 10.0.0.50
    port: 502
    poll_rate_ms: 100

  # Multiple Modbus servers (stress testing / gateway)
  modbus_servers:
    - name: srv1
      port: 5020
      unit_id: 1

  # Multiple Modbus clients
  modbus_clients:
    - name: vfd1
      host: 10.0.0.50
      port: 502
      unit_id: 1
      poll_rate_ms: 100

  # S7 server
  s7:
    enabled: false
    port: 102
    io_registers: 15

  # S7 client
  s7_client:
    enabled: false
    host: 10.0.0.60
    port: 102
    rack: 0
    slot: 1
    poll_rate_ms: 100
    timeout_ms: 5000

  # OPC UA server
  opcua:
    enabled: true
    port: 4840
    io_registers: 15

  # OPC UA client
  opcua_client:
    enabled: false
    endpoint: opc.tcp://10.0.0.70:4840
    policy: None
    mode: None
    poll_rate_ms: 1000

  # FINS (Omron)
  fins:
    enabled: false
    host: 10.0.0.34
    port: 9600
    dest_node: 34
    src_node: 196
    poll_rate_ms: 100

  # FINS server
  fins_server:
    enabled: false
    port: 9600
    node: 1

  # EtherNet/IP adapter (server)
  enip:
    enabled: false
    port: 44818
    tags: []

  # EtherNet/IP scanner (client)
  enip_scanner:
    enabled: false
    host: 10.0.0.80
    port: 44818
    slot: 0
    poll_rate_ms: 100
    tags: []

  # DNP3 outstation (server)
  dnp3:
    enabled: false
    port: 20000
    io_registers: 16

  # DNP3 master (client)
  dnp3_master:
    enabled: false
    host: 10.0.0.90
    port: 20000
    local_address: 1
    remote_address: 10
    poll_rate_ms: 1000

  # IEC 60870-5-104 server
  iec104:
    enabled: false
    port: 2404
    common_addr: 1
    io_registers: 16

  # IEC 104 client
  iec104_client:
    enabled: false
    host: 10.0.0.100
    port: 2404
    common_addr: 1

  # BACnet/IP server
  bacnet:
    enabled: false
    port: 47808
    device_id: 1234
    device_name: GoPLC
    io_registers: 15

  # BACnet client
  bacnet_client:
    enabled: false
    host: 10.0.0.110
    port: 47808
    poll_rate_ms: 5000

  # SNMP agent
  snmp_agent:
    enabled: false
    port: 161
    community: public

  # SNMP client
  snmp_client:
    enabled: false
    host: 10.0.0.120
    port: 161
    community: public
    version: v2c
    poll_rate_ms: 5000

  # MQTT broker (embedded)
  mqtt:
    enabled: false
    port: 1883
    ws_port: 9001

  # MQTT client
  mqtt_client:
    enabled: false
    broker: tcp://10.0.0.144:1883
    client_id: goplc-mqtt
```

---

## 8. I/O Mapping

Map PLC variables to IEC 61131-3 addresses for automatic protocol synchronization:

```yaml
io_mapping:
  discrete_inputs:                    # %IX addresses
    - name: limit_switch_1
      address: "%IX0.0"
      type: BOOL

  coils:                              # %QX addresses
    - name: motor_start
      address: "%QX0.0"
      type: BOOL

  input_registers:                    # %IW addresses
    - name: temperature_raw
      address: "%IW0"
      type: INT
      scale: 0.1
      offset: 0.0
      units: degF

  holding_registers:                  # %QW addresses
    - name: speed_setpoint
      address: "%QW0"
      type: INT

  memory_words:                       # %MW addresses
    - name: batch_count
      address: "%MW0"
      type: INT

io_scan_rate_ms: 10                   # I/O sync frequency (default: 10ms = 100Hz)
```

---

## 9. DataLayer

Inter-PLC variable sharing for clusters:

```yaml
datalayer:
  enabled: true
  node_id: pump-ctrl
  type: direct                        # direct, memory, shm, tcp
  address: ":4222"                    # TCP mode only
  is_server: false                    # TCP mode: server or client
  publish_vars: true
  publish_prefixes:
    - DL_
    - MB_
  publish_stats: false
  stats_interval_ms: 1000
  subscribe_paths:
    - boss
    - valve-ctrl
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `false` | Enable DataLayer |
| `node_id` | string | `""` | Unique node identifier |
| `type` | string | `direct` | Transport: `direct`, `memory`, `shm`, `tcp` |
| `address` | string | `""` | TCP address (server: `:port`, client: `host:port`) |
| `publish_prefixes` | []string | `[]` | Variable prefixes to publish |
| `subscribe_paths` | []string | `[]` | Node IDs to subscribe to |

---

## 10. AI Assistant

```yaml
ai:
  enabled: true
  name: Assistant
  provider: claude                    # claude, openai, ollama
  api_key_env: ANTHROPIC_API_KEY
  model: claude-sonnet-4-20250514
  endpoint: ""                        # Required for ollama (e.g. http://localhost:11434)
  timeout_seconds: 30
  max_tokens: 8192
  temperature: 0.3
```

See the [AI Assistant Guide](goplc_ai_guide.md) for full documentation.

---

## 11. Node-RED

```yaml
nodered:
  enabled: true
  port: 1880
  user_dir: data/nodered
  flow_file: flows.json
  binary_path: ""                     # Auto-detect if empty
  auto_start: true
  restart_on_crash: true
  max_restarts: 5
  restart_backoff_ms: 2000
  credential_secret: ""
  extra_modules:
    - node-red-contrib-influxdb
    - node-red-contrib-modbus
```

See the [Node-RED Guide](goplc_nodered_guide.md) for full documentation.

---

## 12. Real-Time Performance

For deterministic scan times on dedicated hardware:

```yaml
realtime:
  enabled: true
  mode: baremetal                     # container or baremetal
  lock_memory: true                   # Prevent page faults (mlockall)
  lock_os_thread: true                # Pin scan goroutine to OS thread
  cpu_affinity: [2, 3]                # Dedicated CPU cores
  gomaxprocs: 2                       # Match CPU affinity count
  gc_percent: 500                     # Reduce GC frequency (0=off, 100=default)
  priority: 80                        # SCHED_FIFO priority (baremetal only, 1-99)
```

---

## 13. Debug Logging

```yaml
debug:
  enabled: true
  level: info                         # Global level: off, error, warn, info, debug, trace
  modules:                            # Per-module overrides
    modbus: debug
    s7: trace
    runtime: warn
  file: /var/log/goplc/debug.log
  syslog: 10.0.0.144:514
  buffer_size: 1000                   # In-memory ring buffer for API access
```

---

## 14. Fleet Management

```yaml
fleet:
  enabled: true
  auto_discover: true                 # mDNS discovery on startup
  collect_snapshots: true             # Auto-collect snapshots on hash change
  node_id: CRAC-GW-1                  # Stable human-readable ID
  registry_file: data/fleet-registry.json
  username: ""                        # Credentials for authenticated fleet nodes
  password: ""
```

---

## 15. License

```yaml
license:
  demo_hours: 2                       # Demo duration (default: 2 hours per session)
  internal_dir: ""                    # Override license storage path
```

---

## 16. Security

```yaml
allow_exec: false                     # Allow EXEC/EXEC_ASYNC/ENV_SET from ST code
                                      # Default false — must be explicitly enabled
```

> **Warning:** Enabling `allow_exec` lets ST programs run arbitrary shell commands. Only enable on trusted, isolated systems.

---

## 17. ctrlX Data Layer Bridge

For Bosch Rexroth ctrlX CORE integration:

```yaml
ctrlx_datalayer:
  enabled: true
  base_url: https://localhost
  username: boschrexroth
  password: boschrexroth
  publish_prefix: goplc-runtime
  publish_vars:
    - temperature
    - pressure
  subscribe_vars:
    - plc/app/variables/speed_setpoint
  sync_interval_ms: 100
  insecure_tls: true                  # Skip TLS verification (localhost)
```

---

## 18. FUXA Web SCADA

```yaml
fuxa:
  enabled: false
  url: http://fuxa:1881               # Docker container URL
```

---

## 19. Complete Example

A production-ready configuration for a water treatment gateway:

```yaml
project:
  auto_start: true

runtime:
  log_level: info

tasks:
  - name: ControlTask
    type: periodic
    priority: 1
    scan_time_ms: 50
    programs: [POU_PumpControl, POU_ValveControl]
    watchdog_ms: 200
    watchdog_fault: true

  - name: CommsTask
    type: periodic
    priority: 5
    scan_time_ms: 100
    programs: [POU_ModbusComms, POU_MQTTPublish]

  - name: LogTask
    type: periodic
    priority: 10
    scan_time_ms: 1000
    programs: [POU_DataLogger]

protocols:
  modbus:
    enabled: true
    port: 502

nodered:
  enabled: true
  extra_modules:
    - node-red-contrib-influxdb

ai:
  enabled: true
  provider: claude
  api_key_env: ANTHROPIC_API_KEY

debug:
  enabled: true
  level: info
  file: /var/log/goplc/runtime.log
```

---

*GoPLC v1.0.533 | YAML Configuration Reference*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
