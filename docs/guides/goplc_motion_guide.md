# GoPLC Motion Control Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC implements the **PLCopen Motion Control** function block model — the same standard used by CODESYS, Beckhoff TwinCAT, and Bosch Rexroth IndraWorks. Create axes, enable power, home, and execute absolute/relative/velocity moves with trapezoidal motion profiles, all from Structured Text.

Axes are software-simulated by default with callback hooks for connecting to real hardware (stepper drivers, servo amplifiers, VFDs, or any actuator reachable via GPIO, serial, or protocol).

### PLCopen State Machine

Every axis follows the standard PLCopen state diagram:

```
                    ┌──────────────┐
                    │   Disabled   │◄── MC_POWER(FALSE)
                    └──────┬───────┘
                           │ MC_POWER(TRUE)
                           ▼
                    ┌──────────────┐
           ┌───────│  Standstill  │◄──────────────┐
           │       └──────┬───────┘               │
           │              │                       │
    MC_HOME│    MC_MOVE_* │              Move done │
           │              │                       │
           ▼              ▼                       │
    ┌──────────┐  ┌────────────────┐      ┌───────────┐
    │  Homing  │  │ DiscreteMotion │─────►│ Standstill│
    └──────────┘  └────────────────┘      └───────────┘
                          │
               MC_MOVE_VELOCITY
                          │
                          ▼
                  ┌────────────────────┐
                  │ ContinuousMotion   │── MC_STOP ──► Stopping ──► Standstill
                  └────────────────────┘
                          │
                      MC_HALT
                          │
                          ▼
                    ┌──────────┐
                    │ ErrorStop│── MC_RESET ──► Standstill
                    └──────────┘
```

| State | Code | Description |
|-------|------|-------------|
| Disabled | 0 | Power off — no motion possible |
| Standstill | 1 | Powered, idle, ready for commands |
| Homing | 2 | Homing sequence active |
| DiscreteMotion | 3 | Point-to-point move in progress |
| ContinuousMotion | 4 | Velocity/jog mode active |
| SynchronizedMotion | 5 | Reserved (not yet implemented) |
| Stopping | 6 | Controlled deceleration to stop |
| ErrorStop | 7 | Fault — requires MC_RESET |

---

## 2. Axis Lifecycle

### Create and Configure

```iecst
PROGRAM POU_Motion
VAR
    axis : INT;
    ok : BOOL;
    state : INT := 0;
END_VAR

CASE state OF
    0: (* Create axis *)
        axis := MC_CREATE_AXIS('X');

        (* Configure motion parameters *)
        MC_CONFIG(axis, 'max_velocity', 1000.0);      (* units/sec *)
        MC_CONFIG(axis, 'max_accel', 5000.0);          (* units/sec² *)
        MC_CONFIG(axis, 'max_decel', 5000.0);          (* units/sec² *)
        MC_CONFIG(axis, 'max_jerk', 50000.0);           (* units/sec³ *)
        MC_CONFIG(axis, 'units_per_rev', 1000.0);       (* encoder scaling *)
        state := 1;

    1: (* Enable power *)
        ok := MC_POWER(axis, TRUE);
        IF MC_IS_ENABLED(axis) THEN
            state := 2;
        END_IF;

    2: (* Home the axis *)
        ok := MC_HOME(axis);
        state := 3;

    3: (* Wait for homing complete *)
        MC_UPDATE(axis);
        IF MC_IS_HOMED(axis) THEN
            state := 10;
        END_IF;

    10: (* Ready for motion commands *)
        MC_UPDATE(axis);
END_CASE;
END_PROGRAM
```

### Configuration Parameters

| Parameter | Default | Units | Description |
|-----------|---------|-------|-------------|
| `max_velocity` | 1000.0 | units/sec | Maximum travel speed |
| `max_accel` | 5000.0 | units/sec² | Maximum acceleration |
| `max_decel` | 5000.0 | units/sec² | Maximum deceleration |
| `max_jerk` | 50000.0 | units/sec³ | Jerk limit (for S-curve profiles) |
| `units_per_rev` | 1000.0 | units/rev | Encoder/resolver scaling |

---

## 3. Motion Commands

All motion commands are **non-blocking** — they initiate the move and return immediately. Call `MC_UPDATE` every scan cycle to advance the trajectory. Check `MC_IS_MOVING` and `MC_MOVE_DONE` for status.

### MC_MOVE_ABSOLUTE — Move to Position

```iecst
(* Move to position 5000 at 500 units/sec *)
ok := MC_MOVE_ABSOLUTE(axis, 5000.0, 500.0);

(* With custom accel/decel *)
ok := MC_MOVE_ABSOLUTE(axis, 5000.0, 500.0, 2000.0, 2000.0);
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `axis_id` | INT | Yes | Axis identifier |
| `position` | REAL | Yes | Target position (absolute) |
| `velocity` | REAL | No | Travel speed (default: max_velocity) |
| `accel` | REAL | No | Acceleration (default: max_accel) |
| `decel` | REAL | No | Deceleration (default: max_decel) |

### MC_MOVE_RELATIVE — Move by Distance

```iecst
(* Move 1000 units forward *)
ok := MC_MOVE_RELATIVE(axis, 1000.0, 500.0);

(* Move 500 units backward *)
ok := MC_MOVE_RELATIVE(axis, -500.0, 200.0);
```

Same parameters as MC_MOVE_ABSOLUTE, but `distance` instead of `position`.

### MC_MOVE_VELOCITY — Continuous Motion (Jog)

Alias: `MC_JOG`

```iecst
(* Jog forward at 100 units/sec *)
ok := MC_MOVE_VELOCITY(axis, 100.0);

(* Jog reverse *)
ok := MC_MOVE_VELOCITY(axis, -50.0);

(* Jog with custom acceleration *)
ok := MC_MOVE_VELOCITY(axis, 200.0, 1000.0);
```

Runs continuously until `MC_STOP` or `MC_HALT`. Enters ContinuousMotion state.

### MC_STOP — Controlled Stop

```iecst
(* Stop with default deceleration *)
ok := MC_STOP(axis);

(* Stop with custom deceleration *)
ok := MC_STOP(axis, 10000.0);
```

### MC_HALT — Emergency Stop

```iecst
ok := MC_HALT(axis);
```

Stops with 2x the configured max_decel. Enters ErrorStop state — requires `MC_RESET` before new commands.

---

## 4. Cyclic Update

**MC_UPDATE must be called every scan cycle** for each active axis. It advances the trajectory simulation, updates position and velocity, and handles state transitions.

```iecst
(* In your scan loop — REQUIRED *)
MC_UPDATE(axis);

(* With explicit time step (default: 1ms) *)
MC_UPDATE(axis, 0.001);     (* dt in seconds *)
```

If you forget to call MC_UPDATE, the axis position will never change.

---

## 5. Status and Monitoring

### Position and Velocity

```iecst
pos := MC_READ_POSITION(axis);     (* Current position *)
vel := MC_READ_VELOCITY(axis);     (* Current velocity *)
```

### Motion Status

```iecst
IF MC_IS_MOVING(axis) THEN
    (* Motion in progress *)
END_IF;

IF MC_MOVE_DONE(axis) THEN
    (* Move completed — start next move *)
END_IF;

IF MC_IS_ENABLED(axis) THEN ... END_IF;
IF MC_IS_HOMED(axis) THEN ... END_IF;
```

### Full Status

```iecst
status := MC_READ_STATUS(axis);
(* Returns map:
   state           — PLCopen state code (0-7)
   enabled         — Power enabled
   homed           — Homing complete
   error           — Error active
   actual_position — Current position
   actual_velocity — Current velocity
   target_position — Commanded position
   move_active     — Motion in progress
   move_complete   — Move finished
*)
```

### State Code

```iecst
state_code := MC_GET_STATE(axis);
(* 0=Disabled, 1=Standstill, 2=Homing, 3=DiscreteMotion,
   4=ContinuousMotion, 5=Synchronized, 6=Stopping, 7=ErrorStop *)
```

### Error Handling

```iecst
err := MC_READ_ERROR(axis);
(* Returns: {error: bool, error_id: int, error_msg: string} *)

IF MC_GET_STATE(axis) = 7 THEN     (* ErrorStop *)
    MC_RESET(axis);                  (* Clear error → Standstill *)
END_IF;
```

### Set Position (Homing Override)

```iecst
MC_SET_POSITION(axis, 0.0);        (* Zero the axis at current physical location *)
```

### List All Axes

```iecst
axes := MC_LIST_AXES();
(* Returns array of axis IDs *)
```

---

## 6. Motion Profile

Currently supports **trapezoidal** profiles:

```
Velocity
  ^
  |        ┌────────────────┐
  |       /│                │\
  |      / │  Constant Vel  │ \
  |     /  │                │  \
  |    /   │                │   \
  |   /    │                │    \
  +--/-----+----------------+-----\----> Time
     Accel                    Decel
```

The profile ensures:
- Acceleration phase ramps up to commanded velocity
- Constant velocity phase (if distance allows)
- Deceleration phase ramps down to zero at target
- Short moves may be triangular (no constant velocity phase)

---

## 7. Complete Example: Pick and Place

A 3-axis pick-and-place machine:

```iecst
PROGRAM POU_PickAndPlace
VAR
    x_axis : INT;
    y_axis : INT;
    z_axis : INT;
    state : INT := 0;
    ok : BOOL;

    (* Positions *)
    pick_x : REAL := 1000.0;
    pick_y : REAL := 500.0;
    pick_z : REAL := 100.0;
    place_x : REAL := 3000.0;
    place_y : REAL := 1500.0;
    place_z : REAL := 100.0;
    safe_z : REAL := 500.0;

    gripper : BOOL := FALSE;
END_VAR

CASE state OF
    0: (* Initialize axes *)
        x_axis := MC_CREATE_AXIS('X');
        y_axis := MC_CREATE_AXIS('Y');
        z_axis := MC_CREATE_AXIS('Z');

        MC_CONFIG(x_axis, 'max_velocity', 2000.0);
        MC_CONFIG(y_axis, 'max_velocity', 2000.0);
        MC_CONFIG(z_axis, 'max_velocity', 500.0);

        MC_POWER(x_axis, TRUE);
        MC_POWER(y_axis, TRUE);
        MC_POWER(z_axis, TRUE);
        state := 1;

    1: (* Home all axes *)
        MC_HOME(x_axis);
        MC_HOME(y_axis);
        MC_HOME(z_axis);
        state := 2;

    2: (* Wait for all homed *)
        IF MC_IS_HOMED(x_axis) AND MC_IS_HOMED(y_axis) AND MC_IS_HOMED(z_axis) THEN
            state := 10;
        END_IF;

    10: (* Move Z to safe height *)
        MC_MOVE_ABSOLUTE(z_axis, safe_z, 500.0);
        state := 11;

    11: IF MC_MOVE_DONE(z_axis) THEN
            (* Move XY to pick position *)
            MC_MOVE_ABSOLUTE(x_axis, pick_x, 2000.0);
            MC_MOVE_ABSOLUTE(y_axis, pick_y, 2000.0);
            state := 12;
        END_IF;

    12: IF MC_MOVE_DONE(x_axis) AND MC_MOVE_DONE(y_axis) THEN
            (* Lower Z to pick *)
            MC_MOVE_ABSOLUTE(z_axis, pick_z, 200.0);
            state := 13;
        END_IF;

    13: IF MC_MOVE_DONE(z_axis) THEN
            gripper := TRUE;           (* Close gripper *)
            state := 14;
        END_IF;

    14: (* Raise Z *)
        MC_MOVE_ABSOLUTE(z_axis, safe_z, 500.0);
        state := 15;

    15: IF MC_MOVE_DONE(z_axis) THEN
            (* Move XY to place position *)
            MC_MOVE_ABSOLUTE(x_axis, place_x, 2000.0);
            MC_MOVE_ABSOLUTE(y_axis, place_y, 2000.0);
            state := 16;
        END_IF;

    16: IF MC_MOVE_DONE(x_axis) AND MC_MOVE_DONE(y_axis) THEN
            (* Lower Z to place *)
            MC_MOVE_ABSOLUTE(z_axis, place_z, 200.0);
            state := 17;
        END_IF;

    17: IF MC_MOVE_DONE(z_axis) THEN
            gripper := FALSE;          (* Open gripper *)
            state := 18;
        END_IF;

    18: (* Raise Z and cycle back *)
        MC_MOVE_ABSOLUTE(z_axis, safe_z, 500.0);
        state := 19;

    19: IF MC_MOVE_DONE(z_axis) THEN
            state := 10;               (* Repeat cycle *)
        END_IF;
END_CASE;

(* REQUIRED: Update all axes every scan *)
MC_UPDATE(x_axis);
MC_UPDATE(y_axis);
MC_UPDATE(z_axis);

END_PROGRAM
```

---

## 8. Complete Example: Jog Panel

Manual jogging from HMI buttons:

```iecst
PROGRAM POU_JogPanel
VAR
    axis : INT;
    initialized : BOOL := FALSE;

    (* HMI inputs *)
    jog_fwd : BOOL;
    jog_rev : BOOL;
    jog_speed : REAL := 100.0;
    move_to_pos : REAL;
    go_cmd : BOOL;
    home_cmd : BOOL;
    stop_cmd : BOOL;

    (* HMI outputs *)
    current_pos : REAL;
    current_vel : REAL;
    is_moving : BOOL;
    is_homed : BOOL;
    axis_state : INT;
END_VAR

IF NOT initialized THEN
    axis := MC_CREATE_AXIS('manual');
    MC_CONFIG(axis, 'max_velocity', 500.0);
    MC_POWER(axis, TRUE);
    initialized := TRUE;
END_IF;

(* Jog control *)
IF jog_fwd AND NOT jog_rev THEN
    MC_MOVE_VELOCITY(axis, jog_speed);
ELSIF jog_rev AND NOT jog_fwd THEN
    MC_MOVE_VELOCITY(axis, -jog_speed);
ELSIF MC_GET_STATE(axis) = 4 THEN      (* ContinuousMotion *)
    MC_STOP(axis);
END_IF;

(* Point-to-point move *)
IF go_cmd THEN
    MC_MOVE_ABSOLUTE(axis, move_to_pos, jog_speed);
    go_cmd := FALSE;
END_IF;

(* Home *)
IF home_cmd THEN
    MC_HOME(axis);
    home_cmd := FALSE;
END_IF;

(* Emergency stop *)
IF stop_cmd THEN
    MC_HALT(axis);
    stop_cmd := FALSE;
END_IF;

(* Error recovery *)
IF MC_GET_STATE(axis) = 7 THEN
    MC_RESET(axis);
END_IF;

(* Update trajectory *)
MC_UPDATE(axis);

(* Feedback to HMI *)
current_pos := MC_READ_POSITION(axis);
current_vel := MC_READ_VELOCITY(axis);
is_moving := MC_IS_MOVING(axis);
is_homed := MC_IS_HOMED(axis);
axis_state := MC_GET_STATE(axis);

END_PROGRAM
```

---

## 9. Hardware Integration

By default, axes are software-simulated — position and velocity are calculated mathematically. To connect to real hardware, register callback hooks:

| Callback | Triggered By | Use |
|----------|-------------|-----|
| `OnPowerChange` | MC_POWER | Enable/disable servo drive |
| `OnMove` | MC_MOVE_* | Send position/velocity commands to drive |
| `OnHome` | MC_HOME | Trigger drive homing sequence |
| `OnStop` | MC_STOP/HALT | Send stop command to drive |

Hardware integration examples:
- **Stepper/Dir via P2**: MC_MOVE triggers P2_CMD with step pulses
- **Modbus VFD**: MC_MOVE_VELOCITY writes speed register via MB_WRITE_REGISTER
- **EtherNet/IP servo**: MC_MOVE sends tag writes via ENIP_SCANNER_WRITE_REAL
- **G-code machine**: MC_MOVE generates G1 commands via GCODE_SEND_CMD

The software axis handles trajectory planning (acceleration profiles, position tracking) — the callback just sends the output to hardware.

---

## Appendix A: Quick Reference

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `MC_CREATE_AXIS(name)` | 1 | INT | Create axis, returns ID |
| `MC_CONFIG(id, param, value)` | 3 | BOOL | Set axis parameter |
| `MC_POWER(id, enable)` | 2 | BOOL | Enable/disable power |
| `MC_HOME(id)` | 1 | BOOL | Start homing |
| `MC_RESET(id)` | 1 | BOOL | Clear error state |
| `MC_MOVE_ABSOLUTE(id, pos [,vel,acc,dec])` | 2-5 | BOOL | Move to position |
| `MC_MOVE_RELATIVE(id, dist [,vel,acc,dec])` | 2-5 | BOOL | Move by distance |
| `MC_MOVE_VELOCITY(id, vel [,acc,dec])` | 2-4 | BOOL | Continuous velocity/jog |
| `MC_JOG(id, vel [,acc,dec])` | 2-4 | BOOL | Alias for MOVE_VELOCITY |
| `MC_STOP(id [,decel])` | 1-2 | BOOL | Controlled stop |
| `MC_HALT(id)` | 1 | BOOL | Emergency stop (2x decel) |
| `MC_UPDATE(id [,dt])` | 1-2 | BOOL | **Cyclic** — advance trajectory |
| `MC_READ_POSITION(id)` | 1 | REAL | Current position |
| `MC_READ_VELOCITY(id)` | 1 | REAL | Current velocity |
| `MC_READ_STATUS(id)` | 1 | MAP | Full axis status |
| `MC_READ_ERROR(id)` | 1 | MAP | Error info |
| `MC_GET_STATE(id)` | 1 | INT | PLCopen state code (0-7) |
| `MC_IS_ENABLED(id)` | 1 | BOOL | Power on? |
| `MC_IS_HOMED(id)` | 1 | BOOL | Homing done? |
| `MC_IS_MOVING(id)` | 1 | BOOL | Motion active? |
| `MC_MOVE_DONE(id)` | 1 | BOOL | Move complete? |
| `MC_SET_POSITION(id, pos)` | 2 | BOOL | Override position |
| `MC_LIST_AXES()` | 0 | ARRAY | All axis IDs |

---

*GoPLC v1.0.535 | PLCopen Motion Control | 23 Functions | Trapezoidal Profiles*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
