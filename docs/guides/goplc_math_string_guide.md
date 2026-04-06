# GoPLC Math, String & Conversion Reference

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Math & Trigonometry

### Basic Math

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `ABS` | `(x)` | REAL/INT | Absolute value |
| `SIGN` | `(x)` | INT | -1, 0, or 1 |
| `SQRT` | `(x)` | REAL | Square root |
| `POW` | `(base, exp)` | REAL | Power (base^exp) |
| `EXPT` | `(base, exp)` | REAL | Same as POW |
| `EXP` | `(x)` | REAL | e^x |
| `LN` | `(x)` | REAL | Natural logarithm |
| `LOG` | `(x)` | REAL | Base-10 logarithm |
| `FMOD` | `(x, y)` | REAL | Floating-point modulus |

```iecst
distance := SQRT(POW(x2 - x1, 2) + POW(y2 - y1, 2));
gain_db := 20.0 * LOG(vout / vin);
```

### Rounding

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `CEIL` | `(x)` | REAL | Round up to integer |
| `FLOOR` | `(x)` | REAL | Round down to integer |
| `ROUND` | `(x)` | REAL | Round to nearest integer |
| `TRUNC` | `(x)` | REAL | Truncate toward zero |

```iecst
pages := CEIL(total_items / 10.0);      (* 25 items → 3 pages *)
whole := TRUNC(3.7);                     (* 3.0 *)
```

### Trigonometry

All angles in **radians**.

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `SIN` | `(rad)` | REAL | Sine |
| `COS` | `(rad)` | REAL | Cosine |
| `TAN` | `(rad)` | REAL | Tangent |
| `ASIN` | `(x)` | REAL | Arc sine (returns radians) |
| `ACOS` | `(x)` | REAL | Arc cosine |
| `ATAN` | `(x)` | REAL | Arc tangent |
| `ATAN2` | `(y, x)` | REAL | Two-argument arc tangent |
| `DEG_TO_RAD` | `(deg)` | REAL | Degrees → radians |
| `RAD_TO_DEG` | `(rad)` | REAL | Radians → degrees |

```iecst
angle_rad := DEG_TO_RAD(45.0);
x := COS(angle_rad) * radius;
y := SIN(angle_rad) * radius;
heading := RAD_TO_DEG(ATAN2(dy, dx));
```

---

## 2. Selection & Comparison

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `MIN` | `(a, b)` | ANY | Smaller of two values |
| `MAX` | `(a, b)` | ANY | Larger of two values |
| `LIMIT` | `(min, value, max)` | ANY | Clamp value to range |
| `CLAMP` | `(value, min, max)` | ANY | Same as LIMIT (different arg order) |
| `SEL` | `(condition, false_val, true_val)` | ANY | Conditional select (like ternary) |
| `MUX` | `(index, val0, val1, val2, ...)` | ANY | Indexed multiplexer |

```iecst
(* Clamp output to 0-100% *)
output := LIMIT(0.0, pid_output, 100.0);

(* Select based on condition *)
mode_name := SEL(auto_mode, 'MANUAL', 'AUTO');

(* Multiplexer — select by index *)
recipe_temp := MUX(recipe_id, 150.0, 180.0, 200.0, 220.0);
```

---

## 3. Statistics

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `MEAN` | `(array)` | REAL | Arithmetic mean |
| `MEDIAN` | `(array)` | REAL | Middle value |
| `VARIANCE` | `(array)` | REAL | Population variance |
| `STDDEV` | `(array)` | REAL | Standard deviation |
| `PERCENTILE` | `(array, pct)` | REAL | Nth percentile (0-100) |
| `MOVING_AVG` | `(handle, value, window)` | REAL | Moving average (handle-based) |
| `SMA` | `(handle, value, window)` | REAL | Simple moving average (alias) |
| `EMA` | `(handle, value, alpha)` | REAL | Exponential moving average |

```iecst
temps := ARRAY_CREATE(68.2, 72.1, 71.5, 73.0, 69.8);
avg := MEAN(temps);                    (* 70.92 *)
med := MEDIAN(temps);                  (* 71.5 *)
sd := STDDEV(temps);                   (* ~1.8 *)
p95 := PERCENTILE(temps, 95);         (* ~72.8 *)

(* Running average over last 20 samples *)
smooth_temp := MOVING_AVG('temp_avg', raw_temp, 20);

(* Exponential smoothing — alpha 0.1 = heavy smoothing *)
filtered := EMA('pressure_ema', raw_pressure, 0.1);
```

---

## 4. Interpolation & Scaling

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `LERP` | `(a, b, t)` | REAL | Linear interpolation (t=0→a, t=1→b) |
| `SCALE` | `(value, in_min, in_max, out_min, out_max)` | REAL | Map range to range |
| `RANDOM` | `()` | REAL | Random 0.0–1.0 |
| `RAND` | `()` | REAL | Alias for RANDOM |
| `RANDOM_RANGE` | `(min, max)` | REAL | Random in range |

```iecst
(* Scale 0-4095 ADC to 0-100 PSI *)
pressure_psi := SCALE(adc_raw, 0, 4095, 0.0, 100.0);

(* Fade between two colors over 100 steps *)
brightness := LERP(0.0, 100.0, INT_TO_REAL(step) / 100.0);

(* Simulate sensor noise *)
noisy := actual_temp + (RANDOM_RANGE(-0.5, 0.5));
```

---

## 5. Unit Conversions

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `C_TO_F` | `(celsius)` | REAL | Celsius → Fahrenheit |
| `F_TO_C` | `(fahrenheit)` | REAL | Fahrenheit → Celsius |
| `C_TO_K` | `(celsius)` | REAL | Celsius → Kelvin |
| `K_TO_C` | `(kelvin)` | REAL | Kelvin → Celsius |
| `KMH_TO_MS` | `(kmh)` | REAL | km/h → m/s |
| `MS_TO_KMH` | `(ms)` | REAL | m/s → km/h |
| `DEG_TO_RAD` | `(degrees)` | REAL | Degrees → radians |
| `RAD_TO_DEG` | `(radians)` | REAL | Radians → degrees |

---

## 6. String Functions

### Length & Access

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `LEN` | `(str)` | INT | String length |
| `LEFT` | `(str, count)` | STRING | First N characters |
| `RIGHT` | `(str, count)` | STRING | Last N characters |
| `MID` | `(str, start, count)` | STRING | Substring (1-based start) |
| `CHR` | `(code)` | STRING | ASCII code → character |
| `ORD` | `(str)` | INT | First character → ASCII code |

```iecst
name := 'GOPLC-Plant1';
prefix := LEFT(name, 5);              (* "GOPLC" *)
suffix := RIGHT(name, 6);             (* "Plant1" *)
mid := MID(name, 7, 6);               (* "Plant1" *)
newline := CHR(10);                    (* \n *)
```

### Search

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `FIND` | `(str, search)` | INT | Position of substring (0 = not found) |
| `CONTAINS` | `(str, search)` | BOOL | Substring exists? |
| `STARTS_WITH` | `(str, prefix)` | BOOL | Starts with prefix? |
| `ENDS_WITH` | `(str, suffix)` | BOOL | Ends with suffix? |

```iecst
IF CONTAINS(alarm_text, 'HIGH') THEN
    severity := 3;
END_IF;
```

### Modify

| Function | Signature | Returns | Description |
|----------|-----------|---------|-------------|
| `CONCAT` | `(str1, str2, ...)` | STRING | Join strings (variadic) |
| `REPLACE` | `(str, search, replacement)` | STRING | Replace all occurrences |
| `INSERT` | `(str, position, insert_str)` | STRING | Insert at position |
| `DELETE` | `(str, position, count)` | STRING | Delete characters |
| `UPPER` | `(str)` | STRING | Uppercase |
| `LOWER` | `(str)` | STRING | Lowercase |
| `TRIM` | `(str)` | STRING | Strip whitespace both ends |
| `LTRIM` | `(str)` | STRING | Strip leading whitespace |
| `RTRIM` | `(str)` | STRING | Strip trailing whitespace |
| `REVERSE` | `(str)` | STRING | Reverse string |
| `REPEAT` | `(str, count)` | STRING | Repeat N times |
| `PAD_LEFT` | `(str, width, pad_char)` | STRING | Left-pad to width |
| `PAD_RIGHT` | `(str, width, pad_char)` | STRING | Right-pad to width |
| `SPLIT` | `(str, delimiter)` | ARRAY | Split into array |
| `FORMAT` | `(template, args...)` | STRING | Printf-style formatting |

```iecst
msg := CONCAT('Temperature: ', REAL_TO_STRING(temp), ' F');
csv := REPLACE(raw_data, ';', ',');
parts := SPLIT('10.0.0.50:502', ':');       (* ["10.0.0.50", "502"] *)
padded := PAD_LEFT(INT_TO_STRING(batch), 6, '0');  (* "000042" *)
line := FORMAT('%s,%d,%.2f', tag_name, count, value);
```

---

## 7. Type Conversions

### Numeric

| From \ To | INT | DINT | REAL | STRING | BOOL | BYTE | WORD | DWORD |
|-----------|-----|------|------|--------|------|------|------|-------|
| **INT** | — | `INT_TO_DINT` | `INT_TO_REAL` | `INT_TO_STRING` | `INT_TO_BOOL` | `INT_TO_BYTE` | `INT_TO_WORD` | `INT_TO_DWORD` |
| **DINT** | `DINT_TO_INT` | — | `DINT_TO_REAL` | `DINT_TO_STRING` | — | `DINT_TO_BYTE` | `DINT_TO_WORD` | — |
| **REAL** | `REAL_TO_INT` | `REAL_TO_DINT` | — | `REAL_TO_STRING` | — | `REAL_TO_BYTE` | `REAL_TO_WORD` | `REAL_TO_DWORD` |
| **STRING** | `STRING_TO_INT` | `STRING_TO_DINT` | `STRING_TO_REAL` | — | `STRING_TO_BOOL` | `STRING_TO_BYTE` | `STRING_TO_WORD` | `STRING_TO_DWORD` |
| **BOOL** | `BOOL_TO_INT` | `BOOL_TO_DINT` | — | `BOOL_TO_STRING` | — | `BOOL_TO_BYTE` | `BOOL_TO_WORD` | `BOOL_TO_DWORD` |
| **BYTE** | `BYTE_TO_INT` | — | `BYTE_TO_REAL` | `BYTE_TO_STRING` | — | — | `BYTE_TO_WORD` | `BYTE_TO_DWORD` |
| **WORD** | `WORD_TO_INT` | — | `WORD_TO_REAL` | `WORD_TO_STRING` | — | `WORD_TO_BYTE` | — | `WORD_TO_DWORD` |
| **DWORD** | `DWORD_TO_INT` | `DWORD_TO_DINT` | `DWORD_TO_REAL` | `DWORD_TO_STRING` | — | `DWORD_TO_BYTE` | `DWORD_TO_WORD` | — |

### Extended Integer Types

| Function | Description |
|----------|-------------|
| `UINT_TO_INT`, `INT_TO_UINT` | Unsigned ↔ signed 16-bit |
| `UDINT_TO_DINT`, `DINT_TO_UDINT` | Unsigned ↔ signed 32-bit |
| `LINT_TO_INT`, `INT_TO_LINT` | 64-bit ↔ 32-bit |
| `ULINT_TO_UINT`, `UINT_TO_ULINT` | Unsigned 64-bit ↔ 16-bit |
| `SINT_TO_STRING`, `USINT_TO_STRING` | Short int → string |

### Date & Time

| Function | Description |
|----------|-------------|
| `TIME_TO_STRING`, `STRING_TO_TIME` | TIME ↔ STRING |
| `TIME_TO_DINT`, `DINT_TO_TIME` | TIME ↔ milliseconds |
| `TIME_TO_REAL`, `REAL_TO_TIME` | TIME ↔ seconds (float) |
| `DATE_TO_STRING`, `STRING_TO_DATE` | DATE ↔ STRING |
| `DT_TO_STRING`, `STRING_TO_DT` | DATE_TIME ↔ STRING |
| `DT_TO_DATE`, `DATE_TO_DT` | Extract/build date portion |
| `DT_TO_TOD`, `TOD_TO_TIME` | Extract/build time-of-day |
| `DATE_TO_DWORD`, `DWORD_TO_DATE` | DATE ↔ binary |
| `DT_TO_DWORD`, `DWORD_TO_DT` | DATE_TIME ↔ binary |
| `TOD_TO_DINT`, `DINT_TO_TOD` | Time-of-day ↔ integer |

### Number Base

| Function | Description |
|----------|-------------|
| `INT_TO_HEX`, `HEX_TO_INT` | Integer ↔ hex string |
| `DINT_TO_HEX`, `HEX_TO_DINT` | 32-bit ↔ hex string |
| `INT_TO_BIN`, `BIN_TO_INT` | Integer ↔ binary string |
| `DINT_TO_BIN`, `BIN_TO_DINT` | 32-bit ↔ binary string |
| `INT_TO_OCT`, `OCT_TO_INT` | Integer ↔ octal string |
| `DINT_TO_OCT`, `OCT_TO_DINT` | 32-bit ↔ octal string |
| `BYTE_TO_GRAY`, `GRAY_TO_BYTE` | Binary ↔ Gray code |

```iecst
hex := DINT_TO_HEX(255);              (* "FF" *)
val := HEX_TO_INT('1A');               (* 26 *)
gray := BYTE_TO_GRAY(13);              (* Gray code encoding *)
```

---

## 8. Bitwise Operations

| Operator | Syntax | Description |
|----------|--------|-------------|
| `AND` | `a AND b` | Bitwise AND |
| `OR` | `a OR b` | Bitwise OR |
| `XOR` | `a XOR b` | Bitwise XOR |
| `NOT` | `NOT a` | Bitwise NOT |
| `SHL` | `SHL(value, bits)` | Shift left |
| `SHR` | `SHR(value, bits)` | Shift right |
| `ROL` | `ROL(value, bits)` | Rotate left |
| `ROR` | `ROR(value, bits)` | Rotate right |
| `SET_BIT` | `SET_BIT(value, bit)` | Set bit N |

```iecst
(* Extract bits from a status word *)
motor_running := (status_word AND 16#0001) > 0;     (* Bit 0 *)
fault_active := (status_word AND 16#0002) > 0;       (* Bit 1 *)

(* Build a command word *)
cmd := 0;
IF start THEN cmd := cmd OR 16#0001; END_IF;
IF forward THEN cmd := cmd OR 16#0004; END_IF;
```

---

## 9. Complete Example: Sensor Signal Processing

```iecst
PROGRAM POU_SignalProcessing
VAR
    (* Raw inputs *)
    adc_raw : INT;                     (* 0-4095 from ADC *)
    pressure_raw : REAL;

    (* Processed outputs *)
    pressure_psi : REAL;
    temp_f : REAL;
    temp_c : REAL;
    filtered_pressure : REAL;
    alarm_active : BOOL;

    (* Statistics *)
    pressure_avg : REAL;
    pressure_sd : REAL;
    samples : STRING;                  (* ARRAY handle *)
    sample_count : INT := 0;
END_VAR

(* Scale ADC to engineering units *)
pressure_psi := SCALE(INT_TO_REAL(adc_raw), 0.0, 4095.0, 0.0, 100.0);

(* Temperature conversion *)
temp_c := 25.0;
temp_f := C_TO_F(temp_c);

(* Exponential moving average filter *)
filtered_pressure := EMA('press_filter', pressure_psi, 0.15);

(* Hysteresis on alarm — prevents chatter near threshold *)
alarm_active := HYSTERESIS(filtered_pressure, 85.0, 90.0, alarm_active);

(* Clamp output to valid range *)
pressure_psi := CLAMP(pressure_psi, 0.0, 100.0);

(* Collect samples for statistics *)
sample_count := sample_count + 1;
IF sample_count = 1 THEN
    samples := ARRAY_CREATE(filtered_pressure);
ELSE
    samples := ARRAY_APPEND(samples, filtered_pressure);
    IF ARRAY_LENGTH(samples) > 100 THEN
        samples := ARRAY_SLICE(samples, 1, 100);    (* Keep last 100 *)
    END_IF;
END_IF;

IF ARRAY_LENGTH(samples) >= 10 THEN
    pressure_avg := MEAN(samples);
    pressure_sd := STDDEV(samples);
END_IF;

(* Format for display *)
display_text := FORMAT('Pressure: %.1f PSI (avg: %.1f, sd: %.2f)',
                       filtered_pressure, pressure_avg, pressure_sd);

END_PROGRAM
```

---

*GoPLC v1.0.535 | Math, String & Type Conversion Reference | IEC 61131-3 + Extensions*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
