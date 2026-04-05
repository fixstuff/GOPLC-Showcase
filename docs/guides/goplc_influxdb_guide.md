# GoPLC InfluxDB Integration Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC provides native **InfluxDB** write functions callable directly from IEC 61131-3 Structured Text. No Telegraf, no external agents, no data pipeline middleware. GoPLC writes time-series data straight to InfluxDB — both **v1** (1.x databases) and **v2** (2.x buckets with token auth) — using the InfluxDB line protocol over HTTP.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Connection** | `INFLUX_CONNECT` / `INFLUX_CONNECT_V1` / `INFLUX_CONNECT_V1_AUTH` | Connect to InfluxDB v1 or v2 instances |
| **Single Writes** | `INFLUX_WRITE` / `INFLUX_WRITE_INT` / `INFLUX_WRITE_BOOL` / `INFLUX_WRITE_STR` | Immediate single-point writes with explicit typing |
| **Batch Writes** | `INFLUX_BATCH_ADD` / `INFLUX_BATCH_ADD_INT` / `INFLUX_BATCH_FLUSH` | Buffer multiple points and flush as one HTTP request |
| **Line Protocol** | `INFLUX_WRITE_LINE` / `INFLUX_BUILD_LINE` | Raw line protocol for advanced use cases |

All functions are controlled entirely from IEC 61131-3 Structured Text in GoPLC's browser-based IDE.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ST Program                                             │  │
│  │                                                        │  │
│  │ INFLUX_CONNECT('db', 'http://10.0.0.144:8086',          │  │
│  │               'myorg', 'plcdata', 'token...')          │  │
│  │                                                        │  │
│  │ INFLUX_WRITE('db', 'temperature', 'zone=1',             │  │
│  │             'value', 72.5)                             │  │
│  │                                                        │  │
│  │ INFLUX_BATCH_ADD('db', 'motor', 'line=1',                │  │
│  │                'speed', 1750.0)                        │  │
│  │ INFLUX_BATCH_ADD('db', 'motor', 'line=1',                │  │
│  │                'temp', 145.2)                          │  │
│  │ INFLUX_BATCH_FLUSH('db')                                 │  │
│  └───────────────────────┬────────────────────────────────┘  │
│                          │                                   │
│                          │  HTTP POST (line protocol)        │
│                          │  /api/v2/write (v2)               │
│                          │  /write (v1)                      │
└──────────────────────────┼───────────────────────────────────┘
                           │
                           │  TCP :8086
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  InfluxDB                                                    │
│                                                              │
│  v2: Organization → Bucket → Measurement → Fields + Tags     │
│  v1: Database → Measurement → Fields + Tags                  │
│                                                              │
│  Retention policies, continuous queries, downsampling         │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       │  Flux / InfluxQL queries
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  Visualization                                               │
│                                                              │
│  Grafana (InfluxDB datasource)                               │
│  InfluxDB UI (built-in dashboards)                           │
│  Chronograf (v1)                                             │
│  Custom apps (Flux API)                                      │
└──────────────────────────────────────────────────────────────┘
```

### InfluxDB Data Model

| Concept | Description | Example |
|---------|-------------|---------|
| **Measurement** | Table name — groups related data points | `temperature`, `motor`, `production` |
| **Tag** | Indexed metadata — fast to filter, low cardinality | `zone=1`, `line=A`, `machine=press1` |
| **Field** | The actual value — not indexed, any type | `value=72.5`, `speed=1750`, `running=true` |
| **Timestamp** | Nanosecond precision (auto-set by GoPLC if omitted) | `1680000000000000000` |

> **Tags vs. Fields:** Tags are indexed and should be used for metadata you filter or group by (zone, line, machine). Fields hold the measured values. **Never put high-cardinality data in tags** (timestamps, unique IDs) — this creates excessive series and degrades performance.

---

## 2. Connection Management

### 2.1 INFLUX_CONNECT -- Connect to InfluxDB v2

```iecst
ok := INFLUX_CONNECT('db', 'http://10.0.0.144:8086', 'myorg', 'plcdata',
                     'your-api-token-here');
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Instance name (used in all subsequent calls) |
| `serverURL` | STRING | Yes | InfluxDB URL: `http://host:8086` or `https://host:8086` |
| `org` | STRING | Yes | InfluxDB organization name |
| `bucket` | STRING | Yes | Target bucket name |
| `token` | STRING | Yes | API token with write permission to the bucket |

Returns `TRUE` on success.

> **Creating a token:** In the InfluxDB UI, navigate to **Data > API Tokens > Generate Token**. For PLC data logging, create a write-only token scoped to the target bucket. Store the token securely — it cannot be retrieved after creation.

### 2.2 INFLUX_CONNECT_V1 -- Connect to InfluxDB v1 (No Auth)

```iecst
ok := INFLUX_CONNECT_V1('db', 'http://10.0.0.144:8086', 'plc_data');
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Instance name |
| `serverURL` | STRING | Yes | InfluxDB URL |
| `database` | STRING | Yes | Database name |

Returns `TRUE` on success. Use this for InfluxDB 1.x instances without authentication enabled — common in isolated OT networks.

### 2.3 INFLUX_CONNECT_V1_AUTH -- Connect to InfluxDB v1 (With Auth)

```iecst
ok := INFLUX_CONNECT_V1_AUTH('db', 'http://10.0.0.144:8086', 'plc_data',
                           'grafana_writer', 'wr1teP@ss');
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Instance name |
| `serverURL` | STRING | Yes | InfluxDB URL |
| `database` | STRING | Yes | Database name |
| `username` | STRING | Yes | InfluxDB username |
| `password` | STRING | Yes | InfluxDB password |

Returns `TRUE` on success.

### 2.4 INFLUX_DISCONNECT / INFLUX_IS_CONNECTED

```iecst
(* Check connection *)
IF INFLUX_IS_CONNECTED('db') THEN
    (* write data *)
END_IF;

(* Disconnect *)
INFLUX_DISCONNECT('db');
```

---

## 3. Single-Point Writes

### 3.1 INFLUX_WRITE -- Auto-Typed Write

```iecst
ok := INFLUX_WRITE('db', 'temperature', 'zone=1,building=A', 'value', 72.5);
ok := INFLUX_WRITE('db', 'motor', 'line=1', 'speed', 1750);
ok := INFLUX_WRITE('db', 'conveyor', 'line=1', 'running', TRUE);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection instance name |
| `measurement` | STRING | Measurement name (table) |
| `tags` | STRING | Comma-separated key=value tags (e.g., `zone=1,line=A`) |
| `field` | STRING | Field name |
| `value` | ANY | Field value — type auto-detected (INT, REAL, BOOL, STRING) |

Returns `TRUE` on success. GoPLC detects the value type and formats it correctly for the InfluxDB line protocol:

| ST Type | Line Protocol Format | Example |
|---------|---------------------|---------|
| INT / DINT | `42i` (integer suffix) | `speed=1750i` |
| REAL / LREAL | `72.5` (no suffix) | `temp=72.5` |
| BOOL | `true` / `false` | `running=true` |
| STRING | `"quoted"` | `status="OK"` |

> **Empty tags:** Pass an empty string `''` for the tags parameter if no tags are needed. At least one field is always required.

### 3.2 INFLUX_WRITE_INT / WriteBool / WriteStr -- Explicit Types

```iecst
(* Force integer type — avoids type conflicts if the measurement
   already has this field as integer *)
ok := INFLUX_WRITE_INT('db', 'production', 'line=1', 'count', batch_count);

(* Force boolean *)
ok := INFLUX_WRITE_BOOL('db', 'status', 'machine=press1', 'fault', has_fault);

(* Force string *)
ok := INFLUX_WRITE_STR('db', 'events', 'source=plc', 'message', 'Batch complete');
```

Use the explicit-type variants when you need to guarantee the field type matches an existing measurement. InfluxDB rejects writes where a field type conflicts with previously written data (e.g., writing a float to a field that was first written as integer).

> **Type conflict recovery:** If InfluxDB rejects a write with "field type conflict," the measurement already has that field stored as a different type. Options: (1) use the correct explicit-type function, (2) drop and recreate the measurement, or (3) use a different field name. In InfluxDB v1, `DROP MEASUREMENT temperature` clears it. In v2, delete the data via the UI or API.

---

## 4. Batch Writes

For high-throughput data logging, batch writes combine multiple data points into a single HTTP request. This is critical for performance — individual writes at 100ms scan rates generate 600 HTTP requests per minute per field. Batching reduces this to a single request per flush.

### 4.1 INFLUX_BATCH_ADD -- Add Point to Batch (Auto-Typed)

```iecst
ok := INFLUX_BATCH_ADD('db', 'motor', 'line=1,drive=vfd1', 'speed', 1750.0);
ok := INFLUX_BATCH_ADD('db', 'motor', 'line=1,drive=vfd1', 'current', 12.4);
ok := INFLUX_BATCH_ADD('db', 'motor', 'line=1,drive=vfd1', 'temp', 145.2);
ok := INFLUX_BATCH_ADD('db', 'temperature', 'zone=1', 'value', 72.5);
ok := INFLUX_BATCH_ADD('db', 'temperature', 'zone=2', 'value', 68.3);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection instance name |
| `measurement` | STRING | Measurement name |
| `tags` | STRING | Comma-separated key=value tags |
| `field` | STRING | Field name |
| `value` | ANY | Field value (auto-typed) |

Returns `TRUE` on success. The point is added to an in-memory buffer — no HTTP request is made until `INFLUX_BATCH_FLUSH` is called.

### 4.2 INFLUX_BATCH_ADD_INT -- Add Integer Point to Batch

```iecst
ok := INFLUX_BATCH_ADD_INT('db', 'production', 'line=1', 'count', batch_count);
ok := INFLUX_BATCH_ADD_INT('db', 'production', 'line=1', 'rejects', reject_count);
```

Explicitly adds an integer-typed point to the batch. Use this when the measurement field must be integer type.

### 4.3 INFLUX_BATCH_FLUSH -- Send Batch to InfluxDB

```iecst
lines_sent := INFLUX_BATCH_FLUSH('db');
(* Returns: 5 (number of lines written) or -1 on error *)
```

Returns the number of line protocol lines sent, or `-1` on error (connection failure, auth error, type conflict). After a successful flush, the batch buffer is cleared automatically.

### 4.4 INFLUX_BATCH_CLEAR / INFLUX_BATCH_SIZE

```iecst
(* Check how many points are buffered *)
pending := INFLUX_BATCH_SIZE('db');
(* Returns: 5 *)

(* Discard buffered points without sending *)
INFLUX_BATCH_CLEAR('db');
```

`INFLUX_BATCH_CLEAR` discards all buffered points without sending them. Use this to reset the buffer after an error condition or mode change.

---

## 5. Line Protocol (Advanced)

### 5.1 INFLUX_WRITE_LINE -- Write Raw Line Protocol

```iecst
ok := INFLUX_WRITE_LINE('db', 'temperature,zone=1 value=72.5');
ok := INFLUX_WRITE_LINE('db', 'motor,line=1 speed=1750i,temp=145.2,running=true');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection instance name |
| `line` | STRING | Complete line protocol string |

Returns `TRUE` on success. This sends a raw line protocol string directly — you handle all formatting. Use this for multi-field writes (multiple fields in a single line) or when you need explicit timestamp control.

### Line Protocol Format

```
measurement,tag1=val1,tag2=val2 field1=value1,field2=value2 [timestamp]

Examples:
  temperature,zone=1 value=72.5
  motor,line=1,drive=vfd1 speed=1750i,current=12.4,temp=145.2
  status,machine=press running=true,mode="auto"
  temperature,zone=1 value=72.5 1680000000000000000
```

- **No spaces** between measurement and tags (separated by comma)
- **One space** between tags and fields
- **Optional timestamp** in nanoseconds since epoch (InfluxDB uses server time if omitted)
- Integer values need `i` suffix: `1750i`
- String values need double quotes: `"auto"`
- Boolean values: `true` / `false` (no quotes)
- Float values: plain decimal: `72.5`

### 5.2 INFLUX_BUILD_LINE -- Build Line Protocol String

```iecst
line := INFLUX_BUILD_LINE('temperature', 'zone=1', 'value', 72.5);
(* Returns: 'temperature,zone=1 value=72.5' *)

line := INFLUX_BUILD_LINE('motor', 'line=1,drive=vfd1', 'speed', 1750);
(* Returns: 'motor,line=1,drive=vfd1 speed=1750i' *)
```

| Param | Type | Description |
|-------|------|-------------|
| `measurement` | STRING | Measurement name |
| `tags` | STRING | Comma-separated key=value tags |
| `field` | STRING | Field name |
| `value` | ANY | Field value (auto-typed) |

Returns a formatted line protocol string. This is a pure helper — no data is sent. Use it to build lines for `INFLUX_WRITE_LINE` or for constructing multi-field lines by concatenation.

```iecst
(* Build multi-field line manually *)
line := CONCAT('motor,line=1 ',
               'speed=', INT_TO_STRING(speed), 'i,',
               'temp=', REAL_TO_STRING(temp), ',',
               'running=', BOOL_TO_STRING(motor_on));
INFLUX_WRITE_LINE('db', line);
```

---

## 6. Complete Example: Production Data Logger

This example logs production metrics to InfluxDB v2 using batch writes for performance:

```iecst
PROGRAM POU_InfluxDB_Logger
VAR
    state : INT := 0;
    ok : BOOL;
    lines_sent : INT;
    (* Process values — updated from other programs or I/O *)
    line_speed : REAL := 0.0;
    motor_temp : REAL := 0.0;
    motor_current : REAL := 0.0;
    conveyor_running : BOOL := FALSE;
    batch_count : DINT := 0;
    zone1_temp : REAL := 0.0;
    zone2_temp : REAL := 0.0;
    (* Batch timing *)
    scan_counter : INT := 0;
    flush_interval : INT := 10;    (* flush every 10 scans = 1s at 100ms *)
END_VAR

CASE state OF
    0: (* Connect to InfluxDB v2 *)
        ok := INFLUX_CONNECT('db', 'http://10.0.0.144:8086',
                             'myorg', 'plcdata',
                             'your-api-token-here');
        IF ok THEN state := 10; END_IF;

    10: (* Running — collect data into batch *)
        (* Motor data *)
        INFLUX_BATCH_ADD('db', 'motor', 'line=1,drive=vfd1', 'speed', line_speed);
        INFLUX_BATCH_ADD('db', 'motor', 'line=1,drive=vfd1', 'temp', motor_temp);
        INFLUX_BATCH_ADD('db', 'motor', 'line=1,drive=vfd1', 'current', motor_current);

        (* Zone temperatures *)
        INFLUX_BATCH_ADD('db', 'temperature', 'zone=1', 'value', zone1_temp);
        INFLUX_BATCH_ADD('db', 'temperature', 'zone=2', 'value', zone2_temp);

        (* Production counters — integer type *)
        INFLUX_BATCH_ADD_INT('db', 'production', 'line=1', 'count', batch_count);

        (* Conveyor status *)
        INFLUX_BATCH_ADD('db', 'conveyor', 'line=1', 'running', conveyor_running);

        (* Flush batch periodically *)
        scan_counter := scan_counter + 1;
        IF scan_counter >= flush_interval THEN
            lines_sent := INFLUX_BATCH_FLUSH('db');
            IF lines_sent = -1 THEN
                (* Write failed — check connection *)
                IF NOT INFLUX_IS_CONNECTED('db') THEN
                    state := 0;   (* reconnect *)
                END_IF;
            END_IF;
            scan_counter := 0;
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 7. Complete Example: InfluxDB v1 with Grafana

This example connects to an existing InfluxDB 1.x instance (common in legacy OT environments) and writes data for Grafana dashboards:

```iecst
PROGRAM POU_InfluxV1_Grafana
VAR
    state : INT := 0;
    ok : BOOL;
    lines_sent : INT;
    temp : REAL := 0.0;
    pressure : REAL := 0.0;
    flow_rate : REAL := 0.0;
    valve_open : BOOL := FALSE;
    scan_counter : INT := 0;
END_VAR

CASE state OF
    0: (* Connect to InfluxDB v1 — no auth *)
        ok := INFLUX_CONNECT_V1('db', 'http://10.0.0.144:8086', 'process_data');
        IF ok THEN state := 10; END_IF;

        (* Or with auth: *)
        (* ok := INFLUX_CONNECT_V1_AUTH('db', 'http://10.0.0.144:8086',
                                      'process_data', 'writer', 'pass'); *)

    10: (* Running — batch writes every second *)
        INFLUX_BATCH_ADD('db', 'process', 'unit=reactor1', 'temperature', temp);
        INFLUX_BATCH_ADD('db', 'process', 'unit=reactor1', 'pressure', pressure);
        INFLUX_BATCH_ADD('db', 'process', 'unit=reactor1', 'flow_rate', flow_rate);
        INFLUX_BATCH_ADD('db', 'process', 'unit=reactor1', 'valve_open', valve_open);

        scan_counter := scan_counter + 1;
        IF scan_counter >= 10 THEN
            lines_sent := INFLUX_BATCH_FLUSH('db');
            scan_counter := 0;
        END_IF;
END_CASE;
END_PROGRAM
```

### Grafana Dashboard Configuration

1. **Add InfluxDB datasource** in Grafana:
   - URL: `http://10.0.0.144:8086`
   - Database: `process_data` (v1) or Organization + Token (v2)
   - Query language: InfluxQL (v1) or Flux (v2)

2. **Create panels** using the measurements GoPLC writes:

   **InfluxQL (v1):**
   ```sql
   SELECT mean("temperature") FROM "process"
   WHERE "unit" = 'reactor1' AND $timeFilter
   GROUP BY time($__interval) fill(null)
   ```

   **Flux (v2):**
   ```flux
   from(bucket: "plcdata")
     |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
     |> filter(fn: (r) => r._measurement == "process")
     |> filter(fn: (r) => r.unit == "reactor1")
     |> filter(fn: (r) => r._field == "temperature")
     |> aggregateWindow(every: v.windowPeriod, fn: mean)
   ```

3. **Tag-based filtering:** The tags you set in GoPLC (`unit=reactor1`, `line=1`, `zone=1`) become selectable filters in Grafana template variables. Use consistent tag naming across all GoPLC programs for a clean dashboard experience.

---

## 8. Performance Considerations

### Batch vs. Single Writes

| Method | HTTP Requests (at 100ms scan, 7 fields) | Use Case |
|--------|---------------------------------------|----------|
| `INFLUX_WRITE` per field | 4,200/min | Low-frequency data, events |
| `INFLUX_BATCH_FLUSH` every 1s | 60/min | Production data logging |
| `INFLUX_BATCH_FLUSH` every 10s | 6/min | Long-term trending |

**Always use batch writes for cyclic data.** Single writes are appropriate for event-driven data (alarms, mode changes, batch completions) where immediacy matters more than throughput.

### Tag Cardinality

InfluxDB creates a **series** for every unique combination of measurement + tags. High cardinality kills performance:

```iecst
(* Good — low cardinality tags *)
INFLUX_WRITE('db', 'temperature', 'zone=1', 'value', temp);
INFLUX_WRITE('db', 'temperature', 'zone=2', 'value', temp);
(* 2 series total *)

(* Bad — unique ID in tag creates unbounded series *)
INFLUX_WRITE('db', 'temperature', CONCAT('id=', INT_TO_STRING(scan_count)),
            'value', temp);
(* N series, growing forever — will crash InfluxDB *)
```

### Retention Policies

Configure retention in InfluxDB to automatically expire old data:

- **v1:** `CREATE RETENTION POLICY "30d" ON "plc_data" DURATION 30d REPLICATION 1 DEFAULT`
- **v2:** Set retention period in the bucket configuration (UI or API)

A typical pattern: 1-second data retained for 7 days, 1-minute downsampled data retained for 1 year.

### Write Failures and Recovery

`INFLUX_BATCH_FLUSH` returns `-1` on failure. GoPLC does not buffer failed writes across flushes — data in the failed batch is lost. If write reliability is critical:

```iecst
lines_sent := INFLUX_BATCH_FLUSH('db');
IF lines_sent = -1 THEN
    (* Log the failure, but don't retry — the batch is already cleared *)
    error_count := error_count + 1;
    IF NOT INFLUX_IS_CONNECTED('db') THEN
        state := 0;   (* trigger reconnect *)
    END_IF;
END_IF;
```

For guaranteed delivery, combine with GoPLC's MQTT client to buffer data on a local broker as a fallback path.

---

## 9. Troubleshooting

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `INFLUX_CONNECT` returns FALSE | Wrong URL or network | Verify URL, port, firewall; `curl http://host:8086/ping` |
| Write returns FALSE | Auth failure | Check token (v2) or username/password (v1) has write access |
| "field type conflict" | Type mismatch | First write sets field type forever; use explicit-type functions |
| Data appears but with wrong values | Integer vs float confusion | Use `INFLUX_WRITE_INT` for counters, `INFLUX_WRITE` for analog values |
| Grafana shows no data | Wrong database/bucket | Verify Grafana datasource matches GoPLC connection parameters |
| `INFLUX_BATCH_FLUSH` returns -1 | Connection lost | Check `INFLUX_IS_CONNECTED`, reconnect if needed |
| High InfluxDB memory usage | Tag cardinality explosion | Audit tags — never use scan counts, timestamps, or unique IDs as tags |
| Slow queries in Grafana | Missing tags / too many series | Use tags for dimensions you filter by; limit cardinality |

---

## Appendix A: Function Quick Reference

| Function | Params | Returns | Description |
|----------|--------|---------|-------------|
| `INFLUX_CONNECT` | `(name, serverURL, org, bucket, token)` | BOOL | Connect to InfluxDB v2 |
| `INFLUX_CONNECT_V1` | `(name, serverURL, database)` | BOOL | Connect to InfluxDB v1 (no auth) |
| `INFLUX_CONNECT_V1_AUTH` | `(name, serverURL, database, username, password)` | BOOL | Connect to InfluxDB v1 (with auth) |
| `INFLUX_DISCONNECT` | `(name)` | BOOL | Close connection |
| `INFLUX_IS_CONNECTED` | `(name)` | BOOL | Check connection state |
| `INFLUX_WRITE` | `(name, measurement, tags, field, value)` | BOOL | Single write, auto-typed |
| `INFLUX_WRITE_INT` | `(name, measurement, tags, field, value)` | BOOL | Single write, integer |
| `INFLUX_WRITE_BOOL` | `(name, measurement, tags, field, value)` | BOOL | Single write, boolean |
| `INFLUX_WRITE_STR` | `(name, measurement, tags, field, value)` | BOOL | Single write, string |
| `INFLUX_WRITE_LINE` | `(name, line)` | BOOL | Raw line protocol write |
| `INFLUX_BATCH_ADD` | `(name, measurement, tags, field, value)` | BOOL | Add auto-typed point to batch |
| `INFLUX_BATCH_ADD_INT` | `(name, measurement, tags, field, value)` | BOOL | Add integer point to batch |
| `INFLUX_BATCH_FLUSH` | `(name)` | INT | Send batch (returns line count, -1 on error) |
| `INFLUX_BATCH_CLEAR` | `(name)` | BOOL | Discard buffered points |
| `INFLUX_BATCH_SIZE` | `(name)` | INT | Number of buffered points |
| `INFLUX_BUILD_LINE` | `(measurement, tags, field, value)` | STRING | Build line protocol string (no write) |

---

*GoPLC v1.0.533 | InfluxDB v1 + v2 | HTTP Line Protocol Writer*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
