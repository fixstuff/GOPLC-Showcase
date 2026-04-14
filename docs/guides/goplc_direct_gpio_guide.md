# GoPLC Direct GPIO: Imperative Pin Access for Quick Prototyping

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.608

---

GoPLC has two completely separate paths for reading and writing hardware pins on a Linux SBC:

1. **The HAL manifest path** (covered in the HAL guide). Declarative: you write a YAML hardware manifest, the HAL layer maps physical pins to standard IEC 61131-3 addresses (`%IX0.0`, `%QX0.0`), and ST code reads and writes those addresses on every scan. This is the right answer for production logic on a known hardware build.

2. **The direct GPIO path** (this guide). Imperative: you call `GPIO_READ(17)` and `GPIO_WRITE(27, TRUE)` directly from ST code. No manifest, no address mapping, no poll loop — just open a pin, read or write it, move on. This is the right answer for prototyping, diagnostics, one-off utility scripts, and anything where you don't want to ship a config file change to blink an LED.

Both paths run through the same `periph.io` hardware abstraction underneath, so you can't have both simultaneously driving the same pin (the direct path auto-excludes any pin the HAL manifest already claims). But they coexist cleanly on different pins of the same board.

## 1. When to Use It

**Direct GPIO is for:**

- Blinking an LED during first bring-up, before you've written a HAL manifest
- Running `i2cdetect`-style bus scans from ST or curl to find devices
- Reading a dry-contact input from an ad-hoc sensor during commissioning
- Building a one-off utility task (watchdog relay, door latch trigger, test fixture)
- Letting an operator toggle pins from the IDE's REST console without rewriting a project file

**Direct GPIO is NOT for:**

- Production logic that needs to execute on a deterministic scan (use the HAL path — the direct path is a per-call operation with no scan guarantee)
- High-speed edge capture (still call for a P2 or Teensy bridge)
- PWM, pull-resistor control with dynamic switching, or analog — these weren't part of the shipped surface, only digital I/O and I2C scan

**The rule of thumb**: if you find yourself declaring variables and writing stable logic around direct GPIO calls, you should probably move those pins into a HAL manifest. The direct path is imperative by design and stays out of your scan image — that's its strength for prototyping and its weakness for anything production-shaped.

## 2. What Ships Today

Small surface on purpose — this subsystem is digital I/O plus I2C scan, nothing more.

| Capability | Shipped |
|---|---|
| Digital input (read) | ✅ |
| Digital output (write) | ✅ |
| Digital output toggle | ✅ |
| Mode change (input ↔ output) | ✅ |
| Pin list / platform identification | ✅ |
| I2C device scan | ✅ |
| REST control | ✅ (5 endpoints) |
| HAL conflict rejection | ✅ (pins in HAL manifest are auto-excluded) |
| PWM | ❌ (use P2 or BeagleBone DCAN) |
| Pull-up/down at runtime | ❌ (set once in YAML) |
| SPI | ❌ |
| ADC / analog | ❌ |
| I2C read/write (beyond scan) | ❌ (use a HAL device plugin) |

The spec at `docs/spec/DIRECT_GPIO.md` documents the larger roadmap (PWM, SPI, ADC, I2C read/write, named ADC devices). None of that is registered in the live runtime today — this guide covers only the shipped surface.

## 3. Enable It

Direct GPIO is **off by default**. You turn it on in `config.yaml`:

```yaml
gpio:
  enabled: true
  allowed_pins: [4, 17, 18, 22, 23, 24, 25, 27]   # BCM pin numbers
  default_pull: "up"                               # "up", "down", or "none"
```

Three keys and nothing else:

| Key | Type | Purpose |
|---|---|---|
| `enabled` | bool | Master switch. Even with `enabled: false` the `/api/system/platform` endpoint still works as a diagnostic. |
| `allowed_pins` | list of int | BCM pin numbers that ST and REST may touch. Pins already claimed by a HAL device plugin are auto-removed from this list at startup — HAL wins. An empty list disables every pin operation (the `I2C_SCAN` diagnostic still works). |
| `default_pull` | string | Pull-resistor applied when a pin is configured as input without an explicit override. `"up"` is the safest default for dry-contact switches. |

If a project doesn't mention `gpio:` at all, direct GPIO is disabled, the ST functions all return `FALSE`/empty, and the REST endpoints return `503 Service Unavailable`. This is deliberate — the subsystem should only be live when you opted into it.

## 4. Permissions

`periph.io` uses `/sys/class/gpio` and `/dev/gpiochipN` on modern kernels. The running process needs to be in the `gpio` group (and `i2c` for `I2C_SCAN`):

```bash
sudo usermod -aG gpio,i2c goplc
```

On a typical Raspberry Pi OS install, those groups already exist and the `pi` user is already in them. On minimal distros (Alpine, Arch ARM, Yocto) you may need to `groupadd` them yourself and add a udev rule:

```bash
echo 'SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"' \
     | sudo tee /etc/udev/rules.d/60-gpio.rules
sudo udevadm control --reload
```

If GoPLC can't open a pin, the relevant ST function returns `FALSE` and the error is logged with the `hal` tag. The HAL device lifecycle events (`hal.device_error`) fire through the event bus, so webhook subscribers catch permission problems without you having to tail the log.

## 5. ST Functions

All seven functions verified against the live registry at v1.0.608.

| Function | Purpose |
|---|---|
| `GPIO_PLATFORM() : STRING` | Short platform identifier: `"Raspberry Pi 4"`, `"Orange Pi 5"`, `"generic"`, or `"not_available"` |
| `GPIO_LIST() : STRING` | JSON array of every pin in the effective allowlist with mode and last value |
| `GPIO_MODE(pin: DINT, mode: STRING) : BOOL` | Reconfigure a pin — `"input"` or `"output"` |
| `GPIO_READ(pin: DINT) : BOOL` | Read a digital pin. Configures it as input on first use if not already configured. |
| `GPIO_WRITE(pin: DINT, value: BOOL) : BOOL` | Write a digital pin. Configures it as output on first use. |
| `GPIO_TOGGLE(pin: DINT) : BOOL` | Flip an output pin and return the new state. Uses an internal shadow register so toggles work even though `/sys/class/gpio` output pins don't read back. |
| `I2C_SCAN(bus: DINT) : STRING` | Probe every 7-bit address on the given I2C bus and return a JSON array of responders — equivalent to `i2cdetect -r -y <bus>` |

Every function is bounds-checked against `allowed_pins` — a call on an unconfigured pin returns `FALSE` (for the BOOL-returning ones) or an empty JSON object/array (for the STRING-returning ones), and logs an error to the `hal` tag.

### Walkthrough: blink an LED on BCM17

```iec
PROGRAM led_blink
VAR
    led_pin  : DINT := 17;
    state    : BOOL;
    tick     : TON;
END_VAR

tick(IN := TRUE, PT := T#500ms);
IF tick.Q THEN
    tick(IN := FALSE);
    state := NOT state;
    GPIO_WRITE(led_pin, state);
END_IF;
END_PROGRAM
```

That's the whole program. On the first `GPIO_WRITE` call, pin 17 gets configured as output automatically. The TON retriggers every 500 ms and flips the state. With `config.yaml` enabling `gpio.enabled: true` and `allowed_pins: [17]`, this program will blink an LED on BCM17 the moment you deploy it — no manifest, no address map, no scan image entry.

### Walkthrough: read a dry contact on BCM22

```iec
PROGRAM door_sensor
VAR
    sensor_pin : DINT := 22;
    closed     : BOOL;
    opened     : BOOL;
    event_msg  : STRING;
END_VAR

closed := NOT GPIO_READ(sensor_pin);   (* dry contact pulls to GND when closed *)
IF closed AND NOT opened THEN
    opened := TRUE;
    event_msg := 'door closed';
    EVENT_EMIT('hal.device_up', 'door', event_msg);
ELSIF NOT closed AND opened THEN
    opened := FALSE;
    event_msg := 'door open';
    EVENT_EMIT('hal.device_down', 'door', event_msg);
END_IF;
END_PROGRAM
```

Edge-triggered so the event bus only sees state transitions, not a fresh event on every scan. With `default_pull: "up"` in the config, the pin idles high and reads low when the contact closes — no external pull-up needed.

### Walkthrough: bus scan

```iec
PROGRAM i2c_discovery
VAR
    devices : STRING;
    started : BOOL;
END_VAR

IF NOT started THEN
    devices := I2C_SCAN(1);    (* JSON: ["0x08","0x20","0x48"] *)
    DEBUG('i2c', CONCAT('bus 1 devices: ', devices));
    started := TRUE;
END_IF;
END_PROGRAM
```

Runs once, prints the scan result to the debug log, done. Use this during hardware bring-up to confirm that a new I2C device is talking. Bus 1 is the default Raspberry Pi I2C bus (`/dev/i2c-1`); BeagleBone and Orange Pi number their buses differently — check with `ls /dev/i2c-*`.

## 6. REST API

Five endpoints — same surface available from `curl`, `httpie`, or the IDE's built-in REST console. All require authentication when RBAC is enabled.

### List every pin and its state

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/gpio
```

```json
{
  "enabled": true,
  "available": true,
  "platform": "Raspberry Pi 4",
  "pins": [
    {"pin": 17, "mode": "output", "value": true},
    {"pin": 22, "mode": "input",  "value": false},
    {"pin": 27, "mode": "output", "value": false}
  ]
}
```

`available` is `true` when the process can actually open GPIO devices (right user, right kernel, right SBC). On a desktop without a GPIO bank it's `false` and the pin list is empty.

### Read one pin

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/gpio/17
```

```json
{"pin": 17, "value": true}
```

### Write or reconfigure one pin

```bash
# Configure as output and write high
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"mode":"output","value":true}' \
     http://localhost:8082/api/gpio/17

# Just toggle whatever it currently is
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"toggle":true}' \
     http://localhost:8082/api/gpio/17

# Reconfigure as input, don't write
curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"mode":"input"}' \
     http://localhost:8082/api/gpio/22
```

The body must include at least one of `mode`, `value`, or `toggle`. Send any combination — `{"mode":"output","value":true}` configures then writes in one call.

### Platform identification

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/system/platform
```

```json
{"platform": "Raspberry Pi 4", "available": true}
```

This endpoint works even when `gpio.enabled` is `false` — it's a diagnostic probe that tells you what kind of board the runtime is on, independent of whether you've authorized GPIO access.

### I2C bus scan

```bash
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8082/api/i2c/scan/1
```

```json
{"bus": 1, "count": 3, "addresses": ["0x08", "0x20", "0x48"]}
```

Scans every 7-bit address on `/dev/i2c-1` and returns the ones that ACK'd. `count` is the number of devices detected. If the bus can't be opened (permission, wrong bus number, driver not loaded) you get a `400` with an error message.

## 7. Interaction with the HAL Manifest

The one rule: **a pin can only be owned by one path**. If you list pin 17 in a HAL manifest device and also in `gpio.allowed_pins`, the direct path loses — pin 17 is removed from the effective allowlist at startup, and `GPIO_READ(17)` returns `FALSE`. This prevents the HAL poll loop and a direct write from fighting over the same hardware.

A startup log line tells you exactly what was excluded:

```
[INF] [direct-gpio] effective allowlist: [22 27] (HAL claimed: [17 18 23 24 25])
[INF] [direct-gpio] platform=Raspberry Pi 4 default_pull=up
```

If you actually want to move a pin from HAL control to direct control, remove it from the HAL manifest and reload the project — GoPLC doesn't let you hot-swap ownership mid-scan.

## 8. Events

The direct GPIO subsystem emits events through the same bus as every other driver:

| Event | When |
|---|---|
| `hal.device_up` | Platform detected and allowlist applied at startup |
| `hal.device_down` | Subsystem disabled or pin allowlist emptied |
| `hal.device_error` | Pin open/read/write failure (permissions, bad pin, pull mismatch) |

Subscribe to `hal.*` in your event subscription config to route GPIO hardware faults into Slack, PagerDuty, or MQTT via the webhook pipeline — same path as Modbus driver faults, CAN bus-off events, and UPS power-loss warnings. See the Events guide for the subscription syntax.

## 9. Gotchas

**BCM numbering, not physical header pins.** `GPIO_READ(17)` means BCM17 — which is physical pin 11 on a Raspberry Pi 40-pin header. If you pass `11` you get BCM11 (physical pin 23) instead. Keep a BCM-to-physical chart near your desk during bring-up.

**Output read-back uses a shadow register.** `/sys/class/gpio` does not let you read back the state of a pin configured as output. The direct GPIO manager maintains an internal shadow so `GPIO_TOGGLE` works correctly — it flips the shadow and writes the new value. If something outside GoPLC (another process, a physical contention) overrides the pin, the shadow will lie about the current state until your next `GPIO_WRITE`.

**`GPIO_MODE` is not required.** The first `GPIO_READ` or `GPIO_WRITE` on a pin auto-configures it (input for read, output for write). `GPIO_MODE` is only needed when you want to change direction mid-program — which is rare and usually a sign that you should be in the HAL manifest path instead.

**I2C_SCAN touches every address.** A full 7-bit scan probes 112 addresses (0x03–0x77, skipping reserved ranges). On a healthy bus this finishes in under 50 ms. On a bus with a badly-behaved device that latches up on stray probes, it can cause that device to wedge — unplug it before scanning, or scan a narrower range with an I2C tool first if you're worried.

**`default_pull` is set at runtime from config, not ST.** There is no `GPIO_PULL(pin, pull)` function today — if you want pin 22 to have pull-down and pin 23 to have pull-up, you set `default_pull: "up"` globally and handle the exception in hardware. This is a deliberate scope limit; runtime-variable pull will require either a config extension or a new ST function.

**`config.yaml` changes need a reload.** Adding a pin to `allowed_pins` doesn't take effect until you reload the project or restart the runtime. The subsystem's allowlist is computed once at startup from the combination of config and HAL claims.

## 10. Putting It Together

A minimal Pi 4 config that enables direct GPIO on three pins and nothing else:

```yaml
gpio:
  enabled: true
  allowed_pins: [17, 22, 27]
  default_pull: "up"
```

A minimal ST program that exercises all three: blink an output, read an input, pulse a relay when the input closes:

```iec
PROGRAM pin_demo
VAR
    led       : DINT := 17;
    input_pin : DINT := 22;
    relay     : DINT := 27;
    pressed   : BOOL;
    last_in   : BOOL;
    tick      : TON;
    pulse     : TP;
END_VAR

(* Heartbeat LED — flips every 500 ms *)
tick(IN := TRUE, PT := T#500ms);
IF tick.Q THEN
    tick(IN := FALSE);
    GPIO_TOGGLE(led);
END_IF;

(* Pulse the relay when the input transitions low-to-high *)
pressed := GPIO_READ(input_pin);
pulse(IN := pressed AND NOT last_in, PT := T#250ms);
GPIO_WRITE(relay, pulse.Q);
last_in := pressed;
END_PROGRAM
```

Deploy it, go to `http://localhost:8082/ide/`, open the Live Variables panel, and you'll see `pressed` flip in real time as you short pin 22 to ground. The relay on pin 27 fires for exactly 250 ms on each low-to-high transition.

For config-driven pin access at scan speed with deterministic update cadence, see the HAL guide. For hardware-accelerated GPIO and sub-millisecond edge capture, see the P2 or Teensy guides. This guide is the smallest path that gets you from "is my board alive" to "I'm toggling a real pin" in under ten lines of ST.
