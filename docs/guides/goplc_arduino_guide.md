# GoPLC + Arduino Uno R4 WiFi: Hardware Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC treats the Arduino Uno R4 WiFi as a **smart I/O module** — not a compilation target. The R4 runs a precompiled firmware (`goplc_io.ino`, ~99KB compiled) that you upload once via the Arduino IDE or `arduino-cli`. All hardware control flows through USB CDC serial at 115200 baud using the same binary frame protocol as the Propeller 2 driver.

Unlike the P2 driver's dual-mode interface, the Arduino driver uses a **single mode**: dedicated ST functions for each capability. There is no generic `ARD_CMD` — every operation has its own typed function with compile-time parameter checking.

### System Diagram

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)         │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ ST Program                                   │   │
│  │                                              │   │
│  │ ARD_INIT('ard', '/dev/ttyACM0')              │   │
│  │ ARD_PIN_MODE('ard', 13, 1)                   │   │
│  │ ARD_DIGITAL_WRITE('ard', 13, TRUE)           │   │
│  │ val := ARD_ANALOG_READ('ard', 14)            │   │
│  │ ARD_SERVO_WRITE('ard', 0, 9, 90)             │   │
│  │ ARD_LED_TEXT('ard', 50, 'Hello')              │   │
│  └──────────────────────┬───────────────────────┘   │
│                         │                           │
│                         │  Binary frames            │
│                         │  (115200 baud, CRC16)     │
└─────────────────────────┼───────────────────────────┘
                          │
                          │  USB CDC Serial
                          ▼
┌─────────────────────────────────────────────────────┐
│  Arduino Uno R4 WiFi (Renesas RA4M1, 48 MHz)       │
│                                                     │
│  goplc_io.ino firmware (~99KB compiled)             │
│                                                     │
│  14 Digital I/O (D0-D13)                            │
│  6 Analog Inputs (A0-A5, 14-bit ADC)               │
│  6 PWM Outputs (D3, D5, D6, D9, D10, D11)          │
│  1 DAC Output (A0, 12-bit)                          │
│  I2C (SDA/SCL)                                      │
│  12x8 LED Matrix                                    │
│  WiFi (ESP32-S3 module)                             │
│  BLE (ESP32-S3 module)                              │
│  Internal Temperature Sensor                        │
└─────────────────────────────────────────────────────┘
```

---

## 2. Wire Protocol

Every ST function call is packed into a binary frame identical in structure to the P2 protocol:

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
- USB CDC at 115200 baud (not configurable — firmware default)

You never build frames manually — the `ARD_*` functions handle packing/unpacking internally.

---

## 3. Device Lifecycle

### ARD_INIT — Connect to Arduino

Opens the USB CDC serial port and establishes the binary protocol link. The firmware must already be flashed.

```iecst
ok := ARD_INIT('ard', '/dev/ttyACM0');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle name (used by all other ARD_* calls) |
| `port` | STRING | Serial port path |

> **Port Discovery:** Use `SERIAL_FIND('Arduino')` or `SERIAL_PORTS()` to locate the device automatically. See Section 10.

### ARD_STATUS — Connection Health

```iecst
status := ARD_STATUS('ard');
(* Returns: {"connected":true,"ping_us":312,"board_type":4,
             "digital_pins":14,"analog_pins":6,"pwm_pins":6} *)
```

| Field | Type | Description |
|-------|------|-------------|
| `connected` | bool | Link alive |
| `ping_us` | int | Round-trip latency in microseconds |
| `board_type` | int | 0x04 = Arduino Uno R4 WiFi |
| `digital_pins` | int | 14 |
| `analog_pins` | int | 6 |
| `pwm_pins` | int | 6 |

### ARD_CLOSE — Disconnect

```iecst
ok := ARD_CLOSE('ard');
```

Closes the serial port and releases the device handle.

### Example: Safe Init with Port Discovery

```iecst
PROGRAM POU_ArduinoInit
VAR
    port : STRING;
    ok : BOOL;
    status : STRING;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Find Arduino *)
        port := SERIAL_FIND('Arduino');
        IF LEN(port) > 0 THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := ARD_INIT('ard', port);
        IF ok THEN
            state := 2;
        END_IF;

    2: (* Verify *)
        status := ARD_STATUS('ard');
        (* Parse board_type — 4 = R4 WiFi *)
        state := 10;

    10: (* Ready for I/O *)
        (* ... *)
END_CASE;
END_PROGRAM
```

---

## 4. Digital I/O

The R4 WiFi has 14 digital pins (D0-D13). D0/D1 are shared with USB serial — avoid using them for GPIO when the serial link is active.

### ARD_PIN_MODE — Configure Pin Direction

| Param | Type | Values |
|-------|------|--------|
| `name` | STRING | Device handle |
| `pin` | INT | 0-13 |
| `mode` | INT | 0=INPUT, 1=OUTPUT, 2=INPUT_PULLUP |

```iecst
(* Set pin 13 as output (built-in LED) *)
ARD_PIN_MODE('ard', 13, 1);

(* Set pin 2 as input with pull-up *)
ARD_PIN_MODE('ard', 2, 2);
```

### ARD_DIGITAL_READ — Read Digital State

```iecst
sensor := ARD_DIGITAL_READ('ard', 2);
(* Returns: TRUE or FALSE *)
```

> **Note:** Returns a native BOOL, not a JSON string. No parsing needed.

### ARD_DIGITAL_WRITE — Set Digital Output

```iecst
ARD_DIGITAL_WRITE('ard', 13, TRUE);     (* LED on *)
ARD_DIGITAL_WRITE('ard', 13, FALSE);    (* LED off *)
```

### Example: Digital I/O Scan Loop

```iecst
PROGRAM POU_DigitalIO
VAR
    sensor_in : BOOL;
    output_on : BOOL;
END_VAR

(* Read sensor on pin 2 (INPUT_PULLUP — active LOW) *)
sensor_in := ARD_DIGITAL_READ('ard', 2);

(* Drive output on pin 13 based on input *)
IF NOT sensor_in THEN
    ARD_DIGITAL_WRITE('ard', 13, TRUE);
ELSE
    ARD_DIGITAL_WRITE('ard', 13, FALSE);
END_IF;
END_PROGRAM
```

---

## 5. Analog I/O

### 5.1 Analog Input

The R4 WiFi has 6 analog inputs (A0-A5, mapped to pins 14-19) with a 14-bit ADC (0-16383 range). Reference voltage is 3.3V.

#### ARD_ANALOG_READ — Read Analog Value

```iecst
raw := ARD_ANALOG_READ('ard', 14);     (* A0 — returns 0-16383 *)
raw := ARD_ANALOG_READ('ard', 15);     (* A1 *)
raw := ARD_ANALOG_READ('ard', 19);     (* A5 *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `pin` | INT | 14-19 (A0-A5) |

> **14-bit Resolution:** The R4's Renesas RA4M1 provides true 14-bit ADC resolution (0-16383), a significant upgrade over the classic Uno's 10-bit ADC (0-1023). Voltage = raw * 3.3 / 16383.

### 5.2 PWM Output

6 PWM-capable pins: D3, D5, D6, D9, D10, D11. 16-bit duty resolution (0-65535).

#### ARD_PWM_WRITE — Set PWM Duty Cycle

```iecst
(* 50% duty on pin 9 *)
ARD_PWM_WRITE('ard', 9, 32768);

(* Full brightness LED on pin 3 *)
ARD_PWM_WRITE('ard', 3, 65535);

(* Off *)
ARD_PWM_WRITE('ard', 3, 0);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `pin` | INT | PWM-capable pin (3, 5, 6, 9, 10, 11) |
| `duty` | INT | 0-65535 (16-bit) |

### 5.3 DAC Output

The R4 WiFi has a true 12-bit DAC on pin A0 (pin 14). This outputs a real analog voltage, not PWM.

#### ARD_DAC_WRITE — Set DAC Value

```iecst
ARD_DAC_WRITE('ard', 2048);     (* ~1.65V — midpoint *)
ARD_DAC_WRITE('ard', 4095);     (* ~3.3V — full scale *)
ARD_DAC_WRITE('ard', 0);        (* 0V *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `value` | INT | 0-4095 (12-bit) |

> **Pin A0 is shared:** When using DAC output, A0 cannot simultaneously be used as an analog input. The DAC takes exclusive control of the pin.

### Example: Analog Monitor with DAC Feedback

```iecst
PROGRAM POU_AnalogMonitor
VAR
    sensor_raw : INT;
    dac_out : INT;
END_VAR

(* Read potentiometer on A1 (pin 15) *)
sensor_raw := ARD_ANALOG_READ('ard', 15);

(* Scale 14-bit input (0-16383) to 12-bit output (0-4095) *)
dac_out := sensor_raw / 4;

(* Mirror input to DAC output on A0 *)
ARD_DAC_WRITE('ard', dac_out);
END_PROGRAM
```

---

## 6. I2C

The R4 WiFi has one hardware I2C bus on the dedicated SDA/SCL pins (next to AREF).

### ARD_I2C_SCAN — Scan Bus for Devices

```iecst
devices := ARD_I2C_SCAN('ard');
(* Returns: "3C,48,68" — comma-separated hex addresses *)
(* Empty string if no devices found *)
```

### ARD_I2C_WRITE_BYTE — Write Single Byte

```iecst
(* Send command byte 0xAE to OLED at address 0x3C *)
ok := ARD_I2C_WRITE_BYTE('ard', 16#3C, 16#AE);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `addr` | INT | 7-bit I2C device address |
| `value` | INT | Byte to write (0-255) |

### Example: I2C Device Discovery

```iecst
PROGRAM POU_I2CScan
VAR
    devices : STRING;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Scan the bus *)
        devices := ARD_I2C_SCAN('ard');
        state := 1;

    1: (* Check results *)
        IF LEN(devices) > 0 THEN
            (* Found devices — parse comma-separated hex addresses *)
            (* Common: 0x3C=OLED, 0x48=TMP102, 0x68=MPU6050 *)
            state := 10;
        ELSE
            (* No devices — check wiring *)
            state := 99;
        END_IF;

    10: (* Ready to communicate *)
        ARD_I2C_WRITE_BYTE('ard', 16#3C, 16#AE);   (* OLED display off *)
END_CASE;
END_PROGRAM
```

---

## 7. Servo Control

Up to 4 simultaneous servo channels (indices 0-3). Standard hobby servos with 0-180 degree range.

### ARD_SERVO_WRITE — Move Servo

```iecst
(* Attach servo index 0 to pin 9, move to 90 degrees *)
ARD_SERVO_WRITE('ard', 0, 9, 90);

(* Attach servo index 1 to pin 10, move to 0 degrees *)
ARD_SERVO_WRITE('ard', 1, 10, 0);

(* Move index 0 to 180 degrees (pin remembered from attach) *)
ARD_SERVO_WRITE('ard', 0, 9, 180);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `idx` | INT | Servo index 0-3 |
| `pin` | INT | Signal pin |
| `angle` | INT | Position in degrees (0-180) |

> **Index vs. Pin:** The `idx` parameter is a firmware slot (0-3), not the pin number. Each call specifies both the slot and the pin, so you can reassign slots dynamically. For most applications, assign one index per servo and leave it.

### Example: Pan-Tilt Bracket

```iecst
PROGRAM POU_PanTilt
VAR
    pan_angle : INT := 90;
    tilt_angle : INT := 90;
    step : INT := 1;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Initialize — center both servos *)
        ARD_SERVO_WRITE('ard', 0, 9, 90);      (* Pan on pin 9 *)
        ARD_SERVO_WRITE('ard', 1, 10, 90);     (* Tilt on pin 10 *)
        state := 1;

    1: (* Sweep pan left to right *)
        pan_angle := pan_angle + step;
        IF pan_angle >= 180 THEN
            step := -1;
        ELSIF pan_angle <= 0 THEN
            step := 1;
        END_IF;
        ARD_SERVO_WRITE('ard', 0, 9, pan_angle);
END_CASE;
END_PROGRAM
```

---

## 8. Sensors

### ARD_TEMP_READ — Internal Temperature Sensor

Reads the raw ADC value from the R4's built-in temperature sensor.

```iecst
raw_temp := ARD_TEMP_READ('ard');
(* Returns: raw ADC value from internal sensor *)
(* Conversion to Celsius is board-specific — see Renesas RA4M1 datasheet *)
```

### ARD_DISTANCE — HC-SR04 Ultrasonic Distance

Measures distance using an HC-SR04 ultrasonic sensor. Returns distance in millimeters. The firmware handles trigger pulse generation and echo timing internally.

```iecst
dist_mm := ARD_DISTANCE('ard', 7, 8);
(* Returns: distance in millimeters *)
(* 0 or very large value = no echo (out of range or no obstacle) *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `trig_pin` | INT | Trigger pin (output) |
| `echo_pin` | INT | Echo pin (input) |

> **Timing Note:** The HC-SR04 measurement blocks until the echo returns or times out (~30ms max for ~5m range). This adds latency to the scan cycle. For faster scans, call `ARD_DISTANCE` on alternating cycles.

### Example: Proximity Alert

```iecst
PROGRAM POU_Proximity
VAR
    distance_mm : INT;
    alert : BOOL;
    led_duty : INT;
END_VAR

(* Measure distance: trigger on D7, echo on D8 *)
distance_mm := ARD_DISTANCE('ard', 7, 8);

(* Alert if closer than 200mm *)
alert := (distance_mm > 0) AND (distance_mm < 200);
ARD_DIGITAL_WRITE('ard', 13, alert);

(* PWM LED brightness inversely proportional to distance *)
IF distance_mm > 0 AND distance_mm < 1000 THEN
    led_duty := 65535 - (distance_mm * 65);
    IF led_duty < 0 THEN led_duty := 0; END_IF;
    ARD_PWM_WRITE('ard', 3, led_duty);
END_IF;
END_PROGRAM
```

---

## 9. WiFi and BLE

The R4 WiFi's ESP32-S3 module provides both WiFi and BLE capabilities.

### 9.1 WiFi

#### ARD_WIFI_CONNECT — Join Network

```iecst
ip := ARD_WIFI_CONNECT('ard', 'MyNetwork', 'MyPassword');
(* Returns: "192.168.1.42" on success, empty string on failure *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `ssid` | STRING | Network name |
| `password` | STRING | Network password |

#### ARD_WIFI_STATUS — Connection Status

```iecst
wifi := ARD_WIFI_STATUS('ard');
(* Returns: {"Connected":true,"Status":3,"RSSI":-45,"IP":"192.168.1.42"} *)
```

| Field | Type | Description |
|-------|------|-------------|
| `Connected` | bool | Associated with AP |
| `Status` | int | WiFi status code (3=WL_CONNECTED) |
| `RSSI` | int | Signal strength in dBm |
| `IP` | string | Assigned IP address |

### 9.2 BLE

#### ARD_BLE_START — Start BLE Advertising

```iecst
ok := ARD_BLE_START('ard', 'GoPLC-Sensor');
(* Starts BLE peripheral advertising with the given name *)
```

#### ARD_BLE_STOP — Stop BLE

```iecst
ok := ARD_BLE_STOP('ard');
```

### Example: WiFi-Connected Sensor Node

```iecst
PROGRAM POU_WiFiSensor
VAR
    ip : STRING;
    wifi_status : STRING;
    sensor_val : INT;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Connect to WiFi *)
        ip := ARD_WIFI_CONNECT('ard', 'PlantFloor', 'SecurePass123');
        IF LEN(ip) > 0 THEN
            state := 1;
        END_IF;

    1: (* Verify connection *)
        wifi_status := ARD_WIFI_STATUS('ard');
        state := 10;

    10: (* Running — read sensor and report *)
        sensor_val := ARD_ANALOG_READ('ard', 15);
        (* WiFi connection enables remote monitoring via GoPLC web UI *)
        (* The Arduino's IP can be used for additional TCP/UDP if needed *)
END_CASE;
END_PROGRAM
```

---

## 10. LED Matrix

The R4 WiFi has a built-in 12x8 LED matrix on the board face.

### ARD_LED_TEXT — Scroll Text

Scrolls text across the LED matrix. Speed controls the delay between scroll steps.

```iecst
(* Scroll "Hello" at moderate speed *)
ARD_LED_TEXT('ard', 50, 'Hello');

(* Fast scroll *)
ARD_LED_TEXT('ard', 20, 'ALERT!');

(* Slow scroll for readability *)
ARD_LED_TEXT('ard', 100, 'Temperature: 72F');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Device handle |
| `speed` | INT | Milliseconds per scroll step (lower = faster) |
| `text` | STRING | Text to scroll |

### Example: Status Display

```iecst
PROGRAM POU_StatusDisplay
VAR
    distance_mm : INT;
    msg : STRING;
    scan_count : DINT := 0;
    display_interval : DINT := 50;  (* Update every ~5s at 100ms scan *)
END_VAR

scan_count := scan_count + 1;

distance_mm := ARD_DISTANCE('ard', 7, 8);

IF (scan_count MOD display_interval) = 0 THEN
    msg := CONCAT('Dist: ', INT_TO_STRING(distance_mm), 'mm');
    ARD_LED_TEXT('ard', 40, msg);
END_IF;
END_PROGRAM
```

---

## 11. Serial Port Discovery

These functions are shared across all serial-based GoPLC drivers (Arduino, P2, generic serial).

### SERIAL_FIND — Find Port by Vendor Name

```iecst
port := SERIAL_FIND('Arduino');
(* Returns: "/dev/ttyACM0" or empty string if not found *)

(* Also works with partial matches *)
port := SERIAL_FIND('Parallax');    (* Find P2 *)
port := SERIAL_FIND('FTDI');        (* Find FTDI-based device *)
```

### SERIAL_PORTS — List All Serial Ports

```iecst
ports := SERIAL_PORTS();
(* Returns: JSON array of all detected serial ports *)
(* [{"port":"/dev/ttyACM0","vendor":"Arduino","product":"UNO R4"},
     {"port":"/dev/ttyUSB0","vendor":"FTDI","product":"FT232R"}] *)
```

---

## 12. Binary Protocol Command Codes

The Arduino firmware uses command opcodes in the 0xA0-0xB7 range. These are internal to the driver — you never specify them directly — but they are documented here for firmware development and protocol debugging.

### Command Table

| Command | Opcode | Request Payload | Response Payload |
|---------|--------|-----------------|------------------|
| **Device Lifecycle** | | | |
| ping | 0xA0 | — | — |
| status | 0xA1 | — | connected:u8, ping_us:u32, board_type:u8, digital_pins:u8, analog_pins:u8, pwm_pins:u8 |
| **Digital I/O** | | | |
| pin_mode | 0xA2 | pin:u8, mode:u8 | ok:u8 |
| digital_read | 0xA3 | pin:u8 | value:u8 |
| digital_write | 0xA4 | pin:u8, value:u8 | ok:u8 |
| **Analog** | | | |
| analog_read | 0xA5 | pin:u8 | value:u16 |
| pwm_write | 0xA6 | pin:u8, duty:u16 | ok:u8 |
| dac_write | 0xA7 | value:u16 | ok:u8 |
| **I2C** | | | |
| i2c_scan | 0xA8 | — | count:u8, addrs:bytes |
| i2c_write_byte | 0xA9 | addr:u8, value:u8 | ok:u8 |
| **Servo** | | | |
| servo_write | 0xAA | idx:u8, pin:u8, angle:u8 | ok:u8 |
| **Sensors** | | | |
| temp_read | 0xAB | — | value:u16 |
| distance | 0xAC | trig_pin:u8, echo_pin:u8 | distance_mm:u16 |
| **WiFi** | | | |
| wifi_connect | 0xAD | ssid:string, password:string | ip:string |
| wifi_status | 0xAE | — | connected:u8, status:u8, rssi:i16, ip:string |
| **BLE** | | | |
| ble_start | 0xAF | ble_name:string | ok:u8 |
| ble_stop | 0xB0 | — | ok:u8 |
| **LED Matrix** | | | |
| led_text | 0xB1 | speed:u16, text:string | ok:u8 |

### Frame Examples

**Digital Write (pin 13 HIGH):**
```
TX: A5 5A 01 A4 02 00 0D 01 [CRC16]
     ^^^^^ ^^  ^^  ^^^^^  ^^  ^^
     sync  seq cmd  len=2  pin val
```

**Analog Read (pin 14 / A0):**
```
TX: A5 5A 02 A5 01 00 0E [CRC16]
     ^^^^^ ^^  ^^  ^^^^^  ^^
     sync  seq cmd  len=1  pin

RX: A5 5A 02 A5 02 00 FF 3F [CRC16]
     ^^^^^ ^^  ^^  ^^^^^  ^^^^^
     sync  seq cmd  len=2  value=16383 (LE)
```

---

## 13. Complete Example: Sensor Station

A full program combining multiple Arduino peripherals into a sensor monitoring station.

```iecst
PROGRAM POU_SensorStation
VAR
    (* State *)
    state : INT := 0;
    scan_count : DINT := 0;

    (* Device *)
    port : STRING;
    ok : BOOL;

    (* Sensors *)
    distance_mm : INT;
    light_raw : INT;
    temp_raw : INT;

    (* Outputs *)
    led_duty : INT;
    servo_angle : INT;
    msg : STRING;
    ip : STRING;
END_VAR

CASE state OF
    0: (* Discover and connect *)
        port := SERIAL_FIND('Arduino');
        IF LEN(port) > 0 THEN
            ok := ARD_INIT('ard', port);
            IF ok THEN
                state := 1;
            END_IF;
        END_IF;

    1: (* Configure pins *)
        ARD_PIN_MODE('ard', 13, 1);     (* LED output *)
        ARD_PIN_MODE('ard', 2, 2);      (* Button input with pull-up *)
        state := 2;

    2: (* Connect WiFi *)
        ip := ARD_WIFI_CONNECT('ard', 'PlantFloor', 'SecurePass123');
        state := 10;

    10: (* Main loop — read sensors *)
        scan_count := scan_count + 1;

        (* Ultrasonic distance *)
        distance_mm := ARD_DISTANCE('ard', 7, 8);

        (* Light level on A1 *)
        light_raw := ARD_ANALOG_READ('ard', 15);

        (* Internal temperature *)
        temp_raw := ARD_TEMP_READ('ard');

        (* Proximity LED — brighter when closer *)
        IF distance_mm > 0 AND distance_mm < 1000 THEN
            led_duty := 65535 - (distance_mm * 65);
            IF led_duty < 0 THEN led_duty := 0; END_IF;
        ELSE
            led_duty := 0;
        END_IF;
        ARD_PWM_WRITE('ard', 3, led_duty);

        (* Servo tracks distance — closer = more deflection *)
        IF distance_mm > 0 AND distance_mm < 2000 THEN
            servo_angle := 180 - (distance_mm / 11);
            IF servo_angle < 0 THEN servo_angle := 0; END_IF;
        ELSE
            servo_angle := 0;
        END_IF;
        ARD_SERVO_WRITE('ard', 0, 9, servo_angle);

        (* DAC output proportional to light level *)
        ARD_DAC_WRITE('ard', light_raw / 4);

        (* Update LED matrix every 5 seconds *)
        IF (scan_count MOD 50) = 0 THEN
            msg := CONCAT('D:', INT_TO_STRING(distance_mm), 'mm');
            ARD_LED_TEXT('ard', 40, msg);
        END_IF;

        (* Heartbeat *)
        ARD_DIGITAL_WRITE('ard', 13, (scan_count MOD 10) < 5);

END_CASE;
END_PROGRAM
```

---

## 14. Hardware Notes for Arduino R4 WiFi Users

### Pin Constraints

- **D0/D1**: Shared with USB CDC serial. Do not use for GPIO while the GoPLC link is active.
- **A0 (pin 14)**: Shared between analog input and DAC output. Using `ARD_DAC_WRITE` claims the pin exclusively.
- **D3, D5, D6, D9, D10, D11**: PWM-capable pins. `ARD_PWM_WRITE` on other pins will fail silently.
- **SDA/SCL**: Dedicated I2C pins (next to AREF header). Not remappable.

### ADC Resolution

The R4 WiFi uses the Renesas RA4M1 with a true 14-bit ADC. The firmware configures `analogReadResolution(14)` at boot. Raw values range 0-16383. To convert to voltage:

```
voltage_mv = raw * 3300 / 16383
```

### PWM Resolution

The firmware configures `analogWriteResolution(16)` at boot, providing 16-bit duty cycle control (0-65535). Default PWM frequency is ~490 Hz on most pins, ~980 Hz on D5/D6.

### DAC Output

The 12-bit DAC on A0 provides true analog voltage output (not PWM-filtered). Output impedance is relatively high — buffer with an op-amp for driving loads. Voltage range is 0-3.3V with 0.8mV resolution (3300/4096).

### USB CDC Serial

- **Port**: Typically `/dev/ttyACM0` on Linux, `COM3+` on Windows.
- **Baud**: 115200 (fixed in firmware). The GoPLC driver opens at this rate automatically.
- **Reset on connect**: Linux DTR assertion resets the Arduino by default. GoPLC suppresses DTR to prevent unwanted resets. If the Arduino resets unexpectedly, check that no other process is opening the port.
- **Latency**: USB CDC has ~1ms base latency. Typical round-trip for a command is 2-5ms.

### WiFi Module

The ESP32-S3 module handles WiFi and BLE independently from the main RA4M1 MCU. WiFi connection is non-blocking in the firmware — `ARD_WIFI_CONNECT` waits up to 10 seconds for association. RSSI values below -80 dBm indicate poor signal.

### LED Matrix

The 12x8 LED matrix is multiplexed by the firmware. `ARD_LED_TEXT` initiates a non-blocking scroll — the firmware handles frame updates internally. Sending a new text command while a previous scroll is active replaces it immediately.

### Servo Library Limits

The Arduino Servo library supports a maximum of 12 servos, but the GoPLC firmware exposes 4 slots (indices 0-3) to keep command payloads compact. Each `ARD_SERVO_WRITE` call both attaches the servo to the specified pin and sets the angle. Unlike the P2 driver, there is no interpolation — the servo moves as fast as the hardware allows.

### Power

- **USB power**: 5V from host, max ~500mA shared across all peripherals.
- **Servo power**: Do NOT power servos from the Arduino 5V pin. Use an external supply with common ground.
- **3.3V logic**: All I/O pins are 3.3V on the R4 (unlike the classic Uno's 5V). Most 5V sensors work, but verify logic levels.

---

## 15. Arduino vs. Propeller 2 — When to Use Which

| Criteria | Arduino Uno R4 WiFi | Propeller 2 |
|----------|-------------------|-------------|
| **Best for** | Simple I/O, WiFi/BLE connectivity, quick prototyping | High pin count, real-time servo/PWM, multi-UART, advanced analog |
| **Digital I/O** | 14 pins | 64 smart pins |
| **Analog In** | 6 channels, 14-bit | 4 channels, 14-bit (calibrated mV) |
| **PWM** | 6 channels, 16-bit | Any pin, smart pin PWM |
| **DAC** | 1 channel (A0), 12-bit | Any pin, 16-bit dithered |
| **UART** | USB only (for GoPLC link) | 16 channels via smart pins |
| **I2C** | 1 bus (SDA/SCL) | 8 buses (any pins) |
| **SPI** | Not exposed | 8 channels |
| **Servo** | 4 channels, no interpolation | 10 channels, cog-based interpolation |
| **WiFi/BLE** | Built-in (ESP32-S3) | None |
| **LED Matrix** | 12x8 built-in | None (OLED via I2C) |
| **Serial speed** | 115200 baud (USB CDC) | 3 Mbaud (FTDI) |
| **Firmware** | Pre-flash via Arduino IDE | Auto-upload at P2_INIT |
| **Price** | ~$27 | ~$60 (P2-EVAL) |
| **ST interface** | Dedicated functions (ARD_*) | Generic command (P2_CMD) |

---

## Appendix A: Complete Function Quick Reference

| Function | Returns | Description |
|----------|---------|-------------|
| `ARD_INIT(name, port)` | BOOL | Connect to Arduino over USB serial |
| `ARD_CLOSE(name)` | BOOL | Disconnect and release handle |
| `ARD_STATUS(name)` | STRING | JSON: connected, ping_us, board_type, pin counts |
| `ARD_PIN_MODE(name, pin, mode)` | BOOL | Set pin direction: 0=IN, 1=OUT, 2=PULLUP |
| `ARD_DIGITAL_READ(name, pin)` | BOOL | Read digital pin state |
| `ARD_DIGITAL_WRITE(name, pin, value)` | BOOL | Set digital output |
| `ARD_ANALOG_READ(name, pin)` | INT | Read analog input (0-16383, 14-bit) |
| `ARD_PWM_WRITE(name, pin, duty)` | BOOL | Set PWM duty (0-65535, 16-bit) |
| `ARD_DAC_WRITE(name, value)` | BOOL | Set DAC output on A0 (0-4095, 12-bit) |
| `ARD_I2C_SCAN(name)` | STRING | Comma-separated hex addresses |
| `ARD_I2C_WRITE_BYTE(name, addr, value)` | BOOL | Write single byte to I2C device |
| `ARD_SERVO_WRITE(name, idx, pin, angle)` | BOOL | Set servo position (0-180 degrees) |
| `ARD_TEMP_READ(name)` | INT | Internal temperature sensor raw ADC |
| `ARD_DISTANCE(name, trig, echo)` | INT | HC-SR04 distance in millimeters |
| `ARD_WIFI_CONNECT(name, ssid, pass)` | STRING | Join WiFi, returns IP or empty |
| `ARD_WIFI_STATUS(name)` | STRING | JSON: Connected, Status, RSSI, IP |
| `ARD_BLE_START(name, ble_name)` | BOOL | Start BLE advertising |
| `ARD_BLE_STOP(name)` | BOOL | Stop BLE |
| `ARD_LED_TEXT(name, speed, text)` | BOOL | Scroll text on 12x8 LED matrix |
| `SERIAL_FIND(search)` | STRING | Find port by vendor name |
| `SERIAL_PORTS()` | STRING | JSON array of all serial ports |

---

*GoPLC v1.0.520 | Firmware: goplc_io.ino (~99KB compiled) | Arduino Uno R4 WiFi @ 48 MHz*
*Protocol: Binary frame (SYNC+SEQ+CMD+LEN+PAYLOAD+CRC16) over USB CDC @ 115200 baud*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
