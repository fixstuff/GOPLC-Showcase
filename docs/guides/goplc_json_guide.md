# GoPLC JSON Functions Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 22 built-in functions for parsing, building, querying, and modifying JSON from Structured Text. JSON is the interchange format for MQTT payloads, HTTP API responses, configuration data, and inter-system messaging.

All JSON functions work with **handles** — opaque string identifiers returned by `JSON_PARSE` or `JSON_OBJECT`. You pass the handle to other functions to read or modify the data. This avoids re-parsing on every access.

```iecst
(* Parse → Query → Use *)
doc := JSON_PARSE('{"temp": 72.5, "unit": "F"}');
temp := JSON_GET_REAL(doc, 'temp');
unit := JSON_GET_STRING(doc, 'unit');
```

---

## 2. Parsing and Validation

### JSON_PARSE — Parse JSON String

Parses a JSON string and returns a handle for subsequent operations.

```iecst
doc := JSON_PARSE('{"name": "Pump-1", "speed": 1750, "running": true}');
```

| Param | Type | Description |
|-------|------|-------------|
| `json_string` | STRING | Valid JSON string |

Returns: `STRING` — handle to the parsed object. Empty string on parse error.

### JSON_VALID — Check if String is Valid JSON

```iecst
IF JSON_VALID(payload) THEN
    doc := JSON_PARSE(payload);
END_IF;
```

Returns: `BOOL` — TRUE if the string is valid JSON.

### JSON_STRINGIFY — Convert Back to String

Alias: `JSON_ENCODE`

```iecst
str := JSON_STRINGIFY(doc);
(* Returns: '{"name":"Pump-1","speed":1750,"running":true}' *)

pretty := JSON_STRINGIFY(doc, TRUE);
(* Returns formatted with indentation *)
```

| Param | Type | Description |
|-------|------|-------------|
| `handle` | STRING | JSON handle |
| `indent` | BOOL | Optional — TRUE for pretty-printed output |

Returns: `STRING` — JSON string.

---

## 3. Reading Values

### JSON_GET — Read Any Value

Returns the value at the given path. Type is inferred automatically.

```iecst
val := JSON_GET(doc, 'name');        (* Returns: "Pump-1" *)
val := JSON_GET(doc, 'speed');       (* Returns: 1750 *)
val := JSON_GET(doc, 'running');     (* Returns: TRUE *)
```

| Param | Type | Description |
|-------|------|-------------|
| `handle` | STRING | JSON handle |
| `path` | STRING | Dot-notation path (see Path Syntax below) |

### Typed Getters

For type safety, use the typed variants:

| Function | Returns | Default |
|----------|---------|---------|
| `JSON_GET_STRING(handle, path)` | STRING | `""` |
| `JSON_GET_INT(handle, path)` | INT | `0` |
| `JSON_GET_REAL(handle, path)` | REAL | `0.0` |
| `JSON_GET_BOOL(handle, path)` | BOOL | `FALSE` |

```iecst
name := JSON_GET_STRING(doc, 'name');       (* "Pump-1" *)
speed := JSON_GET_INT(doc, 'speed');         (* 1750 *)
temp := JSON_GET_REAL(doc, 'temperature');   (* 72.5 *)
ok := JSON_GET_BOOL(doc, 'running');         (* TRUE *)
```

### JSON_GET_ARRAY — Read Array Element

```iecst
doc := JSON_PARSE('{"temps": [68.2, 72.5, 71.0]}');
first := JSON_GET_ARRAY(doc, 'temps', 0);    (* 68.2 *)
second := JSON_GET_ARRAY(doc, 'temps', 1);   (* 72.5 *)
```

| Param | Type | Description |
|-------|------|-------------|
| `handle` | STRING | JSON handle |
| `path` | STRING | Path to the array |
| `index` | INT | Array index (0-based) |

### JSON_ARRAY_LENGTH — Get Array Size

```iecst
count := JSON_ARRAY_LENGTH(doc, 'temps');    (* 3 *)
```

---

## 4. Path Syntax

All get/set/delete functions use **dot-notation paths** to navigate nested structures:

```iecst
doc := JSON_PARSE('{
    "site": "Plant-A",
    "units": [
        {"name": "Pump-1", "speed": 1750},
        {"name": "Pump-2", "speed": 1200}
    ],
    "config": {
        "network": {
            "ip": "10.0.0.50",
            "port": 502
        }
    }
}');

(* Simple key *)
site := JSON_GET_STRING(doc, 'site');                    (* "Plant-A" *)

(* Nested object *)
ip := JSON_GET_STRING(doc, 'config.network.ip');         (* "10.0.0.50" *)
port := JSON_GET_INT(doc, 'config.network.port');        (* 502 *)

(* Array element by index *)
name := JSON_GET_STRING(doc, 'units.0.name');            (* "Pump-1" *)
speed := JSON_GET_INT(doc, 'units.1.speed');             (* 1200 *)
```

### JSON_PATH — JSONPath Syntax

For more complex queries, use JSONPath notation:

```iecst
val := JSON_PATH(doc, '$.config.network.ip');            (* "10.0.0.50" *)
val := JSON_PATH(doc, '$.units[0].name');                (* "Pump-1" *)
```

The `$` prefix is optional.

---

## 5. Modifying JSON

### JSON_SET — Set a Value

Creates or updates a value at the given path. Creates intermediate objects as needed.

```iecst
doc := JSON_PARSE('{"temp": 72.5}');
doc := JSON_SET(doc, 'temp', 75.0);                     (* Update existing *)
doc := JSON_SET(doc, 'pressure', 101.3);                (* Add new key *)
doc := JSON_SET(doc, 'config.unit', 'PSI');              (* Create nested *)
```

| Param | Type | Description |
|-------|------|-------------|
| `handle` | STRING | JSON handle |
| `path` | STRING | Dot-notation path |
| `value` | ANY | Value to set |

Returns: `STRING` — updated handle.

### JSON_DELETE — Remove a Key

Alias: `JSON_REMOVE`

```iecst
doc := JSON_DELETE(doc, 'pressure');
```

Returns: `STRING` — updated handle.

### JSON_APPEND — Add to Array

```iecst
doc := JSON_PARSE('{"items": [1, 2, 3]}');
doc := JSON_APPEND(doc, 4);                              (* [1, 2, 3, 4] *)
```

### JSON_MERGE — Merge Two Objects

Right-side keys overwrite left-side on conflict.

```iecst
base := JSON_PARSE('{"a": 1, "b": 2}');
overlay := JSON_PARSE('{"b": 99, "c": 3}');
merged := JSON_MERGE(base, overlay);
(* Result: {"a": 1, "b": 99, "c": 3} *)
```

The second argument can be a handle or a raw JSON string.

---

## 6. Building JSON

### JSON_OBJECT — Create Object

```iecst
(* Empty object *)
obj := JSON_OBJECT();

(* From key-value pairs *)
obj := JSON_OBJECT('name', 'Pump-1', 'speed', 1750, 'running', TRUE);
(* Result: {"name": "Pump-1", "speed": 1750, "running": true} *)
```

Arguments are key-value pairs: `key1, val1, key2, val2, ...`

### JSON_ARRAY — Create Array

```iecst
arr := JSON_ARRAY(10, 20, 30, 40);
(* Result: [10, 20, 30, 40] *)

arr := JSON_ARRAY('red', 'green', 'blue');
(* Result: ["red", "green", "blue"] *)
```

### Building Complex Structures

```iecst
(* Build a telemetry payload *)
payload := JSON_OBJECT(
    'timestamp', DT_TO_STRING(NOW()),
    'site', 'Plant-A',
    'temperature', actualTemp,
    'pressure', actualPressure,
    'running', motorRunning
);

json_str := JSON_STRINGIFY(payload);
(* Use with MQTT_PUBLISH, HTTP_POST, etc. *)
```

---

## 7. Inspection

### JSON_HAS — Check if Key Exists

Alias: `JSON_EXISTS`

```iecst
IF JSON_HAS(doc, 'error') THEN
    errMsg := JSON_GET_STRING(doc, 'error');
END_IF;
```

### JSON_TYPE — Get Value Type

```iecst
t := JSON_TYPE(doc, 'name');         (* "string" *)
t := JSON_TYPE(doc, 'speed');        (* "number" *)
t := JSON_TYPE(doc, 'running');      (* "boolean" *)
t := JSON_TYPE(doc, 'units');        (* "array" *)
t := JSON_TYPE(doc, 'config');       (* "object" *)
t := JSON_TYPE(doc);                 (* Type of root — "object" *)
```

Returns: `"null"`, `"boolean"`, `"string"`, `"number"`, `"object"`, `"array"`, or `"unknown"`.

### JSON_LENGTH — Get Size

Alias: `JSON_SIZE`

```iecst
keyCount := JSON_LENGTH(doc);                (* Number of top-level keys *)
arrLen := JSON_LENGTH(doc, 'units');          (* Array length *)
strLen := JSON_LENGTH(doc, 'name');           (* String length *)
```

### JSON_KEYS — Get All Keys

```iecst
keys := JSON_KEYS(doc);
(* Returns array: ["site", "units", "config"] *)
```

### JSON_VALUES — Get All Values

```iecst
vals := JSON_VALUES(doc);
(* Returns array of all top-level values *)
```

Both accept an optional path to inspect a nested object.

---

## 8. Complete Example: MQTT Telemetry with JSON

```iecst
PROGRAM POU_Telemetry
VAR
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;
    ok : BOOL;

    (* Process data *)
    temperature : REAL := 72.5;
    pressure : REAL := 45.3;
    flow_rate : REAL := 120.0;
    motor_running : BOOL := TRUE;

    (* JSON *)
    payload : STRING;
    json_str : STRING;

    (* Incoming command parsing *)
    cmd_raw : STRING;
    cmd_doc : STRING;
    new_setpoint : REAL;
END_VAR

IF NOT initialized THEN
    ok := MQTT_CLIENT_CREATE('telemetry', 'tcp://10.0.0.144:1883', 'goplc-telem');
    ok := MQTT_CLIENT_CONNECT('telemetry');
    ok := MQTT_SUBSCRIBE('telemetry', 'plant/commands');
    initialized := TRUE;
END_IF;

scan_count := scan_count + 1;

(* Publish telemetry every 100 scans (10s at 100ms) *)
IF (scan_count MOD 100) = 0 THEN
    payload := JSON_OBJECT(
        'temp', temperature,
        'pressure', pressure,
        'flow', flow_rate,
        'running', motor_running,
        'scan', scan_count
    );
    json_str := JSON_STRINGIFY(payload);
    MQTT_PUBLISH('telemetry', 'plant/telemetry', json_str);
END_IF;

(* Process incoming commands *)
IF MQTT_HAS_MESSAGE('telemetry', 'plant/commands') THEN
    cmd_raw := MQTT_GET_MESSAGE('telemetry', 'plant/commands');

    IF JSON_VALID(cmd_raw) THEN
        cmd_doc := JSON_PARSE(cmd_raw);

        IF JSON_HAS(cmd_doc, 'setpoint') THEN
            new_setpoint := JSON_GET_REAL(cmd_doc, 'setpoint');
            (* Apply setpoint... *)
        END_IF;

        IF JSON_HAS(cmd_doc, 'command') THEN
            IF JSON_GET_STRING(cmd_doc, 'command') = 'stop' THEN
                motor_running := FALSE;
            ELSIF JSON_GET_STRING(cmd_doc, 'command') = 'start' THEN
                motor_running := TRUE;
            END_IF;
        END_IF;
    END_IF;
END_IF;

END_PROGRAM
```

---

## 9. Complete Example: HTTP API Response Parsing

```iecst
PROGRAM POU_APIClient
VAR
    state : INT := 0;
    response : STRING;
    doc : STRING;
    status_code : INT;
    items_count : INT;
    i : INT;
    item_name : STRING;
END_VAR

CASE state OF
    0: (* Make HTTP request *)
        response := HTTP_GET('http://api.example.com/devices');
        IF LEN(response) > 0 THEN
            state := 1;
        END_IF;

    1: (* Parse response *)
        IF JSON_VALID(response) THEN
            doc := JSON_PARSE(response);

            (* Check response structure *)
            IF JSON_HAS(doc, 'devices') THEN
                items_count := JSON_ARRAY_LENGTH(doc, 'devices');

                (* Iterate through devices *)
                FOR i := 0 TO items_count - 1 DO
                    item_name := JSON_GET_STRING(doc,
                        CONCAT('devices.', INT_TO_STRING(i), '.name'));
                    (* Process each device... *)
                END_FOR;
            END_IF;
        END_IF;
        state := 0;
END_CASE;
END_PROGRAM
```

---

## Appendix A: Quick Reference

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `JSON_PARSE` | `(json_string)` | STRING (handle) | Parse JSON string |
| `JSON_STRINGIFY` | `(handle [, indent])` | STRING | Convert to JSON string. Alias: `JSON_ENCODE` |
| `JSON_VALID` | `(json_string)` | BOOL | Check if valid JSON |
| `JSON_GET` | `(handle, path)` | ANY | Read value at path |
| `JSON_GET_STRING` | `(handle, path)` | STRING | Read as string |
| `JSON_GET_INT` | `(handle, path)` | INT | Read as integer |
| `JSON_GET_REAL` | `(handle, path)` | REAL | Read as float |
| `JSON_GET_BOOL` | `(handle, path)` | BOOL | Read as boolean |
| `JSON_GET_ARRAY` | `(handle, path, index)` | ANY | Read array element |
| `JSON_ARRAY_LENGTH` | `(handle, path)` | INT | Get array size |
| `JSON_SET` | `(handle, path, value)` | STRING (handle) | Set value at path |
| `JSON_DELETE` | `(handle, path)` | STRING (handle) | Remove key. Alias: `JSON_REMOVE` |
| `JSON_APPEND` | `(handle, value)` | STRING (handle) | Append to array |
| `JSON_MERGE` | `(handle1, handle2)` | STRING (handle) | Merge objects (right wins) |
| `JSON_OBJECT` | `([key, val, ...])` | STRING (handle) | Create object from pairs |
| `JSON_ARRAY` | `([val1, val2, ...])` | STRING (handle) | Create array |
| `JSON_HAS` | `(handle, path)` | BOOL | Check if path exists. Alias: `JSON_EXISTS` |
| `JSON_TYPE` | `(handle [, path])` | STRING | Value type: null/boolean/string/number/object/array |
| `JSON_LENGTH` | `(handle [, path])` | INT | Size of object/array/string. Alias: `JSON_SIZE` |
| `JSON_KEYS` | `(handle [, path])` | ARRAY | All object keys |
| `JSON_VALUES` | `(handle [, path])` | ARRAY | All object values |
| `JSON_PATH` | `(handle, jsonpath)` | ANY | JSONPath query (`$.key[0].sub`) |

---

*GoPLC v1.0.535 | 22 JSON Functions | Parse, Build, Query, Modify*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
