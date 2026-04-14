# GoPLC System: Hardware Watchdog, Crash-Safe RETAIN, and UPS Monitoring

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.607

---

A PLC runtime is supposed to keep running. Not "until the kernel hangs", not "unless someone pulls the power", not "unless a task deadlocks" — always. GoPLC's system layer is the set of mechanisms that make that promise credible on bare metal: a hardware watchdog that resets the board if the Go runtime ever stops scheduling, a RETAIN persistence path that survives abrupt power loss without corrupting files, and a UPS monitor that initiates graceful shutdown before the battery drops below the reserve you specified. All three can be configured from `config.yaml`, inspected from ST, and audited from the REST API.

## 1. Why This Exists

A PLC is not a desktop application. It runs on a board wedged into a control cabinet, sometimes in a closet the facility forgot about, and it's expected to still be scanning when someone pulls out an OS image from 2029 and asks "what does this do?". There are three failure modes that kill a naive Go service in that environment:

1. **Silent livelock.** The process is alive and the port is open, but a goroutine is spinning or a lock is held and no task has executed a scan in the last 60 seconds. Nothing external notices until a production line trips.
2. **Power cut mid-write.** RETAIN is meant to survive reboots. If it's saved to a plain JSON file and the power cuts between `write()` and `fsync()`, the file is now half a file, and the next boot loses every retained variable for that task.
3. **Soft-shutdown timing.** A UPS can keep the board alive for ten minutes, but only if something knows to initiate a clean shutdown with enough runway for the final RETAIN flush.

The features in this guide address each one directly — hardware watchdog for #1, atomic-write RETAIN with rolling backups for #2, and a NUT/apcupsd-driven UPS monitor for #3.

## 2. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     GoPLC Runtime                       │
│                                                         │
│  Main loop ──► kicks /dev/watchdog every 5s             │
│                (configurable)                           │
│                                                         │
│  Per-task RETAIN ──► flush every 1s if dirty            │
│                      atomic write (tmp+fsync+rename)    │
│                      rolling .retain.bak.1 / .bak.2     │
│                                                         │
│  UPS poller ──► reads NUT or apcupsd every 5s           │
│                 emits power.on_battery when AC drops    │
│                 emits power.low_battery below threshold │
│                 triggers SYS_SHUTDOWN on low battery    │
│                                                         │
│  Shutdown chain ──► stop accepting new tasks            │
│                     run final flush on every task       │
│                     magic-close the hardware watchdog   │
│                     journal sync                        │
│                     exit(0)                             │
└─────────────────────────────────────────────────────────┘
            │                    │                  │
            ▼                    ▼                  ▼
      /dev/watchdog       data/*.retain       /var/state/ups
       (ioctl + heartbeat)   (atomic)          (NUT socket)
```

Every layer in that diagram is driven from the same event bus that powers the historian, the alarm engine, and the webhook router. A power loss on the UPS does not trigger a shutdown directly — it emits `power.on_battery`, which the RETAIN store subscribes to and reacts to by forcing an immediate flush on every dirty task. The alarm engine subscribes to the same event and annunciates a "system on battery" alarm. The webhook router fans the event out to Slack or PagerDuty. That's why the three components live in one guide: they share a bus and they compose.

## 3. Hardware Watchdog

The Linux kernel exposes `/dev/watchdog`. When you open it, the kernel starts a countdown timer. If the timer expires before you write anything to the device, the kernel forces a hardware reset — not a panic, not a kernel oops, a full CPU reset. Kick the device (write any byte) and the timer resets. Close the device cleanly with the magic character `V` and the timer is disarmed.

GoPLC's watchdog goroutine opens the device at startup, kicks it on the configured interval (default every 5 seconds), and magic-closes it on clean shutdown so the system doesn't reboot during a software update.

### Enable it

```yaml
watchdog:
  hardware:
    enabled: true
    device: "/dev/watchdog"     # default
    timeout_s: 15               # hardware reboots if not kicked for 15s
    kick_interval_ms: 5000      # kick every 5s (well inside the 15s window)
```

### Permissions

`/dev/watchdog` is root-owned by default. The two clean options are:

```bash
# Option A: add the goplc user to the watchdog group
sudo groupadd -f watchdog
sudo chown root:watchdog /dev/watchdog
sudo chmod 660 /dev/watchdog
sudo usermod -aG watchdog goplc

# Option B: udev rule to group-own the device on every boot
echo 'KERNEL=="watchdog", GROUP="watchdog", MODE="0660"' \
     | sudo tee /etc/udev/rules.d/60-watchdog.rules
sudo udevadm control --reload
```

If GoPLC fails to open the device it logs `watchdog: open /dev/watchdog: permission denied` and continues without hardware watchdog support — the task watchdog still runs, and `SYS_WATCHDOG_STATUS()` returns `"not_available"`.

### Verifying it works

The safest way to verify the hardware watchdog is to let it actually fire on a test board:

```bash
# Start GoPLC with hardware watchdog enabled
# Then freeze the process with SIGSTOP and watch the board reboot ~15s later
kill -STOP $(pgrep goplc)
```

On the reboot log you should see your bootloader come back. If the board keeps running, the watchdog is not wired through to the reset line — common on cheap virtual machines and some Pi clones. On real MCP2515 / DCAN / industrial SBCs this always works.

## 4. Systemd Integration

Once the hardware watchdog is open, the next layer is systemd itself. Type=notify + `WatchdogSec=30` gives you two things for free:

1. **Ready notification.** Systemd considers the service "started" only after GoPLC calls `sd_notify(READY=1)`. Anything `After=goplc.service` can be ordered correctly.
2. **Software watchdog.** Systemd expects a `WATCHDOG=1` heartbeat every `WatchdogSec / 2`. If GoPLC stops sending them, systemd kills the process and (via `Restart=on-failure`) relaunches it. This is the second line of defense below the kernel watchdog.

### Enable it in config

```yaml
watchdog:
  systemd:
    notify: true
    watchdog_usec: 30000000   # 30 seconds
```

### Service file

```ini
# /etc/systemd/system/goplc.service
[Unit]
Description=GOPLC IEC 61131-3 PLC Runtime
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WatchdogSec=30
ExecStart=/opt/goplc/goplc /opt/goplc/project.goplc --api-port 8082
WorkingDirectory=/opt/goplc
Restart=on-failure
RestartSec=5

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/goplc/data /opt/goplc/projects

StandardOutput=journal
StandardError=journal
SyslogIdentifier=goplc

[Install]
WantedBy=multi-user.target
```

Install and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now goplc
sudo systemctl status goplc
```

You should see `Status: "Ready"` once GoPLC calls `sd_notify(READY=1)`. If the status sticks on `Status: "Starting..."` the notify call didn't fire — check your config and rebuild against a recent enough release.

## 5. Crash-Safe RETAIN

RETAIN variables keep their value across restarts. In the default configuration, GoPLC's RETAIN store writes to `projects/<project>.<task>.retain` using a three-step atomic write:

1. Write the new JSON to `<file>.tmp`
2. `fsync()` the temporary file
3. `rename()` the temporary file over the real file

On ext4/btrfs/xfs, step 3 is atomic at the filesystem level — either the old file is visible or the new file is visible, never a half-written mix. Combined with periodic fsync and rolling backups, this gives you three lines of defense against power loss:

```yaml
retain:
  flush_interval_ms: 1000   # flush every 1s if any variable has changed
  atomic_write: true        # tmp + fsync + rename (default true)
  backup_count: 2           # keep .retain.bak.1 and .retain.bak.2 as fallbacks
```

On a dirty assignment the store marks the task as dirty and resets a timer. When the timer fires, the store flushes everything in one pass. Between flushes, assignments cost a map write and nothing else — no disk I/O per scan.

### Backups and recovery

With `backup_count: 2` you get `project.task.retain`, `project.task.retain.bak.1`, and `project.task.retain.bak.2`. On a successful flush, `bak.1` gets renamed to `bak.2`, the current file gets copied to `bak.1`, and then the new data is written atomically. If the primary file is corrupt on load, the store falls back to the most recent backup and logs a warning. You can clean up old `.bak.*` files safely — they're not referenced beyond the next flush.

### Forcing a flush from ST

Any event that happens faster than the flush interval deserves an explicit flush: edge-triggered alarms, one-shot setpoint changes, commissioning sequences. Use `SYS_RETAIN_FLUSH()` to force an immediate save across every dirty task.

```iec
PROGRAM commissioning
VAR
    new_setpoint : REAL;
    applied      : BOOL;
    retain_ok    : BOOL;
END_VAR

IF NOT applied AND new_setpoint > 0.0 THEN
    (* apply the setpoint, then force it to disk before we acknowledge *)
    applied := TRUE;
    retain_ok := SYS_RETAIN_FLUSH();
    IF NOT retain_ok THEN
        DEBUG('commissioning', 'retain flush failed');
    END_IF;
END_IF;
END_PROGRAM
```

### Inspecting RETAIN state

From the REST API, `GET /api/system/retain` returns a JSON object with one entry per task:

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/system/retain
```

```json
{
  "tasks": [
    {
      "name": "MainTask",
      "path": "projects/ABTest_good.MainTask.retain",
      "size_bytes": 1248,
      "dirty": false,
      "last_save_unix": 1712943210,
      "backup_count": 2
    }
  ]
}
```

`POST /api/system/retain/flush` forces an immediate save across every task — useful before a maintenance restart or as a health check.

## 6. UPS Monitoring

GoPLC supports two UPS backends: **NUT** (Network UPS Tools — the standard Linux UPS stack) and **apcupsd** (APC's own daemon, still widely used on APC-only installations). Either one polls the UPS hardware over USB or serial and makes battery state available via a Unix socket. GoPLC reads that state every 5 seconds.

### NUT setup

```bash
sudo apt install nut nut-client nut-server
# configure /etc/nut/ups.conf, /etc/nut/upsd.conf, /etc/nut/upsd.users
sudo upsdrvctl start
sudo systemctl enable --now nut-server
upsc ups@localhost   # confirm the UPS is visible
```

### GoPLC config

```yaml
power:
  ups_enabled: true
  ups_type: "nut"                    # or "apc" for apcupsd
  ups_name: "ups@localhost"
  shutdown_on_battery_pct: 20        # initiate shutdown below 20 %
  shutdown_delay_s: 30               # wait 30s on battery first (ignore brownouts)
```

### What happens on AC loss

1. UPS poller detects `ups.status: OB` (on battery) and emits `power.on_battery` on the event bus.
2. The RETAIN store subscribes to `power.on_battery` and forces an immediate flush on every dirty task. You get a crash-safe snapshot within milliseconds of the power going away.
3. The alarm engine subscribes to the same event and annunciates `power.on_battery` as a priority-1 alarm.
4. The webhook router fans the event out to Slack / PagerDuty / MQTT, subject to your event subscription config.
5. If AC comes back within `shutdown_delay_s`, the poller emits `power.on_ac` and life continues. If AC stays out and the battery drops below `shutdown_on_battery_pct`, the poller emits `power.low_battery` and calls `SYS_SHUTDOWN("battery_low")` internally.

`SYS_SHUTDOWN` runs the same clean-shutdown chain as a SIGTERM: stop accepting new tasks, run final flush on every task, magic-close the hardware watchdog, journal sync, exit.

### Reading UPS state from ST

```iec
PROGRAM power_watch
VAR
    ups_state  : STRING;
    battery_pc : REAL;
    runtime_s  : DINT;
    on_battery : BOOL;
END_VAR

ups_state := SYS_UPS_STATUS();    (* "online" | "on_battery" | "low_battery" | "not_available" *)
battery_pc := SYS_UPS_CHARGE();   (* 0.0 to 100.0 *)
runtime_s  := SYS_UPS_RUNTIME_S(); (* seconds of estimated runtime remaining *)

on_battery := ups_state = 'on_battery' OR ups_state = 'low_battery';

IF on_battery THEN
    (* shed non-essential loads, preserve critical state *)
    DEBUG('power', CONCAT('on battery, charge=', REAL_TO_STRING(battery_pc)));
END_IF;
END_PROGRAM
```

## 7. Graceful Shutdown

The `SYS_SHUTDOWN(reason)` ST function, the `POST /api/system/shutdown` REST endpoint, a `SIGTERM`, and the UPS low-battery path all converge on the same shutdown chain:

```
Receive shutdown request
   │
   ▼
Stop accepting new task starts
   │
   ▼
Stop every running task (SaveRetain on each)
   │
   ▼
Final FlushAllRetain() across every task
   │
   ▼
Close protocol drivers (Modbus, MQTT, OPC UA, CAN, ...)
   │
   ▼
Magic-close the hardware watchdog (so the kernel does not reboot)
   │
   ▼
Journal sync + event bus drain
   │
   ▼
exit(0)
```

Every stage is idempotent and has a 5-second timeout so one wedged driver can't block the whole chain. The shutdown reason is propagated to `runtime.stop` on the event bus so your historian logs it alongside the final snapshot.

To trigger a clean shutdown from outside:

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"confirm":true}' \
     http://localhost:8082/api/system/shutdown
```

From inside ST:

```iec
VAR
    need_shutdown : BOOL;
    ok            : BOOL;
END_VAR

IF need_shutdown THEN
    ok := SYS_SHUTDOWN('planned_maintenance');
END_IF;
```

The reason string shows up in the journal, the `runtime.stop` event payload, and the audit trail if RBAC is enabled.

## 8. ST Function Reference

All functions verified against the live GoPLC function registry at v1.0.607.

### Watchdog

| Function | Purpose |
|---|---|
| `SYS_WATCHDOG_KICK() : BOOL` | Manual kick — normally the runtime kicks automatically every `kick_interval_ms` |
| `SYS_WATCHDOG_STATUS() : STRING` | `"active"`, `"disabled"`, or `"not_available"` |

### RETAIN

| Function | Purpose |
|---|---|
| `SYS_RETAIN_FLUSH() : BOOL` | Force immediate save across every dirty task |
| `SYS_RETAIN_STATUS() : STRING` | JSON: per-task last save time, size, dirty flag, backup count |

### UPS / Power

| Function | Purpose |
|---|---|
| `SYS_UPS_STATUS() : STRING` | `"online"`, `"on_battery"`, `"low_battery"`, or `"not_available"` |
| `SYS_UPS_CHARGE() : REAL` | Battery percentage, 0.0 to 100.0 |
| `SYS_UPS_RUNTIME_S() : DINT` | Estimated seconds of runtime remaining on battery |

### Shutdown and lifecycle

| Function | Purpose |
|---|---|
| `SYS_SHUTDOWN(reason: STRING) : BOOL` | Begin the graceful shutdown chain with a reason string |
| `SYS_EXIT(exit_code: INT) : BOOL` | Immediate process exit, skipping the shutdown chain — use only for tests |
| `SYS_CLEAR_ERRORS() : BOOL` | Clear the runtime error counter visible in `CAN_STATUS` and similar |

## 9. REST API

| Endpoint | Purpose |
|---|---|
| `GET /api/system/watchdog` | Hardware + systemd watchdog status |
| `GET /api/system/retain` | Per-task RETAIN status (path, size, dirty, last save) |
| `POST /api/system/retain/flush` | Force immediate flush on every task |
| `GET /api/system/power` | UPS status, charge percentage, runtime estimate |
| `POST /api/system/shutdown` | Graceful shutdown — requires `{"confirm":true}` body |

All endpoints require authentication when RBAC is enabled. Example:

```bash
TOKEN=$(curl -sX POST http://localhost:8082/api/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"username":"goplc","password":"goplc"}' \
    | jq -r .token)

curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/system/watchdog
```

```json
{
  "hardware": {
    "status": "active",
    "device": "/dev/watchdog",
    "timeout_s": 15
  },
  "systemd": {
    "status": "active"
  }
}
```

## 10. Full YAML Reference

```yaml
watchdog:
  hardware:
    enabled: true                # open /dev/watchdog at startup
    device: "/dev/watchdog"      # default
    timeout_s: 15                # kernel reset after 15s of no kicks
    kick_interval_ms: 5000       # kick every 5 seconds
  systemd:
    notify: true                 # call sd_notify(READY=1) + WATCHDOG=1
    watchdog_usec: 30000000      # 30s systemd software watchdog

retain:
  flush_interval_ms: 1000        # periodic flush if dirty (default 1s)
  atomic_write: true             # tmp + fsync + rename (default true)
  backup_count: 2                # rolling .retain.bak.N count

power:
  ups_enabled: true
  ups_type: "nut"                # "nut" or "apc"
  ups_name: "ups@localhost"
  shutdown_on_battery_pct: 20    # shutdown below 20 % battery
  shutdown_delay_s: 30           # wait 30s on battery before shutdown
```

Every key has a sensible default — you can omit the whole `watchdog:` section and still have task-level software watchdog, or omit `power:` and not run a UPS monitor. The `retain:` section defaults to crash-safe (`atomic_write: true`, `flush_interval_ms: 1000`, `backup_count: 2`), so even projects that never mention retain are durable.

## 11. Gotchas

**`/dev/watchdog` needs real hardware.** A lot of virtual machines expose `/dev/watchdog` but wire it to nothing — you can open, kick, and close it all day and the VM never resets. Test by actually stopping the process with `SIGSTOP` on the real target. If the board comes back, the watchdog is real. If it just sits there, you're on a soft-watchdog VM and you need systemd's `Restart=on-failure` as your fallback.

**Magic-close is mandatory.** If the runtime exits without writing `V` to `/dev/watchdog`, the kernel will reboot the board `timeout_s` seconds later — even if the exit was clean. GoPLC always magic-closes on SIGTERM/SIGINT/panic-recovery, but if you kill the process with `SIGKILL -9`, you skipped the shutdown chain and the watchdog will fire. Use `systemctl stop goplc` (SIGTERM) not `kill -9`.

**RETAIN files are per-task.** The filename pattern is `projects/<project>.<task>.retain`. If you rename a task, the old RETAIN file is orphaned — GoPLC does not migrate it for you. Copy the file or export/import RETAIN values explicitly via the API before renaming.

**Atomic-write needs an ext-family filesystem.** On ext4/btrfs/xfs, `rename()` is atomic. On FAT32/exFAT (common on SD-card-only SBCs and Windows), rename semantics are weaker and power loss during rename can leave both files or neither. Use ext4 wherever you can, and if you're stuck on FAT, bump `backup_count` to 3 so you have more fallbacks.

**NUT vs apcupsd talks to the same UPS differently.** You cannot run both daemons against one UPS — they fight for the HID / serial handle. Pick one. NUT is the more general choice (supports most brands and has better packaging on Debian/Ubuntu). apcupsd is the easier one if you have an APC-only environment and don't want to touch the NUT config files.

**`SYS_SHUTDOWN` is a one-way door.** There is no `SYS_CANCEL_SHUTDOWN`. Once the chain starts, tasks are stopped and the process is going down. If you want a "are you sure?" gate, build it in ST and call `SYS_SHUTDOWN` only after the gate passes.

**UPS polling is every 5 seconds.** A very short power blip (under 5s) will not emit `power.on_battery`. This is a feature: brownouts would otherwise trigger false alarms and constant RETAIN flushes. If your power quality is bad enough that you care about sub-5s events, instrument the power path with a GPIO brownout detector and emit your own events.

**`shutdown_delay_s` is the brownout guard.** On AC loss, GoPLC waits this many seconds before beginning the shutdown chain. That gives short outages time to resolve and avoids unnecessary restarts, but it also means you need at least `shutdown_delay_s + 30` seconds of battery runway to finish cleanly. Size your UPS accordingly.

## 12. Putting It Together

A production `config.yaml` fragment for a Pi 4 running GoPLC with a USB-attached APC UPS, a working hardware watchdog, and crash-safe RETAIN:

```yaml
watchdog:
  hardware:
    enabled: true
    device: "/dev/watchdog"
    timeout_s: 15
    kick_interval_ms: 5000
  systemd:
    notify: true
    watchdog_usec: 30000000

retain:
  flush_interval_ms: 500       # tighter than default — small project, fast disk
  atomic_write: true
  backup_count: 3              # extra backup in case the SD card acts up

power:
  ups_enabled: true
  ups_type: "nut"
  ups_name: "apc@localhost"
  shutdown_on_battery_pct: 25  # slightly conservative
  shutdown_delay_s: 20         # short brownout guard
```

Combine this with the systemd service from §4, the udev rule for `/dev/watchdog` from §3, and a properly configured NUT from §6, and you have a runtime that can take a power cut mid-scan and come back with every RETAIN value intact.

For the full event picture — how `power.on_battery`, `runtime.start`, and `runtime.stop` flow to MQTT, Slack, and the historian — see the Events and Historian guides in this directory.
