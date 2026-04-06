# GoPLC SEL Protective Relay Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Architecture Overview

GoPLC implements the **SEL Fast Message** and **SEL ASCII** protocols for communicating with Schweitzer Engineering Laboratories protective relays. Three roles are supported:

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | 30 | Connect to real relays — read metering, status, events, oscillography, mirrored bits |
| **Server** | 12 | Emulate a relay on serial — for testing, simulation, and hardware-in-the-loop |
| **Meter** | 11 | Emulate an SEL metering device on TCP — for SCADA integration testing |

### Supported Relay Models

SEL-311, SEL-351, SEL-387, SEL-421, SEL-451, SEL-487, SEL-551, SEL-651, SEL-700, SEL-735, SEL-751, SEL-787

### System Diagram

```
┌──────────────────────────────────────────────────────────┐
│  GoPLC Runtime                                           │
│                                                          │
│  ┌────────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ SEL Client     │  │ SEL Server   │  │ SEL Meter    │  │
│  │                │  │              │  │              │  │
│  │ Read metering  │  │ Emulate      │  │ Emulate      │  │
│  │ Mirrored bits  │  │ relay on     │  │ SEL-735 on   │  │
│  │ SER events     │  │ serial port  │  │ TCP port     │  │
│  │ Oscillography  │  │              │  │              │  │
│  │ Settings R/W   │  │              │  │              │  │
│  └───────┬────────┘  └──────┬───────┘  └──────┬───────┘  │
│          │ Serial           │ Serial          │ TCP       │
└──────────┼──────────────────┼─────────────────┼───────────┘
           │                  │                 │
           ▼                  ▼                 ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │  SEL Relay   │  │  Test        │  │  SCADA /     │
    │  (real HW)   │  │  Equipment   │  │  HMI Client  │
    └──────────────┘  └──────────────┘  └──────────────┘
```

### Protocols

| Protocol | Transport | Use |
|----------|-----------|-----|
| **SEL Fast Message** | Serial (binary) | Mirrored bits, real-time data exchange |
| **SEL ASCII** | Serial (text) | Commands, metering, settings, SER, oscillography |
| **SEL Metering** | TCP | Meter emulation (voltage, current, power, energy) |

---

## 2. Client — Connect to Real Relays

### Connection

```iecst
PROGRAM POU_SELRelay
VAR
    state : INT := 0;
    ok : BOOL;
    device_id : STRING;
    device_type : STRING;
END_VAR

CASE state OF
    0: (* Connect to relay on serial port *)
        ok := SEL_CLIENT_CREATE('relay1', '/dev/ttyUSB0');
        IF ok THEN state := 1; END_IF;

    1: (* Establish connection *)
        ok := SEL_CLIENT_CONNECT('relay1');
        IF ok THEN state := 2; END_IF;

    2: (* Identify device *)
        device_id := SEL_CLIENT_GET_DEVICE_ID('relay1');
        device_type := SEL_CLIENT_GET_DEVICE_TYPE('relay1');
        state := 10;

    10: (* Running *)
        IF NOT SEL_CLIENT_IS_CONNECTED('relay1') THEN
            state := 1;
        END_IF;
END_CASE;
END_PROGRAM
```

### Metering Data

Read 3-phase voltage, current, power, and frequency from the relay:

```iecst
metering := SEL_CLIENT_GET_METERING('relay1');
(* Returns map:
   voltage_a, voltage_b, voltage_c    — Line-to-neutral RMS
   current_a, current_b, current_c, current_n  — Phase + neutral RMS
   power_real, power_reactive, power_apparent   — kW, kVAR, kVA
   power_factor                        — PF
   frequency                           — Hz
*)
```

### Status

```iecst
status := SEL_CLIENT_GET_STATUS('relay1');
(* Returns map:
   word        — Raw status word
   trip        — Trip output active
   close       — Close output active
   alarm       — Alarm condition
   fault       — Fault detected
   in_service  — Relay in service
   test_mode   — Test mode active
   comm        — Communication OK
   healthy     — Overall healthy
*)
```

### Access Levels

SEL relays have password-protected access levels:

| Level | Permission |
|-------|-----------|
| 1 | Read metering only |
| 2 | Change settings |
| 3 | Control outputs |
| 4 | Super admin |
| 5 | Factory |

```iecst
level := SEL_CLIENT_GET_ACCESS_LEVEL('relay1');
```

### Mirrored Bits

32-bit real-time status/control exchange using SEL Fast Message protocol. Local bits transmit to the relay; remote bits receive from the relay.

```iecst
(* Start mirrored bits exchange *)
SEL_CLIENT_START_MIRRORED_BITS('relay1');

(* Set local bits (GoPLC → Relay) *)
SEL_CLIENT_SET_LOCAL_BIT('relay1', 1, TRUE);     (* Bit 1 = Run permit *)
SEL_CLIENT_SET_LOCAL_BIT('relay1', 2, FALSE);    (* Bit 2 = Reset *)

(* Read remote bits (Relay → GoPLC) *)
trip := SEL_CLIENT_GET_REMOTE_BIT('relay1', 1);   (* Bit 1 = Trip status *)
close := SEL_CLIENT_GET_REMOTE_BIT('relay1', 2);  (* Bit 2 = Close status *)

(* Bulk operations *)
SEL_CLIENT_SET_LOCAL_BITS('relay1', local_word);   (* Set all 32 bits *)
remote_word := SEL_CLIENT_GET_REMOTE_BITS('relay1'); (* Read all 32 bits *)
all_local := SEL_CLIENT_GET_LOCAL_BITS('relay1');    (* Read back local *)

(* Stop exchange *)
SEL_CLIENT_STOP_MIRRORED_BITS('relay1');
```

### Sequential Events Recorder (SER)

Read timestamped fault and event records from the relay:

```iecst
(* Check how many events are stored *)
count := SEL_CLIENT_GET_SER_COUNT('relay1');

(* Read last 10 events *)
events := SEL_CLIENT_READ_SER('relay1', 10);
(* Returns array of event records:
   [{index, timestamp, element, state, value}, ...] *)

(* Clear event log *)
SEL_CLIENT_CLEAR_SER('relay1');
```

### Settings

Read and write relay settings, switch between setting groups (1-6):

```iecst
(* Read current active group *)
group := SEL_CLIENT_GET_ACTIVE_GROUP('relay1');

(* Read a setting *)
pickup := SEL_CLIENT_READ_SETTING('relay1', '51P1P');

(* Write a setting (requires access level 2+) *)
SEL_CLIENT_WRITE_SETTING('relay1', '51P1P', '5.0');

(* Switch to settings group 2 *)
SEL_CLIENT_SWITCH_GROUP('relay1', 2);
```

### Oscillography (Fault Waveforms)

Retrieve fault waveform captures and export as COMTRADE format:

```iecst
(* Check available captures *)
osc_count := SEL_CLIENT_GET_OSCILLOGRAPHY_COUNT('relay1');

(* Read waveform data for event #1 *)
waveform := SEL_CLIENT_READ_OSCILLOGRAPHY('relay1', 1);

(* Export as IEEE COMTRADE (cfg + dat files) *)
comtrade := SEL_CLIENT_EXPORT_COMTRADE('relay1', 1);
```

### Raw Commands

Send any SEL ASCII protocol command:

```iecst
response := SEL_CLIENT_SEND_COMMAND('relay1', 'MET');
response := SEL_CLIENT_SEND_COMMAND('relay1', 'ID');
response := SEL_CLIENT_SEND_COMMAND('relay1', 'SHO T');
```

---

## 3. Server — Emulate a Relay

Emulate a real SEL relay on a serial port for testing. SCADA systems and test equipment connect to the emulated relay as if it were real hardware.

```iecst
PROGRAM POU_SELSimulator
VAR
    state : INT := 0;
    ok : BOOL;
    sim_va : REAL := 120.0;
    sim_ia : REAL := 5.2;
END_VAR

CASE state OF
    0: (* Create relay emulator on serial port *)
        ok := SEL_SERVER_CREATE('sim', '/dev/ttyUSB1');
        IF ok THEN state := 1; END_IF;

    1: (* Start listening *)
        ok := SEL_SERVER_START('sim');
        IF ok THEN state := 10; END_IF;

    10: (* Running — update simulated values *)
        (* Push 3-phase metering *)
        SEL_SERVER_SET_METERING('sim',
            sim_va, sim_va, sim_va,      (* VA, VB, VC *)
            sim_ia, sim_ia, sim_ia);     (* IA, IB, IC *)

        (* Update status bits *)
        SEL_SERVER_SET_STATUS('sim',
            0,         (* status word *)
            FALSE,     (* trip *)
            FALSE,     (* close *)
            FALSE,     (* alarm *)
            FALSE,     (* fault *)
            TRUE);     (* in_service *)

        (* Mirrored bits *)
        SEL_SERVER_SET_LOCAL_BIT('sim', 1, TRUE);
        trip_cmd := SEL_SERVER_GET_REMOTE_BIT('sim', 1);
END_CASE;
END_PROGRAM
```

---

## 4. Meter — TCP Metering Emulator

Emulate an SEL-735 (or similar) metering device over TCP. Provides 3-phase power quality data to connected clients.

```iecst
PROGRAM POU_SELMeter
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create meter emulator on TCP port 7025 *)
        ok := SEL_METER_CREATE('meter1', 7025);
        IF ok THEN state := 1; END_IF;

    1: (* Start TCP listener *)
        ok := SEL_METER_START('meter1');
        IF ok THEN state := 10; END_IF;

    10: (* Running — push metering data *)
        SEL_METER_SET_VOLTAGE('meter1', 120.1, 119.8, 120.3);
        SEL_METER_SET_CURRENT('meter1', 5.2, 4.9, 5.1, 0.3);
        SEL_METER_SET_FREQ('meter1', 60.02);
        SEL_METER_SET_POWER('meter1',
            1.87,      (* kW *)
            0.42,      (* kVAR *)
            1.92,      (* kVA *)
            0.97);     (* PF *)
        SEL_METER_SET_ENERGY('meter1',
            15234.5,   (* Forward kWh *)
            123.4,     (* Reverse kWh *)
            4521.2);   (* Forward kVARh *)
        SEL_METER_SET_DEMAND('meter1', 1.65);     (* 15-min demand kW *)
        SEL_METER_SET_THD('meter1', 3.2, 8.5);    (* THDv%, THDi% *)
END_CASE;
END_PROGRAM
```

---

## 5. Complete Example: Substation Gateway

Bridge SEL relay data to MQTT for remote monitoring:

```iecst
PROGRAM POU_SubstationGateway
VAR
    state : INT := 0;
    ok : BOOL;
    scan_count : DINT := 0;
    metering : STRING;
    status : STRING;
    payload : STRING;
END_VAR

CASE state OF
    0: (* Initialize *)
        ok := SEL_CLIENT_CREATE('feeder1', '/dev/ttyUSB0');
        ok := SEL_CLIENT_CONNECT('feeder1');
        ok := MQTT_CLIENT_CREATE('scada', 'tcp://10.0.0.144:1883', 'sub-gw');
        ok := MQTT_CLIENT_CONNECT('scada');
        SEL_CLIENT_START_MIRRORED_BITS('feeder1');
        state := 10;

    10: (* Running *)
        scan_count := scan_count + 1;

        (* Publish metering every 100 scans (10s) *)
        IF (scan_count MOD 100) = 0 THEN
            metering := SEL_CLIENT_GET_METERING('feeder1');
            MQTT_PUBLISH('scada', 'substation/feeder1/metering',
                         JSON_STRINGIFY(metering));
        END_IF;

        (* Publish status on change *)
        status := SEL_CLIENT_GET_STATUS('feeder1');
        MQTT_PUBLISH('scada', 'substation/feeder1/status',
                     JSON_STRINGIFY(status));

        (* Forward mirrored bits as MQTT *)
        IF SEL_CLIENT_GET_REMOTE_BIT('feeder1', 1) THEN
            MQTT_PUBLISH('scada', 'substation/feeder1/trip', 'TRUE');
        END_IF;

        (* Reconnect on failure *)
        IF NOT SEL_CLIENT_IS_CONNECTED('feeder1') THEN
            SEL_CLIENT_CONNECT('feeder1');
        END_IF;
END_CASE;
END_PROGRAM
```

---

## Appendix A: Quick Reference

### Client Functions (30)

| Function | Returns | Description |
|----------|---------|-------------|
| `SEL_CLIENT_CREATE(name, port)` | BOOL | Create serial connection |
| `SEL_CLIENT_CONNECT(name)` | BOOL | Start polling |
| `SEL_CLIENT_DISCONNECT(name)` | BOOL | Stop polling |
| `SEL_CLIENT_IS_CONNECTED(name)` | BOOL | Check state |
| `SEL_CLIENT_DELETE(name)` | BOOL | Remove client |
| `SEL_CLIENT_LIST()` | ARRAY | All client names |
| `SEL_CLIENT_SEND_COMMAND(name, cmd)` | STRING | Raw ASCII command |
| `SEL_CLIENT_GET_DEVICE_ID(name)` | STRING | Relay serial number |
| `SEL_CLIENT_GET_DEVICE_TYPE(name)` | STRING | Relay model |
| `SEL_CLIENT_GET_ACCESS_LEVEL(name)` | INT | Password level (1-5) |
| `SEL_CLIENT_GET_METERING(name)` | MAP | V/I/P/PF/Hz |
| `SEL_CLIENT_GET_STATUS(name)` | MAP | Trip/close/alarm/fault/healthy |
| `SEL_CLIENT_START_MIRRORED_BITS(name)` | BOOL | Begin bit exchange |
| `SEL_CLIENT_STOP_MIRRORED_BITS(name)` | BOOL | End bit exchange |
| `SEL_CLIENT_SET_LOCAL_BIT(name, bit, val)` | BOOL | Set outgoing bit (1-32) |
| `SEL_CLIENT_SET_LOCAL_BITS(name, word)` | BOOL | Set all 32 bits |
| `SEL_CLIENT_GET_LOCAL_BIT(name, bit)` | BOOL | Read local bit |
| `SEL_CLIENT_GET_LOCAL_BITS(name)` | INT | Read all 32 local bits |
| `SEL_CLIENT_GET_REMOTE_BIT(name, bit)` | BOOL | Read incoming bit |
| `SEL_CLIENT_GET_REMOTE_BITS(name)` | INT | Read all 32 remote bits |
| `SEL_CLIENT_GET_SER_COUNT(name)` | INT | Event count |
| `SEL_CLIENT_READ_SER(name, count)` | ARRAY | Read event records |
| `SEL_CLIENT_CLEAR_SER(name)` | BOOL | Clear event log |
| `SEL_CLIENT_GET_ACTIVE_GROUP(name)` | INT | Active settings group (1-6) |
| `SEL_CLIENT_SWITCH_GROUP(name, group)` | BOOL | Change settings group |
| `SEL_CLIENT_READ_SETTING(name, setting)` | STRING | Read setting value |
| `SEL_CLIENT_WRITE_SETTING(name, setting, val)` | BOOL | Write setting |
| `SEL_CLIENT_GET_OSCILLOGRAPHY_COUNT(name)` | INT | Waveform capture count |
| `SEL_CLIENT_READ_OSCILLOGRAPHY(name, num)` | MAP | Read waveform data |
| `SEL_CLIENT_EXPORT_COMTRADE(name, num)` | MAP | Export as COMTRADE (cfg+dat) |

### Server Functions (12)

| Function | Returns | Description |
|----------|---------|-------------|
| `SEL_SERVER_CREATE(name, port)` | BOOL | Create relay emulator |
| `SEL_SERVER_START(name)` | BOOL | Start listening |
| `SEL_SERVER_STOP(name)` | BOOL | Stop listening |
| `SEL_SERVER_IS_RUNNING(name)` | BOOL | Check state |
| `SEL_SERVER_DELETE(name)` | BOOL | Remove server |
| `SEL_SERVER_LIST()` | ARRAY | All server names |
| `SEL_SERVER_SET_METERING(name, va,vb,vc, ia,ib,ic)` | BOOL | Push 3-phase data |
| `SEL_SERVER_SET_STATUS(name, word,trip,close,alarm,fault,in_svc)` | BOOL | Update status |
| `SEL_SERVER_SET_LOCAL_BIT(name, bit, val)` | BOOL | Set outgoing bit |
| `SEL_SERVER_GET_REMOTE_BIT(name, bit)` | BOOL | Read incoming bit |
| `SEL_SERVER_START_MIRRORED_BITS(name)` | BOOL | Begin bit exchange |
| `SEL_SERVER_STOP_MIRRORED_BITS(name)` | BOOL | End bit exchange |

### Meter Functions (11)

| Function | Returns | Description |
|----------|---------|-------------|
| `SEL_METER_CREATE(name, port)` | BOOL | Create TCP meter emulator |
| `SEL_METER_START(name)` | BOOL | Start TCP listener |
| `SEL_METER_STOP(name)` | BOOL | Stop listener |
| `SEL_METER_IS_RUNNING(name)` | BOOL | Check state |
| `SEL_METER_DELETE(name)` | BOOL | Remove meter |
| `SEL_METER_SET_VOLTAGE(name, va, vb, vc)` | BOOL | 3-phase voltage RMS |
| `SEL_METER_SET_CURRENT(name, ia, ib, ic, in)` | BOOL | 3-phase + neutral current |
| `SEL_METER_SET_FREQ(name, hz)` | BOOL | Grid frequency |
| `SEL_METER_SET_POWER(name, kw, kvar, kva, pf)` | BOOL | Power values |
| `SEL_METER_SET_ENERGY(name, fwd_kwh, rev_kwh, fwd_kvarh)` | BOOL | Energy counters |
| `SEL_METER_SET_DEMAND(name, kw)` | BOOL | 15-min demand |
| `SEL_METER_SET_THD(name, thdv, thdi)` | BOOL | Harmonic distortion % |

---

*GoPLC v1.0.535 | SEL Fast Message + ASCII Protocol | 54 Functions | Protective Relay Integration*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
