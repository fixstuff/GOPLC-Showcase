# GoPLC Sparkplug B Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements a complete **Sparkplug B v3.0** edge node callable directly from IEC 61131-3 Structured Text. No Ignition modules, no Java dependencies, no external gateway software. GoPLC connects to any MQTT 3.1.1 broker (Mosquitto, EMQX, HiveMQ Cloud, AWS IoT) and speaks native Sparkplug B — Google Protocol Buffer payloads, proper birth/death lifecycle, sequence number management, and metric change detection built in.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Edge Node** | `SPARKPLUG_NODE_CREATE` / `SPARKPLUG_NODE_BIRTH` / `SPARKPLUG_NODE_DATA` | Publish PLC data to SCADA via Sparkplug-aware infrastructure |
| **Metrics** | `SPARKPLUG_METRIC_ADD` / `SPARKPLUG_METRIC_SET` / `SPARKPLUG_METRIC_GET` | Register and update named data points with automatic type detection |
| **Commands** | `SPARKPLUG_CMD_SUBSCRIBE` / `SPARKPLUG_CMD_GET` / `SPARKPLUG_CMD_CLEAR` | Receive write-back commands from SCADA (NCMD topic) |
| **Lifecycle** | `SPARKPLUG_NODE_BIRTH` / `SPARKPLUG_NODE_DEATH` / `SPARKPLUG_NODE_DATA` | Full NBIRTH/NDEATH/NDATA state management |

All functions are controlled entirely from IEC 61131-3 Structured Text in GoPLC's browser-based IDE.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ST Program                                             │  │
│  │                                                        │  │
│  │ SPARKPLUG_NODE_CREATE('node1', 'Plant/Line1',            │  │
│  │     'GoPLC-Edge1', 'tcp://broker:1883', 'goplc-sp1')  │  │
│  │ SPARKPLUG_METRIC_ADD('node1', 'Temperature', 72.5)       │  │
│  │ SPARKPLUG_METRIC_ADD('node1', 'MotorRunning', TRUE)      │  │
│  │ SPARKPLUG_NODE_BIRTH('node1')   → NBIRTH                 │  │
│  │ SPARKPLUG_METRIC_SET('node1', 'Temperature', 73.1)       │  │
│  │ SPARKPLUG_NODE_DATA('node1')    → NDATA (changed only)   │  │
│  └───────────────────────┬────────────────────────────────┘  │
│                          │                                   │
│                          │  MQTT 3.1.1 + Sparkplug B         │
│                          │  (Protobuf payloads)              │
└──────────────────────────┼───────────────────────────────────┘
                           │
                           │  TCP :1883 / TLS :8883
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  MQTT Broker (Mosquitto, EMQX, HiveMQ, AWS IoT)             │
│                                                              │
│  Topics:                                                     │
│    spBv1.0/Plant/Line1/NBIRTH/GoPLC-Edge1                    │
│    spBv1.0/Plant/Line1/NDEATH/GoPLC-Edge1                    │
│    spBv1.0/Plant/Line1/NDATA/GoPLC-Edge1                     │
│    spBv1.0/Plant/Line1/NCMD/GoPLC-Edge1                      │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   │  Subscriptions
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  Sparkplug-Aware Consumers                                   │
│                                                              │
│  Ignition SCADA (Cirrus Link module)                         │
│  Chariot MQTT Server                                         │
│  Custom Sparkplug decoders (Python, Node.js)                 │
│  InfluxDB + Telegraf (Sparkplug input plugin)                │
│  Grafana (via any of the above)                              │
└──────────────────────────────────────────────────────────────┘
```

### Sparkplug B Concepts

| Concept | Description |
|---------|-------------|
| **Group ID** | Logical grouping (e.g., `Plant`, `Building1`) — first level of the topic namespace |
| **Edge Node ID** | Unique identifier for this GoPLC instance within the group |
| **Metric** | A named data point (temperature, pressure, motor state) with type, value, and timestamp |
| **NBIRTH** | Node Birth certificate — full metric catalog published on connect |
| **NDEATH** | Node Death certificate — pre-registered LWT, published by broker on disconnect |
| **NDATA** | Node Data — incremental update with only changed metrics |
| **NCMD** | Node Command — write-back from SCADA to edge node |
| **Sequence Number** | 0-255 monotonic counter in every message — consumers detect gaps as missed data |

### Sparkplug B Topic Namespace

```
spBv1.0/{group_id}/{message_type}/{edge_node_id}

Examples:
  spBv1.0/Plant/Line1/NBIRTH/GoPLC-Edge1     ← birth certificate
  spBv1.0/Plant/Line1/NDEATH/GoPLC-Edge1     ← death certificate (LWT)
  spBv1.0/Plant/Line1/NDATA/GoPLC-Edge1      ← data updates
  spBv1.0/Plant/Line1/NCMD/GoPLC-Edge1       ← commands from SCADA
```

> **Why Sparkplug over raw MQTT?** Raw MQTT requires every subscriber to know every topic. Sparkplug adds structure: a birth certificate defines every metric (name, type, initial value), consumers auto-discover tags, the death certificate handles ungraceful disconnects, and sequence numbers detect data loss. Ignition SCADA discovers and displays all GoPLC tags automatically — zero configuration on the Ignition side.

---

## 2. Node Lifecycle

### 2.1 SPARKPLUG_NODE_CREATE -- Create Edge Node

```iecst
ok := SPARKPLUG_NODE_CREATE('node1', 'Plant/Line1', 'GoPLC-Edge1',
                           'tcp://10.0.0.144:1883', 'goplc-sparkplug-1');
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Instance name (used in all subsequent calls) |
| `groupID` | STRING | Yes | Sparkplug group ID (e.g., `Plant/Line1`) |
| `edgeNodeID` | STRING | Yes | Unique edge node identifier |
| `brokerURL` | STRING | Yes | MQTT broker URL: `tcp://host:port` or `ssl://host:port` |
| `clientID` | STRING | Yes | MQTT client ID (must be unique per broker) |

Returns `TRUE` on success. The node is created but **not yet connected** -- call `SPARKPLUG_NODE_CONNECT` next.

For authenticated connections, use `SPARKPLUG_NODE_CREATE_AUTH`:

```iecst
(* No authentication *)
ok := SPARKPLUG_NODE_CREATE('node1', 'Plant', 'Edge1',
                           'tcp://broker:1883', 'goplc-sp-1');

(* With authentication — use SPARKPLUG_NODE_CREATE_AUTH *)
ok := SPARKPLUG_NODE_CREATE_AUTH('node1', 'Plant', 'Edge1',
                                'tcp://broker:1883', 'goplc-sp-1',
                                'goplc_user', 's3cretP@ss');

(* TLS + authentication *)
ok := SPARKPLUG_NODE_CREATE_AUTH('node1', 'Plant', 'Edge1',
                                'ssl://broker:8883', 'goplc-sp-1',
                                'goplc_user', 's3cretP@ss');
```

> **Client ID uniqueness:** If two nodes connect with the same client ID, the broker disconnects the first one. Use a unique ID per GoPLC instance — hostname or MAC address works well.

### 2.2 SPARKPLUG_NODE_CONNECT / Disconnect / IsConnected

```iecst
(* Connect to broker — registers NDEATH as LWT *)
ok := SPARKPLUG_NODE_CONNECT('node1');

(* Check connection state *)
IF SPARKPLUG_NODE_IS_CONNECTED('node1') THEN
    (* publish metrics *)
END_IF;

(* Graceful disconnect — triggers NDEATH from broker LWT *)
SPARKPLUG_NODE_DISCONNECT('node1');
```

`SPARKPLUG_NODE_CONNECT` establishes the MQTT connection and registers the **NDEATH** message as the broker's Last Will and Testament (LWT). If GoPLC crashes or loses network, the broker publishes NDEATH automatically — Ignition and other consumers see the node go offline immediately.

### 2.3 SPARKPLUG_NODE_DELETE / SPARKPLUG_NODE_LIST

```iecst
(* Remove a node *)
SPARKPLUG_NODE_DELETE('node1');

(* List all Sparkplug nodes *)
names := SPARKPLUG_NODE_LIST();
(* Returns: 'node1,node2' — comma-separated string *)
```

---

## 3. Metrics

### 3.1 SPARKPLUG_METRIC_ADD -- Register a Metric

```iecst
(* Add metrics with initial values — type is auto-detected *)
ok := SPARKPLUG_METRIC_ADD('node1', 'Temperature', 72.5);       (* Float *)
ok := SPARKPLUG_METRIC_ADD('node1', 'MotorRunning', TRUE);      (* Boolean *)
ok := SPARKPLUG_METRIC_ADD('node1', 'BatchCount', 0);           (* Integer *)
ok := SPARKPLUG_METRIC_ADD('node1', 'RecipeName', 'Default');   (* String *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Node instance name |
| `metricName` | STRING | Metric name (appears in Sparkplug birth certificate and SCADA tag browser) |
| `value` | ANY | Initial value — type is inferred (BOOL, INT, REAL, STRING) |

Returns `TRUE` on success. Metrics must be added **before** calling `SPARKPLUG_NODE_BIRTH` — the birth certificate includes the complete metric catalog.

> **Metric naming:** Use descriptive, hierarchical names. Ignition displays them as-is in the tag browser. `Line1/Motor/Speed` is better than `N7_0`. Sparkplug metric names support `/` separators — Ignition renders them as a folder tree.

### 3.2 SPARKPLUG_METRIC_SET -- Update a Metric Value

```iecst
(* Update metric — marks it as changed for next NDATA *)
ok := SPARKPLUG_METRIC_SET('node1', 'Temperature', 73.1);
ok := SPARKPLUG_METRIC_SET('node1', 'MotorRunning', FALSE);
ok := SPARKPLUG_METRIC_SET('node1', 'BatchCount', 42);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Node instance name |
| `metricName` | STRING | Metric name (must have been added with `SPARKPLUG_METRIC_ADD`) |
| `value` | ANY | New value |

Returns `TRUE` on success. This **does not** immediately publish — it marks the metric as changed. Call `SPARKPLUG_NODE_DATA` to publish all changed metrics in a single NDATA message.

### 3.3 SPARKPLUG_METRIC_GET -- Read Current Value

```iecst
temp := SPARKPLUG_METRIC_GET('node1', 'Temperature');
(* Returns: 73.1 *)

running := SPARKPLUG_METRIC_GET('node1', 'MotorRunning');
(* Returns: TRUE *)
```

Returns the current local value of the metric. This reads from GoPLC's in-memory metric store, not from the broker.

#### Type-Specific Getters

For type safety, use the typed variants instead of the generic `SPARKPLUG_METRIC_GET`:

```iecst
temp := SPARKPLUG_METRIC_GET_REAL('node1', 'Temperature');   (* Returns: 73.1 as REAL *)
count := SPARKPLUG_METRIC_GET_INT('node1', 'BatchCount');     (* Returns: 42 as INT *)
running := SPARKPLUG_METRIC_GET_BOOL('node1', 'MotorRunning'); (* Returns: TRUE as BOOL *)
recipe := SPARKPLUG_METRIC_GET_STR('node1', 'RecipeName');    (* Returns: "Batch-A" as STRING *)
```

The generic `SPARKPLUG_METRIC_GET` returns ANY and relies on the runtime to infer the type. The typed variants guarantee the return type and return a default value (0.0, 0, FALSE, or empty string) if the metric is not found.

---

## 4. Publishing

### 4.1 SPARKPLUG_NODE_BIRTH -- Send NBIRTH

```iecst
ok := SPARKPLUG_NODE_BIRTH('node1');
```

Publishes the **Node Birth Certificate** to `spBv1.0/{groupID}/NBIRTH/{edgeNodeID}`. The birth message contains:

- **All registered metrics** with their current values and Sparkplug data types
- **Sequence number** reset to 0
- **Timestamp** (milliseconds since epoch)

The birth certificate is a **retained** message — new subscribers (like Ignition connecting later) receive the full metric catalog immediately.

> **When to send NBIRTH:** Call `SPARKPLUG_NODE_BIRTH` once after connecting and adding all metrics. If Ignition sends a rebirth request via NCMD, call it again to republish the full metric catalog.

### 4.2 SPARKPLUG_NODE_DEATH -- Send NDEATH

```iecst
ok := SPARKPLUG_NODE_DEATH('node1');
```

Publishes the **Node Death Certificate** to `spBv1.0/{groupID}/NDEATH/{edgeNodeID}`. This signals an intentional, graceful shutdown. The broker also publishes NDEATH automatically (via LWT) if the connection drops unexpectedly.

> **Graceful vs. ungraceful:** `SPARKPLUG_NODE_DISCONNECT` triggers the broker's LWT (NDEATH). `SPARKPLUG_NODE_DEATH` sends it explicitly before disconnecting. Both result in the same NDEATH message reaching consumers — the distinction matters only for timing.

### 4.3 SPARKPLUG_NODE_DATA -- Send NDATA (Changed Metrics Only)

```iecst
ok := SPARKPLUG_NODE_DATA('node1');
```

Publishes an **NDATA** message containing **only metrics that changed** since the last NDATA or NBIRTH. This is the primary data publishing function — call it on every scan cycle or at your desired publish rate.

```iecst
(* Typical scan cycle pattern *)
SPARKPLUG_METRIC_SET('node1', 'Temperature', current_temp);
SPARKPLUG_METRIC_SET('node1', 'Pressure', current_pressure);
SPARKPLUG_METRIC_SET('node1', 'MotorRunning', motor_fb);

(* Publish only changed values *)
SPARKPLUG_NODE_DATA('node1');
```

If no metrics have changed, `SPARKPLUG_NODE_DATA` returns `TRUE` without publishing — no empty messages are sent. The sequence number only increments when a message is actually published.

### 4.4 SPARKPLUG_GET_SEQ -- Current Sequence Number

```iecst
seq := SPARKPLUG_GET_SEQ('node1');
(* Returns: 42 — current sequence number (0-255, wraps) *)
```

Returns the current Sparkplug sequence number. Consumers use this to detect missed messages — a gap in the sequence means data was lost and a rebirth should be requested.

---

## 5. Commands (NCMD)

### 5.1 SPARKPLUG_CMD_SUBSCRIBE -- Listen for SCADA Commands

```iecst
ok := SPARKPLUG_CMD_SUBSCRIBE('node1');
```

Subscribes to the NCMD topic: `spBv1.0/{groupID}/NCMD/{edgeNodeID}`. SCADA systems (Ignition, etc.) publish NCMD messages to write values back to the edge node — setpoints, mode changes, rebirth requests.

### 5.2 SPARKPLUG_CMD_HAS / CmdGet / CmdClear

```iecst
(* Check if a command arrived for a specific metric *)
IF SPARKPLUG_CMD_HAS('node1', 'Setpoint') THEN
    (* Read the commanded value *)
    new_sp := SPARKPLUG_CMD_GET('node1', 'Setpoint');
    (* Apply it *)
    target_temp := new_sp;
    (* Clear the command flag *)
    SPARKPLUG_CMD_CLEAR('node1', 'Setpoint');
END_IF;

(* Handle rebirth request from Ignition *)
IF SPARKPLUG_CMD_HAS('node1', 'Node Control/Rebirth') THEN
    SPARKPLUG_CMD_CLEAR('node1', 'Node Control/Rebirth');
    SPARKPLUG_NODE_BIRTH('node1');  (* republish full metric catalog *)
END_IF;
```

| Function | Params | Returns | Description |
|----------|--------|---------|-------------|
| `SPARKPLUG_CMD_HAS` | `(name, metricName)` | BOOL | Check if a command arrived |
| `SPARKPLUG_CMD_GET` | `(name, metricName)` | ANY | Read the commanded value |
| `SPARKPLUG_CMD_CLEAR` | `(name, metricName)` | BOOL | Clear the command flag |

> **Ignition rebirth:** When Ignition connects to a broker and finds an existing edge node, it sends a rebirth request via NCMD with metric name `Node Control/Rebirth`. Your ST program must handle this by calling `SPARKPLUG_NODE_BIRTH` to republish the full metric catalog.

---

## 6. Complete Example: Production Line to Ignition

This example connects a GoPLC edge node to Ignition SCADA via Sparkplug B, publishing production data and accepting setpoint commands:

```iecst
PROGRAM POU_Sparkplug_Production
VAR
    state : INT := 0;
    ok : BOOL;
    (* Process values — updated from other programs or I/O *)
    line_speed : REAL := 0.0;
    motor_temp : REAL := 0.0;
    conveyor_running : BOOL := FALSE;
    batch_count : DINT := 0;
    reject_count : DINT := 0;
    (* Setpoint from SCADA *)
    speed_setpoint : REAL := 100.0;
    new_sp : REAL;
    publish_counter : INT := 0;
END_VAR

CASE state OF
    0: (* Create Sparkplug edge node *)
        ok := SPARKPLUG_NODE_CREATE('prod', 'Factory/Line1', 'GoPLC-Line1',
                                   'tcp://10.0.0.144:1883', 'goplc-line1-sp');
        IF ok THEN state := 1; END_IF;

    1: (* Connect to broker *)
        ok := SPARKPLUG_NODE_CONNECT('prod');
        IF ok THEN state := 2; END_IF;

    2: (* Register all metrics *)
        SPARKPLUG_METRIC_ADD('prod', 'Line/Speed', line_speed);
        SPARKPLUG_METRIC_ADD('prod', 'Line/SpeedSetpoint', speed_setpoint);
        SPARKPLUG_METRIC_ADD('prod', 'Motor/Temperature', motor_temp);
        SPARKPLUG_METRIC_ADD('prod', 'Conveyor/Running', conveyor_running);
        SPARKPLUG_METRIC_ADD('prod', 'Production/BatchCount', batch_count);
        SPARKPLUG_METRIC_ADD('prod', 'Production/RejectCount', reject_count);
        state := 3;

    3: (* Publish birth certificate — Ignition auto-discovers all tags *)
        ok := SPARKPLUG_NODE_BIRTH('prod');
        IF ok THEN state := 4; END_IF;

    4: (* Subscribe to commands from Ignition *)
        ok := SPARKPLUG_CMD_SUBSCRIBE('prod');
        IF ok THEN state := 10; END_IF;

    10: (* Running — update metrics and publish *)
        (* Update metric values from process *)
        SPARKPLUG_METRIC_SET('prod', 'Line/Speed', line_speed);
        SPARKPLUG_METRIC_SET('prod', 'Motor/Temperature', motor_temp);
        SPARKPLUG_METRIC_SET('prod', 'Conveyor/Running', conveyor_running);
        SPARKPLUG_METRIC_SET('prod', 'Production/BatchCount', batch_count);
        SPARKPLUG_METRIC_SET('prod', 'Production/RejectCount', reject_count);

        (* Publish changed metrics every 10 scans (~1 second at 100ms scan) *)
        publish_counter := publish_counter + 1;
        IF publish_counter >= 10 THEN
            SPARKPLUG_NODE_DATA('prod');
            publish_counter := 0;
        END_IF;

        (* Handle setpoint commands from Ignition *)
        IF SPARKPLUG_CMD_HAS('prod', 'Line/SpeedSetpoint') THEN
            new_sp := SPARKPLUG_CMD_GET('prod', 'Line/SpeedSetpoint');
            speed_setpoint := new_sp;
            SPARKPLUG_METRIC_SET('prod', 'Line/SpeedSetpoint', speed_setpoint);
            SPARKPLUG_CMD_CLEAR('prod', 'Line/SpeedSetpoint');
        END_IF;

        (* Handle rebirth request *)
        IF SPARKPLUG_CMD_HAS('prod', 'Node Control/Rebirth') THEN
            SPARKPLUG_CMD_CLEAR('prod', 'Node Control/Rebirth');
            SPARKPLUG_NODE_BIRTH('prod');
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 7. Ignition SCADA Integration

### Connecting Ignition to GoPLC via Sparkplug

1. **Install Cirrus Link MQTT Transmission/Engine modules** in Ignition (or use the built-in Sparkplug support in Ignition 8.1+).

2. **Configure MQTT Engine** to connect to the same broker GoPLC uses:
   - Server URL: `tcp://10.0.0.144:1883`
   - Group ID filter: `Factory` (or leave blank for all)

3. **Start GoPLC** with the Sparkplug program above. Ignition auto-discovers the edge node and creates tags under:
   ```
   [MQTT Engine]Factory/Line1/GoPLC-Line1/Line/Speed
   [MQTT Engine]Factory/Line1/GoPLC-Line1/Motor/Temperature
   [MQTT Engine]Factory/Line1/GoPLC-Line1/Conveyor/Running
   ...
   ```

4. **Bind Ignition tags** to Vision/Perspective screens. Writes from Ignition flow back as NCMD messages, which GoPLC receives via `SPARKPLUG_CMD_HAS`/`SPARKPLUG_CMD_GET`.

### Tag Quality and Stale Detection

Ignition tracks tag quality based on Sparkplug lifecycle:

| Sparkplug Event | Ignition Tag Quality |
|-----------------|---------------------|
| NBIRTH received | Good |
| NDATA received | Good (updated) |
| NDEATH received | Bad (stale) |
| Sequence gap detected | Bad (stale) — Ignition requests rebirth |
| No NDATA for timeout period | Uncertain (stale) |

### Metric Naming Best Practices for Ignition

```iecst
(* Good — creates folder hierarchy in Ignition tag browser *)
SPARKPLUG_METRIC_ADD('prod', 'Line1/Motor/Speed', 0.0);
SPARKPLUG_METRIC_ADD('prod', 'Line1/Motor/Temperature', 0.0);
SPARKPLUG_METRIC_ADD('prod', 'Line1/Motor/Running', FALSE);
SPARKPLUG_METRIC_ADD('prod', 'Line1/Conveyor/Speed', 0.0);

(* Bad — flat namespace, hard to navigate in Ignition *)
SPARKPLUG_METRIC_ADD('prod', 'line1_motor_speed', 0.0);
SPARKPLUG_METRIC_ADD('prod', 'line1_motor_temp', 0.0);
```

---

## 8. Sparkplug B Message Lifecycle

### Startup Sequence

```
1. SPARKPLUG_NODE_CREATE()     → Create node (no network)
2. SPARKPLUG_METRIC_ADD() ×N   → Register all metrics
3. SPARKPLUG_NODE_CONNECT()    → MQTT CONNECT (registers NDEATH as LWT)
4. SPARKPLUG_NODE_BIRTH()      → Publish NBIRTH (retained, seq=0)
5. SPARKPLUG_CMD_SUBSCRIBE()   → Subscribe to NCMD
6. SPARKPLUG_NODE_DATA() loop  → Publish NDATA (changed metrics, seq++)
```

### Shutdown Sequence

```
1. SPARKPLUG_NODE_DEATH()      → Publish NDEATH explicitly
2. SPARKPLUG_NODE_DISCONNECT() → MQTT DISCONNECT (broker clears LWT)
3. SPARKPLUG_NODE_DELETE()     → Free resources
```

### Ungraceful Disconnect

```
1. Network drops / process crashes
2. Broker detects TCP timeout (keepalive, typically 60s)
3. Broker publishes NDEATH (from LWT registered at CONNECT)
4. Ignition marks all tags as Bad/Stale
5. GoPLC reconnects → goto Startup Sequence step 3
```

### Protobuf Payload Structure

Every Sparkplug message body is a Google Protocol Buffer (`org.eclipse.tahu.protobuf.Payload`):

```
Payload {
  timestamp: uint64       (ms since epoch)
  seq:       uint64       (0-255, wraps)
  metrics: [
    {
      name:      string   ("Temperature", "Motor/Speed")
      timestamp: uint64
      datatype:  uint32   (9=Int32, 10=Int64, 11=Float, 12=Double, 13=Boolean, 14=String)
      value:     oneof    (int_value, long_value, float_value, double_value, boolean_value, string_value)
    },
    ...
  ]
}
```

GoPLC handles all Protobuf encoding/decoding automatically. You work with native ST types (INT, REAL, BOOL, STRING) and GoPLC maps them to the correct Sparkplug data types.

---

## 9. Troubleshooting

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Ignition shows no tags | NBIRTH not published | Ensure `SPARKPLUG_NODE_BIRTH` is called after all metrics are added |
| Tags show Bad quality | NDEATH received | Check GoPLC connection to broker; verify keepalive |
| Stale data in Ignition | NDATA not publishing | Verify `SPARKPLUG_NODE_DATA` is called periodically |
| Ignition requests rebirth repeatedly | Sequence gap | Ensure no duplicate client IDs; check for network drops |
| Commands not arriving | NCMD not subscribed | Call `SPARKPLUG_CMD_SUBSCRIBE` after connecting |
| Metrics missing from birth | Added after NBIRTH | Add all metrics before calling `SPARKPLUG_NODE_BIRTH` |
| Broker rejects connection | Duplicate client ID | Use unique `clientID` per GoPLC instance |
| TLS handshake failure | Certificate mismatch | Verify broker CA cert and hostname match `ssl://` URL |

---

## Appendix A: Function Quick Reference

| Function | Params | Returns | Description |
|----------|--------|---------|-------------|
| `SPARKPLUG_NODE_CREATE` | `(name, groupID, edgeNodeID, brokerURL, clientID)` | BOOL | Create edge node |
| `SPARKPLUG_NODE_CREATE_AUTH` | `(name, groupID, edgeNodeID, brokerURL, clientID, username, password)` | BOOL | Create edge node with auth |
| `SPARKPLUG_NODE_CONNECT` | `(name)` | BOOL | Connect to broker (registers NDEATH as LWT) |
| `SPARKPLUG_NODE_DISCONNECT` | `(name)` | BOOL | Disconnect from broker |
| `SPARKPLUG_NODE_IS_CONNECTED` | `(name)` | BOOL | Check connection state |
| `SPARKPLUG_NODE_DELETE` | `(name)` | BOOL | Remove node and free resources |
| `SPARKPLUG_METRIC_ADD` | `(name, metricName, value)` | BOOL | Register metric with initial value |
| `SPARKPLUG_METRIC_SET` | `(name, metricName, value)` | BOOL | Update metric (marks changed) |
| `SPARKPLUG_METRIC_GET` | `(name, metricName)` | ANY | Read current local value |
| `SPARKPLUG_METRIC_GET_REAL` | `(name, metricName)` | REAL | Read metric as REAL |
| `SPARKPLUG_METRIC_GET_INT` | `(name, metricName)` | INT | Read metric as INT |
| `SPARKPLUG_METRIC_GET_BOOL` | `(name, metricName)` | BOOL | Read metric as BOOL |
| `SPARKPLUG_METRIC_GET_STR` | `(name, metricName)` | STRING | Read metric as STRING |
| `SPARKPLUG_NODE_BIRTH` | `(name)` | BOOL | Publish NBIRTH (full metric catalog) |
| `SPARKPLUG_NODE_DEATH` | `(name)` | BOOL | Publish NDEATH (explicit shutdown) |
| `SPARKPLUG_NODE_DATA` | `(name)` | BOOL | Publish NDATA (changed metrics only) |
| `SPARKPLUG_CMD_SUBSCRIBE` | `(name)` | BOOL | Subscribe to NCMD topic |
| `SPARKPLUG_CMD_HAS` | `(name, metricName)` | BOOL | Check if command arrived |
| `SPARKPLUG_CMD_GET` | `(name, metricName)` | ANY | Read commanded value |
| `SPARKPLUG_CMD_GET_REAL` | `(name, metricName)` | REAL | Read command as REAL |
| `SPARKPLUG_CMD_GET_INT` | `(name, metricName)` | INT | Read command as INT |
| `SPARKPLUG_CMD_GET_BOOL` | `(name, metricName)` | BOOL | Read command as BOOL |
| `SPARKPLUG_CMD_GET_STR` | `(name, metricName)` | STRING | Read command as STRING |
| `SPARKPLUG_CMD_CLEAR` | `(name, metricName)` | BOOL | Clear command flag |
| `SPARKPLUG_GET_SEQ` | `(name)` | INT | Current sequence number (0-255) |
| `SPARKPLUG_NODE_LIST` | `()` | STRING | Comma-separated node names |

---

*GoPLC v1.0.533 | Sparkplug B v3.0 | Eclipse Tahu Protobuf + MQTT 3.1.1*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
