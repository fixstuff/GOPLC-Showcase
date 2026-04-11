# GoPLC Regular Expressions Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 13 built-in regex functions for pattern matching, extraction, and text manipulation from Structured Text. All functions use the RE2 regex engine (same as Go's `regexp` package) — fast, safe, and predictable with no catastrophic backtracking.

Every function has two names — `REGEX_*` and the shorter `RE_*` alias. They are identical.

```iecst
(* Match a pattern *)
IF REGEX_MATCH(input, '^[0-9]+\.[0-9]+$') THEN
    (* Input is a decimal number *)
END_IF;

(* Extract data *)
ip := REGEX_FIND(response, '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+');

(* Replace *)
clean := REGEX_REPLACE(raw, '\s+', ' ');
```

---

## 2. Matching

### REGEX_MATCH — Test if Pattern Matches

```iecst
IF REGEX_MATCH('192.168.1.50', '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$') THEN
    (* Valid IP format *)
END_IF;

IF REGEX_MATCH(serial_data, 'OK|ACK') THEN
    (* Device acknowledged *)
END_IF;

IF NOT REGEX_MATCH(user_input, '^[A-Za-z0-9_]+$') THEN
    (* Invalid characters in input *)
END_IF;
```

Returns: `BOOL` — TRUE if the pattern matches anywhere in the text.

### REGEX_VALID — Check Pattern Syntax

```iecst
IF REGEX_VALID(user_pattern) THEN
    result := REGEX_FIND(text, user_pattern);
END_IF;
```

Returns: `BOOL` — TRUE if the pattern compiles without error.

---

## 3. Finding

### REGEX_FIND — First Match

```iecst
(* Extract first number from a string *)
num := REGEX_FIND('Temperature: 72.5 F', '[0-9]+\.?[0-9]*');
(* Returns: "72.5" *)

(* Extract IP address *)
ip := REGEX_FIND(log_line, '\d+\.\d+\.\d+\.\d+');
```

Returns: `STRING` — first match, or empty string if no match.

### REGEX_FIND_ALL — All Matches

```iecst
(* Find all numbers in a string *)
nums := REGEX_FIND_ALL('Temps: 72.5, 68.1, 71.8', '[0-9]+\.?[0-9]*');
(* Returns: ["72.5", "68.1", "71.8"] *)

(* Limit results *)
first_two := REGEX_FIND_ALL('a1 b2 c3 d4 e5', '[a-z][0-9]', 2);
(* Returns: ["a1", "b2"] *)
```

Returns: `ARRAY` of strings.

### REGEX_INDEX — Position of First Match

```iecst
pos := REGEX_INDEX('Hello World 123', '[0-9]+');
(* Returns: 12 — index where "123" starts *)
(* Returns: -1 if no match *)
```

### REGEX_INDICES — Start and End Position

```iecst
bounds := REGEX_INDICES('Hello World 123', '[0-9]+');
(* Returns: [12, 15] — start (inclusive) and end (exclusive) *)
```

### REGEX_COUNT — Number of Matches

```iecst
count := REGEX_COUNT('error error warning error info', 'error');
(* Returns: 3 *)
```

---

## 4. Capture Groups

### REGEX_GROUPS — Groups from First Match

Parentheses in the pattern create capture groups.

```iecst
(* Extract components from a Modbus response *)
groups := REGEX_GROUPS('REG[40001]=1750', '(\w+)\[(\d+)\]=(\d+)');
(* Returns: ["REG[40001]=1750", "REG", "40001", "1750"] *)
(*           full match          grp1   grp2     grp3    *)

register := groups[1];     (* "REG" *)
address := groups[2];      (* "40001" *)
value := groups[3];        (* "1750" *)
```

Returns: `ARRAY` — element 0 is the full match, elements 1+ are capture groups. Empty array if no match.

### REGEX_GROUPS_ALL — Groups from All Matches

```iecst
(* Parse all key=value pairs *)
all := REGEX_GROUPS_ALL('temp=72.5 press=45.3 flow=120', '(\w+)=([0-9.]+)');
(* Returns:
   [
     ["temp=72.5",  "temp",  "72.5"],
     ["press=45.3", "press", "45.3"],
     ["flow=120",   "flow",  "120"]
   ]
*)
```

Returns: `ARRAY` of arrays — each sub-array is `[full_match, group1, group2, ...]`.

---

## 5. Replacing

### REGEX_REPLACE — Replace All Matches

```iecst
(* Remove multiple spaces *)
clean := REGEX_REPLACE('hello    world', '\s+', ' ');
(* Returns: "hello world" *)

(* Mask sensitive data *)
masked := REGEX_REPLACE(log, 'password=\S+', 'password=****');

(* Reformat dates: MM/DD/YYYY → YYYY-MM-DD *)
iso := REGEX_REPLACE('03/15/2026', '(\d{2})/(\d{2})/(\d{4})', '$3-$1-$2');
(* Returns: "2026-03-15" *)
```

Use `$1`, `$2`, etc. to reference capture groups in the replacement string.

### REGEX_REPLACE_FIRST — Replace First Match Only

```iecst
result := REGEX_REPLACE_FIRST('error error error', 'error', 'WARNING');
(* Returns: "WARNING error error" *)
```

---

## 6. Splitting

### REGEX_SPLIT — Split by Pattern

```iecst
(* Split on any whitespace *)
parts := REGEX_SPLIT('one  two\tthree\nfour', '\s+');
(* Returns: ["one", "two", "three", "four"] *)

(* Split on comma with optional spaces *)
fields := REGEX_SPLIT('a, b , c,d', ',\s*');
(* Returns: ["a", "b", "c", "d"] *)

(* Limit splits *)
first_rest := REGEX_SPLIT('a:b:c:d:e', ':', 2);
(* Returns: ["a", "b:c:d:e"] *)
```

---

## 7. Escaping

### REGEX_ESCAPE — Escape Special Characters

```iecst
(* Make user input safe for regex *)
safe := REGEX_ESCAPE('price is $10.00 (USD)');
(* Returns: "price is \$10\.00 \(USD\)" *)

(* Use escaped input in a pattern *)
IF REGEX_MATCH(text, REGEX_ESCAPE(search_term)) THEN
    (* Literal match found *)
END_IF;
```

---

## 8. RE2 Pattern Syntax Quick Reference

| Pattern | Matches |
|---------|---------|
| `.` | Any character |
| `\d` | Digit (0-9) |
| `\w` | Word character (a-z, A-Z, 0-9, _) |
| `\s` | Whitespace (space, tab, newline) |
| `\D`, `\W`, `\S` | Inverse of above |
| `[abc]` | Character class |
| `[^abc]` | Negated class |
| `[0-9]` | Range |
| `^` | Start of string |
| `$` | End of string |
| `*` | Zero or more |
| `+` | One or more |
| `?` | Zero or one |
| `{3}` | Exactly 3 |
| `{2,5}` | 2 to 5 times |
| `(...)` | Capture group |
| `(?:...)` | Non-capturing group |
| `a\|b` | Alternation (a or b) |
| `\\.` | Literal dot (escape special chars) |

> **RE2 limitations:** No lookahead (`(?=...)`), no lookbehind (`(?<=...)`), no backreferences (`\1`). These are intentionally excluded for guaranteed linear-time matching.

---

## 9. Complete Example: Protocol Response Parser

Parse structured responses from serial devices:

```iecst
PROGRAM POU_ResponseParser
VAR
    response : STRING;
    groups : STRING;
    all_values : STRING;
    i : INT;
    tag : STRING;
    value : REAL;
END_VAR

(* Example: device returns "STAT:OK TEMP:72.5 PRESS:45.3 FLOW:120.0" *)
response := 'STAT:OK TEMP:72.5 PRESS:45.3 FLOW:120.0';

(* Check for OK status *)
IF REGEX_MATCH(response, 'STAT:OK') THEN

    (* Extract all tag:value pairs *)
    all_values := REGEX_GROUPS_ALL(response, '(\w+):([0-9.]+)');

    (* Parse each pair *)
    FOR i := 0 TO ARRAY_LENGTH(all_values) - 1 DO
        groups := ARRAY_GET(all_values, i);
        tag := ARRAY_GET(groups, 1);
        value := STRING_TO_REAL(ARRAY_GET(groups, 2));

        (* Route by tag name *)
        IF tag = 'TEMP' THEN
            temperature := value;
        ELSIF tag = 'PRESS' THEN
            pressure := value;
        ELSIF tag = 'FLOW' THEN
            flow_rate := value;
        END_IF;
    END_FOR;
END_IF;
END_PROGRAM
```

---

## 10. Complete Example: Input Validation

Validate operator inputs from HMI:

```iecst
PROGRAM POU_InputValidation
VAR
    ip_input : STRING;
    port_input : STRING;
    tag_input : STRING;
    ip_valid : BOOL;
    port_valid : BOOL;
    tag_valid : BOOL;
END_VAR

(* Validate IP address format *)
ip_valid := REGEX_MATCH(ip_input,
    '^([0-9]{1,3}\.){3}[0-9]{1,3}$');

(* Validate port number (1-65535) *)
port_valid := REGEX_MATCH(port_input, '^[0-9]+$')
    AND STRING_TO_INT(port_input) >= 1
    AND STRING_TO_INT(port_input) <= 65535;

(* Validate tag name (letters, numbers, underscores only) *)
tag_valid := REGEX_MATCH(tag_input, '^[A-Za-z_][A-Za-z0-9_]*$');

END_PROGRAM
```

---

## Appendix A: Quick Reference

All functions have `RE_*` aliases (e.g., `RE_MATCH` = `REGEX_MATCH`).

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `REGEX_MATCH(text, pattern)` | 2 | BOOL | Pattern matches? |
| `REGEX_FIND(text, pattern)` | 2 | STRING | First match |
| `REGEX_FIND_ALL(text, pattern [, limit])` | 2-3 | ARRAY | All matches |
| `REGEX_INDEX(text, pattern)` | 2 | INT | Start position (-1 if none) |
| `REGEX_INDICES(text, pattern)` | 2 | ARRAY | [start, end] of first match |
| `REGEX_COUNT(text, pattern)` | 2 | INT | Number of matches |
| `REGEX_GROUPS(text, pattern)` | 2 | ARRAY | Capture groups from first match |
| `REGEX_GROUPS_ALL(text, pattern)` | 2 | ARRAY | Capture groups from all matches |
| `REGEX_REPLACE(text, pattern, repl)` | 3 | STRING | Replace all matches |
| `REGEX_REPLACE_FIRST(text, pattern, repl)` | 3 | STRING | Replace first match |
| `REGEX_SPLIT(text, pattern [, limit])` | 2-3 | ARRAY | Split by pattern |
| `REGEX_ESCAPE(text)` | 1 | STRING | Escape special characters |
| `REGEX_VALID(pattern)` | 1 | BOOL | Check pattern syntax |

---

*GoPLC v1.0.535 | 13 Regex Functions (RE2 Engine) | Pattern Matching from ST*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
