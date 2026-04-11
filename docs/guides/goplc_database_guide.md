# GoPLC Database Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 18 built-in functions for working with databases from Structured Text. Run SQL queries, insert records, manage transactions, and create tables — all from your PLC program. No external drivers or configuration needed.

### Supported Databases

| Database | Type String | Connection String Format |
|----------|-------------|------------------------|
| **SQLite** | `'sqlite'` | `'/path/to/database.db'` |
| **PostgreSQL** | `'postgres'` | `'postgres://user:pass@host:port/dbname?sslmode=disable'` |
| **MySQL/MariaDB** | `'mysql'` | `'user:pass@tcp(host:port)/dbname'` |

```iecst
(* SQLite — local file, zero config *)
ok := DB_CONNECT('sqlite', '/data/process.db');

(* PostgreSQL — network server *)
ok := DB_CONNECT('postgres', 'postgres://goplc:secret@10.0.0.144:5432/plant?sslmode=disable');

(* MySQL — network server *)
ok := DB_CONNECT('mysql', 'goplc:secret@tcp(10.0.0.144:3306)/plant');
```

### Named Connections

Every connection has a name. If you don't specify one, it defaults to `'default'`. Use names to work with multiple databases simultaneously:

```iecst
DB_CONNECT('sqlite', '/data/local.db', 'local');
DB_CONNECT('postgres', 'postgres://...', 'historian');
```

---

## 2. Connection Management

### DB_CONNECT — Open Database Connection

```iecst
ok := DB_CONNECT('sqlite', '/data/process.db');               (* Default name *)
ok := DB_CONNECT('postgres', 'postgres://...', 'historian');   (* Named *)
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | STRING | Yes | `'sqlite'`, `'postgres'`, or `'mysql'` |
| `conn_string` | STRING | Yes | Database-specific connection string |
| `name` | STRING | No | Connection name (default: `'default'`) |

### DB_DISCONNECT — Close Connection

Alias: `DB_CLOSE`

```iecst
ok := DB_DISCONNECT();              (* Close default *)
ok := DB_DISCONNECT('historian');   (* Close named *)
```

Rolls back any active transaction before closing.

### DB_IS_CONNECTED — Check Connection Health

```iecst
IF NOT DB_IS_CONNECTED('historian') THEN
    DB_CONNECT('postgres', 'postgres://...', 'historian');
END_IF;
```

Pings the database to verify the connection is alive.

### DB_STATUS — Connection Details

```iecst
status := DB_STATUS('historian');
(* Returns: {"type":"postgres","connected":true,"open_connections":2,
             "idle_count":1,"in_transaction":false} *)
```

### DB_LIST_CONNECTIONS — List All Connections

```iecst
conns := DB_LIST_CONNECTIONS();
(* Returns: ["default", "historian"] *)
```

---

## 3. Queries

### DB_QUERY — SELECT (Multiple Rows)

Returns an array of row objects. Each row is a map of column names to values.

```iecst
rows := DB_QUERY('SELECT timestamp, temp, pressure FROM readings ORDER BY timestamp DESC LIMIT 10');
```

With parameterized queries (prevents SQL injection):

```iecst
rows := DB_QUERY('SELECT * FROM alarms WHERE severity >= $1 AND acknowledged = $2', 3, FALSE);
```

| Param | Type | Description |
|-------|------|-------------|
| `query` | STRING | SQL SELECT statement |
| `params` | ANY | Optional bind parameters ($1, $2, ... for Postgres; ? for MySQL/SQLite) |

Returns: `ARRAY` of maps — `[{"col1": val1, "col2": val2}, ...]`

### DB_QUERY_ROW — SELECT (Single Row)

Returns the first row as a map, or nil if no results.

```iecst
row := DB_QUERY_ROW('SELECT * FROM config WHERE key = $1', 'scan_time');
IF row <> NIL THEN
    value := JSON_GET_STRING(row, 'value');
END_IF;
```

### DB_QUERY_VALUE — SELECT (Single Value)

Returns the first column of the first row. Ideal for `COUNT(*)`, `MAX()`, `SUM()`, etc.

```iecst
count := DB_QUERY_VALUE('SELECT COUNT(*) FROM alarms WHERE active = TRUE');
max_temp := DB_QUERY_VALUE('SELECT MAX(temperature) FROM readings WHERE date = $1', today);
```

### Using Named Connections

Append `@conn=name` as the last parameter to target a specific connection:

```iecst
(* Query the historian database *)
rows := DB_QUERY('SELECT * FROM readings LIMIT 5', '@conn=historian');

(* Query with params AND named connection *)
rows := DB_QUERY('SELECT * FROM alarms WHERE severity >= $1', 3, '@conn=historian');
```

---

## 4. Writes

### DB_EXEC — INSERT / UPDATE / DELETE

Executes any non-SELECT SQL statement. Returns the number of rows affected.

```iecst
(* Insert *)
affected := DB_EXEC(
    'INSERT INTO readings (timestamp, temperature, pressure) VALUES ($1, $2, $3)',
    NOW(), temperature, pressure
);

(* Update *)
affected := DB_EXEC(
    'UPDATE config SET value = $1 WHERE key = $2',
    '100', 'scan_time'
);

(* Delete *)
affected := DB_EXEC('DELETE FROM readings WHERE timestamp < $1', cutoff_date);
```

Returns: `INT` — rows affected (-1 on error).

### DB_LAST_INSERT_ID — Get Auto-Increment ID

```iecst
DB_EXEC('INSERT INTO events (type, message) VALUES ($1, $2)', 'ALARM', 'High temp');
new_id := DB_LAST_INSERT_ID();
```

### DB_ROWS_AFFECTED — Get Row Count

```iecst
DB_EXEC('UPDATE alarms SET acknowledged = TRUE WHERE id = $1', alarm_id);
changed := DB_ROWS_AFFECTED();
```

---

## 5. Transactions

Group multiple operations into an atomic unit — either all succeed or all roll back.

### DB_BEGIN — Start Transaction

Alias: `DB_BEGIN_TX`

```iecst
ok := DB_BEGIN();
```

### DB_COMMIT — Commit Transaction

```iecst
ok := DB_COMMIT();
```

### DB_ROLLBACK — Roll Back Transaction

```iecst
ok := DB_ROLLBACK();
```

### DB_IN_TRANSACTION — Check Transaction State

```iecst
IF DB_IN_TRANSACTION() THEN
    DB_COMMIT();
END_IF;
```

### Example: Atomic Batch Insert

```iecst
DB_BEGIN();

ok1 := DB_EXEC('INSERT INTO batch (id, product) VALUES ($1, $2)', batch_id, 'Widget-A');
ok2 := DB_EXEC('INSERT INTO batch_log (batch_id, event) VALUES ($1, $2)', batch_id, 'started');
ok3 := DB_EXEC('UPDATE inventory SET reserved = reserved + $1 WHERE product = $2', qty, 'Widget-A');

IF ok1 >= 0 AND ok2 >= 0 AND ok3 >= 0 THEN
    DB_COMMIT();
ELSE
    DB_ROLLBACK();
END_IF;
```

---

## 6. Schema Management

### DB_TABLE_EXISTS — Check Table

```iecst
IF NOT DB_TABLE_EXISTS('readings') THEN
    (* Create table... *)
END_IF;
```

### DB_LIST_TABLES — List All Tables

```iecst
tables := DB_LIST_TABLES();
(* Returns: ["readings", "alarms", "config"] *)
```

### DB_CREATE_TABLE — Create Table

```iecst
ok := DB_CREATE_TABLE('readings', JSON_PARSE('{
    "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
    "timestamp": "DATETIME DEFAULT CURRENT_TIMESTAMP",
    "temperature": "REAL NOT NULL",
    "pressure": "REAL NOT NULL",
    "flow_rate": "REAL"
}'));
```

| Param | Type | Description |
|-------|------|-------------|
| `table` | STRING | Table name |
| `columns` | MAP | Column definitions: `{"name": "TYPE CONSTRAINTS", ...}` |

---

## 7. Complete Example: Process Historian

Log process data to SQLite with automatic table creation and periodic cleanup:

```iecst
PROGRAM POU_Historian
VAR
    state : INT := 0;
    scan_count : DINT := 0;
    log_interval : DINT := 100;   (* Every 10s at 100ms scan *)
    ok : BOOL;
    affected : INT;

    (* Process data *)
    temperature : REAL;
    pressure : REAL;
    flow_rate : REAL;
    motor_running : BOOL;
END_VAR

CASE state OF
    0: (* Connect to SQLite *)
        ok := DB_CONNECT('sqlite', '/data/historian.db');
        IF ok THEN state := 1; END_IF;

    1: (* Create table if needed *)
        IF NOT DB_TABLE_EXISTS('process_data') THEN
            DB_CREATE_TABLE('process_data', JSON_PARSE('{
                "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
                "ts": "DATETIME DEFAULT CURRENT_TIMESTAMP",
                "temperature": "REAL",
                "pressure": "REAL",
                "flow_rate": "REAL",
                "motor_running": "INTEGER"
            }'));
        END_IF;

        IF NOT DB_TABLE_EXISTS('alarms') THEN
            DB_CREATE_TABLE('alarms', JSON_PARSE('{
                "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
                "ts": "DATETIME DEFAULT CURRENT_TIMESTAMP",
                "severity": "INTEGER",
                "message": "TEXT",
                "acknowledged": "INTEGER DEFAULT 0"
            }'));
        END_IF;
        state := 10;

    10: (* Running — log data *)
        scan_count := scan_count + 1;

        IF (scan_count MOD log_interval) = 0 THEN
            DB_EXEC(
                'INSERT INTO process_data (temperature, pressure, flow_rate, motor_running) VALUES ($1, $2, $3, $4)',
                temperature, pressure, flow_rate, motor_running
            );

            (* Check alarms *)
            IF temperature > 180.0 THEN
                DB_EXEC(
                    'INSERT INTO alarms (severity, message) VALUES ($1, $2)',
                    3, CONCAT('High temp: ', REAL_TO_STRING(temperature))
                );
            END_IF;
        END_IF;

        (* Cleanup old data every 10000 scans (~16 min) *)
        IF (scan_count MOD 10000) = 0 THEN
            DB_EXEC('DELETE FROM process_data WHERE ts < datetime("now", "-7 days")');
        END_IF;

        (* Reconnect if needed *)
        IF NOT DB_IS_CONNECTED() THEN
            state := 0;
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 8. Complete Example: Alarm Dashboard Query

Read alarm history for an HMI display:

```iecst
PROGRAM POU_AlarmDashboard
VAR
    active_count : INT;
    recent_alarms : STRING;
    alarm_row : STRING;
    unacked : INT;
END_VAR

(* Count active alarms *)
active_count := DB_QUERY_VALUE('SELECT COUNT(*) FROM alarms WHERE acknowledged = 0');

(* Get 10 most recent *)
recent_alarms := DB_QUERY(
    'SELECT ts, severity, message FROM alarms ORDER BY ts DESC LIMIT 10'
);

(* Acknowledge an alarm by ID *)
IF ack_alarm_id > 0 THEN
    DB_EXEC('UPDATE alarms SET acknowledged = 1 WHERE id = $1', ack_alarm_id);
    ack_alarm_id := 0;
END_IF;

END_PROGRAM
```

---

## Appendix A: Quick Reference

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `DB_CONNECT` | `(type, conn_string [, name])` | BOOL | Open database connection |
| `DB_DISCONNECT` | `([name])` | BOOL | Close connection. Alias: `DB_CLOSE` |
| `DB_IS_CONNECTED` | `([name])` | BOOL | Ping database |
| `DB_STATUS` | `([name])` | MAP | Connection metadata |
| `DB_LIST_CONNECTIONS` | `()` | ARRAY | All connection names |
| `DB_QUERY` | `(sql [, params...])` | ARRAY | SELECT → array of row maps |
| `DB_QUERY_ROW` | `(sql [, params...])` | MAP | SELECT → first row |
| `DB_QUERY_VALUE` | `(sql [, params...])` | ANY | SELECT → first column of first row |
| `DB_EXEC` | `(sql [, params...])` | INT | INSERT/UPDATE/DELETE → rows affected |
| `DB_LAST_INSERT_ID` | `([name])` | INT | Last auto-increment ID |
| `DB_ROWS_AFFECTED` | `([name])` | INT | Rows from last DB_EXEC |
| `DB_BEGIN` | `([name])` | BOOL | Start transaction. Alias: `DB_BEGIN_TX` |
| `DB_COMMIT` | `([name])` | BOOL | Commit transaction |
| `DB_ROLLBACK` | `([name])` | BOOL | Roll back transaction |
| `DB_IN_TRANSACTION` | `([name])` | BOOL | Check transaction state |
| `DB_TABLE_EXISTS` | `(table)` | BOOL | Check if table exists |
| `DB_LIST_TABLES` | `()` | ARRAY | List all table names |
| `DB_CREATE_TABLE` | `(table, columns)` | BOOL | Create table from column map |

---

*GoPLC v1.0.535 | 18 Database Functions | SQLite, PostgreSQL, MySQL/MariaDB*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
