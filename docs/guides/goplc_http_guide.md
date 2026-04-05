# GoPLC HTTP Client Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 16 built-in functions for making HTTP requests from Structured Text. Call REST APIs, fetch data from web services, post telemetry to cloud platforms, and integrate with any HTTP-based system — all from your PLC program.

```iecst
(* Simple GET — one line *)
body := HTTP_GET_BODY('http://api.example.com/status');

(* Full control *)
resp := HTTP_GET('http://api.example.com/data');
IF HTTP_OK(resp) THEN
    data := HTTP_BODY(resp);
END_IF;
```

### Response Pattern

Most HTTP functions return a **response map** with these fields:

| Field | Type | Description |
|-------|------|-------------|
| `status` | INT | HTTP status code (200, 404, 500, etc.) |
| `body` | STRING | Response body |
| `headers` | MAP | Response headers (when available) |
| `error` | STRING | Error message (empty on success) |

Use the helper functions `HTTP_STATUS`, `HTTP_BODY`, `HTTP_OK`, and `HTTP_ERROR` to extract fields from the response.

---

## 2. Simple Request Functions

### HTTP_GET — GET Request

```iecst
resp := HTTP_GET('http://10.0.0.144:8086/health');

IF HTTP_OK(resp) THEN
    body := HTTP_BODY(resp);
END_IF;
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | STRING | Yes | Request URL |
| `timeout_sec` | INT | No | Timeout in seconds (default: 5) |

Returns: response map.

### HTTP_GET_BODY — GET, Returns Body Directly

The simplest form — returns the response body as a string, or empty string on error.

```iecst
body := HTTP_GET_BODY('http://10.0.0.50/api/info');
IF LEN(body) > 0 THEN
    (* Parse body... *)
END_IF;
```

No response map, no status code — just the body. Use this for quick reads where you don't need error details.

### HTTP_POST — POST Request

```iecst
resp := HTTP_POST('http://10.0.0.144:8086/api/v2/write',
                  'temperature,site=Plant1 value=72.5',
                  'text/plain');
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | STRING | Yes | Request URL |
| `body` | STRING | Yes | Request body |
| `content_type` | STRING | No | Content-Type header (default: `application/json`) |
| `timeout_sec` | INT | No | Timeout in seconds (default: 5) |

### HTTP_POST_JSON — POST JSON, Parse Response

Posts JSON and attempts to parse the response as JSON automatically.

```iecst
resp := HTTP_POST_JSON('http://api.example.com/devices',
                       '{"name": "Pump-1", "type": "VFD"}');
(* If response is JSON, resp is a parsed JSON object *)
(* If not, resp is a standard {status, body, error} map *)
```

### HTTP_PUT — PUT Request

```iecst
resp := HTTP_PUT('http://10.0.0.50/api/config',
                 '{"scan_time_ms": 100}');
```

Same parameters as HTTP_POST.

### HTTP_PATCH — PATCH Request

```iecst
resp := HTTP_PATCH('http://10.0.0.50/api/config',
                   '{"log_level": "debug"}');
```

Same parameters as HTTP_POST.

### HTTP_DELETE — DELETE Request

```iecst
resp := HTTP_DELETE('http://10.0.0.50/api/programs/old_program');
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | STRING | Yes | Request URL |
| `timeout_sec` | INT | No | Timeout in seconds (default: 5) |

### HTTP_HEAD — HEAD Request

Returns status and headers only (no body). Useful for checking if a resource exists.

```iecst
resp := HTTP_HEAD('http://10.0.0.50/api/info');
code := HTTP_STATUS(resp);
IF code = 200 THEN
    (* Resource exists *)
END_IF;
```

---

## 3. Advanced: HTTP_REQUEST

Full control over method, headers, and body.

```iecst
(* Build custom headers *)
hdrs := HTTP_SET_HEADER('', 'Authorization', 'Bearer my-token');
hdrs := HTTP_SET_HEADER(hdrs, 'X-Custom-Header', 'GoPLC');

(* Make request *)
resp := HTTP_REQUEST('POST',
                     'http://api.example.com/data',
                     '{"temp": 72.5}',
                     hdrs,
                     10);     (* 10 second timeout *)
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `method` | STRING | Yes | HTTP method (GET, POST, PUT, DELETE, PATCH, etc.) |
| `url` | STRING | Yes | Request URL |
| `body` | STRING | No | Request body |
| `headers` | MAP/STRING | No | Headers map or JSON handle |
| `timeout_sec` | INT | No | Timeout in seconds (default: 5) |

Returns: response map with `status`, `body`, `headers`, and `error`.

---

## 4. Response Helper Functions

### HTTP_STATUS — Get Status Code

```iecst
code := HTTP_STATUS(resp);    (* 200, 404, 500, etc. *)
```

### HTTP_BODY — Get Response Body

```iecst
body := HTTP_BODY(resp);
```

### HTTP_OK — Check for Success (2xx)

```iecst
IF HTTP_OK(resp) THEN
    (* Status is 200-299 *)
END_IF;
```

### HTTP_ERROR — Get Error Message

```iecst
err := HTTP_ERROR(resp);
IF LEN(err) > 0 THEN
    DEBUG_ERROR('http', CONCAT('Request failed: ', err));
END_IF;
```

### HTTP_HEADERS — Get All Response Headers

```iecst
hdrs := HTTP_HEADERS(resp);
```

### HTTP_GET_HEADER — Get Single Header

Case-insensitive header name lookup.

```iecst
content_type := HTTP_GET_HEADER(resp, 'Content-Type');
server := HTTP_GET_HEADER(resp, 'Server');
```

### HTTP_SET_HEADER — Build Request Headers

Creates or adds to a headers map for use with `HTTP_REQUEST`.

```iecst
hdrs := HTTP_SET_HEADER('', 'Authorization', 'Bearer token123');
hdrs := HTTP_SET_HEADER(hdrs, 'Content-Type', 'application/json');
hdrs := HTTP_SET_HEADER(hdrs, 'Accept', 'application/json');
```

Pass empty string as the first argument to create a new headers map.

---

## 5. Complete Example: REST API Integration

Poll a weather API and publish results to MQTT:

```iecst
PROGRAM POU_WeatherPoll
VAR
    state : INT := 0;
    scan_count : DINT := 0;
    resp : STRING;
    body : STRING;
    doc : STRING;
    temp_f : REAL;
    humidity : INT;
    ok : BOOL;
END_VAR

scan_count := scan_count + 1;

CASE state OF
    0: (* Initialize MQTT *)
        ok := MQTT_CLIENT_CREATE('weather', 'tcp://10.0.0.144:1883', 'goplc-weather');
        ok := MQTT_CLIENT_CONNECT('weather');
        state := 10;

    10: (* Poll weather every 600 scans (60s at 100ms) *)
        IF (scan_count MOD 600) = 0 THEN
            resp := HTTP_GET('http://api.weather.local/current');

            IF HTTP_OK(resp) THEN
                body := HTTP_BODY(resp);
                doc := JSON_PARSE(body);
                temp_f := JSON_GET_REAL(doc, 'temp_f');
                humidity := JSON_GET_INT(doc, 'humidity');

                (* Publish to MQTT *)
                MQTT_PUBLISH('weather', 'plant/weather/temp', REAL_TO_STRING(temp_f));
                MQTT_PUBLISH('weather', 'plant/weather/humidity', INT_TO_STRING(humidity));
            ELSE
                DEBUG_WARN('weather', CONCAT('API error: ', HTTP_ERROR(resp)));
            END_IF;
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 6. Complete Example: Webhook Notifications

Send alarm notifications to a webhook endpoint:

```iecst
PROGRAM POU_AlarmWebhook
VAR
    temperature : REAL;
    alarm_active : BOOL := FALSE;
    alarm_sent : BOOL := FALSE;
    resp : STRING;
    payload : STRING;
    hdrs : STRING;
END_VAR

(* Check alarm condition *)
alarm_active := temperature > 180.0;

(* Send webhook on alarm rising edge *)
IF alarm_active AND NOT alarm_sent THEN
    payload := JSON_OBJECT(
        'event', 'HIGH_TEMP_ALARM',
        'value', temperature,
        'threshold', 180.0,
        'source', 'GoPLC-Plant1'
    );

    hdrs := HTTP_SET_HEADER('', 'Authorization', 'Bearer webhook-secret');
    resp := HTTP_REQUEST('POST',
                         'https://hooks.example.com/alerts',
                         JSON_STRINGIFY(payload),
                         hdrs);

    IF HTTP_OK(resp) THEN
        alarm_sent := TRUE;
    END_IF;
END_IF;

(* Reset when alarm clears *)
IF NOT alarm_active THEN
    alarm_sent := FALSE;
END_IF;

END_PROGRAM
```

---

## 7. Complete Example: Cross-PLC Communication

Read variables from another GoPLC instance via its REST API:

```iecst
PROGRAM POU_RemotePLC
VAR
    scan_count : DINT := 0;
    body : STRING;
    doc : STRING;
    remote_temp : REAL;
    remote_running : BOOL;
END_VAR

scan_count := scan_count + 1;

(* Poll remote PLC every 50 scans (5s at 100ms) *)
IF (scan_count MOD 50) = 0 THEN
    body := HTTP_GET_BODY('http://10.0.0.51:8082/api/variables');

    IF LEN(body) > 0 THEN
        doc := JSON_PARSE(body);

        IF JSON_HAS(doc, 'temperature') THEN
            remote_temp := JSON_GET_REAL(doc, 'temperature.value');
        END_IF;

        IF JSON_HAS(doc, 'motor_running') THEN
            remote_running := JSON_GET_BOOL(doc, 'motor_running.value');
        END_IF;
    END_IF;
END_IF;

END_PROGRAM
```

---

## Appendix A: Quick Reference

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `HTTP_GET` | `(url [, timeout])` | Response map | GET request |
| `HTTP_GET_BODY` | `(url [, timeout])` | STRING | GET, returns body directly |
| `HTTP_POST` | `(url, body [, content_type] [, timeout])` | Response map | POST request |
| `HTTP_POST_JSON` | `(url, json_body [, timeout])` | Parsed JSON or map | POST JSON, auto-parse response |
| `HTTP_PUT` | `(url, body [, content_type] [, timeout])` | Response map | PUT request |
| `HTTP_PATCH` | `(url, body [, content_type] [, timeout])` | Response map | PATCH request |
| `HTTP_DELETE` | `(url [, timeout])` | Response map | DELETE request |
| `HTTP_HEAD` | `(url [, timeout])` | Response map | HEAD (status + headers only) |
| `HTTP_REQUEST` | `(method, url [, body] [, headers] [, timeout])` | Response map | Full control request |
| `HTTP_STATUS` | `(response)` | INT | Extract status code |
| `HTTP_BODY` | `(response)` | STRING | Extract body |
| `HTTP_OK` | `(response)` | BOOL | TRUE if status 200-299 |
| `HTTP_ERROR` | `(response)` | STRING | Extract error message |
| `HTTP_HEADERS` | `(response)` | MAP | Extract all headers |
| `HTTP_GET_HEADER` | `(response, name)` | STRING | Get single header (case-insensitive) |
| `HTTP_SET_HEADER` | `(headers, name, value)` | MAP | Build/add to headers map |

---

*GoPLC v1.0.535 | 16 HTTP Client Functions | REST Integration from ST*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
