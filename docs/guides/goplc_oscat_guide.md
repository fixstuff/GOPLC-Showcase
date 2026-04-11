# GoPLC OSCAT Library Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

OSCAT (Open Source Community for Automation Technology) is a comprehensive IEC 61131-3 function library shipped with GoPLC. It provides **550 functions and function blocks** covering mathematics, string processing, date/time, engineering controls, signal processing, and more — all written in Structured Text.

Unlike GoPLC's built-in functions (implemented in Go), OSCAT functions are user-space ST code. They run in your scan loop like any other program. 97 OSCAT functions overlap with GoPLC builtins (math, string, date) — the builtin versions are faster but both work.

---

## 2. Setup — How to Enable OSCAT

### Method 1: YAML Config (Recommended)

Add `oscat` to the `libraries` list in your config file:

```yaml
# config.yaml
runtime:
  libraries:
    - oscat

tasks:
  - name: MainTask
    type: periodic
    scan_time_ms: 50
    programs:
      - POU_MyProgram
```

GoPLC automatically resolves `oscat` to `lib/oscat/LIB_Oscat.st`.

### Method 2: Explicit Path

```yaml
runtime:
  libraries:
    - lib/oscat/LIB_Oscat.st
    - /path/to/other/library.st
```

### Method 3: .goplc Project File

When using a `.goplc` project file, add the library in the project's `config_yaml` section or load it alongside:

```bash
goplc project.goplc --config config.yaml
```

Where `config.yaml` contains the `libraries: [oscat]` entry.

### Method 4: API

```bash
curl -X POST http://localhost:8082/api/libraries \
  -H "Content-Type: application/json" \
  -d '{"name": "oscat", "path": "lib/oscat/LIB_Oscat.st"}'
```

### Verify It Loaded

Once running, all 550 functions are available in every program without imports. Verify by calling any OSCAT function:

```iecst
(* If this compiles, OSCAT is loaded *)
result := SINH(1.0);        (* Should return 1.1752 *)
day := DAY_OF_WEEK(NOW());
```

Or check via API:

```bash
curl http://localhost:8082/api/libraries
# Should show: [{"name": "oscat", "path": "lib/oscat/LIB_Oscat.st", ...}]
```

### Builtin vs OSCAT Overlap — Important

97 of 550 OSCAT functions have identical names as GoPLC's built-in functions (e.g., SINH, CEIL, TRIM, C_TO_F, DAY_OF_YEAR). **GoPLC builtins always win** — the compiled Go version runs regardless of whether OSCAT is loaded. This means:

- No performance penalty for the 97 overlapping functions
- The remaining 453 OSCAT-only functions run as interpreted ST
- You get the best of both: fast builtins + OSCAT's unique capabilities

This is transparent — you call `SINH(x)` and get the Go builtin whether OSCAT is loaded or not.

---

## 3. Library Contents — 25 Categories

| Category | Functions | FBs | Total | Description |
|----------|-----------|-----|-------|-------------|
| **Mathematical** | 64 | — | 64 | Hyperbolic, special functions, interpolation |
| **String** | 72 | 3 | 75 | Formatting, parsing, conversion |
| **Time & Date** | 47 | 8 | 55 | Calendar math, holidays, scheduling |
| **Signal Processing** | 24 | 19 | 43 | Filters, scaling, linearization |
| **Gate Logic** | 34 | 4 | 38 | Bit manipulation, encoding, comparators |
| **Control** | 4 | 30 | 34 | PID variants, ramp generators, controllers |
| **Math / Complex** | 26 | — | 26 | Complex number arithmetic |
| **Generators** | — | 23 | 23 | Clock dividers, pulse generators, sequences |
| **Conversion** | 15 | 6 | 21 | Unit conversion, astronomical calculations |
| **Math / Array** | 18 | — | 18 | Array statistics, operations |
| **Automation** | 1 | 17 | 18 | Motor drivers, interlocks, sequencers |
| **Buffer Management** | 17 | — | 17 | Low-level buffer operations |
| **Measurements** | 2 | 15 | 17 | Alarms, calibration, cycle timing |
| **Signal Generators** | — | 16 | 16 | Ramp, waveform, profile generators |
| **Math / Vector** | 14 | — | 14 | 3D vector math |
| **Edge-Triggered FFs** | — | 13 | 13 | D flip-flops, counters |
| **Math / Functions** | 8 | 3 | 11 | Linear, polynomial, lookup |
| **Sensor** | 10 | — | 10 | RTD, NTC, thermocouple linearization |
| **Math / Geometry** | 8 | — | 8 | Circle, ellipse, cone, sphere |
| **List Processing** | 7 | 1 | 8 | Linked list operations |
| **Other** | 2 | 4 | 6 | Error handling, version info |
| **Math / Double Precision** | 5 | — | 5 | Extended precision math |
| **Memory** | — | 4 | 4 | FIFO, LIFO buffers |
| **Pulse-Triggered FFs** | — | 3 | 3 | Latches, stores |
| **Logic / Other** | 1 | 2 | 3 | CRC, matrix, PIN code |

---

## 4. Mathematical (64 + 56 subtypes = 120)

### Core Math (64)

Hyperbolic, inverse hyperbolic, and special functions not in the IEC standard:

```iecst
(* Hyperbolic functions *)
result := SINH(x);
result := COSH(x);
result := TANH(x);
result := ASINH(x);
result := ACOSH(x);
result := ATANH(x);

(* Special functions *)
result := GDF(x);           (* Gaussian distribution function *)
result := AGDF(x);          (* Inverse Gaussian distribution *)
result := BETA(a, b);       (* Beta function *)
result := GAMMA(x);         (* Gamma function *)
result := ERF(x);           (* Error function *)
result := ERFC(x);          (* Complementary error function *)

(* Interpolation *)
result := F_LIN(x, x1, y1, x2, y2);           (* Linear interpolation *)
result := F_POLY(x, a0, a1, a2, a3);           (* Polynomial evaluation *)
result := F_QUAD(x, x1, y1, x2, y2, x3, y3);  (* Quadratic interpolation *)
```

### Complex Numbers (26)

Full complex arithmetic — add, subtract, multiply, divide, trig, exponential:

```iecst
(* Complex numbers as REAL pairs [real, imaginary] *)
result := CADD(re1, im1, re2, im2);     (* Addition *)
result := CMUL(re1, im1, re2, im2);     (* Multiplication *)
result := CDIV(re1, im1, re2, im2);     (* Division *)
magnitude := CABS(re, im);               (* Absolute value *)
angle := CARG(re, im);                   (* Argument (phase angle) *)
result := CSQRT(re, im);                 (* Square root *)
result := CEXP(re, im);                  (* Exponential *)
result := CLN(re, im);                   (* Natural log *)
```

### Array Operations (18)

```iecst
(* Array math — work on OSCAT-style arrays *)
_ARRAY_INIT(adr, size, value);     (* Fill array *)
_ARRAY_ADD(adr, size, value);      (* Add scalar to each element *)
_ARRAY_MUL(adr, size, value);      (* Multiply each element *)
median := _ARRAY_MEDIAN(adr, size);
sum := _ARRAY_SUM(adr, size);
avg := _ARRAY_AVG(adr, size);
min := _ARRAY_MIN(adr, size);
max := _ARRAY_MAX(adr, size);
```

### Geometry (8)

```iecst
area := CIRCLE_A(radius);               (* Circle area *)
circ := CIRCLE_C(radius);               (* Circumference *)
seg := CIRCLE_SEG(radius, angle);       (* Segment area *)
vol := CONE_V(radius, height);          (* Cone volume *)
area := ELLIPSE_A(a, b);                (* Ellipse area *)
area := TRIANGLE_A(a, b, c);            (* Triangle area (Heron) *)
vol := SPHERE_V(radius);                (* Sphere volume *)
```

### 3D Vectors (14)

```iecst
mag := V3_ABS(x, y, z);                 (* Vector magnitude *)
result := V3_ADD(x1,y1,z1, x2,y2,z2);  (* Vector addition *)
dot := V3_DPRO(x1,y1,z1, x2,y2,z2);   (* Dot product *)
cross := V3_XPRO(x1,y1,z1, x2,y2,z2); (* Cross product *)
norm := V3_NORM(x, y, z);               (* Normalize *)
angle := V3_ANG(x1,y1,z1, x2,y2,z2);  (* Angle between *)
```

---

## 5. String (75)

String formatting, parsing, and manipulation beyond IEC standard:

```iecst
(* Formatting *)
result := CAPITALIZE('hello world');      (* "Hello World" *)
result := TRIM('  hello  ');              (* "hello" *)
result := FILL(' ', 20);                  (* 20 spaces *)
result := FINDB('hello world', 'world');  (* Binary search *)

(* Number formatting *)
result := REAL_TO_STRF(3.14159, 2);       (* "3.14" — formatted *)
result := INT_TO_STRF(42, 5);             (* "   42" — padded *)
result := DT_TO_STRF(now, 'YYYY-MM-DD'); (* Date formatting *)

(* Hex/binary conversion *)
result := BYTE_TO_STRH(255);              (* "FF" *)
result := BYTE_TO_STRB(255);              (* "11111111" *)
result := DWORD_TO_STRH(value);           (* Hex string *)

(* Parsing *)
result := CHARNAME(65);                   (* "A" — character name *)
result := UPPERCASE(str);
result := LOWERCASE(str);
result := IS_ALPHA(char);                 (* Character classification *)
result := IS_NUM(char);
result := IS_ALNUM(char);
```

---

## 6. Time & Date (55)

Calendar math, holiday calculation, scheduling:

```iecst
(* Calendar *)
dow := DAY_OF_WEEK(date);                (* 0=Sunday, 6=Saturday *)
doy := DAY_OF_YEAR(date);                (* 1-366 *)
dom := DAY_OF_MONTH(date);
leap := IS_LEAP_YEAR(year);
days := DAYS_IN_MONTH(month, year);

(* Date arithmetic *)
new_date := DATE_ADD(date, days, months, years);
diff := DAYS_BETWEEN(date1, date2);

(* Time zone and DST *)
result := UTC_TO_LOCAL(utc_time, offset_hours);
is_dst := IS_DST(date, region);

(* Holiday calculation *)
easter := EASTER(year);                   (* Easter Sunday *)
holiday := IS_HOLIDAY(date, country);

(* Astronomical *)
sunrise := SUN_TIME(date, latitude, longitude, 'rise');
sunset := SUN_TIME(date, latitude, longitude, 'set');
moon := MOON_PHASE(date);                (* 0.0-1.0 *)

(* Scheduling *)
schedule.enable := TRUE;
schedule.start := TOD#08:00:00;
schedule.stop := TOD#17:00:00;
active := SCHEDULER(schedule, current_time);
```

---

## 7. Engineering — Control (34)

PID variants, ramp generators, and advanced controllers:

```iecst
(* PID with different control strategies *)
ctrl_pid(pv := actual_temp, sp := setpoint, kp := 5.0, ki := 0.2, kd := 1.0);
output := ctrl_pid.y;

(* Ramp generator — linear ramp to setpoint *)
ramp(IN := new_setpoint, PT := T#10s, OUT => ramped_value);

(* Cascade control *)
outer_pid(pv := level, sp := level_sp);
inner_pid(pv := flow, sp := outer_pid.y);

(* Split-range control *)
CONTROL_SET2(input := pid_output,
             out1 => heating_valve, out2 => cooling_valve,
             sp1 := 50.0, sp2 := 50.0);

(* Band controller — on/off with hysteresis *)
BAND_B(x := temperature, ll := 68.0, ul := 72.0, q => heater);
```

---

## 8. Engineering — Signal Processing (43)

Filters, scaling, linearization, analog I/O conditioning:

```iecst
(* Analog input conditioning *)
AIN(in := raw_adc, ll := 0, ul := 4095, out_ll := 0.0, out_ul := 100.0);

(* First-order low-pass filter *)
filter_lp(in := noisy_signal, t := T#1s, out => filtered);

(* Moving average *)
avg_filter(in := raw_value, n := 10, out => smooth_value);

(* Dead band *)
dead_band(in := value, db := 0.5, out => clean_value);

(* Rate of change limiter *)
ramp_limit(in := setpoint, rate := 10.0, out => limited);

(* Sensor linearization — lookup table *)
linearize(in := raw_temp, table := temp_curve, out => actual_temp);
```

---

## 9. Engineering — Sensors (10)

Resistance-to-temperature conversion for common sensor types:

```iecst
(* Platinum RTD (PT100, PT1000) *)
temp_c := RES_PT(resistance, 100.0);      (* PT100 *)
temp_c := RES_PT(resistance, 1000.0);     (* PT1000 *)

(* NTC thermistor *)
temp_c := RES_NTC(resistance, r25, beta);

(* Nickel RTD *)
temp_c := RES_NI(resistance, r0);

(* Silicon sensor *)
temp_c := RES_SI(resistance, r25);

(* Thermocouple linearization *)
temp_c := TC_K(millivolts);               (* Type K *)
temp_c := TC_J(millivolts);               (* Type J *)
```

---

## 10. Engineering — Automation (18)

Motor control, sequencing, interlocking:

```iecst
(* 4-output motor driver with interlock *)
driver4(fwd := fwd_cmd, rev := rev_cmd, interlock := safety_ok);
motor_fwd := driver4.q1;
motor_rev := driver4.q2;

(* Increment/decrement with limits *)
INC_DEC(up := inc_btn, down := dec_btn, min := 0, max := 100, out => position);

(* Sequencer *)
seq(step := step_cmd, reset := reset_cmd);
current_step := seq.step;
```

---

## 11. Logic (64)

### Gate Logic (38)

Bit manipulation, encoding/decoding, comparators:

```iecst
(* Bit operations *)
count := BIT_COUNT(dword_val);            (* Count set bits *)
result := BIT_LOAD_DW(dword_val, bit, value);  (* Set/clear bit *)
result := REFLECT(byte_val);              (* Reverse bit order *)

(* BCD conversion *)
int_val := BCDC_TO_INT(bcd_val);
bcd_val := INT_TO_BCDC(int_val);

(* Encoding *)
gray := GRAY_ENCODE(binary);
binary := GRAY_DECODE(gray);

(* CRC generation *)
crc := CRC_GEN(data, polynomial, init);
```

### Generators (23)

Clock dividers, pulse generators, sequencers:

```iecst
(* Clock divider *)
clk_div(in := fast_clock, n := 10, out => slow_clock);

(* Pulse train *)
gen_pulse(run := TRUE, pt := T#500ms, q => pulse);

(* Blink generator *)
blink(enable := TRUE, t_on := T#1s, t_off := T#1s, q => output);

(* Debounce *)
debounce(in := raw_input, t := T#50ms, q => stable_input);
```

---

## 12. Conversion (21)

Unit conversion and astronomical calculations:

```iecst
(* Temperature *)
f := C_TO_F(celsius);
c := F_TO_C(fahrenheit);
k := C_TO_K(celsius);

(* Wind speed *)
ms := BFT_TO_MS(beaufort);               (* Beaufort to m/s *)
bft := MS_TO_BFT(meters_per_sec);

(* Pressure *)
psi := BAR_TO_PSI(bar);
bar := PSI_TO_BAR(psi);

(* Direction *)
dir := DEG_TO_DIR(degrees);              (* "N", "NE", "E", ... *)
deg := DIR_TO_DEG('NE');                 (* 45.0 *)

(* Astronomical *)
sunrise := ASTRO(date, lat, lon);        (* Sun position calculation *)
```

---

## 13. Usage Notes

### OSCAT vs GoPLC Builtins

Some OSCAT functions overlap with GoPLC built-in functions. When both exist, the built-in version is faster (compiled Go vs interpreted ST). Use OSCAT when:

- The function doesn't exist as a builtin (e.g., complex numbers, sensor linearization, holiday calculation)
- You need the specific OSCAT behavior (e.g., OSCAT PID tuning parameters)
- Portability matters (OSCAT code works on CODESYS, Beckhoff, Siemens too)

### Pointer Functions

Some OSCAT functions use `REF_TO` (pointer) parameters for buffer and array operations. These are prefixed with `_` (e.g., `_BUFFER_CLEAR`, `_ARRAY_INIT`). They manipulate data in place for performance.

### Version

GoPLC ships OSCAT version **3.31** (30,514 lines, 550 functions/FBs).

---

## Appendix A: Category Quick Reference

| Category | Count | Key Functions |
|----------|-------|---------------|
| Mathematical | 64 | SINH, COSH, TANH, GAMMA, ERF, BETA, GDF |
| Complex | 26 | CADD, CMUL, CDIV, CABS, CSQRT, CEXP |
| Array | 18 | _ARRAY_SUM, _ARRAY_AVG, _ARRAY_MEDIAN, _ARRAY_SORT |
| Vector 3D | 14 | V3_ABS, V3_ADD, V3_DPRO, V3_XPRO, V3_NORM |
| Geometry | 8 | CIRCLE_A, ELLIPSE_A, CONE_V, SPHERE_V, TRIANGLE_A |
| Double Prec. | 5 | R2_ADD, R2_MUL, R2_ABS |
| Functions | 11 | F_LIN, F_POLY, F_QUAD, F_POWER |
| String | 75 | CAPITALIZE, TRIM, REAL_TO_STRF, DT_TO_STRF, IS_ALPHA |
| Time & Date | 55 | DAY_OF_WEEK, EASTER, SUN_TIME, MOON_PHASE, SCHEDULER |
| Control | 34 | PID variants, RAMP, BAND_B, CONTROL_SET1/2, CTRL_IN/OUT |
| Signal Proc. | 43 | AIN, AOUT, LP filter, moving avg, dead band, linearize |
| Sensor | 10 | RES_PT, RES_NTC, RES_NI, TC_K, TC_J |
| Automation | 18 | DRIVER_1/4, INC_DEC, sequencer, interlocks |
| Signal Gen. | 16 | GEN_PULSE, ramp generators, profile |
| Gate Logic | 38 | BIT_COUNT, GRAY_ENCODE, CRC_GEN, BCD conversion |
| Generators | 23 | CLK_DIV, blink, debounce, pulse train |
| Conversion | 21 | BFT_TO_MS, BAR_TO_PSI, DEG_TO_DIR, ASTRO |
| Buffer | 17 | _BUFFER_CLEAR, _BUFFER_INIT, _BUFFER_INSERT |
| Measurement | 17 | ALARM_2, CALIBRATE, CYCLE_TIME |
| FF Edge | 13 | D flip-flops, counters (edge-triggered) |
| FF Pulse | 3 | LTCH, STORE_8 |
| Memory | 4 | FIFO_16, FIFO_32, STACK_16, STACK_32 |
| List | 8 | LIST_ADD, LIST_GET, LIST_INSERT, LIST_CLEAN |
| Other | 6 | OSCAT_VERSION, ESR error handling |

---

*GoPLC v1.0.535 | OSCAT Library v3.31 | 550 Functions & Function Blocks | IEC 61131-3 Compatible*

*OSCAT is developed by the Open Source Community for Automation Technology and licensed under LGPL 3.0.*
*OSCAT is an independent open-source project — not affiliated with JMB Technical Services LLC.*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
