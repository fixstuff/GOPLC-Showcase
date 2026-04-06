# GoPLC Data Structures Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 8 data structure types with ~160 functions for managing collections of data from Structured Text. All handle-based structures (everything except ARRAY) persist across scan cycles and are thread-safe.

| Type | Pattern | Access | Use Case |
|------|---------|--------|----------|
| **ARRAY** | Value-based | Indexed | Fixed data, math operations, sorting |
| **MAP** | Handle-based | Key-value | Lookups, configuration, named data |
| **LIST** | Handle-based | Indexed + linked | Dynamic lists, insertion/removal at any position |
| **QUEUE** | Handle-based | FIFO | Message buffers, work queues |
| **STACK** | Handle-based | LIFO | Undo history, depth-first traversal |
| **DEQUE** | Handle-based | Double-ended | Sliding windows, both-end access |
| **SET** | Handle-based | Unique members | Deduplication, membership tests, set math |
| **HEAP / PQUEUE** | Handle-based | Priority-ordered | Alarm ranking, task scheduling |

### Handle Pattern

Handle-based structures return a string handle on creation. Pass the handle to all subsequent operations:

```iecst
q := QUEUE_CREATE();              (* Returns "queue_1" *)
QUEUE_PUSH(q, 'message-1');
QUEUE_PUSH(q, 'message-2');
msg := QUEUE_POP(q);              (* Returns "message-1" *)
```

---

## 2. ARRAY — Indexed Collections

Arrays are value-based — operations return new arrays rather than modifying in place.

### Create

```iecst
arr := ARRAY_CREATE(10, 20, 30, 40, 50);
arr := ARRAY_OF(0, 10);              (* [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] — fill 10 elements with 0 *)
```

### Access

```iecst
val := ARRAY_GET(arr, 0);            (* First element *)
arr := ARRAY_SET(arr, 2, 99);        (* Set index 2 to 99 — returns new array *)
len := ARRAY_LENGTH(arr);            (* 5 *)
```

### Modify

```iecst
arr := ARRAY_APPEND(arr, 60);        (* Add to end *)
arr := ARRAY_INSERT(arr, 2, 25);     (* Insert at index 2 *)
arr := ARRAY_REMOVE(arr, 0);         (* Remove first element *)
arr := ARRAY_CONCAT(arr1, arr2);     (* Join two arrays *)
arr := ARRAY_SLICE(arr, 1, 3);       (* Elements [1..3) *)
```

### Search

```iecst
found := ARRAY_CONTAINS(arr, 30);    (* TRUE *)
idx := ARRAY_FIND(arr, 30);          (* Index of first match, -1 if not found *)
count := ARRAY_COUNT(arr, 30);       (* Number of occurrences *)
```

### Transform

```iecst
arr := ARRAY_SORT(arr);              (* Ascending *)
arr := ARRAY_SORT_DESC(arr);         (* Descending *)
arr := ARRAY_REVERSE(arr);
arr := ARRAY_UNIQUE(arr);            (* Remove duplicates *)
arr := ARRAY_FILL(arr, 0);           (* Set all elements to 0 *)
```

### Aggregate

```iecst
total := ARRAY_SUM(arr);
average := ARRAY_AVG(arr);
smallest := ARRAY_MIN(arr);
largest := ARRAY_MAX(arr);
```

### Functional

```iecst
(* Filter: keep elements matching condition *)
evens := ARRAY_FILTER(arr, 'x % 2 = 0');

(* Map: transform each element *)
doubled := ARRAY_MAP(arr, 'x * 2');

(* Reduce: accumulate to single value *)
sum := ARRAY_REDUCE(arr, 'acc + x', 0);

(* Any/All: test conditions *)
has_negative := ARRAY_ANY(arr, 'x < 0');
all_positive := ARRAY_ALL(arr, 'x > 0');
```

### Quick Reference (50 functions)

| Function | Returns | Description |
|----------|---------|-------------|
| `ARRAY_CREATE(vals...)` | ARRAY | Create from values |
| `ARRAY_OF(value, count)` | ARRAY | Create filled array |
| `ARRAY_GET(arr, index)` | ANY | Read element |
| `ARRAY_SET(arr, index, val)` | ARRAY | Update element (new array) |
| `ARRAY_LENGTH(arr)` | INT | Element count |
| `ARRAY_APPEND(arr, val)` | ARRAY | Add to end |
| `ARRAY_INSERT(arr, idx, val)` | ARRAY | Insert at position |
| `ARRAY_REMOVE(arr, idx)` | ARRAY | Remove by index |
| `ARRAY_REPLACE(arr, old, new)` | ARRAY | Replace value |
| `ARRAY_CONCAT(arr1, arr2)` | ARRAY | Join arrays |
| `ARRAY_SLICE(arr, start, end)` | ARRAY | Subarray |
| `ARRAY_CONTAINS(arr, val)` | BOOL | Membership test |
| `ARRAY_FIND(arr, val)` | INT | First index (-1 if missing) |
| `ARRAY_FIND_INDEX(arr, expr)` | INT | First matching index |
| `ARRAY_COUNT(arr, val)` | INT | Count occurrences |
| `ARRAY_COUNT_IF(arr, expr)` | INT | Count matching condition |
| `ARRAY_SORT(arr)` | ARRAY | Sort ascending |
| `ARRAY_SORT_DESC(arr)` | ARRAY | Sort descending |
| `ARRAY_REVERSE(arr)` | ARRAY | Reverse order |
| `ARRAY_UNIQUE(arr)` | ARRAY | Remove duplicates |
| `ARRAY_FILL(arr, val)` | ARRAY | Set all to value |
| `ARRAY_JOIN(arr, sep)` | STRING | Join as string |
| `ARRAY_COPY(arr)` | ARRAY | Deep copy |
| `ARRAY_SUM(arr)` | REAL | Sum all |
| `ARRAY_AVG(arr)` | REAL | Average |
| `ARRAY_MIN(arr)` | ANY | Minimum |
| `ARRAY_MAX(arr)` | ANY | Maximum |
| `ARRAY_FILTER(arr, expr)` | ARRAY | Keep matching |
| `ARRAY_MAP(arr, expr)` | ARRAY | Transform each |
| `ARRAY_REDUCE(arr, expr, init)` | ANY | Accumulate |
| `ARRAY_ANY(arr, expr)` | BOOL | Any match? |
| `ARRAY_ALL(arr, expr)` | BOOL | All match? |
| `ARRAY_TAKE(arr, n)` | ARRAY | First N elements |
| `ARRAY_DROP(arr, n)` | ARRAY | Skip first N |
| `ARRAY_PARTITION(arr, expr)` | ARRAY | Split by condition |
| `ARRAY_GROUP_BY(arr, expr)` | MAP | Group into map |
| `ARRAY_ZIP_WITH(a, b, expr)` | ARRAY | Combine two arrays |
| `INDEX_OF(arr, val)` | INT | Alias for ARRAY_FIND |

---

## 3. MAP — Key-Value Store

String-keyed dictionaries for named data.

```iecst
(* Create with initial data *)
config := MAP_CREATE('host', '10.0.0.50', 'port', 502, 'enabled', TRUE);

(* Or empty *)
m := MAP_CREATE();

(* Set and get *)
MAP_SET(m, 'temperature', 72.5);
MAP_SET(m, 'running', TRUE);
temp := MAP_GET(m, 'temperature');            (* 72.5 *)
val := MAP_GET(m, 'missing', 0.0);            (* Default: 0.0 *)

(* Check and remove *)
IF MAP_HAS(m, 'temperature') THEN
    MAP_DELETE(m, 'temperature');
END_IF;

(* Iterate *)
keys := MAP_KEYS(m);                          (* ["running"] *)
vals := MAP_VALUES(m);
entries := MAP_ENTRIES(m);                     (* [[key, val], ...] *)

(* Merge and build *)
MAP_MERGE(m, other_map);                      (* other overwrites on conflict *)
m := MAP_FROM_ARRAYS(key_array, val_array);
```

### Quick Reference (19 functions)

| Function | Returns | Description |
|----------|---------|-------------|
| `MAP_CREATE([k,v,...])` | STRING (handle) | Create map |
| `MAP_SET(h, key, val)` | BOOL | Set value |
| `MAP_GET(h, key [, default])` | ANY | Get value |
| `MAP_DELETE(h, key)` | BOOL | Remove key |
| `MAP_HAS(h, key)` | BOOL | Key exists? |
| `MAP_SIZE(h)` | INT | Key count |
| `MAP_KEYS(h)` | ARRAY | All keys |
| `MAP_VALUES(h)` | ARRAY | All values |
| `MAP_ENTRIES(h)` | ARRAY | Key-value pairs |
| `MAP_MERGE(h1, h2)` | BOOL | Merge (h2 overwrites) |
| `MAP_FROM_ARRAYS(keys, vals)` | STRING (handle) | Build from arrays |
| `MAP_CLEAR(h)` | BOOL | Remove all entries |
| `MAP_EMPTY(h)` | BOOL | Check if empty |

---

## 4. LIST — Dynamic Linked List

Random access plus efficient insertion/removal at any position.

```iecst
lst := LIST_CREATE(10, 20, 30);

(* Add *)
LIST_PUSH_BACK(lst, 40);
LIST_PUSH_FRONT(lst, 5);
LIST_INSERT(lst, 2, 15);

(* Access *)
first := LIST_FRONT(lst);
last := LIST_BACK(lst);
val := LIST_GET(lst, 3);

(* Remove *)
LIST_POP_FRONT(lst);
LIST_POP_BACK(lst);
LIST_REMOVE(lst, 1);
LIST_REMOVE_VALUE(lst, 20);

(* Transform *)
LIST_SORT(lst);
LIST_REVERSE(lst);
LIST_ROTATE_LEFT(lst, 2);
arr := LIST_TO_ARRAY(lst);
```

### Quick Reference (67 functions)

| Function | Returns | Description |
|----------|---------|-------------|
| `LIST_CREATE([vals...])` | STRING (handle) | Create list |
| `LIST_PUSH_FRONT(h, val)` | STRING | Add to front |
| `LIST_PUSH_BACK(h, val)` | STRING | Add to end |
| `LIST_POP_FRONT(h)` | ANY | Remove and return first |
| `LIST_POP_BACK(h)` | ANY | Remove and return last |
| `LIST_INSERT(h, idx, val)` | BOOL | Insert at position |
| `LIST_GET(h, idx)` | ANY | Read by index |
| `LIST_SET(h, idx, val)` | BOOL | Update by index |
| `LIST_REMOVE(h, idx)` | ANY | Remove by index |
| `LIST_REMOVE_VALUE(h, val)` | BOOL | Remove first occurrence |
| `LIST_REMOVE_ALL(h, val)` | BOOL | Remove all occurrences |
| `LIST_FRONT(h)` | ANY | Peek first |
| `LIST_BACK(h)` | ANY | Peek last |
| `LIST_SIZE(h)` | INT | Element count |
| `LIST_CONTAINS(h, val)` | BOOL | Membership test |
| `LIST_INDEX_OF(h, val)` | INT | First index |
| `LIST_SORT(h)` | STRING | Sort ascending |
| `LIST_SORT_DESC(h)` | STRING | Sort descending |
| `LIST_REVERSE(h)` | STRING | Reverse in place |
| `LIST_SLICE(h, start, end)` | STRING | Sub-list |
| `LIST_CONCAT(h1, h2)` | STRING | Join lists |
| `LIST_UNIQUE(h)` | STRING | Remove duplicates |
| `LIST_FLATTEN(h)` | STRING | Flatten nested |
| `LIST_ROTATE_LEFT(h, n)` | STRING | Rotate left |
| `LIST_ROTATE_RIGHT(h, n)` | STRING | Rotate right |
| `LIST_SWAP(h, i, j)` | BOOL | Swap elements |
| `LIST_ZIP(h1, h2)` | STRING | Pair elements |
| `LIST_FILL(h, val, count)` | STRING | Fill with value |
| `LIST_RANGE(start, end, step)` | STRING | Generate sequence |
| `LIST_CLEAR(h)` | BOOL | Remove all |
| `LIST_TO_ARRAY(h)` | ARRAY | Convert to array |

---

## 5. QUEUE — FIFO Buffer

First-in, first-out. Ideal for message buffers and work queues.

```iecst
q := QUEUE_CREATE();

QUEUE_PUSH(q, 'job-1');
QUEUE_PUSH(q, 'job-2');
QUEUE_PUSH(q, 'job-3');

next := QUEUE_PEEK(q);     (* "job-1" — peek without removing *)
job := QUEUE_POP(q);        (* "job-1" — removes from front *)
size := QUEUE_SIZE(q);      (* 2 *)
```

| Function | Returns | Description |
|----------|---------|-------------|
| `QUEUE_CREATE([vals...])` | STRING (handle) | Create queue |
| `QUEUE_PUSH(h, val)` | BOOL | Add to back |
| `QUEUE_POP(h)` | ANY | Remove from front |
| `QUEUE_PEEK(h)` | ANY | Peek front |
| `QUEUE_BACK(h)` | ANY | Peek back |
| `QUEUE_SIZE(h)` | INT | Element count |
| `QUEUE_EMPTY(h)` | BOOL | Check if empty |
| `QUEUE_CONTAINS(h, val)` | BOOL | Membership test |
| `QUEUE_CLEAR(h)` | BOOL | Remove all |
| `QUEUE_TO_ARRAY(h)` | ARRAY | Convert to array |

---

## 6. STACK — LIFO Buffer

Last-in, first-out. Ideal for undo history and recursive-like operations.

```iecst
s := STACK_CREATE();

STACK_PUSH(s, 'action-1');
STACK_PUSH(s, 'action-2');
STACK_PUSH(s, 'action-3');

top := STACK_PEEK(s);       (* "action-3" *)
undo := STACK_POP(s);       (* "action-3" — removes from top *)
```

| Function | Returns | Description |
|----------|---------|-------------|
| `STACK_CREATE([vals...])` | STRING (handle) | Create stack |
| `STACK_PUSH(h, val)` | BOOL | Push to top |
| `STACK_POP(h)` | ANY | Pop from top |
| `STACK_PEEK(h)` | ANY | Peek top |
| `STACK_BOTTOM(h)` | ANY | Peek bottom |
| `STACK_SIZE(h)` | INT | Element count |
| `STACK_EMPTY(h)` | BOOL | Check if empty |
| `STACK_CONTAINS(h, val)` | BOOL | Membership test |
| `STACK_REVERSE(h)` | BOOL | Reverse order |
| `STACK_CLEAR(h)` | BOOL | Remove all |
| `STACK_TO_ARRAY(h)` | ARRAY | Convert to array |

---

## 7. DEQUE — Double-Ended Queue

Push and pop from both ends.

```iecst
d := DEQUE_CREATE();

DEQUE_PUSH_FRONT(d, 'A');
DEQUE_PUSH_BACK(d, 'B');
DEQUE_PUSH_FRONT(d, 'C');
(* Contents: C, A, B *)

front := DEQUE_POP_FRONT(d);    (* "C" *)
back := DEQUE_POP_BACK(d);      (* "B" *)
```

| Function | Returns | Description |
|----------|---------|-------------|
| `DEQUE_CREATE()` | STRING (handle) | Create deque |
| `DEQUE_PUSH_FRONT(h, val)` | BOOL | Add to front |
| `DEQUE_PUSH_BACK(h, val)` | BOOL | Add to back |
| `DEQUE_POP_FRONT(h)` | ANY | Remove from front |
| `DEQUE_POP_BACK(h)` | ANY | Remove from back |
| `DEQUE_FRONT(h)` | ANY | Peek front |
| `DEQUE_BACK(h)` | ANY | Peek back |
| `DEQUE_SIZE(h)` | INT | Element count |
| `DEQUE_EMPTY(h)` | BOOL | Check if empty |

---

## 8. SET — Unique Collection

Stores unique values. Supports set algebra (union, intersection, difference).

```iecst
s := SET_CREATE('A', 'B', 'C');

SET_ADD(s, 'D');
SET_ADD(s, 'A');              (* No effect — already present *)
SET_REMOVE(s, 'B');

IF SET_CONTAINS(s, 'C') THEN
    (* ... *)
END_IF;

(* Set operations *)
s2 := SET_CREATE('C', 'D', 'E');
SET_UNION(s, s2);             (* s = {A, C, D, E} *)
SET_INTERSECTION(s, s2);      (* s = {C, D, E} *)
SET_DIFFERENCE(s, s2);        (* s = elements in s but not s2 *)

is_sub := SET_IS_SUBSET(s, s2);
```

| Function | Returns | Description |
|----------|---------|-------------|
| `SET_CREATE([vals...])` | STRING (handle) | Create set |
| `SET_ADD(h, val)` | BOOL | Add value |
| `SET_REMOVE(h, val)` | BOOL | Remove value |
| `SET_CONTAINS(h, val)` | BOOL | Membership test |
| `SET_SIZE(h)` | INT | Element count |
| `SET_UNION(h1, h2)` | INT | Union (modifies h1) |
| `SET_INTERSECTION(h1, h2)` | INT | Intersect (modifies h1) |
| `SET_DIFFERENCE(h1, h2)` | INT | Difference (modifies h1) |
| `SET_SYMMETRIC_DIFFERENCE(h1, h2)` | INT | XOR (modifies h1) |
| `SET_IS_SUBSET(h1, h2)` | BOOL | h1 subset of h2? |
| `SET_IS_SUPERSET(h1, h2)` | BOOL | h1 superset of h2? |
| `SET_EMPTY(h)` | BOOL | Check if empty |
| `SET_CLEAR(h)` | BOOL | Remove all |
| `SET_TO_ARRAY(h)` | ARRAY | Convert to array |

---

## 9. HEAP / PQUEUE — Priority Queue

Items are ordered by priority. Min-heap (default) returns lowest priority first; max-heap returns highest first.

```iecst
(* Min-heap: lowest priority comes out first *)
h := HEAP_CREATE();

HEAP_PUSH(h, 'low-alarm', 3.0);
HEAP_PUSH(h, 'critical', 1.0);
HEAP_PUSH(h, 'warning', 2.0);

next := HEAP_PEEK(h);        (* "critical" — priority 1.0 *)
pri := HEAP_PEEK_PRIORITY(h); (* 1.0 *)
item := HEAP_POP(h);          (* "critical" — removed *)

(* Max-heap: highest priority comes out first *)
mh := HEAP_CREATE_MAX();
HEAP_PUSH(mh, 'VIP', 100.0);
HEAP_PUSH(mh, 'normal', 10.0);
top := HEAP_POP(mh);          (* "VIP" *)

(* Top-N queries *)
top3 := HEAP_N_LARGEST(h, 3);
bottom3 := HEAP_N_SMALLEST(h, 3);

(* Update priority *)
HEAP_UPDATE_PRIORITY(h, 'warning', 0.5);   (* Promote to higher priority *)
```

PQUEUE functions are aliases with identical behavior (e.g., `PQUEUE_CREATE` = `HEAP_CREATE`, `PQUEUE_PUSH` = `HEAP_PUSH`).

| Function | Returns | Description |
|----------|---------|-------------|
| `HEAP_CREATE()` | STRING (handle) | Create min-heap |
| `HEAP_CREATE_MAX()` | STRING (handle) | Create max-heap |
| `HEAP_PUSH(h, val, priority)` | BOOL | Add with priority |
| `HEAP_POP(h)` | ANY | Remove highest-priority item |
| `HEAP_PEEK(h)` | ANY | Peek highest-priority item |
| `HEAP_PEEK_PRIORITY(h)` | REAL | Peek its priority value |
| `HEAP_UPDATE_PRIORITY(h, val, pri)` | BOOL | Change priority |
| `HEAP_SIZE(h)` | INT | Element count |
| `HEAP_CONTAINS(h, val)` | BOOL | Membership test |
| `HEAP_N_SMALLEST(h, n)` | ARRAY | N lowest-priority items |
| `HEAP_N_LARGEST(h, n)` | ARRAY | N highest-priority items |
| `HEAP_MERGE(h1, h2)` | BOOL | Merge heaps |
| `HEAP_FROM_ARRAY(arr)` | STRING (handle) | Build from array |
| `HEAP_EMPTY(h)` | BOOL | Check if empty |
| `HEAP_CLEAR(h)` | BOOL | Remove all |
| `HEAP_TO_ARRAY(h)` | ARRAY | Convert to array |

---

## 10. Complete Example: Alarm Priority System

```iecst
PROGRAM POU_AlarmManager
VAR
    alarms : STRING;          (* HEAP handle *)
    active_set : STRING;      (* SET handle — track active alarm IDs *)
    history : STRING;         (* QUEUE handle — last 50 acknowledged *)
    initialized : BOOL := FALSE;

    (* Inputs *)
    high_temp : BOOL;
    low_pressure : BOOL;
    door_open : BOOL;
END_VAR

IF NOT initialized THEN
    alarms := HEAP_CREATE();              (* Min-heap: priority 1 = most critical *)
    active_set := SET_CREATE();
    history := QUEUE_CREATE();
    initialized := TRUE;
END_IF;

(* Raise alarms on conditions *)
IF high_temp AND NOT SET_CONTAINS(active_set, 'HIGH_TEMP') THEN
    HEAP_PUSH(alarms, 'HIGH_TEMP', 1.0);     (* Critical *)
    SET_ADD(active_set, 'HIGH_TEMP');
END_IF;

IF low_pressure AND NOT SET_CONTAINS(active_set, 'LOW_PRESS') THEN
    HEAP_PUSH(alarms, 'LOW_PRESS', 2.0);     (* Warning *)
    SET_ADD(active_set, 'LOW_PRESS');
END_IF;

IF door_open AND NOT SET_CONTAINS(active_set, 'DOOR_OPEN') THEN
    HEAP_PUSH(alarms, 'DOOR_OPEN', 3.0);     (* Advisory *)
    SET_ADD(active_set, 'DOOR_OPEN');
END_IF;

(* Most critical alarm is always at the top *)
IF NOT HEAP_EMPTY(alarms) THEN
    top_alarm := HEAP_PEEK(alarms);
    top_priority := HEAP_PEEK_PRIORITY(alarms);
END_IF;

(* Acknowledge: move to history queue *)
IF ack_requested AND NOT HEAP_EMPTY(alarms) THEN
    acked := HEAP_POP(alarms);
    SET_REMOVE(active_set, acked);
    QUEUE_PUSH(history, acked);

    (* Keep history at 50 max *)
    IF QUEUE_SIZE(history) > 50 THEN
        QUEUE_POP(history);
    END_IF;
END_IF;

END_PROGRAM
```

---

*GoPLC v1.0.535 | ~160 Data Structure Functions | ARRAY, MAP, LIST, QUEUE, STACK, DEQUE, SET, HEAP/PQUEUE*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
