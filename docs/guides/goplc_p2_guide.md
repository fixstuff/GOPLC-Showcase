# GoPLC + Parallax Propeller 2: Hardware Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC treats the Propeller 2 as a **smart I/O module** — not a compilation target. The P2 runs a Spin2 firmware (~35KB) that GoPLC uploads automatically at boot via the ROM bootloader. All hardware control flows through USB serial at 3 Mbaud.

There are **two ways** to control a P2 from GoPLC:

| Mode | Interface | Best For |
|------|-----------|----------|
| **Binary Protocol** | `P2_INIT` / `P2_CMD` + convenience functions | Production — structured commands, schema-validated, CRC-protected |
| **Direct Serial (TAQOZ)** | `SER_OPEN` / `SER_WRITE_STR` | Rapid prototyping — send Forth words directly to the P2 ROM interpreter |

The binary protocol offers **two calling styles**: the universal `P2_CMD` function (accepts any command by name) and **37 convenience functions** like `P2_PIN_WRITE`, `P2_UART_SETUP`, etc. that provide a familiar, typed interface. Both styles route through the same schema-driven binary protocol — the convenience functions are thin wrappers over `P2_CMD`.

Both modes use IEC 61131-3 Structured Text as the programming language in GoPLC's browser-based IDE.

### System Diagram

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)         │
│                                                     │
│  ┌──────────────┐  ┌────────────────────────────┐   │
│  │ ST Program   │  │ ST Program                 │   │
│  │ (TAQOZ mode) │  │ (Binary Protocol mode)     │   │
│  │              │  │                            │   │
│  │ SER_OPEN()   │  │ P2_INIT()                  │   │
│  │ SER_WRITE_STR│  │ P2_CMD('pin_write',...)    │   │
│  │ SER_READ_STR │  │ P2_CMD('uart_setup',...)   │   │
│  └──────┬───────┘  └──────────┬─────────────────┘   │
│         │                     │                     │
│         │  Raw serial text    │  Binary frames      │
│         │  (115200 baud)      │  (3 Mbaud, CRC16)   │
└─────────┼─────────────────────┼─────────────────────┘
          │                     │
          │    USB Serial       │
          ▼                     ▼
┌─────────────────────────────────────────────────────┐
│  Parallax Propeller 2 (Rev G, 200 MHz)              │
│                                                     │
│  TAQOZ Forth        │   cyclic_io.spin2 firmware    │
│  (ROM interpreter)  │   (uploaded at P2_INIT)       │
│                     │                               │
│  Cog 0: Forth REPL  │   Cog 0: Frame dispatch       │
│                     │   Cog N: Servo interpolation   │
│                     │   Cog N: UART RX (PASM2)       │
│                     │   Cog N: Eye rendering          │
│                     │                               │
│  64 Smart Pins: GPIO, PWM, ADC, DAC, UART,          │
│  I2C, SPI, Encoder, Frequency, NCO                   │
└─────────────────────────────────────────────────────┘
```

---

## 2. Mode 1: Binary Protocol (P2_CMD)

This is the production interface. GoPLC uploads firmware, establishes a CRC-protected binary link at 3 Mbaud, and provides 44 schema-driven commands through a single `P2_CMD` function.

### 2.1 Core Functions

```iecst
(* Connect to P2 and upload firmware *)
ok := P2_INIT('myp2', '/dev/ttyUSB2');

(* Send any command — two calling conventions *)
result := P2_CMD('myp2', 'pin_write', 'pin', 16, 'value', 1);      (* key-value *)
result := P2_CMD('myp2', 'pin_write', '{"pin": 16, "value": 1}');   (* JSON *)

(* Check connection health *)
status := P2_STATUS('myp2');
(* Returns: {"connected":true,"mode":"cyclic","ping_us":245} *)

(* Disconnect *)
P2_CLOSE('myp2');
```

### 2.2 Convenience Functions

For users who prefer dedicated function calls over `P2_CMD` string commands, GoPLC provides **37 convenience functions** that map 1:1 to binary protocol commands. They are thin wrappers — internally they call `P2_CMD` with the correct parameters.

```iecst
(* These two lines do exactly the same thing: *)
P2_CMD('p2', 'pin_write', 'pin', 16, 'value', 1);     (* P2_CMD style *)
P2_PIN_WRITE('p2', 16, 1);                              (* Convenience style *)

(* Read a pin — convenience function returns the value directly *)
val := P2_PIN_READ('p2', 0);           (* Returns: INT — 0 or 1 *)
result := P2_CMD('p2', 'pin_read', 'pin', 0);  (* Returns: '{"value": 0}' *)
```

**Key difference:** Convenience functions return **native types** (BOOL, INT, STRING) directly, while `P2_CMD` always returns a JSON string that you parse. Use whichever style fits your program.

| Style | Pros | Best For |
|-------|------|----------|
| **Convenience** (`P2_PIN_WRITE`, etc.) | Cleaner syntax, typed returns, easier to read | Beginners, simple I/O, quick prototyping |
| **P2_CMD** | Access to all 44 commands including future additions, full JSON response | Power users, complex parameters, servo_batch |

### 2.2 Wire Protocol

Every `P2_CMD` call is packed into a binary frame:

```
┌──────┬──────┬─────┬─────┬────────┬──────────────┬────────┐
│ 0xA5 │ 0x5A │ SEQ │ CMD │ LEN(2) │ PAYLOAD(0-N) │ CRC(2) │
│ sync │ sync │  1B │  1B │  LE    │  LE fields   │ MODBUS │
└──────┴──────┴─────┴─────┴────────┴──────────────┴────────┘
```

- CRC-16/MODBUS over SEQ + CMD + LEN + PAYLOAD
- Max payload: 1024 bytes
- All multi-byte values: little-endian
- Response uses same frame format

You never build frames manually — `P2_CMD` handles packing/unpacking via the `p2_commands.json` schema.

---

## 3. Command Reference

### 3.1 System Commands

#### ping — Heartbeat

```iecst
P2_CMD('p2', 'ping');
```

No parameters, no response payload. Verifies the link is alive.

#### version — Firmware Version

```iecst
result := P2_CMD('p2', 'version');
(* Returns: {"version": 65537} *)
```

#### status — Device Status

```iecst
result := P2_CMD('p2', 'status');
(* Returns: {"status": 1}  — 1=OK, 128=ERROR *)
```

#### fw_info — Full Firmware Configuration

```iecst
result := P2_CMD('p2', 'fw_info');
(* Returns: {"version":65537,"clkfreq":200000000,
             "num_din":16,"num_dout":16,"num_ain":4,"num_aout":4} *)
```

---

### 3.2 Digital I/O

#### pin_mode — Configure Pin Direction

| Param | Type | Values |
|-------|------|--------|
| `pin` | u8 | 0-63 (P62-P63 reserved for host serial) |
| `mode` | u8 | 0=INPUT (float), 1=OUTPUT_LOW, 2=OUTPUT_HIGH, 3=OPEN_DRAIN, 4=OPEN_SOURCE |

```iecst
(* Set pin 16 as output *)
P2_CMD('p2', 'pin_mode', 'pin', 16, 'mode', 1);
```

**Convenience:** `P2_PIN_MODE(name, pin, mode) : BOOL`

```iecst
ok := P2_PIN_MODE('p2', 16, 1);
```

#### pin_read — Read Digital State

```iecst
result := P2_CMD('p2', 'pin_read', 'pin', 0);
(* Returns: {"value": 1} or {"value": 0} *)
```

**Convenience:** `P2_PIN_READ(name, pin) : INT` — returns 0 or 1 directly

```iecst
val := P2_PIN_READ('p2', 0);
```

> **P2 Note:** Pins read 5V signals as FALSE. Use 3.3V logic or external level shifting.

#### pin_write — Set Digital Output

```iecst
P2_CMD('p2', 'pin_write', 'pin', 16, 'value', 1);
```

**Convenience:** `P2_PIN_WRITE(name, pin, value) : BOOL`

```iecst
P2_PIN_WRITE('p2', 16, 1);
```

#### pin_toggle — Toggle Digital Output

**Convenience only:** `P2_PIN_TOGGLE(name, pin) : BOOL` — reads the current state and writes the inverse. No single `P2_CMD` equivalent (requires two commands internally).

```iecst
P2_PIN_TOGGLE('p2', 16);
```

#### Example: Digital I/O Scan Loop

```iecst
PROGRAM POU_DigitalIO
VAR
    sensor_in : BOOL;
    result : STRING;
END_VAR

(* Read sensor on pin 0 *)
result := P2_CMD('p2', 'pin_read', 'pin', 0);

(* Drive output on pin 16 based on input *)
IF sensor_in THEN
    P2_CMD('p2', 'pin_write', 'pin', 16, 'value', 1);
ELSE
    P2_CMD('p2', 'pin_write', 'pin', 16, 'value', 0);
END_IF;
END_PROGRAM
```

**Same example using convenience functions:**

```iecst
PROGRAM POU_DigitalIO
VAR
    sensor_in : INT;
END_VAR

sensor_in := P2_PIN_READ('p2', 0);

IF sensor_in = 1 THEN
    P2_PIN_WRITE('p2', 16, 1);
ELSE
    P2_PIN_WRITE('p2', 16, 0);
END_IF;
END_PROGRAM
```

---

### 3.3 Smart Pin (Raw Access)

For advanced P2 users who want direct smart pin register control. These map directly to `pinstart()`, `rdpin()`, `wypin()`, `pinfloat()+pinclear()`.

#### smartpin_start — Configure Smart Pin

| Param | Type | Description |
|-------|------|-------------|
| `pin` | u8 | Pin number |
| `mode` | u32 | Smart pin mode register (P_OE, P_PWM_SAWTOOTH, etc.) |
| `x` | u32 | X register (base period/frequency) |
| `y` | u32 | Y register (initial value) |

```iecst
(* Start NCO frequency output on pin 10 *)
P2_CMD('p2', 'smartpin_start', 'pin', 10,
       'mode', 16#00004C58,    (* P_NCO_FREQ | P_OE *)
       'x', 10,
       'y', 858993459);       (* 1kHz at 200MHz: freq * 2^32 / clkfreq *)
```

**Convenience:** `P2_SMARTPIN_START(name, pin, mode, x, y) : BOOL`

```iecst
P2_SMARTPIN_START('p2', 10, 16#00004C58, 10, 858993459);
```

> **Critical:** Smart pin X register packing varies by mode. For PWM/servo modes, X.word[0] = clocks per microsecond, X.word[1] = period in microseconds. See JonnyMac's OBEX objects (`jm_servo.spin2`, `jm_pwm.spin2`) for correct patterns. The higher-level `pwm_setup` and `servo_move` commands handle this packing for you.

#### smartpin_read / smartpin_write / smartpin_stop

```iecst
raw := P2_CMD('p2', 'smartpin_read', 'pin', 10);
(* Returns: {"value": 12345} *)

P2_CMD('p2', 'smartpin_write', 'pin', 10, 'value', 500);

P2_CMD('p2', 'smartpin_stop', 'pin', 10);
```

**Convenience functions:**

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_SMARTPIN_READ` | `(name, pin)` | INT — raw 32-bit value |
| `P2_SMARTPIN_WRITE` | `(name, pin, value)` | BOOL |
| `P2_SMARTPIN_STOP` | `(name, pin)` | BOOL |

```iecst
raw := P2_SMARTPIN_READ('p2', 10);
P2_SMARTPIN_WRITE('p2', 10, 500);
P2_SMARTPIN_STOP('p2', 10);
```

---

### 3.4 UART

Up to 16 channels via smart pin async serial. A dedicated PASM2 RX cog polls all active channels at ~0.4 us per scan cycle with 256-byte ring buffers per channel.

#### uart_setup — Open Channel

| Param | Type | Description |
|-------|------|-------------|
| `ch` | u8 | Channel 0-15 |
| `tx_pin` | u8 | Transmit pin |
| `rx_pin` | u8 | Receive pin |
| `baud` | u32 | Baud rate |

```iecst
(* DF Mini MP3 player on UART ch0 *)
P2_CMD('p2', 'uart_setup', 'ch', 0, 'tx_pin', 30, 'rx_pin', 29, 'baud', 9600);
```

**Convenience:** `P2_UART_SETUP(name, ch, txPin, rxPin, baud) : BOOL`

```iecst
P2_UART_SETUP('p2', 0, 30, 29, 9600);
```

#### uart_tx — Send Data

Data is hex-encoded. `48656C6C6F` = "Hello".

```iecst
(* Send DF Mini play command: 7E FF 06 03 00 00 01 EF *)
P2_CMD('p2', 'uart_tx', 'ch', 0, 'data', '7EFF060300000001EF');
```

**Convenience:** `P2_UART_SEND(name, ch, hexData) : INT` — returns bytes sent

```iecst
count := P2_UART_SEND('p2', 0, '7EFF060300000001EF');
```

#### uart_rx — Receive Data

```iecst
(* Read up to 32 bytes with 100ms timeout *)
result := P2_CMD('p2', 'uart_rx', 'ch', 0, 'max_len', 32, 'timeout_ms', 100);
(* Returns: {"count": 5, "data": "7EFF060000..."} *)
```

**Convenience:** `P2_UART_RECV(name, ch, maxLen, timeoutMs) : STRING` — returns hex data directly

```iecst
data := P2_UART_RECV('p2', 0, 32, 100);
```

> **Timing Note:** UART RX is a blocking acyclic command. The 2-second acyclic timeout accommodates slow devices. For high-throughput serial, the PASM2 RX cog buffers incoming data between polls.

#### uart_txrx — Send Then Receive

```iecst
(* Loopback test: send and receive in one frame *)
result := P2_CMD('p2', 'uart_txrx', 'ch', 0, 'timeout_ms', 50, 'data', '48656C6C6F');
```

**Convenience:** `P2_UART_TXRX(name, ch, hexData, timeoutMs) : STRING` — returns hex response

```iecst
resp := P2_UART_TXRX('p2', 0, '48656C6C6F', 50);
```

#### uart_stop — Close Channel

```iecst
P2_CMD('p2', 'uart_stop', 'ch', 0);
```

**Convenience:** `P2_UART_STOP(name, ch) : BOOL`

```iecst
P2_UART_STOP('p2', 0);
```

---

### 3.5 I2C

Up to 8 buses. Uses `jm_i2c.spin2` from the Parallax OBEX for reliable bit-bang I2C.

#### i2c_setup — Open Bus

| Param | Type | Description |
|-------|------|-------------|
| `ch` | u8 | Channel 0-7 |
| `scl` | u8 | Clock pin |
| `sda` | u8 | Data pin |
| `speed_khz` | u16 | Clock speed (100 or 400 typical) |

```iecst
(* I2C bus on pins 10/11 at 400kHz *)
P2_CMD('p2', 'i2c_setup', 'ch', 0, 'scl', 10, 'sda', 11, 'speed_khz', 400);
```

**Convenience:** `P2_I2C_SETUP(name, ch, scl, sda, speedKHz) : BOOL`

```iecst
P2_I2C_SETUP('p2', 0, 10, 11, 400);
```

#### i2c_xfer — Read/Write Transfer

| Param | Type | Description |
|-------|------|-------------|
| `ch` | u8 | Channel |
| `addr` | u8 | 7-bit device address |
| `flags` | u8 | Bit 0 = no stop (repeated START) |
| `write_len` | u8 | Bytes to write |
| `read_len` | u8 | Bytes to read |
| `write_data` | bytes | Hex-encoded write data |

```iecst
(* Read 2 bytes from temperature sensor at 0x48 register 0x00 *)
result := P2_CMD('p2', 'i2c_xfer', 'ch', 0, 'addr', 72,
                 'flags', 0, 'write_len', 1, 'read_len', 2, 'write_data', '00');
(* Returns: {"ack": 1, "read_data": "0C80"} — ack=1 means device responded *)

(* Write command byte 0xAE to OLED at 0x3C *)
P2_CMD('p2', 'i2c_xfer', 'ch', 0, 'addr', 60,
       'flags', 0, 'write_len', 1, 'read_len', 0, 'write_data', 'AE');

(* I2C scan — probe address, check ack *)
result := P2_CMD('p2', 'i2c_xfer', 'ch', 0, 'addr', 60,
                 'flags', 0, 'write_len', 0, 'read_len', 0, 'write_data', '');
(* ack=1 means device present, ack=0 means no response *)
```

**Convenience functions** simplify `i2c_xfer` into purpose-specific calls (flags and lengths are handled automatically):

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_I2C_WRITE` | `(name, ch, addr, hexData)` | BOOL — write_len auto-calculated from data |
| `P2_I2C_WRITE_BYTE` | `(name, ch, addr, byteValue)` | BOOL — writes a single byte |
| `P2_I2C_READ` | `(name, ch, addr, readLen)` | STRING — hex read_data |
| `P2_I2C_WRITE_READ` | `(name, ch, addr, hexWriteData, readLen)` | STRING — hex read_data |

```iecst
(* Write command byte 0xAE to OLED at 0x3C *)
P2_I2C_WRITE('p2', 0, 60, 'AE');
P2_I2C_WRITE_BYTE('p2', 0, 60, 16#AE);     (* same thing, integer arg *)

(* Read 2 bytes from temp sensor at 0x48, register 0x00 *)
data := P2_I2C_WRITE_READ('p2', 0, 72, '00', 2);   (* Returns: '0C80' *)

(* Pure read — 4 bytes from address 0x50 *)
data := P2_I2C_READ('p2', 0, 80, 4);
```

#### i2c_stop — Close Bus

```iecst
P2_CMD('p2', 'i2c_stop', 'ch', 0);
```

**Convenience:** `P2_I2C_STOP(name, ch) : BOOL`

```iecst
P2_I2C_STOP('p2', 0);
```

---

### 3.6 SPI

Up to 8 channels. Uses smart pin synchronous serial for MOSI/MISO with NCO clock generation.

#### spi_setup — Open Channel

| Param | Type | Description |
|-------|------|-------------|
| `ch` | u8 | Channel 0-7 |
| `clk` | u8 | Clock pin |
| `mosi` | u8 | Master Out pin (255 = unused) |
| `miso` | u8 | Master In pin (255 = unused) |
| `cs` | u8 | Chip Select pin (255 = manual) |
| `speed_khz` | u16 | Clock speed |
| `mode` | u8 | SPI mode 0-3 |

```iecst
P2_CMD('p2', 'spi_setup', 'ch', 0,
       'clk', 40, 'mosi', 41, 'miso', 42, 'cs', 43,
       'speed_khz', 1000, 'mode', 0);
```

**Convenience:** `P2_SPI_SETUP(name, ch, clk, mosi, miso, cs, speedKHz, mode) : BOOL`

```iecst
P2_SPI_SETUP('p2', 0, 40, 41, 42, 43, 1000, 0);
```

#### spi_xfer — Transfer Data

| Flag Bit | Meaning |
|----------|---------|
| 0 (0x01) | Assert CS |
| 1 (0x02) | Deassert CS |
| 2 (0x04) | Read (return rx_data) |

```iecst
(* Full duplex: assert CS, transfer, deassert CS, read response *)
result := P2_CMD('p2', 'spi_xfer', 'ch', 0, 'flags', 7, 'tx_data', 'FF00');
(* Returns: {"rx_data": "a5b7"} *)

(* Write-only (no read flag): flags = 3 *)
P2_CMD('p2', 'spi_xfer', 'ch', 0, 'flags', 3, 'tx_data', 'DEADBEEF');
```

**Convenience:** `P2_SPI_XFER(name, ch, flags, hexTxData) : STRING` — returns hex rx_data

```iecst
rx := P2_SPI_XFER('p2', 0, 7, 'FF00');          (* Returns: 'a5b7' *)
P2_SPI_XFER('p2', 0, 3, 'DEADBEEF');            (* Write-only *)
```

#### spi_stop

```iecst
P2_CMD('p2', 'spi_stop', 'ch', 0);
```

**Convenience:** `P2_SPI_STOP(name, ch) : BOOL`

```iecst
P2_SPI_STOP('p2', 0);
```

---

### 3.7 ADC / DAC

#### adc_setup — Configure Analog Input

14-bit ADC with auto-calibration (GIO/VIO reference). Returns calibrated millivolts.

| Gain | Multiplier | Use Case |
|------|-----------|----------|
| 0 | 1x | General purpose (0-3.3V) |
| 1 | 3.16x | |
| 2 | 10x | Small signals |
| 3 | 31.6x | |
| 4 | 100x | Millivolt-level signals |

```iecst
P2_CMD('p2', 'adc_setup', 'pin', 44, 'gain', 0);
```

**Convenience:** `P2_ADC_SETUP(name, pin, gain) : BOOL`

```iecst
P2_ADC_SETUP('p2', 44, 0);
```

#### adc_read — Read Millivolts

```iecst
result := P2_CMD('p2', 'adc_read', 'pin', 44);
(* Returns: {"millivolts": 1650} — signed i32, can be negative *)
```

**Convenience:** `P2_ADC_READ(name, pin) : INT` — returns millivolts directly

```iecst
mv := P2_ADC_READ('p2', 44);    (* Returns: 1650 *)
```

#### dac_setup / dac_write — Analog Output

16-bit DAC (PWM dithered, 990 ohm, 0-3.3V).

```iecst
P2_CMD('p2', 'dac_setup', 'pin', 45);
P2_CMD('p2', 'dac_write', 'pin', 45, 'value', 32768);   (* ~1.65V *)
```

**Convenience:** `P2_DAC_SETUP(name, pin) : BOOL` / `P2_DAC_WRITE(name, pin, value) : BOOL`

```iecst
P2_DAC_SETUP('p2', 45);
P2_DAC_WRITE('p2', 45, 32768);
```

#### Example: Analog Read Loop

```iecst
PROGRAM POU_AnalogMonitor
VAR
    mv : STRING;
    voltage : REAL;
END_VAR

mv := P2_CMD('p2', 'adc_read', 'pin', 44);
(* Parse millivolts from JSON, scale to engineering units *)
(* voltage := JSON_GET_INT(mv, 'millivolts') / 1000.0; *)
END_PROGRAM
```

**Same example using convenience functions:**

```iecst
PROGRAM POU_AnalogMonitor
VAR
    mv : INT;
    voltage : REAL;
END_VAR

mv := P2_ADC_READ('p2', 44);
voltage := INT_TO_REAL(mv) / 1000.0;
END_PROGRAM
```

---

### 3.8 PWM

General-purpose PWM with configurable frequency and 16-bit duty resolution.

```iecst
(* 1 kHz PWM at 50% duty on pin 16 *)
P2_CMD('p2', 'pwm_setup', 'pin', 16, 'freq', 1000);
P2_CMD('p2', 'pwm_duty', 'pin', 16, 'duty', 32768);     (* 50% = 32768/65535 *)

(* Dim to 25% *)
P2_CMD('p2', 'pwm_duty', 'pin', 16, 'duty', 16384);

(* Stop *)
P2_CMD('p2', 'pwm_stop', 'pin', 16);
```

**Convenience:** `P2_PWM_SETUP(name, pin, freqHz) : BOOL` / `P2_PWM_DUTY(name, pin, duty) : BOOL` / `P2_PWM_STOP(name, pin) : BOOL`

```iecst
P2_PWM_SETUP('p2', 16, 1000);
P2_PWM_DUTY('p2', 16, 32768);
P2_PWM_DUTY('p2', 16, 16384);
P2_PWM_STOP('p2', 16);
```

> **Under the hood:** Uses `P_OE | P_PWM_SAWTOOTH` with X register packed per JonnyMac pattern: `x.word[0] = (clkfreq/freq)/units`, `x.word[1] = units`. `pwm_setup` handles this packing for you.

---

### 3.9 Servo Control

Dedicated servo cog runs at 50 Hz, reading target positions from hub RAM and smoothly interpolating via `wypin`. Up to 10 simultaneous channels.

#### servo_move — Single Servo

| Param | Type | Description |
|-------|------|-------------|
| `pin` | u8 | Servo signal pin |
| `duty` | u16 | Pulse width in microseconds (500-2600 typical) |
| `speed` | i16 | Interpolation: 0=instant, positive=divisor (5=default, 20=slow), negative=-deg/sec |

```iecst
(* Move to center, instant *)
P2_CMD('p2', 'servo_move', 'pin', 0, 'duty', 1500, 'speed', 0);

(* Move to 2000us with smooth easing (divisor 5) *)
P2_CMD('p2', 'servo_move', 'pin', 0, 'duty', 2000, 'speed', 5);

(* Move at constant 90 deg/sec *)
P2_CMD('p2', 'servo_move', 'pin', 0, 'duty', 500, 'speed', -90);
```

**Convenience:** `P2_SERVO_MOVE(name, pin, duty, speed) : BOOL`

```iecst
P2_SERVO_MOVE('p2', 0, 1500, 0);       (* center, instant *)
P2_SERVO_MOVE('p2', 0, 2000, 5);       (* ease to 2000us *)
P2_SERVO_MOVE('p2', 0, 500, -90);      (* 90 deg/sec *)
```

> **Servo Cog Interpolation:** The firmware's servo cog runs independently at 50 Hz. Each cycle it computes `delta = (target - current) / divisor + 1` and updates `wypin`. This produces smooth exponential easing — the servo decelerates as it approaches the target. Your ST code only sets the target; the cog handles the motion.

#### servo_batch — Synchronized Multi-Servo Update

Updates multiple servos in a single atomic command. Requires JSON calling convention for the array parameter.

```iecst
(* Move 4 servos simultaneously *)
P2_CMD('p2', 'servo_batch',
    '{"count": 4, "entries": [
        {"pin": 0, "duty": 1500},
        {"pin": 2, "duty": 1200},
        {"pin": 4, "duty": 1800},
        {"pin": 6, "duty": 1500}
    ]}');
(* Returns: {"updated": 4} *)
```

#### Example: 8-Servo Robot (Megabite Dog Demo)

```iecst
PROGRAM POU_Servo
VAR
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Initialize — set all servos to neutral *)
        P2_CMD('p2', 'servo_batch',
            '{"count": 8, "entries": [
                {"pin": 0,  "duty": 1500},
                {"pin": 2,  "duty": 1500},
                {"pin": 4,  "duty": 1500},
                {"pin": 6,  "duty": 1500},
                {"pin": 41, "duty": 1500},
                {"pin": 43, "duty": 1500},
                {"pin": 45, "duty": 1500},
                {"pin": 47, "duty": 1500}
            ]}');
        state := 1;

    1: (* Running — update servos from control logic *)
        P2_CMD('p2', 'servo_move', 'pin', 0, 'duty', 1200, 'speed', 5);
        P2_CMD('p2', 'servo_move', 'pin', 47, 'duty', 1800, 'speed', 5);
END_CASE;
END_PROGRAM
```

---

### 3.10 Quadrature Encoder

Uses the P2's built-in `P_QUADRATURE` smart pin mode.

```iecst
(* Setup encoder on pins 8 (A) and 9 (B) *)
P2_CMD('p2', 'enc_setup', 'pinA', 8, 'pinB', 9);

(* Read position — signed 32-bit, tracks direction *)
result := P2_CMD('p2', 'enc_read', 'pinA', 8);
(* Returns: {"count": -42} *)

(* Zero the counter *)
P2_CMD('p2', 'enc_reset', 'pinA', 8);
```

**Convenience:** `P2_ENC_SETUP(name, pinA, pinB) : BOOL` / `P2_ENC_READ(name, pinA) : INT` / `P2_ENC_RESET(name, pinA) : BOOL`

```iecst
P2_ENC_SETUP('p2', 8, 9);
pos := P2_ENC_READ('p2', 8);     (* Returns: -42 *)
P2_ENC_RESET('p2', 8);
```

---

### 3.11 Frequency Counter

```iecst
(* Measure frequency on pin 10 with 100ms gate *)
P2_CMD('p2', 'freq_setup', 'pin', 10, 'gate_ms', 100);

result := P2_CMD('p2', 'freq_read', 'pin', 10);
(* Returns: {"hz": 1000, "duty": 500} — 1kHz at 50% duty *)
```

**Convenience:** `P2_FREQ_SETUP(name, pin, gateMs) : BOOL` / `P2_FREQ_READ(name, pin) : INT` — returns Hz

```iecst
P2_FREQ_SETUP('p2', 10, 100);
hz := P2_FREQ_READ('p2', 10);    (* Returns: 1000 *)
```

> **Known Issue:** The frequency counter has a bus fight when `DIR=1` conflicts with an external signal and `rdpin` resets the counter. A firmware redesign is planned.

---

### 3.12 OLED Display (SSD1306)

Firmware-native text rendering — the P2 renders a built-in 5x7 ASCII font directly. 21 characters x 8 rows on a 128x64 OLED.

```iecst
(* I2C bus must be set up first *)
P2_CMD('p2', 'i2c_setup', 'ch', 0, 'scl', 10, 'sda', 11, 'speed_khz', 400);

(* Initialize OLED on I2C ch0 at address 0x3C *)
P2_CMD('p2', 'oled_init', 'ch', 0, 'addr', 60);
P2_CMD('p2', 'oled_clear', 'ch', 0);

(* Print text — rows 0-7 *)
P2_CMD('p2', 'oled_print', 'row', 0, 'text', 'GoPLC v1.0.533');
P2_CMD('p2', 'oled_print', 'row', 2, 'text', 'Scan: 2ms');
P2_CMD('p2', 'oled_print', 'row', 4, 'text', 'Status: RUNNING');
```

**Convenience:** `P2_OLED_INIT(name, ch, addr) : BOOL` / `P2_OLED_CLEAR(name, ch) : BOOL` / `P2_OLED_PRINT(name, row, text) : BOOL`

```iecst
P2_I2C_SETUP('p2', 0, 10, 11, 400);

P2_OLED_INIT('p2', 0, 60);
P2_OLED_CLEAR('p2', 0);

P2_OLED_PRINT('p2', 0, 'GoPLC v1.0.533');
P2_OLED_PRINT('p2', 2, 'Scan: 2ms');
P2_OLED_PRINT('p2', 4, 'Status: RUNNING');
```

---

### 3.13 Eye Display (Animated OLED)

Pixel-level animated eye rendering on SSD1306 OLEDs. A dedicated P2 cog handles smooth pupil interpolation and framebuffer rendering independently of the host.

#### eye_start — Initialize Eye

```iecst
(* Left eye: SDA=11, SCL=10, addr 0x3C *)
P2_CMD('p2', 'eye_start', 'sda', 11, 'scl', 10, 'addr', 60);

(* Right eye: SDA=25, SCL=24, addr 0x3C — separate I2C bus *)
P2_CMD('p2', 'eye_start', 'sda', 25, 'scl', 24, 'addr', 60);
```

> **Two OLEDs at same address:** Use separate I2C buses (different SDA/SCL pins). The eye cog manages each independently.

#### eye_move — Pupil Position

```iecst
(* Look center: x=64, y=32 on 128x64 display *)
P2_CMD('p2', 'eye_move', 'eye', 0, 'x', 64, 'y', 32);

(* Look right *)
P2_CMD('p2', 'eye_move', 'eye', 0, 'x', 90, 'y', 32);

(* Look up-left *)
P2_CMD('p2', 'eye_move', 'eye', 0, 'x', 40, 'y', 20);
```

#### eye_pupil — Pupil Size

```iecst
P2_CMD('p2', 'eye_pupil', 'eye', 0, 'radius', 8);    (* small *)
P2_CMD('p2', 'eye_pupil', 'eye', 0, 'radius', 14);   (* large *)
```

#### eye_lid / eye_bottom_lid — Eyelid Position

```iecst
(* Blink *)
P2_CMD('p2', 'eye_lid', 'eye', 0, 'position', 64);         (* closed *)
P2_CMD('p2', 'eye_lid', 'eye', 0, 'position', 0);          (* open *)

(* Squint — partial close from bottom *)
P2_CMD('p2', 'eye_bottom_lid', 'eye', 0, 'position', 20);
```

#### eye_ring — Iris Ring

```iecst
P2_CMD('p2', 'eye_ring', 'eye', 0, 'radius', 23);   (* default *)
P2_CMD('p2', 'eye_ring', 'eye', 0, 'radius', 30);   (* wide iris *)
```

#### Example: Idle Eye Behavior

```iecst
PROGRAM POU_Eyes
VAR
    scan_count : DINT := 0;
    look_interval : DINT := 25;    (* ~2.5 sec at 100ms scan *)
    blink_interval : DINT := 50;   (* ~5 sec *)
    eye_x : INT := 64;
    eye_y : INT := 32;
END_VAR

scan_count := scan_count + 1;

(* Random look-around *)
IF (scan_count MOD look_interval) = 0 THEN
    eye_x := 44 + (scan_count MOD 40);   (* 44-84 range *)
    eye_y := 22 + (scan_count MOD 20);   (* 22-42 range *)
    P2_CMD('p2', 'eye_move', 'eye', 0, 'x', eye_x, 'y', eye_y);
    P2_CMD('p2', 'eye_move', 'eye', 1, 'x', eye_x, 'y', eye_y);
END_IF;

(* Periodic blink *)
IF (scan_count MOD blink_interval) = 0 THEN
    P2_CMD('p2', 'eye_lid', 'eye', 0, 'position', 64);
    P2_CMD('p2', 'eye_lid', 'eye', 1, 'position', 64);
END_IF;
IF (scan_count MOD blink_interval) = 2 THEN
    P2_CMD('p2', 'eye_lid', 'eye', 0, 'position', 0);
    P2_CMD('p2', 'eye_lid', 'eye', 1, 'position', 0);
END_IF;
END_PROGRAM
```

---

## 4. Mode 2: Direct Serial (TAQOZ Forth)

For rapid prototyping or leveraging the existing TAQOZ ecosystem, you can bypass the binary protocol entirely and talk to the P2's ROM-based Forth interpreter over raw serial.

### 4.1 Serial Port Functions

| Function | Description |
|----------|-------------|
| `SERIAL_FIND(search)` | Find port by vendor/product name. Returns port path. |
| `SER_OPEN(port, baud)` | Open serial connection. Returns handle. |
| `SER_WRITE_STR(handle, text)` | Send text string |
| `SER_READ_STR(handle)` | Read available text |
| `SER_READ_LINE(handle)` | Read until CR/LF |
| `SER_WRITE(handle, hex)` | Send raw binary (hex-encoded) |
| `SER_READ(handle, count)` | Read N bytes (hex-encoded) |
| `SER_FLUSH(handle)` | Flush buffers |
| `SER_SET_DTR(handle, val)` | Control DTR line |
| `SER_SET_RTS(handle, val)` | Control RTS line |
| `SER_CLOSE(handle)` | Close connection |

### 4.2 Entering TAQOZ

The P2 ROM contains TAQOZ Forth. To enter it from serial:

```iecst
PROGRAM POU_TaqozInit
VAR
    port : STRING;
    handle : STRING;
    resp : STRING;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Find Parallax device *)
        port := SERIAL_FIND('Parallax');
        IF LEN(port) > 0 THEN
            state := 1;
        END_IF;

    1: (* Open at 115200 *)
        handle := SER_OPEN(port, 115200);
        IF handle <> '' THEN
            state := 2;
        END_IF;

    2: (* Enter TAQOZ: send > ESC CR *)
        SER_WRITE_STR(handle, CONCAT('> ', CHR(27), CHR(13)));
        state := 3;

    3: (* Drain response *)
        resp := SER_READ_STR(handle);
        state := 4;

    4: (* Enter TAQOZ again (reliable entry) *)
        SER_WRITE_STR(handle, CONCAT('> ', CHR(27), CHR(13)));
        state := 5;

    5: (* Drain — now in TAQOZ# prompt *)
        resp := SER_READ_STR(handle);
        state := 10;

    10: (* Ready — send Forth commands *)
        (* ... *)
END_CASE;
END_PROGRAM
```

### 4.3 Controlling Hardware with Forth Words

Once in TAQOZ, you send Forth words as plain text:

```iecst
(* Blink pin 0: set HIGH, wait 500us, set LOW *)
SER_WRITE_STR(handle, CONCAT('0 HIGH 500 us 0 LOW', CHR(13)));

(* PWM output *)
SER_WRITE_STR(handle, CONCAT('1000 16 HZ', CHR(13)));    (* 1kHz on pin 16 *)

(* Read pin state *)
SER_WRITE_STR(handle, CONCAT('0 PIN@ .', CHR(13)));       (* prints 0 or 1 *)
resp := SER_READ_STR(handle);

(* Define a new Forth word *)
SER_WRITE_STR(handle, CONCAT(': BLINK  0 HIGH 500 ms 0 LOW 500 ms ;', CHR(13)));

(* Run it *)
SER_WRITE_STR(handle, CONCAT('BLINK', CHR(13)));
```

### 4.4 Servo Control via TAQOZ

The TAQOZ test project demonstrates direct servo pulse generation:

```iecst
(* Generate servo pulse: HIGH for pulse_us microseconds, then LOW *)
pulse_us := 500 + (angle * 2100) / 180;   (* 500-2600us range *)
cmd := CONCAT('0 HIGH ', INT_TO_STRING(pulse_us), ' us 0 LOW', CHR(13));
SER_WRITE_STR(handle, cmd);
```

This runs every scan cycle, producing a software-timed servo signal. For production use, the binary protocol's `servo_move` command with its dedicated interpolation cog is more precise.

### 4.5 TAQOZ Quick Reference (P2 Hardware Words)

| Category | Words |
|----------|-------|
| **Pin Control** | `HIGH LOW FLOAT PIN@` |
| **Smart Pin** | `WRPIN WXPIN WYPIN RDPIN RQPIN AKPIN WAITPIN WRACK` |
| **PWM/Freq** | `PWM SAW NCO HZ KHZ MHZ MUTE BLINK BIT` |
| **Pulse** | `PULSE PULSES HILO DUTY` |
| **Serial** | `BAUD TXD RXD TXDAT` |
| **Stack** | `DUP OVER SWAP ROT DROP + - * / AND OR XOR NOT` |
| **Control** | `IF ELSE THEN BEGIN UNTIL AGAIN DO LOOP FOR NEXT` |
| **Memory** | `C@ W@ @ C! W! ! +!` |
| **Display** | `. PRINT .DEC .HEX .BIN EMIT CR SPACE CLS` |
| **Timing** | `ms us CNT@ LAP .LAP .ms` |
| **Cogs** | `COG COGID COGINIT COGSTOP NEWCOG` |
| **System** | `REBOOT RESET HEX DEC BIN WORDS CLKHZ` |
| **Defining** | `: name ... ; VAR FORGET` |
| **SPI Flash** | `SFPINS SFWE SFWRPG SFERASE BACKUP RESTORE` |
| **SD Card** | `MOUNT DIR FOPEN FLOAD FGET FREAD FWRITE` |

> **432 total TAQOZ words** available in the P2 ROM. Use `WORDS` to list them all from the TAQOZ prompt.

---

## 5. Cyclic Exchange (Background I/O)

Independent of the acyclic commands above, the binary protocol firmware runs a **periodic cyclic exchange** at configurable scan rate (default 2ms). This provides deterministic digital and analog I/O without per-scan command overhead.

### How It Works

```
Every 2ms (configurable):
  Go runtime builds output frame:
    Digital[8 bytes] + Analog[N × 4 bytes]
                    ↓
            USB Serial (3 Mbaud)
                    ↓
  P2 firmware applies outputs to pins, reads inputs:
    Digital[8 bytes] + Analog[N × 4 bytes] + Status[1]
                    ↓
  Go runtime stores inputs via atomic (lock-free)
                    ↓
  ST code reads latest values (zero-latency)
```

- **64 digital I/O** (8 bytes, bit-packed)
- **4 analog inputs + 4 analog outputs** (configurable, 32-bit each)
- **Lock-free:** Uses `sync/atomic.Value` — no mutex on the hot path
- **Diagnostics:** Exchange count, CRC errors, timeouts, min/max/avg latency
- **Loss detection:** 10 consecutive errors = disconnected

### Bandwidth

At 3 Mbaud with default payload (24 bytes out + 25 bytes in + 16 bytes framing):

| Configuration | Max Exchange Rate | Notes |
|--------------|-------------------|-------|
| 8 DI + 8 DO | ~10 kHz | Minimum payload |
| 64 mixed I/O + 4 analog | ~1.1 kHz | Default config |
| Full 1024-byte payload | ~140 Hz | Maximum payload |

---

## 6. Timing Tiers

| Tier | Where It Runs | Latency | Use Case |
|------|--------------|---------|----------|
| **P2 cog (PASM2)** | On-chip, dedicated cog | ~10 ns/instruction | Servo interpolation, safety watchdog, UART RX buffering |
| **P2 cog (Spin2)** | On-chip, Spin2 bytecode | 3-10 us/word | Command dispatch, I2C/SPI transactions |
| **GoPLC scan** | Host CPU, ST interpreter | 1-50 ms | PID loops, state machines, sequencing |
| **GoPLC boss** | Cluster coordination | 10-100 ms | HMI, logging, multi-device orchestration |

The P2 handles time-critical operations locally (servo position updates at 50 Hz, UART RX at ~2.5 MHz equivalent poll rate) while GoPLC handles the logic, sequencing, and coordination.

---

## 7. Hardware Notes for P2 Users

### Pin Constraints

- **P62-P63**: Reserved for host serial TX/RX. Cannot be reconfigured.
- **P56-P63**: On-board LEDs on P2-EVAL. Available for general I/O but visual feedback is useful for debugging.
- **P2-EVAL isolated pin groups**: Not all pins share the same power group. Verify ground reference when connecting external devices.

### Smart Pin X Register Packing

This is the single biggest source of bugs when writing raw smart pin code:

| Mode | X.word[0] | X.word[1] |
|------|-----------|-----------|
| **Servo (PWM_SAWTOOTH)** | `clkfreq / 1_000_000` (clocks/us) | `20_000` (period in us) |
| **General PWM** | `(clkfreq / freq) / units` | `units` |
| **DC Motor** | `(clkfreq / (kHz*1000)) / 1000` | `1000` |

**Always check JonnyMac's OBEX objects** (`jm_servo.spin2`, `jm_pwm.spin2`) before implementing custom smart pin modes. AI training data has incorrect P2 register formats. The OBEX is the gold standard.

### Serial Gotchas

- **Linux HUPCL**: Linux serial close sends hangup signal, resetting the P2. Disable with `stty -hupcl /dev/ttyUSB2` or set `CLOCAL` in termios. GoPLC handles this automatically.
- **3.3V logic**: P2 pins read 5V as FALSE. Use 3.3V logic levels or external level shifters.
- **FTDI latency**: Default USB latency timer is 16ms. GoPLC sets it to 1ms automatically for responsive cyclic exchange.

### Firmware Cog Behavior

- **Cogs are launched at firmware init only.** Attempting to `cogspin` from a command handler fails silently. All dedicated cogs (servo, UART RX, eye rendering) start at boot and idle until configured.
- **Eye cog re-initialization:** When new eye displays are registered, the eye cog detects the count change and re-runs OLED init. Track `last_init_count` vs `eye_count`.

---

## Appendix A: Complete Command Quick Reference

| Command | Opcode | Request | Response |
|---------|--------|---------|----------|
| `ping` | 0x01 | — | — |
| `version` | 0x03 | — | version:u32 |
| `status` | 0x05 | — | status:u8 |
| `fw_info` | 0x30 | — | version:u32, clkfreq:u32, num_din:u8, num_dout:u8, num_ain:u8, num_aout:u8 |
| `pin_mode` | 0x20 | pin:u8, mode:u8 | ok:u8 |
| `pin_read` | 0x21 | pin:u8 | value:u8 |
| `pin_write` | 0x22 | pin:u8, value:u8 | ok:u8 |
| `smartpin_start` | 0x23 | pin:u8, mode:u32, x:u32, y:u32 | ok:u8 |
| `smartpin_read` | 0x24 | pin:u8 | value:u32 |
| `smartpin_write` | 0x25 | pin:u8, value:u32 | ok:u8 |
| `smartpin_stop` | 0x26 | pin:u8 | ok:u8 |
| `uart_setup` | 0x40 | ch:u8, tx_pin:u8, rx_pin:u8, baud:u32 | ok:u8 |
| `uart_tx` | 0x41 | ch:u8, data:bytes | count:u16 |
| `uart_rx` | 0x42 | ch:u8, max_len:u8, timeout_ms:u16 | count:u16, data:bytes |
| `uart_stop` | 0x43 | ch:u8 | ok:u8 |
| `uart_txrx` | 0x44 | ch:u8, timeout_ms:u16, data:bytes | count:u16, data:bytes |
| `i2c_setup` | 0x50 | ch:u8, scl:u8, sda:u8, speed_khz:u16 | ok:u8 |
| `i2c_xfer` | 0x51 | ch:u8, addr:u8, flags:u8, write_len:u8, read_len:u8, write_data:bytes | ack:u8, read_data:bytes |
| `i2c_stop` | 0x52 | ch:u8 | ok:u8 |
| `spi_setup` | 0x60 | ch:u8, clk:u8, mosi:u8, miso:u8, cs:u8, speed_khz:u16, mode:u8 | ok:u8 |
| `spi_xfer` | 0x61 | ch:u8, flags:u8, tx_data:bytes | rx_data:bytes |
| `spi_stop` | 0x62 | ch:u8 | ok:u8 |
| `oled_init` | 0x70 | ch:u8, addr:u8 | ok:u8 |
| `oled_clear` | 0x71 | ch:u8 | ok:u8 |
| `oled_print` | 0x72 | row:u8, text:string | ok:u8 |
| `eye_start` | 0x74 | sda:u8, scl:u8, addr:u8 | ok:u8 |
| `eye_move` | 0x75 | eye:u8, x:u8, y:u8 | ok:u8 |
| `eye_pupil` | 0x76 | eye:u8, radius:u8 | ok:u8 |
| `eye_lid` | 0x78 | eye:u8, position:u8 | ok:u8 |
| `eye_bottom_lid` | 0x79 | eye:u8, position:u8 | ok:u8 |
| `eye_ring` | 0x7A | eye:u8, radius:u8 | ok:u8 |
| `adc_setup` | 0x80 | pin:u8, gain:u8 | ok:u8 |
| `adc_read` | 0x81 | pin:u8 | millivolts:i32 |
| `dac_setup` | 0x82 | pin:u8 | ok:u8 |
| `dac_write` | 0x83 | pin:u8, value:u16 | ok:u8 |
| `pwm_setup` | 0x84 | pin:u8, freq:u32 | ok:u8 |
| `pwm_duty` | 0x85 | pin:u8, duty:u16 | ok:u8 |
| `pwm_stop` | 0x86 | pin:u8 | ok:u8 |
| `enc_setup` | 0x87 | pinA:u8, pinB:u8 | ok:u8 |
| `enc_read` | 0x88 | pinA:u8 | count:i32 |
| `enc_reset` | 0x89 | pinA:u8 | ok:u8 |
| `freq_setup` | 0x8A | pin:u8, gate_ms:u16 | ok:u8 |
| `freq_read` | 0x8B | pin:u8 | hz:u32, duty:u32 |
| `servo_batch` | 0x8C | count:u8, entries:[{pin:u8, duty:u16}] | updated:u8 |
| `servo_move` | 0x8D | pin:u8, duty:u16, speed:i16 | ok:u8 |

---

## Appendix B: Convenience Function Quick Reference

All convenience functions are thin wrappers over `P2_CMD`. They take the device name as the first argument and return native types instead of JSON strings.

### GPIO

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_PIN_MODE` | `(name, pin, mode)` | BOOL |
| `P2_PIN_READ` | `(name, pin)` | INT (0 or 1) |
| `P2_PIN_WRITE` | `(name, pin, value)` | BOOL |
| `P2_PIN_TOGGLE` | `(name, pin)` | BOOL (reads then inverts) |

### Smart Pins

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_SMARTPIN_START` | `(name, pin, mode, x, y)` | BOOL |
| `P2_SMARTPIN_READ` | `(name, pin)` | INT (raw 32-bit) |
| `P2_SMARTPIN_WRITE` | `(name, pin, value)` | BOOL |
| `P2_SMARTPIN_STOP` | `(name, pin)` | BOOL |

### UART

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_UART_SETUP` | `(name, ch, txPin, rxPin, baud)` | BOOL |
| `P2_UART_SEND` | `(name, ch, hexData)` | INT (bytes sent) |
| `P2_UART_RECV` | `(name, ch, maxLen, timeoutMs)` | STRING (hex data) |
| `P2_UART_TXRX` | `(name, ch, hexData, timeoutMs)` | STRING (hex response) |
| `P2_UART_STOP` | `(name, ch)` | BOOL |

### I2C

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_I2C_SETUP` | `(name, ch, scl, sda, speedKHz)` | BOOL |
| `P2_I2C_WRITE` | `(name, ch, addr, hexData)` | BOOL (write_len auto-calculated) |
| `P2_I2C_WRITE_BYTE` | `(name, ch, addr, byteValue)` | BOOL |
| `P2_I2C_READ` | `(name, ch, addr, readLen)` | STRING (hex read_data) |
| `P2_I2C_WRITE_READ` | `(name, ch, addr, hexWriteData, readLen)` | STRING (hex read_data) |
| `P2_I2C_STOP` | `(name, ch)` | BOOL |

### SPI

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_SPI_SETUP` | `(name, ch, clk, mosi, miso, cs, speedKHz, mode)` | BOOL |
| `P2_SPI_XFER` | `(name, ch, flags, hexTxData)` | STRING (hex rx_data) |
| `P2_SPI_STOP` | `(name, ch)` | BOOL |

### ADC / DAC

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_ADC_SETUP` | `(name, pin, gain)` | BOOL |
| `P2_ADC_READ` | `(name, pin)` | INT (millivolts, signed) |
| `P2_DAC_SETUP` | `(name, pin)` | BOOL |
| `P2_DAC_WRITE` | `(name, pin, value)` | BOOL (value 0-65535) |

### PWM

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_PWM_SETUP` | `(name, pin, freqHz)` | BOOL |
| `P2_PWM_DUTY` | `(name, pin, duty)` | BOOL (duty 0-65535) |
| `P2_PWM_STOP` | `(name, pin)` | BOOL |

### Encoder

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_ENC_SETUP` | `(name, pinA, pinB)` | BOOL |
| `P2_ENC_READ` | `(name, pinA)` | INT (signed 32-bit count) |
| `P2_ENC_RESET` | `(name, pinA)` | BOOL |

### Frequency Counter

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_FREQ_SETUP` | `(name, pin, gateMs)` | BOOL |
| `P2_FREQ_READ` | `(name, pin)` | INT (Hz) |

### Servo

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_SERVO_MOVE` | `(name, pin, duty, speed)` | BOOL (duty in us, speed: 0=instant, +N=divisor, -N=deg/sec) |

> **Note:** `servo_batch` is `P2_CMD`-only due to its array parameter. Use `P2_SERVO_MOVE` for single servos, `P2_CMD` with JSON for synchronized multi-servo updates.

### OLED Display

| Function | Signature | Returns |
|----------|-----------|---------|
| `P2_OLED_INIT` | `(name, ch, addr)` | BOOL |
| `P2_OLED_CLEAR` | `(name, ch)` | BOOL |
| `P2_OLED_PRINT` | `(name, row, text)` | BOOL |

> **Note:** Eye display commands (`eye_start`, `eye_move`, `eye_pupil`, `eye_lid`, `eye_bottom_lid`, `eye_ring`) and `servo_batch` are available through `P2_CMD` only. Convenience functions cover 38 hardware I/O operations.

---

*GoPLC v1.0.533 | Firmware: cyclic_io.spin2 (flexspin) | P2 Rev G @ 200 MHz*
*Schema source of truth: go-p2/firmware/p2_commands.json (44 commands)*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
