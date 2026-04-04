# GoPLC Sparkplug B Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC implements a complete **Sparkplug B v3.0** edge node callable directly from IEC 61131-3 Structured Text. No Ignition modules, no Java dependencies, no external gateway software. GoPLC connects to any MQTT 3.1.1 broker (Mosquitto, EMQX, HiveMQ Cloud, AWS IoT) and speaks native Sparkplug B — Google Protocol Buffer payloads, proper birth/death lifecycle, sequence number management, and metric change detection built in.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Edge Node** | `SparkplugNodeCreate` / `SparkplugNodeBirth` / `SparkplugNodeData` | Publish PLC data to SCADA via Sparkplug-aware infrastructure |
| **Metrics** | `SparkplugMetricAdd` / `SparkplugMetricSet` / `SparkplugMetricGet` | Register and update named data points with automatic type detection |
| **Commands** | `SparkplugCmdSubscribe` / `SparkplugCmdGet` / `SparkplugCmdClear` | Receive write-back commands from SCADA (NCMD topic) |
| **Lifecycle** | `SparkplugNodeBirth` / `SparkplugNodeDeath` / `SparkplugNodeData` | Full NBIRTH/NDEATH/NDATA state management |

All functions are controlled entirely from IEC 61131-3 Structured Text in GoPLC's browser-based IDE.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ST Program                                             │  │
│  │                                                        │  │
│  │ SparkplugNodeCreate('node1', 'Plant/Line1',            │  │
│  │     'GoPLC-Edge1', 'tcp://broker:1883', 'goplc-sp1')  │  │
│  │ SparkplugMetricAdd('node1', 'Temperature', 72.5)       │  │
│  │ SparkplugMetricAdd('node1', 'MotorRunning', TRUE)      │  │
│  │ SparkplugNodeBirth('node1')   → NBIRTH                 │  │
│  │ SparkplugMetricSet('node1', 'Temperature', 73.1)       │  │
│  │ SparkplugNodeData('node1')    → NDATA (changed only)   │  │
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

### 2.1 SparkplugNodeCreate -- Create Edge Node

```iecst
ok := SparkplugNodeCreate('node1', 'Plant/Line1', 'GoPLC-Edge1',
                           'tcp://10.0.0.144:1883', 'goplc-sparkplug-1');
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Instance name (used in all subsequent calls) |
| `groupID` | STRING | Yes | Sparkplug group ID (e.g., `Plant/Line1`) |
| `edgeNodeID` | STRING | Yes | Unique edge node identifier |
| `brokerURL` | STRING | Yes | MQTT broker URL: `tcp://host:port` or `ssl://host:port` |
| `clientID` | STRING | Yes | MQTT client ID (must be unique per broker) |
| `username` | STRING | No | MQTT username for broker authentication |
| `password` | STRING | No | MQTT password for broker authentication |

Returns `TRUE` on success. The node is created but **not yet connected** -- call `SparkplugNodeConnect` next.

```iecst
(* No authentication *)
ok := SparkplugNodeCreate('node1', 'Plant', 'Edge1',
                           'tcp://broker:1883', 'goplc-sp-1');

(* With authentication *)
ok := SparkplugNodeCreate('node1', 'Plant', 'Edge1',
                           'tcp://broker:1883', 'goplc-sp-1',
                           'goplc_user', 's3cretP@ss');

(* TLS connection *)
ok := SparkplugNodeCreate('node1', 'Plant', 'Edge1',
                           'ssl://broker:8883', 'goplc-sp-1',
                           'goplc_user', 's3cretP@ss');
```

> **Client ID uniqueness:** If two nodes connect with the same client ID, the broker disconnects the first one. Use a unique ID per GoPLC instance — hostname or MAC address works well.

### 2.2 SparkplugNodeConnect / Disconnect / IsConnected

```iecst
(* Connect to broker — registers NDEATH as LWT *)
ok := SparkplugNodeConnect('node1');

(* Check connection state *)
IF SparkplugNodeIsConnected('node1') THEN
    (* publish metrics *)
END_IF;

(* Graceful disconnect — triggers NDEATH from broker LWT *)
SparkplugNodeDisconnect('node1');
```

`SparkplugNodeConnect` establishes the MQTT connection and registers the **NDEATH** message as the broker's Last Will and Testament (LWT). If GoPLC crashes or loses network, the broker publishes NDEATH automatically — Ignition and other consumers see the node go offline immediately.

### 2.3 SparkplugNodeDelete / SparkplugNodeList

```iecst
(* Remove a node *)
SparkplugNodeDelete('node1');

(* List all Sparkplug nodes *)
names := SparkplugNodeList();
(* Returns: ['node1', 'node2'] *)
```

---

## 3. Metrics

### 3.1 SparkplugMetricAdd -- Register a Metric

```iecst
(* Add metrics with initial values — type is auto-detected *)
ok := SparkplugMetricAdd('node1', 'Temperature', 72.5);       (* Float *)
ok := SparkplugMetricAdd('node1', 'MotorRunning', TRUE);      (* Boolean *)
ok := SparkplugMetricAdd('node1', 'BatchCount', 0);           (* Integer *)
ok := SparkplugMetricAdd('node1', 'RecipeName', 'Default');   (* String *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Node instance name |
| `metricName` | STRING | Metric name (appears in Sparkplug birth certificate and SCADA tag browser) |
| `value` | ANY | Initial value — type is inferred (BOOL, INT, REAL, STRING) |

Returns `TRUE` on success. Metrics must be added **before** calling `SparkplugNodeBirth` — the birth certificate includes the complete metric catalog.

> **Metric naming:** Use descriptive, hierarchical names. Ignition displays them as-is in the tag browser. `Line1/Motor/Speed` is better than `N7_0`. Sparkplug metric names support `/` separators — Ignition renders them as a folder tree.

### 3.2 SparkplugMetricSet -- Update a Metric Value

```iecst
(* Update metric — marks it as changed for next NDATA *)
ok := SparkplugMetricSet('node1', 'Temperature', 73.1);
ok := SparkplugMetricSet('node1', 'MotorRunning', FALSE);
ok := SparkplugMetricSet('node1', 'BatchCount', 42);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Node instance name |
| `metricName` | STRING | Metric name (must have been added with `SparkplugMetricAdd`) |
| `value` | ANY | New value |

Returns `TRUE` on success. This **does not** immediately publish — it marks the metric as changed. Call `SparkplugNodeData` to publish all changed metrics in a single NDATA message.

### 3.3 SparkplugMetricGet -- Read Current Value

```iecst
temp := SparkplugMetricGet('node1', 'Temperature');
(* Returns: 73.1 *)

running := SparkplugMetricGet('node1', 'MotorRunning');
(* Returns: TRUE *)
```

Returns the current local value of the metric. This reads from GoPLC's in-memory metric store, not from the broker.

---

## 4. Publishing

### 4.1 SparkplugNodeBirth -- Send NBIRTH

```iecst
ok := SparkplugNodeBirth('node1');
```

Publishes the **Node Birth Certificate** to `spBv1.0/{groupID}/NBIRTH/{edgeNodeID}`. The birth message contains:

- **All registered metrics** with their current values and Sparkplug data types
- **Sequence number** reset to 0
- **Timestamp** (milliseconds since epoch)

The birth certificate is a **retained** message — new subscribers (like Ignition connecting later) receive the full metric catalog immediately.

> **When to send NBIRTH:** Call `SparkplugNodeBirth` once after connecting and adding all metrics. If Ignition sends a rebirth request via NCMD, call it again to republish the full metric catalog.

### 4.2 SparkplugNodeDeath -- Send NDEATH

```iecst
ok := SparkplugNodeDeath('node1');
```

Publishes the **Node Death Certificate** to `spBv1.0/{groupID}/NDEATH/{edgeNodeID}`. This signals an intentional, graceful shutdown. The broker also publishes NDEATH automatically (via LWT) if the connection drops unexpectedly.

> **Graceful vs. ungraceful:** `SparkplugNodeDisconnect` triggers the broker's LWT (NDEATH). `SparkplugNodeDeath` sends it explicitly before disconnecting. Both result in the same NDEATH message reaching consumers — the distinction matters only for timing.

### 4.3 SparkplugNodeData -- Send NDATA (Changed Metrics Only)

```iecst
ok := SparkplugNodeData('node1');
```

Publishes an **NDATA** message containing **only metrics that changed** since the last NDATA or NBIRTH. This is the primary data publishing function — call it on every scan cycle or at your desired publish rate.

```iecst
(* Typical scan cycle pattern *)
SparkplugMetricSet('node1', 'Temperature', current_temp);
SparkplugMetricSet('node1', 'Pressure', current_pressure);
SparkplugMetricSet('node1', 'MotorRunning', motor_fb);

(* Publish only changed values *)
SparkplugNodeData('node1');
```

If no metrics have changed, `SparkplugNodeData` returns `TRUE` without publishing — no empty messages are sent. The sequence number only increments when a message is actually published.

### 4.4 SparkplugGetSeq -- Current Sequence Number

```iecst
seq := SparkplugGetSeq('node1');
(* Returns: 42 — current sequence number (0-255, wraps) *)
```

Returns the current Sparkplug sequence number. Consumers use this to detect missed messages — a gap in the sequence means data was lost and a rebirth should be requested.

---

## 5. Commands (NCMD)

### 5.1 SparkplugCmdSubscribe -- Listen for SCADA Commands

```iecst
ok := SparkplugCmdSubscribe('node1');
```

Subscribes to the NCMD topic: `spBv1.0/{groupID}/NCMD/{edgeNodeID}`. SCADA systems (Ignition, etc.) publish NCMD messages to write values back to the edge node — setpoints, mode changes, rebirth requests.

### 5.2 SparkplugCmdHas / CmdGet / CmdClear

```iecst
(* Check if a command arrived for a specific metric *)
IF SparkplugCmdHas('node1', 'Setpoint') THEN
    (* Read the commanded value *)
    new_sp := SparkplugCmdGet('node1', 'Setpoint');
    (* Apply it *)
    target_temp := new_sp;
    (* Clear the command flag *)
    SparkplugCmdClear('node1', 'Setpoint');
END_IF;

(* Handle rebirth request from Ignition *)
IF SparkplugCmdHas('node1', 'Node Control/Rebirth') THEN
    SparkplugCmdClear('node1', 'Node Control/Rebirth');
    SparkplugNodeBirth('node1');  (* republish full metric catalog *)
END_IF;
```

| Function | Params | Returns | Description |
|----------|--------|---------|-------------|
| `SparkplugCmdHas` | `(name, metricName)` | BOOL | Check if a command arrived |
| `SparkplugCmdGet` | `(name, metricName)` | ANY | Read the commanded value |
| `SparkplugCmdClear` | `(name, metricName)` | BOOL | Clear the command flag |

> **Ignition rebirth:** When Ignition connects to a broker and finds an existing edge node, it sends a rebirth request via NCMD with metric name `Node Control/Rebirth`. Your ST program must handle this by calling `SparkplugNodeBirth` to republish the full metric catalog.

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
        ok := SparkplugNodeCreate('prod', 'Factory/Line1', 'GoPLC-Line1',
                                   'tcp://10.0.0.144:1883', 'goplc-line1-sp');
        IF ok THEN state := 1; END_IF;

    1: (* Connect to broker *)
        ok := SparkplugNodeConnect('prod');
        IF ok THEN state := 2; END_IF;

    2: (* Register all metrics *)
        SparkplugMetricAdd('prod', 'Line/Speed', line_speed);
        SparkplugMetricAdd('prod', 'Line/SpeedSetpoint', speed_setpoint);
        SparkplugMetricAdd('prod', 'Motor/Temperature', motor_temp);
        SparkplugMetricAdd('prod', 'Conveyor/Running', conveyor_running);
        SparkplugMetricAdd('prod', 'Production/BatchCount', batch_count);
        SparkplugMetricAdd('prod', 'Production/RejectCount', reject_count);
        state := 3;

    3: (* Publish birth certificate — Ignition auto-discovers all tags *)
        ok := SparkplugNodeBirth('prod');
        IF ok THEN state := 4; END_IF;

    4: (* Subscribe to commands from Ignition *)
        ok := SparkplugCmdSubscribe('prod');
        IF ok THEN state := 10; END_IF;

    10: (* Running — update metrics and publish *)
        (* Update metric values from process *)
        SparkplugMetricSet('prod', 'Line/Speed', line_speed);
        SparkplugMetricSet('prod', 'Motor/Temperature', motor_temp);
        SparkplugMetricSet('prod', 'Conveyor/Running', conveyor_running);
        SparkplugMetricSet('prod', 'Production/BatchCount', batch_count);
        SparkplugMetricSet('prod', 'Production/RejectCount', reject_count);

        (* Publish changed metrics every 10 scans (~1 second at 100ms scan) *)
        publish_counter := publish_counter + 1;
        IF publish_counter >= 10 THEN
            SparkplugNodeData('prod');
            publish_counter := 0;
        END_IF;

        (* Handle setpoint commands from Ignition *)
        IF SparkplugCmdHas('prod', 'Line/SpeedSetpoint') THEN
            new_sp := SparkplugCmdGet('prod', 'Line/SpeedSetpoint');
            speed_setpoint := new_sp;
            SparkplugMetricSet('prod', 'Line/SpeedSetpoint', speed_setpoint);
            SparkplugCmdClear('prod', 'Line/SpeedSetpoint');
        END_IF;

        (* Handle rebirth request *)
        IF SparkplugCmdHas('prod', 'Node Control/Rebirth') THEN
            SparkplugCmdClear('prod', 'Node Control/Rebirth');
            SparkplugNodeBirth('prod');
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

4. **Bind Ignition tags** to Vision/Perspective screens. Writes from Ignition flow back as NCMD messages, which GoPLC receives via `SparkplugCmdHas`/`SparkplugCmdGet`.

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
SparkplugMetricAdd('prod', 'Line1/Motor/Speed', 0.0);
SparkplugMetricAdd('prod', 'Line1/Motor/Temperature', 0.0);
SparkplugMetricAdd('prod', 'Line1/Motor/Running', FALSE);
SparkplugMetricAdd('prod', 'Line1/Conveyor/Speed', 0.0);

(* Bad — flat namespace, hard to navigate in Ignition *)
SparkplugMetricAdd('prod', 'line1_motor_speed', 0.0);
SparkplugMetricAdd('prod', 'line1_motor_temp', 0.0);
```

---

## 8. Sparkplug B Message Lifecycle

### Startup Sequence

```
1. SparkplugNodeCreate()     → Create node (no network)
2. SparkplugMetricAdd() ×N   → Register all metrics
3. SparkplugNodeConnect()    → MQTT CONNECT (registers NDEATH as LWT)
4. SparkplugNodeBirth()      → Publish NBIRTH (retained, seq=0)
5. SparkplugCmdSubscribe()   → Subscribe to NCMD
6. SparkplugNodeData() loop  → Publish NDATA (changed metrics, seq++)
```

### Shutdown Sequence

```
1. SparkplugNodeDeath()      → Publish NDEATH explicitly
2. SparkplugNodeDisconnect() → MQTT DISCONNECT (broker clears LWT)
3. SparkplugNodeDelete()     → Free resources
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
| Ignition shows no tags | NBIRTH not published | Ensure `SparkplugNodeBirth` is called after all metrics are added |
| Tags show Bad quality | NDEATH received | Check GoPLC connection to broker; verify keepalive |
| Stale data in Ignition | NDATA not publishing | Verify `SparkplugNodeData` is called periodically |
| Ignition requests rebirth repeatedly | Sequence gap | Ensure no duplicate client IDs; check for network drops |
| Commands not arriving | NCMD not subscribed | Call `SparkplugCmdSubscribe` after connecting |
| Metrics missing from birth | Added after NBIRTH | Add all metrics before calling `SparkplugNodeBirth` |
| Broker rejects connection | Duplicate client ID | Use unique `clientID` per GoPLC instance |
| TLS handshake failure | Certificate mismatch | Verify broker CA cert and hostname match `ssl://` URL |

---

## Appendix A: Function Quick Reference

| Function | Params | Returns | Description |
|----------|--------|---------|-------------|
| `SparkplugNodeCreate` | `(name, groupID, edgeNodeID, brokerURL, clientID [, username, password])` | BOOL | Create edge node |
| `SparkplugNodeConnect` | `(name)` | BOOL | Connect to broker (registers NDEATH as LWT) |
| `SparkplugNodeDisconnect` | `(name)` | BOOL | Disconnect from broker |
| `SparkplugNodeIsConnected` | `(name)` | BOOL | Check connection state |
| `SparkplugNodeDelete` | `(name)` | BOOL | Remove node and free resources |
| `SparkplugMetricAdd` | `(name, metricName, value)` | BOOL | Register metric with initial value |
| `SparkplugMetricSet` | `(name, metricName, value)` | BOOL | Update metric (marks changed) |
| `SparkplugMetricGet` | `(name, metricName)` | ANY | Read current local value |
| `SparkplugNodeBirth` | `(name)` | BOOL | Publish NBIRTH (full metric catalog) |
| `SparkplugNodeDeath` | `(name)` | BOOL | Publish NDEATH (explicit shutdown) |
| `SparkplugNodeData` | `(name)` | BOOL | Publish NDATA (changed metrics only) |
| `SparkplugCmdSubscribe` | `(name)` | BOOL | Subscribe to NCMD topic |
| `SparkplugCmdHas` | `(name, metricName)` | BOOL | Check if command arrived |
| `SparkplugCmdGet` | `(name, metricName)` | ANY | Read commanded value |
| `SparkplugCmdClear` | `(name, metricName)` | BOOL | Clear command flag |
| `SparkplugGetSeq` | `(name)` | INT | Current sequence number (0-255) |
| `SparkplugNodeList` | `()` | []STRING | List all Sparkplug nodes |

---

*GoPLC v1.0.520 | Sparkplug B v3.0 | Eclipse Tahu Protobuf + MQTT 3.1.1*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
