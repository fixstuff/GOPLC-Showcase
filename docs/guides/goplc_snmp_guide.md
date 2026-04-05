# GoPLC SNMP Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements a complete **SNMP** stack — client, trap receiver, and agent (server) — callable directly from IEC 61131-3 Structured Text. No MIB compilers, no external tools, no configuration files. You poll network devices, catch traps, and expose PLC data via SNMP with plain function calls in your ST programs.

| Role | Functions | Use Case |
|------|-----------|----------|
| **Client** | `SNMP_CLIENT_CREATE` / `SNMP_GET` / `SNMP_SET` / `SNMP_WALK` | Poll UPS, PDU, switches, printers — any SNMP-managed device |
| **Trap Receiver** | `SNMP_TRAP_START` / `SNMP_TRAP_GET_BUFFER` | Catch asynchronous alerts: link down, UPS on battery, temperature alarms |
| **Agent (Server)** | `SNMP_AGENT_CREATE` / `SNMP_AGENT_SET_INT` / `SNMP_AGENT_SET_STR` | Expose PLC tags to NMS platforms: Nagios, PRTG, Zabbix, LibreNMS |

All three roles run simultaneously. A single GoPLC instance can poll a datacenter UPS and PDU as a client, receive traps from managed switches, and serve its own OID tree to a network management system — all from the same ST program.

### System Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                          │
│                                                                      │
│  ┌──────────────────────┐  ┌────────────────┐  ┌──────────────────┐  │
│  │ ST Program (Client)  │  │ ST Program     │  │ ST Program       │  │
│  │                      │  │ (Trap Receiver)│  │ (Agent/Server)   │  │
│  │ SNMP_CLIENT_CREATE()   │  │                │  │                  │  │
│  │ SNMP_GET()            │  │ SNMP_TRAP_START()│  │ SNMP_AGENT_CREATE()│  │
│  │ SNMP_WALK()           │  │ SNMP_TRAP_GET    │  │ SNMP_AGENT_SET_INT()│  │
│  │ SNMP_SET()            │  │   Buffer()     │  │ SNMP_AGENT_SET_STR()│  │
│  └──────────┬───────────┘  └───────┬────────┘  └────────┬─────────┘  │
│             │                      │                     │            │
│             │  UDP Client          │  UDP Listener       │  UDP Agent │
│             │  (polls out)         │  (port 162)         │  (listens) │
└─────────────┼──────────────────────┼─────────────────────┼────────────┘
              │                      │                     │
              │  SNMP v1/v2c/v3      │  SNMP Traps         │  SNMP v2c
              │  (Port 161 default)  │  (configurable)     │  (configurable)
              ▼                      ▼                     ▼
┌─────────────────────────┐  ┌──────────────────┐  ┌─────────────────────┐
│  Managed Devices        │  │  Trap Sources    │  │  NMS / Monitoring   │
│                         │  │                  │  │                     │
│  UPS, PDU, switches,    │  │  Switches, UPS,  │  │  Nagios, PRTG,     │
│  printers, APs, HVAC    │  │  routers, APs    │  │  Zabbix, LibreNMS  │
└─────────────────────────┘  └──────────────────┘  └─────────────────────┘
```

### SNMP Versions Supported

| Version | Auth | Privacy | GoPLC Support |
|---------|------|---------|---------------|
| **v1** | Community string | None | Client only |
| **v2c** | Community string | None | Client, Agent, Traps |
| **v3** | USM (MD5/SHA) | DES/AES | Client only (SNMPv3 auth+priv) |

### Built-in OID Constants

GoPLC provides named constants for common OIDs so you never need to memorize dotted notation:

| Constant | OID | Description |
|----------|-----|-------------|
| `SNMP_OID_SYS_DESCR` | 1.3.6.1.2.1.1.1.0 | System description |
| `SNMP_OID_SYS_OBJECT_ID` | 1.3.6.1.2.1.1.2.0 | System object identifier |
| `SNMP_OID_SYS_UPTIME` | 1.3.6.1.2.1.1.3.0 | Uptime in hundredths of seconds |
| `SNMP_OID_SYS_CONTACT` | 1.3.6.1.2.1.1.4.0 | Admin contact |
| `SNMP_OID_SYS_NAME` | 1.3.6.1.2.1.1.5.0 | Device hostname |
| `SNMP_OID_SYS_LOCATION` | 1.3.6.1.2.1.1.6.0 | Physical location |
| `SNMP_OID_IF_NUMBER` | 1.3.6.1.2.1.2.1.0 | Number of network interfaces |
| `SNMP_OID_IF_TABLE` | 1.3.6.1.2.1.2.2 | Interface table root |
| `SNMP_OID_UPS_BATTERY_STATUS` | 1.3.6.1.2.1.33.1.2.1.0 | UPS battery status |
| `SNMP_OID_UPS_INPUT_VOLTAGE` | 1.3.6.1.2.1.33.1.3.3.1.3.1 | UPS input voltage |
| `SNMP_OID_UPS_OUTPUT_LOAD` | 1.3.6.1.2.1.33.1.4.4.1.5.1 | UPS output load percentage |

---

## 2. Client Functions

### 2.1 Connection Lifecycle

#### SNMP_CLIENT_CREATE -- Create v1/v2c Client

```iecst
(* Minimal — defaults to port 161, community "public", version v2c *)
ok := SNMP_CLIENT_CREATE('ups1', '10.0.1.50');

(* Explicit port and community *)
ok := SNMP_CLIENT_CREATE('pdu1', '10.0.1.51', 161, 'datacenter-ro', 'v2c');

(* SNMPv1 device *)
ok := SNMP_CLIENT_CREATE('old_switch', '10.0.1.10', 161, 'public', 'v1');
```

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | STRING | (required) | Unique client identifier |
| `host` | STRING | (required) | IP address or hostname |
| `port` | INT | 161 | UDP port |
| `community` | STRING | `'public'` | Community string |
| `version` | STRING | `'v2c'` | `'v1'` or `'v2c'` |

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_CLIENT_CREATE_V3 -- Create v3 Client (AuthPriv)

```iecst
ok := SNMP_CLIENT_CREATE_V3('secure_switch', '10.0.1.20',
    'snmpAdmin',            (* USM username *)
    'SHA',                  (* auth protocol: MD5 or SHA *)
    'authPass123!',         (* auth passphrase *)
    'AES',                  (* privacy protocol: DES or AES *)
    'privPass456!');        (* privacy passphrase *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique client identifier |
| `host` | STRING | IP address or hostname |
| `user` | STRING | USM username |
| `authProto` | STRING | `'MD5'` or `'SHA'` |
| `authPass` | STRING | Authentication passphrase (min 8 chars) |
| `privProto` | STRING | `'DES'` or `'AES'` |
| `privPass` | STRING | Privacy passphrase (min 8 chars) |

**Returns:** `BOOL` -- TRUE on success.

> **Security Note:** SNMPv3 with AuthPriv encrypts the entire PDU. Use this for any SNMP communication crossing untrusted networks. Community strings in v1/v2c travel in plaintext.

#### SNMP_CLIENT_CONNECT -- Establish Connection

```iecst
ok := SNMP_CLIENT_CONNECT('ups1');
```

Opens the UDP socket and starts the background poll loop. The client automatically polls all OIDs retrieved via `SNMP_GET` on a configurable interval, caching results for fast access from cyclic ST programs.

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_CLIENT_DISCONNECT -- Close Connection

```iecst
ok := SNMP_CLIENT_DISCONNECT('ups1');
```

Stops polling and closes the UDP socket. The client can be reconnected later with `SNMP_CLIENT_CONNECT`.

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_CLIENT_IS_CONNECTED -- Check Status

```iecst
IF SNMP_CLIENT_IS_CONNECTED('ups1') THEN
    (* Safe to read cached values *)
END_IF;
```

**Returns:** `BOOL` -- TRUE if connected and polling.

---

### 2.2 Reading Values

#### SNMP_GET -- Read Single OID (from Poll Cache)

```iecst
(* Using built-in OID constant *)
descr := SNMP_GET('ups1', SNMP_OID_SYS_DESCR);
(* Returns: 'APC Smart-UPS 3000 RM' *)

(* Using dotted OID string *)
voltage := SNMP_GET('ups1', '1.3.6.1.2.1.33.1.3.3.1.3.1');
(* Returns: 120 (integer) *)

(* Using built-in UPS constant *)
load := SNMP_GET('ups1', SNMP_OID_UPS_OUTPUT_LOAD);
(* Returns: 47 (percent) *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client name |
| `oidStr` | STRING | OID in dotted notation or built-in constant |

**Returns:** `ANY` -- The value from the poll cache. Type depends on the MIB object: STRING for DisplayString, INT for Integer32/Gauge32/Counter32, etc.

> **Important:** `SNMP_GET` reads from the local poll cache, not the network. This makes it safe to call from fast cyclic tasks (1-10ms) without blocking. The background poller updates the cache asynchronously.

#### SNMP_GET_MULTIPLE -- Read Multiple OIDs at Once

```iecst
result := SNMP_GET_MULTIPLE('ups1', 
    SNMP_OID_SYS_NAME + ',' + SNMP_OID_SYS_UPTIME + ',' + SNMP_OID_UPS_BATTERY_STATUS);
(* Returns: MAP with OID keys and their values *)
(* {"1.3.6.1.2.1.1.5.0": "UPS-DC-RACK1", 
     "1.3.6.1.2.1.1.3.0": 8640000, 
     "1.3.6.1.2.1.33.1.2.1.0": 2} *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client name |
| `oidStrs` | STRING | Comma-separated OID strings |

**Returns:** `MAP` -- OID-to-value mapping from cache.

#### SNMP_GET_NEXT -- Get Next OID in Tree

```iecst
result := SNMP_GET_NEXT('ups1', '1.3.6.1.2.1.1.1');
(* Returns: MAP with "oid" and "value" keys *)
(* {"oid": "1.3.6.1.2.1.1.1.0", "value": "APC Smart-UPS 3000"} *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client name |
| `oidStr` | STRING | Starting OID |

**Returns:** `MAP` -- Contains `oid` (the next OID) and `value`.

#### SNMP_WALK -- Walk an OID Subtree (BulkWalk)

```iecst
(* Walk the entire interface table *)
interfaces := SNMP_WALK('switch1', SNMP_OID_IF_TABLE);
(* Returns: []MAP — array of {oid, value} pairs *)
(* [{"oid": "1.3.6.1.2.1.2.2.1.1.1", "value": 1},
     {"oid": "1.3.6.1.2.1.2.2.1.2.1", "value": "GigabitEthernet0/1"},
     {"oid": "1.3.6.1.2.1.2.2.1.5.1", "value": 1000000000},
     ...] *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client name |
| `rootOidStr` | STRING | Root OID to walk from |

**Returns:** `[]MAP` -- Array of `{oid, value}` pairs. Uses SNMP GETBULK (v2c/v3) for efficiency.

> **Performance:** Walk operations are not cached — they execute a live SNMP BulkWalk on the network. Use them for discovery or infrequent polling, not in fast cyclic tasks.

---

### 2.3 Convenience Getters

These wrap `SNMP_GET` with the appropriate system OID for cleaner code:

```iecst
descr    := SNMP_GET_SYS_DESCR('ups1');      (* System description *)
name     := SNMP_GET_SYS_NAME('ups1');       (* Device hostname *)
uptime   := SNMP_GET_SYS_UPTIME('ups1');     (* Uptime in hundredths of seconds *)
location := SNMP_GET_SYS_LOCATION('ups1');   (* Physical location string *)
contact  := SNMP_GET_SYS_CONTACT('ups1');    (* Admin contact string *)
```

Each returns the same type as the underlying `SNMP_GET` call.

---

### 2.4 Writing Values

#### SNMP_SET -- Write a Value to a Remote Device

```iecst
(* Set the system contact string *)
ok := SNMP_SET('switch1', SNMP_OID_SYS_CONTACT, 'OctetString', 'ops@example.com');

(* Set an integer value *)
ok := SNMP_SET('pdu1', '1.3.6.1.4.1.318.1.1.4.4.2.1.3.1', 'Integer', 1);
(* APC PDU: outlet 1 immediate ON *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client name |
| `oidStr` | STRING | Target OID |
| `valueType` | STRING | SNMP type: `'Integer'`, `'OctetString'`, `'ObjectIdentifier'`, `'IPAddress'`, `'Counter32'`, `'Gauge32'`, `'TimeTicks'` |
| `value` | ANY | Value to write |

**Returns:** `BOOL` -- TRUE on success.

> **Write Access:** Most devices require a read-write community string (often `'private'`). SNMPv3 write access depends on USM user VACM configuration on the target device.

---

### 2.5 Client Management

#### SNMP_CLIENT_GET_STATS -- Connection Statistics

```iecst
stats := SNMP_CLIENT_GET_STATS('ups1');
(* Returns: MAP *)
(* {"requests_sent": 1847, "responses_received": 1845, 
     "timeouts": 2, "errors": 0, "last_poll_ms": 3} *)
```

**Returns:** `MAP` -- Request counts, error counts, and timing.

#### SNMP_CLIENT_DELETE -- Remove Client

```iecst
ok := SNMP_CLIENT_DELETE('ups1');
```

Disconnects (if connected) and removes the client instance. Frees all associated resources.

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_CLIENT_LIST -- List All Clients

```iecst
clients := SNMP_CLIENT_LIST();
(* Returns: ['ups1', 'pdu1', 'switch1'] *)
```

**Returns:** List of client names.

---

## 3. Trap Receiver

The trap receiver listens for asynchronous SNMP notifications (traps and informs) from managed devices. Incoming traps are buffered in a ring buffer that your ST program drains on each scan cycle.

### 3.1 Trap Lifecycle

#### SNMP_TRAP_START -- Start Listening

```iecst
(* Listen on standard trap port with default community *)
ok := SNMP_TRAP_START('datacenter_traps', 162);

(* Restrict to specific communities *)
ok := SNMP_TRAP_START('secure_traps', 1162, 'monitoring-rw,datacenter-ro');
```

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | STRING | (required) | Unique receiver identifier |
| `port` | INT | (required) | UDP listen port (162 = standard, use 1162+ if unprivileged) |
| `communities` | STRING | (all) | Comma-separated allowed community strings; empty = accept all |

**Returns:** `BOOL` -- TRUE on success.

> **Port 162:** On Linux, binding to ports below 1024 requires root or `CAP_NET_BIND_SERVICE`. Run GoPLC with appropriate capabilities or use a port above 1024.

#### SNMP_TRAP_STOP -- Stop Listening

```iecst
ok := SNMP_TRAP_STOP('datacenter_traps');
```

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_TRAP_IS_RUNNING -- Check Receiver Status

```iecst
IF SNMP_TRAP_IS_RUNNING('datacenter_traps') THEN
    (* Receiver is active *)
END_IF;
```

**Returns:** `BOOL` -- TRUE if listening.

#### SNMP_TRAP_GET_STATS -- Receiver Statistics

```iecst
stats := SNMP_TRAP_GET_STATS('datacenter_traps');
(* Returns: MAP *)
(* {"traps_received": 42, "traps_dropped": 0, 
     "buffer_size": 1000, "buffer_used": 3} *)
```

**Returns:** `MAP` -- Trap counts and buffer utilization.

---

### 3.2 Reading Traps

#### SNMP_TRAP_GET_BUFFER -- Drain All Buffered Traps

```iecst
traps := SNMP_TRAP_GET_BUFFER('datacenter_traps');
(* Returns: []MAP — array of trap records *)
(* [{"timestamp": "2026-04-03T14:22:01Z",
      "source": "10.0.1.50",
      "community": "public",
      "enterprise": "1.3.6.1.4.1.318",
      "generic_trap": 6,
      "specific_trap": 1,
      "varbinds": [
          {"oid": "1.3.6.1.2.1.33.1.2.1.0", "type": "Integer", "value": 3},
          {"oid": "1.3.6.1.2.1.33.1.2.2.0", "type": "Integer", "value": 45}
      ]},
     ...] *)
```

**Returns:** `[]MAP` -- Array of trap records. Each contains:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | STRING | ISO 8601 receive time |
| `source` | STRING | Sender IP address |
| `community` | STRING | Community string from trap PDU |
| `enterprise` | STRING | Enterprise OID (v1 traps) |
| `generic_trap` | INT | Generic trap type (v1) or SNMPv2 notification OID |
| `specific_trap` | INT | Enterprise-specific trap code (v1) |
| `varbinds` | []MAP | Variable bindings: `{oid, type, value}` |

> **Buffer Behavior:** `SNMP_TRAP_GET_BUFFER` returns all buffered traps and clears them atomically. Call it once per scan cycle to avoid processing duplicates.

#### SNMP_TRAP_GET_COUNT -- Check Buffer Depth

```iecst
count := SNMP_TRAP_GET_COUNT('datacenter_traps');
IF count > 0 THEN
    traps := SNMP_TRAP_GET_BUFFER('datacenter_traps');
    (* Process traps *)
END_IF;
```

**Returns:** `INT` -- Number of traps currently buffered.

#### SNMP_TRAP_CLEAR_BUFFER -- Discard All Buffered Traps

```iecst
SNMP_TRAP_CLEAR_BUFFER('datacenter_traps');
```

Discards all buffered traps without processing. Useful after reconnection or during initialization when stale traps are not relevant.

---

## 4. Agent (Server) Functions

The SNMP agent exposes GoPLC data as an OID tree that any NMS or monitoring tool can poll. You register OIDs with typed values, and the agent responds to GET/GETNEXT/GETBULK requests automatically.

### 4.1 Agent Lifecycle

#### SNMP_AGENT_CREATE -- Create Agent

```iecst
(* Minimal — defaults to community "public" *)
ok := SNMP_AGENT_CREATE('plc_agent', 1161);

(* Full configuration *)
ok := SNMP_AGENT_CREATE('plc_agent', 1161, 'monitoring-ro',
    'GoPLC v1.0.533 SNMP Agent',   (* sysDescr *)
    'PLC-RACK1');                    (* sysName *)
```

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | STRING | (required) | Unique agent identifier |
| `port` | INT | (required) | UDP listen port |
| `community` | STRING | `'public'` | Required community string for access |
| `sysDescr` | STRING | `''` | Value returned for sysDescr.0 OID |
| `sysName` | STRING | `''` | Value returned for sysName.0 OID |

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_AGENT_START -- Begin Serving

```iecst
ok := SNMP_AGENT_START('plc_agent');
```

Starts the UDP listener. The agent responds to SNMP GET, GETNEXT, and GETBULK requests for any OID you have registered.

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_AGENT_STOP -- Stop Serving

```iecst
ok := SNMP_AGENT_STOP('plc_agent');
```

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_AGENT_IS_RUNNING -- Check Status

```iecst
IF SNMP_AGENT_IS_RUNNING('plc_agent') THEN
    (* Agent is serving requests *)
END_IF;
```

**Returns:** `BOOL` -- TRUE if listening.

---

### 4.2 Setting OID Values

Register OIDs and update their values from your ST program. The agent serves these values to any NMS that polls them.

#### SNMP_AGENT_SET_INT -- Set Integer OID

```iecst
(* Expose production count as a standard integer *)
ok := SNMP_AGENT_SET_INT('plc_agent', '1.3.6.1.4.1.99999.1.1.0', production_count);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Agent name |
| `oidStr` | STRING | OID to register/update |
| `value` | INT | Integer value |

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_AGENT_SET_GAUGE -- Set Gauge32 OID

```iecst
(* Expose temperature — Gauge32 never wraps, suitable for measurements *)
ok := SNMP_AGENT_SET_GAUGE('plc_agent', '1.3.6.1.4.1.99999.1.2.0', tank_temp_x10);
```

Gauge32 values represent a current measurement that can increase or decrease (temperature, pressure, level). Unlike Counter32, they do not wrap.

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_AGENT_SET_COUNTER -- Set Counter32 OID

```iecst
(* Expose total parts — Counter32 monotonically increases and wraps at 2^32 *)
ok := SNMP_AGENT_SET_COUNTER('plc_agent', '1.3.6.1.4.1.99999.1.3.0', total_parts);
```

Counter32 values represent monotonically increasing counts (packets, parts, errors). NMS tools calculate rates from counter deltas.

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_AGENT_SET_STR -- Set OctetString OID

```iecst
(* Expose machine state as a human-readable string *)
ok := SNMP_AGENT_SET_STR('plc_agent', '1.3.6.1.4.1.99999.1.4.0', 'RUNNING');

(* Expose alarm description *)
ok := SNMP_AGENT_SET_STR('plc_agent', '1.3.6.1.4.1.99999.1.5.0', active_alarm_text);
```

**Returns:** `BOOL` -- TRUE on success.

---

### 4.3 Reading OID Values

#### SNMP_AGENT_GET_INT -- Read Back an Integer OID

```iecst
current := SNMP_AGENT_GET_INT('plc_agent', '1.3.6.1.4.1.99999.1.1.0');
```

**Returns:** `INT` -- Current value of the registered OID. Returns 0 if the OID is not registered.

---

### 4.4 Agent Management

#### SNMP_AGENT_DELETE -- Remove Agent

```iecst
ok := SNMP_AGENT_DELETE('plc_agent');
```

Stops (if running) and removes the agent instance.

**Returns:** `BOOL` -- TRUE on success.

#### SNMP_AGENT_LIST -- List All Agents

```iecst
agents := SNMP_AGENT_LIST();
(* Returns: ['plc_agent'] *)
```

**Returns:** List of agent names.

---

## 5. Enterprise OID Design

When exposing PLC data via the SNMP agent, you need a private enterprise OID subtree. Register one at [IANA PEN](https://pen.iana.org/) or use a test range.

### Recommended OID Layout

```
1.3.6.1.4.1.<YOUR_PEN>
  .1  — System
    .1.0  sysState        INTEGER   (0=Stopped, 1=Running, 2=Faulted)
    .2.0  sysVersion      STRING    "1.0.520"
    .3.0  sysScanTimeUs   Gauge32   (scan cycle in microseconds)
  .2  — Process
    .1.0  processTemp     Gauge32   (temperature x10)
    .2.0  processPressure Gauge32   (pressure x100)
    .3.0  processLevel    Gauge32   (level percent x10)
  .3  — Counters
    .1.0  totalParts      Counter32
    .2.0  totalRejects    Counter32
    .3.0  totalRunHours   Counter32
  .4  — Alarms
    .1.0  activeAlarmCount  INTEGER
    .2.0  lastAlarmText     STRING
    .3.0  lastAlarmTime     STRING  (ISO 8601)
```

> **OID Tip:** Always end leaf OIDs with `.0` (scalar instance). Table entries use `.1.N` indexing. NMS tools expect this convention.

---

## 6. Application Examples

### 6.1 Datacenter UPS Monitoring

Monitor an APC Smart-UPS, log battery status, and trigger alarms on power events.

```iecst
PROGRAM POU_UPS_Monitor
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    battery_status : INT;
    input_voltage : INT;
    output_load : INT;
    ups_name : STRING;
    alarm_active : BOOL := FALSE;
END_VAR

IF NOT initialized THEN
    ok := SNMP_CLIENT_CREATE('ups1', '10.0.1.50', 161, 'datacenter-ro', 'v2c');
    ok := SNMP_CLIENT_CONNECT('ups1');
    initialized := TRUE;
    RETURN;
END_IF;

IF NOT SNMP_CLIENT_IS_CONNECTED('ups1') THEN
    ok := SNMP_CLIENT_CONNECT('ups1');
    RETURN;
END_IF;

(* Read UPS values from poll cache — non-blocking *)
battery_status := SNMP_GET('ups1', SNMP_OID_UPS_BATTERY_STATUS);
input_voltage  := SNMP_GET('ups1', SNMP_OID_UPS_INPUT_VOLTAGE);
output_load    := SNMP_GET('ups1', SNMP_OID_UPS_OUTPUT_LOAD);
ups_name       := SNMP_GET_SYS_NAME('ups1');

(* Battery status: 1=unknown, 2=normal, 3=low, 4=depleted *)
IF battery_status <> 2 THEN
    alarm_active := TRUE;
    (* Trigger plant-wide alarm via Modbus, MQTT, etc. *)
END_IF;

(* Overload protection *)
IF output_load > 80 THEN
    (* Log warning — UPS load above 80% *)
END_IF;

END_PROGRAM
```

### 6.2 PDU Outlet Control

Control APC PDU outlets via SNMP SET to remotely power-cycle equipment.

```iecst
PROGRAM POU_PDU_Control
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    outlet_state : INT;
    reboot_request : BOOL;     (* From HMI *)
    target_outlet : INT := 1;  (* Outlet number *)
END_VAR

CONST
    (* APC PDU rPDU2OutletSwitchedStatusOutletState *)
    APC_OUTLET_STATUS := '1.3.6.1.4.1.318.1.1.26.9.2.3.1.5.1.';
    (* APC PDU rPDU2OutletSwitchedControlCommand *)
    APC_OUTLET_CMD    := '1.3.6.1.4.1.318.1.1.26.9.2.4.1.5.1.';
    (* Commands: 1=immediateOn, 2=immediateOff, 3=immediateReboot *)
END_CONST

IF NOT initialized THEN
    ok := SNMP_CLIENT_CREATE('pdu1', '10.0.1.51', 161, 'datacenter-rw', 'v2c');
    ok := SNMP_CLIENT_CONNECT('pdu1');
    initialized := TRUE;
    RETURN;
END_IF;

(* Read outlet status *)
outlet_state := SNMP_GET('pdu1', CONCAT(APC_OUTLET_STATUS, INT_TO_STRING(target_outlet)));
(* 1=on, 2=off *)

(* HMI-triggered reboot *)
IF reboot_request THEN
    ok := SNMP_SET('pdu1',
        CONCAT(APC_OUTLET_CMD, INT_TO_STRING(target_outlet)),
        'Integer', 3);    (* 3 = immediateReboot *)
    reboot_request := FALSE;
END_IF;

END_PROGRAM
```

### 6.3 Network Switch Interface Monitoring

Walk the interface table to detect link-down conditions.

```iecst
PROGRAM POU_Switch_Monitor
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    interfaces : ARRAY[0..99] OF STRING;
    walk_result : ARRAY[0..999] OF STRING;  (* []MAP from walk *)
    walk_timer : TON;
    link_down_count : INT := 0;
END_VAR

CONST
    (* ifOperStatus: 1=up, 2=down, 3=testing *)
    IF_OPER_STATUS := '1.3.6.1.2.1.2.2.1.8';
END_CONST

IF NOT initialized THEN
    ok := SNMP_CLIENT_CREATE('switch1', '10.0.1.1', 161, 'monitoring-ro', 'v2c');
    ok := SNMP_CLIENT_CONNECT('switch1');
    initialized := TRUE;
END_IF;

(* Walk interface status every 30 seconds — not every scan *)
walk_timer(IN := TRUE, PT := T#30s);
IF walk_timer.Q THEN
    walk_timer(IN := FALSE);

    walk_result := SNMP_WALK('switch1', IF_OPER_STATUS);

    link_down_count := 0;
    FOR i := 0 TO UPPER_BOUND(walk_result, 1) DO
        IF walk_result[i].value = 2 THEN
            link_down_count := link_down_count + 1;
        END_IF;
    END_FOR;
END_IF;

END_PROGRAM
```

### 6.4 SNMPv3 Secure Monitoring

Poll a managed switch using authenticated and encrypted SNMPv3.

```iecst
PROGRAM POU_SNMPv3_Monitor
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    sys_descr : STRING;
    sys_uptime : DINT;
    if_count : INT;
END_VAR

IF NOT initialized THEN
    (* Create v3 client with SHA auth + AES privacy *)
    ok := SNMP_CLIENT_CREATE_V3('core_switch', '10.0.1.1',
        'goplc_monitor',     (* USM user — must exist on the switch *)
        'SHA',               (* auth protocol *)
        'MyAuthPhrase99!',   (* auth passphrase *)
        'AES',               (* privacy protocol *)
        'MyPrivPhrase88!');  (* privacy passphrase *)

    ok := SNMP_CLIENT_CONNECT('core_switch');
    initialized := TRUE;
    RETURN;
END_IF;

(* Same read functions work regardless of SNMP version *)
sys_descr  := SNMP_GET_SYS_DESCR('core_switch');
sys_uptime := SNMP_GET_SYS_UPTIME('core_switch');
if_count   := SNMP_GET('core_switch', SNMP_OID_IF_NUMBER);

END_PROGRAM
```

> **Switch-Side Config (Cisco IOS example):**
> ```
> snmp-server group GOPLC_GROUP v3 priv
> snmp-server user goplc_monitor GOPLC_GROUP v3 auth sha MyAuthPhrase99! priv aes 128 MyPrivPhrase88!
> ```

### 6.5 Trap-Driven Alarm Handling

Receive SNMP traps from UPS and switches, classify them, and route to the alarm system.

```iecst
PROGRAM POU_Trap_Handler
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    traps : ARRAY[0..99] OF STRING;  (* []MAP *)
    trap_count : INT;
    i : INT;
    alarm_level : INT;
END_VAR

CONST
    (* APC UPS enterprise OID *)
    APC_ENTERPRISE := '1.3.6.1.4.1.318';
    (* Common generic trap types *)
    TRAP_LINK_DOWN := 2;
    TRAP_LINK_UP   := 3;
    TRAP_ENTERPRISE := 6;  (* enterprise-specific *)
END_CONST

IF NOT initialized THEN
    ok := SNMP_TRAP_START('dc_traps', 1162, 'datacenter-ro,monitoring-rw');
    initialized := TRUE;
    RETURN;
END_IF;

(* Check for new traps every scan *)
trap_count := SNMP_TRAP_GET_COUNT('dc_traps');
IF trap_count = 0 THEN
    RETURN;
END_IF;

(* Drain the buffer *)
traps := SNMP_TRAP_GET_BUFFER('dc_traps');

FOR i := 0 TO trap_count - 1 DO
    (* Classify by generic trap type *)
    CASE traps[i].generic_trap OF
        2: (* linkDown *)
            alarm_level := 2;  (* Warning *)
            (* Log: interface down on traps[i].source *)

        3: (* linkUp *)
            alarm_level := 0;  (* Clear *)
            (* Log: interface restored on traps[i].source *)

        6: (* Enterprise-specific *)
            IF traps[i].enterprise = APC_ENTERPRISE THEN
                (* APC-specific trap — check specific_trap code *)
                CASE traps[i].specific_trap OF
                    1:  alarm_level := 3;  (* UPS on battery — Critical *)
                    2:  alarm_level := 0;  (* UPS back on line — Clear *)
                    3:  alarm_level := 3;  (* UPS low battery — Critical *)
                END_CASE;
            END_IF;
    END_CASE;
END_FOR;

END_PROGRAM
```

### 6.6 Exposing PLC Data via SNMP Agent

Make GoPLC process data visible to Nagios, Zabbix, or any NMS.

```iecst
PROGRAM POU_SNMP_Agent
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    (* Process values — updated by other programs *)
    tank_temp : REAL;
    tank_level : REAL;
    production_count : DINT;
    reject_count : DINT;
    machine_state : INT;
    alarm_text : STRING;
END_VAR

CONST
    PEN := '1.3.6.1.4.1.99999';  (* Your IANA Private Enterprise Number *)
END_CONST

IF NOT initialized THEN
    ok := SNMP_AGENT_CREATE('plc_agent', 1161, 'monitoring-ro',
        'GoPLC SNMP Agent - Plant Floor PLC', 'PLC-LINE1');
    ok := SNMP_AGENT_START('plc_agent');
    initialized := TRUE;
END_IF;

(* Update OIDs every scan — agent serves latest values *)
SNMP_AGENT_SET_INT('plc_agent',     CONCAT(PEN, '.1.1.0'), machine_state);
SNMP_AGENT_SET_STR('plc_agent',     CONCAT(PEN, '.1.2.0'), 'v1.0.533');
SNMP_AGENT_SET_GAUGE('plc_agent',   CONCAT(PEN, '.2.1.0'), REAL_TO_INT(tank_temp * 10.0));
SNMP_AGENT_SET_GAUGE('plc_agent',   CONCAT(PEN, '.2.2.0'), REAL_TO_INT(tank_level * 10.0));
SNMP_AGENT_SET_COUNTER('plc_agent', CONCAT(PEN, '.3.1.0'), production_count);
SNMP_AGENT_SET_COUNTER('plc_agent', CONCAT(PEN, '.3.2.0'), reject_count);
SNMP_AGENT_SET_STR('plc_agent',     CONCAT(PEN, '.4.1.0'), alarm_text);

END_PROGRAM
```

**Nagios check command:**
```bash
# Check machine state (expect 1=Running)
check_snmp -H 10.0.0.196 -p 1161 -C monitoring-ro -o 1.3.6.1.4.1.99999.1.1.0 -w 1:1 -c 0:0

# Check tank temperature (warn >800 = 80.0C, crit >900 = 90.0C)
check_snmp -H 10.0.0.196 -p 1161 -C monitoring-ro -o 1.3.6.1.4.1.99999.2.1.0 -w :800 -c :900
```

### 6.7 Combined: Full Datacenter Monitoring Stack

A single GoPLC program that monitors UPS + PDU, receives traps, and serves aggregated status to NMS.

```iecst
PROGRAM POU_DC_Monitor
VAR
    initialized : BOOL := FALSE;
    ok : BOOL;
    (* UPS readings *)
    ups_battery : INT;
    ups_voltage : INT;
    ups_load : INT;
    (* PDU readings *)
    pdu_total_amps : INT;
    (* Trap processing *)
    trap_count : INT;
    traps : ARRAY[0..99] OF STRING;
    (* Aggregated status *)
    dc_health : INT := 1;   (* 1=OK, 2=Warning, 3=Critical *)
    alarm_msg : STRING := 'All systems normal';
END_VAR

IF NOT initialized THEN
    (* Client: poll UPS and PDU *)
    ok := SNMP_CLIENT_CREATE('ups1', '10.0.1.50', 161, 'datacenter-ro', 'v2c');
    ok := SNMP_CLIENT_CONNECT('ups1');
    ok := SNMP_CLIENT_CREATE('pdu1', '10.0.1.51', 161, 'datacenter-ro', 'v2c');
    ok := SNMP_CLIENT_CONNECT('pdu1');

    (* Trap receiver: catch async alerts *)
    ok := SNMP_TRAP_START('dc_traps', 1162);

    (* Agent: serve aggregated status to NMS *)
    ok := SNMP_AGENT_CREATE('dc_agent', 1161, 'monitoring-ro',
        'GoPLC DC Monitor', 'DC-MONITOR-1');
    ok := SNMP_AGENT_START('dc_agent');

    initialized := TRUE;
    RETURN;
END_IF;

(* ---- Read UPS ---- *)
ups_battery := SNMP_GET('ups1', SNMP_OID_UPS_BATTERY_STATUS);
ups_voltage := SNMP_GET('ups1', SNMP_OID_UPS_INPUT_VOLTAGE);
ups_load    := SNMP_GET('ups1', SNMP_OID_UPS_OUTPUT_LOAD);

(* ---- Read PDU ---- *)
pdu_total_amps := SNMP_GET('pdu1', '1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.1');

(* ---- Process traps ---- *)
trap_count := SNMP_TRAP_GET_COUNT('dc_traps');
IF trap_count > 0 THEN
    traps := SNMP_TRAP_GET_BUFFER('dc_traps');
    (* Classify and escalate — see Example 6.5 *)
END_IF;

(* ---- Compute health ---- *)
dc_health := 1;
alarm_msg := 'All systems normal';

IF ups_battery = 3 THEN       (* Low battery *)
    dc_health := 3;
    alarm_msg := 'UPS BATTERY LOW';
ELSIF ups_battery <> 2 THEN   (* Not normal *)
    dc_health := 2;
    alarm_msg := 'UPS battery abnormal';
END_IF;

IF ups_load > 90 THEN
    dc_health := 3;
    alarm_msg := 'UPS OVERLOAD >90%';
ELSIF ups_load > 80 THEN
    IF dc_health < 2 THEN dc_health := 2; END_IF;
    alarm_msg := 'UPS load warning >80%';
END_IF;

(* ---- Expose to NMS ---- *)
SNMP_AGENT_SET_INT('dc_agent',     '1.3.6.1.4.1.99999.1.1.0', dc_health);
SNMP_AGENT_SET_STR('dc_agent',     '1.3.6.1.4.1.99999.1.2.0', alarm_msg);
SNMP_AGENT_SET_GAUGE('dc_agent',   '1.3.6.1.4.1.99999.2.1.0', ups_voltage);
SNMP_AGENT_SET_GAUGE('dc_agent',   '1.3.6.1.4.1.99999.2.2.0', ups_load);
SNMP_AGENT_SET_GAUGE('dc_agent',   '1.3.6.1.4.1.99999.2.3.0', pdu_total_amps);
SNMP_AGENT_SET_COUNTER('dc_agent', '1.3.6.1.4.1.99999.3.1.0', trap_count);

END_PROGRAM
```

---

## 7. Quick Reference

### Client Functions

| Function | Signature | Returns |
|----------|-----------|---------|
| `SNMP_CLIENT_CREATE` | `(name, host [, port] [, community] [, version])` | BOOL |
| `SNMP_CLIENT_CREATE_V3` | `(name, host, user, authProto, authPass, privProto, privPass)` | BOOL |
| `SNMP_CLIENT_CONNECT` | `(name)` | BOOL |
| `SNMP_CLIENT_DISCONNECT` | `(name)` | BOOL |
| `SNMP_CLIENT_IS_CONNECTED` | `(name)` | BOOL |
| `SNMP_GET` | `(name, oidStr)` | ANY |
| `SNMP_GET_MULTIPLE` | `(name, oidStrs)` | MAP |
| `SNMP_GET_NEXT` | `(name, oidStr)` | MAP |
| `SNMP_SET` | `(name, oidStr, valueType, value)` | BOOL |
| `SNMP_WALK` | `(name, rootOidStr)` | []MAP |
| `SNMP_GET_SYS_DESCR` | `(name)` | STRING |
| `SNMP_GET_SYS_NAME` | `(name)` | STRING |
| `SNMP_GET_SYS_UPTIME` | `(name)` | DINT |
| `SNMP_GET_SYS_LOCATION` | `(name)` | STRING |
| `SNMP_GET_SYS_CONTACT` | `(name)` | STRING |
| `SNMP_CLIENT_GET_STATS` | `(name)` | MAP |
| `SNMP_CLIENT_DELETE` | `(name)` | BOOL |
| `SNMP_CLIENT_LIST` | `()` | LIST |

### Trap Receiver Functions

| Function | Signature | Returns |
|----------|-----------|---------|
| `SNMP_TRAP_START` | `(name, port [, communities])` | BOOL |
| `SNMP_TRAP_STOP` | `(name)` | BOOL |
| `SNMP_TRAP_IS_RUNNING` | `(name)` | BOOL |
| `SNMP_TRAP_GET_STATS` | `(name)` | MAP |
| `SNMP_TRAP_GET_BUFFER` | `(name)` | []MAP |
| `SNMP_TRAP_GET_COUNT` | `(name)` | INT |
| `SNMP_TRAP_CLEAR_BUFFER` | `(name)` | — |

### Agent Functions

| Function | Signature | Returns |
|----------|-----------|---------|
| `SNMP_AGENT_CREATE` | `(name, port [, community] [, sysDescr] [, sysName])` | BOOL |
| `SNMP_AGENT_START` | `(name)` | BOOL |
| `SNMP_AGENT_STOP` | `(name)` | BOOL |
| `SNMP_AGENT_IS_RUNNING` | `(name)` | BOOL |
| `SNMP_AGENT_SET_INT` | `(name, oidStr, value)` | BOOL |
| `SNMP_AGENT_SET_GAUGE` | `(name, oidStr, value)` | BOOL |
| `SNMP_AGENT_SET_COUNTER` | `(name, oidStr, value)` | BOOL |
| `SNMP_AGENT_SET_STR` | `(name, oidStr, value)` | BOOL |
| `SNMP_AGENT_GET_INT` | `(name, oidStr)` | INT |
| `SNMP_AGENT_DELETE` | `(name)` | BOOL |
| `SNMP_AGENT_LIST` | `()` | LIST |

### OID Constants

| Constant | OID |
|----------|-----|
| `SNMP_OID_SYS_DESCR` | 1.3.6.1.2.1.1.1.0 |
| `SNMP_OID_SYS_OBJECT_ID` | 1.3.6.1.2.1.1.2.0 |
| `SNMP_OID_SYS_UPTIME` | 1.3.6.1.2.1.1.3.0 |
| `SNMP_OID_SYS_CONTACT` | 1.3.6.1.2.1.1.4.0 |
| `SNMP_OID_SYS_NAME` | 1.3.6.1.2.1.1.5.0 |
| `SNMP_OID_SYS_LOCATION` | 1.3.6.1.2.1.1.6.0 |
| `SNMP_OID_IF_NUMBER` | 1.3.6.1.2.1.2.1.0 |
| `SNMP_OID_IF_TABLE` | 1.3.6.1.2.1.2.2 |
| `SNMP_OID_UPS_BATTERY_STATUS` | 1.3.6.1.2.1.33.1.2.1.0 |
| `SNMP_OID_UPS_INPUT_VOLTAGE` | 1.3.6.1.2.1.33.1.3.3.1.3.1 |
| `SNMP_OID_UPS_OUTPUT_LOAD` | 1.3.6.1.2.1.33.1.4.4.1.5.1 |

---

*GoPLC v1.0.533 | SNMP v1/v2c/v3 Client, Trap Receiver, Agent*
*Client: ~18 functions | Trap Receiver: 7 functions | Agent: ~11 functions*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
