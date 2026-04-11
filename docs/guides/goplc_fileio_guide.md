# GoPLC File I/O Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 15 built-in functions for reading and writing files from Structured Text. Use them for data logging, configuration files, CSV export, recipe management, and inter-system file exchange.

There are two usage patterns:

| Pattern | Functions | Use Case |
|---------|-----------|----------|
| **Quick file ops** | `FILE_READ`, `FILE_WRITE`, `FILE_APPEND`, `FILE_READ_LINES` | Read/write entire files in one call |
| **Handle-based** | `FILE_OPEN` → `FILE_READ_LINE` / `FILE_WRITE_LINE` → `FILE_CLOSE` | Process files line by line |

```iecst
(* Quick: write entire file *)
FILE_WRITE('/data/log.csv', 'timestamp,temp,pressure\n');

(* Quick: append a line *)
FILE_APPEND('/data/log.csv', '2026-04-05T10:30:00,72.5,45.3\n');

(* Quick: read entire file *)
contents := FILE_READ('/data/config.txt');
```

### Sandbox Security

All file paths are validated against a sandbox directory. Path traversal (`../`) is blocked. Files outside the sandbox cannot be accessed. The sandbox root is configured at runtime.

---

## 2. Quick File Operations

### FILE_READ — Read Entire File

```iecst
contents := FILE_READ('/data/config.txt');
```

| Param | Type | Description |
|-------|------|-------------|
| `path` | STRING | File path |

Returns: `STRING` — entire file contents. Empty string if file not found.

### FILE_READ_LINES — Read File as Line Array

```iecst
lines := FILE_READ_LINES('/data/recipe.csv');
(* Returns array: ["header1,header2", "val1,val2", "val3,val4"] *)
```

Returns: `ARRAY` of strings, one per line. Newlines are stripped.

### FILE_WRITE — Write Entire File

Creates the file if it doesn't exist. Creates parent directories automatically. Overwrites existing content.

```iecst
ok := FILE_WRITE('/data/output.txt', 'Hello World');
```

| Param | Type | Description |
|-------|------|-------------|
| `path` | STRING | File path |
| `data` | STRING | Content to write |

Returns: `BOOL` — TRUE on success.

### FILE_APPEND — Append to File

Creates the file and parent directories if they don't exist. Adds data to the end without overwriting.

```iecst
ok := FILE_APPEND('/data/log.csv', CONCAT(timestamp, ',', REAL_TO_STRING(temp), '\n'));
```

| Param | Type | Description |
|-------|------|-------------|
| `path` | STRING | File path |
| `data` | STRING | Content to append |

Returns: `BOOL` — TRUE on success.

---

## 3. Handle-Based Operations

For line-by-line processing, open a file handle, read/write lines, then close.

### FILE_OPEN — Open File

```iecst
handle := FILE_OPEN('/data/log.csv', 'r');    (* Read *)
handle := FILE_OPEN('/data/output.csv', 'w'); (* Write — creates/truncates *)
handle := FILE_OPEN('/data/log.csv', 'a');    (* Append *)
```

| Param | Type | Description |
|-------|------|-------------|
| `path` | STRING | File path |
| `mode` | STRING | `'r'` = read, `'w'` = write (create/truncate), `'a'` = append |

Returns: `INT` — file handle (0 on error). Parent directories are auto-created for write/append modes.

### FILE_READ_LINE — Read One Line

```iecst
line := FILE_READ_LINE(handle);
```

Returns: `STRING` — one line (newline stripped). Use with `FILE_EOF` to detect end of file.

### FILE_WRITE_LINE — Write One Line

Writes data followed by a newline character.

```iecst
bytes := FILE_WRITE_LINE(handle, 'timestamp,temp,pressure');
```

Returns: `INT` — bytes written.

### FILE_EOF — Check End of File

```iecst
IF FILE_EOF(handle) THEN
    FILE_CLOSE(handle);
END_IF;
```

Returns: `BOOL` — TRUE if file pointer is at the end.

### FILE_CLOSE — Close File Handle

```iecst
ok := FILE_CLOSE(handle);
```

Returns: `BOOL` — TRUE on success.

### Example: Process CSV Line by Line

```iecst
PROGRAM POU_ReadCSV
VAR
    handle : INT;
    line : STRING;
    state : INT := 0;
    line_count : INT := 0;
END_VAR

CASE state OF
    0: (* Open file *)
        handle := FILE_OPEN('/data/recipe.csv', 'r');
        IF handle > 0 THEN
            state := 1;
        END_IF;

    1: (* Read lines *)
        IF NOT FILE_EOF(handle) THEN
            line := FILE_READ_LINE(handle);
            line_count := line_count + 1;
            (* Process line... *)
        ELSE
            FILE_CLOSE(handle);
            state := 10;
        END_IF;

    10: (* Done *)
END_CASE;
END_PROGRAM
```

---

## 4. File Management

### FILE_EXISTS — Check if File Exists

```iecst
IF FILE_EXISTS('/data/config.txt') THEN
    config := FILE_READ('/data/config.txt');
END_IF;
```

### FILE_SIZE — Get File Size

```iecst
size := FILE_SIZE('/data/log.csv');
(* Returns: size in bytes *)
```

### FILE_MODIFIED — Get Modification Timestamp

```iecst
ts := FILE_MODIFIED('/data/config.txt');
(* Returns: Unix timestamp in milliseconds *)
```

### FILE_DELETE — Delete File

```iecst
ok := FILE_DELETE('/data/old_log.csv');
```

### FILE_COPY — Copy File

```iecst
ok := FILE_COPY('/data/config.txt', '/data/config_backup.txt');
```

Both source and destination paths are validated against the sandbox.

### FILE_MOVE — Move/Rename File

```iecst
ok := FILE_MOVE('/data/temp.csv', '/data/final.csv');
```

---

## 5. Complete Example: Data Logger

Log process data to a CSV file with daily rotation:

```iecst
PROGRAM POU_DataLogger
VAR
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;
    log_interval : DINT := 100;    (* Every 100 scans = 10s at 100ms *)
    ok : BOOL;

    (* Process data *)
    temperature : REAL;
    pressure : REAL;
    flow_rate : REAL;

    (* Logging *)
    log_path : STRING;
    line : STRING;
    timestamp : STRING;
END_VAR

scan_count := scan_count + 1;

(* Build log path *)
log_path := '/data/logs/process_log.csv';

(* Create header on first run *)
IF NOT initialized THEN
    IF NOT FILE_EXISTS(log_path) THEN
        FILE_WRITE(log_path, 'timestamp,temperature,pressure,flow_rate\n');
    END_IF;
    initialized := TRUE;
END_IF;

(* Log at interval *)
IF (scan_count MOD log_interval) = 0 THEN
    timestamp := DT_TO_STRING(NOW());
    line := CONCAT(
        timestamp, ',',
        REAL_TO_STRING(temperature), ',',
        REAL_TO_STRING(pressure), ',',
        REAL_TO_STRING(flow_rate), CHR(10)
    );
    FILE_APPEND(log_path, line);

    (* Check file size — rotate if > 10MB *)
    IF FILE_SIZE(log_path) > 10485760 THEN
        FILE_MOVE(log_path, CONCAT('/data/logs/process_log_', timestamp, '.csv'));
        FILE_WRITE(log_path, 'timestamp,temperature,pressure,flow_rate\n');
    END_IF;
END_IF;

END_PROGRAM
```

---

## 6. Complete Example: Recipe Manager

Load and save recipe files:

```iecst
PROGRAM POU_RecipeManager
VAR
    state : INT := 0;
    recipe_name : STRING := 'default';
    recipe_path : STRING;
    recipe_json : STRING;
    doc : STRING;

    (* Recipe parameters *)
    setpoint_temp : REAL;
    setpoint_pressure : REAL;
    mix_time_sec : INT;
    batch_size : INT;
END_VAR

recipe_path := CONCAT('/data/recipes/', recipe_name, '.json');

CASE state OF
    0: (* Load recipe *)
        IF FILE_EXISTS(recipe_path) THEN
            recipe_json := FILE_READ(recipe_path);
            doc := JSON_PARSE(recipe_json);
            setpoint_temp := JSON_GET_REAL(doc, 'temperature');
            setpoint_pressure := JSON_GET_REAL(doc, 'pressure');
            mix_time_sec := JSON_GET_INT(doc, 'mix_time');
            batch_size := JSON_GET_INT(doc, 'batch_size');
            state := 10;
        ELSE
            (* Use defaults *)
            setpoint_temp := 180.0;
            setpoint_pressure := 50.0;
            mix_time_sec := 300;
            batch_size := 100;
            state := 10;
        END_IF;

    10: (* Running — save on change *)
        (* Save recipe *)
        doc := JSON_OBJECT(
            'temperature', setpoint_temp,
            'pressure', setpoint_pressure,
            'mix_time', mix_time_sec,
            'batch_size', batch_size
        );
        FILE_WRITE(recipe_path, JSON_STRINGIFY(doc, TRUE));
END_CASE;
END_PROGRAM
```

---

## Appendix A: Quick Reference

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `FILE_READ` | `(path)` | STRING | Read entire file |
| `FILE_READ_LINES` | `(path)` | ARRAY | Read file as line array |
| `FILE_WRITE` | `(path, data)` | BOOL | Write entire file (creates parents) |
| `FILE_APPEND` | `(path, data)` | BOOL | Append to file (creates parents) |
| `FILE_OPEN` | `(path, mode)` | INT (handle) | Open file: 'r', 'w', 'a' |
| `FILE_READ_LINE` | `(handle)` | STRING | Read one line |
| `FILE_WRITE_LINE` | `(handle, data)` | INT | Write line + newline |
| `FILE_EOF` | `(handle)` | BOOL | TRUE if at end of file |
| `FILE_CLOSE` | `(handle)` | BOOL | Close file handle |
| `FILE_EXISTS` | `(path)` | BOOL | Check if file exists |
| `FILE_SIZE` | `(path)` | INT | File size in bytes |
| `FILE_MODIFIED` | `(path)` | INT | Modification timestamp (Unix ms) |
| `FILE_DELETE` | `(path)` | BOOL | Delete file |
| `FILE_COPY` | `(src, dst)` | BOOL | Copy file |
| `FILE_MOVE` | `(src, dst)` | BOOL | Move/rename file |

---

*GoPLC v1.0.535 | 15 File I/O Functions | Sandboxed File Access from ST*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
