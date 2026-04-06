# GoPLC Resilience & Caching Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 35 built-in functions for building fault-tolerant, production-hardened control systems. These patterns protect against network failures, noisy inputs, resource exhaustion, and cascading faults — all callable from Structured Text.

| Pattern | Functions | Use Case |
|---------|-----------|----------|
| **Cache** | 12 | TTL-based key-value cache with LRU eviction |
| **Circuit Breaker** | 7 | Stop calling a failing service, auto-recover |
| **Rate Limiter** | 4 | Cap requests per time window |
| **Throttle** | 3 | Enforce minimum interval between calls |
| **Debounce** | 3 | Ignore rapid repeated triggers |
| **Bulkhead** | 5 | Limit concurrent operations |
| **Fallback** | 1 | Default value for falsy inputs |
| **Hysteresis** | 1 | Dead-band to prevent signal chatter |
| **Rate Limit (Analog)** | 1 | Clamp rate of change on analog values |

All handle-based patterns (Cache, Circuit Breaker, Rate Limiter, Throttle, Debounce, Bulkhead) use string handles — create once, reference by name.

---

## 2. Cache

TTL-based key-value cache with optional LRU eviction. Use for caching expensive calculations, API responses, or sensor averaging.

### Create

```iecst
(* Unlimited cache, no default TTL *)
c := CACHE_CREATE();

(* Max 100 entries, 60-second default TTL *)
c := CACHE_CREATE(100, 60);
```

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `max_size` | INT | 0 (unlimited) | Maximum entries (LRU eviction when exceeded) |
| `default_ttl` | INT | 0 (no expiry) | Default TTL in seconds |

### Store and Retrieve

```iecst
CACHE_SET(c, 'api_result', response_body);            (* Default TTL *)
CACHE_SET(c, 'sensor_avg', avg_temp, 30);              (* 30s TTL *)

val := CACHE_GET(c, 'api_result');                     (* Returns value or nil *)
val := CACHE_GET(c, 'missing_key', 0.0);               (* Returns 0.0 if not found *)

(* Get or compute: returns cached value, or stores default if missing *)
val := CACHE_GET_OR_SET(c, 'expensive_calc', computed_value, 60);
```

### Manage

```iecst
IF CACHE_HAS(c, 'api_result') THEN ... END_IF;
remaining := CACHE_TTL(c, 'api_result');    (* Seconds remaining, -1=no expiry, -2=not found *)
CACHE_EXPIRE(c, 'api_result', 10);          (* Reset TTL to 10s *)
CACHE_DELETE(c, 'api_result');
removed := CACHE_CLEANUP(c);                (* Remove expired entries, returns count *)
keys := CACHE_KEYS(c);
count := CACHE_SIZE(c);
CACHE_CLEAR(c);
```

### Example: Cache API Responses

```iecst
PROGRAM POU_CachedWeather
VAR
    cache : STRING;
    temp : REAL;
    body : STRING;
    initialized : BOOL := FALSE;
END_VAR

IF NOT initialized THEN
    cache := CACHE_CREATE(50, 300);    (* 5-minute default TTL *)
    initialized := TRUE;
END_IF;

(* Check cache first *)
temp := CACHE_GET(cache, 'outdoor_temp', -999.0);

IF temp = -999.0 THEN
    (* Cache miss — fetch from API *)
    body := HTTP_GET_BODY('http://weather.local/temp');
    IF LEN(body) > 0 THEN
        temp := STRING_TO_REAL(body);
        CACHE_SET(cache, 'outdoor_temp', temp, 300);
    END_IF;
END_IF;
END_PROGRAM
```

---

## 3. Circuit Breaker

Prevents repeated calls to a failing service. After a threshold of failures, the breaker "opens" and blocks calls for a timeout period, then allows a few test calls ("half-open") before fully closing.

### States

```
  CLOSED ──(failures >= threshold)──► OPEN ──(timeout expires)──► HALF-OPEN
    ▲                                                                  │
    └──────────(successes >= threshold)────────────────────────────────┘
    └──────────────────────────(failure)───────────────── OPEN ◄───────┘
```

### Create

```iecst
cb := CIRCUIT_BREAKER_CREATE(5, 2, 30);
```

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `failure_threshold` | INT | 5 | Failures before opening |
| `success_threshold` | INT | 2 | Successes in half-open before closing |
| `timeout_seconds` | INT | 30 | Time in open state before half-open |

### Use Pattern

```iecst
IF CIRCUIT_BREAKER_ALLOW(cb) THEN
    (* Attempt the operation *)
    resp := HTTP_GET('http://10.0.0.50/api/data');

    IF HTTP_OK(resp) THEN
        CIRCUIT_BREAKER_RECORD_SUCCESS(cb);
        (* Process response... *)
    ELSE
        CIRCUIT_BREAKER_RECORD_FAILURE(cb);
    END_IF;
ELSE
    (* Circuit is open — use cached/default data *)
    DEBUG_WARN('comms', 'Circuit breaker open — using cached data');
END_IF;
```

### Monitor

```iecst
state := CIRCUIT_BREAKER_STATE(cb);     (* "closed", "open", or "half-open" *)
stats := CIRCUIT_BREAKER_STATS(cb);     (* JSON with failures, successes, thresholds *)
CIRCUIT_BREAKER_RESET(cb);              (* Force back to closed *)
```

---

## 4. Rate Limiter

Caps the number of operations within a sliding time window. Use for API call limits, alarm rate limiting, or log throttling.

```iecst
rl := RATE_LIMITER_CREATE(10, 60);     (* 10 requests per 60 seconds *)

IF RATE_LIMITER_ALLOW(rl) THEN
    (* Within budget — proceed *)
    MQTT_PUBLISH('telemetry', 'plant/data', payload);
ELSE
    (* Rate exceeded — skip or queue *)
    remaining := RATE_LIMITER_REMAINING(rl);
END_IF;
```

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `max_requests` | INT | 100 | Maximum operations per window |
| `window_seconds` | INT | 60 | Sliding window duration |

| Function | Returns | Description |
|----------|---------|-------------|
| `RATE_LIMITER_CREATE(max, window)` | STRING | Create limiter |
| `RATE_LIMITER_ALLOW(h)` | BOOL | Check and consume quota |
| `RATE_LIMITER_REMAINING(h)` | INT | Remaining quota |
| `RATE_LIMITER_RESET(h)` | BOOL | Clear all counters |

---

## 5. Throttle

Enforces a minimum time interval between operations. Unlike rate limiter (which allows bursts up to a quota), throttle ensures even spacing.

```iecst
th := THROTTLE_CREATE(5000);           (* Minimum 5 seconds between calls *)

IF THROTTLE_ALLOW(th) THEN
    (* At least 5s since last allowed call *)
    send_email_alert();
END_IF;

wait_ms := THROTTLE_WAIT_TIME(th);    (* Milliseconds until next allowed *)
```

| Function | Returns | Description |
|----------|---------|-------------|
| `THROTTLE_CREATE(interval_ms)` | STRING | Create throttle (default: 1000ms) |
| `THROTTLE_ALLOW(h)` | BOOL | Check if interval has elapsed |
| `THROTTLE_WAIT_TIME(h)` | INT | Milliseconds until next allowed |

---

## 6. Debounce

Triggers only after a quiet period — ignores rapid repeated activations. Use for noisy digital inputs, button presses, or alarm suppression.

```iecst
db := DEBOUNCE_CREATE(500);            (* 500ms debounce delay *)

(* Call on every scan where input is active *)
IF button_pressed THEN
    DEBOUNCE_CALL(db);
END_IF;

(* Only true after 500ms of quiet *)
IF DEBOUNCE_READY(db) THEN
    (* Stable press detected — execute once *)
    toggle_output := NOT toggle_output;
END_IF;
```

| Function | Returns | Description |
|----------|---------|-------------|
| `DEBOUNCE_CREATE(delay_ms)` | STRING | Create debouncer (default: 250ms) |
| `DEBOUNCE_CALL(h)` | BOOL | Record activation (resets timer) |
| `DEBOUNCE_READY(h)` | BOOL | TRUE if delay elapsed since last call |

---

## 7. Bulkhead

Limits the number of concurrent operations — a semaphore pattern. Prevents resource exhaustion when multiple tasks or connections compete.

```iecst
bh := BULKHEAD_CREATE(5);             (* Max 5 concurrent operations *)

IF BULKHEAD_ACQUIRE(bh) THEN
    (* Got a slot — do work *)
    resp := HTTP_POST('http://api.example.com/data', payload);
    BULKHEAD_RELEASE(bh);             (* Always release when done *)
ELSE
    (* All slots busy — reject or queue *)
    available := BULKHEAD_AVAILABLE(bh);
END_IF;
```

| Function | Returns | Description |
|----------|---------|-------------|
| `BULKHEAD_CREATE(max_concurrent)` | STRING | Create bulkhead (default: 10) |
| `BULKHEAD_ACQUIRE(h)` | BOOL | Take a slot (FALSE if full) |
| `BULKHEAD_RELEASE(h)` | BOOL | Release a slot |
| `BULKHEAD_AVAILABLE(h)` | INT | Remaining slots |
| `BULKHEAD_STATS(h)` | MAP | {max_concurrent, current, available} |

---

## 8. Fallback

Returns a default value when the primary value is falsy (nil, empty string, FALSE, 0, 0.0).

```iecst
(* If sensor_reading is 0 or nil, use 72.5 *)
temp := FALLBACK(sensor_reading, 72.5);

(* If API response is empty, use cached value *)
data := FALLBACK(HTTP_GET_BODY(url), cached_data);

(* Chain fallbacks *)
value := FALLBACK(primary, FALLBACK(secondary, default_val));
```

---

## 9. Hysteresis

Dead-band function that prevents output chatter when an input oscillates near a threshold. The output only changes when the input crosses the high or low threshold — it holds its previous state in the dead band between them.

```iecst
(* Heater control with 2-degree dead band *)
heater_on := HYSTERESIS(temperature, 68.0, 72.0, heater_on);
(* ON when temp drops below 68, OFF when temp rises above 72 *)
(* Holds previous state between 68-72 *)
```

| Param | Type | Description |
|-------|------|-------------|
| `input` | REAL | Current value |
| `low_threshold` | REAL | Turn ON below this |
| `high_threshold` | REAL | Turn OFF above this |
| `prev_output` | BOOL | Previous output state (for memory) |

---

## 10. Rate Limit (Analog)

Clamps the rate of change on an analog value — the output cannot change faster than the specified rate per second. Different from the discrete RATE_LIMITER which counts events.

```iecst
(* Limit valve movement to 10%/sec up, 5%/sec down *)
valve_cmd := RATELIMIT(setpoint, valve_cmd, 10.0, 5.0, 50);
```

| Param | Type | Description |
|-------|------|-------------|
| `input` | REAL | Desired value |
| `prev_output` | REAL | Current output (state) |
| `max_rate_up` | REAL | Maximum increase per second |
| `max_rate_down` | REAL | Maximum decrease per second |
| `scan_time_ms` | INT | Scan cycle time in milliseconds |

---

## 11. Complete Example: Resilient Protocol Gateway

A gateway that reads from Modbus, publishes to MQTT, with full resilience:

```iecst
PROGRAM POU_ResilientGateway
VAR
    state : INT := 0;
    ok : BOOL;
    scan_count : DINT := 0;

    (* Resilience handles *)
    modbus_cb : STRING;        (* Circuit breaker for Modbus *)
    mqtt_rl : STRING;          (* Rate limiter for MQTT publish *)
    api_cache : STRING;        (* Cache for expensive lookups *)
    pub_throttle : STRING;     (* Throttle alarm notifications *)
    conn_bulkhead : STRING;    (* Limit concurrent connections *)

    (* Data *)
    regs : ARRAY[0..3] OF INT;
    temperature : REAL;
    payload : STRING;
END_VAR

CASE state OF
    0: (* Initialize resilience patterns *)
        modbus_cb := CIRCUIT_BREAKER_CREATE(3, 2, 15);
        mqtt_rl := RATE_LIMITER_CREATE(60, 60);
        api_cache := CACHE_CREATE(100, 300);
        pub_throttle := THROTTLE_CREATE(10000);
        conn_bulkhead := BULKHEAD_CREATE(3);

        ok := MB_CLIENT_CREATE('plc', '10.0.0.50', 502);
        ok := MB_CLIENT_CONNECT('plc');
        ok := MQTT_CLIENT_CREATE('broker', 'tcp://10.0.0.144:1883', 'gw');
        ok := MQTT_CLIENT_CONNECT('broker');
        state := 10;

    10: (* Running *)
        scan_count := scan_count + 1;

        (* Read Modbus — protected by circuit breaker *)
        IF CIRCUIT_BREAKER_ALLOW(modbus_cb) THEN
            IF MB_CLIENT_CONNECTED('plc') THEN
                regs := MB_READ_HOLDING('plc', 0, 4);
                temperature := INT_TO_REAL(regs[0]) / 10.0;
                CIRCUIT_BREAKER_RECORD_SUCCESS(modbus_cb);

                (* Cache the reading *)
                CACHE_SET(api_cache, 'temperature', temperature, 30);
            ELSE
                CIRCUIT_BREAKER_RECORD_FAILURE(modbus_cb);
                MB_CLIENT_CONNECT('plc');
            END_IF;
        ELSE
            (* Use cached value while circuit is open *)
            temperature := CACHE_GET(api_cache, 'temperature', 0.0);
        END_IF;

        (* Publish to MQTT — rate limited *)
        IF RATE_LIMITER_ALLOW(mqtt_rl) THEN
            payload := JSON_STRINGIFY(JSON_OBJECT(
                'temp', temperature,
                'cb_state', CIRCUIT_BREAKER_STATE(modbus_cb)
            ));
            MQTT_PUBLISH('broker', 'plant/gateway/data', payload);
        END_IF;

        (* High-temp alarm — throttled to once per 10s *)
        IF temperature > 180.0 AND THROTTLE_ALLOW(pub_throttle) THEN
            MQTT_PUBLISH('broker', 'plant/alarms/high_temp',
                         CONCAT('Temperature: ', REAL_TO_STRING(temperature)));
        END_IF;
END_CASE;
END_PROGRAM
```

---

## Appendix A: Quick Reference

### Cache (12)

| Function | Returns | Description |
|----------|---------|-------------|
| `CACHE_CREATE([maxSize, ttl])` | STRING | Create cache |
| `CACHE_SET(h, key, val [, ttl])` | BOOL | Store with optional TTL |
| `CACHE_GET(h, key [, default])` | ANY | Retrieve (with default) |
| `CACHE_GET_OR_SET(h, key, val [, ttl])` | ANY | Get or store default |
| `CACHE_HAS(h, key)` | BOOL | Key exists and not expired? |
| `CACHE_DELETE(h, key)` | BOOL | Remove key |
| `CACHE_TTL(h, key)` | INT | Seconds remaining |
| `CACHE_EXPIRE(h, key, ttl)` | BOOL | Reset TTL |
| `CACHE_SIZE(h)` | INT | Entry count |
| `CACHE_KEYS(h)` | ARRAY | All keys |
| `CACHE_CLEANUP(h)` | INT | Remove expired, return count |
| `CACHE_CLEAR(h)` | BOOL | Remove all |

### Circuit Breaker (7)

| Function | Returns | Description |
|----------|---------|-------------|
| `CIRCUIT_BREAKER_CREATE([fail, succ, timeout])` | STRING | Create breaker |
| `CIRCUIT_BREAKER_ALLOW(h)` | BOOL | Check if call permitted |
| `CIRCUIT_BREAKER_RECORD_SUCCESS(h)` | BOOL | Record success |
| `CIRCUIT_BREAKER_RECORD_FAILURE(h)` | BOOL | Record failure |
| `CIRCUIT_BREAKER_STATE(h)` | STRING | "closed"/"open"/"half-open" |
| `CIRCUIT_BREAKER_STATS(h)` | MAP | Full statistics |
| `CIRCUIT_BREAKER_RESET(h)` | BOOL | Force closed |

### Rate Limiter (4), Throttle (3), Debounce (3), Bulkhead (5)

| Function | Returns | Description |
|----------|---------|-------------|
| `RATE_LIMITER_CREATE(max, window_sec)` | STRING | Discrete rate limiter |
| `RATE_LIMITER_ALLOW(h)` | BOOL | Consume quota |
| `RATE_LIMITER_REMAINING(h)` | INT | Remaining quota |
| `RATE_LIMITER_RESET(h)` | BOOL | Clear counters |
| `THROTTLE_CREATE(interval_ms)` | STRING | Minimum interval enforcer |
| `THROTTLE_ALLOW(h)` | BOOL | Interval elapsed? |
| `THROTTLE_WAIT_TIME(h)` | INT | Ms until next allowed |
| `DEBOUNCE_CREATE(delay_ms)` | STRING | Input debouncer |
| `DEBOUNCE_CALL(h)` | BOOL | Record activation |
| `DEBOUNCE_READY(h)` | BOOL | Stable after delay? |
| `BULKHEAD_CREATE(max)` | STRING | Concurrency limiter |
| `BULKHEAD_ACQUIRE(h)` | BOOL | Take slot |
| `BULKHEAD_RELEASE(h)` | BOOL | Release slot |
| `BULKHEAD_AVAILABLE(h)` | INT | Remaining slots |
| `BULKHEAD_STATS(h)` | MAP | Concurrency stats |

### Standalone Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `FALLBACK(value, default)` | ANY | Default for falsy values |
| `HYSTERESIS(input, low, high, prev)` | BOOL | Dead-band switch |
| `RATELIMIT(in, prev, up, down, ms)` | REAL | Analog rate limiter |

---

*GoPLC v1.0.535 | 35 Resilience Functions | Cache, Circuit Breaker, Rate Limiter, Throttle, Debounce, Bulkhead*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
