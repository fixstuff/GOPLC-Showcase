# GoPLC CSV & INI Parsing Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 20 built-in functions for working with two common data file formats from Structured Text:

| Format | Functions | Use Case |
|--------|-----------|----------|
| **CSV** | 10 | Data import/export, recipes, tag lists, report generation |
| **INI** | 10 | Configuration files, device settings, recipe parameters |

Both support in-memory parsing (string → handle → query/modify → string) and CSV/INI files can be combined with the FILE_* functions for disk operations.

---

## 2. CSV Functions

### Parse CSV Data

```iecst
(* Parse a CSV string — first row treated as headers *)
data := CSV_PARSE('name,temp,pressure
Pump-1,72.5,45.3
Pump-2,68.1,42.0
Pump-3,71.8,44.7');

rows := CSV_ROW_COUNT(data);          (* 4 — includes header row *)
cols := CSV_COL_COUNT(data);          (* 3 *)
```

| Param | Type | Description |
|-------|------|-------------|
| `text` | STRING | CSV text to parse |
| `delimiter` | STRING | Optional — custom delimiter (default: comma) |

Returns: handle for use with other CSV_* functions.

### Read Fields

```iecst
(* By row/column index — 0-based *)
name := CSV_GET_FIELD(data, 1, 0);    (* "Pump-1" — row 1, col 0 *)
temp := CSV_GET_FIELD(data, 1, 1);    (* "72.5" *)

(* Get entire row as array *)
row := CSV_GET_ROW(data, 2);          (* ["Pump-2", "68.1", "42.0"] *)

(* Get headers *)
headers := CSV_GET_HEADER(data);      (* ["name", "temp", "pressure"] *)

(* Find column index by header name *)
temp_col := CSV_FIND_COL(data, 'temp');    (* 1 *)
press_col := CSV_FIND_COL(data, 'pressure'); (* 2 *)

(* Name-based access: find column, then read *)
temp_val := CSV_GET_FIELD(data, 1, CSV_FIND_COL(data, 'temp'));
```

### Modify CSV

```iecst
(* Update a field *)
data := CSV_SET_FIELD(data, 1, 1, '75.0');

(* Add a new row *)
data := CSV_ADD_ROW(data, 'Pump-4', '69.5', '41.2');
```

### Export to String

```iecst
csv_text := CSV_TO_STRING(data);

(* With custom delimiter *)
tsv_text := CSV_TO_STRING(data, CHR(9));    (* Tab-separated *)
```

### Parse with Custom Delimiter

```iecst
(* Tab-separated *)
data := CSV_PARSE(tsv_content, CHR(9));

(* Semicolon-separated (European format) *)
data := CSV_PARSE(euro_content, ';');
```

### Example: Load Recipe from CSV File

```iecst
PROGRAM POU_CSVRecipe
VAR
    state : INT := 0;
    csv_text : STRING;
    data : STRING;
    recipe_count : INT;
    i : INT;
    name : STRING;
    temp : REAL;
    pressure : REAL;
    time_sec : INT;
    name_col : INT;
    temp_col : INT;
    press_col : INT;
    time_col : INT;
END_VAR

CASE state OF
    0: (* Read CSV file *)
        IF FILE_EXISTS('/data/recipes.csv') THEN
            csv_text := FILE_READ('/data/recipes.csv');
            data := CSV_PARSE(csv_text);

            (* Find columns by header name *)
            name_col := CSV_FIND_COL(data, 'name');
            temp_col := CSV_FIND_COL(data, 'temperature');
            press_col := CSV_FIND_COL(data, 'pressure');
            time_col := CSV_FIND_COL(data, 'time');

            recipe_count := CSV_ROW_COUNT(data) - 1;    (* Exclude header *)
            state := 10;
        END_IF;

    10: (* Process recipes — skip row 0 (headers) *)
        FOR i := 1 TO recipe_count DO
            name := CSV_GET_FIELD(data, i, name_col);
            temp := STRING_TO_REAL(CSV_GET_FIELD(data, i, temp_col));
            pressure := STRING_TO_REAL(CSV_GET_FIELD(data, i, press_col));
            time_sec := STRING_TO_INT(CSV_GET_FIELD(data, i, time_col));
            (* Use recipe values... *)
        END_FOR;
END_CASE;
END_PROGRAM
```

### Example: Generate CSV Report

```iecst
PROGRAM POU_CSVReport
VAR
    data : STRING;
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;
    temperature : REAL;
    pressure : REAL;
END_VAR

IF NOT initialized THEN
    (* Create CSV with headers *)
    data := CSV_PARSE('timestamp,temperature,pressure');
    initialized := TRUE;
END_IF;

scan_count := scan_count + 1;

(* Add a row every 100 scans *)
IF (scan_count MOD 100) = 0 THEN
    data := CSV_ADD_ROW(data,
        DT_TO_STRING(NOW()),
        REAL_TO_STRING(temperature),
        REAL_TO_STRING(pressure)
    );

    (* Save to file every 1000 scans *)
    IF (scan_count MOD 1000) = 0 THEN
        FILE_WRITE('/data/report.csv', CSV_TO_STRING(data));
    END_IF;
END_IF;
END_PROGRAM
```

---

## 3. INI Functions

INI files use a `[section]` + `key=value` format common in device configuration.

### Two Access Patterns

| Pattern | Functions | Description |
|---------|-----------|-------------|
| **File I/O** | `INI_READ`, `INI_WRITE` | Read/write directly to disk |
| **In-Memory** | `INI_PARSE` → query/modify → `INI_TO_STRING` | Parse string, manipulate, serialize |

### Direct File Access

```iecst
(* Read a value from an INI file *)
host := INI_READ('/data/config.ini', 'modbus', 'host', '10.0.0.50');
port := INI_READ('/data/config.ini', 'modbus', 'port', '502');

(* Write a value to an INI file *)
INI_WRITE('/data/config.ini', 'modbus', 'host', '10.0.0.51');
INI_WRITE('/data/config.ini', 'runtime', 'scan_ms', '50');
```

| Param | Type | Description |
|-------|------|-------------|
| `filepath` | STRING | Path to .ini file |
| `section` | STRING | Section name (without brackets) |
| `key` | STRING | Key name |
| `default` | STRING | INI_READ only — returned if key not found |

INI_WRITE creates the file, section, and key if they don't exist.

### In-Memory Parsing

```iecst
(* Parse INI text *)
cfg := INI_PARSE('
[modbus]
host=10.0.0.50
port=502
unit_id=1

[mqtt]
broker=tcp://10.0.0.144:1883
topic_prefix=plant/data
');

(* Read values *)
host := INI_GET(cfg, 'modbus', 'host', '');           (* "10.0.0.50" *)
port := INI_GET(cfg, 'modbus', 'port', '502');        (* "502" *)
broker := INI_GET(cfg, 'mqtt', 'broker', '');          (* "tcp://10.0.0.144:1883" *)

(* List sections and keys *)
sections := INI_SECTIONS(cfg);                         (* ["modbus", "mqtt"] *)
keys := INI_KEYS(cfg, 'modbus');                       (* ["host", "port", "unit_id"] *)
```

### Modify In-Memory

```iecst
(* Set/update values *)
cfg := INI_SET(cfg, 'modbus', 'host', '10.0.0.51');
cfg := INI_SET(cfg, 'modbus', 'timeout_ms', '5000');   (* Adds new key *)
cfg := INI_SET(cfg, 'logging', 'level', 'info');        (* Creates new section *)

(* Delete *)
cfg := INI_DELETE_KEY(cfg, 'modbus', 'timeout_ms');
cfg := INI_DELETE_SECTION(cfg, 'logging');

(* Serialize back to string *)
ini_text := INI_TO_STRING(cfg);

(* Save to file *)
FILE_WRITE('/data/config.ini', ini_text);
```

### Example: Device Configuration Manager

```iecst
PROGRAM POU_DeviceConfig
VAR
    state : INT := 0;
    cfg : STRING;
    ini_text : STRING;

    (* Loaded config *)
    mb_host : STRING;
    mb_port : INT;
    mb_unit : INT;
    scan_ms : INT;
    log_level : STRING;
END_VAR

CASE state OF
    0: (* Load config file *)
        IF FILE_EXISTS('/data/device.ini') THEN
            ini_text := FILE_READ('/data/device.ini');
            cfg := INI_PARSE(ini_text);
        ELSE
            (* Create default config *)
            cfg := INI_PARSE('');
            cfg := INI_SET(cfg, 'modbus', 'host', '10.0.0.50');
            cfg := INI_SET(cfg, 'modbus', 'port', '502');
            cfg := INI_SET(cfg, 'modbus', 'unit_id', '1');
            cfg := INI_SET(cfg, 'runtime', 'scan_ms', '50');
            cfg := INI_SET(cfg, 'runtime', 'log_level', 'info');
            FILE_WRITE('/data/device.ini', INI_TO_STRING(cfg));
        END_IF;

        (* Apply config *)
        mb_host := INI_GET(cfg, 'modbus', 'host', '10.0.0.50');
        mb_port := STRING_TO_INT(INI_GET(cfg, 'modbus', 'port', '502'));
        mb_unit := STRING_TO_INT(INI_GET(cfg, 'modbus', 'unit_id', '1'));
        scan_ms := STRING_TO_INT(INI_GET(cfg, 'runtime', 'scan_ms', '50'));
        log_level := INI_GET(cfg, 'runtime', 'log_level', 'info');
        state := 10;

    10: (* Running — config applied *)
END_CASE;
END_PROGRAM
```

---

## Appendix A: Quick Reference

### CSV Functions (10)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `CSV_PARSE(text [, delim])` | 1-2 | Handle | Parse CSV string |
| `CSV_GET_FIELD(h, row, col)` | 3 | STRING | Read field by index |
| `CSV_GET_ROW(h, row)` | 2 | ARRAY | Get entire row |
| `CSV_GET_HEADER(h)` | 1 | ARRAY | Get first row (headers) |
| `CSV_FIND_COL(h, name)` | 2 | INT | Find column by header name (-1 if missing) |
| `CSV_ROW_COUNT(h)` | 1 | INT | Number of rows (including header) |
| `CSV_COL_COUNT(h [, row])` | 1-2 | INT | Number of columns |
| `CSV_SET_FIELD(h, row, col, val)` | 4 | Handle | Update field |
| `CSV_ADD_ROW(h, val1, val2, ...)` | 2+ | Handle | Append row |
| `CSV_TO_STRING(h [, delim])` | 1-2 | STRING | Serialize to CSV text |

### INI Functions (10)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `INI_READ(path, section, key [, default])` | 3-4 | STRING | Read from file |
| `INI_WRITE(path, section, key, value)` | 4 | BOOL | Write to file |
| `INI_PARSE(text)` | 1 | Handle | Parse INI string |
| `INI_GET(h, section, key [, default])` | 3-4 | STRING | Read from handle |
| `INI_SET(h, section, key, value)` | 4 | Handle | Set value in handle |
| `INI_SECTIONS(h)` | 1 | ARRAY | List section names |
| `INI_KEYS(h, section)` | 2 | ARRAY | List keys in section |
| `INI_TO_STRING(h)` | 1 | STRING | Serialize to INI text |
| `INI_DELETE_KEY(h, section, key)` | 3 | Handle | Remove key |
| `INI_DELETE_SECTION(h, section)` | 2 | Handle | Remove section |

---

*GoPLC v1.0.535 | 20 CSV & INI Functions | Data Import/Export & Configuration*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
