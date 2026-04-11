# GoPLC MQTT Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC provides a **full MQTT 3.1.1 stack** — both client and broker — as native ST functions. No external libraries, no sidecar containers. An MQTT client can connect to any standard broker (Mosquitto, EMQX, HiveMQ, cloud IoT endpoints), and the built-in broker turns any GoPLC instance into a self-contained edge message bus.

There are **two sides** to the MQTT implementation:

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `MQTT_CLIENT_CREATE` / `MQTT_PUBLISH` / `MQTT_SUBSCRIBE` | Connect to external brokers, publish telemetry, react to commands |
| **Broker** | `MQTT_BROKER_CREATE` / `MQTT_BROKER_START` | Run a broker inside GoPLC for edge deployments, local device-to-device messaging |

Both roles are controlled entirely from IEC 61131-3 Structured Text in GoPLC's browser-based IDE.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows/macOS host)            │
│                                                              │
│  ┌──────────────────────┐    ┌─────────────────────────────┐ │
│  │ ST Program            │    │ Built-in MQTT Broker        │ │
│  │                       │    │ (optional)                  │ │
│  │ MQTT_CLIENT_CREATE()  │    │                             │ │
│  │ MQTT_PUBLISH()        │◄──►│ MQTT_BROKER_CREATE()        │ │
│  │ MQTT_SUBSCRIBE()      │    │ TCP :1883  WS :9001         │ │
│  │ MQTT_GET_MESSAGE()    │    │                             │ │
│  └───────────┬───────────┘    └──────────┬──────────────────┘ │
│              │                           │                    │
└──────────────┼───────────────────────────┼────────────────────┘
               │ TCP/TLS                   │ TCP/WS
               ▼                           ▼
┌──────────────────────┐    ┌──────────────────────────────────┐
│  External Broker      │    │  External Clients                │
│  (Mosquitto, EMQX,   │    │  Node-RED, Grafana, SCADA,      │
│   AWS IoT, HiveMQ)   │    │  mobile apps, other PLCs        │
└──────────────────────┘    └──────────────────────────────────┘
```

### MQTT Concepts Quick Reference

| Concept | Description |
|---------|-------------|
| **Broker** | Central message router — clients connect to it |
| **Topic** | Hierarchical path (e.g., `plant/line1/temp`) — no pre-registration needed |
| **Publish** | Send a message to a topic |
| **Subscribe** | Register interest in a topic (wildcards: `+` single level, `#` multi-level) |
| **QoS 0** | Fire and forget — fastest, no delivery guarantee |
| **QoS 1** | At least once — message acknowledged, may duplicate |
| **QoS 2** | Exactly once — two-phase handshake, slowest |
| **Retained** | Broker stores last message per topic — new subscribers get it immediately |

---

## 2. Client Functions

### 2.1 Connection Lifecycle

#### MQTT_CLIENT_CREATE -- Create Client (No Auth)

```iecst
ok := MQTT_CLIENT_CREATE('plant1', 'tcp://10.0.0.144:1883', 'goplc-plant1');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Instance name (used in all subsequent calls) |
| `broker` | STRING | Broker URL: `tcp://host:port` or `ssl://host:port` |
| `clientID` | STRING | Unique client identifier (broker uses this to track sessions) |

Returns `TRUE` on success. The client is created but **not yet connected** -- call `MQTT_CLIENT_CONNECT` next.

> **Client ID uniqueness:** If two clients connect to the same broker with the same client ID, the broker disconnects the first one. Use unique IDs per GoPLC instance (hostname, MAC address, or serial number work well).

#### MQTT_CLIENT_CREATE_AUTH -- Create Client with Credentials

```iecst
ok := MQTT_CLIENT_CREATE_AUTH('cloud', 'ssl://broker.hivemq.cloud:8883',
                              'goplc-edge-01', 'myuser', 'mypassword');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Instance name |
| `broker` | STRING | Broker URL (use `ssl://` for TLS) |
| `clientID` | STRING | Unique client identifier |
| `username` | STRING | Authentication username |
| `password` | STRING | Authentication password |

#### MQTT_CLIENT_CONNECT -- Establish Connection

```iecst
ok := MQTT_CLIENT_CONNECT('plant1');
```

Initiates the TCP connection and MQTT handshake. Returns `TRUE` when connected. Subscriptions set up before connecting are automatically re-subscribed on reconnection.

Aliases: `MQTT_CONNECT('plant1')` does the same thing.

#### MQTT_CLIENT_DISCONNECT -- Graceful Disconnect

```iecst
ok := MQTT_CLIENT_DISCONNECT('plant1');
```

Sends MQTT DISCONNECT packet and closes the TCP socket. The client instance remains configured -- you can reconnect later with `MQTT_CLIENT_CONNECT`.

Aliases: `MQTT_DISCONNECT('plant1')`.

#### MQTT_CLIENT_IS_CONNECTED -- Connection Status

```iecst
IF MQTT_CLIENT_IS_CONNECTED('plant1') THEN
    (* Safe to publish *)
END_IF;
```

Returns `TRUE` if the client has an active broker connection. Use this to guard publish calls or trigger reconnection logic.

Aliases: `MQTT_IS_CONNECTED('plant1')`.

#### MQTT_CLIENT_DELETE -- Remove Client

```iecst
ok := MQTT_CLIENT_DELETE('plant1');
```

Disconnects (if connected) and removes the client instance entirely. Frees all associated resources and message buffers.

#### MQTT_CLIENT_LIST -- Enumerate Clients

```iecst
clients := MQTT_CLIENT_LIST();
(* Returns: ['plant1', 'cloud', 'local'] *)
```

Returns an array of all active client instance names.

---

### 2.2 Publishing

#### MQTT_PUBLISH -- Publish a Message

```iecst
(* Basic — QoS 0, not retained (defaults) *)
ok := MQTT_PUBLISH('plant1', 'line1/temperature', '72.5');

(* With explicit QoS *)
ok := MQTT_PUBLISH('plant1', 'line1/temperature', '72.5', 1);

(* With QoS and retained flag *)
ok := MQTT_PUBLISH('plant1', 'line1/temperature', '72.5', 1, TRUE);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client instance name |
| `topic` | STRING | MQTT topic path |
| `payload` | ANY | Message content (converted to string) |
| `qos` | INT | *(optional)* 0, 1, or 2. Default: 0 |
| `retained` | BOOL | *(optional)* Broker stores as last-known-good. Default: FALSE |

Returns `TRUE` if the message was queued for delivery (QoS 0) or acknowledged by the broker (QoS 1/2).

#### MQTT_PUBLISH_JSON -- Publish Structured Data

```iecst
ok := MQTT_PUBLISH_JSON('plant1', 'line1/status',
    JSON_OBJECT('temp', 72.5, 'pressure', 14.7, 'running', TRUE));

(* With QoS *)
ok := MQTT_PUBLISH_JSON('plant1', 'line1/status',
    JSON_OBJECT('temp', 72.5, 'pressure', 14.7), 1);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client instance name |
| `topic` | STRING | MQTT topic path |
| `value` | ANY | Value to serialize as JSON |
| `qos` | INT | *(optional)* QoS level |

Automatically serializes the value to a JSON string before publishing. Useful for structured telemetry payloads that downstream systems (Node-RED, Grafana, InfluxDB) can parse without custom logic.

#### MQTT_PUBLISH_RETAINED -- Publish with Retained Flag

```iecst
ok := MQTT_PUBLISH_RETAINED('plant1', 'line1/config/setpoint', '150.0');
```

Convenience wrapper: publishes with the retained flag set to `TRUE` at the client's default QoS. Retained messages are stored by the broker and delivered immediately to any new subscriber on that topic.

> **When to retain:** Use retained messages for configuration values, device status, and last-known readings. Do **not** retain high-frequency telemetry -- the broker only stores the last message per topic, and retained messages persist across broker restarts.

---

### 2.3 Subscribing

#### MQTT_SUBSCRIBE -- Subscribe to a Topic

```iecst
(* Subscribe to a specific topic *)
ok := MQTT_SUBSCRIBE('plant1', 'line1/temperature');

(* Subscribe with explicit QoS *)
ok := MQTT_SUBSCRIBE('plant1', 'line1/temperature', 1);

(* Wildcard — all sensors on line 1 *)
ok := MQTT_SUBSCRIBE('plant1', 'line1/+/value');

(* Wildcard — everything under plant *)
ok := MQTT_SUBSCRIBE('plant1', 'plant/#');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client instance name |
| `topic` | STRING | Topic or topic filter (supports `+` and `#` wildcards) |
| `qos` | INT | *(optional)* Maximum QoS level for received messages |

GoPLC stores the **last received message** for each subscribed topic. Retrieve it with `MQTT_GET_MESSAGE`.

> **Wildcard rules:** `+` matches exactly one topic level (`line1/+/temp` matches `line1/zone3/temp` but not `line1/zone3/sub/temp`). `#` matches zero or more levels and must be the last character (`plant/#` matches everything under `plant/`).

#### MQTT_UNSUBSCRIBE -- Remove Subscription

```iecst
ok := MQTT_UNSUBSCRIBE('plant1', 'line1/temperature');
```

Sends an UNSUBSCRIBE packet to the broker. Incoming messages on that topic are no longer stored.

---

### 2.4 Receiving Messages

#### MQTT_GET_MESSAGE -- Read Last Message (String)

```iecst
payload := MQTT_GET_MESSAGE('plant1', 'line1/temperature');
(* Returns: '72.5' — the last message received on this topic *)
```

Returns the payload of the most recently received message on the given topic as a STRING. Returns empty string if no message has been received.

#### MQTT_GET_MESSAGE_INT -- Read as Integer

```iecst
setpoint := MQTT_GET_MESSAGE_INT('plant1', 'line1/setpoint');
(* Returns: 150 *)
```

Parses the last message payload as an integer. Returns 0 if no message exists or parsing fails.

#### MQTT_GET_MESSAGE_REAL -- Read as Float

```iecst
temp := MQTT_GET_MESSAGE_REAL('plant1', 'line1/temperature');
(* Returns: 72.5 *)
```

#### MQTT_GET_MESSAGE_BOOL -- Read as Boolean

```iecst
running := MQTT_GET_MESSAGE_BOOL('plant1', 'line1/motor/running');
(* Returns: TRUE — parses 'true', '1', 'on', 'yes' as TRUE *)
```

#### MQTT_GET_MESSAGE_JSON -- Read as Parsed JSON

```iecst
data := MQTT_GET_MESSAGE_JSON('plant1', 'line1/status');
temp := JSON_GET_REAL(data, 'temp');
pressure := JSON_GET_REAL(data, 'pressure');
running := JSON_GET_BOOL(data, 'running');
```

Returns the last message as a parsed JSON object. Use with `JSON_GET_*` functions to extract fields.

#### MQTT_HAS_MESSAGE -- Check for Message

```iecst
IF MQTT_HAS_MESSAGE('plant1', 'line1/temperature') THEN
    temp := MQTT_GET_MESSAGE_REAL('plant1', 'line1/temperature');
END_IF;
```

Returns `TRUE` if at least one message has been received on the topic since the last `MQTT_CLEAR_MESSAGE` (or since subscription).

#### MQTT_GET_MESSAGE_AGE -- Staleness Detection

```iecst
age_ms := MQTT_GET_MESSAGE_AGE('plant1', 'line1/temperature');
IF age_ms > 5000 THEN
    (* No update in 5 seconds — sensor may be offline *)
    alarm_stale_data := TRUE;
END_IF;
```

Returns milliseconds since the last message was received on the topic. Returns -1 if no message exists. Essential for detecting stale data from devices that publish on a fixed interval.

---

### 2.5 Message Management

#### MQTT_CLEAR_MESSAGE -- Clear Stored Message

```iecst
ok := MQTT_CLEAR_MESSAGE('plant1', 'line1/temperature');
```

Removes the stored message for a specific topic. `MQTT_HAS_MESSAGE` will return `FALSE` until a new message arrives.

#### MQTT_CLEAR_ALL -- Clear All Stored Messages

```iecst
ok := MQTT_CLEAR_ALL('plant1');
```

Removes all stored messages for the client. Useful during initialization or mode changes.

---

### 2.6 Message Queue

For topics that receive bursts of messages faster than your scan cycle processes them, the message queue captures every message rather than only retaining the last one.

#### MQTT_QUEUE_LENGTH -- Queued Message Count

```iecst
pending := MQTT_QUEUE_LENGTH('plant1');
```

Returns the number of messages waiting in the client's queue.

#### MQTT_QUEUE_POP -- Consume Oldest Message

```iecst
msg := MQTT_QUEUE_POP('plant1');
(* Returns the oldest queued message and removes it *)
```

Returns the oldest queued message as a STRING and removes it from the queue. Returns empty string if the queue is empty. Use in a loop to drain bursts.

#### MQTT_QUEUE_PEEK -- Inspect Without Consuming

```iecst
msg := MQTT_QUEUE_PEEK('plant1');
(* Returns the oldest queued message WITHOUT removing it *)
```

Same as `MQTT_QUEUE_POP` but leaves the message in the queue. Useful for conditional processing — peek first, pop only if you can handle it.

---

### 2.7 Client Configuration

#### MQTT_SET_QOS -- Default QoS Level

```iecst
ok := MQTT_SET_QOS('plant1', 1);
```

Sets the default QoS for all subsequent `MQTT_PUBLISH` calls that don't specify an explicit QoS parameter. Default is 0.

| QoS | Delivery | Overhead | Use Case |
|-----|----------|----------|----------|
| 0 | At most once | Lowest | High-frequency telemetry, sensor readings |
| 1 | At least once | Medium | Commands, alarms, events |
| 2 | Exactly once | Highest | Financial transactions, safety-critical commands |

#### MQTT_SET_RETAINED -- Default Retained Flag

```iecst
ok := MQTT_SET_RETAINED('plant1', TRUE);
```

Sets the default retained flag for all subsequent `MQTT_PUBLISH` calls.

#### MQTT_GET_BROKER -- Read Broker URL

```iecst
url := MQTT_GET_BROKER('plant1');
(* Returns: 'tcp://10.0.0.144:1883' *)
```

#### MQTT_GET_CLIENT_ID -- Read Client ID

```iecst
id := MQTT_GET_CLIENT_ID('plant1');
(* Returns: 'goplc-plant1' *)
```

---

## 3. Broker (Server) Functions

GoPLC can run a fully functional MQTT broker inside the runtime. This eliminates external dependencies for edge deployments, local device networks, and test environments.

### 3.1 Broker Lifecycle

#### MQTT_BROKER_CREATE -- Create Broker (No Auth)

```iecst
ok := MQTT_BROKER_CREATE('edge', 1883, 9001);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Broker instance name |
| `tcpPort` | INT | TCP listener port (standard: 1883) |
| `wsPort` | INT | WebSocket listener port (standard: 9001, 0 to disable) |

Creates a broker instance with both TCP and WebSocket listeners. WebSocket support allows browser-based MQTT clients (MQTT.js, Paho) to connect directly.

#### MQTT_BROKER_CREATE_AUTH -- Create Broker with Credentials

```iecst
ok := MQTT_BROKER_CREATE_AUTH('secure', 1883, 9001, 'admin', 's3cret');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Broker instance name |
| `tcpPort` | INT | TCP listener port |
| `wsPort` | INT | WebSocket listener port (0 to disable) |
| `username` | STRING | Required username for connecting clients |
| `password` | STRING | Required password for connecting clients |

> **Single credential pair:** The built-in broker supports one username/password combination. All connecting clients must use these credentials. For multi-user authentication, use an external broker (Mosquitto, EMQX).

#### MQTT_BROKER_START -- Start Listening

```iecst
ok := MQTT_BROKER_START('edge');
```

Opens the TCP and WebSocket ports and begins accepting client connections.

#### MQTT_BROKER_STOP -- Stop Listening

```iecst
ok := MQTT_BROKER_STOP('edge');
```

Disconnects all clients and closes the listener ports. The broker instance remains configured -- call `MQTT_BROKER_START` to resume.

#### MQTT_BROKER_DELETE -- Remove Broker

```iecst
ok := MQTT_BROKER_DELETE('edge');
```

Stops (if running) and removes the broker instance entirely.

### 3.2 Broker Monitoring

#### MQTT_BROKER_STATS -- Broker Statistics

```iecst
stats := MQTT_BROKER_STATS('edge');
(* Returns JSON:
   {"clients_connected": 4, "messages_received": 12847,
    "messages_sent": 38541, "subscriptions": 12,
    "bytes_received": 524288, "bytes_sent": 1572864,
    "uptime_seconds": 86400} *)
```

Returns a JSON string with broker health metrics. Publish these to InfluxDB or expose via Modbus for SCADA monitoring.

#### MQTT_BROKER_CLIENTS -- Connected Client List

```iecst
clients := MQTT_BROKER_CLIENTS('edge');
(* Returns JSON:
   [{"client_id": "nodered-01", "ip": "10.0.0.50", "subscriptions": 3},
    {"client_id": "grafana-ds", "ip": "10.0.0.144", "subscriptions": 8}] *)
```

Returns a JSON array describing all currently connected clients. Useful for diagnostics and security auditing.

#### MQTT_BROKER_IS_RUNNING -- Check Broker State

```iecst
IF NOT MQTT_BROKER_IS_RUNNING('edge') THEN
    MQTT_BROKER_START('edge');
END_IF;
```

Returns `TRUE` if the broker is actively listening for connections.

#### MQTT_BROKER_KICK -- Disconnect a Client

```iecst
ok := MQTT_BROKER_KICK('edge', 'rogue-client-42');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Broker name |
| `client_id` | STRING | Client ID to disconnect |

Forcibly disconnects a client from the broker. Use with `MQTT_BROKER_CLIENTS` to identify unwanted connections.

#### MQTT_BROKER_PUBLISH -- Publish from Broker

```iecst
ok := MQTT_BROKER_PUBLISH('edge', 'system/announce', 'GoPLC broker online');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Broker name |
| `topic` | STRING | Topic to publish on |
| `payload` | STRING | Message payload |

Publishes a message directly from the broker to all subscribers of the topic. Unlike `MQTT_PUBLISH` (which sends from a client), this originates from the broker itself.

#### MQTT_BROKER_LIST -- List All Brokers

```iecst
brokers := MQTT_BROKER_LIST();
(* Returns: 'edge,secure' — comma-separated names *)
```

Returns the names of all configured broker instances.

---

## 4. Complete Examples

### 4.1 Telemetry Publisher

Reads process data every scan cycle and publishes it to an external broker at a controlled rate.

```iecst
PROGRAM POU_Telemetry
VAR
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;
    publish_interval : DINT := 10;     (* Every 10 scans = 1 sec at 100ms task *)
    ok : BOOL;

    (* Process variables — populated by other programs or I/O *)
    tank_level : REAL := 0.0;
    flow_rate : REAL := 0.0;
    pump_running : BOOL := FALSE;
    pressure_psi : REAL := 0.0;
END_VAR

(* --- One-time initialization --- *)
IF NOT initialized THEN
    MQTT_CLIENT_CREATE_AUTH('telemetry', 'tcp://10.0.0.144:1883',
                           'goplc-line1', 'plc_user', 'plc_pass');
    MQTT_SET_QOS('telemetry', 1);
    MQTT_CLIENT_CONNECT('telemetry');
    initialized := TRUE;
END_IF;

(* --- Periodic publish --- *)
scan_count := scan_count + 1;

IF (scan_count MOD publish_interval) = 0 THEN
    IF MQTT_CLIENT_IS_CONNECTED('telemetry') THEN

        (* Individual topics — simple, easy to subscribe selectively *)
        MQTT_PUBLISH('telemetry', 'plant/line1/tank_level',
                     REAL_TO_STRING(tank_level));
        MQTT_PUBLISH('telemetry', 'plant/line1/flow_rate',
                     REAL_TO_STRING(flow_rate));
        MQTT_PUBLISH('telemetry', 'plant/line1/pump_running',
                     BOOL_TO_STRING(pump_running));

        (* Bundled JSON — single topic, all values at once *)
        MQTT_PUBLISH_JSON('telemetry', 'plant/line1/all',
            JSON_OBJECT(
                'tank_level', tank_level,
                'flow_rate', flow_rate,
                'pump_running', pump_running,
                'pressure_psi', pressure_psi,
                'timestamp', NOW_STR()
            ));

    ELSE
        (* Reconnect if connection dropped *)
        MQTT_CLIENT_CONNECT('telemetry');
    END_IF;
END_IF;

END_PROGRAM
```

> **Topic hierarchy design:** Use a consistent hierarchy: `{site}/{area}/{variable}`. This enables wildcard subscriptions -- a plant dashboard subscribes to `plant/#`, while a line-specific display subscribes to `plant/line1/+`.

---

### 4.2 Subscribe and React

Listens for setpoint changes and commands from an external system (SCADA, Node-RED, or mobile app).

```iecst
PROGRAM POU_CommandHandler
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;

    (* Received values *)
    new_setpoint : REAL;
    cmd : STRING;
    cmd_age : INT;

    (* Process outputs *)
    active_setpoint : REAL := 100.0;
    pump_enable : BOOL := FALSE;
    alarm_ack : BOOL := FALSE;
END_VAR

(* --- One-time initialization --- *)
IF NOT initialized THEN
    MQTT_CLIENT_CREATE('cmd', 'tcp://10.0.0.144:1883', 'goplc-cmd-rx');
    MQTT_SUBSCRIBE('cmd', 'plant/line1/setpoint', 1);
    MQTT_SUBSCRIBE('cmd', 'plant/line1/command', 1);
    MQTT_SUBSCRIBE('cmd', 'plant/line1/pump_enable', 1);
    MQTT_CLIENT_CONNECT('cmd');
    initialized := TRUE;
END_IF;

(* --- Process incoming setpoint --- *)
IF MQTT_HAS_MESSAGE('cmd', 'plant/line1/setpoint') THEN
    new_setpoint := MQTT_GET_MESSAGE_REAL('cmd', 'plant/line1/setpoint');
    IF new_setpoint >= 0.0 AND new_setpoint <= 500.0 THEN
        active_setpoint := new_setpoint;
    END_IF;
END_IF;

(* --- Process pump enable/disable --- *)
IF MQTT_HAS_MESSAGE('cmd', 'plant/line1/pump_enable') THEN
    pump_enable := MQTT_GET_MESSAGE_BOOL('cmd', 'plant/line1/pump_enable');
END_IF;

(* --- Process text commands --- *)
IF MQTT_HAS_MESSAGE('cmd', 'plant/line1/command') THEN
    cmd := MQTT_GET_MESSAGE('cmd', 'plant/line1/command');
    cmd_age := MQTT_GET_MESSAGE_AGE('cmd', 'plant/line1/command');

    (* Only act on recent commands — ignore stale messages from before boot *)
    IF cmd_age < 5000 THEN
        IF cmd = 'ACK_ALARM' THEN
            alarm_ack := TRUE;
            MQTT_CLEAR_MESSAGE('cmd', 'plant/line1/command');
        ELSIF cmd = 'RESET' THEN
            active_setpoint := 100.0;
            pump_enable := FALSE;
            MQTT_CLEAR_MESSAGE('cmd', 'plant/line1/command');
        END_IF;
    END_IF;
END_IF;

END_PROGRAM
```

> **Stale message protection:** Always check `MQTT_GET_MESSAGE_AGE` before acting on commands. When GoPLC starts and re-subscribes, the broker may deliver retained messages that were published hours ago. The age check prevents acting on stale commands.

---

### 4.3 Built-in Broker for Edge Deployment

Run a self-contained MQTT bus inside GoPLC for environments with no external broker -- remote sites, mobile equipment, factory cells with isolated networks.

```iecst
PROGRAM POU_EdgeBroker
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    scan_count : DINT := 0;
    stats : STRING;
END_VAR

(* --- Start built-in broker --- *)
IF NOT initialized THEN
    (* TCP on 1883, WebSocket on 9001 *)
    MQTT_BROKER_CREATE_AUTH('edge', 1883, 9001, 'edge_user', 'edge_pass');
    MQTT_BROKER_START('edge');

    (* Create a local client that connects to our own broker *)
    MQTT_CLIENT_CREATE_AUTH('local', 'tcp://127.0.0.1:1883',
                           'goplc-internal', 'edge_user', 'edge_pass');
    MQTT_SUBSCRIBE('local', 'devices/#');
    MQTT_CLIENT_CONNECT('local');

    initialized := TRUE;
END_IF;

(* --- Publish broker health every 30 seconds --- *)
scan_count := scan_count + 1;
IF (scan_count MOD 300) = 0 THEN
    stats := MQTT_BROKER_STATS('edge');
    MQTT_PUBLISH('local', 'broker/stats', stats);
END_IF;

(* --- React to messages from field devices --- *)
IF MQTT_HAS_MESSAGE('local', 'devices/sensor1/temp') THEN
    (* Process sensor data, run control logic, etc. *)
END_IF;

END_PROGRAM
```

In this pattern, GoPLC acts as both the message broker and a processing node. External devices (sensors, other PLCs, HMIs) connect to `tcp://<goplc-ip>:1883` and publish/subscribe normally. The browser-based HMI can connect via WebSocket on port 9001.

```
┌──────────────┐     ┌──────────────────────────────────────┐
│  Sensor Node  │────►│  GoPLC (10.0.0.196)                  │
│  ESP32 + MQTT │     │                                      │
└──────────────┘     │  ┌──────────────┐  ┌──────────────┐  │
                     │  │ MQTT Broker   │  │ ST Programs   │  │
┌──────────────┐     │  │ :1883 (TCP)   │◄►│ Control logic │  │
│  HMI Browser  │◄──►│  │ :9001 (WS)    │  │ Data logging  │  │
│  MQTT.js/WS   │     │  └──────────────┘  └──────────────┘  │
└──────────────┘     │                                      │
                     └──────────────────────────────────────┘
┌──────────────┐            ▲
│  Node-RED     │────────────┘
│  Dashboard    │   tcp://10.0.0.196:1883
└──────────────┘
```

---

### 4.4 MQTT + Node-RED Integration Pattern

Node-RED is the most common companion to GoPLC for dashboards, alerting, and cloud integration. This pattern establishes a clean contract between the PLC and Node-RED.

**GoPLC side -- publish process data, subscribe to commands:**

```iecst
PROGRAM POU_NodeRED
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    scan_count : DINT := 0;

    (* Process variables *)
    motor_speed_rpm : REAL := 0.0;
    motor_current_a : REAL := 0.0;
    motor_running : BOOL := FALSE;
    target_speed : REAL := 0.0;
    estop : BOOL := FALSE;
END_VAR

IF NOT initialized THEN
    MQTT_CLIENT_CREATE('nr', 'tcp://10.0.0.144:1883', 'goplc-nodered');
    MQTT_SET_QOS('nr', 1);

    (* Subscribe to command topics from Node-RED *)
    MQTT_SUBSCRIBE('nr', 'cmd/motor/target_speed');
    MQTT_SUBSCRIBE('nr', 'cmd/motor/start');
    MQTT_SUBSCRIBE('nr', 'cmd/motor/stop');
    MQTT_SUBSCRIBE('nr', 'cmd/estop');

    MQTT_CLIENT_CONNECT('nr');
    initialized := TRUE;
END_IF;

(* --- Publish status at 1 Hz --- *)
scan_count := scan_count + 1;
IF (scan_count MOD 10) = 0 THEN
    IF MQTT_CLIENT_IS_CONNECTED('nr') THEN
        MQTT_PUBLISH_JSON('nr', 'status/motor',
            JSON_OBJECT(
                'speed_rpm', motor_speed_rpm,
                'current_a', motor_current_a,
                'running', motor_running,
                'target_speed', target_speed,
                'estop', estop
            ));

        (* Publish device online status as retained *)
        MQTT_PUBLISH_RETAINED('nr', 'status/plc/online', 'true');
    ELSE
        MQTT_CLIENT_CONNECT('nr');
    END_IF;
END_IF;

(* --- Handle commands from Node-RED --- *)
IF MQTT_HAS_MESSAGE('nr', 'cmd/motor/target_speed') THEN
    target_speed := MQTT_GET_MESSAGE_REAL('nr', 'cmd/motor/target_speed');
    MQTT_CLEAR_MESSAGE('nr', 'cmd/motor/target_speed');
END_IF;

IF MQTT_HAS_MESSAGE('nr', 'cmd/motor/start') THEN
    IF NOT estop THEN
        motor_running := TRUE;
    END_IF;
    MQTT_CLEAR_MESSAGE('nr', 'cmd/motor/start');
END_IF;

IF MQTT_HAS_MESSAGE('nr', 'cmd/motor/stop') THEN
    motor_running := FALSE;
    MQTT_CLEAR_MESSAGE('nr', 'cmd/motor/stop');
END_IF;

IF MQTT_HAS_MESSAGE('nr', 'cmd/estop') THEN
    estop := MQTT_GET_MESSAGE_BOOL('nr', 'cmd/estop');
    IF estop THEN
        motor_running := FALSE;
        target_speed := 0.0;
    END_IF;
    MQTT_CLEAR_MESSAGE('nr', 'cmd/estop');
END_IF;

END_PROGRAM
```

**Node-RED side** (configured in the Node-RED editor):

```
MQTT In  [status/motor]  ──► JSON Parse ──► Dashboard Gauges
                                         ──► InfluxDB Write

Dashboard Slider [0-3600] ──► MQTT Out [cmd/motor/target_speed]
Dashboard Button [Start]  ──► MQTT Out [cmd/motor/start] payload="1"
Dashboard Button [Stop]   ──► MQTT Out [cmd/motor/stop]  payload="1"
Dashboard Button [E-Stop] ──► MQTT Out [cmd/estop]       payload="true"
```

**Topic convention:**

| Direction | Prefix | Example | QoS |
|-----------|--------|---------|-----|
| PLC to Node-RED | `status/` | `status/motor`, `status/plc/online` | 1 |
| Node-RED to PLC | `cmd/` | `cmd/motor/start`, `cmd/estop` | 1 |
| PLC diagnostics | `diag/` | `diag/scan_time`, `diag/faults` | 0 |

This separation makes it immediately clear which direction data flows and prevents accidental loops.

---

## 5. Initialization Patterns

### 5.1 One-Shot State Machine

The recommended pattern for MQTT initialization: use a state variable to ensure setup runs exactly once, regardless of scan cycling.

```iecst
PROGRAM POU_MQTTInit
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create client *)
        ok := MQTT_CLIENT_CREATE('main', 'tcp://10.0.0.144:1883', 'goplc-main');
        IF ok THEN state := 1; END_IF;

    1: (* Configure *)
        MQTT_SET_QOS('main', 1);
        MQTT_SUBSCRIBE('main', 'cmd/#');
        MQTT_SUBSCRIBE('main', 'config/#');
        state := 2;

    2: (* Connect *)
        ok := MQTT_CLIENT_CONNECT('main');
        IF ok THEN state := 10; END_IF;

    10: (* Running — normal operation *)
        IF NOT MQTT_CLIENT_IS_CONNECTED('main') THEN
            state := 2;    (* Reconnect *)
        END_IF;
END_CASE;

END_PROGRAM
```

### 5.2 Multi-Broker Setup

Connect to multiple brokers simultaneously -- local for real-time, cloud for archiving.

```iecst
PROGRAM POU_MultiBroker
VAR
    initialized : BOOL := FALSE;
END_VAR

IF NOT initialized THEN
    (* Local broker — low-latency, real-time control *)
    MQTT_CLIENT_CREATE('local', 'tcp://10.0.0.144:1883', 'goplc-local');
    MQTT_SET_QOS('local', 0);
    MQTT_SUBSCRIBE('local', 'sensors/#');
    MQTT_CLIENT_CONNECT('local');

    (* Cloud broker — TLS, reliable delivery *)
    MQTT_CLIENT_CREATE_AUTH('cloud', 'ssl://mqtt.example.com:8883',
                           'goplc-edge-01', 'api_key', 'api_secret');
    MQTT_SET_QOS('cloud', 1);
    MQTT_CLIENT_CONNECT('cloud');

    initialized := TRUE;
END_IF;

(* Read from local, forward summary to cloud *)
IF MQTT_HAS_MESSAGE('local', 'sensors/temp') THEN
    MQTT_PUBLISH('cloud', 'sites/plant1/temp',
                 MQTT_GET_MESSAGE('local', 'sensors/temp'));
END_IF;

END_PROGRAM
```

---

## 6. Best Practices

### Topic Design

| Rule | Example | Why |
|------|---------|-----|
| Use hierarchical topics | `plant/line1/motor/speed` | Enables wildcard subscriptions |
| Lowercase, no spaces | `plant/line1` not `Plant/Line 1` | Avoids case-sensitivity bugs |
| Separate status from commands | `status/pump` vs `cmd/pump` | Prevents accidental feedback loops |
| Keep payloads compact | `72.5` not `{"value": 72.5, "unit": "F", "source": "..."}` | Reduces bandwidth on constrained networks |

### QoS Selection

| Scenario | QoS | Rationale |
|----------|-----|-----------|
| Temperature readings every second | 0 | Next reading replaces a lost one |
| Alarm notifications | 1 | Must be delivered at least once |
| Setpoint changes from operator | 1 | Must arrive, duplicate is harmless (idempotent) |
| Safety-critical interlock commands | 1 + application ACK | QoS 2 is slow; use QoS 1 + publish an acknowledgment back |

### Reconnection

GoPLC MQTT clients do **not** auto-reconnect by default. Your ST program owns the reconnection logic. This is intentional -- the PLC programmer decides what to do when the broker is unreachable (buffer data, switch to local mode, raise an alarm).

```iecst
(* Minimal reconnection pattern *)
IF NOT MQTT_CLIENT_IS_CONNECTED('main') THEN
    MQTT_CLIENT_CONNECT('main');
END_IF;
```

### Message Age for Data Quality

Always validate freshness before using MQTT-sourced data in control loops:

```iecst
age := MQTT_GET_MESSAGE_AGE('sensor', 'tank/level');
IF age >= 0 AND age < 3000 THEN
    (* Data is less than 3 seconds old — use it *)
    level := MQTT_GET_MESSAGE_REAL('sensor', 'tank/level');
ELSE
    (* Stale or missing — hold last good value, set quality flag *)
    data_quality_good := FALSE;
END_IF;
```

---

## Appendix A: Function Quick Reference

### Client Functions (29)

| Function | Signature | Returns |
|----------|-----------|---------|
| `MQTT_CLIENT_CREATE` | `(name, broker, clientID)` | BOOL |
| `MQTT_CLIENT_CREATE_AUTH` | `(name, broker, clientID, username, password)` | BOOL |
| `MQTT_CLIENT_CONNECT` | `(name)` | BOOL |
| `MQTT_CLIENT_DISCONNECT` | `(name)` | BOOL |
| `MQTT_CLIENT_IS_CONNECTED` | `(name)` | BOOL |
| `MQTT_CLIENT_DELETE` | `(name)` | BOOL |
| `MQTT_CLIENT_LIST` | `()` | ARRAY |
| `MQTT_CONNECT` | `(name)` | BOOL |
| `MQTT_DISCONNECT` | `(name)` | BOOL |
| `MQTT_IS_CONNECTED` | `(name)` | BOOL |
| `MQTT_PUBLISH` | `(name, topic, payload [, qos] [, retained])` | BOOL |
| `MQTT_PUBLISH_JSON` | `(name, topic, value [, qos])` | BOOL |
| `MQTT_PUBLISH_RETAINED` | `(name, topic, payload)` | BOOL |
| `MQTT_SUBSCRIBE` | `(name, topic [, qos])` | BOOL |
| `MQTT_UNSUBSCRIBE` | `(name, topic)` | BOOL |
| `MQTT_GET_MESSAGE` | `(name, topic)` | STRING |
| `MQTT_GET_MESSAGE_INT` | `(name, topic)` | INT |
| `MQTT_GET_MESSAGE_REAL` | `(name, topic)` | REAL |
| `MQTT_GET_MESSAGE_BOOL` | `(name, topic)` | BOOL |
| `MQTT_GET_MESSAGE_JSON` | `(name, topic)` | ANY |
| `MQTT_HAS_MESSAGE` | `(name, topic)` | BOOL |
| `MQTT_GET_MESSAGE_AGE` | `(name, topic)` | INT (ms) |
| `MQTT_CLEAR_MESSAGE` | `(name, topic)` | BOOL |
| `MQTT_CLEAR_ALL` | `(name)` | BOOL |
| `MQTT_QUEUE_LENGTH` | `(name)` | INT |
| `MQTT_QUEUE_POP` | `(name)` | STRING |
| `MQTT_QUEUE_PEEK` | `(name)` | STRING |
| `MQTT_SET_QOS` | `(name, qos)` | BOOL |
| `MQTT_SET_RETAINED` | `(name, retained)` | BOOL |
| `MQTT_GET_BROKER` | `(name)` | STRING |
| `MQTT_GET_CLIENT_ID` | `(name)` | STRING |

### Broker Functions (7)

| Function | Signature | Returns |
|----------|-----------|---------|
| `MQTT_BROKER_CREATE` | `(name, tcpPort, wsPort)` | BOOL |
| `MQTT_BROKER_CREATE_AUTH` | `(name, tcpPort, wsPort, username, password)` | BOOL |
| `MQTT_BROKER_START` | `(name)` | BOOL |
| `MQTT_BROKER_STOP` | `(name)` | BOOL |
| `MQTT_BROKER_DELETE` | `(name)` | BOOL |
| `MQTT_BROKER_STATS` | `(name)` | STRING (JSON) |
| `MQTT_BROKER_CLIENTS` | `(name)` | STRING (JSON) |
| `MQTT_BROKER_IS_RUNNING` | `(name)` | BOOL |
| `MQTT_BROKER_KICK` | `(name, client_id)` | BOOL |
| `MQTT_BROKER_PUBLISH` | `(name, topic, payload)` | BOOL |
| `MQTT_BROKER_LIST` | `()` | STRING |

---

*GoPLC v1.0.533 | MQTT 3.1.1 | Built-in Paho client + Mochi broker*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
