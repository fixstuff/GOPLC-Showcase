# GoPLC + Parallax Propeller 1: Hardware Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.594

---

GoPLC treats the Parallax Propeller 1 as a schema-driven smart-I/O module: plug a Propeller Project Board or a SimplyTronics Activity Board into a USB port, call `P1_INIT` from your ST program, and thirty-two builtins drive GPIO, SPI, UART, I2C, PWM, servos, encoders, frequency counters, and HC-SR04-style pulse measurement. Firmware is embedded in the GoPLC binary and uploaded automatically over the ROM bootloader on first connect; you do not run any Spin toolchain yourself. The P1 counterpart to the existing P2 guide: same calling pattern (binary protocol + convenience wrappers over a shared `P1_CMD` dispatcher), same health-tracked acyclic mode, fewer pins and fewer cogs but a dramatically smaller form factor and lower power draw for embedded edge jobs.

## 1. Architecture Overview

Like the P2 guide, the P1 is **not** a compilation target. GoPLC does not generate Spin. Instead, a ~6 KB cyclic-I/O firmware is embedded in the GoPLC binary, uploaded to the P1 over the ROM bootloader at `P1_INIT`, and then driven via a schema-described binary protocol over the USB-serial link.

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/macOS/Windows host)   │
│                                                     │
│  ┌────────────────────────────────────────────────┐ │
│  │ ST Program                                     │ │
│  │                                                │ │
│  │ P1_INIT('p1', port)                            │ │
│  │ P1_PIN_MODE('p1', 10, 1)                       │ │
│  │ P1_PIN_WRITE('p1', 10, 1)                      │ │
│  │ dist := P1_PULSE_MEASURE('p1', 10, 11, 60000)  │ │
│  └───────────────────┬────────────────────────────┘ │
│                      │ binary frames                │
│                      │ (115200 baud, packed struct) │
└──────────────────────┼───────────────────────────────┘
                       │
                       │  USB Serial (FTDI / CP210x / CH34x)
                       ▼
┌─────────────────────────────────────────────────────┐
│  Parallax Propeller 1 (8 cogs, 32-bit, 80 MHz)      │
│                                                     │
│  Embedded firmware (p1_cyclic_io.binary, ~6 KB)     │
│                                                     │
│  Cog 0: Frame dispatch                              │
│  Cog N: UART TX/RX helpers                          │
│  Cog N: PWM / servo interpolation                   │
│  Cog N: Quadrature/step encoder                     │
│                                                     │
│  32 GPIO pins (P0..P31), 3.3 V, 40 mA sink/source   │
└─────────────────────────────────────────────────────┘
```

Two points worth internalizing before you write any P1 code:

1. **The P1 is shared state.** Pin 10 set to output from one ST program stays an output until another call changes it. There is no "end of scan" reset. Treat the P1 like a hardware register bank, not a stateless RPC endpoint.
2. **The protocol is acyclic.** Each `P1_*` call is a discrete command-response round trip over the USB link. There is no cyclic mode, no telegram watchdog, no deterministic timing guarantee. Commands return in a few hundred microseconds on a quiet link; blocking commands (`P1_FREQ_READ`, `P1_PULSE_MEASURE`, `P1_UART_RECV`) block for their specified duration on purpose.

## 2. Hardware and wiring

| Board | Vendor | MCU | Notes |
|-------|--------|-----|-------|
| Propeller Project Board USB (#32810) | Parallax | P8X32A-Q44 | Full-size breadboard layout, onboard VGA/audio headers. Identify string usually contains "Parallax" or "FTDI". |
| Activity Board | SimplyTronics | P8X32A-Q44 | Wide ecosystem of edge add-ons. Identify string usually contains "SimplyTronics". |
| Propeller FLiP | Parallax | P8X32A-Q44 | DIP-style, breadboardable. |
| Any custom P1 with a USB-serial bridge (FT232, CP2102, CH340) | — | P8X32A | GoPLC drives any board that boots over the standard ROM LFSR + 3BP protocol. |

All P1 pins (P0–P31) are 3.3 V logic. The ROM bootloader lives at the same reset sequence on every board — GoPLC handles the 3BP handshake transparently via the `go-p1` package.

**USB port selection**: combine `SERIAL_FIND` with `P1_INIT` so you never hard-code `/dev/ttyUSB0`. `SERIAL_FIND` searches system USB device descriptors for a substring match on the product or manufacturer string:

```iec
VAR
    p1_port : STRING;
    p1_ok   : BOOL;
END_VAR

p1_port := SERIAL_FIND('SimplyTronics');  (* or 'Parallax', 'FT232', etc. *)
IF p1_port <> '' THEN
    p1_ok := P1_INIT('p1', p1_port);
END_IF;
```

This pattern survives a USB port reshuffle on reboot — the device shows up on a different `/dev/ttyUSB*` but the identify string still matches.

## 3. Connection, Firmware, Health

Three functions own the lifecycle. Every other P1 builtin assumes the device is connected and healthy and returns a zero-equivalent value (`FALSE`, `0`, `''`) if it isn't.

### 3.1 `P1_INIT(name, port [, firmware_path]) : BOOL`

```iec
(* Typical form — use embedded firmware, let GoPLC pick the default *)
ok := P1_INIT('p1', '/dev/ttyUSB0');

(* With an explicit firmware path override *)
ok := P1_INIT('p1', '/dev/ttyUSB0', '/opt/custom/p1_cyclic_io.binary');
```

Returns `TRUE` when the device is connected and the firmware is running. **Safe to call every scan** — if the named device is already open and healthy, `P1_INIT` is a no-op and returns `TRUE` immediately. If the device was previously healthy and has now gone dark (USB unplug, power cycle, firmware crash), `P1_INIT` tears down the old transport and re-opens on the supplied port. You can therefore put a plain `P1_INIT('p1', port)` at the top of every scan and let it self-heal.

The third argument is optional. Omit it and GoPLC extracts the embedded firmware (`p1_cyclic_io.binary`) into the working directory and uses that. Pass a path to override — the only time you would is during firmware development.

On a fresh (uninitialized) board the first `P1_INIT` takes ~1.5 seconds for the 3BP upload. Subsequent re-inits (after a USB replug) take ~200 ms because the host-side state is already warm.

### 3.2 `P1_HEALTHY(name) : BOOL`

```iec
IF NOT P1_HEALTHY('p1') THEN
    (* Skip this scan — device is unreachable *)
    RETURN;
END_IF;
```

Returns `TRUE` if the device is open and recent command-response exchanges have succeeded. The health flag flips to `FALSE` after N consecutive command failures (the underlying `go-p1` device tracks this), and GoPLC emits a single `protocol.disconnect` bus event on the transition — one event per disconnect, not per scan. When `P1_INIT` subsequently succeeds, GoPLC emits `protocol.connect`.

Use `P1_HEALTHY` at the top of any program that touches the device. Every `P1_*` convenience function already returns `FALSE`/`0`/`''` when the device is unhealthy, but checking once up front with a `RETURN` keeps the scan short and the error handling obvious.

### 3.3 `P1_STATUS(name) : STRING` and `P1_CLOSE(name) : BOOL`

```iec
VAR
    info : STRING;
END_VAR

info := P1_STATUS('p1');
(* {"name":"p1","port":"/dev/ttyUSB0","connected":true,"mode":"acyclic","ping_us":382} *)

(* Teardown — only if you really need to release the USB handle *)
P1_CLOSE('p1');
```

`P1_STATUS` pings the device and returns a JSON document with the device name, port, connection state, mode (always `"acyclic"` on P1), and round-trip ping time in microseconds. The ping itself walks the same protocol path as any other command, so the reported time is representative of actual command latency.

You rarely need `P1_CLOSE`. The Go-side context closes all P1 devices automatically at runtime shutdown. Call it only if you need to hand the USB port to another program mid-run.

## 4. Generic command dispatcher: `P1_CMD`

Every P1 function is a thin wrapper around `P1_CMD`, which is the schema-driven generic dispatcher. Use it directly when a convenience function doesn't exist for a command you need, or when you want a command's raw JSON response:

```iec
(* Two calling styles, equivalent *)

(* 1. JSON parameter string *)
resp := P1_CMD('p1', 'pin_write', '{"pin":16,"value":1}');

(* 2. Key-value pairs (GoPLC assembles the JSON) *)
resp := P1_CMD('p1', 'pin_write', 'pin', 16, 'value', 1);

(* Query the firmware version *)
ver_json := P1_CMD('p1', 'version');    (* {"fw_version":1,"hw_type":1,"num_pins":32,"num_spi":1} *)
```

`P1_CMD` returns the full JSON response string. Empty string means the call failed — the device is unhealthy, the command is unknown, the pack/unpack errored, or the firmware returned `CMD_ERROR`. Failures are logged at the `debug` level under the `p1` module; none of them error out the scan.

Available firmware commands (all 27, exposed by the embedded schema):

| Category | Commands |
|----------|----------|
| Core | `ping`, `version` |
| GPIO | `pin_mode`, `pin_read`, `pin_write` |
| SPI | `spi_setup`, `spi_xfer`, `spi_stop` |
| UART | `uart_setup`, `uart_tx`, `uart_rx`, `uart_stop` |
| I2C | `i2c_setup`, `i2c_xfer`, `i2c_stop` |
| PWM | `pwm_setup`, `pwm_duty`, `pwm_stop` |
| Servo | `servo_move`, `servo_stop` |
| Frequency counter | `freq_setup`, `freq_read` |
| Pulse measure | `pulse_measure` |
| Encoder | `enc_setup`, `enc_read`, `enc_reset`, `enc_rev` |

Everything else in this guide is a convenience wrapper that calls into one of these.

## 5. GPIO

The P1 has 32 GPIO pins numbered `P0..P31`. All pins are independently configurable input/output; there is no pin-group I/O register exposed through the binary protocol. For bulk operations, loop over pins in your ST code — the USB-serial round trip dominates latency, not your loop.

### 5.1 `P1_PIN_MODE(name, pin, mode) : BOOL`

```iec
P1_PIN_MODE('p1', 10, 1);   (* P10 = output *)
P1_PIN_MODE('p1', 11, 0);   (* P11 = input  *)
```

`mode`: `0` = input, `1` = output. Returns `TRUE` on success.

### 5.2 `P1_PIN_READ(name, pin) : DINT`

```iec
VAR
    button : DINT;
END_VAR

button := P1_PIN_READ('p1', 11);
IF button = 1 THEN
    button_pressed := TRUE;
END_IF;
```

Returns `0` or `1`. A pin that is not configured as input returns whatever the last output state was; configure the pin as an input first.

### 5.3 `P1_PIN_WRITE(name, pin, value) : BOOL`

```iec
P1_PIN_WRITE('p1', 10, 1);  (* Drive P10 high *)
P1_PIN_WRITE('p1', 10, 0);  (* Drive P10 low  *)
```

### 5.4 `P1_PIN_TOGGLE(name, pin) : BOOL`

```iec
(* Heartbeat blink *)
IF blink_timer.Q THEN
    P1_PIN_TOGGLE('p1', 10);
    blink_timer(IN := FALSE);
END_IF;
blink_timer(IN := TRUE, PT := T#500MS);
```

Reads the current state and writes the opposite. Two USB round trips per call.

## 6. PWM and Servos

The P1's CTRA/CTRB counters drive PWM and servo pulse trains. GoPLC's firmware exposes a single PWM channel (using CTRA in DUTY mode) plus a two-channel servo driver.

### 6.1 PWM

```iec
P1_PWM_SETUP('p1', 16);          (* Claim P16 for PWM, starts at 0% duty *)
P1_PWM_DUTY('p1', 16, 128);      (* 50% duty *)
P1_PWM_DUTY('p1', 16, 64);       (* 25% duty *)
P1_PWM_STOP('p1', 16);           (* Release the pin *)
```

- `P1_PWM_SETUP(name, pin) : BOOL` — Claims the pin. Duty starts at 0.
- `P1_PWM_DUTY(name, pin, duty_0_255) : BOOL` — Sets the duty cycle. Out-of-range values are clamped (0 → 0, 256+ → 255).
- `P1_PWM_STOP(name, pin) : BOOL` — Releases the pin back to idle input.

PWM frequency is fixed by the firmware (not runtime-configurable on P1 — the CTRA DUTY mode is implicitly driven by the system clock). If you need a specific frequency, use the Propeller 2 instead, which exposes smart-pin frequency control.

### 6.2 Servos

```iec
(* Two-channel servo — channels 0 and 1 *)
P1_SERVO_MOVE('p1', 0, 14, 1500);    (* Center *)
P1_SERVO_MOVE('p1', 0, 14, 1000);    (* Full left   *)
P1_SERVO_MOVE('p1', 1, 15, 2000);    (* Full right  *)
P1_SERVO_STOP('p1', 0);
```

- `P1_SERVO_MOVE(name, ch, pin, us) : BOOL` — `ch` is 0 or 1 (two independent servo slots). `pin` binds the channel to a GPIO. `us` is the servo pulse width in microseconds (typical range 500–2500, center at 1500). Values are clamped to `[0, 2500]`.
- `P1_SERVO_STOP(name, ch) : BOOL` — Stops the channel and releases the pin.

The servo ISR runs on its own cog inside the firmware, so servo pulse output is stable at jitter-free microsecond resolution regardless of your ST scan rate.

## 7. SPI, UART, I2C

Standard three-wire peripherals. Each setup claims pins; stopping releases them.

### 7.1 SPI

```iec
(* SPI channel 0 on clk=0, mosi=1, miso=2, cs=3, 1000 kHz, mode 0 *)
P1_SPI_SETUP('p1', 0, 0, 1, 2, 3, 1000, 0);

(* Transfer: flags=0, data is a hex string *)
rx_hex := P1_SPI_XFER('p1', 0, 0, '01020304');   (* write 4 bytes, read 4 *)

P1_SPI_STOP('p1', 0);
```

- `P1_SPI_SETUP(name, ch, clk, mosi, miso, cs, speed_khz, mode) : BOOL` — Eight positional args. `ch` is 0 (only one SPI channel on P1). `mode` is 0–3 (CPOL/CPHA per standard SPI mode table).
- `P1_SPI_XFER(name, ch, flags, hex_data) : STRING` — `hex_data` is a hex string (two chars per byte, no prefix). Returns a hex string of equal length containing the received bytes. Max transfer is 64 bytes per call (firmware framing limit).
- `P1_SPI_STOP(name, ch) : BOOL`

### 7.2 UART

```iec
(* UART on tx_pin=20, rx_pin=21, 9600 baud *)
P1_UART_SETUP('p1', 20, 21, 9600);

(* Send ASCII "HELLO" as hex *)
count := P1_UART_SEND('p1', '48454c4c4f');

(* Receive up to 64 bytes with a 200 ms timeout *)
rx := P1_UART_RECV('p1', 64, 200);

P1_UART_STOP('p1');
```

- `P1_UART_SETUP(name, tx_pin, rx_pin, baud) : BOOL`
- `P1_UART_SEND(name, hex_data) : DINT` — Returns bytes sent. Data is a hex string. To send ASCII, convert with `STRING_TO_HEX` or build the hex inline.
- `P1_UART_RECV(name, max_len, timeout_ms) : STRING` — Blocks for up to `timeout_ms`, returns a hex string of received bytes (empty string on timeout with no data).
- `P1_UART_STOP(name) : BOOL`

The P1 has one hardware UART in this firmware build — you cannot have two independent UARTs active simultaneously. For multi-port serial, use the P2.

### 7.3 I2C

```iec
(* I2C on scl=28, sda=29, 100 kHz *)
P1_I2C_SETUP('p1', 28, 29, 100);

(* Read register 0x00 from BH1750 at 0x23 *)
rx := P1_I2C_XFER('p1', 16#23, '00', 2);       (* write 0x00, read 2 bytes *)

P1_I2C_STOP('p1');
```

- `P1_I2C_SETUP(name, scl_pin, sda_pin, speed_khz) : BOOL`
- `P1_I2C_XFER(name, addr_7bit, write_hex, read_len) : STRING` — 7-bit address (no R/W bit). `write_hex` is the bytes to write; `read_len` is how many bytes to read after the write. Set `read_len = 0` for write-only; pass `''` as `write_hex` for read-only.
- `P1_I2C_STOP(name) : BOOL`

## 8. Frequency counter and pulse measurement

Two specialized functions for timing-sensitive signals.

### 8.1 `P1_FREQ_SETUP` / `P1_FREQ_READ`

```iec
(* Count rising edges on P19 *)
P1_FREQ_SETUP('p1', 19);

(* Gate for 100 ms, return frequency in Hz *)
freq_hz := P1_FREQ_READ('p1', 100);
```

- `P1_FREQ_SETUP(name, pin) : BOOL` — Arms CTRB to count rising edges on the pin.
- `P1_FREQ_READ(name, gate_ms) : DINT` — **Blocks** for `gate_ms` milliseconds while counting, then returns the tally scaled to Hz. `gate_ms` is clamped to `[1, 1000]`; the default when you pass `< 1` is 100 ms.

Because `P1_FREQ_READ` blocks, it counts against your watchdog budget. A 100 ms gate used every scan on a 50 ms scan task will trip the watchdog. Either gate for less time, call it less often (every Nth scan), or move the call to a dedicated low-rate task.

### 8.2 `P1_PULSE_MEASURE`

```iec
(* HC-SR04 ultrasonic ping on trig=10, echo=11, 60 ms timeout *)
pulse_us := P1_PULSE_MEASURE('p1', 10, 11, 60000);
IF pulse_us > 0 THEN
    distance_mm := pulse_us * 10 / 58;   (* 58 µs per cm round trip *)
END_IF;
```

- `P1_PULSE_MEASURE(name, trig_pin, echo_pin, timeout_us) : DINT` — Drives `trig_pin` high for 10 µs, then measures the high-pulse width on `echo_pin` in microseconds. Returns `0` on timeout. `timeout_us` is clamped to `[0, 65535]`; pass `0` to use the default 30 ms.

This is purpose-built for the HC-SR04 family of ultrasonic distance sensors but works for any trigger-and-measure pulse pattern.

## 9. Quadrature / step-direction encoder

One channel (channel 0), two modes: quadrature x4 or step+direction. The encoder runs on its own cog and is sampled by GoPLC via three status reads.

```iec
(* Quadrature x4 encoder on A=P0, B=P1, Z=P2 *)
P1_ENC_SETUP('p1', 0, 0, 0, 1, 2);

(* Read position (signed, wraps at ±2^31) *)
pos := P1_ENC_READ('p1', 0);

(* Read how many Z-marker revolutions since last reset *)
revs := P1_ENC_REV_COUNT('p1', 0);

(* Read the position recorded at the most recent Z marker *)
pos_at_z := P1_ENC_POS_AT_Z('p1', 0);

(* Reset everything to zero *)
P1_ENC_RESET('p1', 0);
```

- `P1_ENC_SETUP(name, ch, mode, pin_a, pin_b, pin_z) : BOOL`
  - `mode: 0` — quadrature x4 (A/B/Z). Pin Z is optional; pass `255` if there is no Z channel.
  - `mode: 1` — step + direction (A = step, B = direction; Z is ignored).
- `P1_ENC_READ(name, ch) : DINT` — Signed position accumulator. Wraps modulo `2^32`.
- `P1_ENC_REV_COUNT(name, ch) : DINT` — Number of times the Z marker has been seen since the last reset.
- `P1_ENC_POS_AT_Z(name, ch) : DINT` — The `P1_ENC_READ` value latched at the most recent Z marker. Useful for home-seek logic: hit Z, subtract `pos_at_z` from the live position to get a zero-origin offset without a reset transient.
- `P1_ENC_RESET(name, ch) : BOOL` — Zeros position, latch, and rev count.

## 10. Event bus integration

P1 command health is tracked via the events bus, just like every other protocol driver. You don't have to do anything to get these events — they fire automatically based on transitions.

| Event type | Fires when | Severity |
|------------|------------|----------|
| `protocol.connect` | A failed → healthy transition (first `P1_INIT` success, or a reconnect after a drop) | `info` |
| `protocol.disconnect` | A healthy → failed transition (N consecutive command errors) | `warning` |

Source field is `p1:<name>`, so a device opened as `P1_INIT('main_p1', ...)` emits `p1:main_p1`. Subscribe from a webhook or MQTT to get notified on plug/unplug without instrumenting every ST call:

```yaml
events:
  enabled: true
  webhooks:
    - name: "ops-slack"
      url: "https://hooks.slack.com/services/..."
      format: "slack"
      event_types: ["protocol.connect", "protocol.disconnect"]
      min_severity: "info"
```

The dedup window (default 1 s) collapses rapid flap — you get one notification per real connect/disconnect, not one per scan.

## 11. Recipes

### 11.1 HC-SR04 distance sensor with alarm

Matches the `p1_ping_alarm.goplc` example project. Measures distance on every scan, logs the value to the historian, and trips a low-distance alarm with a deadband so the reading doesn't chatter:

```iec
PROGRAM P1_PingAlarm
VAR
    p1_port         : STRING;
    p1_ok           : BOOL;
    p1_healthy      : BOOL;
    alarm_created   : BOOL := FALSE;

    pulse_us        : DINT;
    distance_mm     : DINT;
END_VAR

    p1_port := SERIAL_FIND('SimplyTronics');
    IF p1_port <> '' THEN
        p1_ok := P1_INIT('p1', p1_port);
    END_IF;

    p1_healthy := P1_HEALTHY('p1');
    IF NOT p1_healthy THEN
        RETURN;
    END_IF;

    P1_PIN_MODE('p1', 10, 1);    (* trig = output *)
    P1_PIN_MODE('p1', 11, 0);    (* echo = input  *)

    (* One-time alarm bootstrap: trip below 30 mm, clear above 40 mm *)
    IF NOT alarm_created THEN
        ALARM_DELETE('distance_low');
        ALARM_CREATE('distance_low', 'p1_pingalarm.distance_mm', 'LO',
                     30.0, 10.0, 2, 0);
        alarm_created := TRUE;
    END_IF;

    pulse_us := P1_PULSE_MEASURE('p1', 10, 11, 60000);
    IF pulse_us > 0 AND pulse_us < 50000 THEN
        distance_mm := pulse_us * 10 / 58;
        HIST_LOG_VALUE('p1.distance_mm', distance_mm);
    END_IF;
END_PROGRAM
```

### 11.2 Heartbeat LED with unplug detection

A blinking LED that halts (stays off) when the P1 is unplugged or otherwise unhealthy. Pair this with a webhook on `protocol.disconnect` to get paged when your edge node goes dark:

```iec
PROGRAM Heartbeat
VAR
    p1_ok      : BOOL;
    p1_healthy : BOOL;
    blink      : TON;
    led_state  : BOOL;
END_VAR

    p1_ok := P1_INIT('p1', SERIAL_FIND('Parallax'));
    p1_healthy := P1_HEALTHY('p1');

    IF NOT p1_healthy THEN
        led_state := FALSE;
        RETURN;
    END_IF;

    P1_PIN_MODE('p1', 16, 1);

    blink(IN := NOT blink.Q, PT := T#500MS);
    IF blink.Q THEN
        led_state := NOT led_state;
        P1_PIN_WRITE('p1', 16, BOOL_TO_DINT(led_state));
    END_IF;
END_PROGRAM
```

### 11.3 I2C light sensor polling with deadband logging

Read a BH1750 light sensor once per scan, convert the raw lux value, and push it into the historian with a 5 lx deadband so only meaningful changes get logged:

```iec
PROGRAM LightSensor
VAR
    init_done    : BOOL := FALSE;
    i2c_ok       : BOOL;
    rx           : STRING;
    raw          : DINT;
    lux          : DINT;
END_VAR

    IF NOT P1_HEALTHY('p1') THEN
        P1_INIT('p1', SERIAL_FIND('Parallax'));
        RETURN;
    END_IF;

    IF NOT init_done THEN
        i2c_ok := P1_I2C_SETUP('p1', 28, 29, 100);
        (* BH1750 continuous H-res mode: write 0x10 to power on *)
        P1_I2C_XFER('p1', 16#23, '10', 0);
        init_done := TRUE;
    END_IF;

    (* Read two bytes of raw reading *)
    rx := P1_I2C_XFER('p1', 16#23, '', 2);
    raw := HEX_TO_DINT(rx);
    lux := raw * 10 / 12;

    HIST_LOG_VALUE('p1.lux', lux);
END_PROGRAM
```

### 11.4 Two-servo pan-tilt from HMI sliders

The event bus gives you one-way HMI-to-ST state via bound variables. Drive two servos directly from slider variables:

```iec
PROGRAM PanTilt
VAR
    pan_us  : DINT := 1500;   (* HMI-bound, 500..2500 *)
    tilt_us : DINT := 1500;
END_VAR

    IF NOT P1_HEALTHY('p1') THEN
        P1_INIT('p1', SERIAL_FIND('Parallax'));
        RETURN;
    END_IF;

    P1_SERVO_MOVE('p1', 0, 14, pan_us);
    P1_SERVO_MOVE('p1', 1, 15, tilt_us);
END_PROGRAM
```

## 12. Performance Notes

- **Per-command cost is ~300–600 µs** round-trip on a modern host over a quiet USB link. GPIO writes, reads, and PWM duty updates all fit this envelope.
- **`P1_PULSE_MEASURE` blocks for up to `timeout_us`** — schedule it on a dedicated task with a scan time longer than your worst-case timeout, or it will trip the watchdog.
- **`P1_FREQ_READ` blocks for `gate_ms` milliseconds** — same scheduling caveat. A 100 ms gate on a 50 ms scan task will double the apparent scan time.
- **`P1_UART_RECV` blocks for up to `timeout_ms`**. Use a short timeout (10–50 ms) or move UART receive onto a slower task.
- **SPI and I2C transfers are non-blocking** at the ST level but the firmware drives the bus at the configured clock rate, so a 32-byte I2C read at 100 kHz takes ~3 ms of bus time plus USB latency.
- **Thirty-two GPIO writes per scan** cost ~15 ms of USB round-trip and will starve a 10 ms scan task. Batch by using `P1_SPI_XFER` against an external shift-register chain for high-pin-count fanout, or move to the P2 which exposes wider pin-register operations.
- **Embedded firmware extracts to the working directory on first `P1_INIT`**. The extracted file is cached — subsequent `P1_INIT` calls do not re-extract. You can safely delete it; GoPLC re-extracts on the next boot.

## 13. P1 vs P2 — when to use which

| Dimension | P1 | P2 |
|-----------|----|----|
| Cogs | 8 | 8 (Rev G), wider pipelines |
| Clock | 80 MHz | 180–320 MHz |
| GPIO pins | 32 | 64 smart pins |
| Built-in peripherals | Basic GPIO, CTRA/CTRB counters | Smart pins with per-pin PWM, ADC, DAC, UART, frequency, quadrature |
| USB baud | 115200 (bootloader), command link shares | 3 Mbaud |
| Firmware size | ~6 KB | ~35 KB |
| Board cost | ~$30 | ~$50 |
| Typical job | Low pin count, low power, battery edge nodes, one UART or one I2C bus | High-channel-count I/O, multiple simultaneous UARTs, ADC/DAC, eye rendering, motor control |

If you need four encoders, eight PWM channels, two UARTs, and an ADC on one board — the P2 is the right call. If you need a battery-powered outpost polling one sensor, flipping a relay, and sleeping 99% of the time — the P1 wins on power and cost. Both are schema-driven and plug into the same event bus, so your architecture doesn't change as you scale from one to the other.

## 14. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `P1_INIT` returns `FALSE` on first call | USB port name wrong, or device isn't a P1 | Check `SERIAL_FIND` returned a non-empty string. Try `ls /dev/ttyUSB*`. On macOS: `ls /dev/tty.usbserial-*`. |
| `P1_INIT` returns `TRUE` but `P1_HEALTHY` is `FALSE` shortly after | Firmware upload succeeded but command schema didn't load | Ensure `p1_commands.json` is in the same directory as the firmware binary. The embedded firmware path includes both. |
| Distance reads of `0` from `P1_PULSE_MEASURE` | Timeout too short, or echo pin isn't a floating 5 V → 3.3 V divided signal | Raise `timeout_us` to 60000. HC-SR04 5 V echo on a 3.3 V pin needs a resistor divider (2×10 kΩ to ground). |
| Encoder counts missing | Mode wrong, or pin_z not set to 255 when there's no Z | Set `pin_z = 255` for quadrature-without-Z and for step+direction mode. |
| PWM duty above 128 doesn't get brighter | Clamped to 255 already, or the LED is hitting a current limit | `P1_PWM_DUTY` clamps to `[0, 255]`. An LED saturating at 50% duty is usually a series-resistor / V_f issue. |
| Commands time out after an hour of uptime | USB bridge hung (common with low-cost CH340 adapters) | `P1_INIT` self-heals: just call it every scan with a fresh `SERIAL_FIND` result. If it still fails, replace the USB cable — most flakes trace to the cable. |
| Firmware won't upload at all | ROM bootloader sequence rejected | Check the reset circuit on the board. Some custom P1s tie RTS or DTR to the wrong reset line. The Propeller Project Board and SimplyTronics Activity Board work out of the box. |

## 15. Related

- [`goplc_p2_guide.md`](goplc_p2_guide.md) — the Propeller 2 counterpart, with smart pins, more channels, and TAQOZ interactive mode.
- [`goplc_hal_guide.md`](goplc_hal_guide.md) — `rpi_gpio`, `pcf8574`, `grove_adc` and other local-host GPIO options when USB serial isn't the right transport.
- [`goplc_alarms_guide.md`](goplc_alarms_guide.md) — the alarm engine used in recipe 11.1.
- [`goplc_events_guide.md`](goplc_events_guide.md) — `protocol.connect` / `protocol.disconnect` event emission and webhook fan-out.
- [`goplc_debug_guide.md`](goplc_debug_guide.md) — enabling the `p1` debug module to see per-command logging during bring-up.
