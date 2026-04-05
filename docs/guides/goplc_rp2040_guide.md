# GoPLC + Waveshare RP2040-Zero: Hardware Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC treats the RP2040-Zero as a **smart I/O module** — not a compilation target. The board runs a precompiled Rust firmware that you flash once via UF2. All hardware control flows through USB CDC serial using a binary frame protocol, identical in concept to the Arduino and Teensy drivers.

The RP2040-Zero is a compact board based on the Raspberry Pi RP2040 chip with an onboard NeoPixel LED, making it ideal for small-footprint I/O expansion.

### System Diagram

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)         │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ ST Program                                   │   │
│  │                                              │   │
│  │ RP2040_INIT('rp', '/dev/ttyACM0')            │   │
│  │ RP2040_PIN_MODE('rp', 15, 1)                 │   │
│  │ RP2040_DIGITAL_WRITE('rp', 15, TRUE)         │   │
│  │ val := RP2040_ANALOG_READ('rp', 26)          │   │
│  │ RP2040_NEOPIXEL('rp', 0, 255, 0)             │   │
│  └──────────────────────┬───────────────────────┘   │
│                         │                           │
│                         │  Binary frames            │
│                         │  (USB CDC, CRC-16)        │
└─────────────────────────┼───────────────────────────┘
                          │
                          │  USB CDC Serial
                          ▼
┌─────────────────────────────────────────────────────┐
│  Waveshare RP2040-Zero (Dual-core Cortex-M0+)      │
│                                                     │
│  Rust firmware (UF2 flash)                          │
│                                                     │
│  29 GPIO (GP0-GP28)                                 │
│  4 ADC Inputs (GP26-GP29, 12-bit)                   │
│  16 PWM Channels (any GPIO)                         │
│  2 UART Channels (GP0/GP1, GP4/GP5)                 │
│  I2C (GP4=SDA, GP5=SCL)                             │
│  SPI (GP10=SCK, GP11=MOSI, GP12=MISO, GP13=CS)     │
│  1 Onboard NeoPixel (GP16)                          │
│  Internal Temperature Sensor                        │
│  SSD1306 OLED Support (via I2C)                     │
└─────────────────────────────────────────────────────┘
```

---

## 2. Device Lifecycle

### RP2040_INIT — Connect to Board

```iecst
ok := RP2040_INIT('rp', '/dev/ttyACM0');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle name (used by all other RP2040_* calls) |
| `port` | STRING | Serial port path |

> **Port Discovery:** Use `SERIAL_FIND('RP2040')` or `SERIAL_PORTS()` to locate the device automatically.

### RP2040_STATUS — Connection Health

```iecst
status := RP2040_STATUS('rp');
(* Returns JSON: {"connected":true,"ping_us":280,...} *)
```

### RP2040_CLOSE — Disconnect

```iecst
ok := RP2040_CLOSE('rp');
```

### RP2040_BOOTLOADER — Enter UF2 Flash Mode

```iecst
ok := RP2040_BOOTLOADER('rp');
```

Reboots the RP2040 into UF2 bootloader mode for firmware updates. The device disconnects — you must re-flash and call `RP2040_INIT` again to reconnect.

### Example: Safe Init with Port Discovery

```iecst
PROGRAM POU_RP2040Init
VAR
    port : STRING;
    ok : BOOL;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Find RP2040 *)
        port := SERIAL_FIND('RP2040');
        IF LEN(port) > 0 THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := RP2040_INIT('rp', port);
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Ready for I/O *)
        (* ... *)
END_CASE;
END_PROGRAM
```

---

## 3. Digital I/O

The RP2040-Zero has 29 GPIO pins (GP0-GP28).

### RP2040_PIN_MODE — Configure Pin Direction

| Param | Type | Values |
|-------|------|--------|
| `name` | STRING | Device handle |
| `pin` | INT | 0-28 |
| `mode` | INT | 0=INPUT, 1=OUTPUT, 2=INPUT_PULLUP, 3=PWM, 4=ADC |

```iecst
RP2040_PIN_MODE('rp', 15, 1);     (* Output *)
RP2040_PIN_MODE('rp', 14, 2);     (* Input with pull-up *)
```

### RP2040_DIGITAL_READ — Read Digital State

```iecst
sensor := RP2040_DIGITAL_READ('rp', 14);
(* Returns: TRUE or FALSE *)
```

Auto-configures pin as input if not already set.

### RP2040_DIGITAL_WRITE — Set Digital Output

```iecst
RP2040_DIGITAL_WRITE('rp', 15, TRUE);     (* High *)
RP2040_DIGITAL_WRITE('rp', 15, FALSE);    (* Low *)
```

Auto-configures pin as output if not already set.

### RP2040_RESET_PINS — Release All Pins

```iecst
ok := RP2040_RESET_PINS('rp');
```

Returns all pins to their default (unconfigured) state.

---

## 4. Analog I/O

### 4.1 Analog Input (ADC)

4 ADC-capable pins: GP26, GP27, GP28, GP29. 12-bit resolution scaled to 16-bit (0-65535).

```iecst
raw := RP2040_ANALOG_READ('rp', 26);     (* GP26 / A0 — returns 0-65535 *)
raw := RP2040_ANALOG_READ('rp', 27);     (* GP27 / A1 *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `pin` | INT | 26-29 (ADC-capable pins only) |

> **Voltage:** The RP2040 ADC reference is 3.3V. Voltage = raw * 3.3 / 65535.

### 4.2 PWM Output

Any GPIO pin can output PWM. 16-bit duty resolution (0-65535).

```iecst
RP2040_PWM_WRITE('rp', 15, 32768);     (* 50% duty *)
RP2040_PWM_WRITE('rp', 15, 65535);     (* Full on *)
RP2040_PWM_WRITE('rp', 15, 0);         (* Off *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `pin` | INT | Any GPIO pin |
| `duty` | INT | 0-65535 (16-bit) |

---

## 5. NeoPixel

The RP2040-Zero has an onboard WS2812B NeoPixel on GP16.

### RP2040_NEOPIXEL — Set Onboard LED Color

```iecst
RP2040_NEOPIXEL('rp', 255, 0, 0);      (* Red *)
RP2040_NEOPIXEL('rp', 0, 255, 0);      (* Green *)
RP2040_NEOPIXEL('rp', 0, 0, 255);      (* Blue *)
RP2040_NEOPIXEL('rp', 0, 0, 0);        (* Off *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `r` | INT | Red (0-255) |
| `g` | INT | Green (0-255) |
| `b` | INT | Blue (0-255) |

### RP2040_NEO_STRIP — Drive External NeoPixel Strip

Drives up to 64 NeoPixels on GP16. Colors are provided as a hex string with one RGB triplet per LED.

```iecst
(* 3 LEDs: red, green, blue *)
ok := RP2040_NEO_STRIP('rp', 3, 'FF0000 00FF00 0000FF');

(* 5 LEDs: all white at half brightness *)
ok := RP2040_NEO_STRIP('rp', 5, '808080 808080 808080 808080 808080');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `num_leds` | INT | Number of LEDs (1-64) |
| `colors` | STRING | Space-separated hex RGB values per LED |

---

## 6. I2C

The RP2040-Zero uses I2C0 on GP4 (SDA) and GP5 (SCL).

### RP2040_I2C_SCAN — Scan Bus for Devices

```iecst
devices := RP2040_I2C_SCAN('rp');
(* Returns: "0x3C,0x68" — comma-separated hex addresses *)
```

### RP2040_I2C_WRITE_BYTE — Write Single Byte

```iecst
ok := RP2040_I2C_WRITE_BYTE('rp', 16#3C, 16#AE);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `addr` | INT | 7-bit I2C device address |
| `value` | INT | Byte to write (0-255) |

### RP2040_I2C_READ_BYTE — Read Single Byte

```iecst
val := RP2040_I2C_READ_BYTE('rp', 16#48);
(* Returns: byte value 0-255, or -1 on error *)
```

### RP2040_I2C_WRITE_READ — Write Register Then Read

```iecst
data := RP2040_I2C_WRITE_READ('rp', 16#48, 16#00, 2);
(* Writes register 0x00 to device 0x48, reads back 2 bytes *)
(* Returns: comma-separated decimal values, e.g. "12,128" *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `addr` | INT | 7-bit I2C device address |
| `reg` | INT | Register address to write first |
| `read_len` | INT | Number of bytes to read |

---

## 7. SPI

Fixed pinout: GP10 (SCK), GP11 (MOSI), GP12 (MISO), GP13 (CS).

### RP2040_SPI_TRANSFER — Full-Duplex Transfer

```iecst
(* Send 3 bytes, receive 3 bytes simultaneously *)
rx := RP2040_SPI_TRANSFER('rp', 'FF 00 A5');
(* Returns: hex string of received bytes, e.g. "00 42 FF" *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `data` | STRING | Space-separated hex bytes to send |

---

## 8. UART

Two UART channels with fixed pin assignments:

| Channel | TX | RX |
|---------|----|----|
| 0 | GP0 | GP1 |
| 1 | GP4 | GP5 |

### RP2040_UART_INIT — Initialize UART Channel

```iecst
ok := RP2040_UART_INIT('rp', 0, 9600);      (* Channel 0 at 9600 baud *)
ok := RP2040_UART_INIT('rp', 1, 115200);    (* Channel 1 at 115200 baud *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `channel` | INT | 0 or 1 |
| `baud` | INT | Baud rate |

### RP2040_UART_SEND — Send Data

```iecst
ok := RP2040_UART_SEND('rp', 0, 'Hello World');
```

### RP2040_UART_RECV — Receive Data (Non-Blocking)

```iecst
data := RP2040_UART_RECV('rp', 0, 64);
(* Returns: received string, or empty if nothing available *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `channel` | INT | 0 or 1 |
| `max_len` | INT | Maximum bytes to read |

---

## 9. Servo

Standard hobby servos on any GPIO pin. Uses 50Hz PWM with 1-2ms pulse width.

```iecst
RP2040_SERVO('rp', 15, 90);      (* Center *)
RP2040_SERVO('rp', 15, 0);       (* Min position *)
RP2040_SERVO('rp', 15, 180);     (* Max position *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `pin` | INT | GPIO pin |
| `angle` | INT | Position in degrees (0-180) |

---

## 10. Sensors

### RP2040_TEMP_READ — Internal Temperature Sensor

```iecst
raw := RP2040_TEMP_READ('rp');
(* Returns: temperature in degrees C x 100 *)
(* Example: 2534 = 25.34 degrees C *)

temp_c := INT_TO_REAL(raw) / 100.0;
```

### RP2040_DISTANCE — HC-SR04 Ultrasonic Distance

```iecst
dist_mm := RP2040_DISTANCE('rp', 7, 8);
(* Returns: distance in millimeters, 0 on error *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `trig_pin` | INT | Trigger pin (output) |
| `echo_pin` | INT | Echo pin (input) |

---

## 11. OLED Display (SSD1306)

Drives an SSD1306 128x64 OLED via I2C (GP4=SDA, GP5=SCL).

### RP2040_OLED_INIT — Initialize Display

```iecst
ok := RP2040_OLED_INIT('rp', 16#3C);     (* Standard address 0x3C *)
```

### RP2040_OLED_CLEAR — Clear Screen

```iecst
ok := RP2040_OLED_CLEAR('rp', 16#3C);
```

### RP2040_OLED_PRINT — Print Text

```iecst
RP2040_OLED_PRINT('rp', 16#3C, 0, 'Temperature:');
RP2040_OLED_PRINT('rp', 16#3C, 1, '25.3 C');
RP2040_OLED_PRINT('rp', 16#3C, 3, 'GoPLC Running');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `addr` | INT | I2C address (typically 0x3C) |
| `row` | INT | Text row (0-7, 8 rows of 5x7 font) |
| `text` | STRING | Text to display (21 chars per line max) |

---

## 12. Complete Example: Sensor Station

```iecst
PROGRAM POU_RP2040Station
VAR
    state : INT := 0;
    port : STRING;
    ok : BOOL;
    scan_count : DINT := 0;

    (* Sensors *)
    distance_mm : INT;
    light_raw : INT;
    temp_raw : INT;
    temp_c : REAL;

    (* Outputs *)
    led_duty : INT;
    msg : STRING;
END_VAR

CASE state OF
    0: (* Discover and connect *)
        port := SERIAL_FIND('RP2040');
        IF LEN(port) > 0 THEN
            ok := RP2040_INIT('rp', port);
            IF ok THEN state := 1; END_IF;
        END_IF;

    1: (* Configure pins + OLED *)
        RP2040_PIN_MODE('rp', 15, 1);         (* LED output *)
        RP2040_PIN_MODE('rp', 14, 2);         (* Button input w/ pull-up *)
        RP2040_OLED_INIT('rp', 16#3C);
        RP2040_OLED_CLEAR('rp', 16#3C);
        RP2040_OLED_PRINT('rp', 16#3C, 0, 'GoPLC RP2040 Station');
        state := 10;

    10: (* Main loop *)
        scan_count := scan_count + 1;

        (* Internal temperature *)
        temp_raw := RP2040_TEMP_READ('rp');
        temp_c := INT_TO_REAL(temp_raw) / 100.0;

        (* Light sensor on GP26 *)
        light_raw := RP2040_ANALOG_READ('rp', 26);

        (* Ultrasonic distance *)
        distance_mm := RP2040_DISTANCE('rp', 7, 8);

        (* NeoPixel: green = close, red = far *)
        IF distance_mm > 0 AND distance_mm < 500 THEN
            RP2040_NEOPIXEL('rp', 0, 255, 0);
        ELSIF distance_mm > 0 THEN
            RP2040_NEOPIXEL('rp', 255, 0, 0);
        ELSE
            RP2040_NEOPIXEL('rp', 0, 0, 50);     (* Blue = no reading *)
        END_IF;

        (* PWM LED brightness from light sensor *)
        led_duty := 65535 - light_raw;
        RP2040_PWM_WRITE('rp', 15, led_duty);

        (* Update OLED every 50 scans *)
        IF (scan_count MOD 50) = 0 THEN
            msg := CONCAT('Temp: ', REAL_TO_STRING(temp_c), ' C');
            RP2040_OLED_PRINT('rp', 16#3C, 2, msg);
            msg := CONCAT('Dist: ', INT_TO_STRING(distance_mm), ' mm');
            RP2040_OLED_PRINT('rp', 16#3C, 3, msg);
            msg := CONCAT('Light: ', INT_TO_STRING(light_raw));
            RP2040_OLED_PRINT('rp', 16#3C, 4, msg);
        END_IF;

        (* Heartbeat *)
        RP2040_DIGITAL_WRITE('rp', 15, (scan_count MOD 10) < 5);
END_CASE;
END_PROGRAM
```

---

## 13. Hardware Notes

### Pin Constraints

- **GP0/GP1**: UART0 TX/RX. Available for GPIO if UART0 not used.
- **GP4/GP5**: I2C0 SDA/SCL and UART1 TX/RX. Shared — use one or the other.
- **GP10-GP13**: SPI0 pins. Available for GPIO if SPI not used.
- **GP16**: Onboard NeoPixel. Also used for external NeoPixel strips.
- **GP26-GP29**: ADC-capable. Can also be used as digital GPIO.
- **GP23-GP25**: Used internally on some RP2040 boards — check your specific board pinout.

### ADC Resolution

The RP2040 has a 12-bit ADC (0-4095) but the firmware scales to 16-bit (0-65535) for consistency with other GoPLC hardware drivers.

### USB CDC Serial

- **Port**: Typically `/dev/ttyACM0` on Linux.
- **Protocol**: Binary frames with CRC-16 (same structure as Arduino/Teensy drivers).
- **Firmware**: Rust-based, flashed via UF2.

### Power

- **USB power**: 5V from host, 3.3V logic on all GPIO.
- **Current**: Max ~300mA total from 3.3V regulator. Budget for NeoPixels (60mA per LED at full white).
- **Servo power**: Use external supply for servos — do not power from the board's 3.3V.

---

## Appendix A: Function Quick Reference

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `RP2040_INIT` | `(name, port)` | BOOL | Connect to RP2040 board |
| `RP2040_CLOSE` | `(name)` | BOOL | Disconnect |
| `RP2040_STATUS` | `(name)` | STRING | JSON status and board info |
| `RP2040_BOOTLOADER` | `(name)` | BOOL | Enter UF2 flash mode |
| `RP2040_PIN_MODE` | `(name, pin, mode)` | BOOL | Set pin: 0=IN, 1=OUT, 2=PULLUP, 3=PWM, 4=ADC |
| `RP2040_DIGITAL_READ` | `(name, pin)` | BOOL | Read digital pin |
| `RP2040_DIGITAL_WRITE` | `(name, pin, value)` | BOOL | Write digital pin |
| `RP2040_ANALOG_READ` | `(name, pin)` | INT | Read ADC (pins 26-29, 0-65535) |
| `RP2040_PWM_WRITE` | `(name, pin, duty)` | BOOL | Set PWM duty (0-65535) |
| `RP2040_NEOPIXEL` | `(name, r, g, b)` | BOOL | Set onboard NeoPixel color |
| `RP2040_NEO_STRIP` | `(name, num_leds, colors)` | BOOL | Drive NeoPixel strip (GP16, max 64) |
| `RP2040_TEMP_READ` | `(name)` | INT | Internal temp (degrees C x 100) |
| `RP2040_RESET_PINS` | `(name)` | BOOL | Release all pins to default |
| `RP2040_I2C_SCAN` | `(name)` | STRING | Comma-separated hex addresses |
| `RP2040_I2C_WRITE_BYTE` | `(name, addr, value)` | BOOL | Write byte to I2C device |
| `RP2040_I2C_READ_BYTE` | `(name, addr)` | INT | Read byte (-1 on error) |
| `RP2040_I2C_WRITE_READ` | `(name, addr, reg, read_len)` | STRING | Write register, read N bytes |
| `RP2040_SPI_TRANSFER` | `(name, hex_data)` | STRING | Full-duplex SPI transfer |
| `RP2040_SERVO` | `(name, pin, angle)` | BOOL | Set servo angle (0-180) |
| `RP2040_DISTANCE` | `(name, trig_pin, echo_pin)` | INT | HC-SR04 distance in mm |
| `RP2040_UART_INIT` | `(name, channel, baud)` | BOOL | Init UART (ch 0: GP0/1, ch 1: GP4/5) |
| `RP2040_UART_SEND` | `(name, channel, data)` | BOOL | Send string via UART |
| `RP2040_UART_RECV` | `(name, channel, max_len)` | STRING | Receive from UART (non-blocking) |
| `RP2040_OLED_INIT` | `(name, addr)` | BOOL | Init SSD1306 OLED |
| `RP2040_OLED_CLEAR` | `(name, addr)` | BOOL | Clear OLED screen |
| `RP2040_OLED_PRINT` | `(name, addr, row, text)` | BOOL | Print text at row (0-7) |

---

*GoPLC v1.0.533 | Firmware: Rust (UF2) | Waveshare RP2040-Zero @ 133 MHz*
*Protocol: Binary frame (CRC-16) over USB CDC*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
