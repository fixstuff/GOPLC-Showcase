# GoPLC Timers, Counters & Function Blocks Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC implements 14 IEC 61131-3 standard function blocks. Unlike plain functions, function blocks retain state between scan cycles — a timer remembers how long it has been running, a counter remembers its count, a PID controller remembers its integral term.

| Category | Function Blocks | Description |
|----------|----------------|-------------|
| **Timers** | TON, TOF, TP, RTO | Time-based delays, pulses, and accumulation |
| **Counters** | CTU, CTD, CTUD | Event counting (up, down, bidirectional) |
| **Bistables** | SR, RS | Set/reset latches with priority control |
| **Edge Triggers** | R_TRIG, F_TRIG | Rising and falling edge detection |
| **PID Controllers** | PID, PIDE | Proportional-Integral-Derivative feedback control |

### How Function Blocks Work in ST

Function blocks are declared as variables, then called with named parameters:

```iecst
PROGRAM POU_Example
VAR
    myTimer : TON;              (* Declare instance *)
    startButton : BOOL;
    output : BOOL;
END_VAR

myTimer(IN := startButton, PT := T#5s);   (* Call with inputs *)
output := myTimer.Q;                       (* Read outputs *)
END_PROGRAM
```

Each instance maintains its own state. You can have multiple instances of the same type:

```iecst
VAR
    pumpDelay : TON;
    fanDelay : TON;
    alarmDelay : TON;
END_VAR
```

---

## 2. Timers

### 2.1 TON — Timer On-Delay

Output Q goes TRUE after IN has been TRUE continuously for PT duration. If IN goes FALSE before PT expires, the timer resets.

```iecst
VAR
    startDelay : TON;
END_VAR

startDelay(IN := startButton, PT := T#3s);

IF startDelay.Q THEN
    (* Button held for 3 seconds — start motor *)
    motor := TRUE;
END_IF;
```

**Inputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `IN` | BOOL | Enable input — timer runs while TRUE |
| `PT` | TIME | Preset time (e.g., `T#3s`, `T#500ms`, `T#1h30m`) |
| `R` | BOOL | Reset — clears elapsed time and output |

**Outputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `Q` | BOOL | Output — TRUE when elapsed >= PT |
| `ET` | TIME | Elapsed time (capped at PT) |
| `DN` | BOOL | Done — TRUE when timing complete |
| `TT` | BOOL | Timer Timing — TRUE while actively counting |
| `EN` | BOOL | Enabled — mirrors IN |

**Timing Diagram:**

```
IN:  ──┐     ┌──────────────────────┐     ┌───
       └─────┘                      └─────┘
PT:  ========  (3 seconds)

Q:   ─────────────────┐             ┌─────────
                      └─────────────┘
       <--- 3s --->
       IN went FALSE    Q stays FALSE
       before PT,       until IN has been
       timer reset      TRUE for full PT
```

---

### 2.2 TOF — Timer Off-Delay

Output Q goes TRUE immediately when IN goes TRUE. When IN goes FALSE, Q stays TRUE for PT duration before going FALSE.

```iecst
VAR
    coolDown : TOF;
END_VAR

coolDown(IN := runCommand, PT := T#10s);

(* Fan keeps running 10 seconds after run command stops *)
fan := coolDown.Q;
```

**Inputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `IN` | BOOL | Enable input |
| `PT` | TIME | Off-delay duration |
| `R` | BOOL | Reset |

**Outputs:** Same as TON (Q, ET, DN, TT, EN).

**Timing Diagram:**

```
IN:  ──┐     ┌────────────┐     ┌───
       └─────┘            └─────┘

Q:   ──┐     ┌────────────┐           ┌───
       └─────┘            └───────────┘
                           <-- 10s -->
                           Q holds TRUE
                           after IN falls
```

---

### 2.3 TP — Timer Pulse

Generates a fixed-width pulse on the rising edge of IN. Not retriggerable — if IN pulses again during an active pulse, it is ignored.

```iecst
VAR
    oneShot : TP;
END_VAR

oneShot(IN := trigger, PT := T#200ms);

(* 200ms pulse on every rising edge of trigger *)
solenoid := oneShot.Q;
```

**Inputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `IN` | BOOL | Trigger input (rising edge starts pulse) |
| `PT` | TIME | Pulse width |

**Outputs:** Same as TON (Q, ET, DN, TT, EN).

**Timing Diagram:**

```
IN:  ──┐ ┌──┐     ┌──┐
       └─┘  └─────┘  └───
              ^ignored (pulse active)

Q:   ──┐                ┌──────────┐
       └────────────────┘          └───
       <---- 200ms ---->  <-200ms->
```

---

### 2.4 RTO — Retentive Timer On-Delay

Accumulates time while IN is TRUE. Unlike TON, it does **not** reset when IN goes FALSE — accumulated time is retained. Only an explicit R (reset) input clears the timer.

```iecst
VAR
    runHours : RTO;
    totalRuntime : TIME;
END_VAR

runHours(IN := motorRunning, PT := T#8h, R := resetBtn);

totalRuntime := runHours.ET;

IF runHours.Q THEN
    (* Motor has accumulated 8 hours of runtime — schedule maintenance *)
    maintenanceDue := TRUE;
END_IF;
```

**Inputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `IN` | BOOL | Enable — accumulates time while TRUE |
| `PT` | TIME | Preset time (total accumulation target) |
| `R` | BOOL | Reset — clears accumulated time and output |

**Outputs:** Same as TON (Q, ET, DN, TT, EN).

**Timing Diagram:**

```
IN:  ──┐     ┌──┐     ┌──────────────
       └─────┘  └─────┘

ET:  0  2s  2s  4s  4s  6s  8s...
         ^retained  ^retained
         when IN    when IN
         goes FALSE goes FALSE

Q:   ──────────────────────────┐
                               └── (Q stays TRUE until R)
                          ET >= PT
```

---

## 3. Counters

### 3.1 CTU — Count Up

Increments CV on each rising edge of CU. Q becomes TRUE when CV reaches PV.

```iecst
VAR
    partCount : CTU;
END_VAR

partCount(CU := proxSensor, PV := 100, R := resetBtn);

IF partCount.Q THEN
    (* 100 parts counted — signal batch complete *)
    batchDone := TRUE;
END_IF;

currentCount := partCount.CV;
```

**Inputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `CU` | BOOL | Count Up — rising edge increments CV |
| `PV` | INT | Preset value (target count) |
| `R` | BOOL | Reset — sets CV to 0 |
| `LD` | BOOL | Load — loads PV into CV |

**Outputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `Q` | BOOL | Output — TRUE when CV >= PV |
| `CV` | INT | Current count value |

---

### 3.2 CTD — Count Down

Decrements CV on each rising edge of CD. Q becomes TRUE when CV reaches 0.

```iecst
VAR
    remaining : CTD;
END_VAR

remaining(CD := dispenseSensor, PV := 50, LD := loadBtn);

IF remaining.Q THEN
    (* All items dispensed *)
    hopperEmpty := TRUE;
END_IF;

itemsLeft := remaining.CV;
```

**Inputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `CD` | BOOL | Count Down — rising edge decrements CV |
| `PV` | INT | Preset value (loaded by LD) |
| `R` | BOOL | Reset — sets CV to 0 |
| `LD` | BOOL | Load — loads PV into CV |

**Outputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `Q` | BOOL | Output — TRUE when CV <= 0 |
| `CV` | INT | Current count value |

---

### 3.3 CTUD — Count Up/Down

Bidirectional counter with separate up and down inputs.

```iecst
VAR
    position : CTUD;
END_VAR

position(CU := forwardPulse, CD := reversePulse, PV := 1000, R := homeBtn);

atUpperLimit := position.QU;    (* CV >= 1000 *)
atLowerLimit := position.QD;    (* CV <= 0 *)
currentPos := position.CV;
```

**Inputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `CU` | BOOL | Count Up — rising edge increments CV |
| `CD` | BOOL | Count Down — rising edge decrements CV |
| `PV` | INT | Preset value (upper threshold) |
| `R` | BOOL | Reset — sets CV to 0 |
| `LD` | BOOL | Load — loads PV into CV |

**Outputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `QU` | BOOL | Upper limit — TRUE when CV >= PV |
| `QD` | BOOL | Lower limit — TRUE when CV <= 0 |
| `CV` | INT | Current count value |

---

## 4. Bistables (Latches)

### 4.1 SR — Set-Reset (Set Dominant)

When both S1 and R are TRUE, **Set wins** — Q1 stays TRUE.

```iecst
VAR
    latch : SR;
END_VAR

latch(S1 := startBtn, R := stopBtn);
motorEnabled := latch.Q1;
```

| Input | Type | Description |
|-------|------|-------------|
| `S1` | BOOL | Set (dominant) |
| `R` | BOOL | Reset |

| Output | Type | Description |
|--------|------|-------------|
| `Q1` | BOOL | Latched output (retained) |

Logic: `Q1 := S1 OR (NOT R AND Q1)`

---

### 4.2 RS — Reset-Set (Reset Dominant)

When both S and R1 are TRUE, **Reset wins** — Q1 goes FALSE. Safer for emergency stop circuits.

```iecst
VAR
    safeLatch : RS;
END_VAR

safeLatch(S := runPermit, R1 := eStop);
motorAllowed := safeLatch.Q1;
```

| Input | Type | Description |
|-------|------|-------------|
| `S` | BOOL | Set |
| `R1` | BOOL | Reset (dominant) |

| Output | Type | Description |
|--------|------|-------------|
| `Q1` | BOOL | Latched output (retained) |

Logic: `Q1 := NOT R1 AND (S OR Q1)`

> **Safety:** Use RS (reset-dominant) for safety-critical latches. An E-stop should always be able to override a run command, even if both signals are active simultaneously.

---

## 5. Edge Triggers

### 5.1 R_TRIG — Rising Edge Detector

Output Q is TRUE for exactly one scan when CLK transitions from FALSE to TRUE.

```iecst
VAR
    riseDetect : R_TRIG;
END_VAR

riseDetect(CLK := inputSignal);

IF riseDetect.Q THEN
    (* Rising edge detected — execute once *)
    batchCount := batchCount + 1;
END_IF;
```

| Input | Type | Description |
|-------|------|-------------|
| `CLK` | BOOL | Signal to monitor |

| Output | Type | Description |
|--------|------|-------------|
| `Q` | BOOL | TRUE for one scan on rising edge |

---

### 5.2 F_TRIG — Falling Edge Detector

Output Q is TRUE for exactly one scan when CLK transitions from TRUE to FALSE.

```iecst
VAR
    fallDetect : F_TRIG;
END_VAR

fallDetect(CLK := inputSignal);

IF fallDetect.Q THEN
    (* Falling edge detected — signal just went off *)
    offCount := offCount + 1;
END_IF;
```

| Input | Type | Description |
|-------|------|-------------|
| `CLK` | BOOL | Signal to monitor |

| Output | Type | Description |
|--------|------|-------------|
| `Q` | BOOL | TRUE for one scan on falling edge |

---

## 6. PID Controllers

### 6.1 PID — Standard PID Controller

Proportional-Integral-Derivative feedback controller with anti-windup.

```iecst
VAR
    tempPID : PID;
    heaterOutput : REAL;
END_VAR

tempPID(
    EN := TRUE,
    PV := actualTemp,          (* Measured temperature *)
    SP := setpointTemp,        (* Desired temperature *)
    KP := 10.0,                (* Proportional gain *)
    KI := 0.5,                 (* Integral gain *)
    KD := 2.0,                 (* Derivative gain *)
    CYCLE := 0.1,              (* Scan time in seconds *)
    MN := 0.0,                 (* Min output *)
    MX := 100.0                (* Max output *)
);

heaterOutput := tempPID.CV;
```

**Inputs:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `EN` | BOOL | TRUE | Enable |
| `PV` | REAL | required | Process variable (measurement) |
| `SP` | REAL | required | Setpoint (target) |
| `KP` | REAL | 1.0 | Proportional gain |
| `KI` | REAL | 0.0 | Integral gain |
| `KD` | REAL | 0.0 | Derivative gain |
| `CYCLE` | REAL | 0.1 | Scan time in seconds |
| `MN` | REAL | 0.0 | Minimum output |
| `MX` | REAL | 100.0 | Maximum output |
| `MR` | BOOL | FALSE | Manual reset (clears integral) |

**Outputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `CV` | REAL | Control variable (calculated output) |
| `E` | REAL | Error (SP - PV) |

**Algorithm:**

```
Error = SP - PV
P = KP * Error
I = KI * accumulated_integral
D = KD * (Error - prevError) / CYCLE
CV = CLAMP(P + I + D, MN, MX)
```

Anti-windup prevents the integral term from growing when the output is saturated at MN or MX.

---

### 6.2 PIDE — Enhanced PID (Rockwell-Style)

Extended PID with feed-forward, output bias, manual mode, setpoint limits, and alarm thresholds.

```iecst
VAR
    reactorPID : PIDE;
END_VAR

reactorPID(
    EN := TRUE,
    PV := reactorTemp,
    SP := 180.0,
    KP := 5.0,
    KI := 0.2,
    KD := 1.0,
    CYCLE := 0.1,
    FF := steamFlow * 0.5,    (* Feed-forward from steam *)
    BIAS := 10.0,              (* Output offset *)
    MAXO := 100.0,             (* Max output *)
    MINO := 0.0,               (* Min output *)
    MAXS := 200.0,             (* Max setpoint *)
    MINS := 50.0               (* Min setpoint *)
);

valveOutput := reactorPID.CV;
spClamped := reactorPID.SPH OR reactorPID.SPL;
```

**Additional Inputs (beyond PID):**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `FF` | REAL | 0.0 | Feed-forward term (added directly to output) |
| `BIAS` | REAL | 0.0 | Output bias/offset |
| `MAXO` | REAL | 100.0 | Maximum output |
| `MINO` | REAL | 0.0 | Minimum output |
| `MAXS` | REAL | 0.0 | Maximum setpoint limit |
| `MINS` | REAL | 0.0 | Minimum setpoint limit |
| `MAXI` | REAL | 100.0 | Maximum integral accumulation |
| `MINI` | REAL | -100.0 | Minimum integral accumulation |
| `DPTS` | BOOL | FALSE | Dependent gains mode |
| `MO` | BOOL | FALSE | Manual output mode (CV = MOCV) |
| `MOCV` | REAL | 0.0 | Manual CV value |
| `INIMAN` | BOOL | FALSE | Initialize integral from MOCV |

**Additional Outputs:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `SPH` | BOOL | Setpoint clamped to MAXS |
| `SPL` | BOOL | Setpoint clamped to MINS |
| `PVHH` | BOOL | PV high-high alarm |
| `PVH` | BOOL | PV high alarm |
| `PVL` | BOOL | PV low alarm |
| `PVLL` | BOOL | PV low-low alarm |

**Key Differences from PID:**
- Derivative is calculated on PV (not error) to avoid derivative kick on setpoint changes
- Feed-forward term for measurable disturbance rejection
- Setpoint clamping with limit flags
- Manual mode for bumpless transfer between auto and manual
- Bounded integral accumulation (separate from output limits)

---

## 7. TIME Literals

All timer presets use IEC 61131-3 TIME literals:

| Literal | Duration |
|---------|----------|
| `T#500ms` | 500 milliseconds |
| `T#1s` | 1 second |
| `T#5s` | 5 seconds |
| `T#1m30s` | 1 minute 30 seconds |
| `T#1h` | 1 hour |
| `T#1h30m` | 1 hour 30 minutes |
| `T#2d` | 2 days |
| `T#100ms` | 100 milliseconds |
| `T#10us` | 10 microseconds |

---

## 8. Complete Example: Pump Station

A realistic pump control program using timers, counters, edge triggers, and PID.

```iecst
PROGRAM POU_PumpStation
VAR
    (* Inputs *)
    startBtn : BOOL;
    stopBtn : BOOL;
    eStop : BOOL;
    levelSensor : REAL;            (* 0-100% *)
    flowSensor : REAL;             (* GPM *)

    (* Function block instances *)
    runLatch : RS;                 (* Reset-dominant for safety *)
    startDelay : TON;              (* Anti-short-cycle delay *)
    runTimer : RTO;                (* Accumulate total run hours *)
    cycleCount : CTU;              (* Count start/stop cycles *)
    startEdge : R_TRIG;           (* Detect start events *)
    levelPID : PID;                (* Level control *)
    dryRunTimer : TON;             (* Dry run protection *)

    (* Outputs *)
    pumpRun : BOOL;
    vfdSpeed : REAL;
    maintenanceDue : BOOL;
    dryRunFault : BOOL;
END_VAR

(* Safety latch — E-stop always wins *)
runLatch(S := startBtn AND NOT dryRunFault, R1 := stopBtn OR eStop);

(* Anti-short-cycle: must wait 30s between starts *)
startDelay(IN := NOT runLatch.Q1, PT := T#30s);
pumpRun := runLatch.Q1 AND startDelay.Q;

(* Count start events *)
startEdge(CLK := pumpRun);
cycleCount(CU := startEdge.Q, PV := 10000, R := FALSE);

(* Accumulate runtime for maintenance scheduling *)
runTimer(IN := pumpRun, PT := T#2000h, R := FALSE);
maintenanceDue := runTimer.Q;

(* Level PID — controls VFD speed *)
levelPID(
    EN := pumpRun,
    PV := levelSensor,
    SP := 75.0,                    (* Maintain 75% level *)
    KP := 5.0,
    KI := 0.3,
    KD := 0.5,
    CYCLE := 0.05,                 (* 50ms scan *)
    MN := 20.0,                    (* Min speed 20% *)
    MX := 100.0                    (* Max speed 100% *)
);
vfdSpeed := levelPID.CV;

(* Dry run protection: fault if running with no flow for 10s *)
dryRunTimer(IN := pumpRun AND (flowSensor < 1.0), PT := T#10s);
IF dryRunTimer.Q THEN
    dryRunFault := TRUE;           (* Latches until operator clears *)
END_IF;

END_PROGRAM
```

---

## Appendix A: Quick Reference

### Timers

| FB | Purpose | Key I/O |
|----|---------|---------|
| **TON** | On-delay | IN + PT → Q after delay |
| **TOF** | Off-delay | Q holds TRUE for PT after IN falls |
| **TP** | Pulse | Fixed-width pulse on rising edge |
| **RTO** | Retentive on-delay | Accumulates time, retains on IN=FALSE, needs R to clear |

### Counters

| FB | Purpose | Key I/O |
|----|---------|---------|
| **CTU** | Count up | CU rising edge → CV++, Q when CV >= PV |
| **CTD** | Count down | CD rising edge → CV--, Q when CV <= 0 |
| **CTUD** | Up/down | CU/CD edges, QU (upper), QD (lower) |

### Bistables

| FB | Purpose | Priority |
|----|---------|----------|
| **SR** | Set-Reset latch | Set dominant |
| **RS** | Reset-Set latch | Reset dominant (use for safety) |

### Edge Triggers

| FB | Purpose | Output |
|----|---------|--------|
| **R_TRIG** | Rising edge | Q = TRUE for one scan on FALSE→TRUE |
| **F_TRIG** | Falling edge | Q = TRUE for one scan on TRUE→FALSE |

### PID

| FB | Purpose | Key Features |
|----|---------|-------------|
| **PID** | Standard PID | KP/KI/KD, anti-windup, output clamping |
| **PIDE** | Enhanced PID | Feed-forward, bias, manual mode, SP limits, alarms |

---

*GoPLC v1.0.535 | IEC 61131-3 Function Blocks | Timers, Counters, PID*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
