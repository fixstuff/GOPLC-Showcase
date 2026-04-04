# GoPLC BACnet Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.520

---

## 1. Architecture Overview

GoPLC implements a complete **BACnet/IP** stack — both client and server — callable directly from IEC 61131-3 Structured Text. No external BACnet libraries, no EDE files, no vendor configuration tools. You create connections, read/write BACnet objects, subscribe to change-of-value (COV) notifications, and expose points to BMS systems with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `BACnetClientCreate` / `BACnetRead*` / `BACnetWrite*` / `BACnetSubscribeCOV` | Poll and command BACnet devices: AHUs, VAVs, chillers, meters, other controllers |
| **Server** | `BACnetServerCreate` / `BACnetServerSet*` / `BACnetServerGet*` | Expose GoPLC data to BMS front-ends, operator workstations, or third-party controllers |

Both roles can run simultaneously. A single GoPLC instance can poll a dozen VAV controllers as a client while serving zone data to a Tridium Niagara front-end — all from the same ST program.

### System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                  │
│                                                              │
│  ┌────────────────────────────┐  ┌────────────────────────┐  │
│  │ ST Program (Client)        │  │ ST Program (Server)    │  │
│  │                            │  │                        │  │
│  │ BACnetClientCreate()       │  │ BACnetServerCreate()   │  │
│  │ BACnetClientConnect()      │  │ BACnetServerStart()    │  │
│  │ BACnetReadPresentValue()   │  │ BACnetServerSetAI()    │  │
│  │ BACnetWritePriority()      │  │ BACnetServerSetAV()    │  │
│  │ BACnetSubscribeCOV()       │  │ BACnetServerGetAO()    │  │
│  │ BACnetWhoIs()              │  │                        │  │
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
| **Analog Input** | `BACnetObjectType_AnalogInput` | Sensor readings: temperature, pressure, humidity, flow |
| **Analog Output** | `BACnetObjectType_AnalogOutput` | Control outputs: valve position, damper command, VFD speed |
| **Analog Value** | `BACnetObjectType_AnalogValue` | Setpoints, tuning parameters, calculated values |
| **Binary Input** | `BACnetObjectType_BinaryInput` | Status signals: fan running, filter alarm, occupancy |
| **Binary Output** | `BACnetObjectType_BinaryOutput` | On/off commands: fan start, pump enable, lighting relay |
| **Binary Value** | `BACnetObjectType_BinaryValue` | Mode flags: occupied/unoccupied, auto/manual, enable/disable |
| **Multi-State Input** | `BACnetObjectType_MultiStateInput` | Enumerated status: operating mode, fault code |
| **Multi-State Output** | `BACnetObjectType_MultiStateOutput` | Enumerated commands: speed stage, mode select |
| **Multi-State Value** | `BACnetObjectType_MultiStateValue` | Enumerated setpoints: schedule mode, season |

### BACnet Property Constants

Every BACnet object has properties. GoPLC provides constants for the most commonly accessed ones:

| Constant | Description |
|----------|-------------|
| `BACnetProperty_PresentValue` | Current value of the object — the most-read property |
| `BACnetProperty_ObjectName` | Human-readable name string |
| `BACnetProperty_Description` | Free-text description |
| `BACnetProperty_Units` | Engineering units (degrees-F, PSI, CFM, etc.) |
| `BACnetProperty_PriorityArray` | 16-level command priority array (outputs only) |
| `BACnetProperty_RelinquishDefault` | Value used when all priority slots are NULL |

> **Priority Array:** BACnet outputs (AO, BO, MSO) use a 16-level priority scheme. Priority 1 is highest (life safety), priority 16 is lowest (default). When you write to an output, you specify which priority slot to claim. The device uses the highest-priority non-NULL value. This prevents a scheduling override from fighting a life-safety shutdown.

---

## 2. Client Functions

The BACnet client connects to remote BACnet/IP devices and performs read/write/subscribe operations using standard BACnet services.

### 2.1 Connection Management

#### BACnetClientCreate — Create Named Connection

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
ok := BACnetClientCreate('ahu1', '10.0.1.100', 1001);

(* Connect to a device on a non-standard port *)
ok := BACnetClientCreate('vav3', '10.0.1.50', 3050, 47808, 47809);
```

> **Named connections:** Every BACnet client connection has a unique string name. This name is used in all subsequent calls. Create one connection per BACnet device — GoPLC manages the UDP sockets internally.

#### BACnetClientConnect — Establish Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name from BACnetClientCreate |

Returns: `BOOL` — TRUE if connected successfully.

```iecst
ok := BACnetClientConnect('ahu1');
```

#### BACnetClientDisconnect — Close Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if disconnected successfully.

```iecst
ok := BACnetClientDisconnect('ahu1');
```

#### BACnetClientIsConnected — Check Connection State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if the connection is active.

```iecst
IF NOT BACnetClientIsConnected('ahu1') THEN
    BACnetClientConnect('ahu1');
END_IF;
```

#### BACnetClientDelete — Remove Connection

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `BOOL` — TRUE if deleted successfully.

```iecst
ok := BACnetClientDelete('ahu1');
```

#### BACnetClientList — List All Connections

Returns: `[]STRING` — Array of connection names.

```iecst
clients := BACnetClientList();
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
        ok := BACnetClientCreate('ahu1', '10.0.1.100', 1001);
        IF ok THEN
            state := 1;
        END_IF;

    1: (* Connect *)
        ok := BACnetClientConnect('ahu1');
        IF ok THEN
            state := 10;
        END_IF;

    10: (* Running — read/write in other programs *)
        IF NOT BACnetClientIsConnected('ahu1') THEN
            state := 1;  (* Reconnect *)
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.2 Generic Read/Write

These functions work with any BACnet object type and property. Use the object type and property constants for clarity.

#### BACnetReadProperty — Read Any Property

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `property` | INT | BACnet property constant |

Returns: `ANY` — Value type depends on the property.

```iecst
(* Read the present value of Analog Input 1 *)
temp := BACnetReadProperty('ahu1',
    BACnetObjectType_AnalogInput, 1,
    BACnetProperty_PresentValue);
(* Returns: 72.5 *)

(* Read the object name *)
name := BACnetReadProperty('ahu1',
    BACnetObjectType_AnalogInput, 1,
    BACnetProperty_ObjectName);
(* Returns: 'ZN-T' *)

(* Read the engineering units *)
units := BACnetReadProperty('ahu1',
    BACnetObjectType_AnalogInput, 1,
    BACnetProperty_Units);
(* Returns: 64  (degrees-Fahrenheit) *)

(* Read the priority array of an Analog Output *)
priorities := BACnetReadProperty('ahu1',
    BACnetObjectType_AnalogOutput, 1,
    BACnetProperty_PriorityArray);
(* Returns: [NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,72.0,NULL,NULL,NULL,NULL,NULL,NULL,NULL] *)
```

#### BACnetWriteProperty — Write Any Property

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
ok := BACnetWriteProperty('ahu1',
    BACnetObjectType_AnalogValue, 5,
    BACnetProperty_Description, 'Cooling setpoint offset');
```

> **Present Value Writes:** For writing present values to outputs with priority, use `BACnetWritePriority` instead. Direct writes to PresentValue via `BACnetWriteProperty` go to priority 16 (lowest) and may be overridden by higher-priority commands.

#### BACnetReadPresentValue — Read Present Value (Shorthand)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |

Returns: `ANY` — Current present value of the object.

```iecst
(* These two calls are equivalent *)
temp := BACnetReadPresentValue('ahu1', BACnetObjectType_AnalogInput, 1);
temp := BACnetReadProperty('ahu1', BACnetObjectType_AnalogInput, 1, BACnetProperty_PresentValue);
```

#### BACnetWritePresentValue — Write Present Value (Shorthand)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `value` | ANY | Value to write |

Returns: `BOOL` — TRUE if acknowledged.

```iecst
ok := BACnetWritePresentValue('ahu1', BACnetObjectType_AnalogValue, 5, 72.0);
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

#### BACnetWritePriority — Write at Specific Priority

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
ok := BACnetWritePriority('ahu1',
    BACnetObjectType_AnalogOutput, 1,
    75.0, 8);

(* Write fan command ON at priority 5 (critical equipment) *)
ok := BACnetWritePriority('ahu1',
    BACnetObjectType_BinaryOutput, 1,
    TRUE, 5);

(* Write occupied cooling setpoint at priority 16 (scheduling) *)
ok := BACnetWritePriority('ahu1',
    BACnetObjectType_AnalogValue, 10,
    72.0, 16);
```

#### BACnetRelinquish — Release a Priority Slot

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
ok := BACnetRelinquish('ahu1',
    BACnetObjectType_AnalogOutput, 1,
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
        ok := BACnetRelinquish('ahu1',
            BACnetObjectType_AnalogOutput, 1, 8);
        override_active := FALSE;
        override_timer := 0;
    END_IF;
ELSE
    (* Normal operation — write at priority 16 *)
    ok := BACnetWritePriority('ahu1',
        BACnetObjectType_AnalogOutput, 1,
        pid_output, 16);
END_IF;
END_PROGRAM
```

---

### 2.4 Typed Convenience Functions

These wrap `BACnetReadPresentValue` / `BACnetWritePresentValue` for the six most common object types. They return properly typed values and require only the connection name and instance number — the object type is implied by the function name.

#### Analog Reads

| Function | Object Type | Returns |
|----------|-------------|---------|
| `BACnetReadAI(name, instance)` | Analog Input | `REAL` |
| `BACnetReadAO(name, instance)` | Analog Output | `REAL` |
| `BACnetReadAV(name, instance)` | Analog Value | `REAL` |

```iecst
(* Read zone temperature from AI-1 *)
zone_temp := BACnetReadAI('vav3', 1);

(* Read current damper position from AO-1 *)
damper_pos := BACnetReadAO('vav3', 1);

(* Read cooling setpoint from AV-10 *)
clg_sp := BACnetReadAV('vav3', 10);
```

#### Binary Reads

| Function | Object Type | Returns |
|----------|-------------|---------|
| `BACnetReadBI(name, instance)` | Binary Input | `BOOL` |
| `BACnetReadBO(name, instance)` | Binary Output | `BOOL` |
| `BACnetReadBV(name, instance)` | Binary Value | `BOOL` |

```iecst
(* Read fan status from BI-1 *)
fan_running := BACnetReadBI('ahu1', 1);

(* Read fan command from BO-1 *)
fan_cmd := BACnetReadBO('ahu1', 1);

(* Read occupancy mode from BV-5 *)
occupied := BACnetReadBV('ahu1', 5);
```

#### Analog Writes

| Function | Object Type | Param | Returns |
|----------|-------------|-------|---------|
| `BACnetWriteAO(name, instance, value)` | Analog Output | `REAL` | `BOOL` |
| `BACnetWriteAV(name, instance, value)` | Analog Value | `REAL` | `BOOL` |

```iecst
(* Command damper to 50% *)
ok := BACnetWriteAO('vav3', 1, 50.0);

(* Write cooling setpoint *)
ok := BACnetWriteAV('vav3', 10, 74.0);
```

#### Binary Writes

| Function | Object Type | Param | Returns |
|----------|-------------|-------|---------|
| `BACnetWriteBO(name, instance, value)` | Binary Output | `BOOL` | `BOOL` |
| `BACnetWriteBV(name, instance, value)` | Binary Value | `BOOL` | `BOOL` |

```iecst
(* Start supply fan *)
ok := BACnetWriteBO('ahu1', 1, TRUE);

(* Set occupied mode *)
ok := BACnetWriteBV('ahu1', 5, TRUE);
```

> **No Write for AI/BI:** Analog Inputs and Binary Inputs are read-only by definition. There is no `BACnetWriteAI` or `BACnetWriteBI`. If you need a writable analog point, use Analog Value (AV). If you need a writable binary point, use Binary Value (BV).

---

### 2.5 Device Discovery (WhoIs)

BACnet provides a broadcast discovery mechanism. `WhoIs` sends a broadcast (or directed) request, and all BACnet devices in the specified range respond with their device instance, IP address, and other identifying information.

#### BACnetWhoIs — Discover Devices

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | STRING | Yes | Connection name (uses its UDP socket) |
| `lowLimit` | INT | No | Lowest device instance to find |
| `highLimit` | INT | No | Highest device instance to find |

Returns: `[]MAP` — Array of device descriptors.

```iecst
(* Discover ALL BACnet devices on the network *)
devices := BACnetWhoIs('ahu1');
(* Returns:
   [
     {"device_id": 1001, "ip": "10.0.1.100", "vendor": "Trane"},
     {"device_id": 1002, "ip": "10.0.1.101", "vendor": "Trane"},
     {"device_id": 3050, "ip": "10.0.1.50",  "vendor": "Distech"}
   ]
*)

(* Discover devices in a specific range *)
devices := BACnetWhoIs('ahu1', 1000, 1099);
(* Returns only devices with instance 1000-1099 *)

(* Find a single device *)
devices := BACnetWhoIs('ahu1', 1001, 1001);
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
        ok := BACnetClientCreate('scanner', '255.255.255.255', 0);
        IF ok THEN
            ok := BACnetClientConnect('scanner');
            state := 1;
        END_IF;

    1: (* Send WhoIs broadcast *)
        devices := BACnetWhoIs('scanner');
        device_count := LEN(devices);
        state := 2;

    2: (* Log discovered devices *)
        FOR i := 0 TO device_count - 1 DO
            LOG(CONCAT('Found device ', INT_TO_STRING(devices[i].device_id),
                       ' at ', devices[i].ip));
        END_FOR;
        state := 10;

    10: (* Done *)
        BACnetClientDelete('scanner');
END_CASE;
END_PROGRAM
```

---

### 2.6 Change of Value (COV) Subscriptions

Instead of polling, COV lets you subscribe to a BACnet object and receive asynchronous notifications when its value changes. This reduces network traffic and provides near-instant updates for critical points.

#### BACnetSubscribeCOV — Create Subscription

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `objectType` | INT | BACnet object type constant |
| `objectInstance` | INT | Object instance number |
| `lifetime` | INT | Subscription lifetime in seconds (0 = indefinite) |

Returns: `INT` — Subscription ID (used for unsubscribe), or -1 on failure.

```iecst
(* Subscribe to zone temperature changes — 1 hour lifetime *)
sub_id := BACnetSubscribeCOV('vav3',
    BACnetObjectType_AnalogInput, 1,
    3600);

(* Subscribe indefinitely to fan status *)
sub_id2 := BACnetSubscribeCOV('ahu1',
    BACnetObjectType_BinaryInput, 1,
    0);
```

> **COV Increment:** The remote device determines when to send notifications based on its configured COV increment. For analog objects, this is typically 0.1-1.0 units. For binary objects, any state change triggers a notification. The notification updates the cached present value, which you read with `BACnetReadPresentValue` or the typed convenience functions.

> **Lifetime Management:** When the lifetime expires, the subscription ends silently. Set lifetime to 0 for indefinite subscriptions, or re-subscribe periodically. Some devices limit the number of active COV subscriptions (typically 16-64). Use COV for critical points and poll the rest.

#### BACnetUnsubscribeCOV — Cancel Subscription

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |
| `subscriptionID` | INT | Subscription ID from BACnetSubscribeCOV |

Returns: `BOOL` — TRUE if unsubscribed successfully.

```iecst
ok := BACnetUnsubscribeCOV('vav3', sub_id);
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
        sub_temp := BACnetSubscribeCOV('ahu1',
            BACnetObjectType_AnalogInput, 1, 0);
        sub_fan := BACnetSubscribeCOV('ahu1',
            BACnetObjectType_BinaryInput, 1, 0);
        IF sub_temp >= 0 AND sub_fan >= 0 THEN
            state := 10;
        END_IF;

    10: (* Monitor — values update automatically via COV *)
        zone_temp := BACnetReadAI('ahu1', 1);
        fan_status := BACnetReadBI('ahu1', 1);

        (* High temperature alarm *)
        IF zone_temp > high_temp_limit AND NOT fan_status THEN
            alarm_active := TRUE;
            (* Force fan ON at high priority *)
            BACnetWritePriority('ahu1',
                BACnetObjectType_BinaryOutput, 1,
                TRUE, 5);
        ELSIF zone_temp < (high_temp_limit - 2.0) THEN
            IF alarm_active THEN
                BACnetRelinquish('ahu1',
                    BACnetObjectType_BinaryOutput, 1, 5);
                alarm_active := FALSE;
            END_IF;
        END_IF;
END_CASE;
END_PROGRAM
```

---

### 2.7 Alarms and Statistics

#### BACnetGetAlarms — Read Active Alarms

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Connection name |

Returns: `[]MAP` — Array of active alarm entries from the device.

```iecst
alarms := BACnetGetAlarms('ahu1');
(* Returns:
   [
     {"object_type": 0, "instance": 3, "state": "high-limit",
      "value": 87.2, "timestamp": "2026-04-03T14:22:00Z"},
     {"object_type": 4, "instance": 1, "state": "offnormal",
      "value": 0, "timestamp": "2026-04-03T14:20:15Z"}
   ]
*)
```

#### BACnetGetStats — Connection Statistics

Returns: `MAP` — Statistics for the BACnet stack.

```iecst
stats := BACnetGetStats();
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

#### BACnetServerCreate — Create Server Instance

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique server name |
| `port` | INT | UDP listen port (typically 47808) |
| `device_id` | INT | BACnet device instance to advertise |

Returns: `BOOL` — TRUE if created successfully.

```iecst
(* Create a BACnet server — device ID 99001 *)
ok := BACnetServerCreate('bms_server', 47808, 99001);
```

> **Device ID:** Every BACnet device on the network must have a unique device instance number. Coordinate with the BMS integrator to avoid conflicts. Common convention: 99xxx for soft controllers, leaving lower ranges for hardware controllers.

#### BACnetServerStart — Begin Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if started.

```iecst
ok := BACnetServerStart('bms_server');
```

#### BACnetServerStop — Stop Listening

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if stopped.

```iecst
ok := BACnetServerStop('bms_server');
```

#### BACnetServerIsRunning — Check Server State

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if the server is actively listening.

```iecst
IF NOT BACnetServerIsRunning('bms_server') THEN
    BACnetServerStart('bms_server');
END_IF;
```

#### BACnetServerDelete — Remove Server

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |

Returns: `BOOL` — TRUE if deleted.

```iecst
ok := BACnetServerDelete('bms_server');
```

#### BACnetServerList — List All Servers

Returns: `[]STRING` — Array of server names.

```iecst
servers := BACnetServerList();
```

---

### 3.2 Setting Server Point Values

Use these to push GoPLC data into server objects. Remote BACnet clients will read these values.

#### BACnetServerSetAI — Set Analog Input Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |
| `value` | REAL | Analog value |

Returns: `BOOL` — TRUE if set.

```iecst
(* Expose zone temperature as AI-1 *)
ok := BACnetServerSetAI('bms_server', 1, zone_temp);

(* Expose discharge air temperature as AI-2 *)
ok := BACnetServerSetAI('bms_server', 2, dat);
```

#### BACnetServerSetBI — Set Binary Input Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |
| `value` | BOOL | Binary value |

Returns: `BOOL` — TRUE if set.

```iecst
(* Expose fan status as BI-1 *)
ok := BACnetServerSetBI('bms_server', 1, fan_running);
```

#### BACnetServerSetAV — Set Analog Value

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |
| `value` | REAL | Analog value |

Returns: `BOOL` — TRUE if set.

```iecst
(* Expose PID output as AV-1 *)
ok := BACnetServerSetAV('bms_server', 1, pid_output);
```

---

### 3.3 Reading Commanded Values

When a remote BACnet client writes to your server's output objects, use these to read the commanded values.

#### BACnetServerGetAV — Read Analog Value (Written by Remote)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |

Returns: `REAL` — Current value.

```iecst
(* Read setpoint written by the BMS front-end *)
remote_setpoint := BACnetServerGetAV('bms_server', 10);
```

#### BACnetServerGetAO — Read Analog Output (Written by Remote)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |

Returns: `REAL` — Current value.

```iecst
(* Read command from BMS *)
valve_cmd := BACnetServerGetAO('bms_server', 1);
```

#### BACnetServerGetBO — Read Binary Output (Written by Remote)

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Server name |
| `instance` | INT | Object instance number |

Returns: `BOOL` — Current value.

```iecst
(* Read fan command from BMS *)
fan_cmd_from_bms := BACnetServerGetBO('bms_server', 1);
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
        ok := BACnetServerCreate('bms', 47808, 99001);
        IF ok THEN
            BACnetServerStart('bms');
            state := 10;
        END_IF;

    10: (* Running — update exposed points every scan *)
        (* Push sensor data to BACnet objects *)
        BACnetServerSetAI('bms', 1, zone_temp);     (* AI-1: Zone Temp *)
        BACnetServerSetAI('bms', 2, dat);            (* AI-2: Discharge Air Temp *)
        BACnetServerSetBI('bms', 1, fan_running);    (* BI-1: Fan Status *)
        BACnetServerSetAV('bms', 1, pid_output);     (* AV-1: PID Output *)

        (* Read commands written by BMS front-end *)
        remote_sp := BACnetServerGetAV('bms', 10);   (* AV-10: Remote Setpoint *)
        fan_cmd := BACnetServerGetBO('bms', 1);       (* BO-1: Fan Command *)
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
        ok := BACnetClientCreate('vav_b1', '10.0.1.110', 2001);
        IF ok THEN
            ok := BACnetClientConnect('vav_b1');
            IF ok THEN state := 10; END_IF;
        END_IF;

    10: (* Read current status *)
        zone_temp := BACnetReadAI('vav_b1', 1);     (* Zone temp *)
        zone_sp := BACnetReadAV('vav_b1', 1);       (* Zone setpoint *)
        damper_pos := BACnetReadAO('vav_b1', 1);     (* Damper feedback *)
        airflow := BACnetReadAI('vav_b1', 2);        (* CFM *)
        occ_mode := BACnetReadBV('vav_b1', 1);       (* Occupied mode *)

        (* Simple proportional damper control *)
        IF occ_mode THEN
            damper_cmd := (zone_temp - zone_sp) * 10.0;  (* P-only *)
            IF damper_cmd < min_flow THEN damper_cmd := min_flow; END_IF;
            IF damper_cmd > max_flow THEN damper_cmd := max_flow; END_IF;
        ELSE
            damper_cmd := min_flow;  (* Minimum flow when unoccupied *)
        END_IF;

        (* Write damper command at priority 8 *)
        ok := BACnetWritePriority('vav_b1',
            BACnetObjectType_AnalogOutput, 1,
            damper_cmd, 8);

        (* Reconnect if lost *)
        IF NOT BACnetClientIsConnected('vav_b1') THEN
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
        ok := BACnetClientCreate('ch1', '10.0.2.10', 5001);
        BACnetClientConnect('ch1');
        ok := BACnetClientCreate('ch2', '10.0.2.11', 5002);
        BACnetClientConnect('ch2');
        state := 1;

    1: (* Subscribe to chiller status via COV *)
        sub_ch1_status := BACnetSubscribeCOV('ch1',
            BACnetObjectType_BinaryInput, 1, 0);
        sub_ch2_status := BACnetSubscribeCOV('ch2',
            BACnetObjectType_BinaryInput, 1, 0);
        sub_load := BACnetSubscribeCOV('ch1',
            BACnetObjectType_AnalogInput, 10, 0);
        state := 10;

    10: (* Staging logic — COV keeps values current *)
        ch1_running := BACnetReadBI('ch1', 1);
        ch2_running := BACnetReadBI('ch2', 1);
        plant_load := BACnetReadAI('ch1', 10);

        (* Stage up: start chiller 2 when load exceeds threshold *)
        IF plant_load > stage_up_sp AND NOT ch2_running THEN
            BACnetWritePriority('ch2',
                BACnetObjectType_BinaryOutput, 1,
                TRUE, 8);
        END_IF;

        (* Stage down: stop chiller 2 when load drops *)
        IF plant_load < stage_down_sp AND ch2_running AND ch1_running THEN
            BACnetWritePriority('ch2',
                BACnetObjectType_BinaryOutput, 1,
                FALSE, 8);
        END_IF;

        (* Fault handling *)
        IF NOT BACnetClientIsConnected('ch1') THEN
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
        ok := MBClientCreate('meter1', '10.0.0.80', 502);
        MBClientConnect('meter1');
        ok := BACnetServerCreate('gateway', 47808, 99100);
        BACnetServerStart('gateway');
        state := 10;

    10: (* Read Modbus, expose as BACnet *)
        (* Read power meter via Modbus *)
        mb_regs := MBClientReadHoldingRegisters('meter1', 0, 8);
        voltage := INT_TO_REAL(mb_regs[0]) / 10.0;
        current := INT_TO_REAL(mb_regs[2]) / 100.0;
        power_kw := INT_TO_REAL(mb_regs[4]) / 10.0;

        (* Expose as BACnet AI objects *)
        BACnetServerSetAI('gateway', 1, voltage);     (* AI-1: Voltage *)
        BACnetServerSetAI('gateway', 2, current);     (* AI-2: Current *)
        BACnetServerSetAI('gateway', 3, power_kw);    (* AI-3: Power kW *)
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
            ok := BACnetClientCreate(ahu_names[i], ahu_ips[i], ahu_ids[i]);
            BACnetClientConnect(ahu_names[i]);
        END_FOR;
        state := 10;

    10: (* Poll all AHUs *)
        building_avg_temp := 0.0;
        fans_running := 0;

        FOR i := 0 TO 3 DO
            IF BACnetClientIsConnected(ahu_names[i]) THEN
                sat[i] := BACnetReadAI(ahu_names[i], 1);
                rat[i] := BACnetReadAI(ahu_names[i], 2);
                fan_sts[i] := BACnetReadBI(ahu_names[i], 1);

                building_avg_temp := building_avg_temp + rat[i];
                IF fan_sts[i] THEN
                    fans_running := fans_running + 1;
                END_IF;
            ELSE
                alarms[i] := TRUE;
                BACnetClientConnect(ahu_names[i]);  (* Attempt reconnect *)
            END_IF;
        END_FOR;

        building_avg_temp := building_avg_temp / 4.0;
END_CASE;
END_PROGRAM
```

---

## 5. BACnet Protocol Notes

### Port and Network Configuration

- **Standard BACnet/IP port:** 47808 (0xBAC0). Most devices use this. Non-standard ports are supported by specifying them in `BACnetClientCreate`.
- **UDP protocol:** BACnet/IP uses UDP, not TCP. GoPLC manages socket creation and reuse internally.
- **Broadcast address:** WhoIs uses UDP broadcast on the BACnet/IP port. Ensure your network allows UDP broadcast on port 47808.
- **Firewall rules:** Allow UDP 47808 bidirectionally for both client and server operation.

### BACnet/IP vs. MS/TP

GoPLC speaks **BACnet/IP** natively. For devices on BACnet MS/TP (RS-485) trunks, you need a BACnet router between the IP network and the MS/TP trunk. Common BACnet routers: Tridium JACE, Contemporary Controls BASrouter, Loytec L-IP. The router handles protocol translation transparently — GoPLC sees MS/TP devices as normal BACnet/IP devices.

### Timeout and Retry Behavior

- **Default timeout:** 3 seconds per request. BACnet devices behind MS/TP segments may need longer due to token rotation delays.
- **Automatic retry:** Failed reads return the last known value. Check connection state with `BACnetClientIsConnected` to detect prolonged failures.
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
| `BACnetClientCreate` | name, targetIP, deviceID [, localPort] [, targetPort] | BOOL | Create named connection |
| `BACnetClientConnect` | name | BOOL | Establish connection |
| `BACnetClientDisconnect` | name | BOOL | Close connection |
| `BACnetClientIsConnected` | name | BOOL | Check connection state |
| `BACnetClientDelete` | name | BOOL | Remove connection |
| `BACnetClientList` | — | []STRING | List all connections |
| `BACnetReadProperty` | name, objectType, objectInstance, property | ANY | Read any property |
| `BACnetWriteProperty` | name, objectType, objectInstance, property, value | BOOL | Write any property |
| `BACnetReadPresentValue` | name, objectType, objectInstance | ANY | Read present value |
| `BACnetWritePresentValue` | name, objectType, objectInstance, value | BOOL | Write present value |
| `BACnetWritePriority` | name, objectType, objectInstance, value, priority | BOOL | Write at specific priority |
| `BACnetRelinquish` | name, objectType, objectInstance, priority | BOOL | Release priority slot |
| `BACnetWhoIs` | name [, lowLimit] [, highLimit] | []MAP | Discover devices |
| `BACnetSubscribeCOV` | name, objectType, objectInstance, lifetime | INT | Subscribe to value changes |
| `BACnetUnsubscribeCOV` | name, subscriptionID | BOOL | Cancel subscription |
| `BACnetGetAlarms` | name | []MAP | Read active alarms |
| `BACnetGetStats` | — | MAP | Stack statistics |
| `BACnetReadAI` | name, instance | REAL | Read Analog Input |
| `BACnetReadAO` | name, instance | REAL | Read Analog Output |
| `BACnetReadAV` | name, instance | REAL | Read Analog Value |
| `BACnetReadBI` | name, instance | BOOL | Read Binary Input |
| `BACnetReadBO` | name, instance | BOOL | Read Binary Output |
| `BACnetReadBV` | name, instance | BOOL | Read Binary Value |
| `BACnetWriteAO` | name, instance, value | BOOL | Write Analog Output |
| `BACnetWriteAV` | name, instance, value | BOOL | Write Analog Value |
| `BACnetWriteBO` | name, instance, value | BOOL | Write Binary Output |
| `BACnetWriteBV` | name, instance, value | BOOL | Write Binary Value |

### Server Functions

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `BACnetServerCreate` | name, port, device_id | BOOL | Create server instance |
| `BACnetServerStart` | name | BOOL | Begin listening |
| `BACnetServerStop` | name | BOOL | Stop listening |
| `BACnetServerIsRunning` | name | BOOL | Check server state |
| `BACnetServerSetAI` | name, instance, value | BOOL | Set Analog Input value |
| `BACnetServerSetBI` | name, instance, value | BOOL | Set Binary Input value |
| `BACnetServerSetAV` | name, instance, value | BOOL | Set Analog Value |
| `BACnetServerGetAV` | name, instance | REAL | Read Analog Value |
| `BACnetServerGetAO` | name, instance | REAL | Read Analog Output |
| `BACnetServerGetBO` | name, instance | BOOL | Read Binary Output |
| `BACnetServerDelete` | name | BOOL | Remove server |
| `BACnetServerList` | — | []STRING | List all servers |

### Object Type Constants

| Constant | Description |
|----------|-------------|
| `BACnetObjectType_AnalogInput` | Sensor readings (read-only) |
| `BACnetObjectType_AnalogOutput` | Analog control outputs (commandable) |
| `BACnetObjectType_AnalogValue` | Setpoints and calculated values |
| `BACnetObjectType_BinaryInput` | Status signals (read-only) |
| `BACnetObjectType_BinaryOutput` | On/off commands (commandable) |
| `BACnetObjectType_BinaryValue` | Mode flags and enables |
| `BACnetObjectType_MultiStateInput` | Enumerated status |
| `BACnetObjectType_MultiStateOutput` | Enumerated commands |
| `BACnetObjectType_MultiStateValue` | Enumerated setpoints |

### Property Constants

| Constant | Description |
|----------|-------------|
| `BACnetProperty_PresentValue` | Current value of the object |
| `BACnetProperty_ObjectName` | Human-readable name |
| `BACnetProperty_Description` | Free-text description |
| `BACnetProperty_Units` | Engineering units |
| `BACnetProperty_PriorityArray` | 16-level command priority array |
| `BACnetProperty_RelinquishDefault` | Default value when all priorities are NULL |

---

*GoPLC v1.0.520 | BACnet/IP (ASHRAE 135-2020) | UDP Port 47808*
*Client: ~27 functions | Server: ~12 functions*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
