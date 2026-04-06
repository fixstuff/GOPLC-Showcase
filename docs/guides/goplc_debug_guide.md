# GoPLC Debug & Logging Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 36 built-in functions for structured logging from Structured Text programs. Log messages can be routed to multiple simultaneous targets — file, database, InfluxDB, syslog, console, and an in-memory ring buffer queryable via the REST API.

### Targets

| Target | Function | Persistence | Query |
|--------|----------|-------------|-------|
| **Ring Buffer** | Always active | In-memory (lost on restart) | `GET /api/logs` |
| **File** | `DEBUG_TO_FILE` | Disk | Read file directly |
| **SQLite** | `DEBUG_TO_SQLITE` | Local database | `DEBUG_DB_QUERY` or SQL |
| **PostgreSQL** | `DEBUG_TO_POSTGRES` | Network database | `DEBUG_DB_QUERY` or SQL |
| **InfluxDB** | `DEBUG_TO_INFLUX` | Time-series | Grafana dashboards |
| **Syslog** | `DEBUG_TO_SYSLOG` | Remote syslog server | Syslog viewer |
| **Console** | `DEBUG_TO_CONSOLE` | stdout | Terminal |

Multiple targets can be active simultaneously — log to file AND InfluxDB AND the ring buffer at the same time.

### Log Levels

| Level | Use |
|-------|-----|
| `'TRACE'` | Detailed diagnostic (scan-level) |
| `'DEBUG'` | Development debugging |
| `'INFO'` | Normal operational events |
| `'WARN'` | Unusual conditions |
| `'ERROR'` | Failures requiring attention |

---

## 2. Writing Log Messages

All logging functions take a **module** name and a **message**. The module name groups related logs and enables per-module level filtering.

```iecst
DEBUG_INFO('pump', 'Pump started at 1750 RPM');
DEBUG_WARN('comms', 'Modbus timeout on VFD connection');
DEBUG_ERROR('safety', CONCAT('E-stop triggered at ', DT_TO_STRING(NOW())));
DEBUG_TRACE('scan', CONCAT('Scan time: ', REAL_TO_STRING(scan_ms), 'ms'));
DEBUG_LOG('general', 'This logs at DEBUG level');
```

| Function | Level | Description |
|----------|-------|-------------|
| `DEBUG_TRACE(module, message)` | TRACE | Finest detail |
| `DEBUG_LOG(module, message)` | DEBUG | Debug-level logging |
| `DEBUG_INFO(module, message)` | INFO | Normal events |
| `DEBUG_WARN(module, message)` | WARN | Warnings |
| `DEBUG_ERROR(module, message)` | ERROR | Errors |

---

## 3. Level Control

### Per-Module Levels

Each module can have its own log level. Messages below the module's level are silently discarded.

```iecst
(* Enable a module and set its level *)
DEBUG_ENABLE('pump');
DEBUG_SET_LEVEL('pump', 'INFO');

(* This will log — INFO >= INFO *)
DEBUG_INFO('pump', 'Pump running');

(* This will be suppressed — TRACE < INFO *)
DEBUG_TRACE('pump', 'Scan cycle details');

(* Check current level *)
level := DEBUG_GET_LEVEL('pump');        (* "INFO" *)

(* Disable a module entirely *)
DEBUG_DISABLE('pump');
```

### Global Level

The global level applies to all modules that don't have a per-module level set.

```iecst
DEBUG_SET_GLOBAL_LEVEL('WARN');          (* Only WARN and ERROR pass globally *)
level := DEBUG_GET_GLOBAL_LEVEL();       (* "WARN" *)
```

### System Enable/Disable

Master switch for all debug output:

```iecst
DEBUG_SYSTEM_DISABLE();                  (* Suppress ALL logging *)
DEBUG_SYSTEM_ENABLE();                   (* Re-enable *)

IF DEBUG_IS_ENABLED() THEN
    (* Logging is active *)
END_IF;
```

### List Active Modules

```iecst
modules := DEBUG_LIST_MODULES();
(* Returns: ["pump", "comms", "safety", ...] *)
```

---

## 4. File Target

Log to a file with automatic rotation.

```iecst
(* Start logging to file *)
ok := DEBUG_TO_FILE('/var/log/goplc/runtime.log');

(* Append mode (default creates/truncates) *)
ok := DEBUG_TO_FILE('/var/log/goplc/runtime.log', TRUE);

(* Check current file *)
path := DEBUG_GET_FILE_PATH();           (* "/var/log/goplc/runtime.log" *)

(* Stop file logging *)
DEBUG_FILE_CLOSE();
```

---

## 5. Database Target

Log to SQLite or PostgreSQL for structured querying.

### SQLite

```iecst
ok := DEBUG_TO_SQLITE('/data/logs.db');

(* Custom table name *)
ok := DEBUG_TO_SQLITE('/data/logs.db', 'plc_events');
```

Creates a table with columns: `id`, `timestamp`, `level`, `module`, `message`.

### PostgreSQL

```iecst
ok := DEBUG_TO_POSTGRES('host=10.0.0.144 port=5432 dbname=goplc user=goplc password=secret');

(* Custom table name *)
ok := DEBUG_TO_POSTGRES('host=10.0.0.144 port=5432 dbname=goplc', 'plant_logs');
```

### Query Logs from ST

```iecst
(* Last 10 log entries *)
entries := DEBUG_DB_QUERY(10);

(* Last 20 entries from 'pump' module *)
entries := DEBUG_DB_QUERY(20, 'pump');

(* Last 5 errors from 'comms' module *)
entries := DEBUG_DB_QUERY(5, 'comms', 'ERROR');
```

Returns: array of maps with `{id, timestamp, level, module, message}`.

### Status and Close

```iecst
status := DEBUG_DB_STATUS();
(* Returns: {"type": "sqlite", "connected": true, "path": "/data/logs.db", "row_count": 1542} *)

DEBUG_DB_CLOSE();
```

---

## 6. InfluxDB Target

Log to InfluxDB for time-series analysis and Grafana dashboards.

```iecst
ok := DEBUG_TO_INFLUX(
    'http://10.0.0.144:8086',    (* URL *)
    'my-token',                   (* API token *)
    'my-org',                     (* Organization *)
    'plc_logs'                    (* Bucket *)
);
```

Writes each log entry as an InfluxDB point with:
- **Measurement**: `plc_log`
- **Tags**: `level`, `module`
- **Field**: `message`
- **Timestamp**: nanosecond precision

```iecst
status := DEBUG_INFLUX_STATUS();
(* Returns: {"connected": true, "url": "...", "bucket": "plc_logs", "writes": 842} *)

DEBUG_INFLUX_CLOSE();
```

---

## 7. Syslog Target

Forward logs to a remote syslog server (UDP, RFC 3164).

```iecst
ok := DEBUG_TO_SYSLOG('10.0.0.144:514');

status := DEBUG_SYSLOG_STATUS();
(* Returns: {"connected": true, "host": "10.0.0.144:514", "messages_sent": 256} *)

DEBUG_SYSLOG_CLOSE();
```

---

## 8. Console Output

Send log messages to stdout (visible in terminal or `journalctl`):

```iecst
DEBUG_TO_CONSOLE(TRUE);     (* Enable console output *)
DEBUG_TO_CONSOLE(FALSE);    (* Disable *)
```

---

## 9. Ring Buffer

All log messages are always stored in an in-memory ring buffer regardless of other targets. The buffer is queryable from ST and via the REST API.

```iecst
(* Get last 20 messages *)
messages := DEBUG_GET_BUFFER(20);
(* Returns: array of formatted log strings *)

(* Check buffer size *)
size := DEBUG_GET_BUFFER_SIZE();

(* Clear buffer *)
DEBUG_CLEAR_BUFFER();
```

### REST API Access

```
GET /api/logs?level=WARN&limit=50&program=POU_Control
```

---

## 10. Complete Example: Multi-Target Diagnostics

```iecst
PROGRAM POU_Diagnostics
VAR
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;
    temperature : REAL;
    pressure : REAL;
    ok : BOOL;
END_VAR

IF NOT initialized THEN
    (* Enable modules *)
    DEBUG_ENABLE('diag');
    DEBUG_SET_LEVEL('diag', 'INFO');

    DEBUG_ENABLE('alarm');
    DEBUG_SET_LEVEL('alarm', 'WARN');

    (* Route to multiple targets *)
    DEBUG_TO_FILE('/var/log/goplc/diagnostics.log');
    DEBUG_TO_SQLITE('/data/diag.db');
    DEBUG_TO_INFLUX('http://10.0.0.144:8086', 'token', 'org', 'plc_logs');
    DEBUG_TO_CONSOLE(TRUE);

    DEBUG_INFO('diag', 'Diagnostics initialized — file + sqlite + influx + console');
    initialized := TRUE;
END_IF;

scan_count := scan_count + 1;

(* Periodic heartbeat *)
IF (scan_count MOD 600) = 0 THEN
    DEBUG_INFO('diag', CONCAT('Heartbeat — cycle: ', DINT_TO_STRING(scan_count)));
END_IF;

(* Alarm conditions *)
IF temperature > 180.0 THEN
    DEBUG_ERROR('alarm', CONCAT('OVER-TEMP: ', REAL_TO_STRING(temperature), ' F'));
ELSIF temperature > 150.0 THEN
    DEBUG_WARN('alarm', CONCAT('High temp warning: ', REAL_TO_STRING(temperature), ' F'));
END_IF;

IF pressure < 20.0 THEN
    DEBUG_WARN('alarm', CONCAT('Low pressure: ', REAL_TO_STRING(pressure), ' PSI'));
END_IF;

(* Trace-level scan diagnostics (only visible if level set to TRACE) *)
DEBUG_TRACE('diag', CONCAT('Scan ', DINT_TO_STRING(scan_count),
            ' temp=', REAL_TO_STRING(temperature),
            ' press=', REAL_TO_STRING(pressure)));
END_PROGRAM
```

---

## 11. Complete Example: Log Query Dashboard

```iecst
PROGRAM POU_LogDashboard
VAR
    recent_errors : STRING;
    error_count : INT;
    db_status : STRING;
    modules : STRING;
END_VAR

(* Query last 10 errors for HMI display *)
recent_errors := DEBUG_DB_QUERY(10, '', 'ERROR');

(* Get database health *)
db_status := DEBUG_DB_STATUS();

(* List active logging modules *)
modules := DEBUG_LIST_MODULES();

END_PROGRAM
```

---

## Appendix A: Quick Reference

### Logging (5)

| Function | Parameters | Description |
|----------|-----------|-------------|
| `DEBUG_TRACE(module, msg)` | 2 | Trace-level log |
| `DEBUG_LOG(module, msg)` | 2 | Debug-level log |
| `DEBUG_INFO(module, msg)` | 2 | Info-level log |
| `DEBUG_WARN(module, msg)` | 2 | Warning-level log |
| `DEBUG_ERROR(module, msg)` | 2 | Error-level log |

### Level Control (10)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `DEBUG_ENABLE(module)` | 1 | BOOL | Enable module logging |
| `DEBUG_DISABLE(module)` | 1 | BOOL | Disable module |
| `DEBUG_SET_LEVEL(module, level)` | 2 | BOOL | Set module level |
| `DEBUG_GET_LEVEL(module)` | 1 | STRING | Get module level |
| `DEBUG_SET_GLOBAL_LEVEL(level)` | 1 | BOOL | Set default level |
| `DEBUG_GET_GLOBAL_LEVEL()` | 0 | STRING | Get default level |
| `DEBUG_SYSTEM_ENABLE()` | 0 | BOOL | Master enable |
| `DEBUG_SYSTEM_DISABLE()` | 0 | BOOL | Master disable |
| `DEBUG_IS_ENABLED()` | 0 | BOOL | Master switch state |
| `DEBUG_LIST_MODULES()` | 0 | ARRAY | All module names |

### Targets (15)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `DEBUG_TO_FILE(path [, append])` | 1-2 | BOOL | Log to file |
| `DEBUG_FILE_CLOSE()` | 0 | BOOL | Stop file logging |
| `DEBUG_GET_FILE_PATH()` | 0 | STRING | Current log file path |
| `DEBUG_TO_SQLITE(path [, table])` | 1-2 | BOOL | Log to SQLite |
| `DEBUG_TO_POSTGRES(conn [, table])` | 1-2 | BOOL | Log to PostgreSQL |
| `DEBUG_DB_CLOSE()` | 0 | BOOL | Stop database logging |
| `DEBUG_DB_STATUS()` | 0 | MAP | Database connection info |
| `DEBUG_DB_QUERY(limit [, module] [, level])` | 1-3 | ARRAY | Query log entries |
| `DEBUG_TO_INFLUX(url, token, org, bucket)` | 4 | BOOL | Log to InfluxDB |
| `DEBUG_INFLUX_CLOSE()` | 0 | BOOL | Stop InfluxDB logging |
| `DEBUG_INFLUX_STATUS()` | 0 | MAP | InfluxDB connection info |
| `DEBUG_TO_SYSLOG(host_port)` | 1 | BOOL | Log to syslog (UDP) |
| `DEBUG_SYSLOG_CLOSE()` | 0 | BOOL | Stop syslog |
| `DEBUG_SYSLOG_STATUS()` | 0 | MAP | Syslog connection info |
| `DEBUG_TO_CONSOLE(enabled)` | 1 | BOOL | Enable/disable stdout |

### Ring Buffer (3)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `DEBUG_GET_BUFFER(count)` | 1 | ARRAY | Last N log messages |
| `DEBUG_GET_BUFFER_SIZE()` | 0 | INT | Buffer entry count |
| `DEBUG_CLEAR_BUFFER()` | 0 | — | Clear ring buffer |

---

*GoPLC v1.0.535 | 36 Debug & Logging Functions | File, SQLite, PostgreSQL, InfluxDB, Syslog, Console*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
