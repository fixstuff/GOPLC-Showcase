# GoPLC + Phidgets: Hardware Interface Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC treats Phidgets as **plug-and-play USB sensor/actuator modules**. Each Phidget channel is opened by serial number and channel index, given a string name, and accessed through typed ST functions. No drivers to install, no configuration files — plug in the USB device and call `PHIDGET_OPEN`.

There are **16 ST functions** organized into three groups:

| Group | Functions | Purpose |
|-------|-----------|---------|
| **Device Lifecycle** | `PHIDGET_OPEN`, `CLOSE`, `IS_ATTACHED`, `DELETE`, `LIST` | Connect, disconnect, enumerate |
| **Reading Sensors** | `PHIDGET_READ`, `READ_BOOL`, `VOLTAGE`, `CURRENT`, `TEMPERATURE`, `HUMIDITY`, `RATIO` | Typed sensor input |
| **Writing Outputs** | `PHIDGET_WRITE`, `WRITE_BOOL`, `SET_MOTOR`, `SET_RELAY` | Typed actuator output |

All functions use IEC 61131-3 Structured Text in GoPLC's browser-based IDE.

### System Diagram

```
┌─────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)         │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ ST Program                                   │   │
│  │                                              │   │
│  │ PHIDGET_OPEN('temp1', 561234, 0)             │   │
│  │ temp := PHIDGET_TEMPERATURE('temp1')         │   │
│  │ PHIDGET_SET_RELAY('relay1', TRUE)            │   │
│  └──────────────────┬───────────────────────────┘   │
│                     │                               │
│  ┌──────────────────┴───────────────────────────┐   │
│  │ Phidgets Driver Layer (libphidget22)         │   │
│  │ - USB enumeration and hot-plug detection     │   │
│  │ - Channel-level event callbacks              │   │
│  │ - Automatic calibration and unit conversion  │   │
│  └──────────────────┬───────────────────────────┘   │
└─────────────────────┼───────────────────────────────┘
                      │  USB
                      ▼
┌─────────────────────────────────────────────────────┐
│  Phidgets Hardware                                  │
│                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ VINT Hub │ │ 1048     │ │ REL1100  │            │
│  │ HUB0000  │ │ Temp/Hum │ │ 4x Relay │            │
│  │ 6 ports  │ │ Sensor   │ │ Module   │            │
│  └──────────┘ └──────────┘ └──────────┘            │
│                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ 1002     │ │ DCC1000  │ │ 1046     │            │
│  │ Voltage  │ │ DC Motor │ │ Bridge   │            │
│  │ Input    │ │ Control  │ │ (Load    │            │
│  │          │ │          │ │  Cells)  │            │
│  └──────────┘ └──────────┘ └──────────┘            │
└─────────────────────────────────────────────────────┘
```

### Typical Applications

- **Industrial measurement** — High-precision voltage/current monitoring with calibrated sensors
- **Environmental monitoring** — Temperature and humidity logging across multiple zones
- **Load cell / strain gauge** — Ratiometric bridge input for weighing and force measurement
- **Relay control** — Switching AC/DC loads with isolated solid-state or mechanical relays
- **Motor control** — Variable-speed DC motor drive with bidirectional speed (-1.0 to 1.0)
- **Lab automation** — Plug-and-play USB sensor expansion without custom wiring

---

## 2. Device Lifecycle

Every Phidget channel follows the same pattern: **open, use, close**. The string `name` you assign at open time is the handle used by all subsequent read/write calls.

### 2.1 PHIDGET_OPEN — Connect to a Channel

```iecst
(* Open a temperature sensor: serial 561234, channel 0 *)
ok := PHIDGET_OPEN('temp1', 561234, 0);
(* Returns: TRUE if the channel was opened successfully *)

(* Open a relay module: serial 437891, channel 2 *)
ok := PHIDGET_OPEN('relay_main', 437891, 2);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique handle for this channel (your choice) |
| `serial_number` | INT | Device serial number (printed on label, visible in Phidget Control Panel) |
| `channel` | INT | Channel index on the device (0-based) |

> **Finding the serial number:** Every Phidgets device has a unique serial number printed on the board. You can also enumerate connected devices with `PHIDGET_LIST()`.

### 2.2 PHIDGET_CLOSE — Disconnect a Channel

```iecst
ok := PHIDGET_CLOSE('temp1');
(* Returns: TRUE if closed successfully *)
```

Releases the channel. The device remains physically connected and can be reopened.

### 2.3 PHIDGET_IS_ATTACHED — Check Connection

```iecst
IF PHIDGET_IS_ATTACHED('temp1') THEN
    (* Safe to read *)
    temp := PHIDGET_TEMPERATURE('temp1');
END_IF;
```

Returns `TRUE` if the device is physically connected and the channel is open. Use this to guard reads against USB disconnection.

### 2.4 PHIDGET_DELETE — Remove a Channel

```iecst
ok := PHIDGET_DELETE('temp1');
(* Returns: TRUE if the channel was removed from the internal registry *)
```

Closes the channel (if open) and removes it from GoPLC's internal channel map. Use this for cleanup when a device is permanently removed.

### 2.5 PHIDGET_LIST — Enumerate Channels

```iecst
list := PHIDGET_LIST();
(* Returns a string listing all registered channels and their status *)
```

Returns a string describing all channels that have been opened with `PHIDGET_OPEN`, including their attachment state. Useful for diagnostics and HMI display.

### Example: Startup Initialization

```iecst
PROGRAM POU_PhidgetInit
VAR
    state : INT := 0;
    ok : BOOL;
    info : STRING;
END_VAR

CASE state OF
    0: (* Open all channels *)
        ok := PHIDGET_OPEN('temp_ambient', 561234, 0);
        ok := PHIDGET_OPEN('humidity1', 561234, 1);
        ok := PHIDGET_OPEN('voltage_in', 329876, 0);
        ok := PHIDGET_OPEN('relay1', 437891, 0);
        ok := PHIDGET_OPEN('relay2', 437891, 1);
        state := 1;

    1: (* Wait for all devices to attach *)
        IF PHIDGET_IS_ATTACHED('temp_ambient')
           AND PHIDGET_IS_ATTACHED('voltage_in')
           AND PHIDGET_IS_ATTACHED('relay1') THEN
            state := 10;
        END_IF;

    10: (* Running — list channels for diagnostics *)
        info := PHIDGET_LIST();
END_CASE;
END_PROGRAM
```

---

## 3. Reading Sensors

Each sensor type has a dedicated function that returns a value in calibrated engineering units. All read functions take a single `name` parameter — the handle assigned at `PHIDGET_OPEN`.

### 3.1 PHIDGET_READ — Generic Sensor Read

```iecst
value := PHIDGET_READ('sensor1');
(* Returns: REAL — the primary value of whatever sensor type is attached *)
```

Returns the primary measurement value for any sensor. The meaning depends on the device type (voltage for voltage inputs, temperature for temperature sensors, etc.). Use the typed functions below when you need explicit clarity about what you're reading.

### 3.2 PHIDGET_READ_BOOL — Digital Input

```iecst
door_open := PHIDGET_READ_BOOL('door_sensor');
(* Returns: BOOL — TRUE if the digital input is active *)
```

For digital input channels (e.g., HIN1101 touch sensor, 1012 digital input). Returns the boolean state of the input.

### 3.3 PHIDGET_VOLTAGE — Voltage Input

```iecst
volts := PHIDGET_VOLTAGE('voltage_in');
(* Returns: REAL — voltage in Volts *)
```

Reads a voltage input channel. Resolution and range depend on the hardware (e.g., 1002 Voltage Input: 0-5V, 12-bit; VINT VoltageInput: -40 to +40V, 16-bit).

### 3.4 PHIDGET_CURRENT — Current Input

```iecst
amps := PHIDGET_CURRENT('current_probe');
(* Returns: REAL — current in Amps *)
```

Reads a current input channel. Typically used with the 1122 30A Current Sensor or VINT current inputs.

### 3.5 PHIDGET_TEMPERATURE — Temperature Sensor

```iecst
temp_c := PHIDGET_TEMPERATURE('temp_ambient');
(* Returns: REAL — temperature in degrees Celsius *)
```

Reads a temperature channel. Works with thermocouple interfaces (1048, TMP1100), RTD interfaces (TMP1200), and integrated temperature/humidity sensors (HUM1000).

### 3.6 PHIDGET_HUMIDITY — Humidity Sensor

```iecst
rh := PHIDGET_HUMIDITY('humidity1');
(* Returns: REAL — relative humidity in percent (0.0-100.0) *)
```

Reads a humidity channel from sensors like the HUM1000 or 1125.

### 3.7 PHIDGET_RATIO — Ratiometric Sensor

```iecst
ratio := PHIDGET_RATIO('load_cell');
(* Returns: REAL — voltage ratio (V/V) *)
```

Reads a ratiometric bridge input. Used with load cells, strain gauges, and pressure sensors connected to a Wheatstone bridge interface (1046 PhidgetBridge, DAQ1500). The returned value is the ratio of the measured differential voltage to the excitation voltage.

### Example: Environmental Monitoring

```iecst
PROGRAM POU_Environment
VAR
    temp_c : REAL;
    humidity : REAL;
    temp_f : REAL;
    alarm : BOOL := FALSE;
END_VAR

IF PHIDGET_IS_ATTACHED('temp_ambient') THEN
    temp_c := PHIDGET_TEMPERATURE('temp_ambient');
    temp_f := temp_c * 9.0 / 5.0 + 32.0;
END_IF;

IF PHIDGET_IS_ATTACHED('humidity1') THEN
    humidity := PHIDGET_HUMIDITY('humidity1');
END_IF;

(* High-temperature alarm *)
IF temp_c > 40.0 OR humidity > 85.0 THEN
    alarm := TRUE;
ELSE
    alarm := FALSE;
END_IF;
END_PROGRAM
```

### Example: Load Cell Measurement

```iecst
PROGRAM POU_LoadCell
VAR
    raw_ratio : REAL;
    weight_kg : REAL;
    tare_offset : REAL := 0.0;
    scale_factor : REAL := 1000.0;   (* kg per V/V — calibrate per cell *)
END_VAR

IF PHIDGET_IS_ATTACHED('load_cell') THEN
    raw_ratio := PHIDGET_RATIO('load_cell');
    weight_kg := (raw_ratio - tare_offset) * scale_factor;
END_IF;
END_PROGRAM
```

### Example: Voltage and Current Measurement

```iecst
PROGRAM POU_PowerMonitor
VAR
    voltage : REAL;
    current : REAL;
    power_w : REAL;
END_VAR

IF PHIDGET_IS_ATTACHED('voltage_in') AND PHIDGET_IS_ATTACHED('current_probe') THEN
    voltage := PHIDGET_VOLTAGE('voltage_in');
    current := PHIDGET_CURRENT('current_probe');
    power_w := voltage * current;
END_IF;
END_PROGRAM
```

---

## 4. Writing Outputs

Output functions return `BOOL` — `TRUE` on success, `FALSE` on failure (device detached, invalid value, etc.).

### 4.1 PHIDGET_WRITE — Generic Output Write

```iecst
ok := PHIDGET_WRITE('analog_out', 2.5);
(* Writes 2.5 to the output channel *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Channel handle |
| `value` | REAL | Output value (meaning depends on device type) |

Generic write for any output channel. The interpretation of `value` depends on the device.

### 4.2 PHIDGET_WRITE_BOOL — Digital Output

```iecst
ok := PHIDGET_WRITE_BOOL('indicator_led', TRUE);
(* Turns on a digital output *)

ok := PHIDGET_WRITE_BOOL('indicator_led', FALSE);
(* Turns it off *)
```

For digital output channels (e.g., REL1101 isolated digital output, OUT1100 digital output).

### 4.3 PHIDGET_SET_MOTOR — Motor Speed Control

```iecst
(* Full speed forward *)
ok := PHIDGET_SET_MOTOR('drive_motor', 1.0);

(* Half speed reverse *)
ok := PHIDGET_SET_MOTOR('drive_motor', -0.5);

(* Stop *)
ok := PHIDGET_SET_MOTOR('drive_motor', 0.0);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Channel handle |
| `value` | REAL | Speed: -1.0 (full reverse) to 1.0 (full forward) |

Controls DC motor controllers (DCC1000, DCC1001, DCC1002, 1060, 1064). The value is a duty cycle ratio — negative values reverse direction.

### 4.4 PHIDGET_SET_RELAY — Relay Control

```iecst
(* Energize relay *)
ok := PHIDGET_SET_RELAY('relay1', TRUE);

(* De-energize relay *)
ok := PHIDGET_SET_RELAY('relay1', FALSE);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Channel handle |
| `value` | BOOL | TRUE = energized, FALSE = de-energized |

Controls relay channels on relay boards (REL1100, REL1101, 1014, 1017). Functionally equivalent to `PHIDGET_WRITE_BOOL` but provides semantic clarity for relay applications.

### Example: Motor with Safety Interlock

```iecst
PROGRAM POU_MotorControl
VAR
    speed_setpoint : REAL := 0.0;
    e_stop : BOOL;
    ok : BOOL;
END_VAR

(* Read e-stop digital input *)
e_stop := PHIDGET_READ_BOOL('e_stop_input');

IF e_stop THEN
    (* Emergency stop — kill motor immediately *)
    ok := PHIDGET_SET_MOTOR('drive_motor', 0.0);
    ok := PHIDGET_SET_RELAY('motor_contactor', FALSE);
ELSE
    (* Normal operation *)
    ok := PHIDGET_SET_RELAY('motor_contactor', TRUE);
    ok := PHIDGET_SET_MOTOR('drive_motor', speed_setpoint);
END_IF;
END_PROGRAM
```

### Example: Relay Sequencer

```iecst
PROGRAM POU_RelaySequence
VAR
    state : INT := 0;
    scan_count : DINT := 0;
    delay_scans : DINT := 50;   (* ~5 sec at 100ms scan *)
    ok : BOOL;
END_VAR

scan_count := scan_count + 1;

CASE state OF
    0: (* Step 1: Energize pump relay *)
        ok := PHIDGET_SET_RELAY('pump', TRUE);
        scan_count := 0;
        state := 1;

    1: (* Wait for pressure to stabilize *)
        IF scan_count >= delay_scans THEN
            state := 2;
        END_IF;

    2: (* Step 2: Open valve *)
        ok := PHIDGET_SET_RELAY('valve', TRUE);
        scan_count := 0;
        state := 3;

    3: (* Wait for flow *)
        IF scan_count >= delay_scans THEN
            state := 4;
        END_IF;

    4: (* Running — monitor and hold *)
        (* Control logic here *)
END_CASE;
END_PROGRAM
```

---

## 5. Complete Program Example

This example ties together lifecycle, sensor reads, and output control in a single temperature-controlled relay system.

```iecst
PROGRAM POU_TempControl
VAR
    state : INT := 0;
    temp_c : REAL;
    humidity : REAL;
    setpoint : REAL := 25.0;
    deadband : REAL := 1.0;
    cooling_on : BOOL := FALSE;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Initialize — open all channels *)
        ok := PHIDGET_OPEN('temp1', 561234, 0);
        ok := PHIDGET_OPEN('hum1', 561234, 1);
        ok := PHIDGET_OPEN('fan_relay', 437891, 0);
        ok := PHIDGET_OPEN('alarm_relay', 437891, 1);
        state := 1;

    1: (* Wait for attach *)
        IF PHIDGET_IS_ATTACHED('temp1')
           AND PHIDGET_IS_ATTACHED('fan_relay') THEN
            state := 10;
        END_IF;

    10: (* Running — temperature control loop *)
        temp_c := PHIDGET_TEMPERATURE('temp1');
        humidity := PHIDGET_HUMIDITY('hum1');

        (* Deadband control *)
        IF temp_c > (setpoint + deadband) AND NOT cooling_on THEN
            ok := PHIDGET_SET_RELAY('fan_relay', TRUE);
            cooling_on := TRUE;
        ELSIF temp_c < (setpoint - deadband) AND cooling_on THEN
            ok := PHIDGET_SET_RELAY('fan_relay', FALSE);
            cooling_on := FALSE;
        END_IF;

        (* Over-temperature alarm *)
        IF temp_c > 50.0 THEN
            ok := PHIDGET_SET_RELAY('alarm_relay', TRUE);
        ELSE
            ok := PHIDGET_SET_RELAY('alarm_relay', FALSE);
        END_IF;

    99: (* Shutdown *)
        ok := PHIDGET_SET_RELAY('fan_relay', FALSE);
        ok := PHIDGET_SET_RELAY('alarm_relay', FALSE);
        ok := PHIDGET_CLOSE('temp1');
        ok := PHIDGET_CLOSE('hum1');
        ok := PHIDGET_CLOSE('fan_relay');
        ok := PHIDGET_CLOSE('alarm_relay');
END_CASE;
END_PROGRAM
```

---

## 6. Function Quick Reference

| Function | Returns | Description |
|----------|---------|-------------|
| `PHIDGET_OPEN(name, serial, channel)` | BOOL | Open a channel by serial number and channel index |
| `PHIDGET_CLOSE(name)` | BOOL | Close a channel |
| `PHIDGET_IS_ATTACHED(name)` | BOOL | Check if device is physically connected |
| `PHIDGET_DELETE(name)` | BOOL | Remove channel from registry |
| `PHIDGET_LIST()` | STRING | List all registered channels |
| `PHIDGET_READ(name)` | REAL | Generic sensor read (primary value) |
| `PHIDGET_READ_BOOL(name)` | BOOL | Digital input read |
| `PHIDGET_VOLTAGE(name)` | REAL | Voltage input (Volts) |
| `PHIDGET_CURRENT(name)` | REAL | Current input (Amps) |
| `PHIDGET_TEMPERATURE(name)` | REAL | Temperature sensor (degrees C) |
| `PHIDGET_HUMIDITY(name)` | REAL | Humidity sensor (% RH) |
| `PHIDGET_RATIO(name)` | REAL | Ratiometric bridge input (V/V) |
| `PHIDGET_WRITE(name, value)` | BOOL | Generic output write |
| `PHIDGET_WRITE_BOOL(name, value)` | BOOL | Digital output write |
| `PHIDGET_SET_MOTOR(name, value)` | BOOL | Motor speed (-1.0 to 1.0) |
| `PHIDGET_SET_RELAY(name, value)` | BOOL | Relay control (TRUE/FALSE) |

---

*GoPLC v1.0.533 | Phidgets USB Sensor/Actuator Interface*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
