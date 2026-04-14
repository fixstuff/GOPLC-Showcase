# GoPLC Hot Standby Redundancy

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.594

---

GoPLC hot standby is active/standby redundancy with real-time state synchronization, automatic role election, and sub-second failover. Two GoPLC nodes on a network exchange heartbeats and full interpreter state — variables, timers, counters, SFC step indices — at a configurable cadence. One runs as primary and executes the scan; the other runs as standby, ingests state updates, and keeps its shadow interpreter ready for a bumpless takeover. When the primary goes dark, the standby promotes itself within a handful of heartbeat intervals (default ~1 s), starts its own scan, and takes over protocol I/O without dropping accumulated state. A priority-based split-brain resolver catches the case where both nodes survive a partition and come back thinking they're primary. Eight ST builtins and six REST endpoints let you inspect and drive the redundancy pair from programs, HMIs, or deploy scripts.

## 1. Architecture

```
┌─────────────────────────┐              ┌─────────────────────────┐
│     Node A (primary)    │              │    Node B (standby)     │
│                         │              │                         │
│  ┌──────────────────┐   │              │   ┌──────────────────┐  │
│  │ Scan loop        │   │              │   │ Shadow interp    │  │
│  │ (running)        │   │              │   │ (tasks stopped)  │  │
│  └────────┬─────────┘   │              │   └────────▲─────────┘  │
│           │             │              │            │            │
│           ▼             │              │            │            │
│  ┌──────────────────┐   │  State sync  │   ┌────────┴─────────┐  │
│  │ SyncService      │───┼──────────────┼──►│ SyncService       │  │
│  │  publisher       │   │ UDP + gzip   │   │  receiver         │  │
│  │  diff + full     │   │ every 10 ms  │   │  apply updates    │  │
│  └──────────────────┘   │              │   └──────────────────┘  │
│                         │              │                         │
│  ┌──────────────────┐   │  Heartbeat   │   ┌──────────────────┐  │
│  │ HeartbeatService │◄──┼──────────────┼──►│ HeartbeatService │  │
│  │  emit + observe  │   │ every 100 ms │   │  emit + observe  │  │
│  └────────┬─────────┘   │              │   └────────┬─────────┘  │
│           │             │              │            │            │
│           └────► events.Bus ◄──────────┼────────────┘            │
│                 cluster.node_join      │                         │
│                 cluster.node_lost      │                         │
│                 cluster.failover_*     │                         │
│                 cluster.split_brain    │                         │
│                         │              │                         │
│  ┌──────────────────┐   │              │   ┌──────────────────┐  │
│  │ Manager          │   │              │   │ Manager          │  │
│  │  role state      │   │              │   │  role state      │  │
│  │  machine         │   │              │   │  machine         │  │
│  └──────────────────┘   │              │   └──────────────────┘  │
└─────────────────────────┘              └─────────────────────────┘
```

Three services run on each node:

1. **`HeartbeatService`** — Publishes a heartbeat envelope every `heartbeat.interval_ms` (default 100 ms) and listens for the peer's heartbeats. On transitions (peer disappears, peer appears) it emits `cluster.node_lost` / `cluster.node_join` on the events bus. Also tracks role change history for audit.
2. **`SyncService`** — On the primary, publishes incremental state updates over UDP every `sync.interval_ms` (default 10 ms). The payload is a diff against the last send — only changed variables are serialized. On connect or force-sync, it sends a full state payload (gzip-compressed if `sync.compress: true`). On the standby, it receives UDP packets and applies them to the shadow interpreter.
3. **`Manager`** — Subscribes to the bus and runs the role state machine. Reacts to `cluster.node_lost` by promoting (if standby), to `cluster.node_join` by pushing a full sync (if primary) or checking for split-brain, and to manual `Promote` / `Demote` calls from REST or ST.

The scan loop lives in the task scheduler and is gated by role. A `RolePrimary` instance runs its tasks; a `RoleStandby` instance stops them and lets the SyncService mutate the interpreter state directly. A `RoleStandalone` instance (failover disabled or misconfigured) runs tasks like a normal non-redundant GoPLC.

## 2. Roles and initial election

Three role constants:

| Role | Meaning | Task execution |
|------|---------|----------------|
| `primary` | This node owns the scan and writes to physical I/O. | tasks running |
| `standby` | This node is a hot shadow of the primary. Tasks stopped; state is driven by sync packets. | tasks stopped |
| `standalone` | Failover not configured, or peer unreachable on boot and no auto election possible. Behaves like a regular non-redundant GoPLC. | tasks running |

You configure `role:` explicitly or set it to `"auto"` (the default) to let the pair negotiate at startup. The auto-election algorithm is:

1. At boot, wait one failover-timeout window (heartbeat interval × timeout multiplier, default 1 s) for a peer heartbeat.
2. **No peer observed** → become `primary`.
3. **Peer observed**, peer role is `primary` → become `standby`.
4. **Peer observed**, both roles are unresolved → compare configured `priority`; lower wins, take `primary`, tie goes to standby.

Because the wait is synchronous, both nodes can boot simultaneously and still land in opposite roles — whoever announces priority first wins the auto election. If you care about which physical machine is canonically primary, give it `priority: 1` and the partner `priority: 2`.

## 3. Configuration

One top-level `failover:` block covers the entire feature. Every field has a sensible default so a minimal two-node setup fits in ten lines per machine.

### 3.1 Minimal — two nodes, auto election

**Node A (`10.0.0.10`):**

```yaml
failover:
  enabled: true
  role: auto
  priority: 1
  peer:
    address: 10.0.0.11
    port: 8082
```

**Node B (`10.0.0.11`):**

```yaml
failover:
  enabled: true
  role: auto
  priority: 2
  peer:
    address: 10.0.0.10
    port: 8082
```

That's it. 100 ms heartbeat, 1 s failover timeout, 10 ms state sync, gzip compression, priority-based split-brain resolution. Node A takes primary unless it's unavailable at boot; Node B shadows it.

### 3.2 Full reference with all knobs

```yaml
failover:
  enabled: true
  role: auto                         # "primary", "standby", "auto" (default: auto)
  priority: 1                         # lower = preferred primary (default: 1)
  instance_id: ""                     # unique node ID (default: hostname)

  peer:
    address: 10.0.0.11                # peer IP or hostname — required
    port: 8082                        # peer API port (state sync uses port + 10001)

  heartbeat:
    interval_ms: 100                  # heartbeat period (default: 100)
    timeout_multiplier: 10            # failover after N missed beats (default: 10 → 1 s)
    transport: datalayer              # "datalayer" or "mqtt" — heartbeat transport (default: datalayer)

  sync:
    interval_ms: 10                   # incremental sync period (default: 10)
    full_sync_on_connect: true        # full transfer when standby connects (default: true)
    compress: true                    # gzip full-sync payloads (default: true)
    verify_hash_interval: 100         # verify state hash every N sync cycles (default: 100)

  protocols:
    mode: cold                        # "cold" (connect on failover) or "warm" (pre-connect read-only)

  split_brain:
    strategy: priority                # "priority" (default), "witness", "shared_lock"
    witness_address: ""               # for witness strategy
    lock_path: ""                     # for shared_lock strategy
```

Four subsections matter in practice:

**`heartbeat.timeout_multiplier`** controls failover aggressiveness. The effective failover timeout is `interval_ms × multiplier`. The default `100 × 10 = 1000 ms` means the standby promotes ~1 second after the primary disappears. Tight links can go lower (`100 × 5 = 500 ms` works on gigabit LAN); flaky Wi-Fi or congested backhaul links should go higher to avoid false positives during network hiccups. Never set the multiplier below `3` — one dropped packet should not cause failover.

**`sync.interval_ms`** trades CPU and bandwidth against state freshness. At 10 ms (default), the standby is at most 10 ms of scan progress behind the primary — bumpless for any non-cycle-accurate process. Raise it to 50 or 100 for slow processes where state freshness doesn't matter; lower it to 5 if you're on a LAN with CPU headroom and need sub-scan granularity.

**`sync.full_sync_on_connect`** determines what happens when the standby first comes up or reconnects after a partition. When true, the primary does a one-shot full state dump (optionally gzip-compressed) so the standby catches up in one packet. When false, the standby catches up incrementally — fine if state churn is slow, but can leave the shadow out of sync for minutes on a slow process.

**`protocols.mode`** — `cold` means the standby doesn't open any protocol driver connections until it's promoted. Bandwidth-free, but every protocol reconnects on failover, which adds 1–5 seconds of stalled I/O. `warm` has the standby open each driver in read-only mode so the TCP/MQTT session is already up when failover happens — more bandwidth, but failover is bumpless for the protocol layer too. Use `warm` when seconds of protocol stall are unacceptable (safety, interlocks, downstream SCADA expecting a continuous Modbus poll).

### 3.3 Split-brain strategies

When both nodes survive a partition and each one becomes primary on its own side, reconnection triggers split-brain detection on the `cluster.node_join` event. The `split_brain.strategy` field decides who wins:

- **`priority`** (default, in-tree): Compare configured `priority` values; lower number wins. Ties keep whichever node was already primary. Emits `cluster.split_brain_detected` at `critical` severity and `cluster.failover_started` on the losing side as it demotes.
- **`witness`** (spec'd, not yet implemented): Ping a third-party witness node. Whichever side can reach the witness wins. Useful when you don't trust either node's clock or priority to be authoritative.
- **`shared_lock`** (spec'd, not yet implemented): Acquire an exclusive flock on a shared filesystem path. First to get the lock wins.

As of v1.0.594 only the `priority` strategy is wired into the code. The config accepts the other values and falls back to priority.

## 4. State sync wire protocol

State sync is a dedicated UDP stream, **not** part of the HTTP API, and **not** the same as the UADP multicast DataLayer (documented separately). The publisher dials `peer.address:peer.port+10001` and sends newline-delimited JSON payloads. The receiver binds the corresponding port and applies the updates.

| Packet type | Contents |
|-------------|----------|
| Incremental | Only changed variables since the last send, per task. Tiny (usually 50–500 bytes). |
| Full | All variables, all timers, all counters, all SFC step indices. Compressed with gzip if `sync.compress: true`. Triggered on startup, on `cluster.node_join` when primary, on `ForceFullSync` REST call, and every `verify_hash_interval` cycles if a hash mismatch is detected. |

Each packet carries a `seq` field (monotonic `uint64`), a task name, and an xxhash of the full state. The receiver uses the hash to verify bit-for-bit agreement every N cycles — if the hash diverges, the receiver requests a full sync on the next cycle. You can see the current sequence and the last observed lag in the status endpoint.

Port math: if your primary is on `8082`, state sync runs on UDP `8082 + 10001 = 18083`. Both nodes need that UDP port open to each other. The heartbeat transport is separate (`datalayer` = UADP multicast on the OPC UA Pub/Sub group; `mqtt` = embedded-broker fan-out).

## 5. ST Functions

Eight builtins let ST code observe and drive the redundancy pair. All return a safe default when failover is disabled or the global manager isn't running, so guard-free usage from ST programs is safe.

### 5.1 Status queries

```iec
VAR
    role      : STRING;
    is_prim   : BOOL;
    peer      : STRING;
    uptime_ms : LINT;
    lag_ms    : LINT;
END_VAR

role      := FAILOVER_ROLE();           (* 'primary', 'standby', 'standalone' *)
is_prim   := FAILOVER_IS_PRIMARY();     (* TRUE if role = 'primary' or 'standalone' *)
peer      := FAILOVER_PEER_STATUS();    (* 'connected', 'disconnected', 'unknown' *)
uptime_ms := FAILOVER_UPTIME_MS();      (* this instance's failover uptime *)
lag_ms    := FAILOVER_SYNC_LAG_MS();    (* how far behind primary this standby is *)
```

`FAILOVER_IS_PRIMARY` returns `TRUE` when the node is either `primary` or `standalone` — the common case of "is this instance the one that should be doing work?" A standby returns `FALSE`; you can use this to gate any side-effecting code that should run only once across the pair:

```iec
IF FAILOVER_IS_PRIMARY() THEN
    (* Send the start command to the VFD only once, not twice *)
    MB_WRITE_REG('plant1', 40001, 1);
END_IF;
```

`FAILOVER_SYNC_LAG_MS` is the standby's observed lag behind the primary. On a healthy LAN pair it sits under 10 ms; a persistent lag of hundreds of milliseconds is a symptom of a saturated network path or a CPU-starved standby.

### 5.2 Role transitions

```iec
(* Manual promotion — typically called from a pushbutton or scheduled test *)
IF manual_switch_button AND NOT was_pressed THEN
    FAILOVER_PROMOTE();
END_IF;
was_pressed := manual_switch_button;

(* Manual demotion — less common, usually for planned maintenance *)
FAILOVER_DEMOTE();

(* Force a full state resync from primary to standby *)
FAILOVER_FORCE_SYNC();
```

`FAILOVER_PROMOTE` returns `TRUE` if the node was not already primary and the transition succeeded. `FAILOVER_DEMOTE` is the reverse. Both log a role-change entry with the reason `"manual: ST program"` and emit `cluster.failover_started` on the bus.

`FAILOVER_FORCE_SYNC` triggers an immediate full state sync from primary to standby. Use it after a deploy or a config reload when you know the interpreter state has diverged and you don't want to wait for the next hash verification cycle. Returns `TRUE` on success, `FALSE` if the sync service isn't running.

## 6. REST API

Six endpoints under `/api/failover/*`.

### 6.1 `GET /api/failover`

```bash
curl http://host:port/api/failover
```

Returns the current status:

```json
{
  "role": "primary",
  "instance_id": "plant1-a",
  "peer_status": "connected",
  "peer_id": "plant1-b",
  "peer_address": "10.0.0.11:8082",
  "sync_lag_ms": 8,
  "last_heartbeat": "2026-04-13T14:22:18Z",
  "uptime_ms": 3621540,
  "sync_sequence": 41256,
  "state_hash_match": true
}
```

- `role` — `primary` / `standby` / `standalone`.
- `peer_status` — `connected` / `disconnected` / `unknown`.
- `sync_lag_ms` — how far behind the standby is (from the primary's perspective, or 0 on the primary itself).
- `sync_sequence` — monotonic counter of sync packets sent/received.
- `state_hash_match` — whether the last hash verification agreed.

### 6.2 `GET /api/failover/history`

```bash
curl http://host:port/api/failover/history
```

Returns up to the last N role-change entries:

```json
[
  {
    "timestamp": "2026-04-13T14:22:18Z",
    "from_role": "standby",
    "to_role": "primary",
    "reason": "peer lost"
  },
  {
    "timestamp": "2026-04-13T09:14:02Z",
    "from_role": "standalone",
    "to_role": "standby",
    "reason": "startup"
  }
]
```

Every `setRole` call adds an entry. The history is in-memory — surviving a restart requires pulling it off the bus audit trail.

### 6.3 Promote / demote / force sync

```bash
# Promote the standby (or standalone) to primary
curl -X POST http://host:port/api/failover/promote

# Demote the primary to standby (for planned maintenance)
curl -X POST http://host:port/api/failover/demote

# Force an immediate full state resync from primary to standby
curl -X POST http://host:port/api/failover/sync

# Snapshot-style sync status
curl http://host:port/api/failover/sync/status
```

All three mutating endpoints emit a bus event (`cluster.failover_started` with a `reason` field). They are subject to the standard auth/RBAC middleware — promote, demote, and force-sync require `engineer` role if RBAC is enabled.

## 7. Event bus integration

Failover state transitions fire bus events that can be routed to Slack, PagerDuty, MQTT, or the WebSocket stream for live HMI banners. Subscribe from the events guide patterns.

| Event type | Severity | Emitted when | Source |
|------------|----------|--------------|--------|
| `cluster.node_join` | info | Heartbeat service first hears a heartbeat from a new peer | `failover` |
| `cluster.node_lost` | warning | Peer heartbeat missed for `interval_ms × timeout_multiplier` | `failover` |
| `cluster.failover_started` | warning | Role transition (auto promotion, manual promote, split-brain demotion) | `failover` |
| `cluster.split_brain_detected` | critical | Both nodes claim primary at reconnection | `failover` |

A typical ops setup routes all four to Slack at `info` and the `split_brain_detected` to PagerDuty at `critical`:

```yaml
events:
  enabled: true
  webhooks:
    - name: "ops-slack"
      url: "https://hooks.slack.com/services/..."
      format: "slack"
      event_types:
        - "cluster.node_join"
        - "cluster.node_lost"
        - "cluster.failover_started"
        - "cluster.split_brain_detected"
      min_severity: "info"

    - name: "pagerduty-critical"
      url: "https://events.pagerduty.com/v2/enqueue"
      format: "pagerduty"
      routing_key: "R0UTINGKEY..."
      event_types: ["cluster.split_brain_detected"]
      min_severity: "critical"
```

The dedup window (default 1 s) collapses a flapping link into one notification per real transition.

## 8. What gets synced (and what doesn't)

`StateExporter` — the interface the task scheduler satisfies for the SyncService — exports and imports:

**Synced:**
- All interpreter variables, across all tasks (via `ExportAllTaskStates` / `ImportTaskVariables`).
- Timer state: running flag, elapsed, preset, Q output (from `TimerState`). Lets TON/TOF/TP instances resume mid-timer with no visible glitch on promotion.
- Counter values (`CTU` / `CTD` / `CTUD` accumulators).
- SFC step indices — which step each state machine is currently in.
- A state hash (xxhash) for verification.

**Not synced:**
- Protocol driver connection state. Open TCP sockets, MQTT subscriptions, ENIP explicit-message sessions — none of these live on the shadow side. The standby opens its own connections on promotion (cold mode) or keeps read-only mirrors (warm mode, when implemented per-driver).
- File descriptors from `FileIO` operations. Any file the primary has open is not visible to the standby.
- HTTP client state from `HTTP_GET` etc. — these are in-flight requests, not persistent state.
- In-memory caches that aren't in the interpreter variable map (e.g., JIT regex caches). Not usually a problem — they rebuild on first use.
- The `GlobalEngine` state for alarms and events. Alarms are reconstructed from config on the new primary; event history lives in the SQLite bus store, which is per-node.

The practical consequence: failover is bumpless for pure control logic but **not** bumpless for I/O-facing subsystems. A VFD driven over Modbus will see the connection drop and a fresh connection ~1 second later. Design interlocks to tolerate this — don't rely on a TCP socket being continuously open across a failover event.

## 9. Recipes

### 9.1 Run once across the pair

The most common pattern: a side-effecting action that must run exactly once even if both nodes are up. Gate on `FAILOVER_IS_PRIMARY`:

```iec
PROGRAM AlertPump
VAR
    pump_fault_bit : BOOL;
    prev_fault     : BOOL;
END_VAR

    IF pump_fault_bit AND NOT prev_fault THEN
        IF FAILOVER_IS_PRIMARY() THEN
            NOTIFY_CRITICAL('Pump fault — manual reset required');
        END_IF;
    END_IF;
    prev_fault := pump_fault_bit;
END_PROGRAM
```

Standby instances evaluate the same ST code (because state sync mirrors variables, including `prev_fault`), but skip the notification. The primary sends exactly one Slack/PagerDuty message per fault rising edge.

### 9.2 Alarm on sync lag drift

`FAILOVER_SYNC_LAG_MS` is a scalar you can alarm on. Create a `HI` alarm with a setpoint of 100 ms and a priority of 2 — if the standby starts lagging, operations gets notified before the lag is bad enough to cause a problem:

```yaml
alarms:
  enabled: true
  definitions:
    - name: "standby_sync_lag"
      tag: "failover_watchdog.lag_ms"
      type: HI
      setpoint: 100.0
      deadband: 20.0
      priority: 2
      delay_ms: 5000
```

```iec
PROGRAM FailoverWatchdog
VAR
    lag_ms : LINT;
END_VAR

    lag_ms := FAILOVER_SYNC_LAG_MS();
END_PROGRAM
```

One ST variable, one alarm definition, one recipe — the operator gets warned before the redundancy pair drifts far enough to matter.

### 9.3 Planned-maintenance demotion

```iec
PROGRAM MaintDemote
VAR
    maint_switch : BOOL;      (* HMI toggle *)
    prev_switch  : BOOL;
END_VAR

    IF maint_switch AND NOT prev_switch THEN
        (* Flip to standby; peer will promote within the heartbeat timeout *)
        FAILOVER_DEMOTE();
    END_IF;
    IF NOT maint_switch AND prev_switch THEN
        (* Done with maintenance — take primary back *)
        FAILOVER_PROMOTE();
    END_IF;
    prev_switch := maint_switch;
END_PROGRAM
```

The `cluster.failover_started` event on both nodes carries the reason `"manual: ST program"`, so you can prove from the audit trail that the demotion was intentional.

### 9.4 Split-brain recovery drill

To rehearse the split-brain detection without a real partition, you can force both nodes to primary manually:

```bash
# On node A
curl -X POST http://nodeA:8082/api/failover/promote

# On node B (simultaneously)
curl -X POST http://nodeB:8082/api/failover/promote
```

Both nodes briefly claim primary; the next heartbeat exchange fires `cluster.split_brain_detected` at `critical` severity, and the priority-based resolver demotes the higher-priority-number node. Watch the bus stream:

```bash
wscat -c 'ws://nodeA:8082/api/events/stream'
# … you'll see cluster.split_brain_detected and then cluster.failover_started …
```

Use this as a smoke test whenever you deploy a new GoPLC version to a redundant pair.

## 10. Performance and scaling

- **Heartbeat transport cost is negligible**: 100 ms × ~200-byte packets = 2 kB/s total, on either the UADP multicast group or the MQTT broker.
- **Incremental sync cost is variable**: 10 ms tick × size of diff. For a 100-variable program with maybe 5 variables changing per scan, expect ~2 kB/s. For a 1,000-variable program with significant churn, expect ~50 kB/s.
- **Full sync cost is one-shot**: at connect, it's the compressed total state. For a typical 1,000-variable project, that's 10–50 kB on the wire.
- **Failover detection latency** is `heartbeat.interval_ms × timeout_multiplier` (default 1 s). Reduce the multiplier to 5 for 500 ms on a gigabit LAN; never go below 3.
- **Promotion latency** is dominated by the `StartTasks` call — typically 10–50 ms on a cold instance. The SyncService's shadow state is already warm, so the new primary's first scan executes with fully-caught-up variables.
- **State sync CPU cost** on the standby is the cost of deserializing the JSON diff and writing back into the interpreter map. Small — expect well under 1% of one core at 10 ms tick rate.
- **Bandwidth is the limiting factor** on high-variable-churn programs. If you're seeing `sync_lag_ms` climb, check the link bandwidth first, then raise `sync.interval_ms`.

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Both nodes stay `standalone` | `enabled: false` on one or both, or `peer.address` empty | Check both configs, ensure `enabled: true` and the peer addresses cross-reference. |
| Failover fires on every small network blip | `timeout_multiplier` too aggressive | Raise to 10 (default) or higher on flaky Wi-Fi. Never lower than 3. |
| `sync_lag_ms` climbs without bound | Bandwidth saturation or CPU-starved standby | Check `iftop`/`nload` on the link, raise `sync.interval_ms` if link is the bottleneck, or move to a faster interconnect. |
| Standby never catches up after reconnect | `full_sync_on_connect: false` and state changes too fast for incremental catch-up | Turn `full_sync_on_connect: true`. |
| `state_hash_match: false` persists | One side has a variable the other doesn't (program version skew) | Redeploy the same project to both nodes. Failover can't reconcile different ST program sets. |
| Split-brain happens on every cold boot | Both nodes auto-elect primary before the first heartbeat exchange | Set `priority` explicitly on each node; don't rely on tiebreakers. |
| Protocol drivers stall for several seconds on failover | `protocols.mode: cold` | Switch to `warm` (where supported) or design ST logic to tolerate the reconnect window. |
| `FAILOVER_PROMOTE` returns `FALSE` from ST | Already primary, or failover manager not initialized | Check `FAILOVER_ROLE()` first; if it returns `standalone`, failover is disabled entirely. |
| Heartbeat events not appearing in the bus log | Heartbeat transport is `mqtt` but events MQTT broker isn't configured | Either switch transport to `datalayer` or configure `events.mqtt.auto_create: true`. |

## 12. Related

- [`goplc_events_guide.md`](goplc_events_guide.md) — the bus that carries `cluster.*` events; webhook and PagerDuty fan-out for failover alarms.
- [`goplc_alarms_guide.md`](goplc_alarms_guide.md) — used in recipe 9.2 to alarm on sync lag drift.
- [`goplc_clustering_guide.md`](goplc_clustering_guide.md) — boss + minion clustering, which is orthogonal to redundancy (can be combined for both scale-out and hot standby).
- [`goplc_api_guide.md`](goplc_api_guide.md) — REST and WebSocket fundamentals.
- [`goplc_debug_guide.md`](goplc_debug_guide.md) — enabling the `failover` debug module to see heartbeat and sync decisions in the log stream.
