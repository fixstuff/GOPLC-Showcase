# GoPLC Clustering & DataLayer Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC clustering uses a **boss/minion model**. One GoPLC instance promotes itself to "boss" and orchestrates one or more "minion" instances. Each minion is a **full PLC runtime** with its own isolated variable space, scan engine, programs, and tasks. There is no shared memory between minions — all inter-node communication flows through the DataLayer.

This design mirrors how physical PLCs are deployed in production: each controller owns its I/O and logic, and a supervisory layer coordinates them. The difference is that GoPLC can run hundreds of these nodes in a single process, on a single machine, with microsecond-level coordination.

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  GoPLC Boss                                                     │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Minion A    │  │  Minion B    │  │  Minion C    │  . . .   │
│  │              │  │              │  │              │          │
│  │  Programs    │  │  Programs    │  │  Programs    │          │
│  │  Variables   │  │  Variables   │  │  Variables   │          │
│  │  Tasks       │  │  Tasks       │  │  Tasks       │          │
│  │  Scan Engine │  │  Scan Engine │  │  Scan Engine │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └────────┬────────┴────────┬────────┘                   │
│                  │                 │                             │
│           ┌──────┴─────────────────┴──────┐                     │
│           │         DataLayer             │                     │
│           │  Pub/Sub Variable Sharing     │                     │
│           │  Transport: direct/shm/tcp    │                     │
│           └───────────────────────────────┘                     │
│                                                                 │
│  REST API  ──  /api/cluster/*                                   │
│  Fleet API ──  /api/fleet/*                                     │
└─────────────────────────────────────────────────────────────────┘
```

**Key properties:**

| Property | Detail |
|----------|--------|
| Variable isolation | Each minion has its own namespace — no cross-contamination |
| Independent scan | Each minion runs its own scan cycle at its own interval |
| Fault isolation | A faulted minion does not crash the boss or siblings |
| Hot deployment | Push new ST programs to running minions without restart |
| Transparent proxying | Boss REST API proxies requests to any minion via `/api/cluster/{name}/api/*` |

---

## 2. Three Cluster Modes

GoPLC offers three ways to form a cluster, each suited to different use cases.

### 2.1 Static (Directory-Based)

A directory on disk defines the cluster. Each subdirectory contains a minion's `config.yaml` and program files. The boss discovers minions at startup and communicates via Unix domain sockets.

```
my-cluster/
├── boss/
│   └── config.yaml
├── pump-controller/
│   ├── config.yaml
│   └── programs/
│       └── pump_logic.st
├── valve-controller/
│   ├── config.yaml
│   └── programs/
│       └── valve_logic.st
└── hmi-bridge/
    ├── config.yaml
    └── programs/
        └── hmi_tags.st
```

**Launch:**

```bash
goplc --cluster-dir ./my-cluster
```

Each minion runs as a separate process. Inter-process communication uses Unix domain sockets for low latency on the same host.

**Best for:** Production deployments with well-defined, version-controlled configurations.

### 2.2 Auto-Generated (--cluster-mode N)

A single command-line flag spawns N lightweight minions in-process. All minions share the boss process and use the in-process DataLayer (direct transport).

```bash
# Spawn a boss with 50 lightweight minions
goplc --cluster-mode 50
```

Minions are named `minion-001` through `minion-050` by default. Each gets its own variable space and scan engine, but they share the process address space — no IPC overhead.

**Best for:** Testing, benchmarking, simulation, and scenarios where you need many nodes without managing individual configs.

### 2.3 Dynamic (Runtime via ST)

ST code running in the boss can promote a standalone instance to a boss, spawn minions, deploy programs, and start/stop them — all at runtime. This is the most flexible mode.

```iecst
PROGRAM POU_DynamicCluster
VAR
    initialized : BOOL := FALSE;
    status : STRING;
    ok : BOOL;
END_VAR

IF NOT initialized THEN
    (* Step 1: Promote this instance to boss *)
    ok := CLUSTER_ENABLE();

    (* Step 2: Spawn minions *)
    ok := CLUSTER_ADD_MINION('pump-ctrl');
    ok := CLUSTER_ADD_MINION('valve-ctrl');
    ok := CLUSTER_ADD_MINION('monitor');

    (* Step 3: Deploy programs *)
    ok := CLUSTER_DEPLOY('pump-ctrl', 'PumpLogic',
        'PROGRAM PumpLogic
        VAR
            DL_pressure : REAL := 0.0;
            DL_pump_cmd : BOOL := FALSE;
        END_VAR
        IF DL_pressure > 150.0 THEN
            DL_pump_cmd := FALSE;
        ELSIF DL_pressure < 80.0 THEN
            DL_pump_cmd := TRUE;
        END_IF;
        END_PROGRAM');

    ok := CLUSTER_DEPLOY('valve-ctrl', 'ValveLogic',
        'PROGRAM ValveLogic
        VAR
            DL_valve_pos : REAL := 0.0;
            DL_target : REAL := 50.0;
        END_VAR
        IF DL_valve_pos < DL_target THEN
            DL_valve_pos := DL_valve_pos + 0.5;
        ELSIF DL_valve_pos > DL_target THEN
            DL_valve_pos := DL_valve_pos - 0.5;
        END_IF;
        END_PROGRAM');

    (* Step 4: Start minions *)
    ok := CLUSTER_START('pump-ctrl');
    ok := CLUSTER_START('valve-ctrl');
    ok := CLUSTER_START('monitor');

    initialized := TRUE;
END_IF;

(* Check cluster health *)
status := CLUSTER_STATUS();
(* Returns: 'boss' *)
END_PROGRAM
```

**Best for:** Adaptive systems that scale up/down based on conditions, self-configuring edge deployments, and orchestration logic written entirely in ST.

---

## 3. Cluster ST Functions

Eleven functions for managing the cluster lifecycle from Structured Text.

### 3.1 CLUSTER_ENABLE() -> BOOL

Promotes the current instance from standalone to boss. Returns `TRUE` on success. Fails if already a boss or if cluster infrastructure cannot be initialized.

```iecst
ok := CLUSTER_ENABLE();
```

### 3.2 CLUSTER_DISABLE() -> BOOL

Tears down all minions, stops the DataLayer, and reverts the instance to standalone mode. Returns `TRUE` on success.

```iecst
ok := CLUSTER_DISABLE();
```

> **Warning:** All minion state is lost. Ensure minions are stopped and data is persisted before disabling.

### 3.3 CLUSTER_STATUS() -> STRING

Returns the current cluster role as a string.

| Return Value | Meaning |
|-------------|---------|
| `'boss'` | Instance is the cluster boss |
| `'standalone'` | No cluster active |
| `'disabled'` | Cluster was explicitly disabled |

```iecst
status := CLUSTER_STATUS();
IF status = 'boss' THEN
    (* Cluster is active *)
END_IF;
```

### 3.4 CLUSTER_ADD_MINION(name : STRING) -> BOOL

Spawns a new in-process minion with the given name. The minion starts with no programs — use `CLUSTER_DEPLOY` to push logic. Returns `TRUE` on success. Fails if the name is already taken or the caller is not a boss.

```iecst
ok := CLUSTER_ADD_MINION('conveyor-01');
```

### 3.5 CLUSTER_REMOVE_MINION(name : STRING) -> BOOL

Stops and removes a minion. Its variable space is freed and the name becomes available for reuse.

```iecst
ok := CLUSTER_REMOVE_MINION('conveyor-01');
```

### 3.6 CLUSTER_HAS(name : STRING) -> BOOL

Checks if a minion with the given name exists in the cluster.

```iecst
IF CLUSTER_HAS('pump-ctrl') THEN
    (* Minion is present *)
END_IF;
```

### 3.7 CLUSTER_COUNT() -> INT

Returns the total number of minions currently in the cluster (not including the boss).

```iecst
count := CLUSTER_COUNT();
(* e.g. 3 *)
```

### 3.8 CLUSTER_LIST() -> STRING

Returns a comma-separated list of all minion names.

```iecst
names := CLUSTER_LIST();
(* e.g. 'pump-ctrl,valve-ctrl,monitor' *)
```

### 3.9 CLUSTER_DEPLOY(minion : STRING, program_name : STRING, source : STRING) -> BOOL

Pushes an ST program to a minion. The program is compiled and loaded into the minion's runtime. If a program with the same name already exists, it is replaced (hot-swap). Returns `TRUE` on successful compilation and deployment.

```iecst
ok := CLUSTER_DEPLOY('monitor', 'Watchdog',
    'PROGRAM Watchdog
    VAR
        DL_heartbeat : INT := 0;
    END_VAR
    DL_heartbeat := DL_heartbeat + 1;
    IF DL_heartbeat > 32767 THEN
        DL_heartbeat := 0;
    END_IF;
    END_PROGRAM');
```

> **Compile errors** are reported in the boss's fault log. Check `GET /api/faults` after a failed deploy.

### 3.10 CLUSTER_START(minion : STRING) -> BOOL

Starts the scan engine on a minion. The minion begins executing its deployed programs.

```iecst
ok := CLUSTER_START('pump-ctrl');
```

### 3.11 CLUSTER_STOP(minion : STRING) -> BOOL

Stops the scan engine on a minion. Programs halt, but variables retain their last values.

```iecst
ok := CLUSTER_STOP('pump-ctrl');
```

---

## 4. DataLayer — Pub/Sub Variable Sharing

The DataLayer is GoPLC's mechanism for sharing variables between cluster nodes. It uses a **publish/subscribe** model: each node publishes variables matching configured prefixes, and subscribes to variables from other nodes.

### 4.1 Transport Types

| Transport | Latency | Use Case |
|-----------|---------|----------|
| **direct** | < 1 us | In-process minions (auto-generated and dynamic clusters) |
| **memory** | < 1 us | Same as direct — alias for clarity in configs |
| **shm** | ~ 100 us | Separate processes on the same host (static cluster) |
| **tcp** | ~ 100-500 us | Nodes on different machines (fleet/networked clusters) |

Transport is selected automatically based on topology, but can be overridden in `config.yaml`.

### 4.2 Variable Naming Convention

Published variables appear on subscriber nodes with a prefix encoding their origin:

```
REMOTE_{NODEID}_{VARNAME}
```

For example, if minion `pump-ctrl` publishes `DL_pressure`, the boss and other minions see it as:

```
REMOTE_pump-ctrl_DL_pressure
```

### 4.3 DataLayer ST Functions

#### DL_GET(node_id : STRING, var_name : STRING) -> ANY

Reads a variable from a remote node. Returns the current value. Type is preserved — REAL stays REAL, INT stays INT.

```iecst
pressure := DL_GET('pump-ctrl', 'DL_pressure');
(* Returns: 120.5 (REAL) *)

pump_running := DL_GET('pump-ctrl', 'DL_pump_cmd');
(* Returns: TRUE (BOOL) *)
```

#### DL_EXISTS(node_id : STRING, var_name : STRING) -> BOOL

Checks if a remote variable exists and has been published at least once.

```iecst
IF DL_EXISTS('pump-ctrl', 'DL_pressure') THEN
    pressure := DL_GET('pump-ctrl', 'DL_pressure');
END_IF;
```

#### DL_GET_TS(node_id : STRING, var_name : STRING) -> INT

Returns the timestamp of the last update to a remote variable, in **microseconds** since epoch. Use this to detect stale data.

```iecst
ts := DL_GET_TS('pump-ctrl', 'DL_pressure');
now_us := TIME_US();
age_us := now_us - ts;
IF age_us > 1000000 THEN
    (* Data is older than 1 second — stale *)
    alarm := TRUE;
END_IF;
```

#### DL_LATENCY_US(node_id : STRING, var_name : STRING) -> INT

Returns the measured network latency in microseconds for the last update of a remote variable. Useful for diagnostics and transport health monitoring.

```iecst
latency := DL_LATENCY_US('pump-ctrl', 'DL_pressure');
(* Returns: 2 (direct transport) or 350 (tcp transport) *)
```

### 4.4 DataLayer Configuration

Variables are published based on **prefix matching**. Any variable whose name starts with a configured prefix is automatically published to the DataLayer.

```yaml
datalayer:
  node_id: "pump-ctrl"
  transport: "direct"
  publish_prefixes:
    - "DL_"
    - "MB_"
  subscribe_paths:
    - "valve-ctrl"
    - "monitor"
```

| Field | Description |
|-------|-------------|
| `node_id` | Unique identifier for this node in the DataLayer |
| `transport` | Transport type: `direct`, `memory`, `shm`, `tcp` |
| `publish_prefixes` | List of variable name prefixes to publish (e.g. `DL_`, `MB_`) |
| `subscribe_paths` | List of node IDs to subscribe to |

> **Convention:** Prefix shared variables with `DL_` so they are immediately recognizable as DataLayer-published. Use `MB_` for Modbus-mapped variables that should also be shared.

### 4.5 Complete DataLayer Example

A boss reads pressure from one minion and sends a valve command to another:

```iecst
PROGRAM POU_Supervisor
VAR
    pressure : REAL;
    valve_target : REAL;
    pump_running : BOOL;
    latency : INT;
    data_valid : BOOL;
END_VAR

(* Verify data freshness *)
data_valid := DL_EXISTS('pump-ctrl', 'DL_pressure');

IF data_valid THEN
    (* Read pressure from pump controller *)
    pressure := DL_GET('pump-ctrl', 'DL_pressure');
    latency := DL_LATENCY_US('pump-ctrl', 'DL_pressure');

    (* Read pump state *)
    pump_running := DL_GET('pump-ctrl', 'DL_pump_cmd');

    (* Compute valve position *)
    IF pressure > 120.0 THEN
        valve_target := 25.0;    (* Restrict flow *)
    ELSIF pressure < 60.0 THEN
        valve_target := 100.0;   (* Full open *)
    ELSE
        valve_target := 50.0;    (* Normal *)
    END_IF;

    (* Write target — published via DL_ prefix to valve-ctrl *)
    DL_valve_target := valve_target;
END_IF;
END_PROGRAM
```

In this example, the boss's `DL_valve_target` variable is published automatically (because it starts with `DL_`), and `valve-ctrl` subscribes to it, seeing it as `REMOTE_boss_DL_valve_target`.

---

## 5. REST API

All cluster operations are available via the boss's REST API.

### 5.1 Cluster Members

#### GET /api/cluster/members

Returns all cluster members with status and latency.

```json
{
  "members": [
    {
      "name": "pump-ctrl",
      "status": "online",
      "mode": "minion",
      "scan_time_us": 46,
      "scans_per_sec": 978,
      "latency_us": 2
    },
    {
      "name": "valve-ctrl",
      "status": "online",
      "mode": "minion",
      "scan_time_us": 48,
      "scans_per_sec": 965,
      "latency_us": 2
    }
  ],
  "count": 2,
  "boss": "main"
}
```

### 5.2 Enable / Disable Cluster

#### POST /api/cluster/enable

Promotes the instance to boss.

```bash
curl -X POST http://localhost:8300/api/cluster/enable
```

```json
{"status": "ok", "role": "boss"}
```

#### POST /api/cluster/disable

Tears down the cluster and reverts to standalone.

```bash
curl -X POST http://localhost:8300/api/cluster/disable
```

```json
{"status": "ok", "role": "standalone"}
```

### 5.3 Minion Management

#### POST /api/cluster/minions

Spawn a new minion.

```bash
curl -X POST http://localhost:8300/api/cluster/minions \
  -H "Content-Type: application/json" \
  -d '{"name": "new-minion"}'
```

```json
{"status": "ok", "name": "new-minion"}
```

#### DELETE /api/cluster/minions/{name}

Remove a minion.

```bash
curl -X DELETE http://localhost:8300/api/cluster/minions/new-minion
```

```json
{"status": "ok", "removed": "new-minion"}
```

### 5.4 Dynamic Cluster Status

#### GET /api/cluster/dynamic

Full cluster status including all minions, their programs, variables, and DataLayer metrics.

```bash
curl http://localhost:8300/api/cluster/dynamic
```

```json
{
  "role": "boss",
  "minions": {
    "pump-ctrl": {
      "status": "running",
      "programs": ["PumpLogic"],
      "variables": 4,
      "scan_time_us": 46,
      "datalayer": {
        "published": 2,
        "subscribed": 1,
        "transport": "direct"
      }
    }
  },
  "datalayer": {
    "total_published": 8,
    "total_subscribed": 6,
    "avg_latency_us": 1.7
  }
}
```

### 5.5 Minion API Proxy

#### GET /api/cluster/{name}/api/*

Proxies any REST request to a minion's API. This lets you access a minion's variables, programs, and diagnostics through the boss's single endpoint.

```bash
# List variables on pump-ctrl minion
curl http://localhost:8300/api/cluster/pump-ctrl/api/variables

# Read a specific variable
curl http://localhost:8300/api/cluster/pump-ctrl/api/variables/DL_pressure

# Get minion's runtime status
curl http://localhost:8300/api/cluster/pump-ctrl/api/runtime/status
```

### 5.6 Cluster Bundles

#### POST /api/cluster/export

Downloads the entire cluster configuration as a `.goplc-cluster` bundle (zip archive containing all configs, programs, and DataLayer mappings).

```bash
curl -X POST http://localhost:8300/api/cluster/export \
  -o my-cluster.goplc-cluster
```

#### POST /api/cluster/import

Uploads a `.goplc-cluster` bundle and deploys it to all nodes.

```bash
curl -X POST http://localhost:8300/api/cluster/import \
  -F "bundle=@my-cluster.goplc-cluster"
```

```json
{"status": "ok", "imported": 3, "nodes": ["pump-ctrl", "valve-ctrl", "monitor"]}
```

---

## 6. Fleet Management

Fleet management extends clustering to **multiple physical machines** using mDNS discovery. While clustering manages minions within a single boss, fleet management coordinates independent GoPLC instances across the network.

### 6.1 Discovery

#### GET /api/fleet/discover

Triggers an mDNS scan for GoPLC instances on the local network. Returns discovered nodes with their addresses and capabilities.

```bash
curl http://localhost:8300/api/fleet/discover
```

```json
{
  "nodes": [
    {
      "id": "goplc-edge-01",
      "address": "10.0.0.50:8300",
      "version": "1.0.520",
      "role": "standalone",
      "uptime": "4d 12h 30m"
    },
    {
      "id": "goplc-edge-02",
      "address": "10.0.0.51:8300",
      "version": "1.0.520",
      "role": "boss",
      "minions": 5,
      "uptime": "2d 8h 15m"
    }
  ],
  "count": 2,
  "scan_time_ms": 2100
}
```

#### GET /api/fleet/nodes

Returns the cached list of known fleet nodes (no new scan).

```bash
curl http://localhost:8300/api/fleet/nodes
```

### 6.2 Configuration Push

#### POST /api/fleet/nodes/{id}/config

Pushes a `config.yaml` to a remote node. The node validates and applies the configuration, then restarts its runtime.

```bash
curl -X POST http://localhost:8300/api/fleet/nodes/goplc-edge-01/config \
  -H "Content-Type: application/yaml" \
  -d @edge01-config.yaml
```

```json
{"status": "ok", "node": "goplc-edge-01", "restarted": true}
```

### 6.3 Snapshot Collection

#### POST /api/fleet/snapshots/collect

Collects a point-in-time snapshot from all fleet nodes — variables, programs, faults, and diagnostics.

```bash
curl -X POST http://localhost:8300/api/fleet/snapshots/collect
```

```json
{
  "snapshot_id": "snap-20260403-143022",
  "nodes_collected": 3,
  "timestamp": "2026-04-03T14:30:22Z"
}
```

#### POST /api/fleet/snapshots/export

Exports collected snapshots as a downloadable archive.

```bash
curl -X POST http://localhost:8300/api/fleet/snapshots/export \
  -d '{"snapshot_id": "snap-20260403-143022"}' \
  -o fleet-snapshot.zip
```

---

## 7. Performance

Measured on a single host (Intel i7-12700K, 32 GB RAM, Ubuntu 24.04). All minions running a 10-variable ST program with DataLayer pub/sub active.

### 7.1 Cluster Scaling

| Minions | Avg Scan Time | Total Scans/sec | Efficiency |
|---------|---------------|-----------------|------------|
| 1 | 46 us | 978 | baseline |
| 10 | 45 us | 9,814 | 100.3% |
| 50 | 44 us | 49,112 | 100.4% |
| 100 | 44 us | 96,074 | 98.2% |
| 250 | 48 us | 237,500 | 97.1% |
| 500 | 52 us | 464,199 | 94.9% |

**Efficiency** = (actual total scans/sec) / (single-minion scans/sec * N) * 100

The slight degradation at 500 minions is due to Go runtime scheduling overhead — not DataLayer contention. Each minion runs on its own goroutine; the Go scheduler distributes them across available CPU cores.

### 7.2 DataLayer Latency (Direct Transport)

| Metric | Value |
|--------|-------|
| Average | 1.7 us |
| p50 | 1.2 us |
| p95 | 5.5 us |
| p99 | 8.2 us |
| Max observed | 42 us |

p99 spikes correlate with Go garbage collection pauses. For hard real-time requirements below 10 us, pin minions to dedicated CPU cores via `GOMAXPROCS` and `taskset`.

### 7.3 Transport Comparison

| Transport | Avg Latency | p99 Latency | Throughput |
|-----------|-------------|-------------|------------|
| direct | 1.7 us | 8.2 us | > 500K vars/sec |
| memory | 1.7 us | 8.2 us | > 500K vars/sec |
| shm | 98 us | 210 us | ~ 50K vars/sec |
| tcp (localhost) | 120 us | 450 us | ~ 20K vars/sec |
| tcp (LAN) | 350 us | 1.2 ms | ~ 5K vars/sec |

---

## 8. YAML Configuration

### 8.1 DataLayer Config

```yaml
# config.yaml — DataLayer section
datalayer:
  node_id: "pump-ctrl"
  transport: "direct"

  # Variables matching these prefixes are published automatically
  publish_prefixes:
    - "DL_"      # DataLayer-shared variables
    - "MB_"      # Modbus-mapped variables

  # Subscribe to variables from these nodes
  subscribe_paths:
    - "boss"
    - "valve-ctrl"
    - "monitor"

  # Optional: override transport per subscription
  subscriptions:
    - node_id: "remote-plc"
      transport: "tcp"
      address: "10.0.0.51:8300"
```

### 8.2 Static Cluster Config

Each minion directory contains its own `config.yaml`:

```yaml
# my-cluster/pump-controller/config.yaml
runtime:
  name: "pump-ctrl"
  scan_interval: "1ms"
  web_port: 0              # 0 = no HTTP server (boss proxies)

programs:
  - name: "PumpLogic"
    file: "programs/pump_logic.st"
    task: "Main"

tasks:
  - name: "Main"
    interval: "1ms"
    priority: 1

datalayer:
  node_id: "pump-ctrl"
  transport: "shm"         # Unix shared memory for static clusters
  publish_prefixes:
    - "DL_"
  subscribe_paths:
    - "boss"
    - "valve-ctrl"
```

Boss `config.yaml`:

```yaml
# my-cluster/boss/config.yaml
runtime:
  name: "boss"
  scan_interval: "1ms"
  web_port: 8300

cluster:
  mode: "static"
  directory: "/opt/goplc/my-cluster"

datalayer:
  node_id: "boss"
  transport: "shm"
  publish_prefixes:
    - "DL_"
  subscribe_paths:
    - "pump-ctrl"
    - "valve-ctrl"
    - "hmi-bridge"
```

### 8.3 Auto-Generated Cluster Config

```yaml
# config.yaml — auto-generated mode
runtime:
  name: "boss"
  scan_interval: "1ms"
  web_port: 8300

cluster:
  mode: "auto"
  count: 50                 # Spawn 50 minions
  minion_prefix: "node"     # Names: node-001 through node-050

datalayer:
  node_id: "boss"
  transport: "direct"       # In-process, sub-microsecond
  publish_prefixes:
    - "DL_"
```

---

## Appendix A: Complete Example — Dynamic Water Treatment Plant

This example demonstrates a self-configuring water treatment cluster. The boss spawns three minions, deploys purpose-built programs to each, and uses the DataLayer to coordinate them.

```iecst
(* ============================================================
   Water Treatment Plant — Dynamic Cluster
   Boss program: spawns and orchestrates 3 minions
   ============================================================ *)
PROGRAM POU_WaterPlant
VAR
    init_done : BOOL := FALSE;
    ok : BOOL;
    count : INT;
    status : STRING;

    (* DataLayer reads from minions *)
    inlet_pressure : REAL;
    outlet_flow : REAL;
    ph_level : REAL;
    chlorine_ppm : REAL;

    (* DataLayer writes — published to minions *)
    DL_inlet_valve_cmd : REAL := 50.0;
    DL_dose_rate : REAL := 2.0;
    DL_alarm_active : BOOL := FALSE;
END_VAR

(* --- INITIALIZATION --- *)
IF NOT init_done THEN
    ok := CLUSTER_ENABLE();

    (* Spawn process minions *)
    ok := CLUSTER_ADD_MINION('inlet');
    ok := CLUSTER_ADD_MINION('treatment');
    ok := CLUSTER_ADD_MINION('outlet');

    (* Deploy inlet control *)
    ok := CLUSTER_DEPLOY('inlet', 'InletControl',
        'PROGRAM InletControl
        VAR
            DL_pressure : REAL := 0.0;
            DL_flow_gpm : REAL := 0.0;
            valve_pos : REAL := 50.0;
            sim_counter : INT := 0;
        END_VAR
        sim_counter := sim_counter + 1;
        DL_pressure := 45.0 + SIN(INT_TO_REAL(sim_counter) * 0.01) * 10.0;
        DL_flow_gpm := valve_pos * 2.0;
        END_PROGRAM');

    (* Deploy treatment dosing *)
    ok := CLUSTER_DEPLOY('treatment', 'ChemDose',
        'PROGRAM ChemDose
        VAR
            DL_ph : REAL := 7.0;
            DL_chlorine : REAL := 1.5;
            dose_rate : REAL := 2.0;
            sim_counter : INT := 0;
        END_VAR
        sim_counter := sim_counter + 1;
        DL_ph := 7.0 + SIN(INT_TO_REAL(sim_counter) * 0.02) * 0.5;
        DL_chlorine := dose_rate * 0.75;
        END_PROGRAM');

    (* Deploy outlet monitoring *)
    ok := CLUSTER_DEPLOY('outlet', 'OutletMonitor',
        'PROGRAM OutletMonitor
        VAR
            DL_outlet_flow : REAL := 0.0;
            DL_turbidity : REAL := 0.0;
            sim_counter : INT := 0;
        END_VAR
        sim_counter := sim_counter + 1;
        DL_outlet_flow := 85.0 + SIN(INT_TO_REAL(sim_counter) * 0.015) * 5.0;
        DL_turbidity := 0.3 + SIN(INT_TO_REAL(sim_counter) * 0.005) * 0.1;
        END_PROGRAM');

    (* Start all minions *)
    ok := CLUSTER_START('inlet');
    ok := CLUSTER_START('treatment');
    ok := CLUSTER_START('outlet');

    init_done := TRUE;
END_IF;

(* --- SUPERVISORY LOGIC (runs every scan) --- *)
IF init_done THEN
    count := CLUSTER_COUNT();

    (* Read from minions via DataLayer *)
    IF DL_EXISTS('inlet', 'DL_pressure') THEN
        inlet_pressure := DL_GET('inlet', 'DL_pressure');
    END_IF;

    IF DL_EXISTS('treatment', 'DL_ph') THEN
        ph_level := DL_GET('treatment', 'DL_ph');
        chlorine_ppm := DL_GET('treatment', 'DL_chlorine');
    END_IF;

    IF DL_EXISTS('outlet', 'DL_outlet_flow') THEN
        outlet_flow := DL_GET('outlet', 'DL_outlet_flow');
    END_IF;

    (* Supervisory decisions *)
    IF inlet_pressure > 55.0 THEN
        DL_inlet_valve_cmd := 30.0;      (* Throttle *)
    ELSIF inlet_pressure < 35.0 THEN
        DL_inlet_valve_cmd := 80.0;      (* Open up *)
    ELSE
        DL_inlet_valve_cmd := 50.0;      (* Normal *)
    END_IF;

    IF ph_level < 6.5 OR ph_level > 7.8 THEN
        DL_alarm_active := TRUE;
        DL_dose_rate := 4.0;             (* Increase dosing *)
    ELSE
        DL_alarm_active := FALSE;
        DL_dose_rate := 2.0;             (* Normal dosing *)
    END_IF;
END_IF;
END_PROGRAM
```

---

## Appendix B: Function Quick Reference

### Cluster Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `CLUSTER_ENABLE()` | BOOL | Promote to boss |
| `CLUSTER_DISABLE()` | BOOL | Tear down cluster, revert to standalone |
| `CLUSTER_STATUS()` | STRING | `'boss'`, `'standalone'`, or `'disabled'` |
| `CLUSTER_ADD_MINION(name)` | BOOL | Spawn in-process minion |
| `CLUSTER_REMOVE_MINION(name)` | BOOL | Stop and remove minion |
| `CLUSTER_HAS(name)` | BOOL | Check if minion exists |
| `CLUSTER_COUNT()` | INT | Number of minions |
| `CLUSTER_LIST()` | STRING | Comma-separated minion names |
| `CLUSTER_DEPLOY(minion, prog, src)` | BOOL | Push ST program to minion |
| `CLUSTER_START(minion)` | BOOL | Start minion scan engine |
| `CLUSTER_STOP(minion)` | BOOL | Stop minion scan engine |

### DataLayer Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `DL_GET(node_id, var_name)` | ANY | Read remote variable |
| `DL_EXISTS(node_id, var_name)` | BOOL | Check if remote variable exists |
| `DL_GET_TS(node_id, var_name)` | INT | Last update timestamp (microseconds) |
| `DL_LATENCY_US(node_id, var_name)` | INT | Network latency (microseconds) |

---

*GoPLC v1.0.520 | Clustering + DataLayer | Boss/Minion Architecture*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
