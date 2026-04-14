# GoPLC CAN Bus: SocketCAN, CAN FD, J1939, OBD-II, and DBC

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.606

---

GoPLC speaks CAN bus natively on Linux. Open a SocketCAN interface from ST, send and receive classic CAN or CAN FD frames, decode J1939 heavy-duty data and OBD-II passenger-car PIDs with one-line function calls, and load manufacturer DBC files to auto-decode proprietary frames. No external daemons, no Python bridge, no bridge board — a raw AF_CAN socket in pure Go talking directly to the kernel CAN stack.

## 1. Why SocketCAN

GoPLC already had a CAN path: the Teensy CAN bridge (`TEENSY_CAN_*`), which tunnels FlexCAN frames over USB serial. That path is still the right answer when you need hardware-isolated timing, three buses on one board, or you're running GoPLC on a host without a CAN controller. But it has limits:

- USB serial hop adds jitter and a Teensy to the BOM
- Classic CAN only (no CAN FD)
- No kernel-level filtering, no `candump`/`cansend` interop

SocketCAN is the right answer when you're running GoPLC on a Linux SBC with a real CAN controller — an MCP2515 HAT on a Pi, a Waveshare dual-CAN, a BeagleBone DCAN, a BPI-R4, a USB-CAN adapter, or the kernel virtual `vcan` module for bench work. You get:

- Direct kernel access via `AF_CAN` raw sockets (same stack `can-utils` uses)
- CAN FD up to 64-byte payloads and bit-rate switching
- Kernel-level hardware filters (`CAN_RAW_FILTER`) so unwanted frames never cross the userspace boundary
- J1939, OBD-II, and DBC layers built on top
- Coexistence with `candump`, Wireshark, and SocketCAN-aware tools on the same interface

## 2. Architecture

```
┌────────────────────────────────────────────────────────────┐
│                      GoPLC Runtime                         │
│                                                            │
│  ST Code                                                   │
│    ├─ CAN_*       (core frames)                            │
│    ├─ J1939_*     (heavy-duty vehicle, PGN decoder)        │
│    ├─ OBD2_*      (passenger car, ISO 15765)               │
│    └─ DBC_*       (manufacturer database decoder)          │
│             │                                              │
│             ▼                                              │
│   ┌─────────────────────┐                                  │
│   │    CAN Manager      │  Thread-safe interface registry  │
│   │  (go-io/drivers/can)│  with per-interface rx buffers   │
│   └──┬──────┬──────┬────┘                                  │
│      │      │      │                                       │
│      ▼      ▼      ▼                                       │
│   socketcan j1939 dbc                                      │
│   obd2      frame   parser                                 │
│      │                                                     │
└──────┼─────────────────────────────────────────────────────┘
       │  AF_CAN / SOCK_RAW / CAN_RAW
       ▼
┌────────────────────────────────────────────────────────────┐
│                     Linux Kernel CAN Stack                 │
│   ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐           │
│   │  can0  │  │  can1  │  │ vcan0  │  │ slcan0 │           │
│   │MCP2515 │  │  DCAN  │  │virtual │  │USB-CAN │           │
│   └────────┘  └────────┘  └────────┘  └────────┘           │
└────────────────────────────────────────────────────────────┘
```

Every open interface gets its own raw socket, a background goroutine reading frames into a 256-slot buffer, and atomic TX/RX/error counters. `CAN_RAW_RECV_OWN_MSGS` is enabled on every socket so your own transmissions are echoed back — required for `vcan` loopback testing and useful on real buses as a transmit confirmation.

## 3. Kernel Setup

SocketCAN is a kernel feature. The interface must exist and be `UP` before you call `CAN_OPEN` — GoPLC does not run `ip link` for you, and it does not set bit rates. Bring the link up once at boot with `systemd-networkd` or an `/etc/network/interfaces.d/can0` stanza, or issue `ip link` commands by hand during development.

### Bench testing with vcan (no hardware)

```bash
sudo modprobe vcan
sudo ip link add dev vcan0 type vcan
sudo ip link set up vcan0
```

You now have a virtual CAN interface named `vcan0`. Every frame you transmit is delivered back to every listener on `vcan0`, including yourself. Perfect for unit tests and guide walkthroughs.

### MCP2515 HAT on a Raspberry Pi

Add to `/boot/firmware/config.txt` (Bookworm) or `/boot/config.txt` (older):

```
dtparam=spi=on
dtoverlay=mcp2515-can0,oscillator=16000000,interrupt=25
```

Reboot, then:

```bash
sudo ip link set can0 up type can bitrate 500000
ip -s link show can0
```

### USB-CAN adapter (gs_usb family)

Plug it in. The `gs_usb` driver is in-tree on modern Linux:

```bash
sudo ip link set can0 up type can bitrate 500000
```

### Persistent bring-up with systemd-networkd

Create `/etc/systemd/network/80-can0.network`:

```
[Match]
Name=can0

[CAN]
BitRate=500000
RestartSec=100ms
```

`RestartSec` is important: when the controller enters bus-off (too many errors), systemd-networkd will automatically restart it. Without this, a noisy bus will leave the interface down until you manually reset it.

## 4. Core CAN: Open, Send, Receive

The smallest useful program: open `vcan0`, send a frame every second, log everything that arrives.

```iec
PROGRAM can_echo
VAR
    opened       : BOOL;
    counter      : DWORD := 0;
    pending      : DINT;
    frame_json   : STRING;
    tx_ok        : BOOL;
    tick         : TON;
END_VAR

IF NOT opened THEN
    opened := CAN_OPEN('vcan0');
    IF NOT opened THEN
        RETURN; (* interface not up — bring it up with `ip link set up vcan0` *)
    END_IF;
END_IF;

tick(IN := TRUE, PT := T#1S);
IF tick.Q THEN
    tick(IN := FALSE);
    counter := counter + 1;
    (* 8-byte payload, first 4 bytes = counter, last 4 bytes = 0xCAFEBABE *)
    tx_ok := CAN_SEND('vcan0', 16#123, 'DEADBEEFCAFEBABE', 8);
END_IF;

(* Drain the rx buffer every scan *)
pending := CAN_RECV_COUNT('vcan0');
WHILE pending > 0 DO
    frame_json := CAN_RECV('vcan0');
    IF LEN(frame_json) > 0 THEN
        DEBUG('can', CONCAT('rx: ', frame_json));
    END_IF;
    pending := pending - 1;
END_WHILE;
END_PROGRAM
```

A few rules that are easy to miss:

- **Data is hex.** `CAN_SEND` takes the payload as an uppercase hex string, two characters per byte, no separators. `'DEADBEEFCAFEBABE'` is 8 bytes. An odd number of hex characters is rejected.
- **DLC is clamped.** If you pass `dlc=8` but give 4 hex bytes, the driver transmits 4 bytes. You cannot pad a short frame by over-declaring DLC.
- **Extended IDs use `CAN_SEND_EXT`.** Classic 11-bit IDs use `CAN_SEND`. There is no flag — the function you call chooses the frame format.
- **`CAN_RECV` returns a JSON string or the empty string.** Always check `LEN(frame_json) > 0` before parsing. `CAN_RECV_COUNT` tells you how many frames are buffered so you can drain the queue in a bounded loop instead of spinning forever.
- **The buffer is 256 frames per interface.** On a busy bus, drain it every scan or set filters to drop what you don't care about.

### Kernel filters

`CAN_SET_FILTER` installs a hardware-level accept filter. The kernel drops non-matching frames before they reach the socket, so a tight filter is essentially free. Masks are the standard CAN match: a frame passes when `(frame.id & mask) == (filter.id & mask)`.

```iec
(* Accept only IDs 0x100 through 0x10F *)
CAN_SET_FILTER('can0', 16#100, 16#7F0);

(* Accept exactly one ID *)
CAN_SET_FILTER('can0', 16#123, 16#7FF);

(* Wide open — receive everything *)
CAN_CLEAR_FILTERS('can0');
```

Filters are cumulative: each `CAN_SET_FILTER` call adds another accept rule. `CAN_CLEAR_FILTERS` removes all of them and returns the interface to the default "accept everything" state.

## 5. CAN FD

CAN FD ("Flexible Data Rate") allows payloads up to 64 bytes and an optional higher data-phase bit rate. Use it when you need more bandwidth per frame and your hardware supports it — MCP2515 does not; MCP2518FD does.

```iec
VAR
    opened : BOOL;
    tx_ok  : BOOL;
END_VAR

opened := CAN_OPEN_FD('can0');

(* 32-byte payload, BRS=TRUE switches to the faster data-phase bit rate *)
tx_ok := CAN_SEND_FD('can0', 16#200,
    '00112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDDEEFF',
    TRUE);
```

`CAN_OPEN_FD` will fail if the kernel or controller doesn't support CAN FD. You can still send classic 8-byte frames on an FD-enabled socket with `CAN_SEND`, and received classic frames will still arrive on the rx channel — CAN FD is strictly additive.

The data-phase bit rate is set on the kernel interface when you bring the link up, not from ST:

```bash
sudo ip link set can0 up type can bitrate 500000 dbitrate 2000000 fd on
```

## 6. J1939 (Heavy Duty Vehicles)

J1939 is the SAE standard used on commercial trucks, agricultural equipment, construction machinery, and marine engines. Frames use 29-bit extended IDs encoding a Parameter Group Number (PGN), source address, and priority. GoPLC's J1939 layer caches the last received value for every PGN and exposes both raw access and convenience getters for common signals.

### Convenience getters

```iec
VAR
    rpm          : REAL;
    speed_kmh    : REAL;
    coolant_c    : REAL;
    fuel_lph     : REAL;
    engine_hours : REAL;
END_VAR

CAN_OPEN('can0');

rpm          := J1939_ENGINE_RPM('can0');    (* PGN 61444 / EEC1 / SPN 190 *)
speed_kmh    := J1939_VEHICLE_SPEED('can0'); (* PGN 65265 / CCVS1 / SPN 84 *)
coolant_c    := J1939_COOLANT_TEMP('can0');  (* PGN 65262 / ET1 / SPN 110 *)
fuel_lph     := J1939_FUEL_RATE('can0');     (* PGN 65266 / LFE1 / SPN 183 *)
engine_hours := J1939_ENGINE_HOURS('can0');  (* PGN 65253 / HOURS / SPN 247 *)
```

Each of these returns the last decoded value for that SPN. If no frame has been received yet, you get `0.0` — there is no "unknown" sentinel, so gate your logic on a freshness flag if you need to distinguish "really zero" from "never heard".

### Raw PGN access

For any PGN not covered by a convenience getter, use `J1939_READ_PGN`. It returns the raw payload of the last received frame for that PGN as a JSON string, or `""` if nothing has been received.

```iec
VAR
    pgn_data : STRING;
    ok       : BOOL;
END_VAR

(* PGN 65266 (LFE1) — Fuel Economy *)
pgn_data := J1939_READ_PGN('can0', 16#FEF2);

(* Send a PGN request (broadcast to source address 255) *)
ok := J1939_REQUEST_PGN('can0', 16#FEEC, 255);

(* Transmit a custom PGN *)
ok := J1939_SEND_PGN('can0', 16#FF00, 255, '0102030405060708');
```

`J1939_SEND_PGN` handles the 29-bit ID assembly and priority bits for you — you give it a PGN, destination address, and hex data, and it transmits the frame with priority 6 (the J1939 default).

## 7. OBD-II (Passenger Cars)

OBD-II is the diagnostic protocol on every passenger car sold since 1996 (US) or 2001 (EU). It rides on CAN via ISO 15765-4 using 11-bit IDs `0x7DF` (broadcast request) and `0x7E8`–`0x7EF` (ECU responses). GoPLC exposes the standard Mode 01 live data PIDs as convenience functions and a generic `OBD2_READ_PID` for anything else.

```iec
VAR
    rpm         : REAL;
    speed_kmh   : REAL;
    coolant_c   : REAL;
    throttle_pc : REAL;
    fuel_pc     : REAL;
    maf_gs      : REAL;
    (* Generic PID access for anything not in the convenience list *)
    iat_c       : REAL;
END_VAR

CAN_OPEN('can0');

rpm         := OBD2_RPM('can0');          (* Mode 01, PID 0x0C *)
speed_kmh   := OBD2_SPEED('can0');        (* Mode 01, PID 0x0D *)
coolant_c   := OBD2_COOLANT_TEMP('can0'); (* Mode 01, PID 0x05 *)
throttle_pc := OBD2_THROTTLE('can0');     (* Mode 01, PID 0x11 *)
fuel_pc     := OBD2_FUEL_LEVEL('can0');   (* Mode 01, PID 0x2F *)
maf_gs      := OBD2_MAF('can0');          (* Mode 01, PID 0x10 *)

(* Intake air temperature — Mode 01, PID 0x0F, no convenience wrapper *)
iat_c := OBD2_READ_PID('can0', 16#01, 16#0F);
```

All values are returned pre-scaled into engineering units per the SAE J1979 formulas — RPM in rev/min, speed in km/h, temperatures in °C, percentages as 0.0 to 100.0, MAF in g/s. `OBD2_READ_PID` returns the raw numeric result; you apply the PID-specific scaling yourself. Check an OBD-II PID reference (e.g. Wikipedia's "OBD-II PIDs") for the formulas.

**Note**: OBD-II on CAN requires the vehicle's ECU to be powered (key on, engine off is enough). Some cars time out the CAN gateway after 30–60 seconds of bus silence — keep polling or the gateway will stop answering until a genuine scan tool pokes it.

## 8. DBC Files

DBC (Database CAN) files are the Vector Informatik file format for describing CAN messages: IDs, signal names, bit positions, byte order, scaling, offset, and units. Every vehicle manufacturer publishes internal DBCs for their engineering tools; many are public (the OpenDBC project has hundreds). Loading a DBC lets you read named signals instead of parsing raw bytes.

```iec
VAR
    loaded     : BOOL;
    msgs_json  : STRING;
    latest     : STRING;
    engine_rpm : REAL;
    coolant    : REAL;
END_VAR

CAN_OPEN('can0');

(* Load a DBC file from the FileIO sandbox (data/ directory by default) *)
loaded := DBC_LOAD('vehicle', 'data/vehicle.dbc');

(* List every message defined in the DBC as a JSON array *)
msgs_json := DBC_LIST_MESSAGES('vehicle');

(* Decode the most recently received frame against the DBC and
   return every signal as a JSON object *)
latest := DBC_DECODE('vehicle', 'can0');

(* Pull one signal value by name — returns the latest decoded value
   for a signal we've been tracking on this interface *)
engine_rpm := DBC_GET_SIGNAL('vehicle', 'can0', 'EngineSpeed');
coolant    := DBC_GET_SIGNAL('vehicle', 'can0', 'CoolantTemp');

(* When done *)
DBC_UNLOAD('vehicle');
```

The `name` argument is a local handle — you pick it when you load the DBC and use it to refer to the loaded database in later calls. You can load multiple DBCs (one per bus, for example) as long as the handles are unique.

DBC files are read from the FileIO sandbox. By default the sandbox root is the `data/` directory next to your project file, so `DBC_LOAD('vehicle', 'data/vehicle.dbc')` works if the file is at `data/vehicle.dbc`. Absolute paths outside the sandbox are rejected.

## 9. ST Function Reference

All 32 functions verified against the live function registry at GoPLC v1.0.606.

### Core CAN

| Function | Purpose |
|---|---|
| `CAN_OPEN(interface: STRING) : BOOL` | Open a SocketCAN interface in classic CAN mode |
| `CAN_OPEN_FD(interface: STRING) : BOOL` | Open in CAN FD mode (up to 64-byte payloads) |
| `CAN_CLOSE(interface: STRING) : BOOL` | Close an open interface and release its socket |
| `CAN_STATUS(interface: STRING) : STRING` | JSON with state, TX/RX counts, error counts |
| `CAN_LIST() : STRING` | JSON array of every CAN/VCAN interface visible to the kernel |
| `CAN_SET_FILTER(interface: STRING, id: DWORD, mask: DWORD) : BOOL` | Add a kernel-level accept filter |
| `CAN_CLEAR_FILTERS(interface: STRING) : BOOL` | Remove all filters (receive everything) |
| `CAN_SEND(interface: STRING, id: DWORD, data: STRING, dlc: DINT) : BOOL` | Send classic 11-bit frame, hex payload |
| `CAN_SEND_EXT(interface: STRING, id: DWORD, data: STRING, dlc: DINT) : BOOL` | Send classic 29-bit extended frame |
| `CAN_SEND_FD(interface: STRING, id: DWORD, data: STRING, brs: BOOL) : BOOL` | Send CAN FD frame, optional bit-rate switch |
| `CAN_RECV(interface: STRING) : STRING` | Pop one frame off the rx buffer as JSON, or "" |
| `CAN_RECV_COUNT(interface: STRING) : DINT` | Number of frames buffered, waiting to be popped |

### J1939

| Function | Purpose |
|---|---|
| `J1939_READ_PGN(interface: STRING, pgn: DWORD) : STRING` | Last received payload for this PGN as JSON |
| `J1939_SEND_PGN(interface: STRING, pgn: DWORD, dest: DINT, data: STRING) : BOOL` | Transmit a PGN, hex data |
| `J1939_REQUEST_PGN(interface: STRING, pgn: DWORD, dest: DINT) : BOOL` | Request a PGN from another node |
| `J1939_ENGINE_RPM(interface: STRING) : REAL` | Engine RPM from EEC1 / PGN 61444 |
| `J1939_VEHICLE_SPEED(interface: STRING) : REAL` | Ground speed from CCVS1 / PGN 65265 |
| `J1939_COOLANT_TEMP(interface: STRING) : REAL` | Coolant temperature from ET1 / PGN 65262 |
| `J1939_FUEL_RATE(interface: STRING) : REAL` | Fuel rate from LFE1 / PGN 65266 |
| `J1939_ENGINE_HOURS(interface: STRING) : REAL` | Total engine hours from HOURS / PGN 65253 |

### OBD-II

| Function | Purpose |
|---|---|
| `OBD2_READ_PID(interface: STRING, mode: DINT, pid: DINT) : REAL` | Generic OBD-II PID read, returns raw numeric value |
| `OBD2_RPM(interface: STRING) : REAL` | Engine RPM (PID 0x0C) |
| `OBD2_SPEED(interface: STRING) : REAL` | Vehicle speed in km/h (PID 0x0D) |
| `OBD2_COOLANT_TEMP(interface: STRING) : REAL` | Coolant temp in °C (PID 0x05) |
| `OBD2_THROTTLE(interface: STRING) : REAL` | Throttle position 0–100 % (PID 0x11) |
| `OBD2_FUEL_LEVEL(interface: STRING) : REAL` | Fuel level 0–100 % (PID 0x2F) |
| `OBD2_MAF(interface: STRING) : REAL` | Mass air flow in g/s (PID 0x10) |

### DBC

| Function | Purpose |
|---|---|
| `DBC_LOAD(name: STRING, file_path: STRING) : BOOL` | Load a DBC file under a handle |
| `DBC_UNLOAD(name: STRING) : BOOL` | Drop a loaded DBC |
| `DBC_LIST_MESSAGES(name: STRING) : STRING` | JSON array of every message in the DBC |
| `DBC_DECODE(name: STRING, interface: STRING) : STRING` | Decode the latest frame on this bus against the DBC |
| `DBC_GET_SIGNAL(name: STRING, interface: STRING, signal_name: STRING) : REAL` | Latest value of one named signal |

## 10. REST API

Six endpoints for managing CAN interfaces without touching ST. Useful for one-shot testing from `curl`, or for integrating GoPLC CAN state into Grafana or Node-RED. All endpoints require authentication when RBAC is enabled — obtain a JWT via `POST /api/auth/login` and pass it as `Authorization: Bearer <token>`.

### List visible and open interfaces

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/can
```

```json
{
  "interfaces": ["can0", "vcan0"],
  "open": [
    {"name":"vcan0","fd":false,"tx_frames":42,"rx_frames":42,"tx_errors":0,"rx_errors":0}
  ]
}
```

`interfaces` is every CAN/VCAN device the kernel knows about (open or not). `open` is stats for everything this GoPLC process has actually opened.

### Per-interface stats

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/can/vcan0
```

### Open an interface (optional CAN FD)

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"fd":false}' \
     http://localhost:8082/api/can/vcan0/open
```

An empty body opens in classic CAN mode. `{"fd":true}` enables CAN FD.

### Close an interface

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/can/vcan0/close
```

### Send a frame

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"id":291,"data":"DEADBEEF","extended":false}' \
     http://localhost:8082/api/can/vcan0/send
```

`id` is the CAN arbitration ID (decimal or JSON hex literal). `data` is an uppercase hex string; spaces are allowed for readability. `extended=true` selects the 29-bit frame format. Response:

```json
{"sent":true,"id":291,"dlc":4,"fd":false}
```

### Read buffered frames

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/can/vcan0/recv
```

Returns up to 10 buffered frames in a single response. Each frame contains `id`, `data`, `dlc`, `extended`, `fd`, and `timestamp`. The same frames are removed from the buffer — calling `/recv` twice does not return the same frames twice.

## 11. Hardware Options

| Hardware | Interface | Notes |
|---|---|---|
| `vcan` kernel module | Virtual | Free, no hardware, full loopback — perfect for tests |
| MCP2515 HAT (Raspberry Pi) | SPI → 1x CAN 2.0 | ~$10. Classic CAN only |
| Waveshare 2-CH CAN HAT | SPI → 2x CAN 2.0, isolated | Dual bus, opto-isolated inputs |
| MCP2518FD HAT | SPI → 1x CAN FD | ~$25. Actually supports CAN FD |
| BeagleBone Black DCAN | Native 2x CAN 2.0 | In-SoC CAN controllers, no add-on |
| Banana Pi BPI-R4 | Native CAN | Built into the router SoC |
| Gs_usb adapters (CANable, Innomaker USB2CAN) | USB → CAN | ~$20–40. Plug-and-play on modern Linux |
| Kvaser Leaf | USB → CAN | Commercial-grade, reliable kernel driver |
| Copperhill Triple CAN Teensy 4.1 | USB serial → 3x CAN (2x classic + 1x FD) | Use the TEENSY_CAN_* path, not SocketCAN |

## 12. Gotchas

**Interface must be UP before `CAN_OPEN`.** GoPLC does not bring links up; it fails cleanly if the kernel device is `DOWN`. Check with `ip -s link show can0`. On `vcan`, the `modprobe` + `ip link add` + `ip link set up` sequence is all three commands, not just the first two.

**Bus-off recovery is a kernel concern.** When a CAN controller accumulates too many transmit errors it enters bus-off and stops. By default SocketCAN leaves it bus-off until someone brings the link down and back up. `RestartSec=100ms` in a systemd-networkd `.network` file tells the kernel to auto-reset. Without it, a single noisy burst can take your bus out until the next reboot.

**Classic and FD mix on an FD socket.** Opening with `CAN_OPEN_FD` does not stop you from sending classic frames with `CAN_SEND`, and classic frames from other nodes still arrive on the rx channel. FD is purely additive. But the kernel and controller both have to actually support FD — on an MCP2515 you'll get an error the moment you try.

**`CAN_SEND` is synchronous, `CAN_RECV` is non-blocking.** Send blocks briefly while the kernel enqueues the frame (microseconds on a clear bus, milliseconds on a saturated one). Receive returns immediately with the empty string when the buffer is empty — there is no blocking wait. Use `CAN_RECV_COUNT` to avoid tight-looping on an empty bus.

**The rx buffer is 256 frames.** On a 500 kbps bus running at capacity you can receive ~8000 frames per second, which fills a 256-slot buffer in 32 ms. If your scan time is longer than that, add kernel filters to drop uninteresting IDs before they reach the buffer.

**DBC files are sandboxed.** Passing an absolute path like `/etc/vehicle.dbc` to `DBC_LOAD` is rejected. Put the file under `data/` (the FileIO sandbox root) and reference it with a relative path. This is consistent with `FILE_READ` and every other file-touching ST function.

**`CAN_RAW_RECV_OWN_MSGS` is on.** Every frame you send is echoed back to your own rx buffer. This is what makes `vcan` loopback tests work. On a real bus, you see your own transmissions alongside peer traffic — filter them out yourself if you don't want them, typically by comparing the source address (J1939) or by tracking what you just sent.

**Protocol events ride the webhook pipeline.** CAN bus state changes emit `protocol.connect`, `protocol.disconnect`, `protocol.reconnect`, and `protocol.error` events that flow through the same webhook/MQTT/Slack routes as every other driver. Subscribe to `protocol.*` in your event config to get CAN-level alerts for free.

## 13. Putting It All Together: Truck Dashboard

A complete program that reads J1939 vitals from a heavy-duty truck, writes them into ST variables, and emits a status event when the engine coolant exceeds a threshold. Pair this with the Historian guide to log everything to InfluxDB, or with the HMI builder to render a live dashboard.

```iec
PROGRAM truck_dashboard
VAR
    opened        : BOOL;
    rpm           : REAL;
    speed         : REAL;
    coolant_c     : REAL;
    fuel_lph      : REAL;
    hours         : REAL;
    coolant_high  : BOOL;
    last_coolant  : BOOL;
    event_json    : STRING;
    err           : STRING;
END_VAR

IF NOT opened THEN
    opened := CAN_OPEN('can0');
    IF NOT opened THEN
        err := CAN_STATUS('can0');
        RETURN;
    END_IF;
END_IF;

rpm       := J1939_ENGINE_RPM('can0');
speed     := J1939_VEHICLE_SPEED('can0');
coolant_c := J1939_COOLANT_TEMP('can0');
fuel_lph  := J1939_FUEL_RATE('can0');
hours     := J1939_ENGINE_HOURS('can0');

coolant_high := coolant_c > 100.0;

(* Edge-trigger the alert so we don't spam the event bus every scan *)
IF coolant_high AND NOT last_coolant THEN
    event_json := CONCAT('{"coolant_c":', REAL_TO_STRING(coolant_c));
    event_json := CONCAT(event_json, ',"rpm":');
    event_json := CONCAT(event_json, REAL_TO_STRING(rpm));
    event_json := CONCAT(event_json, '}');
    EVENT_EMIT('protocol.error', 'can0', event_json);
END_IF;
last_coolant := coolant_high;

END_PROGRAM
```

Things worth noting in the pattern:

- `CAN_OPEN` is called once, guarded by `opened`. Re-opening an already-open interface is not an error, but there's no reason to.
- Every J1939 getter returns the last cached value — no blocking, no round-trip to the bus. Your scan time stays flat regardless of bus traffic.
- The coolant alert is edge-triggered (`coolant_high AND NOT last_coolant`). Without this, you'd emit a `protocol.error` event every scan the coolant is high, which would pin the event bus and fill your webhook logs.
- `CAN_STATUS` returns a JSON string — stash it into `err` on open failure so you can see it in the Live Variables panel without adding a breakpoint.

## 14. What's Next

SocketCAN is production-ready today — classic CAN, CAN FD, J1939, OBD-II, and DBC decoding all ride on a single kernel socket per bus. Bolt it onto the existing features:

- **Historian** → archive every J1939 SPN at 1 Hz to InfluxDB with deadband compression
- **Alarms** → ISA-18.2 state machine on top of `coolant_c > 100.0`, with shelving and auto-ack
- **Events** → `protocol.*` events fan out to Slack/PagerDuty/MQTT via the webhook pipeline
- **HMI builder** → live gauges for RPM, speed, coolant, fuel rate
- **Node-RED** → feed decoded frames into dashboards, rule flows, or cloud backends

For a working end-to-end example, see the Historian and Events guides in this directory.
