# GoPLC BACnet Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements a complete **BACnet/IP** stack — both client and server — callable directly from IEC 61131-3 Structured Text. No external BACnet libraries, no EDE files, no vendor configuration tools. You create connections, read/write BACnet objects, subscribe to change-of-value (COV) notifications, and expose points to BMS systems with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `BACNET_CLIENT_CREATE` / `BACNET_READ_*` / `BACNET_WRITE_*` / `BACNET_SUBSCRIBE_COV` | Poll and command BACnet devices: AHUs, VAVs, chillers, meters, other controllers |
| **Server** | `BACNET_SERVER_CREATE` / `BACNET_SERVER_SET_*` / `BACNET_SERVER_GET_*` | Expose GoPLC data to BMS front-ends, operator workstations, or third-party controllers |

Both roles can run simultaneously. A single GoPLC instance can poll a dozen VAV controllers as a client while serving zone data to a Tridium Niagara front-end — all from the same ST program.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                  │
│                                                              │
│  ┌────────────────────────────┐  ┌────────────────────────┐  │
│  │ ST Program (Client)        │  │ ST Program (Server)    │  │
│  │                            │  │                        │  │
│  │ BACNET_CLIENT_CREATE()       │  │ BACNET_SERVER_CREATE()   │  │
│  │ BACNET_CLIENT_CONNECT()      │  │ BACNET_SERVER_START()    │  │
│  │ BACNET_READ_PRESENT_VALUE()   │  │ BACNET_SERVER_SET_AI()    │  │
│  │ BACNET_WRITE_PRIORITY()      │  │ BACNET_SERVER_SET_AV()    │  │
│  │ BACNET_SUBSCRIBE_COV()       │  │ BACNET_SERVER_GET_AO()    │  │
│  │ BACNET_WHO_IS()              │  │                        │  │
│  └──────────────┬─────────────┘  └──────────┬─────────────┘  │
│                 │                            │                │
│                 │  BACnet/IP Client          │  BACnet/IP     │
│                 │  (sends requests)          │  Server        │
│                 │                            │  (listens)     │
└─────────────────┼────────────────────────────┼────────────────┘
                  │                            │
                  │  UDP/IP                     │  UDP/IP
                  │  (Port 47808 default)       │  (Port 47808)
                  ▼                            ▼
┌──────────────────────────────┐   ┌────────────────────────────────┐
│  Remote BACnet Device        │   │  Remote BACnet Client          │
│                              │   │                                │
│  AHU, VAV, Chiller,         │   │  Niagara, Metasys, WebCTRL,   │
│  Boiler, Power Meter,       │   │  SkySpark, Node-RED,          │
│  Lighting Controller         │   │  Another BACnet Controller     │
└──────────────────────────────┘   └────────────────────────────────┘
```

### BACnet Object Model

BACnet organizes all data into typed objects, each with a set of properties. The most commonly used objects in HVAC/BMS applications:

| Object Type | Constant | Typical Use |
|-------------|----------|-------------|
| **Analog Input** | `BACNET_OBJECT_AI` | Sensor readings: temperature, pressure, humidity, flow |
| **Analog Output** | `BACNET_OBJECT_AO` | Control outputs: valve position, damper command, VFD speed |
| **Analog Value** | `BACNET_OBJECT_AV` | Setpoints, tuning parameters, calculated values |
| **Binary Input** | `BACNET_OBJECT_BI` | Status signals: fan running, filter alarm, occupancy |
| **Binary Output** | `BACNET_OBJECT_BO` | On/off commands: fan start, pump enable, lighting relay |
| **Binary Value** | `BACNET_OBJECT_BV` | Mode flags: occupied/unoccupied, auto/manual, enable/disable |
| **Multi-State Input** | `BACNET_OBJECT_MSI` | Enumerated status: operating mode, fault code |
| **Multi-State Output** | `BACNET_OBJECT_MSO` | Enumerated commands: speed stage, mode select |
| **Multi-State Value** | `BACNET_OBJECT_MSV` | Enumerated setpoints: schedule mode, season |

### BACnet Property Constants

Every BACnet object has properties. GoPLC provides constants for the most commonly accessed ones:

| Constant | Description |
|----------|-------------|
| `BACNET_PROP_PRESENT_VALUE` | Current value of the object — the most-read property |
| `BACNET_PROP_OBJECT_NAME` | Human-readable name string |
| `BACNET_PROP_DESCRIPTION` | Free-text description |
| `BACNET_PROP_UNITS` | Engineering units (degrees-F, PSI, CFM, etc.) |
| `BACNET_PROP_PRIORITY_ARRAY` | 16-level command priority array (outputs only) |
| `BACNET_PROP_RELINQUISH_DEFAULT` | Value used when all priority slots are NULL |

> **Priority Array:** BACnet outputs (AO, BO, MSO) use a 16-level priority scheme. Priority 1 is highest (life safety), priority 16 is lowest (default). When you write to an output, you specify which priority slot to claim. The device uses the highest-priority non-NULL value. This prevents a scheduling override from fighting a life-safety shutdown.

---

## 2. Client Functions

The BACnet client connects to remote BACnet/IP devices and performs read/write/subscribe operations using standard BACnet services.

### 2.1 Connection Management

#### BACNET_CLIENT_CREATE — Create Named Connection

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Unique connection name |
| `targetIP` | STRING | Yes | IP address of the BACnet device |
| `deviceID` | INT | Yes | BACnet device instance number |
| `localPort` | INT | No | Local UDP port (default 47808) |
| `targetPort` | INT | No | Target UDP port (default 47808) |

Returns: `BOOL` — TRUE if the connection was created successfully.

```iecst
(* Connect to an AHU controller at 10.0.1.100, device ID 1001 *)
ok := BACNET_CLIENT_CREATE('ahu1', '10.0.1.100', 1001);

(* Connect to a device on a non-standard port *)
ok := BACNET_CLIENT_CREATE('vav3', '10.0.1.50', 3050, 47808, 47809);
```

> **Named connections:** Every BACnet client connection has a unique string name. This name is used in all subsequent calls. Create one connection per BACnet device — GoPLC manages the UDP sockets internally.

#### BACNET_CLIENT_CONNECT — Establish Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from BACNET_CLIENT_CREATE |

Returns: `BOOL` — TRUE if connected successfully.

```iecst
ok := BACNET_CLIENT_CONNECT('ahu1');
```

#### BACNET_CLIENT_DISCONNECT — Close Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully.

```iecst
ok := BACNET_CLIENT_DISCONNECT('ahu1');
```

#### BACNET_CLIENT_IS_CONNECTED — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the connection is active.

```iecst
IF NOT BACNET_CLIENT_IS_CONNECTED('ahu1') THEN
    BACNET_CLIENT_CONNECT('ahu1');
END_IF;
```

#### BACNET_CLIENT_DELETE — Remove Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if deleted successfully.

```iecst
ok := BACNET_CLIENT_DELETE('ahu1');
```

#### BACNET_CLIENT_LIST — List All Connections

Returns: `[]STRING` — Array of connection names.

```iecst
clients := BACNET_CLIENT_LIST();
(* Returns: ['ahu1', 'vav3', 'chiller1'] *)
```

#### Example: Connection Lifecycle

```iecst
PROGRAM POU_BACnetInit
VAR
    state : INT := 0;
    ok : BOOL;
END_VAR

CASE state OF
    0: (* Create connection *)
        ok := BACNET_CLIENT_CREATE('ahu1', '10.0.1.100', 1001);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := BACNET_CLIENT_CONNECT('ahu1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT BACNET_CLIENT_IS_CONNECTED('ahu1') THEN
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.2 Generic Read/Write

These functions work with any BACnet object type and property. Use the object type and property constants for clarity.

#### BACNET_READ_PROPERTY — Read Any Property

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `property` | INT | BACnet property constant |

Returns: `ANY` — Value type depends on the property.

```iecst
(* Read the present value of Analog Input 1 *)
temp := BACNET_READ_PROPERTY('ahu1',
    BACNET_OBJECT_AI, 1,
    BACNET_PROP_PRESENT_VALUE);
(* Returns: 72.5 *)

(* Read the object name *)
name := BACNET_READ_PROPERTY('ahu1',
    BACNET_OBJECT_AI, 1,
    BACNET_PROP_OBJECT_NAME);
(* Returns: 'ZN-T' *)

(* Read the engineering units *)
units := BACNET_READ_PROPERTY('ahu1',
    BACNET_OBJECT_AI, 1,
    BACNET_PROP_UNITS);
(* Returns: 64  (degrees-Fahrenheit) *)

(* Read the priority array of an Analog Output *)
priorities := BACNET_READ_PROPERTY('ahu1',
    BACNET_OBJECT_AO, 1,
    BACNET_PROP_PRIORITY_ARRAY);
(* Returns: [NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,72.0,NULL,NULL,NULL,NULL,NULL,NULL,NULL] *)
```

#### BACNET_WRITE_PROPERTY — Write Any Property

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `property` | INT | BACnet property constant |
| `value` | ANY | Value to write |

Returns: `BOOL` — TRUE if the write was acknowledged.

```iecst
(* Write a description *)
ok := BACNET_WRITE_PROPERTY('ahu1',
    BACNET_OBJECT_AV, 5,
    BACNET_PROP_DESCRIPTION, 'Cooling setpoint offset');
```

> **Present Value Writes:** For writing present values to outputs with priority, use `BACNET_WRITE_PRIORITY` instead. Direct writes to PresentValue via `BACNET_WRITE_PROPERTY` go to priority 16 (lowest) and may be overridden by higher-priority commands.

#### BACNET_READ_PRESENT_VALUE — Read Present Value (Shorthand)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |

Returns: `ANY` — Current present value of the object.

```iecst
(* These two calls are equivalent *)
temp := BACNET_READ_PRESENT_VALUE('ahu1', BACNET_OBJECT_AI, 1);
temp := BACNET_READ_PROPERTY('ahu1', BACNET_OBJECT_AI, 1, BACNET_PROP_PRESENT_VALUE);
```

#### BACNET_WRITE_PRESENT_VALUE — Write Present Value (Shorthand)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `value` | ANY | Value to write |

Returns: `BOOL` — TRUE if acknowledged.

```iecst
ok := BACNET_WRITE_PRESENT_VALUE('ahu1', BACNET_OBJECT_AV, 5, 72.0);
```

---

### 2.3 Priority Array and Relinquish

BACnet output objects (AO, BO, BV, AV when commandable, MSO, MSV when commandable) support a 16-level priority array. This is fundamental to BMS control — it prevents conflicts between life safety, manual overrides, scheduled operations, and default programming.

#### BACnet Priority Levels (ASHRAE 135)

| Priority | Level | Typical Use |
|----------|-------|-------------|
| 1 | Manual-Life Safety | Fire alarm shutdown |
| 2 | Automatic-Life Safety | Smoke control sequences |
| 3 | Available | — |
| 4 | Available | — |
| 5 | Critical Equipment Control | Chiller staging |
| 6 | Minimum On/Off | Freeze protection |
| 7 | Available | — |
| 8 | Manual Operator | Operator overrides from workstation |
| 9 | Available | — |
| 10 | Available | — |
| 11 | Available | — |
| 12 | Available | — |
| 13 | Available | — |
| 14 | Available | — |
| 15 | Available | — |
| 16 | Available (Lowest) | Default / scheduling |

#### BACNET_WRITE_PRIORITY — Write at Specific Priority

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `value` | ANY | Value to write |
| `priority` | INT | Priority level (1-16) |

Returns: `BOOL` — TRUE if acknowledged.

```iecst
(* Write cooling valve to 75% at priority 8 (operator override) *)
ok := BACNET_WRITE_PRIORITY('ahu1',
    BACNET_OBJECT_AO, 1,
    75.0, 8);

(* Write fan command ON at priority 5 (critical equipment) *)
ok := BACNET_WRITE_PRIORITY('ahu1',
    BACNET_OBJECT_BO, 1,
    TRUE, 5);

(* Write occupied cooling setpoint at priority 16 (scheduling) *)
ok := BACNET_WRITE_PRIORITY('ahu1',
    BACNET_OBJECT_AV, 10,
    72.0, 16);
```

#### BACNET_RELINQUISH — Release a Priority Slot

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `priority` | INT | Priority level to release (1-16) |

Returns: `BOOL` — TRUE if acknowledged.

When you relinquish a priority slot, it becomes NULL. The device then uses the next highest-priority non-NULL value, or the relinquish default if all slots are NULL.

```iecst
(* Release the operator override — control returns to scheduling *)
ok := BACNET_RELINQUISH('ahu1',
    BACNET_OBJECT_AO, 1,
    8);
```

#### Example: Override with Automatic Release

```iecst
PROGRAM POU_OverrideControl
VAR
    override_active : BOOL := FALSE;
    override_timer : INT := 0;
    override_duration : INT := 600;  (* 60 seconds at 100ms scan *)
    ok : BOOL;
END_VAR

IF override_active THEN
    override_timer := override_timer + 1;

    IF override_timer >= override_duration THEN
        (* Time expired — relinquish override *)
        ok := BACNET_RELINQUISH('ahu1',
            BACNET_OBJECT_AO, 1, 8);
        override_active := FALSE;
        override_timer := 0;
    END_IF;
ELSE
    (* Normal operation — write at priority 16 *)
    ok := BACNET_WRITE_PRIORITY('ahu1',
        BACNET_OBJECT_AO, 1,
        pid_output, 16);
END_IF;
END_PROGRAM
```

---

### 2.4 Typed Convenience Functions

These wrap `BACNET_READ_PRESENT_VALUE` / `BACNET_WRITE_PRESENT_VALUE` for the six most common object types. They return properly typed values and require only the connection name and instance number — the object type is implied by the function name.

#### Analog Reads

| Function | Object Type | Returns |
|----------|-------------|---------|
| `BACNET_READ_AI(name, instance)` | Analog Input | `REAL` |
| `BACNET_READ_AO(name, instance)` | Analog Output | `REAL` |
| `BACNET_READ_AV(name, instance)` | Analog Value | `REAL` |

```iecst
(* Read zone temperature from AI-1 *)
zone_temp := BACNET_READ_AI('vav3', 1);

(* Read current damper position from AO-1 *)
damper_pos := BACNET_READ_AO('vav3', 1);

(* Read cooling setpoint from AV-10 *)
clg_sp := BACNET_READ_AV('vav3', 10);
```

#### Binary Reads

| Function | Object Type | Returns |
|----------|-------------|---------|
| `BACNET_READ_BI(name, instance)` | Binary Input | `BOOL` |
| `BACNET_READ_BO(name, instance)` | Binary Output | `BOOL` |
| `BACNET_READ_BV(name, instance)` | Binary Value | `BOOL` |

```iecst
(* Read fan status from BI-1 *)
fan_running := BACNET_READ_BI('ahu1', 1);

(* Read fan command from BO-1 *)
fan_cmd := BACNET_READ_BO('ahu1', 1);

(* Read occupancy mode from BV-5 *)
occupied := BACNET_READ_BV('ahu1', 5);
```

#### Analog Writes

| Function | Object Type | Param | Returns |
|----------|-------------|-------|---------|
| `BACNET_WRITE_AO(name, instance, value)` | Analog Output | `REAL` | `BOOL` |
| `BACNET_WRITE_AV(name, instance, value)` | Analog Value | `REAL` | `BOOL` |

```iecst
(* Command damper to 50% *)
ok := BACNET_WRITE_AO('vav3', 1, 50.0);

(* Write cooling setpoint *)
ok := BACNET_WRITE_AV('vav3', 10, 74.0);
```

#### Binary Writes

| Function | Object Type | Param | Returns |
|----------|-------------|-------|---------|
| `BACNET_WRITE_BO(name, instance, value)` | Binary Output | `BOOL` | `BOOL` |
| `BACNET_WRITE_BV(name, instance, value)` | Binary Value | `BOOL` | `BOOL` |

```iecst
(* Start supply fan *)
ok := BACNET_WRITE_BO('ahu1', 1, TRUE);

(* Set occupied mode *)
ok := BACNET_WRITE_BV('ahu1', 5, TRUE);
```

> **No Write for AI/BI:** Analog Inputs and Binary Inputs are read-only by definition. There is no `BACNET_WRITE_AI` or `BACNET_WRITE_BI`. If you need a writable analog point, use Analog Value (AV). If you need a writable binary point, use Binary Value (BV).

---

### 2.5 Device Discovery (WhoIs)

BACnet provides a broadcast discovery mechanism. `WhoIs` sends a broadcast (or directed) request, and all BACnet devices in the specified range respond with their device instance, IP address, and other identifying information.

#### BACNET_WHO_IS — Discover Devices

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Connection name (uses its UDP socket) |
| `lowLimit` | INT | No | Lowest device instance to find |
| `highLimit` | INT | No | Highest device instance to find |

Returns: `[]MAP` — Array of device descriptors.

```iecst
(* Discover ALL BACnet devices on the network *)
devices := BACNET_WHO_IS('ahu1');
(* Returns:
   [
     {"device_id": 1001, "ip": "10.0.1.100", "vendor": "Trane"},
     {"device_id": 1002, "ip": "10.0.1.101", "vendor": "Trane"},
     {"device_id": 3050, "ip": "10.0.1.50",  "vendor": "Distech"}
   ]
*)

(* Discover devices in a specific range *)
devices := BACNET_WHO_IS('ahu1', 1000, 1099);
(* Returns only devices with instance 1000-1099 *)

(* Find a single device *)
devices := BACNET_WHO_IS('ahu1', 1001, 1001);
```

> **Network Broadcast:** `WhoIs` uses UDP broadcast. All devices on the local subnet will respond. For routed BACnet networks (BACnet/IP to MS/TP), devices behind BACnet routers will also respond if the router forwards the broadcast. Response time varies — allow 2-5 seconds for all devices to reply, especially with MS/TP segments.

#### Example: Auto-Discovery and Inventory

```iecst
PROGRAM POU_Discovery
VAR
    state : INT := 0;
    devices : ARRAY[0..99] OF MAP;
    device_count : INT;
    ok : BOOL;
    i : INT;
END_VAR

CASE state OF
    0: (* Create a temporary connection for discovery *)
        ok := BACNET_CLIENT_CREATE('scanner', '255.255.255.255', 0);
        IF ok THEN
            ok := BACNET_CLIENT_CONNECT('scanner');
            state := 1;
        END_IF;

    1: (* Send WhoIs broadcast *)
        devices := BACNET_WHO_IS('scanner');
        device_count := LEN(devices);
        state := 2;

    2: (* Log discovered devices *)
        FOR i := 0 TO device_count - 1 DO
            LOG(CONCAT('Found device ', INT_TO_STRING(devices[i].device_id),
                       ' at ', devices[i].ip));
        END_FOR;
        state := 10;

    10: (* Done *)
        BACNET_CLIENT_DELETE('scanner');
END_CASE;
END_PROGRAM
```

---

### 2.6 Change of Value (COV) Subscriptions

Instead of polling, COV lets you subscribe to a BACnet object and receive asynchronous notifications when its value changes. This reduces network traffic and provides near-instant updates for critical points.

#### BACNET_SUBSCRIBE_COV — Create Subscription

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `lifetime` | INT | Subscription lifetime in seconds (0 = indefinite) |

Returns: `INT` — Subscription ID (used for unsubscribe), or -1 on failure.

```iecst
(* Subscribe to zone temperature changes — 1 hour lifetime *)
sub_id := BACNET_SUBSCRIBE_COV('vav3',
    BACNET_OBJECT_AI, 1,
    3600);

(* Subscribe indefinitely to fan status *)
sub_id2 := BACNET_SUBSCRIBE_COV('ahu1',
    BACNET_OBJECT_BI, 1,
    0);
```

> **COV Increment:** The remote device determines when to send notifications based on its configured COV increment. For analog objects, this is typically 0.1-1.0 units. For binary objects, any state change triggers a notification. The notification updates the cached present value, which you read with `BACNET_READ_PRESENT_VALUE` or the typed convenience functions.

> **Lifetime Management:** When the lifetime expires, the subscription ends silently. Set lifetime to 0 for indefinite subscriptions, or re-subscribe periodically. Some devices limit the number of active COV subscriptions (typically 16-64). Use COV for critical points and poll the rest.

#### BACNET_UNSUBSCRIBE_COV — Cancel Subscription

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `subscriptionID` | INT | Subscription ID from BACNET_SUBSCRIBE_COV |

Returns: `BOOL` — TRUE if unsubscribed successfully.

```iecst
ok := BACNET_UNSUBSCRIBE_COV('vav3', sub_id);
```

#### Example: COV-Driven Zone Monitoring

```iecst
PROGRAM POU_COVMonitor
VAR
    state : INT := 0;
    sub_temp : INT;
    sub_fan : INT;
    zone_temp : REAL;
    fan_status : BOOL;
    alarm_active : BOOL := FALSE;
    high_temp_limit : REAL := 85.0;
END_VAR

CASE state OF
    0: (* Subscribe to critical points *)
        sub_temp := BACNET_SUBSCRIBE_COV('ahu1',
            BACNET_OBJECT_AI, 1, 0);
        sub_fan := BACNET_SUBSCRIBE_COV('ahu1',
            BACNET_OBJECT_BI, 1, 0);
        IF sub_temp >= 0 AND sub_fan >= 0 THEN
            state := 10;
        END_IF;

    10: (* Monitor — values update automatically via COV *)
        zone_temp := BACNET_READ_AI('ahu1', 1);
        fan_status := BACNET_READ_BI('ahu1', 1);

        (* High temperature alarm *)
        IF zone_temp > high_temp_limit AND NOT fan_status THEN
            alarm_active := TRUE;
            (* Force fan ON at high priority *)
            BACNET_WRITE_PRIORITY('ahu1',
                BACNET_OBJECT_BO, 1,
                TRUE, 5);
        ELSIF zone_temp < (high_temp_limit - 2.0) THEN
            IF alarm_active THEN
                BACNET_RELINQUISH('ahu1',
                    BACNET_OBJECT_BO, 1, 5);
                alarm_active := FALSE;
            END_IF;
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.7 Alarms and Statistics

#### BACNET_GET_ALARMS — Read Active Alarms

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `[]MAP` — Array of active alarm entries from the device.

```iecst
alarms := BACNET_GET_ALARMS('ahu1');
(* Returns:
   [
     {"object_type": 0, "instance": 3, "state": "high-limit",
      "value": 87.2, "timestamp": "2026-04-03T14:22:00Z"},
     {"object_type": 4, "instance": 1, "state": "offnormal",
      "value": 0, "timestamp": "2026-04-03T14:20:15Z"}
   ]
*)
```

#### BACNET_GET_STATS — Connection Statistics

Returns: `MAP` — Statistics for the BACnet stack.

```iecst
stats := BACNET_GET_STATS();
(* Returns:
   {
     "requests_sent": 12450,
     "responses_received": 12448,
     "timeouts": 2,
     "cov_notifications": 873,
     "errors": 0,
     "uptime_seconds": 86400
   }
*)
```

---

## 3. Server Functions

The BACnet server exposes GoPLC data as standard BACnet objects. Any BMS front-end, operator workstation, or third-party controller that speaks BACnet/IP can read and write these points without any custom integration.

### 3.1 Server Lifecycle

#### BACNET_SERVER_CREATE — Create Server Instance

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique server name |
| `port` | INT | UDP listen port (typically 47808) |
| `device_id` | INT | BACnet device instance to advertise |

Returns: `BOOL` — TRUE if created successfully.

```iecst
(* Create a BACnet server — device ID 99001 *)
ok := BACNET_SERVER_CREATE('bms_server', 47808, 99001);
```

> **Device ID:** Every BACnet device on the network must have a unique device instance number. Coordinate with the BMS integrator to avoid conflicts. Common convention: 99xxx for soft controllers, leaving lower ranges for hardware controllers.

#### BACNET_SERVER_START — Begin Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if started.

```iecst
ok := BACNET_SERVER_START('bms_server');
```

#### BACNET_SERVER_STOP — Stop Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if stopped.

```iecst
ok := BACNET_SERVER_STOP('bms_server');
```

#### BACNET_SERVER_IS_RUNNING — Check Server State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server is actively listening.

```iecst
IF NOT BACNET_SERVER_IS_RUNNING('bms_server') THEN
    BACNET_SERVER_START('bms_server');
END_IF;
```

#### BACNET_SERVER_DELETE — Remove Server

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if deleted.

```iecst
ok := BACNET_SERVER_DELETE('bms_server');
```

#### BACNET_SERVER_LIST — List All Servers

Returns: `[]STRING` — Array of server names.

```iecst
servers := BACNET_SERVER_LIST();
```

---

### 3.2 Setting Server Point Values

Use these to push GoPLC data into server objects. Remote BACnet clients will read these values.

#### BACNET_SERVER_SET_AI — Set Analog Input Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |
| `value` | REAL | Analog value |

Returns: `BOOL` — TRUE if set.

```iecst
(* Expose zone temperature as AI-1 *)
ok := BACNET_SERVER_SET_AI('bms_server', 1, zone_temp);

(* Expose discharge air temperature as AI-2 *)
ok := BACNET_SERVER_SET_AI('bms_server', 2, dat);
```

#### BACNET_SERVER_SET_BI — Set Binary Input Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |
| `value` | BOOL | Binary value |

Returns: `BOOL` — TRUE if set.

```iecst
(* Expose fan status as BI-1 *)
ok := BACNET_SERVER_SET_BI('bms_server', 1, fan_running);
```

#### BACNET_SERVER_SET_AV — Set Analog Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |
| `value` | REAL | Analog value |

Returns: `BOOL` — TRUE if set.

```iecst
(* Expose PID output as AV-1 *)
ok := BACNET_SERVER_SET_AV('bms_server', 1, pid_output);
```

---

### 3.3 Reading Commanded Values

When a remote BACnet client writes to your server's output objects, use these to read the commanded values.

#### BACNET_SERVER_GET_AV — Read Analog Value (Written by Remote)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |

Returns: `REAL` — Current value.

```iecst
(* Read setpoint written by the BMS front-end *)
remote_setpoint := BACNET_SERVER_GET_AV('bms_server', 10);
```

#### BACNET_SERVER_GET_AO — Read Analog Output (Written by Remote)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |

Returns: `REAL` — Current value.

```iecst
(* Read command from BMS *)
valve_cmd := BACNET_SERVER_GET_AO('bms_server', 1);
```

#### BACNET_SERVER_GET_BO — Read Binary Output (Written by Remote)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |

Returns: `BOOL` — Current value.

```iecst
(* Read fan command from BMS *)
fan_cmd_from_bms := BACNET_SERVER_GET_BO('bms_server', 1);
```

---

### 3.4 Example: Full Server Setup

```iecst
PROGRAM POU_BACnetServer
VAR
    state : INT := 0;
    ok : BOOL;
    zone_temp : REAL;
    dat : REAL;
    fan_running : BOOL;
    pid_output : REAL;
    remote_sp : REAL;
    fan_cmd : BOOL;
END_VAR

CASE state OF
    0: (* Create and start server *)
        ok := BACNET_SERVER_CREATE('bms', 47808, 99001);
        IF ok THEN
            BACNET_SERVER_START('bms');
            state := 10;
        END_IF;

    10: (* Running — update exposed points every scan *)
        (* Push sensor data to BACnet objects *)
        BACNET_SERVER_SET_AI('bms', 1, zone_temp);     (* AI-1: Zone Temp *)
        BACNET_SERVER_SET_AI('bms', 2, dat);            (* AI-2: Discharge Air Temp *)
        BACNET_SERVER_SET_BI('bms', 1, fan_running);    (* BI-1: Fan Status *)
        BACNET_SERVER_SET_AV('bms', 1, pid_output);     (* AV-1: PID Output *)

        (* Read commands written by BMS front-end *)
        remote_sp := BACNET_SERVER_GET_AV('bms', 10);   (* AV-10: Remote Setpoint *)
        fan_cmd := BACNET_SERVER_GET_BO('bms', 1);       (* BO-1: Fan Command *)
END_CASE;
END_PROGRAM
```

---

## 4. Application Examples

### 4.1 VAV Box Controller

A complete VAV box integration — reading sensors, commanding dampers, and monitoring alarms across multiple controllers.

```iecst
PROGRAM POU_VAVControl
VAR
    state : INT := 0;
    ok : BOOL;

    (* VAV box data *)
    zone_temp : REAL;
    zone_sp : REAL;
    damper_pos : REAL;
    airflow : REAL;
    reheat_cmd : REAL;
    occ_mode : BOOL;

    (* Control *)
    damper_cmd : REAL;
    min_flow : REAL := 20.0;   (* % minimum airflow *)
    max_flow : REAL := 100.0;  (* % maximum airflow *)
END_VAR

CASE state OF
    0: (* Initialize *)
        ok := BACNET_CLIENT_CREATE('vav_b1', '10.0.1.110', 2001);
        IF ok THEN
            ok := BACNET_CLIENT_CONNECT('vav_b1');
            IF ok THEN state := 10; END_IF;
        END_IF;

    10: (* Read current status *)
        zone_temp := BACNET_READ_AI('vav_b1', 1);     (* Zone temp *)
        zone_sp := BACNET_READ_AV('vav_b1', 1);       (* Zone setpoint *)
        damper_pos := BACNET_READ_AO('vav_b1', 1);     (* Damper feedback *)
        airflow := BACNET_READ_AI('vav_b1', 2);        (* CFM *)
        occ_mode := BACNET_READ_BV('vav_b1', 1);       (* Occupied mode *)

        (* Simple proportional damper control *)
        IF occ_mode THEN
            damper_cmd := (zone_temp - zone_sp) * 10.0;  (* P-only *)
            IF damper_cmd < min_flow THEN damper_cmd := min_flow; END_IF;
            IF damper_cmd > max_flow THEN damper_cmd := max_flow; END_IF;
        ELSE
            damper_cmd := min_flow;  (* Minimum flow when unoccupied *)
        END_IF;

        (* Write damper command at priority 8 *)
        ok := BACNET_WRITE_PRIORITY('vav_b1',
            BACNET_OBJECT_AO, 1,
            damper_cmd, 8);

        (* Reconnect if lost *)
        IF NOT BACNET_CLIENT_IS_CONNECTED('vav_b1') THEN
            state := 0;
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 4.2 Chiller Plant Staging with COV

Use COV subscriptions to react instantly to chiller status changes without continuous polling.

```iecst
PROGRAM POU_ChillerPlant
VAR
    state : INT := 0;
    ok : BOOL;

    (* Subscriptions *)
    sub_ch1_status : INT;
    sub_ch2_status : INT;
    sub_load : INT;

    (* Plant data *)
    ch1_running : BOOL;
    ch2_running : BOOL;
    plant_load : REAL;
    stage_up_sp : REAL := 85.0;    (* % load to stage up *)
    stage_down_sp : REAL := 30.0;  (* % load to stage down *)
END_VAR

CASE state OF
    0: (* Initialize connections *)
        ok := BACNET_CLIENT_CREATE('ch1', '10.0.2.10', 5001);
        BACNET_CLIENT_CONNECT('ch1');
        ok := BACNET_CLIENT_CREATE('ch2', '10.0.2.11', 5002);
        BACNET_CLIENT_CONNECT('ch2');
        state := 1;

    1: (* Subscribe to chiller status via COV *)
        sub_ch1_status := BACNET_SUBSCRIBE_COV('ch1',
            BACNET_OBJECT_BI, 1, 0);
        sub_ch2_status := BACNET_SUBSCRIBE_COV('ch2',
            BACNET_OBJECT_BI, 1, 0);
        sub_load := BACNET_SUBSCRIBE_COV('ch1',
            BACNET_OBJECT_AI, 10, 0);
        state := 10;

    10: (* Staging logic — COV keeps values current *)
        ch1_running := BACNET_READ_BI('ch1', 1);
        ch2_running := BACNET_READ_BI('ch2', 1);
        plant_load := BACNET_READ_AI('ch1', 10);

        (* Stage up: start chiller 2 when load exceeds threshold *)
        IF plant_load > stage_up_sp AND NOT ch2_running THEN
            BACNET_WRITE_PRIORITY('ch2',
                BACNET_OBJECT_BO, 1,
                TRUE, 8);
        END_IF;

        (* Stage down: stop chiller 2 when load drops *)
        IF plant_load < stage_down_sp AND ch2_running AND ch1_running THEN
            BACNET_WRITE_PRIORITY('ch2',
                BACNET_OBJECT_BO, 1,
                FALSE, 8);
        END_IF;

        (* Fault handling *)
        IF NOT BACNET_CLIENT_IS_CONNECTED('ch1') THEN
            state := 0;
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 4.3 BACnet Gateway — Modbus to BACnet

GoPLC as a protocol translator: read Modbus devices and expose their data as BACnet objects for the BMS.

```iecst
PROGRAM POU_ModbusToBACnet
VAR
    state : INT := 0;
    ok : BOOL;

    (* Modbus power meter data *)
    voltage : REAL;
    current : REAL;
    power_kw : REAL;
    energy_kwh : REAL;

    (* Modbus registers — Shark 200 power meter *)
    mb_regs : ARRAY[0..7] OF INT;
END_VAR

CASE state OF
    0: (* Initialize both protocols *)
        ok := MB_CLIENT_CREATE('meter1', '10.0.0.80', 502);
        MB_CLIENT_CONNECT('meter1');
        ok := BACNET_SERVER_CREATE('gateway', 47808, 99100);
        BACNET_SERVER_START('gateway');
        state := 10;

    10: (* Read Modbus, expose as BACnet *)
        (* Read power meter via Modbus *)
        mb_regs := MB_READ_HOLDING('meter1', 0, 8);
        voltage := INT_TO_REAL(mb_regs[0]) / 10.0;
        current := INT_TO_REAL(mb_regs[2]) / 100.0;
        power_kw := INT_TO_REAL(mb_regs[4]) / 10.0;

        (* Expose as BACnet AI objects *)
        BACNET_SERVER_SET_AI('gateway', 1, voltage);     (* AI-1: Voltage *)
        BACNET_SERVER_SET_AI('gateway', 2, current);     (* AI-2: Current *)
        BACNET_SERVER_SET_AI('gateway', 3, power_kw);    (* AI-3: Power kW *)
END_CASE;
END_PROGRAM
```

---

### 4.4 Multi-AHU Monitoring Dashboard

Poll multiple AHUs and aggregate data for a building-level view.

```iecst
PROGRAM POU_BuildingMonitor
VAR
    state : INT := 0;
    ok : BOOL;
    i : INT;

    (* AHU data — 4 units *)
    ahu_names : ARRAY[0..3] OF STRING := ['ahu_1', 'ahu_2', 'ahu_3', 'ahu_4'];
    ahu_ips : ARRAY[0..3] OF STRING := ['10.0.1.100', '10.0.1.101', '10.0.1.102', '10.0.1.103'];
    ahu_ids : ARRAY[0..3] OF INT := [1001, 1002, 1003, 1004];

    sat : ARRAY[0..3] OF REAL;     (* Supply air temps *)
    rat : ARRAY[0..3] OF REAL;     (* Return air temps *)
    fan_sts : ARRAY[0..3] OF BOOL; (* Fan status *)
    alarms : ARRAY[0..3] OF BOOL;  (* Alarm active *)

    building_avg_temp : REAL;
    fans_running : INT := 0;
END_VAR

CASE state OF
    0: (* Create all connections *)
        FOR i := 0 TO 3 DO
            ok := BACNET_CLIENT_CREATE(ahu_names[i], ahu_ips[i], ahu_ids[i]);
            BACNET_CLIENT_CONNECT(ahu_names[i]);
        END_FOR;
        state := 10;

    10: (* Poll all AHUs *)
        building_avg_temp := 0.0;
        fans_running := 0;

        FOR i := 0 TO 3 DO
            IF BACNET_CLIENT_IS_CONNECTED(ahu_names[i]) THEN
                sat[i] := BACNET_READ_AI(ahu_names[i], 1);
                rat[i] := BACNET_READ_AI(ahu_names[i], 2);
                fan_sts[i] := BACNET_READ_BI(ahu_names[i], 1);

                building_avg_temp := building_avg_temp + rat[i];
                IF fan_sts[i] THEN
                    fans_running := fans_running + 1;
                END_IF;
            ELSE
                alarms[i] := TRUE;
                BACNET_CLIENT_CONNECT(ahu_names[i]);  (* Attempt reconnect *)
            END_IF;
        END_FOR;

        building_avg_temp := building_avg_temp / 4.0;
END_CASE;
END_PROGRAM
```

---

## 5. BACnet Protocol Notes

### Port and Network Configuration

- **Standard BACnet/IP port:** 47808 (0xBAC0). Most devices use this. Non-standard ports are supported by specifying them in `BACNET_CLIENT_CREATE`.
- **UDP protocol:** BACnet/IP uses UDP, not TCP. GoPLC manages socket creation and reuse internally.
- **Broadcast address:** WhoIs uses UDP broadcast on the BACnet/IP port. Ensure your network allows UDP broadcast on port 47808.
- **Firewall rules:** Allow UDP 47808 bidirectionally for both client and server operation.

### BACnet/IP vs. MS/TP

GoPLC speaks **BACnet/IP** natively. For devices on BACnet MS/TP (RS-485) trunks, you need a BACnet router between the IP network and the MS/TP trunk. Common BACnet routers: Tridium JACE, Contemporary Controls BASrouter, Loytec L-IP. The router handles protocol translation transparently — GoPLC sees MS/TP devices as normal BACnet/IP devices.

### Timeout and Retry Behavior

- **Default timeout:** 3 seconds per request. BACnet devices behind MS/TP segments may need longer due to token rotation delays.
- **Automatic retry:** Failed reads return the last known value. Check connection state with `BACNET_CLIENT_IS_CONNECTED` to detect prolonged failures.
- **COV resubscription:** If a device reboots, active COV subscriptions are lost. Monitor subscription health and re-subscribe as needed.

### Common BACnet Device IDs by Vendor

These are conventions, not standards — always verify with the integrator:

| Vendor | Typical Device ID Range |
|--------|------------------------|
| Trane Tracer | 1000-9999 |
| Johnson Controls (Metasys) | 10000-99999 |
| Distech Controls | 100-999 |
| Honeywell Spyder/WEB | 1-999 |
| Reliable Controls | 1000-65535 |
| Siemens DXR | 1-9999 |

### Priority Array Best Practices

1. **Always relinquish when done.** A stuck priority 8 override will fight your scheduling forever.
2. **Use consistent priorities across the project.** Document which priority each application uses.
3. **Priority 8 for operator overrides, 16 for scheduling** is the most common pattern.
4. **Never write to priority 1 or 2** unless you are implementing actual life safety logic. BMS integrators will flag this during commissioning.
5. **Read the priority array before writing** to understand what else is commanding the point.

---

## Appendix A: Function Quick Reference

### Client Functions

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `BACNET_CLIENT_CREATE` | name, targetIP, deviceID [, localPort] [, targetPort] | BOOL | Create named connection |
| `BACNET_CLIENT_CONNECT` | name | BOOL | Establish connection |
| `BACNET_CLIENT_DISCONNECT` | name | BOOL | Close connection |
| `BACNET_CLIENT_IS_CONNECTED` | name | BOOL | Check connection state |
| `BACNET_CLIENT_DELETE` | name | BOOL | Remove connection |
| `BACNET_CLIENT_LIST` | — | []STRING | List all connections |
| `BACNET_READ_PROPERTY` | name, objectType, objectInstance, property | ANY | Read any property |
| `BACNET_WRITE_PROPERTY` | name, objectType, objectInstance, property, value | BOOL | Write any property |
| `BACNET_READ_PRESENT_VALUE` | name, objectType, objectInstance | ANY | Read present value |
| `BACNET_WRITE_PRESENT_VALUE` | name, objectType, objectInstance, value | BOOL | Write present value |
| `BACNET_WRITE_PRIORITY` | name, objectType, objectInstance, value, priority | BOOL | Write at specific priority |
| `BACNET_RELINQUISH` | name, objectType, objectInstance, priority | BOOL | Release priority slot |
| `BACNET_WHO_IS` | name [, lowLimit] [, highLimit] | []MAP | Discover devices |
| `BACNET_SUBSCRIBE_COV` | name, objectType, objectInstance, lifetime | INT | Subscribe to value changes |
| `BACNET_UNSUBSCRIBE_COV` | name, subscriptionID | BOOL | Cancel subscription |
| `BACNET_GET_ALARMS` | name | []MAP | Read active alarms |
| `BACNET_GET_STATS` | — | MAP | Stack statistics |
| `BACNET_READ_AI` | name, instance | REAL | Read Analog Input |
| `BACNET_READ_AO` | name, instance | REAL | Read Analog Output |
| `BACNET_READ_AV` | name, instance | REAL | Read Analog Value |
| `BACNET_READ_BI` | name, instance | BOOL | Read Binary Input |
| `BACNET_READ_BO` | name, instance | BOOL | Read Binary Output |
| `BACNET_READ_BV` | name, instance | BOOL | Read Binary Value |
| `BACNET_WRITE_AO` | name, instance, value | BOOL | Write Analog Output |
| `BACNET_WRITE_AV` | name, instance, value | BOOL | Write Analog Value |
| `BACNET_WRITE_BO` | name, instance, value | BOOL | Write Binary Output |
| `BACNET_WRITE_BV` | name, instance, value | BOOL | Write Binary Value |

### Server Functions

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `BACNET_SERVER_CREATE` | name, port, device_id | BOOL | Create server instance |
| `BACNET_SERVER_START` | name | BOOL | Begin listening |
| `BACNET_SERVER_STOP` | name | BOOL | Stop listening |
| `BACNET_SERVER_IS_RUNNING` | name | BOOL | Check server state |
| `BACNET_SERVER_SET_AI` | name, instance, value | BOOL | Set Analog Input value |
| `BACNET_SERVER_SET_BI` | name, instance, value | BOOL | Set Binary Input value |
| `BACNET_SERVER_SET_AV` | name, instance, value | BOOL | Set Analog Value |
| `BACNET_SERVER_GET_AV` | name, instance | REAL | Read Analog Value |
| `BACNET_SERVER_GET_AO` | name, instance | REAL | Read Analog Output |
| `BACNET_SERVER_GET_BO` | name, instance | BOOL | Read Binary Output |
| `BACNET_SERVER_DELETE` | name | BOOL | Remove server |
| `BACNET_SERVER_LIST` | — | []STRING | List all servers |

### Object Type Constants

| Constant | Description |
|----------|-------------|
| `BACNET_OBJECT_AI` | Sensor readings (read-only) |
| `BACNET_OBJECT_AO` | Analog control outputs (commandable) |
| `BACNET_OBJECT_AV` | Setpoints and calculated values |
| `BACNET_OBJECT_BI` | Status signals (read-only) |
| `BACNET_OBJECT_BO` | On/off commands (commandable) |
| `BACNET_OBJECT_BV` | Mode flags and enables |
| `BACNET_OBJECT_MSI` | Enumerated status |
| `BACNET_OBJECT_MSO` | Enumerated commands |
| `BACNET_OBJECT_MSV` | Enumerated setpoints |

### Property Constants

| Constant | Description |
|----------|-------------|
| `BACNET_PROP_PRESENT_VALUE` | Current value of the object |
| `BACNET_PROP_OBJECT_NAME` | Human-readable name |
| `BACNET_PROP_DESCRIPTION` | Free-text description |
| `BACNET_PROP_UNITS` | Engineering units |
| `BACNET_PROP_PRIORITY_ARRAY` | 16-level command priority array |
| `BACNET_PROP_RELINQUISH_DEFAULT` | Default value when all priorities are NULL |

---

*GoPLC v1.0.533 | BACnet/IP (ASHRAE 135-2020) | UDP Port 47808*
*Client: ~27 functions | Server: ~12 functions*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
