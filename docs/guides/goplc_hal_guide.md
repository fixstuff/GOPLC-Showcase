# GoPLC HAL: Native GPIO, I2C, SPI, and ADC on Linux SBCs

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.548

---

GoPLC has a built-in Hardware Abstraction Layer (HAL) that talks directly to Raspberry Pi GPIO, I2C expanders, and analog-to-digital converters without any external bridge board. You declare pins in a YAML manifest, GoPLC maps them to standard IEC 61131-3 addresses (`%IX0.0`, `%QX0.0`, `%QW0`), and your ST code reads and writes those addresses exactly like inputs and outputs on a traditional PLC.

## 1. Architecture Overview

The HAL is a unified driver (`pkg/hal`) that hosts one or more device plugins. At startup it reads the `hal:` section of your config, instantiates each device, calls its `Init()` method, and begins a polling loop at the configured rate. Inputs are read every cycle and merged into the runtime's input image; outputs written by ST code are routed to the owning device on the next scan boundary.

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime                                      │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ ST Program                                   │   │
│  │                                              │   │
│  │ VAR                                          │   │
│  │   startBtn AT %IX0.0 : BOOL;                 │   │
│  │   motor    AT %QX0.0 : BOOL;                 │   │
│  │   speed    AT %QW0   : INT;                  │   │
│  │ END_VAR                                      │   │
│  └──────────────────────┬───────────────────────┘   │
│                         │                           │
│  ┌──────────────────────▼───────────────────────┐   │
│  │ HAL Driver (pkg/hal/hal.go)                  │   │
│  │  - Poll loop @ poll_rate_ms                  │   │
│  │  - Address mapping IEC ↔ device              │   │
│  └─────┬──────────┬──────────┬───────────┬──────┘   │
│        │          │          │           │          │
│    ┌───▼───┐  ┌───▼────┐ ┌───▼────┐ ┌────▼────┐    │
│    │rpi_   │  │pcf8574 │ │grove_  │ │ dht /   │    │
│    │gpio   │  │(I2C)   │ │adc(I2C)│ │ adxl345 │    │
│    └───┬───┘  └───┬────┘ └───┬────┘ └────┬────┘    │
│        │          │          │           │          │
└────────┼──────────┼──────────┼───────────┼──────────┘
         │          │          │           │
   periph.io    /dev/i2c-1  /dev/i2c-1   /dev/i2c-1
   /dev/gpiomem  @ 0x20     @ 0x08       @ varies
```

Every device is implemented through [periph.io](https://periph.io) v3, which is already a GoPLC dependency — no extra libraries required.

## 2. Why HAL Instead of a Bridge Board

GoPLC also supports smart I/O bridge boards (Arduino, P2, Teensy, RP2040, Flipper, Phidgets) that handle hardware over a serial link. Those are the right answer when you need isolation, fast hardware timing, or you're running GoPLC on a host without GPIO (a desktop or VM). The HAL is the right answer when:

- You're running GoPLC **directly on a Pi, Orange Pi, or similar Linux SBC**
- You only need tens of pins, not hundreds
- You want a $15 Pi Zero 2W + a $10 relay hat to be a complete controller — no bridge board, no USB cable
- You want your `config.yaml` to fully describe the machine

One caveat: the HAL polls at `poll_rate_ms` (default 10 ms). For hard real-time or sub-millisecond edge capture, use a P2 or Teensy bridge board.

## 3. Supported Device Types

These device types are registered and ready to use. The `type:` field in your YAML selects one.

| `type:` | Hardware | Notes |
|---------|----------|-------|
| `rpi_gpio` | Raspberry Pi / Pi Zero / compatible GPIO headers | Digital I/O, PWM, pull-up/down |
| `pcf8574` | PCF8574 / PCF8574A I2C 8-bit I/O expander | 8 bidirectional pins, active-low outputs |
| `grove_adc` | Seeed Grove Base HAT ADC (STM32) | 8 × 12-bit analog channels, 0–4095 raw |
| `dht` | DHT11 / DHT22 temperature + humidity sensor | 1-wire, read via Grove HAT |
| `adxl345` | ADXL345 3-axis accelerometer | I2C, used in the motion guide |
| `virtual` | Simulated device | For testing on a dev machine without hardware |
| `serial` | Generic serial I/O | For custom firmware targets |
| `nextion` | Nextion HMI display | Serial protocol |
| `camera` | USB/CSI camera | Frame capture into variables |
| `tft` | TFT LCD (ILI9341 family) | SPI framebuffer |
| `p2` | Parallax Propeller 2 (as a HAL device) | Alternative to the dedicated P2 driver |

For the rest of this guide I'll focus on the three most common ones: `rpi_gpio`, `pcf8574`, and `grove_adc`.

## 4. Configuration Schema

The HAL lives under the `hal:` key in your `config.yaml`:

```yaml
hal:
  enabled: true             # must be true to activate the HAL
  poll_rate_ms: 10          # how often to scan inputs and flush outputs
  devices:
    - name: rpi              # instance name (unique, used in logs)
      type: rpi_gpio         # selects the driver
      inputs:  [ ... ]
      outputs: [ ... ]
      pwm:     [ ... ]
      bus: 0                 # I2C bus number (ignored for rpi_gpio)
      address: 0             # I2C device address (ignored for rpi_gpio)
      settings: {}           # optional device-specific overrides
```

Each pin entry is a `PinConfig`:

```yaml
- pin: 17                    # hardware pin/channel/bit number
  address: "%IX0.0"          # IEC 61131-3 address your ST code reads
  pull: up                   # up | down | none  (rpi_gpio inputs only)
  description: "Start"       # shows up in docs and logs
```

PWM entries use `PWMConfig`:

```yaml
- pin: 12
  address: "%QW0"
  frequency: 1000            # Hz
  description: "Motor speed"
```

The data value at the PWM address is a duty cycle in the range **0–1000**, where 0 = 0% and 1000 = 100%. GoPLC rescales this to periph.io's internal duty representation internally, so you don't need to think in fractions.

## 5. Tutorial: Blink an LED on a Raspberry Pi

The cheapest working GoPLC deployment: a Pi, a resistor, an LED, a config file.

### Wiring

- LED anode → 330 Ω resistor → Pi header pin 11 (GPIO 17)
- LED cathode → Pi header pin 9 (GND)

### `config.yaml`

```yaml
hal:
  enabled: true
  poll_rate_ms: 10
  devices:
    - name: rpi
      type: rpi_gpio
      outputs:
        - pin: 17
          address: "%QX0.0"
          description: "Heartbeat LED"
```

### ST program

```iecst
PROGRAM Blink
VAR
    heartbeat AT %QX0.0 : BOOL;
    blink_tmr : TON;
END_VAR

blink_tmr(IN := NOT blink_tmr.Q, PT := T#500ms);
IF blink_tmr.Q THEN
    heartbeat := NOT heartbeat;
END_IF;
END_PROGRAM
```

Drop the program into a task at 50 ms scan, deploy, and pin 17 will toggle at 1 Hz.

### Permissions

Running as a non-root user? Add the user to the `gpio` and `i2c` groups:

```bash
sudo usermod -aG gpio,i2c "$USER"
# log out and back in
```

On modern Pi OS periph.io uses `/dev/gpiomem` (no root required). If you see "operation not permitted" errors, double-check group membership and verify the file `/dev/gpiomem` is readable by the `gpio` group.

## 6. Reading a Button with Pull-Up

```yaml
hal:
  enabled: true
  devices:
    - name: rpi
      type: rpi_gpio
      inputs:
        - pin: 27
          address: "%IX0.0"
          pull: up
          description: "E-Stop (normally closed)"
```

`pull: up` enables the internal pull-up so the pin reads HIGH when the button is open. With a normally-closed E-Stop, `estop := TRUE` means "safe" and a drop to `FALSE` means "stopped" — exactly what you want for a fail-safe circuit.

```iecst
VAR
    estop_ok AT %IX0.0 : BOOL;
    run_perm : BOOL;
END_VAR

run_perm := estop_ok AND ready AND NOT fault;
```

## 7. PWM: Dimming an LED

```yaml
hal:
  enabled: true
  devices:
    - name: rpi
      type: rpi_gpio
      pwm:
        - pin: 18
          address: "%QW0"
          frequency: 1000
          description: "LED brightness"
```

```iecst
VAR
    brightness AT %QW0 : INT;
    fade_step  : INT := 5;
END_VAR

brightness := brightness + fade_step;
IF brightness >= 1000 OR brightness <= 0 THEN
    fade_step := -fade_step;
END_IF;
```

PWM duty values are **0–1000**, not 0–100 and not 0–255. Clamp to that range in your ST code — values outside are silently clamped in the driver, but clamping yourself is clearer.

## 8. PCF8574 — Adding 8 Cheap Pins Over I2C

The PCF8574 is a $1 I2C 8-bit I/O expander. Each pin is bidirectional, and GoPLC infers direction from whether you listed it under `inputs` or `outputs`. Pins listed as `inputs` are driven high by the driver so the external circuit can pull them low.

```yaml
hal:
  enabled: true
  devices:
    - name: io_expander
      type: pcf8574
      bus: 1                # /dev/i2c-1
      address: 0x20         # default PCF8574 address
      inputs:
        - pin: 0
          address: "%IX1.0"
          description: "Door switch"
        - pin: 1
          address: "%IX1.1"
          description: "Lid switch"
      outputs:
        - pin: 4
          address: "%QX1.0"
          description: "Relay 1"
        - pin: 5
          address: "%QX1.1"
          description: "Relay 2"
```

**Important quirks:**

- `pin:` for PCF8574 is the **bit number 0–7**, not a header pin.
- Outputs are **active-low**: writing `TRUE` pulls the pin LOW (relay energised). The driver handles the inversion so your ST code still reads "TRUE = on".
- Inputs also read **active-low**: the driver returns `TRUE` when the pin is pulled LOW externally (button pressed). Again, your ST code sees the intuitive polarity.
- Default I2C address is `0x20`. The PCF8574**A** variant uses `0x38`. Three address pins let you chain eight of these on one bus — 64 pins total.

Confirm the chip is present before deploying:

```bash
sudo apt install i2c-tools
i2cdetect -y 1
```

You should see `20` (or wherever you jumpered the address pins) in the grid.

## 9. Grove ADC — Reading Analog Sensors

The Seeed Grove Base HAT has an onboard STM32 that exposes 8 analog channels over I2C. Perfect for potentiometers, light sensors, gas sensors, anything that's a voltage.

```yaml
hal:
  enabled: true
  devices:
    - name: adc
      type: grove_adc
      bus: 1
      address: 0x08          # default Grove Base HAT address
      inputs:
        - pin: 0             # A0
          address: "%IW0"
          description: "Tank level (4-20mA shunt)"
        - pin: 2             # A2
          address: "%IW1"
          description: "Ambient light"
```

The raw value is a 12-bit integer **0–4095** corresponding to 0–3.3 V. Scale it in ST:

```iecst
VAR
    tank_raw  AT %IW0 : INT;
    tank_pct  : REAL;
END_VAR

// 0-4095 → 0-100%
tank_pct := INT_TO_REAL(tank_raw) * 100.0 / 4095.0;
```

For a 4-20 mA loop powered across a 165 Ω shunt (producing 0.66-3.3 V):

```iecst
// 4 mA ≈ 820 raw, 20 mA ≈ 4095 raw
flow_pct := INT_TO_REAL(flow_raw - 820) * 100.0 / (4095.0 - 820.0);
```

## 10. Mixing Multiple Devices

Nothing stops you from stacking devices — the HAL merges their address spaces. Addresses have to be unique across devices, but pin numbers don't.

```yaml
hal:
  enabled: true
  poll_rate_ms: 10
  devices:
    # Onboard Pi GPIO for fast local I/O
    - name: rpi
      type: rpi_gpio
      inputs:
        - { pin: 17, address: "%IX0.0", pull: up, description: "Start button" }
        - { pin: 27, address: "%IX0.1", pull: up, description: "Stop button" }
      outputs:
        - { pin: 18, address: "%QX0.0", description: "Contactor" }
        - { pin: 23, address: "%QX0.1", description: "Fault lamp" }

    # 8 more relays over I2C
    - name: relays
      type: pcf8574
      bus: 1
      address: 0x20
      outputs:
        - { pin: 0, address: "%QX1.0", description: "Valve 1" }
        - { pin: 1, address: "%QX1.1", description: "Valve 2" }
        - { pin: 2, address: "%QX1.2", description: "Valve 3" }
        - { pin: 3, address: "%QX1.3", description: "Pump" }

    # Analog tank level + temperature
    - name: adc
      type: grove_adc
      bus: 1
      address: 0x08
      inputs:
        - { pin: 0, address: "%IW0", description: "Tank level" }
        - { pin: 1, address: "%IW1", description: "Supply temp" }
```

From ST code this looks like one 14-input, 12-output, 2-analog PLC. The HAL hides the fact that half the pins are onboard and half are on an I2C chip.

## 11. Runtime Inspection

After startup the runtime logs every configured device and address count:

```
HAL: Initialized device rpi (type: rpi_gpio)
HAL: Initialized device relays (type: pcf8574)
HAL: Initialized device adc (type: grove_adc)
HAL: Built 10 input and 12 output mappings
HAL: Started with 3 device(s)
```

If a device fails to initialize — wrong address, missing chip, permission denied — the runtime **logs and skips** it and continues starting other devices. Your ST program will still compile but the affected addresses will never update. Always check startup logs after changing the manifest.

The existing runtime/API tooling lets you inspect variables and I/O at runtime:

- `GET /api/variables` — current input image, including HAL-backed addresses
- `GET /api/tags` — tag database showing the PLC address → description mapping
- `POST /api/variables/:name` — force an output (great for bringup)

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `pin GPIO17 not found` | Wrong OS or non-Pi hardware | Only `rpi_gpio` works on Broadcom SoCs. On Orange Pi, Rock Pi, etc. you'll want to fall back to `sysfs` via a different driver. |
| `open I2C bus /dev/i2c-1: permission denied` | User not in `i2c` group | `sudo usermod -aG i2c "$USER"` and re-login. |
| `open I2C bus /dev/i2c-1: no such file` | I2C not enabled on the Pi | `sudo raspi-config` → Interface Options → I2C → Enable. Reboot. |
| PCF8574 outputs are inverted in ST code | You're not accounting for the driver's active-low handling | The driver already inverts. Write `TRUE` for "energised" and trust it. If it's *still* wrong, your relay board is itself active-low (most are) — in which case `FALSE` in ST = relay on. |
| ADC reads 0 or 4095 constantly | Shorted to GND or V+ | Grove Base HAT tolerates 0–3.3 V only. Exceeding 3.3 V can damage the STM32. |
| Output writes appear to "lag" | `poll_rate_ms` too high | The HAL flushes on every poll cycle. Drop `poll_rate_ms` to 5 or 10 for snappier response. Trade-off: CPU load. |
| Nothing happens, no errors | `enabled: false` or the `hal:` section is missing | Check `GET /api/config` to confirm the HAL block is present and enabled. |

## 13. What the HAL Does *Not* Do (Yet)

Known limits of the current HAL layer:

- **No direct ST function calls.** You can't write `GPIO_WRITE(17, TRUE)` in ST today — every pin must be declared in the YAML manifest first. A spec for "direct GPIO ST functions" exists at `docs/spec/DIRECT_GPIO.md` but is not implemented.
- **No hardware interrupts.** Inputs are polled at `poll_rate_ms`, so the fastest edge you can reliably catch is about 2× that period. For microsecond-class edges, bridge to a P2 or Teensy.
- **No runtime pin reconfiguration.** Pin direction and pull mode are set once at `Init()`. Changing them requires a project reload.
- **No native SPI driver in the HAL layer yet.** SPI devices go through device-specific drivers (`tft`, P2/Teensy bridges). A generic `SPI_TRANSFER` ST function is on the spec list but not yet built.

## 14. Comparison Cheat Sheet

| Need | Use |
|------|-----|
| Handful of pins, GoPLC on a Pi, low cost | **HAL with `rpi_gpio`** |
| More digital pins over I2C, still on Pi | **HAL with `pcf8574`** (stackable to 64 pins) |
| Analog sensors into a Pi | **HAL with `grove_adc`** |
| Temperature / humidity | **HAL with `dht`** |
| Motion / vibration | **HAL with `adxl345`** |
| Hard real-time edge capture, encoder counting | **P2 or Teensy bridge** (see respective guides) |
| Hundreds of I/O, complex motion | **P2 or ENIP remote I/O rack** |
| GoPLC on a non-Pi host (desktop, VM, x86 gateway) | **Arduino, Phidgets, P2, or a remote EtherNet/IP I/O module** |

---

The HAL is intentionally boring: declarative config, standard IEC addresses, no new ST vocabulary to learn. That's the whole point. If you can read and write `%IX` and `%QX` you can control a Raspberry Pi from GoPLC today, using exactly the same ST code you'd write for a traditional PLC rack.
