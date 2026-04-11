# GoPLC + Flipper Zero: Hardware Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC treats the Flipper Zero as a **multi-protocol RF and access control module** — a Swiss army knife for wireless industrial I/O. The Flipper connects over USB serial and exposes NFC, 125kHz RFID, Sub-GHz radio, infrared, iButton, and GPIO through 31 Structured Text functions.

There is **one interface mode**: the Flipper driver manages a named connection over USB serial. All protocol interactions are abstracted into purpose-built ST functions grouped by subsystem.

### Industrial Use Cases

| Subsystem | Frequency / Protocol | Industrial Application |
|-----------|---------------------|----------------------|
| **NFC** | 13.56 MHz (ISO 14443) | Asset tracking, maintenance logging, work order tagging |
| **RFID** | 125 kHz (EM4100, HID) | Badge access control, operator authentication |
| **Sub-GHz** | 315/433/868/915 MHz | Wireless sensor networks, weather stations, remote I/O |
| **Infrared** | 38 kHz carrier | HVAC control, equipment power management |
| **iButton** | 1-Wire (DS1990A) | Operator authentication, guard tour systems |
| **GPIO** | Digital I/O | Simple I/O expansion, sensor inputs, indicator outputs |

### System Diagram

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)         │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ ST Program                                   │   │
│  │                                              │   │
│  │ FLIPPER_CONNECT('flip', '/dev/ttyACM0')      │   │
│  │ FLIPPER_NFC_SCAN('flip')                     │   │
│  │ FLIPPER_SUBGHZ_RX_START('flip', 433920000)   │   │
│  │ FLIPPER_IR_TX('flip', 'NEC', 16#04, 16#08)   │   │
│  │ FLIPPER_RFID_READ('flip')                    │   │
│  │ FLIPPER_IBUTTON_READ('flip')                 │   │
│  └──────────────────────┬───────────────────────┘   │
│                         │                           │
│                         │  USB Serial (CDC ACM)     │
└─────────────────────────┼───────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│  Flipper Zero (STM32WB55, 64 MHz)                   │
│                                                     │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ NFC         │  │ Sub-GHz  │  │ Infrared     │   │
│  │ (ST25R3916) │  │ (CC1101) │  │ (TSOP75238)  │   │
│  │ 13.56 MHz   │  │ 300-928  │  │ 38 kHz RX    │   │
│  │ ISO 14443   │  │ MHz      │  │ IR LED TX    │   │
│  └─────────────┘  └──────────┘  └──────────────┘   │
│                                                     │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ 125 kHz     │  │ iButton  │  │ GPIO         │   │
│  │ RFID        │  │ 1-Wire   │  │ 8 pins       │   │
│  │ (EM4100,    │  │ (DS1990A │  │ 3.3V logic   │   │
│  │  HID Prox)  │  │  compat) │  │ 5V tolerant  │   │
│  └─────────────┘  └──────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## 2. Connection Management

GoPLC manages Flipper Zero devices by name. You can connect multiple Flippers simultaneously for distributed installations — one per access point, one per sensor zone, etc.

### 2.1 The Six Connection Functions

```iecst
(* Connect to Flipper Zero over USB serial *)
ok := FLIPPER_CONNECT('flip', '/dev/ttyACM0');

(* Check if connected *)
IF FLIPPER_IS_CONNECTED('flip') THEN
    (* Device is online *)
END_IF;

(* Get device information *)
info := FLIPPER_INFO('flip');
(* Returns JSON: {"name":"Flipper","model":"Zero","firmware":"0.98.3",
                  "hardware":"F7","serial":"ABC123"} *)

(* List all connected Flippers *)
all := FLIPPER_LIST();
(* Returns JSON: ["flip","flip2","warehouse_flip"] *)

(* Disconnect cleanly *)
FLIPPER_DISCONNECT('flip');

(* Remove device entry entirely *)
FLIPPER_DELETE('flip');
```

### 2.2 Connection Lifecycle

```iecst
PROGRAM POU_FlipperInit
VAR
    state : INT := 0;
    ok : BOOL;
    info : STRING;
    connected : BOOL;
END_VAR

CASE state OF
    0: (* Connect *)
        ok := FLIPPER_CONNECT('flip', '/dev/ttyACM0');
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Verify connection and read device info *)
        connected := FLIPPER_IS_CONNECTED('flip');
        IF connected THEN
            info := FLIPPER_INFO('flip');
            state := 10;
        ELSE
            state := 0;  (* Retry *)
        END_IF;

    10: (* Ready — device is online *)
        (* ... application logic ... *)
END_CASE;
END_PROGRAM
```

---

## 3. NFC (13.56 MHz)

The Flipper Zero's ST25R3916 NFC frontend supports ISO 14443A/B, ISO 15693, and FeliCa. In industrial settings, NFC is ideal for **asset tracking** and **maintenance logging** — technicians tap an NFC tag on equipment to log inspections, and GoPLC records the tag UID with a timestamp.

### 3.1 NFC Functions

| Function | Description |
|----------|-------------|
| `FLIPPER_NFC_SCAN(name)` | Scan for NFC tags in field. Returns JSON with tag type and UID. |
| `FLIPPER_NFC_READ(name)` | Read full data from NFC tag (NDEF records, sectors). |
| `FLIPPER_NFC_EMULATE(name, data)` | Emulate an NFC tag with specified data. |
| `FLIPPER_NFC_STOP(name)` | Stop any active NFC operation (scan, read, or emulate). |

### 3.2 NFC Code Examples

```iecst
PROGRAM POU_AssetTracking
VAR
    state : INT := 0;
    scan_result : STRING;
    tag_data : STRING;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Scan for NFC tags *)
        scan_result := FLIPPER_NFC_SCAN('flip');
        IF LEN(scan_result) > 0 THEN
            (* Returns: {"type":"NTAG215","uid":"04:A2:C8:1A:B3:52:80"} *)
            state := 1;
        END_IF;

    1: (* Read full tag data *)
        tag_data := FLIPPER_NFC_READ('flip');
        (* Returns: {"uid":"04:A2:C8:1A:B3:52:80",
                     "type":"NTAG215",
                     "data":"NDEF record content..."} *)
        state := 2;

    2: (* Process tag — log asset inspection *)
        (* Compare UID against known asset database *)
        (* Record timestamp + operator + equipment ID *)
        FLIPPER_NFC_STOP('flip');
        state := 0;  (* Return to scanning *)
END_CASE;
END_PROGRAM
```

#### NFC Tag Emulation (Test Fixture)

```iecst
(* Emulate an NFC tag for testing badge readers *)
ok := FLIPPER_NFC_EMULATE('flip', '{"uid":"04:A2:C8:1A:B3:52:80","type":"NTAG215"}');

(* Stop emulation when done *)
FLIPPER_NFC_STOP('flip');
```

> **Industrial Tip:** Mount a Flipper at each maintenance station. Technicians tap their NFC work order card, GoPLC logs the event and updates the SCADA historian. No custom NFC reader hardware required.

---

## 4. RFID (125 kHz)

The Flipper's 125 kHz RFID subsystem reads EM4100, HID Prox, and similar low-frequency proximity cards — the same cards used in most industrial access control systems. GoPLC uses this for **operator authentication** and **zone access control**.

### 4.1 RFID Functions

| Function | Description |
|----------|-------------|
| `FLIPPER_RFID_READ(name)` | Read a 125 kHz RFID tag. Blocks briefly while antenna energizes. |
| `FLIPPER_RFID_READ_CACHED(name)` | Return the last successfully read tag without re-scanning. |
| `FLIPPER_RFID_EMULATE(name, data)` | Emulate an RFID tag with specified data. |
| `FLIPPER_RFID_STOP(name)` | Stop any active RFID operation. |

### 4.2 RFID Code Examples

```iecst
PROGRAM POU_AccessControl
VAR
    state : INT := 0;
    badge : STRING;
    cached : STRING;
    ok : BOOL;
    door_open : BOOL := FALSE;
    door_timer : INT := 0;
END_VAR

CASE state OF
    0: (* Wait for badge tap *)
        badge := FLIPPER_RFID_READ('flip');
        IF LEN(badge) > 0 THEN
            (* Returns: {"type":"EM4100","data":"1A:2B:3C:4D:5E"} *)
            state := 1;
        END_IF;

    1: (* Validate badge against authorized list *)
        (* Check badge data against known operator IDs *)
        (* For demo: any valid read grants access *)
        door_open := TRUE;
        door_timer := 50;  (* 5 seconds at 100ms scan *)
        state := 2;

    2: (* Hold door open, count down *)
        door_timer := door_timer - 1;
        IF door_timer <= 0 THEN
            door_open := FALSE;
            state := 0;
        END_IF;
END_CASE;
END_PROGRAM
```

#### Retrieve Last Badge Read

```iecst
(* Non-blocking: get the last cached tag without re-scanning *)
cached := FLIPPER_RFID_READ_CACHED('flip');
(* Returns same format as FLIPPER_RFID_READ, or empty if no tag cached *)
```

#### RFID Emulation (Commissioning Tool)

```iecst
(* Emulate an EM4100 badge for testing door controllers *)
ok := FLIPPER_RFID_EMULATE('flip', '{"type":"EM4100","data":"1A:2B:3C:4D:5E"}');

(* Stop emulation *)
FLIPPER_RFID_STOP('flip');
```

> **Access Control Note:** Combine RFID badge reads with GoPLC's built-in logging to create a complete access audit trail. Each badge tap generates a timestamped event with operator ID, door ID, and grant/deny status.

---

## 5. Sub-GHz Radio (315/433/868/915 MHz)

The Flipper's CC1101 transceiver covers 300-928 MHz — the same bands used by industrial 433 MHz sensors, weather stations, remote thermometers, and wireless relay modules. GoPLC uses Sub-GHz for **wireless sensor integration** without dedicated radio hardware.

### 5.1 Sub-GHz Functions

| Function | Description |
|----------|-------------|
| `FLIPPER_SUBGHZ_TX(name, frequency, data)` | Transmit data on specified frequency (Hz). |
| `FLIPPER_SUBGHZ_RX_START(name, frequency)` | Start receiver on specified frequency (Hz). |
| `FLIPPER_SUBGHZ_RX_READ(name)` | Read received data buffer. |
| `FLIPPER_SUBGHZ_RX_STOP(name)` | Stop receiver. |

### 5.2 Sub-GHz Code Examples

#### Receive: 433 MHz Wireless Sensor Network

```iecst
PROGRAM POU_WirelessSensors
VAR
    state : INT := 0;
    ok : BOOL;
    rx_data : STRING;
    sensor_temp : REAL;
    sensor_humidity : REAL;
END_VAR

CASE state OF
    0: (* Start 433.92 MHz receiver *)
        ok := FLIPPER_SUBGHZ_RX_START('flip', 433920000);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Poll for incoming sensor data *)
        rx_data := FLIPPER_SUBGHZ_RX_READ('flip');
        IF LEN(rx_data) > 0 THEN
            (* Returns: {"frequency":433920000,
                         "protocol":"Oregon_v2.1",
                         "data":"A1:B2:C3:D4:E5:F6"} *)
            (* Parse temperature/humidity from protocol data *)
            state := 1;  (* Continue receiving *)
        END_IF;
END_CASE;
END_PROGRAM
```

#### Transmit: Wireless Relay Control

```iecst
(* Send 433 MHz command to wireless relay module *)
ok := FLIPPER_SUBGHZ_TX('flip', 433920000, 'A1B2C3D4');

(* Send on 315 MHz for US-market devices *)
ok := FLIPPER_SUBGHZ_TX('flip', 315000000, 'DEADBEEF');
```

#### Full Duplex: Weather Station Gateway

```iecst
PROGRAM POU_WeatherGateway
VAR
    state : INT := 0;
    ok : BOOL;
    wx_data : STRING;
    poll_count : DINT := 0;
    poll_interval : DINT := 100;  (* 10 sec at 100ms scan *)
END_VAR

CASE state OF
    0: (* Start receiver on 433.92 MHz *)
        ok := FLIPPER_SUBGHZ_RX_START('flip', 433920000);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Continuous receive — weather sensors transmit periodically *)
        wx_data := FLIPPER_SUBGHZ_RX_READ('flip');
        IF LEN(wx_data) > 0 THEN
            (* Decode weather station protocol *)
            (* Log to SCADA historian *)
        END_IF;

        (* Periodic transmit: send acknowledgment or relay command *)
        poll_count := poll_count + 1;
        IF (poll_count MOD poll_interval) = 0 THEN
            FLIPPER_SUBGHZ_RX_STOP('flip');
            state := 2;
        END_IF;

    2: (* Transmit window *)
        ok := FLIPPER_SUBGHZ_TX('flip', 433920000, 'ACK_OK');
        state := 0;  (* Restart receiver *)
END_CASE;
END_PROGRAM
```

> **Regulatory Note:** Sub-GHz transmissions are subject to regional regulations (FCC Part 15 in US, ETSI EN 300 220 in EU). The Flipper's CC1101 supports region-locked frequency plans. Ensure your transmit frequency and power comply with local regulations for your installation site.

---

## 6. Infrared

The Flipper's IR subsystem includes a TSOP75238 receiver (38 kHz demodulation) and a multi-LED transmitter. GoPLC uses IR for **HVAC control** and **equipment power management** — controlling split-unit air conditioners, projectors, displays, and other IR-equipped devices without proprietary gateways.

### 6.1 IR Functions

| Function | Description |
|----------|-------------|
| `FLIPPER_IR_TX(name, protocol, address, command)` | Send IR command using known protocol (NEC, Samsung, RC5, etc.). |
| `FLIPPER_IR_TX_RAW(name, frequency, duty, data)` | Send raw IR timing data for unknown protocols. |
| `FLIPPER_IR_RX_START(name)` | Start IR receiver (learning mode). |
| `FLIPPER_IR_RX_READ(name)` | Read received IR data. |
| `FLIPPER_IR_RX_STOP(name)` | Stop IR receiver. |

### 6.2 IR Code Examples

#### Transmit: HVAC Control

```iecst
PROGRAM POU_HVACControl
VAR
    temp_reading : REAL;
    ok : BOOL;
    cooling_on : BOOL := FALSE;
END_VAR

(* Simple thermostat logic *)
IF temp_reading > 25.0 AND NOT cooling_on THEN
    (* Send NEC protocol: power ON command to AC unit *)
    ok := FLIPPER_IR_TX('flip', 'NEC', 16#04, 16#08);
    cooling_on := TRUE;
ELSIF temp_reading < 22.0 AND cooling_on THEN
    (* Send power OFF command *)
    ok := FLIPPER_IR_TX('flip', 'NEC', 16#04, 16#09);
    cooling_on := FALSE;
END_IF;
END_PROGRAM
```

#### Transmit: Raw IR (Unknown Protocol)

```iecst
(* Send raw IR timing data for devices with proprietary protocols *)
(* frequency=38000 Hz, duty_cycle=33%, data=timing pairs in microseconds *)
ok := FLIPPER_IR_TX_RAW('flip', 38000, 33,
    '9000:4500:560:560:560:1690:560:560:560:1690');
```

#### Receive: Learn IR Codes

```iecst
PROGRAM POU_IRLearn
VAR
    state : INT := 0;
    ok : BOOL;
    ir_data : STRING;
END_VAR

CASE state OF
    0: (* Start IR receiver *)
        ok := FLIPPER_IR_RX_START('flip');
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Wait for IR signal — point remote at Flipper *)
        ir_data := FLIPPER_IR_RX_READ('flip');
        IF LEN(ir_data) > 0 THEN
            (* Returns: {"protocol":"NEC","address":"0x04",
                         "command":"0x08"} *)
            (* Or raw: {"frequency":38000,"duty":33,
                        "data":"9000:4500:560:560:..."} *)
            FLIPPER_IR_RX_STOP('flip');
            state := 2;
        END_IF;

    2: (* Learned — store code for replay *)
        (* Save ir_data to configuration *)
END_CASE;
END_PROGRAM
```

> **HVAC Tip:** Use IR learning mode during commissioning to capture the exact codes from each AC unit's remote. Store the protocol/address/command values in GoPLC variables, then replay them from your control logic. One Flipper can control multiple IR devices by aiming the transmitter LEDs appropriately — or mount one Flipper per zone.

---

## 7. iButton (1-Wire)

The Flipper's iButton interface reads and emulates DS1990A-compatible contact keys — the metal "fob" tokens commonly used in industrial **guard tour systems** and **operator authentication**. The operator touches the iButton probe on the Flipper to identify themselves.

### 7.1 iButton Functions

| Function | Description |
|----------|-------------|
| `FLIPPER_IBUTTON_READ(name)` | Read an iButton key in contact with the probe. |
| `FLIPPER_IBUTTON_READ_CACHED(name)` | Return the last read iButton without re-scanning. |
| `FLIPPER_IBUTTON_EMULATE(name, data)` | Emulate an iButton key. |
| `FLIPPER_IBUTTON_STOP(name)` | Stop any active iButton operation. |

### 7.2 iButton Code Examples

```iecst
PROGRAM POU_OperatorAuth
VAR
    state : INT := 0;
    key_data : STRING;
    cached : STRING;
    ok : BOOL;
    operator_id : STRING;
    authenticated : BOOL := FALSE;
END_VAR

CASE state OF
    0: (* Wait for iButton touch *)
        key_data := FLIPPER_IBUTTON_READ('flip');
        IF LEN(key_data) > 0 THEN
            (* Returns: {"type":"Dallas","data":"01:A2:B3:C4:D5:E6:F7:08"} *)
            state := 1;
        END_IF;

    1: (* Validate operator *)
        (* Match 64-bit ROM code against authorized operator list *)
        (* key_data contains the unique DS1990A serial number *)
        authenticated := TRUE;
        operator_id := key_data;
        state := 2;

    2: (* Operator authenticated — enable machine controls *)
        (* Periodically re-check with cached read *)
        cached := FLIPPER_IBUTTON_READ_CACHED('flip');
        (* Machine runs while operator key is recognized *)

        IF NOT authenticated THEN
            state := 0;
        END_IF;
END_CASE;
END_PROGRAM
```

#### iButton Emulation (Guard Tour Commissioning)

```iecst
(* Emulate an iButton for testing guard tour readers *)
ok := FLIPPER_IBUTTON_EMULATE('flip', '{"type":"Dallas","data":"01:A2:B3:C4:D5:E6:F7:08"}');

(* Stop emulation *)
FLIPPER_IBUTTON_STOP('flip');
```

> **Guard Tour Note:** Mount a Flipper at each checkpoint. Security personnel touch their iButton key at each station. GoPLC logs the guard's ID, checkpoint ID, and timestamp — a complete electronic guard tour system with zero custom hardware.

---

## 8. GPIO

The Flipper Zero exposes 8 GPIO pins at 3.3V logic (5V tolerant inputs). GoPLC uses these for **simple I/O expansion** — reading limit switches, pushbuttons, or sensor outputs, and driving indicator LEDs or small relays.

### 8.1 GPIO Functions

| Function | Description |
|----------|-------------|
| `FLIPPER_GPIO_MODE(name, pin, mode)` | Set pin direction: 'input', 'output', 'input_pullup', 'input_pulldown'. |
| `FLIPPER_GPIO_READ(name, pin)` | Read digital state. Returns BOOL. |
| `FLIPPER_GPIO_WRITE(name, pin, value)` | Write digital output. |

### 8.2 Button Read

| Function | Description |
|----------|-------------|
| `FLIPPER_BTN_READ(name)` | Read Flipper's physical buttons. Returns INT bitmask. |

### 8.3 GPIO Code Examples

```iecst
PROGRAM POU_GPIOExpansion
VAR
    state : INT := 0;
    ok : BOOL;
    sensor_in : BOOL;
    btn_state : INT;
END_VAR

CASE state OF
    0: (* Configure GPIO pins *)
        ok := FLIPPER_GPIO_MODE('flip', 2, 'input_pullup');   (* Sensor input *)
        ok := FLIPPER_GPIO_MODE('flip', 5, 'output');         (* Indicator LED *)
        state := 1;

    1: (* Scan loop — read sensor, drive indicator *)
        sensor_in := FLIPPER_GPIO_READ('flip', 2);
        FLIPPER_GPIO_WRITE('flip', 5, sensor_in);

        (* Read Flipper's physical buttons for local override *)
        btn_state := FLIPPER_BTN_READ('flip');
        (* Bit 0=Up, Bit 1=Down, Bit 2=Left, Bit 3=Right, Bit 4=OK, Bit 5=Back *)

        IF (btn_state AND 16#10) <> 0 THEN
            (* OK button pressed — manual override *)
            FLIPPER_GPIO_WRITE('flip', 5, TRUE);
        END_IF;
END_CASE;
END_PROGRAM
```

> **GPIO Limits:** The Flipper's GPIO is 3.3V with limited current drive (max ~20 mA per pin). For industrial loads, use the GPIO to drive an external relay module or optocoupler. The Flipper is not a replacement for dedicated industrial I/O — use it for auxiliary signals and local indicators.

---

## 9. Multi-Flipper Deployment

For larger facilities, deploy multiple Flippers — each dedicated to a subsystem or zone. GoPLC manages them all by name from a single ST program.

```iecst
PROGRAM POU_FacilityControl
VAR
    state : INT := 0;
    ok : BOOL;
    badge : STRING;
    wx_data : STRING;
    nfc_tag : STRING;
END_VAR

CASE state OF
    0: (* Initialize all Flippers *)
        ok := FLIPPER_CONNECT('door_east', '/dev/ttyACM0');
        ok := FLIPPER_CONNECT('door_west', '/dev/ttyACM1');
        ok := FLIPPER_CONNECT('sensors', '/dev/ttyACM2');
        ok := FLIPPER_CONNECT('hvac', '/dev/ttyACM3');
        state := 1;

    1: (* Parallel operations across all devices *)

        (* Access control — east door *)
        badge := FLIPPER_RFID_READ('door_east');
        IF LEN(badge) > 0 THEN
            (* Validate and log *)
        END_IF;

        (* Access control — west door *)
        badge := FLIPPER_RFID_READ('door_west');
        IF LEN(badge) > 0 THEN
            (* Validate and log *)
        END_IF;

        (* 433 MHz sensor polling *)
        wx_data := FLIPPER_SUBGHZ_RX_READ('sensors');
        IF LEN(wx_data) > 0 THEN
            (* Decode wireless sensor data *)
        END_IF;

        (* HVAC zone control via IR *)
        (* Triggered by temperature logic elsewhere *)
END_CASE;
END_PROGRAM
```

---

## 10. Timing Considerations

| Operation | Typical Latency | Notes |
|-----------|----------------|-------|
| **USB Serial round-trip** | 2-5 ms | CDC ACM class, no custom driver needed |
| **NFC scan** | 50-200 ms | Depends on tag type and field coupling |
| **RFID read** | 30-100 ms | 125 kHz antenna energize + demodulate |
| **Sub-GHz TX** | 5-20 ms | Depends on data length |
| **Sub-GHz RX poll** | 1-2 ms | Reading buffer, not waiting for signal |
| **IR TX** | 10-50 ms | Depends on protocol timing |
| **iButton read** | 20-80 ms | 1-Wire ROM read cycle |
| **GPIO read/write** | 1-3 ms | Fastest operation |

The Flipper is not a real-time I/O device. USB serial latency is 2-5 ms minimum, and RF operations add protocol-dependent delays. Use the Flipper for **event-driven** workflows (badge tap, sensor report, IR command) rather than tight control loops. For deterministic I/O, use a Propeller 2 or dedicated industrial I/O module.

---

## 11. Hardware Notes

### USB Serial

- **Linux device**: Typically `/dev/ttyACM0`. Use `SERIAL_FIND('Flipper')` to auto-detect.
- **No special drivers**: The Flipper enumerates as standard CDC ACM. Works on any Linux host out of the box.
- **Multiple Flippers**: Each gets a unique `/dev/ttyACMn` device. Use `udev` rules to assign persistent names by serial number for reliable multi-device setups.

### Power

- **USB powered**: 5V from host USB. No external supply needed.
- **Battery backup**: The Flipper's internal battery keeps the device running briefly during USB disconnects, but GoPLC should handle reconnection gracefully.
- **Current draw**: ~120 mA typical, ~200 mA during Sub-GHz TX. Standard USB 2.0 port is sufficient.

### Antenna Placement

- **NFC**: Effective range is 1-4 cm. Mount the Flipper flush against the tag presentation surface.
- **125 kHz RFID**: Range is 3-8 cm. Similar mounting to NFC.
- **Sub-GHz**: Range depends on environment and frequency. Line-of-sight at 433 MHz can reach 50+ meters with the built-in antenna. For longer range, use the Flipper's external antenna connector.
- **IR**: Line-of-sight only. Mount the Flipper with a clear optical path to the target device. Range is 3-8 meters depending on ambient IR noise.

### Firmware

- **Flipper firmware**: GoPLC's driver is compatible with stock Flipper Zero firmware. No custom firmware required.
- **Firmware updates**: Update the Flipper's firmware via the Flipper mobile app or qFlipper desktop tool. GoPLC reconnects automatically after firmware updates.

---

## Appendix A: Complete Function Quick Reference

| Function | Parameters | Returns |
|----------|-----------|---------|
| `FLIPPER_CONNECT` | name:STRING, port:STRING | BOOL |
| `FLIPPER_DISCONNECT` | name:STRING | BOOL |
| `FLIPPER_IS_CONNECTED` | name:STRING | BOOL |
| `FLIPPER_INFO` | name:STRING | STRING (JSON) |
| `FLIPPER_DELETE` | name:STRING | BOOL |
| `FLIPPER_LIST` | — | STRING (JSON array) |
| `FLIPPER_GPIO_MODE` | name:STRING, pin:INT, mode:STRING | BOOL |
| `FLIPPER_GPIO_READ` | name:STRING, pin:INT | BOOL |
| `FLIPPER_GPIO_WRITE` | name:STRING, pin:INT, value:BOOL | BOOL |
| `FLIPPER_BTN_READ` | name:STRING | INT |
| `FLIPPER_NFC_SCAN` | name:STRING | STRING (JSON) |
| `FLIPPER_NFC_READ` | name:STRING | STRING (JSON) |
| `FLIPPER_NFC_EMULATE` | name:STRING, data:STRING | BOOL |
| `FLIPPER_NFC_STOP` | name:STRING | BOOL |
| `FLIPPER_RFID_READ` | name:STRING | STRING (JSON) |
| `FLIPPER_RFID_READ_CACHED` | name:STRING | STRING (JSON) |
| `FLIPPER_RFID_EMULATE` | name:STRING, data:STRING | BOOL |
| `FLIPPER_RFID_STOP` | name:STRING | BOOL |
| `FLIPPER_SUBGHZ_TX` | name:STRING, frequency:DINT, data:STRING | BOOL |
| `FLIPPER_SUBGHZ_RX_START` | name:STRING, frequency:DINT | BOOL |
| `FLIPPER_SUBGHZ_RX_READ` | name:STRING | STRING (JSON) |
| `FLIPPER_SUBGHZ_RX_STOP` | name:STRING | BOOL |
| `FLIPPER_IR_TX` | name:STRING, protocol:STRING, address:INT, command:INT | BOOL |
| `FLIPPER_IR_TX_RAW` | name:STRING, frequency:INT, duty:INT, data:STRING | BOOL |
| `FLIPPER_IR_RX_START` | name:STRING | BOOL |
| `FLIPPER_IR_RX_READ` | name:STRING | STRING (JSON) |
| `FLIPPER_IR_RX_STOP` | name:STRING | BOOL |
| `FLIPPER_IBUTTON_READ` | name:STRING | STRING (JSON) |
| `FLIPPER_IBUTTON_READ_CACHED` | name:STRING | STRING (JSON) |
| `FLIPPER_IBUTTON_EMULATE` | name:STRING, data:STRING | BOOL |
| `FLIPPER_IBUTTON_STOP` | name:STRING | BOOL |

---

*GoPLC v1.0.533 | Driver: flipper_zero (USB CDC ACM) | Flipper Zero (STM32WB55 @ 64 MHz)*
*31 ST functions across 7 subsystems: Connection, GPIO, NFC, RFID, Sub-GHz, IR, iButton*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
