# GoPLC Edge Historian

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.594

---

The GoPLC edge historian records tag values into a local SQLite database with deadband filtering, time decimation, automatic downsampling, event-triggered burst capture, and multi-destination forwarding to InfluxDB, MQTT per-tag topics, or HTTP webhooks. You can register tags declaratively in YAML, imperatively from ST with `HIST_LOG`, or turn on `log_all: true` to auto-register every runtime variable VTScada-style. Samples flush to disk on a timer so the scan loop never stalls on I/O. Queries, aggregates (min/max/avg), CSV export, and a per-tag stats view are exposed over REST so Grafana, Node-RED, or a scripted report can read straight from the edge node without an upstream historian round trip. Burst mode captures a dense window of samples around an event (watchdog trip, alarm, anything on the events bus) so you have pre- and post-incident context without paying the storage cost for continuous high-rate logging.

## 1. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        GoPLC Runtime                         │
│                                                              │
│  Scan loop ───► variables ───► historian sampler (tick)      │
│                                   │                          │
│                                   ▼                          │
│              ┌─────────────────────────────────────────┐     │
│              │       pkg/historian.Engine              │     │
│              │                                         │     │
│              │   per-tag ring buffer (buffer_size)     │     │
│              │   deadband filter    interval enforce   │     │
│              │   decimation tiers   burst capture      │     │
│              │                                         │     │
│              │   flush ticker (flush_interval_ms)      │     │
│              └──────────────┬──────────────────────────┘     │
│                             │ batched INSERT                 │
│                             ▼                                │
│              ┌─────────────────────────────────────────┐     │
│              │  data/historian.db (SQLite, WAL)        │     │
│              │  samples (tag_id, ts_ms, value, qual)   │     │
│              │  tags   (name, deadband, interval, ...) │     │
│              └──────────────┬──────────────────────────┘     │
│                             │                                │
│              ┌──────────────┼──────────────────────────┐     │
│              │              │                           │    │
│              ▼              ▼                           ▼    │
│      REST /api/history   Forwarder goroutines    Burst capt. │
│      (query/export/      (InfluxDB / MQTT /      (event-     │
│       tag mgmt/stats)     webhook)                triggered) │
└──────────────────────────────────────────────────────────────┘
```

Five things happen inside the engine:

1. **Sampling** — one goroutine walks the registered-tag list every tick, reads each tag's current value from the executor, applies the per-tag interval and deadband, and pushes accepted samples into the tag's in-memory ring buffer.
2. **Flushing** — a separate ticker fires every `flush_interval_ms` (default 1 s) and batches every buffered sample into a single SQLite transaction via `pkg/sqlitebatch`. The scan loop never waits on disk.
3. **Decimation** — background retention logic replaces raw samples older than `decimation.1min_after_hours` with 1-minute rollups, and samples older than `decimation.1hour_after_days` with 1-hour rollups. The source-of-truth resolution degrades smoothly over time instead of falling off a cliff when retention expires.
4. **Burst capture** — an event-triggered worker subscribes to configured bus events and, on trigger, records a high-rate snapshot of a tag set for `duration_s` seconds. Bursts bypass deadband so you always get the full waveform around an incident.
5. **Forwarding** — optional goroutines replicate every flushed sample to InfluxDB (line protocol), MQTT (per-tag retained messages), or an HTTP webhook (JSON summary). Failures back off with retry; the upstream sink cannot stall the edge loop.

The historian engine is a package-level singleton (`historian.GlobalEngine()`), so Go code, ST builtins, and REST handlers all talk to the same instance.

## 2. Configuration

Everything lives under the `historian:` block. Every field has a default; the minimum useful config is `enabled: true`.

```yaml
historian:
  enabled: true
  database: "data/historian.db"     # SQLite path (default: data/historian.db)
  max_size_mb: 500                  # auto-prune when exceeded (default: 500)
  max_age_days: 90                  # delete data older than (default: 90)
  flush_interval_ms: 1000           # batch write cadence (default: 1000)
  buffer_size: 1000                 # in-memory ring per tag (default: 1000)

  # VTScada-style "log every variable" mode — optional
  log_all: false
  log_all_interval_ms: 1000          # default interval for auto-registered tags
  log_all_deadband: 0                # default deadband (0 = log every change)

  decimation:
    1min_after_hours: 24             # rollup raw samples to 1 min after 24 h
    1hour_after_days: 7              # rollup 1 min samples to 1 h after 7 d

  # Declarative tags — logged for the life of the runtime
  tags:
    - pattern: "main_task.boiler_temp_c"
      interval_ms: 500
      deadband: 0.1

    - pattern: "main_task.pressure_*"   # glob match — every pressure variable
      interval_ms: 1000
      deadband: 0.5

  # Event-triggered burst captures
  bursts:
    - trigger: "task.fault"             # bus event type
      filter: "task:MainTask"           # bus source (optional)
      tags: "main_task.*"               # glob of tags to capture
      duration_s: 300                   # capture 5 minutes after the trigger
      interval_ms: 100                  # at 100 ms resolution

    - trigger: "alarm.active"
      filter: "alarm:high_temp:*"
      tags: "main_task.boiler_*"
      duration_s: 600
      interval_ms: 50

  # Upstream forwarding
  forwarding:
    enabled: true
    destinations:
      - type: influxdb
        url: "http://10.0.0.144:8086"
        database: "goplc_plant1"
        batch_size: 500
        flush_interval_ms: 5000
        retry_interval_s: 30

      - type: mqtt
        url: "tcp://10.0.0.144:1883"
        topic_prefix: "goplc/plant1/history"
        qos: 1
        retained: true

      - type: webhook
        url: "https://ops.example.com/api/edge-summary"
        format: "summary"
        schedule: "@hourly"
```

A few things to internalize:

**`log_all: true`** auto-registers every variable the executor knows about. Every runtime variable becomes a historian tag with the default interval and deadband. This is the fastest way to light up an entire plant — you don't have to enumerate the tags you care about — but it costs disk space proportional to the variable count. On a ten-thousand-tag project, expect a few gigabytes per day at 1 Hz.

**`tags:` with glob patterns** lets you register groups in one line. `"main_task.pressure_*"` picks up every variable in `main_task` whose name starts with `pressure_`. The engine evaluates the glob once at register time; adding a new variable to the scan after the fact requires a reload.

**`decimation`** is a retention policy, not a query-time aggregation. Old raw samples are physically replaced with rollups, freeing disk space. If you need raw resolution indefinitely, set the decimation fields to zero — the historian will keep raw samples until `max_age_days` expires them.

**`forwarding.destinations`** is a list — you can have an InfluxDB, an MQTT broker, and a webhook all running in parallel. Each destination has its own retry backoff; one slow upstream doesn't block the others. The `format: "summary"` option on a webhook sends periodic aggregates instead of individual samples, useful for HTTP receivers that can't handle the volume.

## 3. ST Functions

Fifteen builtins cover tag lifecycle, queries, aggregates, burst control, and DB stats. All return a safe zero-equivalent if the historian engine isn't enabled, so guard-free usage from ST is safe.

### 3.1 Tag management

```iec
(* Register a tag for continuous logging *)
(* HIST_LOG(tag_name, deadband, interval_ms) : BOOL *)
HIST_LOG('main_task.boiler_temp_c', 0.1, 500);

(* Register with default interval (1000 ms) and no deadband *)
HIST_LOG('main_task.pump_speed');

(* Stop logging a tag — does not delete history *)
HIST_STOP('main_task.boiler_temp_c');

(* Manual value injection — for computed values that aren't scoped variables *)
(* HIST_LOG_VALUE(tag_name, value, quality) : BOOL *)
HIST_LOG_VALUE('derived.setpoint_error', sp - pv, 0);
```

`HIST_LOG` registers a tag by name. The name format is the lowercase scoped form — `main_task.boiler_temp_c` matches the variable key the executor maintains internally. `deadband` of `0` logs every value change; a positive value only logs when the new value differs from the last-logged value by more than the deadband (prevents chatter on noisy analogs). `interval_ms` throttles samples — a registered tag records at most once per interval even if it changes more often. Set `interval_ms` to `0` for on-change-only logging.

`HIST_LOG_VALUE` is the escape hatch for synthetic tags — values that are computed in ST but don't exist as scheduler variables. The engine registers the tag on first call (with no deadband, no interval) and captures the value directly. Useful for derived signals like setpoint error, PID output, or a rolling average you compute in ST.

### 3.2 Queries and aggregates

```iec
VAR
    json_points : STRING;
    latest      : REAL;
    minv        : REAL;
    maxv        : REAL;
    avgv        : REAL;
    t_now       : LINT;
    t_hr_ago    : LINT;
END_VAR

t_now    := NOW_MS();
t_hr_ago := t_now - 3600000;

(* Last value for a tag — 0.0 if tag not found *)
latest := HIST_LAST('main_task.boiler_temp_c');

(* Min/max/avg over a time range (ms epoch) *)
minv := HIST_MIN('main_task.boiler_temp_c', t_hr_ago, t_now);
maxv := HIST_MAX('main_task.boiler_temp_c', t_hr_ago, t_now);
avgv := HIST_AVG('main_task.boiler_temp_c', t_hr_ago, t_now);

(* Raw JSON-array query — max_points clamps the result *)
(* HIST_QUERY(tag_name, start_ms, end_ms, max_points) : STRING *)
json_points := HIST_QUERY('main_task.boiler_temp_c', t_hr_ago, t_now, 500);
```

`HIST_LAST` is the most commonly used — it returns the most recent historian-recorded value, which can be stale by up to one `flush_interval_ms` but is typically fresh. Use it to recover state across a cold boot when RETAIN isn't enabled for a particular variable.

`HIST_MIN` / `HIST_MAX` / `HIST_AVG` compute the aggregate directly against the SQLite store, so you don't have to round-trip a large JSON array just to get a scalar. The time range is milliseconds since Unix epoch — grab `NOW_MS()` and subtract.

`HIST_QUERY` returns a JSON array of `{ts,value,quality}` triplets. Use it when you need the waveform itself — for a custom chart in the HMI, an anomaly detector, or to publish a time-series summary onto the event bus.

### 3.3 Burst capture

```iec
VAR
    burst_id : STRING;
END_VAR

(* Start a 5-minute burst at 50 ms resolution for every main_task tag *)
burst_id := HIST_BURST_START('main_task.*', 300, 50);

(* … later, after something triggers the burst to end early …*)
HIST_BURST_STOP(burst_id);
```

`HIST_BURST_START` kicks off a time-bounded high-rate capture for a tag glob. It returns a burst ID you can use to stop it early. Bursts bypass per-tag deadband and interval — you get every value at the configured capture interval regardless of how the tag was originally registered. When `duration_s` elapses, the burst stops automatically.

This is the imperative form. The YAML `historian.bursts` list is the declarative equivalent, driven by bus events — typically preferred so you don't have to write ST code that watches the event stream.

### 3.4 DB management

```iec
VAR
    n_tags      : DINT;
    n_samples   : LINT;
    db_size     : REAL;
    pruned      : LINT;
END_VAR

n_tags    := HIST_TAG_COUNT();
n_samples := HIST_SAMPLE_COUNT('main_task.boiler_temp_c');
db_size   := HIST_DB_SIZE_MB();
pruned    := HIST_PRUNE(30);   (* remove samples older than 30 days *)
HIST_FLUSH();                   (* force an immediate batch write *)
```

`HIST_PRUNE` accepts a max-age argument; note the current build triggers a generic prune/flush cycle and returns `1` on success rather than the deleted row count (the store's prune method doesn't surface the count yet). Use it to clean up proactively ahead of `max_size_mb` eviction. `HIST_FLUSH` forces the batch writer to commit the current ring buffers to disk — useful right before a planned shutdown or a coordinated snapshot.

## 4. REST API

Seven endpoints, all under `/api/history/*`. All return JSON unless you request CSV explicitly.

### 4.1 Query samples

```bash
# Last hour of samples for a tag
NOW=$(date +%s%3N)
HR=$((NOW - 3600000))
curl "http://host:port/api/history?tag=main_task.boiler_temp_c&start=$HR&end=$NOW&points=500"

# CSV download — add &format=csv
curl "http://host:port/api/history?tag=main_task.boiler_temp_c&start=$HR&end=$NOW&format=csv" \
  -o boiler_temp.csv

# Dedicated export endpoint (always CSV)
curl "http://host:port/api/history/export?tag=main_task.boiler_temp_c&start=$HR&end=$NOW" \
  -o boiler_temp_export.csv
```

The JSON response has `tag`, `points`, `count`, `start_ms`, and `end_ms`:

```json
{
  "tag": "main_task.boiler_temp_c",
  "points": [
    {"timestamp": 1744551600000, "value": 78.2, "quality": 0},
    {"timestamp": 1744551601000, "value": 78.3, "quality": 0},
    {"timestamp": 1744551602000, "value": 78.5, "quality": 0}
  ],
  "count": 3,
  "start_ms": 1744548000000,
  "end_ms": 1744551600000
}
```

`quality` is 0 for good samples. Non-zero codes are reserved for future use (sensor fault, stale, substituted).

Both endpoints hard-cap the result at 1,000 points (`points=` query param) for the JSON form and 100,000 for the CSV export. If you need more, query smaller windows in a loop.

### 4.2 Tag management

```bash
# List all logged tags with per-tag stats
curl http://host:port/api/history/tags

# Register a new tag
curl -X POST -H 'Content-Type: application/json' \
  -d '{"name":"main_task.flow_rate","deadband":0.5,"interval_ms":1000}' \
  http://host:port/api/history/tags

# Stop logging a tag and remove its data
curl -X DELETE http://host:port/api/history/tags/main_task.flow_rate
```

`GET /api/history/tags` returns a list with per-tag sample counts, first/last timestamps, and the configured deadband/interval — useful for a "what am I logging" overview on the HMI.

Deleting a tag via the REST endpoint **does** remove its historical samples. If you want to stop sampling but keep the data, stop the tag from ST via `HIST_STOP` instead; that path unregisters the tag without touching the store.

### 4.3 Stats and maintenance

```bash
# Overall DB size, sample count, oldest/newest timestamps
curl http://host:port/api/history/stats

# Manual prune (admin-triggered retention cleanup + flush)
curl -X POST http://host:port/api/history/prune
```

`GET /api/history/stats` returns:

```json
{
  "db_size_mb": 127.4,
  "sample_count": 9243150,
  "tag_count": 284,
  "oldest_ts": 1739052000000,
  "newest_ts": 1744551600000
}
```

`POST /api/history/prune` triggers a flush + retention cycle on demand. The regular scheduled prune runs automatically based on `max_size_mb` and `max_age_days`.

## 5. Forwarding destinations

The historian has native forwarders for three destination types. Configure any combination under `historian.forwarding.destinations`. Each destination is independent — failure on one doesn't affect the others, and each has its own retry backoff.

### 5.1 InfluxDB

```yaml
- type: influxdb
  url: "http://10.0.0.144:8086"
  database: "goplc_plant1"          # InfluxDB v1 database, or v2 bucket name
  batch_size: 500                    # batch point writes for throughput
  flush_interval_ms: 5000            # commit the batch every 5 s
  retry_interval_s: 30               # wait 30 s before retry on failure
```

Line-protocol writes to `POST /write?db=<database>`. Each flushed historian sample becomes one point with the tag name as the measurement, the value as the `value` field, and the quality code as a tag. Tags with special characters are escaped per Influx line-protocol rules.

The forwarder does **not** pass authentication by default — if your InfluxDB requires auth, put credentials in the URL (`http://user:pass@host:8086`). The forwarder uses stdlib `net/http` with a 10-second timeout; large batches that exceed the timeout are retried on the next interval.

### 5.2 MQTT

```yaml
- type: mqtt
  url: "tcp://10.0.0.144:1883"
  topic_prefix: "goplc/plant1/history"
  qos: 1
  retained: true
  batch_size: 100
  flush_interval_ms: 1000
```

Each sample is published to `<topic_prefix>/<tag_name>` (dots in the tag name are converted to slashes). The payload is a JSON object `{"ts":...,"value":...,"quality":...}`. With `retained: true`, new subscribers immediately see the last value of every tag — the MQTT equivalent of "current state" without polling.

Point this at GoPLC's own embedded MQTT broker (the one used by the events bus) to get a single unified broker for events and history. Point it at a separate Mosquitto, EMQX, or HiveMQ if you need external subscribers.

### 5.3 Webhook

```yaml
- type: webhook
  url: "https://ops.example.com/api/edge-summary"
  format: "summary"
  schedule: "@hourly"
```

Hits an HTTP endpoint with a periodic JSON summary of historian activity — tag count, sample count, DB size, flush latency. Intended for dashboards and health probes, not for raw sample delivery. If you need raw samples over HTTP, point an MQTT bridge or a Node-RED function at the MQTT forwarder instead.

## 6. Burst capture — the two modes

### 6.1 Declarative (YAML, event-triggered)

Preferred for reactive capture around known failure modes. Configure a burst under `historian.bursts`:

```yaml
historian:
  bursts:
    - trigger: "task.fault"
      filter: "task:MainTask"
      tags: "main_task.*"
      duration_s: 300
      interval_ms: 100
```

When the event bus emits a `task.fault` event whose source matches `task:MainTask`, the burst worker captures every variable in `main_task.*` at 100 ms resolution for 5 minutes. Burst samples bypass per-tag deadband — you get the full waveform regardless of configured filters. The burst start and stop emit `historian.burst_started` and `historian.burst_stopped` events for audit.

### 6.2 Imperative (ST, program-triggered)

Useful when the trigger is a condition your ST code detects directly rather than a bus event:

```iec
PROGRAM AnomalyCatcher
VAR
    delta          : REAL;
    active_burst   : STRING := '';
    alarm_was_hot  : BOOL := FALSE;
    alarm_is_hot   : BOOL;
END_VAR

    alarm_is_hot := ALARM_IS_ACTIVE('high_temp');

    IF alarm_is_hot AND NOT alarm_was_hot THEN
        (* Rising edge — start a 10-minute burst at 50 ms *)
        active_burst := HIST_BURST_START('main_task.*', 600, 50);
    END_IF;

    IF NOT alarm_is_hot AND alarm_was_hot AND active_burst <> '' THEN
        (* Cleared early — stop the burst so we don't waste disk *)
        HIST_BURST_STOP(active_burst);
        active_burst := '';
    END_IF;
    alarm_was_hot := alarm_is_hot;
END_PROGRAM
```

Prefer the declarative form when you can — it keeps the trigger logic in config and reusable across programs. Use the imperative form for conditions that can't be expressed as a simple event type filter.

## 7. Recipes

### 7.1 Log every variable, light a Grafana dashboard

```yaml
historian:
  enabled: true
  log_all: true
  log_all_interval_ms: 1000
  log_all_deadband: 0
  decimation:
    1min_after_hours: 24
    1hour_after_days: 7
  forwarding:
    enabled: true
    destinations:
      - type: influxdb
        url: "http://grafana-stack:8086"
        database: "goplc"
```

Every variable, 1 Hz, forwarded to InfluxDB. Grafana points at the Influx datasource and you have one-line panels for anything in the project. First deploy cost: 5 minutes.

### 7.2 Pre- and post-incident capture for alarm conditions

```yaml
historian:
  enabled: true
  tags:
    - pattern: "main_task.*"
      interval_ms: 1000
      deadband: 0.0

  bursts:
    - trigger: "alarm.active"
      filter: "alarm:*"
      tags: "main_task.*"
      duration_s: 600
      interval_ms: 50
```

Regular 1 Hz logging for trending, plus a 10-minute burst at 50 ms resolution the moment any alarm trips. You end up with a low-cost continuous record for every tag and a high-res snapshot around every incident.

### 7.3 Compute a setpoint-error trend from ST

```iec
PROGRAM ErrorTrending
VAR
    sp    : REAL;
    pv    : REAL;
    err   : REAL;
END_VAR

    err := sp - pv;
    HIST_LOG_VALUE('trend.setpoint_error', err, 0);
END_PROGRAM
```

One line per scan writes a synthetic signal into the historian. The derived tag is queryable exactly like any other:

```bash
curl "http://host:port/api/history?tag=trend.setpoint_error&start=$HR&end=$NOW"
```

### 7.4 Weekly report over webhook

Point a webhook at your reporting system and have it pull an hourly summary:

```yaml
historian:
  forwarding:
    enabled: true
    destinations:
      - type: webhook
        url: "https://reporting.internal/goplc/hourly"
        format: "summary"
        schedule: "@hourly"
```

The webhook gets a JSON summary every hour; a downstream cron job aggregates seven hours into a weekly report, stores it in the reporting system, and emails the plant manager. No ST code required.

### 7.5 Cold-boot recovery via `HIST_LAST`

```iec
PROGRAM StateRecovery
VAR
    recovered     : BOOL := FALSE;
    cached_temp   : REAL;
    cached_sp     : REAL;
END_VAR

    IF NOT recovered THEN
        cached_temp := HIST_LAST('main_task.boiler_temp_c');
        cached_sp   := HIST_LAST('main_task.boiler_setpoint');
        recovered := TRUE;
    END_IF;
END_PROGRAM
```

On cold boot, ST reads the last recorded value of tags that aren't on the RETAIN list. Useful for recovering non-critical state without expanding RETAIN (which has its own crash-safety overhead — see the system monitoring guide).

## 8. Performance notes

- **Flush cost** is O(buffered samples) × one SQLite transaction per `flush_interval_ms`. A 1 s flush interval with 100 tags at 1 Hz is ~100 rows per transaction — microseconds of disk time on WAL-mode SQLite.
- **Per-sample cost** at registration time is a map lookup + one channel send into the batch writer. Single-digit microseconds.
- **`log_all: true` overhead** scales linearly with variable count. Ten thousand variables at 1 s interval = ~10 kB/s disk write rate plus proportional RAM for the ring buffers.
- **Query cost** is O(rows_in_range) with indexed lookups on `(tag_id, timestamp)`. A million-row query for one tag over one day takes 50–200 ms. Aggregates (`HIST_MIN/MAX/AVG`) run as SQL aggregates — same cost as the underlying query.
- **Decimation cost** is an off-schedule background pass — the engine does not pause sampling while decimating. Expect a few seconds of CPU per gigabyte of raw samples compacted.
- **Forwarding cost** is the cost of encoding the payload (Influx line protocol, JSON for MQTT/webhook) plus network round trip. Runs on its own goroutine; upstream failures do not back up the sampler.
- **Max DB size** enforcement is lazy — the engine checks `db_size_mb` on each flush and prunes from the oldest end only when the limit is crossed. Setting `max_size_mb` lower than steady-state churn can cause flapping; leave headroom.

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `GET /api/history/tags` returns empty list | Historian not enabled, or no tags registered (and `log_all: false`) | Set `enabled: true` and either register tags or turn on `log_all`. |
| Tag exists but `HIST_QUERY` returns `[]` | Time range is inverted or in the future | Check `start_ms` < `end_ms` and both are Unix milliseconds, not seconds. |
| `HIST_LAST` returns 0 for a tag that's definitely changing | Tag not registered (use `HIST_LOG` first) or last sample outside the buffered window and disk flush hasn't happened yet | Call `HIST_FLUSH()` or wait one `flush_interval_ms`. |
| DB grows beyond `max_size_mb` | Prune is asynchronous; sampler writes faster than the pruner deletes | Lower `flush_interval_ms` to trigger prune checks more often, or raise `max_size_mb`. |
| Samples missing during a burst | Burst `interval_ms` is lower than the engine's internal tick granularity | Minimum practical burst resolution is ~50 ms. Lower values get coalesced. |
| InfluxDB forwarder silently drops data | Auth required, credentials missing | Put credentials in the URL: `http://user:pass@host:8086`. |
| MQTT retained messages don't appear for new subscribers | `retained: false` in config | Set `retained: true` and reconnect the subscriber. |
| Decimation never runs | `1min_after_hours: 0` or `1hour_after_days: 0` disables that tier | Set to positive values to enable rollups. |
| `log_all: true` misses a new variable | The glob was resolved once at registration; new variables don't back-fill | Reload programs or call `HIST_LOG` explicitly for the new variable. |
| `HIST_LOG_VALUE` writes return `TRUE` but the value doesn't appear in queries | Known current-build limitation: manual values are staged until the next sampling tick picks them up | Use it for tags that are also registered via `HIST_LOG`, or wait for the direct-inject path to land. |

## 10. Related

- [`goplc_events_guide.md`](goplc_events_guide.md) — the bus that triggers burst captures.
- [`goplc_alarms_guide.md`](goplc_alarms_guide.md) — alarms that commonly gate `HIST_BURST_START` calls.
- [`goplc_influxdb_guide.md`](goplc_influxdb_guide.md) — the ST `INFLUX_*` builtins; the historian InfluxDB forwarder is independent but shares the same protocol.
- [`goplc_mqtt_guide.md`](goplc_mqtt_guide.md) — the broker used by the MQTT forwarder and the events fan-out.
- [`goplc_api_guide.md`](goplc_api_guide.md) — REST fundamentals, auth, and CSV responses.
