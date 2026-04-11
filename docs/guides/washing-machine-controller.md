# GoPLC Smart Washing Machine Controller

> **DISCLAIMER:** This is a hypothetical project guide for educational and demonstration
> purposes. It illustrates how GoPLC can be used for appliance control. **All responsibility
> for implementation, safety, electrical work, and compliance with local codes lies entirely
> with the user.** Modifying appliances involves mains voltage and water — improper work
> can cause electrocution, fire, flooding, or property damage. Consult a licensed electrician
> before attempting any mains wiring.

Replace a dead washing machine control board with a Raspberry Pi running GoPLC,
Waveshare Modbus I/O modules, and a phone dashboard via Node-RED.

> **Skill level:** Intermediate (basic electrical wiring, comfortable with terminal blocks)
>
> **Safety:** This project involves 120VAC mains wiring. All high-voltage connections
> must be made by a qualified person. Follow your local electrical code.

---

## Why GoPLC for Appliance Control?

A modern washing machine controller is just a small PLC: it sequences valves, motors,
and pumps based on sensor inputs, runs safety interlocks, and follows a state machine.
Factory boards are expensive, proprietary, and non-repairable. GoPLC gives you:

- **Full control** over every cycle parameter — wash time, spin speed, water level, temperature
- **Phone dashboard** via Node-RED — start/stop, cycle selection, status, push notifications
- **Real industrial I/O** — Waveshare DIN-rail Modbus modules rated for 10A 250VAC relays
- **State machine in Structured Text** — readable, modifiable, no black-box firmware
- **Expandable** — add sensors, logging, energy monitoring, or integrate with home automation

---

## System Architecture

```
                                    RS485 Bus (daisy-chain)
                                   ┌──────────────────────────────┐
  ┌──────────────┐   Ethernet      │                              │
  │ Raspberry Pi │──────────────►┌─┴──────────────┐  ┌───────────┴────────────┐
  │   + GoPLC    │  Modbus TCP   │ Waveshare      │  │ Waveshare              │
  │              │               │ RS485-to-ETH   │  │ Modbus RTU Analog      │
  │  Node-RED    │               │ Gateway        │  │ Input 8CH              │
  │  Dashboard   │               └─┬──────────────┘  │ (Slave ID 2)           │
  └──────────────┘                 │                  │ - Water temperature    │
         │                         │                  │ - Motor current        │
      WiFi/LAN                  ┌──┴──────────────┐   │ - Water pressure/level │
         │                      │ Waveshare       │  └────────────────────────┘
    ┌────┴─────┐                │ Modbus RTU      │
    │  Phone   │                │ Relay (D)       │
    │Dashboard │                │ (Slave ID 1)    │
    └──────────┘                │ 8 Relay + 8 DI  │
                                └─────────────────┘
                                       │
                            ┌──────────┴──────────┐
                            │  Washing Machine    │
                            │  Valves, Motor,     │
                            │  Pump, Door Lock,   │
                            │  Sensors            │
                            └─────────────────────┘
```

**Data flow:** GoPLC runs the wash cycle state machine in Structured Text. Each scan
(100ms), it reads sensors via Modbus TCP through the Waveshare gateway, runs control
logic, and writes relay outputs. Node-RED provides the operator interface on any browser.

---

## Bill of Materials

| # | Item | Purpose | Est. Cost |
|---|------|---------|-----------|
| 1 | Raspberry Pi 2/3/4/5 | Runs GoPLC + Node-RED | $35-80 |
| 2 | MicroSD card (32GB+) | Pi OS + GoPLC | $8 |
| 3 | Waveshare RS485 TO ETH (B) | Modbus TCP-to-RTU gateway | $20 |
| 4 | Waveshare Modbus RTU Relay (D) | 8 relay outputs + 8 digital inputs | $35 |
| 5 | Waveshare Modbus RTU Analog Input 8CH | Analog sensor inputs (12-bit) | $30 |
| 6 | DIN rail power supply 120VAC to 24VDC (60W) | Powers all Modbus modules + sensors | $15 |
| 7 | DIN rail circuit breaker 15A | Branch protection for 120VAC loads | $8 |
| 8 | DIN rail terminal blocks (20-pack) | All point-to-point wiring connections | $12 |
| 9 | 35mm DIN rail (1 meter) | Mounting for all DIN components | $6 |
| 10 | Enclosure (IP54 or better) | Houses all control components | $25-40 |
| 11 | 18 AWG stranded wire (assorted colors) | 120VAC load wiring | $15 |
| 12 | 22 AWG stranded wire (assorted colors) | 24VDC signal/sensor wiring | $10 |
| 13 | Wire ferrules + crimp tool | Clean terminal connections | $20 |
| 14 | Ethernet cable (Cat5e, length as needed) | Pi to RS485-to-ETH gateway | $5 |
| | | **Total (approx.)** | **$245-305** |

### About the Waveshare Modules

**RS485 TO ETH (B)** — Bridges Modbus TCP (Ethernet) to Modbus RTU (RS485). Configure
it in "Modbus TCP to RTU gateway" mode. GoPLC talks standard Modbus TCP; the gateway
handles serial framing and timing on the RS485 side. Supports 9-24V power, DIN rail mount.

**Modbus RTU Relay (D)** — 8 relay outputs (10A 250VAC each) + 8 optocoupled digital
inputs. 7-36V power. DIN rail mount. Default: slave 1, 9600 baud, 8N1.

**Modbus RTU Analog Input 8CH** — 8 channels, 12-bit resolution. Configurable per-channel:
0-10V, 2-10V, 0-20mA, or 4-20mA. 7-36V power. DIN rail mount. Default: slave 1
(**must be changed to slave 2** before connecting to the bus).

---

## I/O Assignment

### Relay (D) Module — Slave ID 1

#### Relay Outputs (Coils 0x0000-0x0007)

| Relay | Coil Addr | Function | Load | Notes |
|-------|-----------|----------|------|-------|
| CH1 | 0x0000 | Hot water inlet valve | 120VAC solenoid | Normally closed valve |
| CH2 | 0x0001 | Cold water inlet valve | 120VAC solenoid | Normally closed valve |
| CH3 | 0x0002 | Drain pump | 120VAC motor | ~1A typical |
| CH4 | 0x0003 | Door lock solenoid | 24VDC solenoid | Energize to lock |
| CH5 | 0x0004 | Motor - agitate | 120VAC contactor coil | Low speed, reversing |
| CH6 | 0x0005 | Motor - spin | 120VAC contactor coil | High speed, one direction |
| CH7 | 0x0006 | Buzzer | 24VDC buzzer | Cycle complete alert |
| CH8 | 0x0007 | Spare | — | Future: fabric softener valve |

#### Digital Inputs (Discrete Inputs 0x0000-0x0007)

| Input | Addr | Function | Type | Notes |
|-------|------|----------|------|-------|
| DI1 | 0x0000 | Door closed | N.O. switch | TRUE = door closed |
| DI2 | 0x0001 | Door locked feedback | N.O. contact | TRUE = lock engaged |
| DI3 | 0x0002 | Water level - low | Pressure switch | TRUE = above minimum |
| DI4 | 0x0003 | Water level - medium | Pressure switch | TRUE = medium fill |
| DI5 | 0x0004 | Water level - high | Pressure switch | TRUE = full |
| DI6 | 0x0005 | Motor overload trip | N.C. thermal OL | FALSE = tripped |
| DI7 | 0x0006 | Water leak detected | Leak sensor | TRUE = leak |
| DI8 | 0x0007 | Spare | — | — |

### Analog Input Module — Slave ID 2

| Channel | Reg Addr | Function | Range | Sensor |
|---------|----------|----------|-------|--------|
| CH1 | 0x0000 | Water temperature | 4-20mA | PT100 transmitter (0-100C) |
| CH2 | 0x0001 | Motor current | 0-10V | Split-core CT + signal conditioner |
| CH3 | 0x0002 | Vibration | 0-10V | Accelerometer module |
| CH4-8 | 0x0003-0x0007 | Spare | — | — |

---

## Wiring — Point to Point

### Power Distribution

| From | To | Wire | Notes |
|------|----|------|-------|
| Mains 120VAC Hot | CB-15A input | 14 AWG black | House breaker should also protect this circuit |
| CB-15A output | Terminal TB-HOT | 14 AWG black | Fused 120VAC hot bus |
| Mains 120VAC Neutral | Terminal TB-NEU | 14 AWG white | Neutral bus |
| Mains Ground | Terminal TB-GND | 14 AWG green | Ground bus, bond to enclosure |
| TB-HOT | 24VDC PSU L input | 18 AWG black | PSU line input |
| TB-NEU | 24VDC PSU N input | 18 AWG white | PSU neutral input |
| TB-GND | 24VDC PSU GND input | 18 AWG green | PSU earth ground |
| 24VDC PSU +V out | Terminal TB-24V+ | 18 AWG red | 24VDC positive bus |
| 24VDC PSU -V out | Terminal TB-24V- | 18 AWG blue | 24VDC negative bus (0V) |
| TB-24V+ | Relay (D) V+ | 22 AWG red | Module power |
| TB-24V- | Relay (D) V- | 22 AWG blue | Module power |
| TB-24V+ | Analog Input V+ | 22 AWG red | Module power |
| TB-24V- | Analog Input V- | 22 AWG blue | Module power |
| TB-24V+ | RS485-to-ETH V+ | 22 AWG red | Gateway power (9-24V) |
| TB-24V- | RS485-to-ETH V- | 22 AWG blue | Gateway power |

### RS485 Bus (Daisy-Chain)

| From | To | Wire | Notes |
|------|----|------|-------|
| RS485-to-ETH A+ | Relay (D) A | 22 AWG twisted pair | Use shielded twisted pair |
| RS485-to-ETH B- | Relay (D) B | 22 AWG twisted pair | Same pair |
| Relay (D) A | Analog Input A | 22 AWG twisted pair | Continue daisy chain |
| Relay (D) B | Analog Input B | 22 AWG twisted pair | Same pair |
| Analog Input A-B | 120 ohm resistor | — | Termination at last device on bus |
| Cable shield | TB-GND | — | Ground shield at one end only |

### Ethernet

| From | To | Wire | Notes |
|------|----|------|-------|
| Pi Ethernet port | RS485-to-ETH RJ45 | Cat5e patch cable | Standard Ethernet |

### Relay Outputs to Loads

| From | To | Wire | Notes |
|------|----|------|-------|
| TB-HOT | Relay CH1 COM | 18 AWG black | Hot water valve circuit |
| Relay CH1 N.O. | Hot water valve | 18 AWG black | Valve other wire to TB-NEU |
| TB-HOT | Relay CH2 COM | 18 AWG black | Cold water valve circuit |
| Relay CH2 N.O. | Cold water valve | 18 AWG black | Valve other wire to TB-NEU |
| TB-HOT | Relay CH3 COM | 18 AWG black | Drain pump circuit |
| Relay CH3 N.O. | Drain pump | 18 AWG black | Pump other wire to TB-NEU |
| TB-24V+ | Relay CH4 COM | 22 AWG red | Door lock circuit (24VDC) |
| Relay CH4 N.O. | Door lock solenoid + | 22 AWG red | Solenoid - to TB-24V- |
| TB-HOT | Relay CH5 COM | 18 AWG black | Motor agitate contactor |
| Relay CH5 N.O. | Agitate contactor coil | 18 AWG black | Coil other side to TB-NEU |
| TB-HOT | Relay CH6 COM | 18 AWG black | Motor spin contactor |
| Relay CH6 N.O. | Spin contactor coil | 18 AWG black | Coil other side to TB-NEU |
| TB-24V+ | Relay CH7 COM | 22 AWG red | Buzzer circuit (24VDC) |
| Relay CH7 N.O. | Buzzer + | 22 AWG red | Buzzer - to TB-24V- |

### Digital Inputs

The Relay (D) module supports passive (dry contact) and active (wet contact) inputs.
Wire all inputs as dry contacts with the module's internal pull-up:

| From | To | Wire | Notes |
|------|----|------|-------|
| Relay (D) DI1 | Door closed switch N.O. | 22 AWG | Switch other terminal to DI COM |
| Relay (D) DI2 | Door lock feedback N.O. | 22 AWG | Contact other terminal to DI COM |
| Relay (D) DI3 | Level switch - low | 22 AWG | Closes at low water level |
| Relay (D) DI4 | Level switch - medium | 22 AWG | Closes at medium level |
| Relay (D) DI5 | Level switch - high | 22 AWG | Closes at high level |
| Relay (D) DI6 | Motor thermal O/L N.C. | 22 AWG | Opens on overload trip |
| Relay (D) DI7 | Leak sensor N.O. | 22 AWG | Closes on water detection |
| DI COM (all) | TB-24V- | 22 AWG | Common return for all DIs |

### Analog Inputs

| From | To | Wire | Notes |
|------|----|------|-------|
| TB-24V+ | PT100 transmitter + | 22 AWG red | Loop power for 4-20mA |
| PT100 transmitter signal | Analog CH1 + | 22 AWG | 4-20mA signal |
| Analog CH1 - | TB-24V- | 22 AWG blue | Return |
| Motor CT signal + | Analog CH2 + | 22 AWG | 0-10V from CT conditioner |
| Motor CT signal - | Analog CH2 - | 22 AWG | Signal ground |
| Vibration sensor + | Analog CH3 + | 22 AWG | 0-10V from accelerometer |
| Vibration sensor - | Analog CH3 - | 22 AWG | Signal ground |

---

## Waveshare Gateway Configuration

Before connecting, configure the RS485-to-ETH gateway via its web interface
(default IP: 192.168.1.200):

1. Set a static IP on your network (e.g., 192.168.1.100)
2. Mode: **Modbus TCP to RTU**
3. Serial: **9600 baud, 8N1** (matches Waveshare module defaults)
4. TCP port: **502** (standard Modbus TCP port)

Also set the Analog Input module slave address to **2** (default is 1, same as the
Relay module — they must be different). Use the module's configuration software or
send the Modbus command to write holding register 0x4000 with value 0x0002.

---

## GoPLC Configuration

### Project File Setup

Create a new GoPLC project or add to an existing one. The washer needs two tasks:

- **wash_main** — Cycle state machine, I/O scanning, interlocks (100ms scan)
- **wash_monitor** — Analog scaling, trending, diagnostics (500ms scan)

### YAML Task Configuration

```yaml
tasks:
  - name: wash_main
    program: POU_WashMain
    scan_time_ms: 100
  - name: wash_monitor
    program: POU_WashMonitor
    scan_time_ms: 500
```

---

## ST Programs

### GVL — Global Variables

```iecst
VAR_GLOBAL
    (* --- Modbus Connection --- *)
    gw_ip           : STRING := '192.168.1.100';  (* RS485-to-ETH gateway IP *)
    gw_port         : INT := 502;
    mb_connected     : BOOL := FALSE;

    (* --- Relay Outputs (coil addresses) --- *)
    COIL_HOT_VALVE   : INT := 0;   (* CH1 *)
    COIL_COLD_VALVE  : INT := 1;   (* CH2 *)
    COIL_DRAIN_PUMP  : INT := 2;   (* CH3 *)
    COIL_DOOR_LOCK   : INT := 3;   (* CH4 *)
    COIL_MOTOR_AGIT  : INT := 4;   (* CH5 *)
    COIL_MOTOR_SPIN  : INT := 5;   (* CH6 *)
    COIL_BUZZER      : INT := 6;   (* CH7 *)

    (* --- Output Commands (written by state machine) --- *)
    cmd_hot_valve    : BOOL := FALSE;
    cmd_cold_valve   : BOOL := FALSE;
    cmd_drain_pump   : BOOL := FALSE;
    cmd_door_lock    : BOOL := FALSE;
    cmd_motor_agit   : BOOL := FALSE;
    cmd_motor_spin   : BOOL := FALSE;
    cmd_buzzer       : BOOL := FALSE;

    (* --- Digital Input States (read from module) --- *)
    di_door_closed   : BOOL := FALSE;
    di_door_locked   : BOOL := FALSE;
    di_level_low     : BOOL := FALSE;
    di_level_med     : BOOL := FALSE;
    di_level_high    : BOOL := FALSE;
    di_motor_ol_ok   : BOOL := TRUE;   (* N.C. — TRUE = healthy *)
    di_leak_detect   : BOOL := FALSE;

    (* --- Analog Values (scaled) --- *)
    water_temp_c     : REAL := 0.0;    (* Degrees C *)
    motor_current_a  : REAL := 0.0;    (* Amps *)
    vibration_g      : REAL := 0.0;    (* g-force *)

    (* --- Cycle Settings (set from dashboard) --- *)
    cycle_select     : INT := 0;       (* 0=none, 1=normal, 2=heavy, 3=delicate, 4=rinse_only *)
    water_temp_set   : INT := 1;       (* 0=cold, 1=warm, 2=hot *)
    water_level_set  : INT := 1;       (* 0=low, 1=medium, 2=high *)
    extra_rinse      : BOOL := FALSE;
    cmd_start        : BOOL := FALSE;  (* Start button from dashboard *)
    cmd_stop         : BOOL := FALSE;  (* Stop/cancel from dashboard *)

    (* --- Cycle Parameters (set by cycle_select) --- *)
    wash_time_s      : INT := 600;     (* Wash duration seconds *)
    rinse_time_s     : INT := 300;     (* Rinse duration seconds *)
    spin_time_s      : INT := 360;     (* Spin duration seconds *)
    agitate_on_s     : INT := 10;      (* Agitate on-time per stroke *)
    agitate_off_s    : INT := 3;       (* Pause between strokes *)

    (* --- State Machine --- *)
    wash_state       : INT := 0;       (* Current state *)
    state_timer      : DINT := 0;      (* Seconds in current state *)
    cycle_active     : BOOL := FALSE;
    fault_code       : INT := 0;       (* 0=none, see fault list *)
    fault_active     : BOOL := FALSE;

    (* --- State Constants --- *)
    ST_IDLE          : INT := 0;
    ST_DOOR_LOCK     : INT := 1;
    ST_FILL_WASH     : INT := 2;
    ST_HEAT_WAIT     : INT := 3;
    ST_AGITATE       : INT := 4;
    ST_DRAIN_1       : INT := 5;
    ST_FILL_RINSE    : INT := 6;
    ST_RINSE         : INT := 7;
    ST_DRAIN_2       : INT := 8;
    ST_SPIN          : INT := 9;
    ST_DRAIN_FINAL   : INT := 10;
    ST_COMPLETE      : INT := 11;
    ST_FAULT         : INT := 99;

    (* --- Fault Codes --- *)
    FLT_NONE         : INT := 0;
    FLT_DOOR_OPEN    : INT := 1;
    FLT_DOOR_LOCK    : INT := 2;   (* Lock didn't engage in time *)
    FLT_FILL_TIMEOUT : INT := 3;   (* Didn't reach level in 5 min *)
    FLT_MOTOR_OL     : INT := 4;   (* Motor thermal overload *)
    FLT_LEAK         : INT := 5;   (* Water leak detected *)
    FLT_UNBALANCE    : INT := 6;   (* Excessive vibration in spin *)
    FLT_TEMP_HIGH    : INT := 7;   (* Water over-temperature *)
    FLT_COMM_LOSS    : INT := 8;   (* Modbus communication lost *)

    (* --- Diagnostics --- *)
    total_cycles     : DINT := 0;
    scan_counter     : DINT := 0;
    agitate_toggle   : BOOL := FALSE;  (* Alternates for agitate stroke *)
    agitate_timer    : DINT := 0;
    spin_ramp_done   : BOOL := FALSE;
    rinse_count      : INT := 0;       (* Tracks rinse passes *)
END_VAR
```

### POU_WashMain — Main Cycle Controller

```iecst
PROGRAM POU_WashMain
VAR
    mb_init_done   : BOOL := FALSE;
    prev_second    : DINT := 0;
    now_ms         : DINT;
    now_s          : DINT;
    coil_states    : ARRAY[0..7] OF BOOL;
    di_values      : ARRAY[0..7] OF BOOL;
    target_level   : BOOL;
END_VAR

(* ============================================================
   SECTION 1: MODBUS INITIALIZATION
   Create and connect the Modbus TCP client once.
   ============================================================ *)
IF NOT mb_init_done THEN
    MB_CLIENT_CREATE('washer', GVL.gw_ip, GVL.gw_port, 1);
    MB_CLIENT_CONNECT('washer');
    mb_init_done := TRUE;
END_IF;

GVL.mb_connected := MB_CLIENT_CONNECTED('washer');

(* Reconnect if we lose connection *)
IF mb_init_done AND NOT GVL.mb_connected THEN
    MB_CLIENT_CONNECT('washer');
END_IF;

(* ============================================================
   SECTION 2: READ INPUTS
   Read digital inputs and map to GVL booleans.
   ============================================================ *)
IF GVL.mb_connected THEN
    (* Read 8 discrete inputs from slave 1, starting at address 0 *)
    di_values := MB_READ_DISCRETE('washer', 0, 8);

    GVL.di_door_closed := di_values[0];
    GVL.di_door_locked := di_values[1];
    GVL.di_level_low   := di_values[2];
    GVL.di_level_med   := di_values[3];
    GVL.di_level_high  := di_values[4];
    GVL.di_motor_ol_ok := di_values[5];   (* N.C. — TRUE = healthy *)
    GVL.di_leak_detect := di_values[6];
END_IF;

(* ============================================================
   SECTION 3: TIMEKEEPING
   Increment state_timer once per second.
   ============================================================ *)
now_ms := NOW_MS();
now_s  := now_ms / 1000;
IF now_s <> prev_second THEN
    prev_second := now_s;
    GVL.state_timer := GVL.state_timer + 1;
    GVL.scan_counter := GVL.scan_counter + 1;
END_IF;

(* ============================================================
   SECTION 4: SAFETY INTERLOCKS
   These override everything — checked every scan.
   ============================================================ *)

(* Leak detection — immediate shutdown *)
IF GVL.di_leak_detect THEN
    GVL.fault_code := GVL.FLT_LEAK;
    GVL.fault_active := TRUE;
    GVL.wash_state := GVL.ST_FAULT;
END_IF;

(* Motor overload — stop motor immediately *)
IF NOT GVL.di_motor_ol_ok THEN
    GVL.cmd_motor_agit := FALSE;
    GVL.cmd_motor_spin := FALSE;
    GVL.fault_code := GVL.FLT_MOTOR_OL;
    GVL.fault_active := TRUE;
    GVL.wash_state := GVL.ST_FAULT;
END_IF;

(* Over-temperature — stop heating (close hot valve) *)
IF GVL.water_temp_c > 85.0 THEN
    GVL.cmd_hot_valve := FALSE;
    GVL.fault_code := GVL.FLT_TEMP_HIGH;
    GVL.fault_active := TRUE;
    GVL.wash_state := GVL.ST_FAULT;
END_IF;

(* Communication loss — if active cycle, go to fault *)
IF GVL.cycle_active AND NOT GVL.mb_connected THEN
    GVL.fault_code := GVL.FLT_COMM_LOSS;
    GVL.fault_active := TRUE;
    GVL.wash_state := GVL.ST_FAULT;
END_IF;

(* Stop button — drain and unlock *)
IF GVL.cmd_stop AND GVL.cycle_active THEN
    GVL.cmd_stop := FALSE;
    GVL.cmd_hot_valve := FALSE;
    GVL.cmd_cold_valve := FALSE;
    GVL.cmd_motor_agit := FALSE;
    GVL.cmd_motor_spin := FALSE;
    GVL.cmd_drain_pump := TRUE;
    GVL.wash_state := GVL.ST_DRAIN_FINAL;
    GVL.state_timer := 0;
END_IF;

(* ============================================================
   SECTION 5: CYCLE PARAMETER SELECTION
   Set wash/rinse/spin times based on cycle_select.
   ============================================================ *)
CASE GVL.cycle_select OF
    1: (* Normal *)
        GVL.wash_time_s := 600;
        GVL.rinse_time_s := 300;
        GVL.spin_time_s := 360;
        GVL.agitate_on_s := 10;
        GVL.agitate_off_s := 3;
    2: (* Heavy Duty *)
        GVL.wash_time_s := 900;
        GVL.rinse_time_s := 420;
        GVL.spin_time_s := 480;
        GVL.agitate_on_s := 12;
        GVL.agitate_off_s := 2;
    3: (* Delicate *)
        GVL.wash_time_s := 360;
        GVL.rinse_time_s := 240;
        GVL.spin_time_s := 180;
        GVL.agitate_on_s := 6;
        GVL.agitate_off_s := 5;
    4: (* Rinse Only *)
        GVL.wash_time_s := 0;
        GVL.rinse_time_s := 300;
        GVL.spin_time_s := 360;
        GVL.agitate_on_s := 8;
        GVL.agitate_off_s := 3;
END_CASE;

(* ============================================================
   SECTION 6: MAIN STATE MACHINE
   ============================================================ *)
CASE GVL.wash_state OF

    (* ---- IDLE: Waiting for start command ---- *)
    0: (* ST_IDLE *)
        GVL.cycle_active := FALSE;
        GVL.cmd_hot_valve := FALSE;
        GVL.cmd_cold_valve := FALSE;
        GVL.cmd_drain_pump := FALSE;
        GVL.cmd_door_lock := FALSE;
        GVL.cmd_motor_agit := FALSE;
        GVL.cmd_motor_spin := FALSE;
        GVL.cmd_buzzer := FALSE;

        IF GVL.cmd_start AND GVL.di_door_closed AND GVL.cycle_select > 0 THEN
            GVL.cmd_start := FALSE;
            GVL.fault_code := GVL.FLT_NONE;
            GVL.fault_active := FALSE;
            GVL.rinse_count := 0;
            GVL.cycle_active := TRUE;
            GVL.state_timer := 0;

            (* Rinse-only skips to fill_rinse *)
            IF GVL.cycle_select = 4 THEN
                GVL.wash_state := GVL.ST_DOOR_LOCK;
            ELSE
                GVL.wash_state := GVL.ST_DOOR_LOCK;
            END_IF;
        END_IF;

    (* ---- DOOR LOCK: Engage lock, verify feedback ---- *)
    1: (* ST_DOOR_LOCK *)
        GVL.cmd_door_lock := TRUE;

        IF GVL.di_door_locked THEN
            GVL.state_timer := 0;
            IF GVL.cycle_select = 4 THEN
                GVL.wash_state := GVL.ST_FILL_RINSE;
            ELSE
                GVL.wash_state := GVL.ST_FILL_WASH;
            END_IF;
        ELSIF GVL.state_timer > 5 THEN
            (* Lock didn't engage in 5 seconds *)
            GVL.fault_code := GVL.FLT_DOOR_LOCK;
            GVL.fault_active := TRUE;
            GVL.wash_state := GVL.ST_FAULT;
        END_IF;

    (* ---- FILL WASH: Open valve(s) until target level ---- *)
    2: (* ST_FILL_WASH *)
        (* Select valve based on temperature setting *)
        CASE GVL.water_temp_set OF
            0: (* Cold *)
                GVL.cmd_hot_valve := FALSE;
                GVL.cmd_cold_valve := TRUE;
            1: (* Warm — both valves *)
                GVL.cmd_hot_valve := TRUE;
                GVL.cmd_cold_valve := TRUE;
            2: (* Hot *)
                GVL.cmd_hot_valve := TRUE;
                GVL.cmd_cold_valve := FALSE;
        END_CASE;

        (* Check target level reached *)
        CASE GVL.water_level_set OF
            0: target_level := GVL.di_level_low;
            1: target_level := GVL.di_level_med;
            2: target_level := GVL.di_level_high;
        END_CASE;

        IF target_level THEN
            GVL.cmd_hot_valve := FALSE;
            GVL.cmd_cold_valve := FALSE;
            GVL.state_timer := 0;

            (* If hot or warm, wait for temperature *)
            IF GVL.water_temp_set > 0 THEN
                GVL.wash_state := GVL.ST_HEAT_WAIT;
            ELSE
                GVL.wash_state := GVL.ST_AGITATE;
            END_IF;
        ELSIF GVL.state_timer > 300 THEN
            (* 5 minute fill timeout *)
            GVL.cmd_hot_valve := FALSE;
            GVL.cmd_cold_valve := FALSE;
            GVL.fault_code := GVL.FLT_FILL_TIMEOUT;
            GVL.fault_active := TRUE;
            GVL.wash_state := GVL.ST_FAULT;
        END_IF;

    (* ---- HEAT WAIT: Let hot water stabilize (no heater element) ---- *)
    3: (* ST_HEAT_WAIT *)
        (* No electric heater — just using hot water supply.
           Wait 30 seconds for mixing, then proceed. *)
        IF GVL.state_timer > 30 THEN
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_AGITATE;
        END_IF;

    (* ---- AGITATE: Motor on/off strokes for wash time ---- *)
    4: (* ST_AGITATE *)
        GVL.agitate_timer := GVL.agitate_timer + 1;

        IF GVL.agitate_toggle THEN
            (* Motor ON phase *)
            GVL.cmd_motor_agit := TRUE;
            IF GVL.agitate_timer >= GVL.agitate_on_s THEN
                GVL.agitate_timer := 0;
                GVL.agitate_toggle := FALSE;
                GVL.cmd_motor_agit := FALSE;
            END_IF;
        ELSE
            (* Pause phase *)
            GVL.cmd_motor_agit := FALSE;
            IF GVL.agitate_timer >= GVL.agitate_off_s THEN
                GVL.agitate_timer := 0;
                GVL.agitate_toggle := TRUE;
            END_IF;
        END_IF;

        (* Check if wash time complete *)
        IF GVL.state_timer >= GVL.wash_time_s THEN
            GVL.cmd_motor_agit := FALSE;
            GVL.agitate_timer := 0;
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_DRAIN_1;
        END_IF;

    (* ---- DRAIN 1: Drain wash water ---- *)
    5: (* ST_DRAIN_1 *)
        GVL.cmd_drain_pump := TRUE;

        (* Drain until below low level, plus 30s extra *)
        IF NOT GVL.di_level_low AND GVL.state_timer > 30 THEN
            GVL.cmd_drain_pump := FALSE;
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_FILL_RINSE;
        ELSIF GVL.state_timer > 180 THEN
            (* 3 minute drain timeout — pump may be clogged but continue *)
            GVL.cmd_drain_pump := FALSE;
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_FILL_RINSE;
        END_IF;

    (* ---- FILL RINSE: Fill with cold water ---- *)
    6: (* ST_FILL_RINSE *)
        GVL.cmd_hot_valve := FALSE;
        GVL.cmd_cold_valve := TRUE;

        CASE GVL.water_level_set OF
            0: target_level := GVL.di_level_low;
            1: target_level := GVL.di_level_med;
            2: target_level := GVL.di_level_high;
        END_CASE;

        IF target_level THEN
            GVL.cmd_cold_valve := FALSE;
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_RINSE;
        ELSIF GVL.state_timer > 300 THEN
            GVL.cmd_cold_valve := FALSE;
            GVL.fault_code := GVL.FLT_FILL_TIMEOUT;
            GVL.fault_active := TRUE;
            GVL.wash_state := GVL.ST_FAULT;
        END_IF;

    (* ---- RINSE: Agitate in clean water ---- *)
    7: (* ST_RINSE *)
        GVL.agitate_timer := GVL.agitate_timer + 1;

        IF GVL.agitate_toggle THEN
            GVL.cmd_motor_agit := TRUE;
            IF GVL.agitate_timer >= GVL.agitate_on_s THEN
                GVL.agitate_timer := 0;
                GVL.agitate_toggle := FALSE;
                GVL.cmd_motor_agit := FALSE;
            END_IF;
        ELSE
            GVL.cmd_motor_agit := FALSE;
            IF GVL.agitate_timer >= GVL.agitate_off_s THEN
                GVL.agitate_timer := 0;
                GVL.agitate_toggle := TRUE;
            END_IF;
        END_IF;

        IF GVL.state_timer >= GVL.rinse_time_s THEN
            GVL.cmd_motor_agit := FALSE;
            GVL.agitate_timer := 0;
            GVL.state_timer := 0;
            GVL.rinse_count := GVL.rinse_count + 1;
            GVL.wash_state := GVL.ST_DRAIN_2;
        END_IF;

    (* ---- DRAIN 2: Drain rinse water ---- *)
    8: (* ST_DRAIN_2 *)
        GVL.cmd_drain_pump := TRUE;

        IF NOT GVL.di_level_low AND GVL.state_timer > 30 THEN
            GVL.cmd_drain_pump := FALSE;
            GVL.state_timer := 0;

            (* Extra rinse? Do another rinse pass *)
            IF GVL.extra_rinse AND GVL.rinse_count < 2 THEN
                GVL.wash_state := GVL.ST_FILL_RINSE;
            ELSE
                GVL.wash_state := GVL.ST_SPIN;
            END_IF;
        ELSIF GVL.state_timer > 180 THEN
            GVL.cmd_drain_pump := FALSE;
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_SPIN;
        END_IF;

    (* ---- SPIN: High-speed spin to extract water ---- *)
    9: (* ST_SPIN *)
        GVL.cmd_drain_pump := TRUE;   (* Keep draining during spin *)
        GVL.cmd_motor_spin := TRUE;

        (* Unbalance detection via vibration sensor *)
        IF GVL.vibration_g > 2.5 THEN
            (* Excessive vibration — stop spin, redistribute, retry *)
            GVL.cmd_motor_spin := FALSE;
            GVL.fault_code := GVL.FLT_UNBALANCE;
            GVL.fault_active := TRUE;
            GVL.wash_state := GVL.ST_FAULT;
        END_IF;

        IF GVL.state_timer >= GVL.spin_time_s THEN
            GVL.cmd_motor_spin := FALSE;
            GVL.cmd_drain_pump := FALSE;
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_DRAIN_FINAL;
        END_IF;

    (* ---- DRAIN FINAL: Final drain after spin ---- *)
    10: (* ST_DRAIN_FINAL *)
        GVL.cmd_motor_agit := FALSE;
        GVL.cmd_motor_spin := FALSE;
        GVL.cmd_drain_pump := TRUE;

        IF GVL.state_timer > 15 THEN
            GVL.cmd_drain_pump := FALSE;
            GVL.state_timer := 0;
            GVL.wash_state := GVL.ST_COMPLETE;
        END_IF;

    (* ---- COMPLETE: Unlock door, signal done ---- *)
    11: (* ST_COMPLETE *)
        GVL.cmd_door_lock := FALSE;
        GVL.cmd_buzzer := TRUE;
        GVL.total_cycles := GVL.total_cycles + 1;

        (* Buzzer for 10 seconds, then silence *)
        IF GVL.state_timer > 10 THEN
            GVL.cmd_buzzer := FALSE;
        END_IF;

        (* Wait for door to open, then return to idle *)
        IF NOT GVL.di_door_closed THEN
            GVL.cmd_buzzer := FALSE;
            GVL.cycle_active := FALSE;
            GVL.wash_state := GVL.ST_IDLE;
        END_IF;

    (* ---- FAULT: Safe state ---- *)
    99: (* ST_FAULT *)
        GVL.cmd_motor_agit := FALSE;
        GVL.cmd_motor_spin := FALSE;
        GVL.cmd_hot_valve := FALSE;
        GVL.cmd_cold_valve := FALSE;
        (* Keep drain pump ON in fault to empty tub *)
        GVL.cmd_drain_pump := TRUE;
        GVL.cmd_buzzer := TRUE;
        GVL.cycle_active := FALSE;

        (* After 60 seconds draining, unlock door *)
        IF GVL.state_timer > 60 THEN
            GVL.cmd_drain_pump := FALSE;
            GVL.cmd_door_lock := FALSE;
            GVL.cmd_buzzer := FALSE;
        END_IF;

        (* Reset fault from dashboard — returns to idle *)
        IF GVL.cmd_start AND NOT GVL.cycle_active THEN
            GVL.cmd_start := FALSE;
            GVL.fault_code := GVL.FLT_NONE;
            GVL.fault_active := FALSE;
            GVL.wash_state := GVL.ST_IDLE;
        END_IF;

END_CASE;

(* ============================================================
   SECTION 7: WRITE OUTPUTS
   Write all coil commands to the relay module every scan.
   ============================================================ *)
IF GVL.mb_connected THEN
    coil_states[0] := GVL.cmd_hot_valve;
    coil_states[1] := GVL.cmd_cold_valve;
    coil_states[2] := GVL.cmd_drain_pump;
    coil_states[3] := GVL.cmd_door_lock;
    coil_states[4] := GVL.cmd_motor_agit;
    coil_states[5] := GVL.cmd_motor_spin;
    coil_states[6] := GVL.cmd_buzzer;
    coil_states[7] := FALSE;  (* Spare *)

    MB_WRITE_COILS('washer', 0, coil_states);
END_IF;

END_PROGRAM
```

### POU_WashMonitor — Analog Scaling and Diagnostics

```iecst
PROGRAM POU_WashMonitor
VAR
    mb_init_done : BOOL := FALSE;
    raw_values   : ARRAY[0..7] OF INT;
    raw_ch1      : INT;
    raw_ch2      : INT;
    raw_ch3      : INT;
END_VAR

(* ============================================================
   Connect to analog input module (slave ID 2)
   Uses same gateway IP but different unit ID.
   ============================================================ *)
IF NOT mb_init_done THEN
    MB_CLIENT_CREATE('washer_ai', GVL.gw_ip, GVL.gw_port, 2);
    MB_CLIENT_CONNECT('washer_ai');
    mb_init_done := TRUE;
END_IF;

(* ============================================================
   Read 3 analog input channels (input registers, FC04)
   12-bit raw values: 0-4095
   ============================================================ *)
IF MB_CLIENT_CONNECTED('washer_ai') THEN
    raw_values := MB_READ_INPUT('washer_ai', 0, 3);
    raw_ch1 := raw_values[0];
    raw_ch2 := raw_values[1];
    raw_ch3 := raw_values[2];

    (* --- CH1: Water Temperature ---
       4-20mA → PT100 transmitter → 0 to 100 C
       Raw 0-4095 maps to 0-20mA, but 4mA = 0C, 20mA = 100C
       4mA  = 4095 * (4/20)  = 819
       20mA = 4095            = 4095
       Scale: temp = (raw - 819) * 100.0 / (4095 - 819)     *)
    IF raw_ch1 > 819 THEN
        GVL.water_temp_c := INT_TO_REAL(raw_ch1 - 819) * 100.0 / 3276.0;
    ELSE
        GVL.water_temp_c := 0.0;
    END_IF;

    (* --- CH2: Motor Current ---
       0-10V → CT signal conditioner → 0 to 15A
       Raw 0-4095 maps to 0-10V
       Scale: amps = raw * 15.0 / 4095                      *)
    GVL.motor_current_a := INT_TO_REAL(raw_ch2) * 15.0 / 4095.0;

    (* --- CH3: Vibration ---
       0-10V → accelerometer module → 0 to 5g
       Scale: g = raw * 5.0 / 4095                          *)
    GVL.vibration_g := INT_TO_REAL(raw_ch3) * 5.0 / 4095.0;
END_IF;

END_PROGRAM
```

---

## Node-RED Dashboard

GoPLC includes built-in Node-RED integration. The dashboard gives you phone control
of the washing machine from any browser on your network.

### Recommended Dashboard Layout

**Tab 1 — Control**
- Cycle selector dropdown (Normal / Heavy / Delicate / Rinse Only)
- Water temp selector (Cold / Warm / Hot)
- Water level selector (Low / Medium / High)
- Extra rinse toggle
- START button (green, writes `cmd_start = TRUE`)
- STOP button (red, writes `cmd_stop = TRUE`)

**Tab 2 — Status**
- Current state display (text: "Filling", "Washing", "Rinsing", "Spinning", etc.)
- State timer (minutes:seconds remaining)
- Progress bar (calculated from state position in cycle)
- Water temperature gauge
- Motor current gauge
- Door status indicator
- Water level indicators (3 LEDs: low/med/high)

**Tab 3 — Diagnostics**
- Fault code and description
- Total cycle count
- Motor current trend chart
- Water temperature trend chart
- Vibration trend chart
- Modbus connection status

### Node-RED Flow Outline

Use the GoPLC Node-RED nodes to read/write variables:

```
[goplc-read: wash_state]  → [function: state-to-text] → [ui_text: "Status"]
[goplc-read: water_temp_c] → [ui_gauge: "Water Temp"]
[goplc-read: motor_current_a] → [ui_chart: "Motor Current"]
[ui_dropdown: "Cycle"] → [goplc-write: cycle_select]
[ui_button: "START"] → [goplc-write: cmd_start = TRUE]
[ui_button: "STOP"]  → [goplc-write: cmd_stop = TRUE]
```

### State-to-Text Function

```javascript
var states = {
    0: "Idle — Ready",
    1: "Locking Door...",
    2: "Filling — Wash",
    3: "Heating Water...",
    4: "Washing",
    5: "Draining",
    6: "Filling — Rinse",
    7: "Rinsing",
    8: "Draining",
    9: "Spinning",
    10: "Final Drain",
    11: "Complete!",
    99: "FAULT"
};
msg.payload = states[msg.payload] || "Unknown (" + msg.payload + ")";
return msg;
```

---

## Testing and Commissioning

### Phase 1: Bench Test (No Loads Connected)

1. Power up the Pi, 24VDC PSU, and Waveshare modules
2. Open the GoPLC web IDE and load the project
3. Verify Modbus connection: check `mb_connected` = TRUE in variable monitor
4. Toggle DI inputs manually (jumper wire to simulate switches)
5. Verify `di_door_closed`, `di_level_low`, etc. respond correctly
6. Trigger a start command — watch state machine step through states
7. Verify relay LEDs on the Relay (D) module activate in the correct sequence
8. Use a multimeter on relay N.O. contacts to confirm switching

### Phase 2: Individual Load Test

Connect one load at a time and verify:
1. Door lock solenoid — engages and releases, feedback switch works
2. Cold water valve — opens when commanded, closes cleanly
3. Hot water valve — same
4. Drain pump — runs, no dry-run damage (fill tub first)
5. Motor agitate — runs at low speed, reverses per stroke pattern
6. Motor spin — runs at high speed
7. Buzzer — sounds on cycle complete

### Phase 3: Full Cycle Test

1. Run a Normal cycle with a small load of towels
2. Monitor the Node-RED dashboard on your phone
3. Watch water fill, agitate pattern, drain, rinse, spin sequence
4. Verify unbalance detection by deliberately unbalancing (optional)
5. Test the STOP button mid-cycle — should drain and unlock
6. Test door-open fault — open door switch mid-cycle (with lock disengaged for testing)

---

## Safety Considerations

| Hazard | Mitigation |
|--------|------------|
| Electric shock (120VAC) | All connections in enclosed panel, ground fault on house circuit |
| Water + electricity | IP54 enclosure, leak sensor on DI7, fault drains and de-energizes |
| Door opening during spin | Door lock solenoid + feedback, software interlock |
| Motor overload/fire | Thermal overload relay on motor, wired to DI6 |
| Uncontrolled fill (flood) | 5-minute fill timeout, high-level switch as hard limit |
| Software crash | GoPLC watchdog restarts task; fault state is fail-safe (drain + unlock) |
| Power loss | All valves are normally closed (spring return), door lock releases |

**Fail-safe design principle:** On loss of power or controller fault, all valves close
(spring return), the drain pump stops, and the door lock releases. Water cannot flow
without active relay output. The motor cannot run without active contactor coils.

---

## Fault Reference

| Code | Name | Cause | Recovery |
|------|------|-------|----------|
| 1 | DOOR_OPEN | Door switch opened during cycle | Close door, press START to reset |
| 2 | DOOR_LOCK | Lock solenoid didn't engage within 5s | Check solenoid wiring, press START |
| 3 | FILL_TIMEOUT | Water level not reached in 5 minutes | Check water supply valves, press START |
| 4 | MOTOR_OL | Motor thermal overload tripped | Let motor cool, reset OL relay, press START |
| 5 | LEAK | Water leak sensor activated | Find and fix leak, press START |
| 6 | UNBALANCE | Excessive vibration during spin | Redistribute load, press START |
| 7 | TEMP_HIGH | Water temperature exceeded 85C | Check hot water supply, press START |
| 8 | COMM_LOSS | Modbus connection to gateway lost | Check Ethernet/gateway, auto-reconnects |

---

## Parts Sources

- [Waveshare Modbus RTU Relay (D)](https://www.waveshare.com/modbus-rtu-relay-d.htm) — 8 relay + 8 DI
- [Waveshare Modbus RTU Analog Input 8CH](https://www.waveshare.com/modbus-rtu-analog-input-8ch.htm) — 12-bit analog
- [Waveshare RS485 TO ETH (B)](https://www.waveshare.com/rs485-to-eth-b.htm) — Modbus TCP/RTU gateway
- [Waveshare RS485 CAN HAT](https://www.waveshare.com/rs485-can-hat.htm) — Alternative: direct RS485 from Pi (use MB_RTU_* functions instead)

---

## Expanding the Project

- **Energy monitoring** — Add a CT on the mains feed to the washer, track kWh per cycle
- **Water usage** — Add a flow meter on the cold water inlet, track gallons per cycle
- **Predictive maintenance** — Trend motor current over cycles; rising current = worn bearings
- **Home automation** — MQTT integration to Home Assistant, trigger notifications
- **Custom cycles** — Add more cycle types (sanitize, quick wash, soak) as new state paths
- **Multi-appliance** — Add a second Relay (D) module on the RS485 bus for a dryer controller
