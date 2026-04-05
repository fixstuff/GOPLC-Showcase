# GoPLC + Teensy 4.0: Hardware Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC treats the Teensy 4.0 as a **smart I/O module** connected over USB RawHID. The Teensy runs a Rust firmware that exposes 47 ST functions covering digital I/O, analog, PWM, CAN bus, hardware PID, encoders, and more. All hardware control flows through 64-byte HID reports at full-speed USB (1 kHz poll rate).

Unlike serial-based protocols, RawHID provides **guaranteed delivery with no framing ambiguity** — each USB transaction is exactly 64 bytes, eliminating sync-byte hunting and partial-frame recovery.

| Feature | Specification |
|---------|---------------|
| **MCU** | NXP i.MX RT1062, ARM Cortex-M7 @ 600 MHz |
| **Flash** | 1 MB (+ 8 MB QSPI on Teensy 4.0) |
| **RAM** | 512 KB tightly-coupled + 512 KB general |
| **Digital Pins** | 40 (all 3.3V, 5V tolerant on most) |
| **Analog Inputs** | 14 (10-bit default, configurable to 12-bit) |
| **PWM Outputs** | 31 (FlexPWM with complementary pairs and fault inputs) |
| **CAN Buses** | 3 (CAN 2.0B, FlexCAN hardware) |
| **Serial Ports** | 7 (hardware UART) |
| **Encoder** | Hardware quadrature decoder |
| **RTC** | Battery-backed real-time clock |
| **TRNG** | Hardware true random number generator |

### System Diagram

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)         │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ ST Program                                   │   │
│  │                                              │   │
│  │ TEENSY_INIT('t1', '')                        │   │
│  │ TEENSY_DIGITAL_WRITE('t1', 13, TRUE)         │   │
│  │ TEENSY_CAN_SEND('t1', 16#200, '0102030405')  │   │
│  │ TEENSY_PID_CONFIG('t1', 14, 3, 2.0, 0.1, 0) │   │
│  └──────────────────┬───────────────────────────┘   │
│                     │                               │
│                     │  64-byte HID reports           │
│                     │  (USB RawHID, 1 kHz poll)      │
└─────────────────────┼───────────────────────────────┘
                      │
                      │    USB RawHID
                      ▼
┌─────────────────────────────────────────────────────┐
│  Teensy 4.0 (ARM Cortex-M7, 600 MHz)               │
│                                                     │
│  Rust Firmware                                      │
│                                                     │
│  Command dispatch (0xC0-0xFF opcodes)               │
│  FlexPWM engine — complementary pairs + fault       │
│  FlexCAN — 3 buses, hardware filtering              │
│  Hardware quadrature encoder                        │
│  On-chip PID loop (runs in firmware tick)            │
│  TRNG — hardware entropy source                     │
│  RTC — battery-backed timekeeping                   │
│                                                     │
│  40 Digital, 14 Analog, 31 PWM, 3 CAN,             │
│  7 UART, I2C, SPI, NeoPixel, OLED                  │
└─────────────────────────────────────────────────────┘
```

---

## 2. Connection and Wire Protocol

### 2.1 The Three Lifecycle Functions

```iecst
(* Connect to Teensy — empty path for auto-discovery *)
ok := TEENSY_INIT('t1', '');

(* Or specify the exact HID device *)
ok := TEENSY_INIT('t1', '/dev/hidraw3');

(* Check connection health *)
status := TEENSY_STATUS('t1');
(* Returns: "connected" or "disconnected" *)

(* Disconnect *)
TEENSY_CLOSE('t1');
```

**Auto-discovery** scans `/dev/hidraw*` devices for the Teensy RawHID vendor/product ID. In most single-Teensy setups, an empty path is all you need. For multi-Teensy rigs, specify the exact device path.

### 2.2 Wire Protocol

Every function call is packed into a 64-byte HID report:

```
┌──────┬──────┬─────┬─────┬────────┬──────────────┬────────┐
│ 0xA5 │ 0x5A │ SEQ │ CMD │ LEN(2) │ PAYLOAD(0-N) │ CRC(2) │
│ sync │ sync │  1B │  1B │  LE    │  LE fields   │ MODBUS │
└──────┴──────┴─────┴─────┴────────┴──────────────┴────────┘
```

- CRC-16/MODBUS over SEQ + CMD + LEN + PAYLOAD
- Fixed 64-byte USB HID reports (zero-padded)
- All multi-byte values: little-endian
- Response uses same frame format
- Command opcodes: 0xC0-0xFF (Teensy namespace, no collision with P2 opcodes)

You never build frames manually — each `TEENSY_*` function handles packing/unpacking internally.

### 2.3 Why RawHID (Not Serial)

| | USB RawHID | USB Serial |
|--|-----------|------------|
| **Framing** | Fixed 64-byte packets | Byte stream — need sync bytes, escape sequences |
| **Reliability** | USB guarantees delivery | Bytes can be lost if buffer overflows |
| **Latency** | 1 ms poll interval (USB full-speed) | Variable — depends on OS buffering, FTDI latency timer |
| **Multi-device** | Each Teensy gets unique hidraw device | Serial ports can shuffle on reboot |
| **No driver needed** | Linux HID subsystem (built-in) | Requires CDC-ACM or FTDI driver |

---

## 3. Function Reference

### 3.1 Device Lifecycle

#### TEENSY_INIT — Connect to Teensy

```iecst
(* Auto-discover first Teensy *)
ok := TEENSY_INIT('t1', '');

(* Explicit device path *)
ok := TEENSY_INIT('t1', '/dev/hidraw3');
```

Returns `TRUE` on successful connection. The firmware responds with its version and capability flags.

#### TEENSY_STATUS — Connection Health

```iecst
status := TEENSY_STATUS('t1');
(* Returns: "connected" or "disconnected" *)
```

#### TEENSY_CLOSE — Disconnect

```iecst
ok := TEENSY_CLOSE('t1');
```

---

### 3.2 Digital I/O

#### TEENSY_PIN_MODE — Configure Pin Direction

| Param | Type | Values |
|-------|------|--------|
| `name` | STRING | Device name |
| `pin` | INT | 0-39 |
| `mode` | INT | 0=INPUT, 1=OUTPUT, 2=INPUT_PULLUP, 3=INPUT_PULLDOWN |

```iecst
(* Set pin 13 (onboard LED) as output *)
TEENSY_PIN_MODE('t1', 13, 1);

(* Set pin 2 as input with pullup *)
TEENSY_PIN_MODE('t1', 2, 2);
```

#### TEENSY_DIGITAL_READ — Read Pin State

```iecst
state := TEENSY_DIGITAL_READ('t1', 2);
(* Returns: TRUE or FALSE *)
```

#### TEENSY_DIGITAL_WRITE — Set Output

```iecst
TEENSY_DIGITAL_WRITE('t1', 13, TRUE);   (* LED on *)
TEENSY_DIGITAL_WRITE('t1', 13, FALSE);  (* LED off *)
```

#### TEENSY_RESET_PINS — Reset All Pins to Default

```iecst
(* Emergency reset — all pins return to high-impedance input *)
TEENSY_RESET_PINS('t1');
```

Useful for fault recovery or safe shutdown. Every pin is set to floating input, all PWM stopped, all peripherals de-initialized.

#### Example: Digital I/O Scan Loop

```iecst
PROGRAM POU_DigitalIO
VAR
    sensor : BOOL;
    ok : BOOL;
END_VAR

(* Read sensor on pin 2 *)
sensor := TEENSY_DIGITAL_READ('t1', 2);

(* Drive relay on pin 6 based on sensor *)
IF sensor THEN
    ok := TEENSY_DIGITAL_WRITE('t1', 6, TRUE);
ELSE
    ok := TEENSY_DIGITAL_WRITE('t1', 6, FALSE);
END_IF;
END_PROGRAM
```

---

### 3.3 Analog Input

The Teensy 4.0 has 14 analog inputs (pins 14-27 on default mapping) with 10-bit resolution (0-1023) by default.

#### TEENSY_ANALOG_READ — Read ADC Value

```iecst
raw := TEENSY_ANALOG_READ('t1', 14);
(* Returns: 0-1023 (10-bit) or 0-4095 (12-bit if configured) *)
```

#### Example: Analog Monitoring

```iecst
PROGRAM POU_AnalogMonitor
VAR
    raw_value : INT;
    voltage : REAL;
END_VAR

raw_value := TEENSY_ANALOG_READ('t1', 14);
(* Scale to voltage: 3.3V reference, 10-bit resolution *)
voltage := INT_TO_REAL(raw_value) * 3.3 / 1023.0;
END_PROGRAM
```

---

### 3.4 PWM

The Teensy 4.0's FlexPWM engine provides 31 PWM outputs with configurable frequency, resolution, complementary pairs, and hardware fault inputs — capabilities that rival dedicated motor drive ICs.

#### TEENSY_PWM_WRITE — Basic PWM Output

```iecst
(* 50% duty on pin 3 (uses default frequency and resolution) *)
ok := TEENSY_PWM_WRITE('t1', 3, 128);
```

#### TEENSY_PWM_CONFIG — Configure Frequency and Resolution

| Param | Type | Description |
|-------|------|-------------|
| `pin` | INT | PWM-capable pin |
| `freq` | INT | Frequency in Hz |
| `resolution` | INT | Bit depth (8-16 typical) |

```iecst
(* 20 kHz PWM at 12-bit resolution on pin 3 *)
ok := TEENSY_PWM_CONFIG('t1', 3, 20000, 12);

(* Now set duty: 0-4095 range (12-bit) *)
ok := TEENSY_PWM_WRITE('t1', 3, 2048);   (* 50% *)
```

> **Note:** Higher frequency reduces maximum resolution. At 600 MHz bus clock: 20 kHz allows ~15 bits, 100 kHz allows ~13 bits, 1 MHz allows ~9 bits.

#### TEENSY_PWM_PAIR — Complementary PWM with Dead Time

This is the industrial workhorse for half-bridge and full-bridge motor drives, where the high-side and low-side switches must never conduct simultaneously.

| Param | Type | Description |
|-------|------|-------------|
| `pinA` | INT | High-side PWM pin |
| `pinB` | INT | Low-side PWM pin (complementary) |
| `freq` | INT | Switching frequency in Hz |
| `dutyA` | INT | High-side duty (0-65535) |
| `dutyB` | INT | Low-side duty (0-65535) |
| `deadtime_ns` | INT | Dead time in nanoseconds |

```iecst
(* Half-bridge: 20 kHz, 50% duty, 500ns dead time *)
ok := TEENSY_PWM_PAIR('t1', 2, 3, 20000, 32768, 32768, 500);
```

> **Why this matters:** Dead time prevents shoot-through — the catastrophic condition where both transistors in a half-bridge conduct simultaneously, creating a short circuit from supply to ground. The FlexPWM hardware inserts the dead time in silicon, with nanosecond precision that software timers cannot match.

#### TEENSY_PWM_FAULT — Hardware Fault Input

Connects a physical fault pin to the FlexPWM shutdown logic. When the fault pin triggers, PWM outputs are disabled in hardware within one clock cycle — no software latency.

```iecst
(* Fault on pin 5, active LOW (typical for gate driver fault outputs) *)
ok := TEENSY_PWM_FAULT('t1', 5, TRUE);

(* Fault on pin 7, active HIGH *)
ok := TEENSY_PWM_FAULT('t1', 7, FALSE);
```

> **Industrial application:** Gate drivers for IGBTs and MOSFETs provide a fault output (overcurrent, desaturation, overtemperature). Wiring this to a FlexPWM fault input guarantees sub-microsecond shutdown — critical for protecting power electronics from destructive faults.

#### Example: Motor Drive with Protection

```iecst
PROGRAM POU_MotorDrive
VAR
    ok : BOOL;
    speed_cmd : INT := 0;     (* 0-65535 *)
    running : BOOL := FALSE;
END_VAR

IF NOT running THEN
    (* Configure fault input first — always set up protection before enabling drive *)
    ok := TEENSY_PWM_FAULT('t1', 5, TRUE);

    (* Configure complementary PWM: 20 kHz, 1us dead time *)
    ok := TEENSY_PWM_PAIR('t1', 2, 3, 20000, 0, 0, 1000);
    running := TRUE;
END_IF;

(* Update duty from control logic *)
ok := TEENSY_PWM_PAIR('t1', 2, 3, 20000, speed_cmd, speed_cmd, 1000);
END_PROGRAM
```

---

### 3.5 Servo

#### TEENSY_SERVO — Set Servo Angle

| Param | Type | Description |
|-------|------|-------------|
| `pin` | INT | Servo signal pin |
| `angle` | INT | Position in degrees (0-180) |

```iecst
(* Center servo *)
ok := TEENSY_SERVO('t1', 9, 90);

(* Full sweep *)
ok := TEENSY_SERVO('t1', 9, 0);     (* min *)
ok := TEENSY_SERVO('t1', 9, 180);   (* max *)
```

> **Pin sharing:** Servo signals are generated by the same FlexPWM hardware as `TEENSY_PWM_WRITE`. Configuring a pin for servo overrides any prior PWM configuration on that pin.

---

### 3.6 I2C

The Teensy 4.0 has dedicated I2C hardware with internal pullups available.

#### TEENSY_I2C_SCAN — Discover Devices

```iecst
devices := TEENSY_I2C_SCAN('t1');
(* Returns: "3C,48,68" — comma-separated hex addresses *)
```

#### TEENSY_I2C_WRITE — Write Data

```iecst
(* Write command byte 0xAE to OLED at 0x3C *)
ok := TEENSY_I2C_WRITE('t1', 16#3C, 'AE');
```

#### TEENSY_I2C_READ — Read Data

```iecst
(* Read 2 bytes from temperature sensor at 0x48 *)
data := TEENSY_I2C_READ('t1', 16#48, 2);
(* Returns: "0C80" — hex-encoded bytes *)
```

#### TEENSY_I2C_WRITE_READ — Write Then Read (Repeated START)

Most I2C sensors require writing a register address, then reading the result without releasing the bus.

```iecst
(* Read 2 bytes from register 0x00 of device at 0x48 *)
data := TEENSY_I2C_WRITE_READ('t1', 16#48, '00', 2);
(* Returns: "0C80" *)
```

#### Example: Temperature Sensor (LM75/TMP102)

```iecst
PROGRAM POU_TempSensor
VAR
    raw_hex : STRING;
    ok : BOOL;
END_VAR

(* Read 2-byte temperature register from LM75 at 0x48 *)
raw_hex := TEENSY_I2C_WRITE_READ('t1', 16#48, '00', 2);
(* Parse: raw_hex contains MSB:LSB, temperature = value / 256.0 *)
END_PROGRAM
```

---

### 3.7 SPI

#### TEENSY_SPI_TRANSFER — Full Duplex Transfer

| Param | Type | Description |
|-------|------|-------------|
| `cs_pin` | INT | Chip select pin |
| `speed_hz` | INT | Clock speed in Hz |
| `mode` | INT | SPI mode 0-3 |
| `data_hex` | STRING | Hex-encoded transmit data |

```iecst
(* Transfer 2 bytes at 1 MHz, SPI mode 0, CS on pin 10 *)
rx := TEENSY_SPI_TRANSFER('t1', 10, 1000000, 0, 'FF00');
(* Returns: hex-encoded received data *)
```

#### Example: MCP3008 ADC (8-channel, 10-bit)

```iecst
PROGRAM POU_ExternalADC
VAR
    result : STRING;
END_VAR

(* Read channel 0: send start bit + single-ended + channel *)
(* 0x01 = start, 0x80 = single-ended CH0, 0x00 = clock out result *)
result := TEENSY_SPI_TRANSFER('t1', 10, 1000000, 0, '018000');
(* Parse 10-bit result from response bytes *)
END_PROGRAM
```

---

### 3.8 UART

The Teensy 4.0 has 7 hardware serial ports. Channels 1-7 map to Serial1-Serial7 in the Teensy ecosystem.

#### TEENSY_UART_INIT — Open Channel

| Param | Type | Description |
|-------|------|-------------|
| `ch` | INT | Channel 1-7 |
| `tx_pin` | INT | Transmit pin |
| `rx_pin` | INT | Receive pin |
| `baud` | INT | Baud rate |

```iecst
(* Serial1 on default pins: TX=1, RX=0 at 9600 baud *)
ok := TEENSY_UART_INIT('t1', 1, 1, 0, 9600);

(* Serial2 for Modbus RTU at 19200 *)
ok := TEENSY_UART_INIT('t1', 2, 8, 7, 19200);
```

#### TEENSY_UART_SEND — Transmit Data

Data is hex-encoded. `48656C6C6F` = "Hello".

```iecst
(* Send Modbus query frame *)
ok := TEENSY_UART_SEND('t1', 2, '0103000000010A11');
```

#### TEENSY_UART_RECV — Receive Data

```iecst
(* Read up to 32 bytes with 500ms timeout *)
data := TEENSY_UART_RECV('t1', 2, 32, 500);
(* Returns: hex-encoded received bytes, empty string on timeout *)
```

#### Example: RS-485 Modbus RTU Query

```iecst
PROGRAM POU_ModbusQuery
VAR
    ok : BOOL;
    response : STRING;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Initialize UART for Modbus *)
        ok := TEENSY_UART_INIT('t1', 2, 8, 7, 19200);
        IF ok THEN state := 1; END_IF;

    1: (* Send read holding registers: addr=1, func=3, start=0, count=10 *)
        ok := TEENSY_UART_SEND('t1', 2, '010300000000A5CD');
        state := 2;

    2: (* Wait for response *)
        response := TEENSY_UART_RECV('t1', 2, 64, 100);
        IF LEN(response) > 0 THEN
            (* Parse Modbus response *)
            state := 1;  (* Continue polling *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 3.9 OLED Display (SSD1306)

Firmware-native text rendering on I2C OLED displays. 21 characters x 8 rows on a 128x64 OLED.

```iecst
(* Initialize OLED at I2C address 0x3C *)
ok := TEENSY_OLED_INIT('t1', 16#3C);

(* Clear screen *)
ok := TEENSY_OLED_CLEAR('t1');

(* Print status information *)
ok := TEENSY_OLED_PRINT('t1', 0, 'GoPLC + Teensy 4.0');
ok := TEENSY_OLED_PRINT('t1', 2, 'CAN: 250kbps OK');
ok := TEENSY_OLED_PRINT('t1', 4, 'PID: Kp=2.0 Ki=0.1');
ok := TEENSY_OLED_PRINT('t1', 6, 'Temp: 42C');
```

---

### 3.10 NeoPixel (WS2812B)

#### TEENSY_NEOPIXEL — Set Single Pixel

```iecst
(* Set pixel 0 on pin 5 to red *)
ok := TEENSY_NEOPIXEL('t1', 5, 0, 255, 0, 0);

(* Set pixel 3 to blue *)
ok := TEENSY_NEOPIXEL('t1', 5, 3, 0, 0, 255);
```

#### TEENSY_NEO_STRIP — Full Strip Update

Updates an entire NeoPixel strip in a single command. Colors are passed as a JSON array.

```iecst
(* Update 4-pixel strip: red, green, blue, white *)
ok := TEENSY_NEO_STRIP('t1', 5, 4,
    '[{"r":255,"g":0,"b":0},{"r":0,"g":255,"b":0},{"r":0,"g":0,"b":255},{"r":255,"g":255,"b":255}]');
```

#### Example: Status Indicator Strip

```iecst
PROGRAM POU_StatusLEDs
VAR
    ok : BOOL;
    can_ok : BOOL;
    pid_ok : BOOL;
    temp_ok : BOOL;
END_VAR

(* Green = OK, Red = Fault *)
(* Pixel 0: CAN bus status *)
IF can_ok THEN
    ok := TEENSY_NEOPIXEL('t1', 5, 0, 0, 255, 0);
ELSE
    ok := TEENSY_NEOPIXEL('t1', 5, 0, 255, 0, 0);
END_IF;

(* Pixel 1: PID loop status *)
IF pid_ok THEN
    ok := TEENSY_NEOPIXEL('t1', 5, 1, 0, 255, 0);
ELSE
    ok := TEENSY_NEOPIXEL('t1', 5, 1, 255, 0, 0);
END_IF;

(* Pixel 2: Temperature OK *)
IF temp_ok THEN
    ok := TEENSY_NEOPIXEL('t1', 5, 2, 0, 255, 0);
ELSE
    ok := TEENSY_NEOPIXEL('t1', 5, 2, 255, 0, 0);
END_IF;
END_PROGRAM
```

---

### 3.11 CAN Bus

The Teensy 4.0 has 3 hardware CAN 2.0B controllers (FlexCAN). This is the primary industrial fieldbus interface — CAN is the backbone of automotive, industrial automation, and robotics communication.

#### TEENSY_CAN_INIT — Initialize CAN Bus

```iecst
(* Initialize CAN at 250 kbps (typical industrial) *)
ok := TEENSY_CAN_INIT('t1', 250000);

(* 500 kbps for automotive *)
ok := TEENSY_CAN_INIT('t1', 500000);

(* 1 Mbps for high-speed applications *)
ok := TEENSY_CAN_INIT('t1', 1000000);
```

> **Hardware required:** CAN needs an external transceiver (MCP2551, SN65HVD230, or similar) between the Teensy CAN TX/RX pins and the CAN bus. The Teensy provides the protocol controller; the transceiver handles the differential signaling and bus fault protection.

#### TEENSY_CAN_SEND — Transmit Frame

```iecst
(* Send 8-byte CAN frame with ID 0x200 *)
ok := TEENSY_CAN_SEND('t1', 16#200, '0102030405060708');

(* Send 3-byte frame *)
ok := TEENSY_CAN_SEND('t1', 16#100, '112233');
```

#### TEENSY_CAN_RECV — Receive Frame

```iecst
(* Wait up to 100ms for a CAN frame *)
frame := TEENSY_CAN_RECV('t1', 100);
(* Returns JSON: {"id":512,"data":"0102030405060708","len":8} *)
(* Empty string on timeout *)
```

#### TEENSY_CAN_FILTER — Set Hardware Acceptance Filter

Filters are applied in hardware — rejected frames never reach the firmware, reducing CPU load.

| Param | Type | Description |
|-------|------|-------------|
| `id` | INT | Acceptance ID |
| `mask` | INT | Bit mask (1 = must match, 0 = don't care) |

```iecst
(* Accept only ID 0x200 exactly *)
ok := TEENSY_CAN_FILTER('t1', 16#200, 16#7FF);

(* Accept IDs 0x300-0x30F (mask ignores low 4 bits) *)
ok := TEENSY_CAN_FILTER('t1', 16#300, 16#7F0);

(* Accept all (no filter) *)
ok := TEENSY_CAN_FILTER('t1', 0, 0);
```

#### TEENSY_CAN_STATUS — Bus Diagnostics

```iecst
status := TEENSY_CAN_STATUS('t1');
(* Returns JSON: {"state":"active","tx_errors":0,"rx_errors":0,"bus_off":false} *)
```

CAN states: `active` (normal), `warning` (error count > 96), `passive` (error count > 127), `bus_off` (error count > 255, bus disconnected).

#### Example: CANopen-Style I/O Module

```iecst
PROGRAM POU_CANBridge
VAR
    ok : BOOL;
    frame : STRING;
    state : INT := 0;
    analog_value : INT;
END_VAR

CASE state OF
    0: (* Initialize CAN at 250 kbps *)
        ok := TEENSY_CAN_INIT('t1', 250000);
        (* Accept PDO range 0x180-0x1FF *)
        ok := TEENSY_CAN_FILTER('t1', 16#180, 16#780);
        IF ok THEN state := 1; END_IF;

    1: (* Main loop: receive commands, send data *)
        (* Check for incoming PDO *)
        frame := TEENSY_CAN_RECV('t1', 10);
        IF LEN(frame) > 0 THEN
            (* Parse and apply digital outputs from CAN frame *)
        END_IF;

        (* Read local analog and broadcast as TPDO *)
        analog_value := TEENSY_ANALOG_READ('t1', 14);
        ok := TEENSY_CAN_SEND('t1', 16#280,
            CONCAT(INT_TO_HEX(analog_value), '0000000000000000'));
END_CASE;
END_PROGRAM
```

---

### 3.12 Quadrature Encoder

Uses the Teensy 4.0's hardware quadrature decoder for zero-CPU-overhead position tracking.

#### TEENSY_ENCODER_INIT — Configure Encoder

```iecst
(* Encoder on pins 2 (A) and 3 (B) *)
ok := TEENSY_ENCODER_INIT('t1', 2, 3);
```

#### TEENSY_ENCODER_READ — Read Position

```iecst
count := TEENSY_ENCODER_READ('t1');
(* Returns: signed INT — positive for CW, negative for CCW *)
```

#### TEENSY_ENCODER_RESET — Zero the Counter

```iecst
ok := TEENSY_ENCODER_RESET('t1');
```

#### Example: Position Tracking

```iecst
PROGRAM POU_Encoder
VAR
    position : INT;
    ok : BOOL;
    initialized : BOOL := FALSE;
END_VAR

IF NOT initialized THEN
    ok := TEENSY_ENCODER_INIT('t1', 2, 3);
    ok := TEENSY_ENCODER_RESET('t1');
    initialized := TRUE;
END_IF;

position := TEENSY_ENCODER_READ('t1');
(* position tracks cumulative counts — 4x decoding (both edges, both channels) *)
END_PROGRAM
```

---

### 3.13 Frequency Counter

#### TEENSY_FREQ_INIT — Configure Input Pin

```iecst
ok := TEENSY_FREQ_INIT('t1', 10);
```

#### TEENSY_FREQ_READ — Read Frequency

```iecst
hz := TEENSY_FREQ_READ('t1');
(* Returns: REAL — frequency in Hz as floating point *)
(* Example: 1000.0 for 1 kHz, 0.5 for one pulse every 2 seconds *)
```

#### Example: RPM Measurement

```iecst
PROGRAM POU_RPM
VAR
    freq : REAL;
    rpm : REAL;
    ok : BOOL;
    initialized : BOOL := FALSE;
END_VAR

IF NOT initialized THEN
    ok := TEENSY_FREQ_INIT('t1', 10);
    initialized := TRUE;
END_IF;

freq := TEENSY_FREQ_READ('t1');
(* 1 pulse per revolution: RPM = Hz * 60 *)
rpm := freq * 60.0;
END_PROGRAM
```

---

### 3.14 Hardware PID Controller

The PID loop runs **in the Teensy firmware**, not in the GoPLC scan cycle. This provides deterministic control at the firmware tick rate (typically 1 kHz) regardless of GoPLC scan time or USB latency.

#### TEENSY_PID_CONFIG — Initialize PID Loop

| Param | Type | Description |
|-------|------|-------------|
| `input_pin` | INT | Analog input pin (process variable) |
| `output_pin` | INT | PWM output pin (control variable) |
| `kp` | REAL | Proportional gain |
| `ki` | REAL | Integral gain |
| `kd` | REAL | Derivative gain |

```iecst
(* Temperature control: thermocouple on pin 14, heater PWM on pin 3 *)
ok := TEENSY_PID_CONFIG('t1', 14, 3, 2.0, 0.1, 0.05);
```

#### TEENSY_PID_SETPOINT — Set Target Value

```iecst
(* Set target to ADC value corresponding to desired temperature *)
ok := TEENSY_PID_SETPOINT('t1', 512);   (* mid-scale = ~1.65V *)
```

#### TEENSY_PID_READ — Read PID State

```iecst
state := TEENSY_PID_READ('t1');
(* Returns JSON: {"input":498,"output":178,"setpoint":512,"error":14} *)
```

#### TEENSY_PID_TUNE — Hot-Tune Gains

Change PID gains without stopping the control loop. Essential for field tuning.

```iecst
(* Increase proportional gain *)
ok := TEENSY_PID_TUNE('t1', 3.0, 0.1, 0.05);
```

#### TEENSY_PID_STOP — Stop PID Loop

```iecst
ok := TEENSY_PID_STOP('t1');
(* Output pin goes to 0 — safe shutdown *)
```

#### Example: Closed-Loop Temperature Control

```iecst
PROGRAM POU_TempControl
VAR
    ok : BOOL;
    pid_state : STRING;
    setpoint : INT := 512;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Configure PID: thermocouple on A0 (pin 14), heater on pin 3 *)
        ok := TEENSY_PID_CONFIG('t1', 14, 3, 2.0, 0.1, 0.05);
        ok := TEENSY_PID_SETPOINT('t1', setpoint);
        state := 1;

    1: (* Monitor — PID runs autonomously in firmware *)
        pid_state := TEENSY_PID_READ('t1');
        (* Log or display pid_state *)
        (* Adjust setpoint from HMI if needed *)

    99: (* Shutdown *)
        ok := TEENSY_PID_STOP('t1');
        state := 100;
END_CASE;
END_PROGRAM
```

> **Why firmware PID matters:** A GoPLC scan cycle runs at 1-50 ms. USB round-trip adds 1-2 ms. The firmware PID loop runs at the Teensy's internal tick rate (~1 kHz), giving 10-50x faster control response. For thermal control this may not matter; for motor speed or pressure regulation, it is the difference between stable control and oscillation.

---

### 3.15 RTC (Real-Time Clock)

The Teensy 4.0 has a battery-backed RTC that maintains time through power cycles (with a CR2032 coin cell on the VBAT pin).

#### TEENSY_RTC_GET — Read Current Time

```iecst
timestamp := TEENSY_RTC_GET('t1');
(* Returns: "2026-04-03T14:30:00Z" — ISO 8601 format *)
```

#### TEENSY_RTC_SET — Set Time

```iecst
ok := TEENSY_RTC_SET('t1', '2026-04-03T14:30:00Z');
```

#### Example: Timestamped Event Logging

```iecst
PROGRAM POU_EventLog
VAR
    timestamp : STRING;
    fault_active : BOOL;
    last_fault : BOOL := FALSE;
END_VAR

fault_active := TEENSY_DIGITAL_READ('t1', 5);

(* Log rising edge of fault *)
IF fault_active AND NOT last_fault THEN
    timestamp := TEENSY_RTC_GET('t1');
    (* Log: CONCAT('FAULT at ', timestamp) *)
END_IF;

last_fault := fault_active;
END_PROGRAM
```

---

### 3.16 True Random Number Generator (TRNG)

The i.MX RT1062 contains a hardware entropy source that produces cryptographically random numbers from physical noise — not a PRNG seeded from a timer.

#### TEENSY_TRNG_READ — Get Random Number

```iecst
rng := TEENSY_TRNG_READ('t1');
(* Returns: INT — 32-bit hardware random value *)
```

#### Example: Session Token Generation

```iecst
PROGRAM POU_Security
VAR
    token_a : INT;
    token_b : INT;
END_VAR

(* Generate 64 bits of hardware entropy for session tokens *)
token_a := TEENSY_TRNG_READ('t1');
token_b := TEENSY_TRNG_READ('t1');
END_PROGRAM
```

> **Industrial use cases:** Challenge-response authentication with field devices, nonce generation for encrypted CAN frames, randomized retry backoff for multi-master bus arbitration.

---

### 3.17 Sensors

#### TEENSY_TEMP_READ — Internal Die Temperature

```iecst
temp_c := TEENSY_TEMP_READ('t1');
(* Returns: INT — internal temperature in degrees Celsius *)
```

Useful for thermal monitoring of the Teensy itself, especially in enclosed industrial panels.

#### TEENSY_DISTANCE — HC-SR04 Ultrasonic Distance

| Param | Type | Description |
|-------|------|-------------|
| `trig` | INT | Trigger pin |
| `echo` | INT | Echo pin |

```iecst
mm := TEENSY_DISTANCE('t1', 20, 21);
(* Returns: INT — distance in millimeters *)
```

#### Example: Proximity Detection

```iecst
PROGRAM POU_Proximity
VAR
    distance_mm : INT;
    object_present : BOOL;
END_VAR

distance_mm := TEENSY_DISTANCE('t1', 20, 21);
object_present := (distance_mm > 0) AND (distance_mm < 300);
END_PROGRAM
```

---

### 3.18 System

#### TEENSY_BOOTLOADER — Enter Firmware Update Mode

```iecst
ok := TEENSY_BOOTLOADER('t1');
(* Teensy enters bootloader — connection is lost *)
(* Re-flash with teensy_loader_cli or Teensy Loader GUI *)
```

> **Caution:** This is a one-way trip. The Teensy disconnects from GoPLC and enters bootloader mode. You must re-flash firmware and call `TEENSY_INIT` again to reconnect.

---

## 4. Industrial Application Patterns

### 4.1 Motor Drive with CAN Bus Feedback

Combines complementary PWM, encoder feedback, CAN bus communication, and hardware PID — a complete servo drive in ST code.

```iecst
PROGRAM POU_ServoDrive
VAR
    ok : BOOL;
    position : INT;
    pid_state : STRING;
    can_frame : STRING;
    can_status : STRING;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Initialize all subsystems *)
        ok := TEENSY_CAN_INIT('t1', 250000);
        ok := TEENSY_CAN_FILTER('t1', 16#200, 16#7FF);
        ok := TEENSY_ENCODER_INIT('t1', 2, 3);
        ok := TEENSY_PWM_FAULT('t1', 5, TRUE);
        ok := TEENSY_PID_CONFIG('t1', 14, 6, 1.5, 0.05, 0.01);
        ok := TEENSY_PID_SETPOINT('t1', 0);
        state := 1;

    1: (* Running — CAN receives setpoint, encoder provides position *)
        (* Check for CAN command *)
        can_frame := TEENSY_CAN_RECV('t1', 5);
        IF LEN(can_frame) > 0 THEN
            (* Parse new setpoint from CAN frame and apply *)
            (* ok := TEENSY_PID_SETPOINT('t1', new_setpoint); *)
        END_IF;

        (* Read encoder for position feedback *)
        position := TEENSY_ENCODER_READ('t1');

        (* Read PID state for diagnostics *)
        pid_state := TEENSY_PID_READ('t1');

        (* Broadcast position on CAN *)
        ok := TEENSY_CAN_SEND('t1', 16#280,
            CONCAT(INT_TO_HEX(position), '00000000'));

        (* Monitor CAN bus health *)
        can_status := TEENSY_CAN_STATUS('t1');

    99: (* Fault — stop everything *)
        ok := TEENSY_PID_STOP('t1');
        ok := TEENSY_RESET_PINS('t1');
END_CASE;
END_PROGRAM
```

### 4.2 Multi-Sensor Data Acquisition

```iecst
PROGRAM POU_DataAcq
VAR
    ok : BOOL;
    analog_ch : INT;
    adc_values : ARRAY[0..3] OF INT;
    die_temp : INT;
    distance : INT;
    encoder_pos : INT;
    freq : REAL;
    timestamp : STRING;
END_VAR

(* Read 4 analog channels *)
adc_values[0] := TEENSY_ANALOG_READ('t1', 14);
adc_values[1] := TEENSY_ANALOG_READ('t1', 15);
adc_values[2] := TEENSY_ANALOG_READ('t1', 16);
adc_values[3] := TEENSY_ANALOG_READ('t1', 17);

(* Read other sensors *)
die_temp := TEENSY_TEMP_READ('t1');
distance := TEENSY_DISTANCE('t1', 20, 21);
encoder_pos := TEENSY_ENCODER_READ('t1');
freq := TEENSY_FREQ_READ('t1');
timestamp := TEENSY_RTC_GET('t1');

(* Display on OLED *)
ok := TEENSY_OLED_PRINT('t1', 0, CONCAT('T:', INT_TO_STRING(die_temp), 'C'));
ok := TEENSY_OLED_PRINT('t1', 2, CONCAT('D:', INT_TO_STRING(distance), 'mm'));
ok := TEENSY_OLED_PRINT('t1', 4, CONCAT('E:', INT_TO_STRING(encoder_pos)));
ok := TEENSY_OLED_PRINT('t1', 6, CONCAT('F:', REAL_TO_STRING(freq), 'Hz'));
END_PROGRAM
```

---

## 5. Timing Tiers

| Tier | Where It Runs | Latency | Use Case |
|------|--------------|---------|----------|
| **Teensy firmware (Rust)** | On-chip, Cortex-M7 | ~1.7 ns/cycle (600 MHz) | PID loop, PWM fault shutdown, encoder counting |
| **FlexPWM hardware** | Peripheral silicon | Sub-nanosecond | Dead time insertion, complementary outputs, fault response |
| **USB RawHID** | Host ↔ Teensy | 1-2 ms round-trip | Command/response, sensor reads |
| **GoPLC scan** | Host CPU, ST interpreter | 1-50 ms | State machines, sequencing, CAN orchestration |
| **GoPLC boss** | Cluster coordination | 10-100 ms | HMI, logging, multi-device orchestration |

The key insight: **time-critical operations run in the Teensy firmware or hardware peripherals**. The PID loop does not wait for GoPLC. The PWM fault shutdown does not wait for USB. GoPLC handles the logic, sequencing, and coordination — the Teensy handles the microsecond-level control.

---

## 6. Hardware Notes for Teensy 4.0 Users

### Pin Constraints

- **Pin 13**: Onboard LED — usable for general I/O but convenient for debug.
- **Pins 0/1**: Default Serial1 TX/RX. Available for GPIO if Serial1 is not used.
- **Pins 18/19**: Default I2C SDA/SCL. Available for GPIO if I2C is not used.
- **CAN pins**: CAN1 TX=22, RX=23. CAN2 TX=1, RX=0. CAN3 TX=31, RX=30.

### Voltage Levels

- **All I/O is 3.3V.** Most pins are 5V tolerant (can read 5V input without damage), but output is always 3.3V.
- **Analog reference**: 3.3V, not adjustable. External voltage dividers needed for higher voltage signals.
- **CAN transceiver**: Must be 3.3V compatible (SN65HVD230) or use a 5V transceiver (MCP2551) with level shifting.

### USB RawHID Gotchas

- **Linux permissions**: By default, `/dev/hidraw*` devices require root access. Add a udev rule:
  ```
  SUBSYSTEM=="hidraw", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="0486", MODE="0666"
  ```
  GoPLC's install script creates this rule automatically.
- **Device enumeration**: hidraw device numbers can change on reboot. Use `TEENSY_INIT('t1', '')` for auto-discovery, or write udev rules that create symlinks based on serial number.
- **64-byte limit**: Each HID report is exactly 64 bytes. Commands with payloads exceeding ~56 bytes (after header + CRC) are split across multiple reports automatically.

### Firmware Update

1. Call `TEENSY_BOOTLOADER('t1')` to enter bootloader mode (or press the physical button on the Teensy).
2. Flash new firmware with `teensy_loader_cli --mcu=TEENSY40 firmware.hex` or the Teensy Loader GUI.
3. Teensy reboots with new firmware.
4. Call `TEENSY_INIT('t1', '')` to reconnect.

### Power Considerations

- **USB power**: 500 mA from USB. Sufficient for the Teensy itself plus moderate I/O.
- **External power**: Use VIN pin (5-24V) for higher current applications. The onboard regulator provides 3.3V at 250 mA.
- **Motor drives**: Always use external power for motors. Never power motors from the Teensy's regulator.
- **CAN bus termination**: Add 120-ohm termination resistors at each end of the CAN bus. The Teensy does not include built-in termination.

---

## Appendix A: Complete Function Quick Reference

| Function | Opcode | Parameters | Returns |
|----------|--------|------------|---------|
| `TEENSY_INIT` | — | name:STRING, path:STRING | BOOL |
| `TEENSY_CLOSE` | — | name:STRING | BOOL |
| `TEENSY_STATUS` | — | name:STRING | STRING |
| `TEENSY_PIN_MODE` | 0xC0 | name, pin:INT, mode:INT | BOOL |
| `TEENSY_DIGITAL_READ` | 0xC1 | name, pin:INT | BOOL |
| `TEENSY_DIGITAL_WRITE` | 0xC2 | name, pin:INT, value:BOOL | BOOL |
| `TEENSY_RESET_PINS` | 0xC3 | name | BOOL |
| `TEENSY_ANALOG_READ` | 0xC4 | name, pin:INT | INT |
| `TEENSY_PWM_WRITE` | 0xC5 | name, pin:INT, duty:INT | BOOL |
| `TEENSY_PWM_CONFIG` | 0xC6 | name, pin:INT, freq:INT, resolution:INT | BOOL |
| `TEENSY_PWM_PAIR` | 0xC7 | name, pinA:INT, pinB:INT, freq:INT, dutyA:INT, dutyB:INT, deadtime_ns:INT | BOOL |
| `TEENSY_PWM_FAULT` | 0xC8 | name, fault_pin:INT, active_low:BOOL | BOOL |
| `TEENSY_SERVO` | 0xC9 | name, pin:INT, angle:INT | BOOL |
| `TEENSY_I2C_SCAN` | 0xCA | name | STRING |
| `TEENSY_I2C_WRITE` | 0xCB | name, addr:INT, data_hex:STRING | BOOL |
| `TEENSY_I2C_READ` | 0xCC | name, addr:INT, count:INT | STRING (hex) |
| `TEENSY_I2C_WRITE_READ` | 0xCD | name, addr:INT, write_hex:STRING, read_count:INT | STRING (hex) |
| `TEENSY_SPI_TRANSFER` | 0xCE | name, cs_pin:INT, speed_hz:INT, mode:INT, data_hex:STRING | STRING (hex) |
| `TEENSY_UART_INIT` | 0xD0 | name, ch:INT, tx_pin:INT, rx_pin:INT, baud:INT | BOOL |
| `TEENSY_UART_SEND` | 0xD1 | name, ch:INT, data_hex:STRING | BOOL |
| `TEENSY_UART_RECV` | 0xD2 | name, ch:INT, max_len:INT, timeout_ms:INT | STRING (hex) |
| `TEENSY_OLED_INIT` | 0xD3 | name, addr:INT | BOOL |
| `TEENSY_OLED_CLEAR` | 0xD4 | name | BOOL |
| `TEENSY_OLED_PRINT` | 0xD5 | name, row:INT, text:STRING | BOOL |
| `TEENSY_NEOPIXEL` | 0xD6 | name, pin:INT, index:INT, r:INT, g:INT, b:INT | BOOL |
| `TEENSY_NEO_STRIP` | 0xD7 | name, pin:INT, count:INT, colors_json:STRING | BOOL |
| `TEENSY_CAN_INIT` | 0xD8 | name, bitrate:INT | BOOL |
| `TEENSY_CAN_SEND` | 0xD9 | name, id:INT, data_hex:STRING | BOOL |
| `TEENSY_CAN_RECV` | 0xDA | name, timeout_ms:INT | STRING (JSON) |
| `TEENSY_CAN_FILTER` | 0xDB | name, id:INT, mask:INT | BOOL |
| `TEENSY_CAN_STATUS` | 0xDC | name | STRING (JSON) |
| `TEENSY_ENCODER_INIT` | 0xDD | name, pinA:INT, pinB:INT | BOOL |
| `TEENSY_ENCODER_READ` | 0xDE | name | INT (signed) |
| `TEENSY_ENCODER_RESET` | 0xDF | name | BOOL |
| `TEENSY_FREQ_INIT` | 0xE0 | name, pin:INT | BOOL |
| `TEENSY_FREQ_READ` | 0xE1 | name | REAL (Hz) |
| `TEENSY_PID_CONFIG` | 0xE2 | name, input_pin:INT, output_pin:INT, kp:REAL, ki:REAL, kd:REAL | BOOL |
| `TEENSY_PID_SETPOINT` | 0xE3 | name, setpoint:INT | BOOL |
| `TEENSY_PID_READ` | 0xE4 | name | STRING (JSON) |
| `TEENSY_PID_TUNE` | 0xE5 | name, kp:REAL, ki:REAL, kd:REAL | BOOL |
| `TEENSY_PID_STOP` | 0xE6 | name | BOOL |
| `TEENSY_RTC_GET` | 0xE7 | name | STRING (ISO 8601) |
| `TEENSY_RTC_SET` | 0xE8 | name, timestamp:STRING | BOOL |
| `TEENSY_TRNG_READ` | 0xE9 | name | INT |
| `TEENSY_TEMP_READ` | 0xEA | name | INT (degrees C) |
| `TEENSY_DISTANCE` | 0xEB | name, trig:INT, echo:INT | INT (mm) |
| `TEENSY_BOOTLOADER` | 0xFF | name | BOOL |

---

*GoPLC v1.0.533 | Firmware: Rust (USB RawHID) | Teensy 4.0 (i.MX RT1062) @ 600 MHz*
*47 ST functions | Command opcodes 0xC0-0xFF*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
