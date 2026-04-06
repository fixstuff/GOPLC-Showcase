# GoPLC Protocol Analyzer & Store-and-Forward Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Protocol Analyzer

The protocol analyzer captures industrial protocol transactions in real time — Modbus, FINS, EtherNet/IP, S7, OPC UA, DNP3, BACnet, and more. Captures are viewable from ST code, queryable via REST API, and exportable to PCAP for Wireshark analysis.

### Capture Workflow

```iecst
(* 1. Initialize with buffer size *)
AN_INIT(1000);

(* 2. Start capture — optionally filter by device/protocol *)
AN_START('10.0.0.50', 'modbus');

(* 3. ... protocol traffic is captured automatically ... *)

(* 4. Check status *)
IF AN_IS_CAPTURING() THEN
    count := AN_COUNT();
    stats := AN_STATS();
END_IF;

(* 5. Retrieve and decode *)
transactions := AN_GET(50);
decoded := AN_DECODE('modbus', '0001000000060103000A0002');

(* 6. Export and stop *)
AN_EXPORT_PCAP('/data/capture.pcap');
AN_STOP();
```

### ST Functions (12)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `AN_INIT(buffer_size)` | 1 | BOOL | Initialize analyzer with transaction buffer |
| `AN_START([device, protocol])` | 0-2 | BOOL | Start capture (optional device/protocol filter) |
| `AN_STOP()` | 0 | BOOL | Stop capture |
| `AN_IS_CAPTURING()` | 0 | BOOL | Check if capture is active |
| `AN_RECORD(device, protocol, direction, hex)` | 4 | BOOL | Record transaction manually |
| `AN_FILTER(device, protocol, limit)` | 3 | ARRAY | Get filtered transactions |
| `AN_GET(limit)` | 1 | ARRAY | Get recent transactions |
| `AN_DECODE(protocol, hex)` | 2 | MAP | Decode raw packet to fields |
| `AN_COUNT()` | 0 | INT | Transaction count |
| `AN_STATS()` | 0 | MAP | Capture statistics (total, errors, by-protocol) |
| `AN_CLEAR()` | 0 | BOOL | Clear transaction buffer |
| `AN_EXPORT_PCAP(path)` | 1 | BOOL | Export to PCAP file |

### REST API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/analyzer` | Capture state and statistics |
| POST | `/api/analyzer/start` | Start capture |
| POST | `/api/analyzer/stop` | Stop capture |
| GET | `/api/analyzer/transactions` | List transactions (limit/offset) |
| GET | `/api/analyzer/transactions/{id}` | Single transaction |
| DELETE | `/api/analyzer/transactions` | Clear buffer |
| GET | `/api/analyzer/stats` | Detailed statistics |
| POST | `/api/analyzer/decode` | Decode hex packet |
| GET | `/api/analyzer/export/pcap` | Download PCAP |
| GET | `/api/analyzer/protocols` | List supported protocols |

### Example: Capture and Decode Modbus Traffic

```iecst
PROGRAM POU_PacketCapture
VAR
    state : INT := 0;
    capture_timer : DINT := 0;
    transactions : STRING;
    decoded : STRING;
    stats : STRING;
END_VAR

CASE state OF
    0: (* Initialize *)
        AN_INIT(500);
        AN_START('10.0.0.50', 'modbus');
        state := 1;

    1: (* Capture for 3000 scans (~5 min at 100ms) *)
        capture_timer := capture_timer + 1;

        IF capture_timer >= 3000 THEN
            AN_STOP();
            stats := AN_STATS();
            transactions := AN_GET(20);
            DEBUG_INFO('capture', CONCAT('Captured ', INT_TO_STRING(AN_COUNT()), ' transactions'));
            state := 2;
        END_IF;

    2: (* Done — data available via API *)
END_CASE;
END_PROGRAM
```

---

## 2. Store-and-Forward

The store-and-forward subsystem queues messages locally when the network is unavailable and forwards them when connectivity is restored. Messages persist in a SQLite database — no data loss across restarts.

### Workflow

```iecst
(* 1. Initialize with database path *)
SF_INIT('/data/telemetry_queue.db', 10000, 86400);

(* 2. Store messages (always succeeds — local DB) *)
SF_STORE('plant/telemetry', payload, 1);
SF_STORE_JSON('plant/status', 1, status_map);

(* 3. Check pending *)
pending := SF_COUNT();
is_online := SF_ONLINE(TRUE);

(* 4. Forward when ready *)
forwarded := SF_FORWARD(forward_callback);

(* 5. Stats and cleanup *)
stats := SF_STATS();
SF_CLEAR();
SF_CLOSE();
```

### ST Functions (10)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `SF_INIT(db_path, max_msgs, max_age_sec)` | 3 | BOOL | Initialize with SQLite database |
| `SF_STORE(topic, payload, priority)` | 3 | INT | Store text message (returns ID) |
| `SF_STORE_JSON(topic, priority, value)` | 3 | INT | Store structured value as JSON |
| `SF_FORWARD(callback)` | 1 | INT | Forward pending messages (returns count) |
| `SF_ONLINE(online)` | 1 | — | Set network availability flag |
| `SF_COUNT()` | 0 | INT | Pending message count |
| `SF_GET_PENDING(limit)` | 1 | ARRAY | View pending messages |
| `SF_STATS()` | 0 | MAP | Queue statistics (stored, forwarded, dropped) |
| `SF_CLEAR()` | 0 | BOOL | Clear all pending messages |
| `SF_CLOSE()` | 0 | — | Close database connection |

### Example: Resilient MQTT Telemetry

```iecst
PROGRAM POU_ResilientTelemetry
VAR
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;
    pending : INT;
    payload : STRING;
END_VAR

IF NOT initialized THEN
    SF_INIT('/data/telemetry.db', 50000, 604800);    (* 50K msgs, 7-day max age *)
    MQTT_CLIENT_CREATE('broker', 'tcp://10.0.0.144:1883', 'goplc-sf');
    MQTT_CLIENT_CONNECT('broker');
    initialized := TRUE;
END_IF;

scan_count := scan_count + 1;

(* Store telemetry every 10 scans *)
IF (scan_count MOD 10) = 0 THEN
    payload := JSON_STRINGIFY(JSON_OBJECT(
        'temp', temperature,
        'pressure', pressure
    ));
    SF_STORE('plant/telemetry', payload, 1);
END_IF;

(* Track connectivity *)
SF_ONLINE(MQTT_CLIENT_IS_CONNECTED('broker'));

(* Monitor queue depth *)
pending := SF_COUNT();
IF pending > 1000 THEN
    DEBUG_WARN('sf', CONCAT('Queue depth: ', INT_TO_STRING(pending)));
END_IF;
END_PROGRAM
```

---

*GoPLC v1.0.535 | Protocol Analyzer (12) + Store-and-Forward (10) | Packet Capture & Offline Queuing*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
