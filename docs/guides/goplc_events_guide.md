# GoPLC Events, Webhooks, and Notifications

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.559

---

GoPLC has a built-in event bus that every subsystem publishes to — task start/stop, watchdog faults, protocol connects/disconnects, program reloads, login attempts, memory and disk thresholds — and your ST code can emit its own events on top. Those events fan out to any combination of four destinations: HTTP webhooks (Slack/Teams/PagerDuty/generic), the embedded MQTT broker, a SQLite log for querying history, and a WebSocket stream for live dashboards. You configure it once in YAML and the whole pipeline runs with zero ST boilerplate.

## 1. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime                                               │
│                                                              │
│  ┌────────────┐  ┌───────────┐  ┌────────┐  ┌─────────────┐  │
│  │ Scheduler  │  │ Protocol  │  │  Auth  │  │ ST Program  │  │
│  │ task.*     │  │ protocol.*│  │ auth.* │  │ EVENT_EMIT  │  │
│  └─────┬──────┘  └─────┬─────┘  └────┬───┘  └──────┬──────┘  │
│        │               │             │             │         │
│        └───────┬───────┴──────┬──────┴─────────────┘         │
│                │              │                              │
│         ┌──────▼──────────────▼──────┐                       │
│         │       events.Bus           │  (pkg/events)         │
│         │  channel fanout + dedup    │                       │
│         └─┬────────┬────────┬───────┬┘                       │
│           │        │        │       │                        │
│      ┌────▼──┐ ┌──▼────┐ ┌─▼────┐ ┌─▼────────┐               │
│      │Webhook│ │ MQTT  │ │SQLite│ │ WS stream│               │
│      │Worker │ │Broker │ │ Log  │ │/events/  │               │
│      │(retry)│ │(local)│ │(hist)│ │  stream  │               │
│      └────┬──┘ └───┬───┘ └──────┘ └──────────┘               │
└───────────┼────────┼──────────────────────────────────────────┘
            │        │
      Slack/Teams  mosquitto_sub
      PagerDuty    goplc/events/#
      generic
```

The bus is a package-level singleton (`events.Default()`). Any Go code or ST builtin can publish without plumbing a context through. Each destination runs on its own goroutine with its own channel buffer, so a slow webhook can't stall the scan loop.

## 2. Event Anatomy

Every event carries the same fields:

| Field | Type | Example |
|-------|------|---------|
| `id` | UUID string | `"f3a1..."` |
| `timestamp` | RFC3339Nano UTC | `"2026-04-10T15:04:05.123456789Z"` |
| `type` | dotted string | `"task.fault"`, `"protocol.connect"` |
| `severity` | `info` / `warning` / `error` / `critical` | `"warning"` |
| `source` | subsystem origin | `"modbus:plant1"`, `"task:MainTask"`, `"st:Alarms"` |
| `message` | human-readable | `"Task MainTask watchdog trip: 6.3ms > 5.0ms"` |
| `data` | optional JSON | `{"protocol":"modbus","name":"plant1"}` |

Severity ordering is `info < warning < error < critical`. Every filter (`min_severity` on webhooks, the MQTT publisher, the `GET /api/events` query) uses this ordering, so `min_severity: warning` delivers warnings, errors, and criticals.

## 3. Event Types

These types are emitted automatically by the runtime — you don't need to do anything to get them:

| Type | Emitted by | Severity |
|------|------------|----------|
| `runtime.start` | Process boot | info |
| `runtime.stop` | Process shutdown | info |
| `task.start` | Scheduler, on task start | info |
| `task.stop` | Scheduler, on task stop | info |
| `task.fault` | Watchdog trip or execution error | error |
| `task.reload` | After `POST /api/tasks/:name/reload` | info |
| `protocol.connect` | Driver connect OK | info |
| `protocol.disconnect` | Driver disconnect | warning |
| `protocol.error` | Driver connect fail, comm error | error |
| `program.update` | `POST /api/programs` | info |
| `program.delete` | `DELETE /api/programs/:name` | info |
| `config.change` | Configuration changed | info |
| `auth.login` | Successful login, carries client IP | info |
| `auth.failed` | Failed login attempt | warning |
| `system.memory` | Heap usage crossed `memory_warning_pct` | warning |
| `system.disk` | Data dir usage crossed `disk_warning_pct` | warning |
| `cluster.node_join` | Cluster peer joined | info |
| `cluster.node_lost` | Cluster peer lost | warning |
| `power.on_battery` | UPS on battery | warning |
| `power.low_battery` | UPS battery critically low | critical |
| `alarm.active` / `alarm.clear` / `alarm.ack` | Reserved for Alarm Management | varies |

Protocol events fire for all 11 drivers — modbus, opcua, s7, enip, mqtt, dnp3, iec104, bacnet, fins, df1, snmp — at the eval-shim layer, so they work regardless of how the connection was opened (YAML config or ST `MB_CLIENT_CREATE` etc.).

You can also emit your own custom types from ST or the API. Names are free-form dotted strings; no registration is required.

## 4. Configuration

The entire feature is driven by the `events:` block in your YAML config:

```yaml
events:
  enabled: true
  bus_size: 1024          # per-subscriber channel buffer
  dedup_window_ms: 1000   # suppress duplicate (type,source) within this window

  log:
    enabled: true
    database: "data/events.db"   # relative to data dir
    max_age_days: 90

  mqtt:
    enabled: true
    auto_create: true            # start embedded broker at boot
    auto_create_port: 1883
    auto_create_ws_port: 8083
    broker_name: "events"
    topic_prefix: "goplc/events"
    min_severity: "info"

  thresholds:
    memory_warning_pct: 85       # heap usage
    disk_warning_pct: 90         # data dir filesystem
    scan_time_warning_pct: 80    # of watchdog budget
    sample_interval_ms: 5000

  webhooks:
    - name: "slack-ops"
      url: "https://hooks.slack.com/services/T.../B.../..."
      format: "slack"
      min_severity: "warning"
      event_types: ["task.fault", "protocol.*", "alarm.active"]
      retry_count: 3
      retry_delay_ms: 5000
      timeout_ms: 10000

    - name: "pagerduty-oncall"
      url: "https://events.pagerduty.com/v2/enqueue"
      format: "pagerduty"
      routing_key: "R0UTINGKEY..."
      min_severity: "critical"
      event_types: ["*"]
```

All four subsystems (`log`, `mqtt`, `webhooks`, `thresholds`) are independent. Turn off what you don't need — an empty `webhooks:` list is fine, as is `log.enabled: false`.

### The embedded MQTT broker

With `events.mqtt.auto_create: true`, GoPLC starts an in-process mochi-mqtt broker at boot. You don't need a separate Mosquitto container to see events — any MQTT client, including `mosquitto_sub` from a terminal, can subscribe immediately:

```bash
mosquitto_sub -h 127.0.0.1 -p 1883 -t 'goplc/events/#' -v
# goplc/events/runtime.start {"id":"...","type":"runtime.start",...}
# goplc/events/task.start    {"id":"...","type":"task.start",...}
```

Topics are structured as `<topic_prefix>/<event_type>`. The payload is the JSON-serialized event.

### Dedup window

`dedup_window_ms` collapses repeated events with the same `(type, source)` pair within the window. A protocol driver that reconnects once per second for 10 seconds won't spam your Slack channel with 10 identical notifications — the default 1-second window merges them into one. Set to `0` to disable.

## 5. Webhook Formats

Each webhook's `format` field picks the payload shape:

**`generic`** — posts the raw event JSON as the body. Use this for your own HTTP receivers:

```json
{
  "id": "f3a1...",
  "timestamp": "2026-04-10T15:04:05.123Z",
  "type": "task.fault",
  "severity": "error",
  "source": "task:MainTask",
  "message": "Task MainTask watchdog trip: 6.3ms > 5.0ms",
  "data": {"task":"MainTask","scan_us":6300,"budget_us":5000}
}
```

**`slack`** — Slack Incoming Webhook format with a colored attachment. Severity maps to color: info=`#36a64f` (green), warning=`#ffa500` (orange), error=`#ff0000` (red), critical=`#8b0000` (dark red). No extra auth headers needed; the webhook URL is the secret.

**`teams`** — Microsoft Teams MessageCard format. Same severity-to-color mapping, fields are the event type, source, severity, and message.

**`pagerduty`** — PagerDuty Events API v2 (`enqueue`). Requires a `routing_key` on the webhook. Severity maps to PagerDuty's `critical`/`error`/`warning`/`info`. The event is an `alert` action; there's no auto-resolve, so you pair this with an alarm-clear webhook or handle dedup on the PagerDuty side.

## 6. Filtering: Event Types and Severity

Each webhook has two independent filters: `event_types` (match) and `min_severity` (threshold). An event must pass both to be delivered.

`event_types` supports three patterns:

| Pattern | Matches |
|---------|---------|
| `"*"` | every event |
| `"protocol.*"` | anything starting with `protocol.` (connect/disconnect/error/reconnect) |
| `"task.fault"` | literal exact match |

You can mix them:

```yaml
event_types:
  - "task.fault"
  - "protocol.*"
  - "alarm.active"
  - "notify.slack-ops"
```

If `event_types` is empty, it defaults to `["*"]`.

`min_severity` defaults to `info` (everything). To route only problems to PagerDuty:

```yaml
min_severity: "critical"
event_types: ["*"]
```

## 7. Webhook Hardening: HMAC Signing, Rate Limiting, and the Incident Safety Valve

Once you start pushing events to external systems you have two new problems: how does the receiver know a request actually came from your PLC, and how do you keep a noisy event stream from blowing through a vendor's API quota (or your Slack channel's patience) without silencing an incident at the worst possible moment? GoPLC ships answers to both, and the defaults are designed so you can't accidentally shoot yourself in the foot.

### 7.1 HMAC-SHA256 signing

Any webhook with a `secret` field automatically signs every outbound request. The signature is an HMAC-SHA256 of the raw request body using the secret as the key, delivered in an `X-GoPLC-Signature` header:

```yaml
webhooks:
  - name: "ops-slack"
    url: "https://your-endpoint.example/hook"
    format: "generic"
    secret: "s3cret-shared-between-goplc-and-receiver"
```

Every request to that endpoint now carries:

```
X-GoPLC-Event-Id: f3a1...
X-GoPLC-Event-Type: task.fault
X-GoPLC-Timestamp: 2026-04-10T15:04:05.123456789Z
X-GoPLC-Signature: sha256=9f2c1a...
```

Receivers verify the signature using the same shared secret. Reference Python:

```python
import hmac, hashlib

def verify(body: bytes, header: str, secret: bytes) -> bool:
    expected = "sha256=" + hmac.new(secret, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(header, expected)
```

Node.js:

```javascript
const crypto = require('crypto');
function verify(body, header, secret) {
  const expected = 'sha256=' + crypto.createHmac('sha256', secret).update(body).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(header), Buffer.from(expected));
}
```

Always use `hmac.compare_digest` / `timingSafeEqual` — a naive string compare is vulnerable to timing attacks.

The extra `X-GoPLC-Event-Id` header lets your receiver deduplicate if GoPLC's retry logic ever delivers the same event twice due to transient network failures. The `X-GoPLC-Timestamp` header lets you reject replay attacks by refusing anything older than a few minutes.

Signing is opt-in. If you don't set `secret`, the three identification headers are still sent but `X-GoPLC-Signature` is omitted. Whether a webhook is signed is visible in `GET /api/webhooks` as the `signed: true/false` field.

### 7.2 Rate limiting with a sliding window

Set `rate_limit_per_min` on any webhook to cap how many events per rolling 60-second window get pushed to that endpoint. The limiter is a pure sliding window — it remembers the timestamp of every delivery in the last 60 seconds and rejects further deliveries once the count hits the cap. Tokens don't refill at a steady rate; they expire as their 60-second lease runs out.

```yaml
webhooks:
  - name: "ops-slack"
    url: "https://hooks.slack.com/services/..."
    rate_limit_per_min: 30    # at most 30 posts to Slack per minute
```

Zero (the default) disables the cap entirely. Retries of a single accepted event do **not** count against the limit — only newly accepted events consume tokens. A flapping endpoint hammering retries can't accidentally burn through your cap.

### 7.3 The incident safety valve: severity bypass

A rate limit helps under steady state but can hurt badly during an incident, because that's exactly when event rates spike. You do not want your PLC to rate-limit the task fault that wakes the on-call engineer.

Every rate-limited webhook has a `rate_limit_bypass_severity` field that lets high-severity events skip the limiter entirely. **The default is `"error"`**, which means any `error` or `critical` event is always delivered, no matter how saturated the cap is. Only `info` and `warning` are subject to the rate limit.

```yaml
webhooks:
  - name: "ops-slack"
    rate_limit_per_min: 30
    rate_limit_bypass_severity: "error"   # default — can omit
```

You can override in either direction:

- `rate_limit_bypass_severity: "critical"` — only criticals bypass; errors are still subject to the cap. Use this if error-severity events are your noise floor.
- `rate_limit_bypass_severity: "warning"` — warnings, errors, and criticals all bypass. Use this on a well-behaved receiver where only `info` is noisy.
- `rate_limit_bypass_severity: "none"` — uniform capping. **Not recommended** for anything that reaches a human.

Bypassed events increment a separate `bypassed` counter in `GET /api/webhooks` so you can see how often the safety valve kicked in.

### 7.4 Self-announcing drops

When a rate-limited webhook first starts dropping events, the limiter publishes a `webhook.rate_limited` event back onto the bus at `warning` severity:

```json
{
  "type": "webhook.rate_limited",
  "severity": "warning",
  "source": "webhook:ops-slack",
  "message": "Webhook \"ops-slack\" rate limited (cap=30/min) — dropping events until the window clears",
  "data": {
    "webhook": "ops-slack",
    "cap": 30,
    "dropped_total": 14
  }
}
```

This event is **edge-triggered** — one announce per saturation episode, not one per dropped event. The worker tracks whether it's currently in a rate-limited state and only emits on the transition from "allowing" to "limiting". When the next event is allowed (window cycled, cap reopened), the state resets and the next saturation will emit a fresh announce.

The trick is that this event goes on the same event bus as everything else. Any other webhook subscribed to `webhook.*` or `*` will see it. The recommended pattern is to have a second "observer" webhook with **no** rate limit, subscribed to monitoring events:

```yaml
webhooks:
  - name: "ops-slack"
    url: "https://hooks.slack.com/..."
    event_types: ["task.fault", "protocol.*"]
    rate_limit_per_min: 30

  - name: "ops-observer"
    url: "https://your-monitoring-box.example/goplc"
    event_types: ["webhook.*", "system.*"]
    # no rate limit — we want every drop announcement
```

Now if `ops-slack` ever saturates, `ops-observer` catches the warning and you find out before the dropped events become real operational blindness.

`GET /api/webhooks` also surfaces a `currently_rate_limited: true/false` field for each webhook so a dashboard or health check can poll it directly.

### 7.5 Recommended starting configuration

The defaults are safe. Start here:

```yaml
webhooks:
  - name: "ops-slack"
    url: "..."
    format: "slack"
    secret: "strong-random-string-here"     # HMAC signing
    event_types: ["task.fault", "protocol.*", "system.*"]
    min_severity: "warning"
    # No rate_limit_per_min until you've seen the real event rate in
    # production for a few days. Then measure and set it to ~3× your
    # p99 steady-state rate, which gives headroom for spikes.

  - name: "pagerduty-critical"
    url: "https://events.pagerduty.com/v2/enqueue"
    format: "pagerduty"
    routing_key: "..."
    secret: "another-strong-random-string"
    event_types: ["*"]
    min_severity: "critical"                # pages only on criticals
    # Deliberately no rate_limit_per_min — never cap a pager.
```

Measure first, cap later. And even when you cap, leave the bypass at the default so an incident always gets through.

## 8. Storage, Retention, and Forensic Queries

Everything published to the event bus is written to the SQLite event log **before** any webhook delivery decision is made. This is critical to understand: **rate-limited events are not lost.** The log and the webhook pipeline are independent subscribers to the same bus, and the log subscribes first.

```
Event published
     │
     ▼
 ┌─────────┐          ┌───────────────┐
 │  Bus    │─────────▶│ SQLite log    │  ← stored, regardless of webhooks
 │ fanout  │─────────▶│ Webhook worker│  ← may drop, retry, bypass
 │         │─────────▶│ MQTT publisher│
 │         │─────────▶│ WebSocket     │
 └─────────┘          └───────────────┘
```

The log is the ground truth. Webhooks are a push notification layer on top.

### 8.1 What gets stored

- **`events` table** — every event that hit the bus: `id`, `timestamp`, `type`, `severity`, `source`, `message`, `data` (as JSON). Includes events that no webhook subscribed to, events dropped by rate limiting, events bypassed by the severity valve, and the `webhook.rate_limited` self-announces.
- **`delivery_history` table** — every webhook delivery attempt: which webhook, which event ID, HTTP status, attempt number (1 for first try, 2+ for retries), response snippet. Rate-limited drops are recorded here with `status: 0` and response `"rate limited"` so you can see exactly which events didn't make it to which endpoints.

### 8.2 Retention

The log is pruned in the background based on `events.log.max_age_days` (default **90**). Set it to whatever your audit requirements demand:

```yaml
events:
  log:
    enabled: true
    database: "data/events.db"
    max_age_days: 365        # one year of history
```

Set to `0` to disable automatic pruning entirely — the log will grow until you manage it manually.

### 8.3 What's searchable, what's not

The `GET /api/events` endpoint hits a parameterized SQLite SELECT. Server-side filters are:

| Parameter | Match | Notes |
|-----------|-------|-------|
| `type` | exact, or `prefix.*` glob | `type=protocol.*` matches all `protocol.*` events via SQL `LIKE 'protocol.%'` |
| `severity` | exact | `info`/`warning`/`error`/`critical` |
| `min_severity` | threshold | returns everything at or above the level |
| `source` | **exact only** | no wildcards — use `jq` for prefix/suffix searches (see recipes below) |
| `start` / `end` | RFC3339 range | UTC; either or both may be omitted |
| `limit` | count cap | defaults to 100, raise for forensic sweeps |

These can be combined freely; they're ANDed together in the query.

**Not searchable server-side:**

- The `message` text field — no `LIKE '%foo%'`, no full-text search. The base SQLite build does not enable FTS5 on the events table.
- The `data` JSON blob — no JSON-path query support. You can't ask "find events where `data.task_count > 100`" server-side.
- `source` wildcards, as noted above.

**The workaround** for all three is to pull a generous time-window slice and filter client-side with `jq`. On the scale of events a typical PLC emits (thousands per day at most), a broad fetch + local filter is fast and avoids the complexity of maintaining FTS indexes. Examples are in the recipes below.

### 8.4 Forensic query patterns

**"What happened during the incident last night?"**

```bash
curl 'http://host/api/events?start=2026-04-09T22:00:00Z&end=2026-04-10T02:00:00Z&min_severity=warning'
```

**"How many task faults in the last hour?"**

```bash
curl 'http://host/api/events/summary?since_hours=1' | jq '.summary'
```

**"Did the PagerDuty webhook actually deliver during the incident?"**

```bash
curl 'http://host/api/webhooks/pagerduty-oncall/history?limit=500' \
  | jq '.history[] | select(.timestamp >= "2026-04-09T22:00:00Z" and .status != 200)'
```

If any events show `status: 0` with response `"rate limited"` in that window, you just proved your cap was too tight and got a list of exactly what was dropped.

**"Has any webhook been saturated in the last day?"**

```bash
curl 'http://host/api/events?type=webhook.rate_limited&since_hours=24'
```

Every rate-limit saturation episode is visible as a stored event.

**"What was the most recent protocol error from any Modbus client?"**

Server-side, `source` is exact-match only — no wildcards. So pull down the recent protocol errors and filter with `jq`:

```bash
curl 'http://host/api/events?type=protocol.error&limit=50' \
  | jq '.events | map(select(.source | startswith("modbus:"))) | .[0]'
```

**"Show me every config change in the last week and who made it."**

```bash
curl 'http://host/api/events?type=config.change&since_hours=168' \
  | jq '.events[] | {ts: .timestamp, user: .data.user, action: .data.action, section: .data.section}'
```

The `config.change` events include the user from the auth context, the client IP, the section that changed, and the byte count before/after — a full audit trail with no extra instrumentation.

### 8.5 Querying from ST code

Two builtins let your ST program ask the log questions:

```iec
VAR
    faults_last_hour : DINT;
    last_fault_json  : STRING[512];
END_VAR

faults_last_hour := EVENT_COUNT('task.fault', 3600000);   (* last 1h *)
last_fault_json  := EVENT_LAST('task.fault');             (* '' if none *)

IF faults_last_hour > 5 THEN
    NOTIFY_CRITICAL('5+ task faults in the last hour — investigate');
END_IF;
```

`EVENT_COUNT(type, since_ms)` returns a `DINT` — the number of events of that type in the last N milliseconds. `EVENT_LAST(type)` returns the most recent matching event serialized as JSON, or `''` if none. Both return zero/empty without erroring if the store is disabled, so ST code that uses them degrades gracefully on nodes with the log turned off.

### 8.6 One log per node

The log is local to each PLC instance. A 20-node cluster has 20 independent `events.db` files, one per node. For cross-node forensics, either:

1. Query each node's `/api/events` in a loop from your monitoring box, or
2. Subscribe to every node's MQTT event topics from a central collector:

```bash
# From your monitoring box, tap every node's events in real time:
for node in plc-01 plc-02 plc-03; do
  mosquitto_sub -h $node -t 'goplc/events/#' -v &
done
wait
```

The MQTT event publisher is specifically there for the "one log per node" problem — it fans out every event over the network as it happens, so a central aggregator (Grafana/Loki, Elastic, Splunk, your own sink) can build a unified timeline. The per-node SQLite log is the fallback for when the network is down.

## 9. ST Functions

Eight builtins let ST code emit, query, and send notifications. All return `BOOL` or an integer status; none of them block the scan for longer than a few microseconds unless explicitly marked.

### EVENT_EMIT / EVENT_EMIT_DATA

```iec
EVENT_EMIT('batch.complete', 'info', 'Batch 742 finished');
EVENT_EMIT_DATA('quality.reject', 'warning',
    'Reject on unit 17',
    '{"unit":17,"reason":"overweight","grams":512}');
```

Publishes a custom event on the bus. The `source` field is filled in automatically as `st:<program_name>`. `data_json` is parsed as JSON if it starts with `{` or `[`; otherwise it's stored as a string. Returns `TRUE` if queued, `FALSE` only when the bus is uninitialized.

### EVENT_COUNT / EVENT_LAST

```iec
recent_faults := EVENT_COUNT('task.fault', 3600000);  // last hour (ms)
last_fault    := EVENT_LAST('task.fault');            // JSON string or ''
```

`EVENT_COUNT(type, since_ms)` returns a `DINT` — the number of events of that type emitted in the last N ms. `EVENT_LAST(type)` returns the most recent matching event serialized as JSON, or `''` if none. Both require the SQLite log (`events.log.enabled: true`); they return `0`/`''` without erroring if the log is off.

### WEBHOOK_SEND / WEBHOOK_SEND_ASYNC

```iec
// Blocking — returns HTTP status or 0 on transport error
status := WEBHOOK_SEND(
    'https://your-endpoint.example/alert',
    '{"machine":"press-3","state":"jammed"}');

// Non-blocking — fire-and-forget, returns TRUE immediately
WEBHOOK_SEND_ASYNC(
    'https://your-endpoint.example/alert',
    '{"machine":"press-3","state":"jammed"}');
```

Use `WEBHOOK_SEND` when you care about the HTTP response code. Use `WEBHOOK_SEND_ASYNC` in any scan cycle where you don't want network latency counting against the watchdog — it spawns a goroutine and drops the result. Both default to `application/json`; the blocking form accepts optional `content_type` and `timeout_s` arguments.

These bypass the bus entirely. They're direct HTTP POSTs. For anything that benefits from retry, dedup, or fanout across multiple destinations, emit to the bus with `EVENT_EMIT` and let the configured webhooks do the work.

### NOTIFY / NOTIFY_CRITICAL

```iec
NOTIFY('slack-ops', 'Line 2 restarted cleanly after the jam');
NOTIFY_CRITICAL('COOLANT LEVEL LOW — manual intervention required');
```

`NOTIFY(channel, message)` emits `notify.<channel>` at `info` severity. The convention is to name the channel after your webhook, then subscribe that webhook to `notify.<name>`:

```yaml
- name: "slack-ops"
  url: "..."
  format: "slack"
  event_types: ["notify.slack-ops", "task.fault"]
```

`NOTIFY_CRITICAL(message)` emits `notify.critical` at `critical` severity. Any webhook subscribed to `notify.*`, `notify.critical`, or `*` picks it up — and because it's `critical`, it also passes any `min_severity: critical` filter on a paging webhook.

## 10. REST API

Ten endpoints cover the feature. All return JSON.

### Events

```bash
# Query the SQLite log
curl 'http://host:port/api/events?type=task.*&severity=warning&limit=50'
curl 'http://host:port/api/events?min_severity=error&start=2026-04-10T00:00:00Z'

# Emit a custom event over HTTP
curl -X POST http://host:port/api/events \
  -H 'Content-Type: application/json' \
  -d '{"type":"maintenance.start","severity":"info","message":"Weekly PM begins"}'

# Counts grouped by (type, severity), plus bus stats
curl 'http://host:port/api/events/summary?since_hours=24'

# Registered event type catalog with descriptions
curl http://host:port/api/events/types

# Live WebSocket stream of every event as it happens
wscat -c ws://host:port/api/events/stream
```

`GET /api/events` supports `type` (with `*` wildcards), `severity` (exact), `min_severity` (threshold), `source`, `start`, `end` (RFC3339), and `limit` (default 100).

### Webhooks

```bash
# List configured webhooks with delivery stats
curl http://host:port/api/webhooks

# Add a webhook at runtime (persists for process lifetime)
curl -X POST http://host:port/api/webhooks \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "ops-slack",
    "url": "https://hooks.slack.com/services/...",
    "format": "slack",
    "min_severity": "warning",
    "event_types": ["task.fault","protocol.*"]
  }'

# Remove a webhook
curl -X DELETE http://host:port/api/webhooks/ops-slack

# Fire a synthetic test event to the named webhook (bypasses filters)
curl http://host:port/api/webhooks/ops-slack/test

# Delivery history (requires events.log.enabled)
curl 'http://host:port/api/webhooks/ops-slack/history?limit=50'
```

Runtime-added webhooks are in-memory only — they disappear on restart. To make them permanent, add the same entry to your `events.webhooks:` YAML list.

## 11. Recipes

### Slack channel for operations alerts

```yaml
events:
  enabled: true
  log: { enabled: true }
  webhooks:
    - name: "ops"
      url: "https://hooks.slack.com/services/<TEAM_ID>/<BOT_ID>/<TOKEN>"
      format: "slack"
      min_severity: "warning"
      event_types: ["task.fault", "protocol.*", "system.*", "notify.ops"]
```

From ST, emit on-demand notifications to the same channel:

```iec
IF door_sensor AND NOT production_running THEN
    NOTIFY('ops', 'Door opened while line is idle');
END_IF;
```

### PagerDuty on-call, criticals only

```yaml
webhooks:
  - name: "oncall"
    url: "https://events.pagerduty.com/v2/enqueue"
    format: "pagerduty"
    routing_key: "R0UTINGKEYFROMPD..."
    min_severity: "critical"
    event_types: ["*"]
```

In ST, raise a page from a safety interlock:

```iec
IF tank_overtemp AND NOT interlock_ack THEN
    NOTIFY_CRITICAL('Tank 3 overtemperature — interlock engaged');
END_IF;
```

### Custom alarm counter on an HMI

```iec
VAR
    faults_last_hour : DINT;
    last_fault_json  : STRING[512];
END_VAR

faults_last_hour := EVENT_COUNT('task.fault', 3600000);
last_fault_json  := EVENT_LAST('task.fault');
```

Bind `faults_last_hour` and `last_fault_json` to dashboard widgets via the standard variable APIs.

### Live event tail for debugging

```bash
# Terminal 1: watch every event as it happens over MQTT
mosquitto_sub -h localhost -t 'goplc/events/#' -v

# Terminal 2: or tail the bus over WebSocket
wscat -c ws://localhost:8302/api/events/stream

# Terminal 3: query history
curl -s 'http://localhost:8302/api/events?limit=20' | jq '.events[] | {ts:.timestamp,type,msg:.message}'
```

### Webhook receiver for testing (Python)

```python
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(n)
        print(json.dumps(json.loads(body), indent=2))
        self.send_response(200); self.end_headers()

HTTPServer(('0.0.0.0', 9000), Handler).serve_forever()
```

Point a `generic`-format webhook at `http://<your-ip>:9000/` and you'll see every matching event printed in real time.

## 12. Threshold Monitor

The threshold monitor samples the Go heap and the data-dir filesystem every `sample_interval_ms`. It's edge-triggered — you get one event when usage crosses a threshold, and the next event for that resource doesn't fire until it drops back below and crosses again. No alert storms.

```yaml
events:
  thresholds:
    memory_warning_pct: 85
    disk_warning_pct: 90
    sample_interval_ms: 5000
```

Events emitted:

- `system.memory` (warning) — carries `{heap_mb, pct, threshold}`
- `system.disk` (warning) — carries `{free_mb, used_mb, pct, path}`

Set any value to `0` to skip that check. If you want to react in ST, emit from those types using `EVENT_COUNT` or subscribe via the WebSocket stream from a separate process.

## 13. Performance Notes

- **Bus fanout is channel-based.** Each subscriber has its own buffer (`bus_size`, default 1024). A slow subscriber is dropped-per-event, not backpressured — the emitter never waits.
- **Webhook workers run off-bus.** Each webhook has its own goroutine + retry loop, so a down Slack endpoint can't slow down PagerDuty or vice versa.
- **SQLite writes are batched.** The log writer flushes periodically; individual `Publish` calls don't hit disk.
- **MQTT publishes are in-process** when you use `auto_create`. Zero network hop; it's a function call to the embedded broker, which then fans out to any connected subscribers over the loopback TCP listener.
- **`dedup_window_ms` runs at publish time** — duplicates are dropped before they reach any subscriber.

On a typical Pi 4, emitting 1000 events/second through three webhooks, MQTT, and SQLite stayed under 2% CPU in internal testing.

## 14. Related

- **Spec:** `docs/spec/WEBHOOK_EVENTS.md` — the design document this feature implements.
- **Alarm Management:** `docs/spec/ALARM_MANAGEMENT.md` — planned, will use the `alarm.*` event types.
- **Resilience guide:** `goplc_resilience_guide` — circuit breakers and retries for the protocol calls whose `protocol.error` events you're catching.
- **Cluster guide:** `goplc_clustering_guide` — `cluster.node_join`/`cluster.node_lost` events.

---

Everything in this guide works on the running instance as of v1.0.552. If you extend the event types or add a new webhook format, add it to `pkg/events/` and register it in the tables above.
