# GoPLC OPC UA Protocol Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC implements OPC UA as both a **client** and a **server**, giving you two distinct roles in a single runtime. The client connects outward to PLCs, historians, and SCADA gateways (Kepware, Ignition, Beckhoff TwinCAT). The server exposes GoPLC's variables as OPC UA nodes so that any compliant client can read and subscribe.

Both roles are programmed entirely in IEC 61131-3 Structured Text. No external configuration files are required — you can create connections, map nodes, and start servers from ST code alone (though YAML config is also supported).

| Role | Direction | Use Case |
|------|-----------|----------|
| **Client** | GoPLC --> remote server | Read sensors from Kepware, write setpoints to Ignition, browse Beckhoff address space |
| **Server** | Remote client --> GoPLC | Expose process data to SCADA, let Ignition poll GoPLC tags, feed a historian |

### System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  GoPLC Runtime (Go, any Linux/Windows host)                 │
│                                                             │
│  ┌─────────────────────┐     ┌─────────────────────────┐   │
│  │ OPC UA Client       │     │ OPC UA Server            │   │
│  │                     │     │                          │   │
│  │ CREATE / CONNECT    │     │ CREATE / START           │   │
│  │ READ_REAL / BROWSE  │     │ SET_INT / SET_REAL       │   │
│  │ WRITE_BOOL          │     │ GET_BOOL / GET_STRING    │   │
│  └──────────┬──────────┘     └──────────┬───────────────┘   │
│             │                           │                   │
└─────────────┼───────────────────────────┼───────────────────┘
              │ opc.tcp://...             │ opc.tcp://0.0.0.0:4840
              ▼                           ▼
┌──────────────────────┐     ┌────────────────────────────┐
│  Remote OPC UA Server│     │  Remote OPC UA Client      │
│                      │     │                            │
│  Kepware TEX Server  │     │  Ignition Gateway          │
│  Ignition Gateway    │     │  Grafana OPC UA plugin     │
│  Beckhoff TwinCAT    │     │  UaExpert / Prosys browser │
│  Siemens S7 OPC UA   │     │  Custom .NET / Python app  │
└──────────────────────┘     └────────────────────────────┘
```

---

## 2. OPC UA Client

The client side provides 20 functions covering the full lifecycle: create, connect, map nodes, read/write typed values, browse the remote address space, and clean up.

### 2.1 Connection Management

#### OPCUA_CLIENT_CREATE -- Create Client Instance

```iecst
(* Minimal — no security *)
ok := OPCUA_CLIENT_CREATE('kepware', 'opc.tcp://10.0.0.50:49320');

(* With security policy and mode *)
ok := OPCUA_CLIENT_CREATE('ignition', 'opc.tcp://10.0.0.60:4840',
                          'Basic256Sha256', 'SignAndEncrypt');
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique instance name (used by all subsequent calls) |
| `endpoint` | STRING | Full OPC UA endpoint URL |
| `policy` | STRING | *(optional)* Security policy: `'None'`, `'Basic256Sha256'` |
| `mode` | STRING | *(optional)* Message security mode: `'None'`, `'Sign'`, `'SignAndEncrypt'` |

Returns `TRUE` on success. Fails if the name is already in use.

> **Security defaults:** When `policy` and `mode` are omitted, the client connects with `SecurityPolicy#None` and `MessageSecurityMode#None`. This is fine for isolated plant networks but should never be used across untrusted network segments.

#### OPCUA_CLIENT_CONNECT -- Establish Session

```iecst
IF OPCUA_CLIENT_CONNECT('kepware') THEN
    state := 10;  (* connected *)
END_IF;
```

Opens a TCP connection and activates an OPC UA session. This is a blocking call — it will return `FALSE` if the server is unreachable or rejects the security handshake.

#### OPCUA_CLIENT_DISCONNECT -- Close Session

```iecst
OPCUA_CLIENT_DISCONNECT('kepware');
```

Gracefully closes the session and TCP connection. The client instance remains configured and can be reconnected.

#### OPCUA_CLIENT_IS_CONNECTED -- Check Session State

```iecst
IF NOT OPCUA_CLIENT_IS_CONNECTED('kepware') THEN
    (* reconnect logic *)
    state := 1;
END_IF;
```

Returns `TRUE` if the session is active. Use this in your scan loop to detect dropped connections.

#### OPCUA_CLIENT_DELETE -- Destroy Client Instance

```iecst
OPCUA_CLIENT_DELETE('kepware');
```

Disconnects (if connected) and frees all resources. The instance name becomes available for reuse.

#### OPCUA_CLIENT_LIST -- Enumerate All Clients

```iecst
clients := OPCUA_CLIENT_LIST();
(* Returns: ['kepware', 'ignition', 'beckhoff'] *)
```

Returns an array of all client instance names. Useful for diagnostics and cleanup.

#### OPCUA_CLIENT_GET_ENDPOINT -- Get Configured Endpoint

```iecst
url := OPCUA_CLIENT_GET_ENDPOINT('kepware');
(* Returns: 'opc.tcp://10.0.0.50:49320' *)
```

---

### 2.2 Node Management

#### OPCUA_CLIENT_ADD_NODE -- Map a Remote Node to a Local Tag

```iecst
ok := OPCUA_CLIENT_ADD_NODE('kepware', 'Temperature',
                            'ns=2;s=Channel1.Device1.Temperature',
                            'REAL', FALSE);

ok := OPCUA_CLIENT_ADD_NODE('kepware', 'Setpoint',
                            'ns=2;s=Channel1.Device1.Setpoint',
                            'REAL', TRUE);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client instance name |
| `tag` | STRING | Local tag name for this mapping |
| `nodeID` | STRING | OPC UA Node ID (e.g. `'ns=2;s=Tag1'` or `'ns=2;i=1001'`) |
| `dataType` | STRING | Expected data type: `'BOOL'`, `'INT'`, `'REAL'`, `'STRING'` |
| `writable` | BOOL | `TRUE` if this node should be writable |

Returns `TRUE` on success. Node mappings persist for the lifetime of the client instance.

> **Node ID formats:** OPC UA supports several Node ID encodings. The two most common are string-based (`ns=2;s=MyTag`) used by Kepware and Ignition, and numeric (`ns=2;i=1001`) used by Beckhoff and Siemens. The `ns` is the namespace index — namespace 0 is the OPC UA standard namespace, namespace 2+ are vendor/user-defined.

#### OPCUA_CLIENT_GET_MAPPINGS -- List All Node Mappings

```iecst
mappings := OPCUA_CLIENT_GET_MAPPINGS('kepware');
(* Returns: [
     {"tag": "Temperature", "nodeID": "ns=2;s=Channel1.Device1.Temperature",
      "dataType": "REAL", "writable": false},
     {"tag": "Setpoint", "nodeID": "ns=2;s=Channel1.Device1.Setpoint",
      "dataType": "REAL", "writable": true}
   ] *)
```

Returns an array of maps describing each registered node mapping.

---

### 2.3 Reading Nodes

GoPLC provides both a generic read and four typed reads. The typed reads avoid the overhead of runtime type inspection and return the correct ST data type directly.

#### OPCUA_CLIENT_READ_NODE -- Generic Read (Any Type)

```iecst
value := OPCUA_CLIENT_READ_NODE('kepware', 'ns=2;s=Channel1.Device1.Temperature');
```

Returns the node value as `ANY`. The runtime infers the OPC UA data type from the server's response.

#### OPCUA_CLIENT_READ_BOOL -- Read Boolean

```iecst
running := OPCUA_CLIENT_READ_BOOL('kepware', 'ns=2;s=Channel1.Device1.Running');
```

#### OPCUA_CLIENT_READ_INT -- Read Integer

```iecst
speed := OPCUA_CLIENT_READ_INT('kepware', 'ns=2;s=Channel1.Device1.SpeedRPM');
```

Handles OPC UA Int16, Int32, UInt16, and UInt32 transparently.

#### OPCUA_CLIENT_READ_REAL -- Read Floating Point

```iecst
temp := OPCUA_CLIENT_READ_REAL('kepware', 'ns=2;s=Channel1.Device1.Temperature');
```

Handles both OPC UA Float and Double.

#### OPCUA_CLIENT_READ_STRING -- Read String

```iecst
product := OPCUA_CLIENT_READ_STRING('kepware', 'ns=2;s=Channel1.Device1.ProductID');
```

---

### 2.4 Writing Nodes

Symmetric to reads. Each write returns `TRUE` on success.

#### OPCUA_CLIENT_WRITE_NODE -- Generic Write

```iecst
ok := OPCUA_CLIENT_WRITE_NODE('kepware', 'ns=2;s=Channel1.Device1.Setpoint', 72.5);
```

#### OPCUA_CLIENT_WRITE_BOOL

```iecst
ok := OPCUA_CLIENT_WRITE_BOOL('kepware', 'ns=2;s=Channel1.Device1.Enable', TRUE);
```

#### OPCUA_CLIENT_WRITE_INT

```iecst
ok := OPCUA_CLIENT_WRITE_INT('kepware', 'ns=2;s=Channel1.Device1.SpeedCmd', 1750);
```

#### OPCUA_CLIENT_WRITE_REAL

```iecst
ok := OPCUA_CLIENT_WRITE_REAL('kepware', 'ns=2;s=Channel1.Device1.TempSetpoint', 75.0);
```

#### OPCUA_CLIENT_WRITE_STRING

```iecst
ok := OPCUA_CLIENT_WRITE_STRING('kepware', 'ns=2;s=Channel1.Device1.Recipe', 'BATCH_42');
```

---

### 2.5 Browsing the Address Space

#### OPCUA_CLIENT_BROWSE -- Discover Child Nodes

```iecst
children := OPCUA_CLIENT_BROWSE('kepware', 'ns=2;s=Channel1.Device1');
(* Returns: ['Temperature', 'Pressure', 'SpeedRPM', 'Running', 'Setpoint'] *)
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Client instance name |
| `nodeID` | STRING | Parent node to browse from. Use `'i=85'` for the Objects folder (root). |

Returns an array of child node names. Use this to explore an unfamiliar server's address space interactively or to build dynamic tag discovery logic.

> **Browsing Kepware:** Start at `'i=85'` (Objects folder), then drill into the channel name, then device name. Kepware exposes tags as `Channel.Device.TagName`.

> **Browsing Ignition:** Ignition's default tag provider appears under `ns=2`. Browse from `'ns=2;s=[default]'` to see the tag tree.

---

### 2.6 Example: Full Client Lifecycle

```iecst
PROGRAM POU_OPCUAClient
VAR
    state       : INT := 0;
    connected   : BOOL;
    temperature : REAL;
    pressure    : REAL;
    running     : BOOL;
    setpoint    : REAL := 75.0;
    write_ok    : BOOL;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* CREATE — one-time init *)
        IF OPCUA_CLIENT_CREATE('kepware', 'opc.tcp://10.0.0.50:49320') THEN
            state := 1;
        END_IF;

    1: (* CONNECT *)
        IF OPCUA_CLIENT_CONNECT('kepware') THEN
            state := 10;
        END_IF;

    10: (* RUNNING — read/write every scan *)
        connected := OPCUA_CLIENT_IS_CONNECTED('kepware');
        IF NOT connected THEN
            state := 1;  (* reconnect *)
        END_IF;

        (* Read process values *)
        temperature := OPCUA_CLIENT_READ_REAL('kepware', 'ns=2;s=Channel1.Device1.Temperature');
        pressure    := OPCUA_CLIENT_READ_REAL('kepware', 'ns=2;s=Channel1.Device1.Pressure');
        running     := OPCUA_CLIENT_READ_BOOL('kepware', 'ns=2;s=Channel1.Device1.Running');

        (* Write setpoint *)
        write_ok := OPCUA_CLIENT_WRITE_REAL('kepware', 'ns=2;s=Channel1.Device1.TempSetpoint', setpoint);

        cycles := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

---

## 3. OPC UA Server

The server side provides 16 functions. You create a server, start it, and then use typed Set/Get calls to publish and read back variable values. Nodes are auto-created on first `Set` call — no manual node registration required.

### 3.1 Server Lifecycle

#### OPCUA_SERVER_CREATE -- Create Server Instance

```iecst
ok := OPCUA_SERVER_CREATE('main', 4840);
```

| Param | Type | Description |
|-------|------|-------------|
| `name` | STRING | Unique server instance name |
| `port` | INT | TCP port to listen on (4840 is the IANA-assigned OPC UA default) |

Returns `TRUE` on success. The server is created but not yet listening.

#### OPCUA_SERVER_START -- Begin Listening

```iecst
ok := OPCUA_SERVER_START('main');
```

Binds to the configured port and begins accepting OPC UA client connections. The endpoint URL will be `opc.tcp://<host-ip>:<port>`.

#### OPCUA_SERVER_STOP -- Stop Listening

```iecst
ok := OPCUA_SERVER_STOP('main');
```

Closes all active client sessions and stops accepting new connections. The server instance and its node configuration are preserved.

#### OPCUA_SERVER_IS_RUNNING -- Check Server State

```iecst
IF NOT OPCUA_SERVER_IS_RUNNING('main') THEN
    OPCUA_SERVER_START('main');
END_IF;
```

#### OPCUA_SERVER_DELETE -- Destroy Server Instance

```iecst
OPCUA_SERVER_DELETE('main');
```

Stops the server (if running) and frees all resources.

#### OPCUA_SERVER_LIST -- Enumerate All Servers

```iecst
servers := OPCUA_SERVER_LIST();
(* Returns: ['main', 'backup'] *)
```

#### OPCUA_SERVER_GET_ENDPOINT -- Get Endpoint URL

```iecst
url := OPCUA_SERVER_GET_ENDPOINT('main');
(* Returns: 'opc.tcp://10.0.0.196:4840' *)
```

Returns the full endpoint URL. Useful for logging or passing to other systems.

#### OPCUA_SERVER_GET_STATS -- Server Statistics

```iecst
stats := OPCUA_SERVER_GET_STATS('main');
(* Returns JSON:
   {"sessions": 2, "nodes": 15, "reads": 48210, "writes": 312,
    "uptime_s": 86400, "errors": 0} *)
```

Returns a JSON string with runtime statistics. Parse with GoPLC's JSON functions for alarming or dashboarding.

---

### 3.2 Setting Variables (Publishing Data)

Each `Set` call writes a value to the server's address space. If the node does not exist, it is **automatically created** with the correct OPC UA data type. Subsequent calls update the value in place.

#### OPCUA_SERVER_SET_INT

```iecst
ok := OPCUA_SERVER_SET_INT('main', 'SpeedRPM', 1750);
```

#### OPCUA_SERVER_SET_REAL

```iecst
ok := OPCUA_SERVER_SET_REAL('main', 'Temperature', 72.5);
```

#### OPCUA_SERVER_SET_BOOL

```iecst
ok := OPCUA_SERVER_SET_BOOL('main', 'MotorRunning', TRUE);
```

#### OPCUA_SERVER_SET_STRING

```iecst
ok := OPCUA_SERVER_SET_STRING('main', 'ActiveRecipe', 'BATCH_42');
```

> **Auto-create behavior:** The first time you call `SET_REAL('main', 'Temperature', ...)`, the server creates an OPC UA Variable node named `Temperature` with data type `Float` under the server's Objects folder. Remote clients immediately see the new node without restart or reconfiguration.

---

### 3.3 Getting Variables (Reading Back)

These read the current value from the server's address space. Useful when remote clients write values that your ST logic needs to consume (e.g., setpoints from a SCADA operator screen).

#### OPCUA_SERVER_GET_INT

```iecst
sp := OPCUA_SERVER_GET_INT('main', 'SpeedSetpoint');
```

#### OPCUA_SERVER_GET_REAL

```iecst
temp_sp := OPCUA_SERVER_GET_REAL('main', 'TempSetpoint');
```

#### OPCUA_SERVER_GET_BOOL

```iecst
enable := OPCUA_SERVER_GET_BOOL('main', 'RemoteEnable');
```

#### OPCUA_SERVER_GET_STRING

```iecst
recipe := OPCUA_SERVER_GET_STRING('main', 'RecipeCommand');
```

---

### 3.4 Example: Expose Process Data to SCADA

```iecst
PROGRAM POU_OPCUAServer
VAR
    state       : INT := 0;
    (* Process values — updated by control logic *)
    temperature : REAL := 72.5;
    pressure    : REAL := 14.7;
    motor_on    : BOOL := FALSE;
    speed_rpm   : INT := 0;
    (* Setpoints — written by remote SCADA clients *)
    temp_sp     : REAL;
    speed_sp    : INT;
    remote_en   : BOOL;
END_VAR

CASE state OF
    0: (* CREATE and START — one-time init *)
        IF OPCUA_SERVER_CREATE('scada', 4840) THEN
            IF OPCUA_SERVER_START('scada') THEN
                state := 10;
            END_IF;
        END_IF;

    10: (* RUNNING — publish process values every scan *)
        (* Publish current process state *)
        OPCUA_SERVER_SET_REAL('scada', 'Temperature', temperature);
        OPCUA_SERVER_SET_REAL('scada', 'Pressure', pressure);
        OPCUA_SERVER_SET_BOOL('scada', 'MotorRunning', motor_on);
        OPCUA_SERVER_SET_INT('scada', 'SpeedRPM', speed_rpm);

        (* Read setpoints written by SCADA operators *)
        temp_sp   := OPCUA_SERVER_GET_REAL('scada', 'TempSetpoint');
        speed_sp  := OPCUA_SERVER_GET_INT('scada', 'SpeedSetpoint');
        remote_en := OPCUA_SERVER_GET_BOOL('scada', 'RemoteEnable');

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

---

## 4. Security Policies

OPC UA defines three security levels. GoPLC supports all of them via the optional parameters on `OPCUA_CLIENT_CREATE`.

| Policy | Mode | Wire Encryption | Authentication | Use Case |
|--------|------|-----------------|----------------|----------|
| `None` | `None` | No | Anonymous | Isolated plant networks, development |
| `Basic256Sha256` | `Sign` | No | Certificates | Tamper detection without encryption overhead |
| `Basic256Sha256` | `SignAndEncrypt` | AES-256 | Certificates | Production — untrusted segments, compliance |

### 4.1 No Security (Default)

```iecst
ok := OPCUA_CLIENT_CREATE('dev', 'opc.tcp://10.0.0.50:4840');
```

Equivalent to passing `'None', 'None'`. No certificates, no encryption. Messages are plaintext on the wire.

### 4.2 Sign Only

```iecst
ok := OPCUA_CLIENT_CREATE('audit', 'opc.tcp://10.0.0.50:4840',
                          'Basic256Sha256', 'Sign');
```

Messages include a SHA-256 signature so tampering is detected, but payload is unencrypted. Lower CPU overhead than full encryption — suitable when eavesdropping is not a concern but integrity matters.

### 4.3 Sign and Encrypt

```iecst
ok := OPCUA_CLIENT_CREATE('secure', 'opc.tcp://10.0.0.50:4840',
                          'Basic256Sha256', 'SignAndEncrypt');
```

Full AES-256 encryption plus SHA-256 signatures. Required for compliance with IEC 62443 and most enterprise security policies.

> **Certificate management:** When using `Basic256Sha256`, GoPLC auto-generates a self-signed certificate on first use. For production, replace the auto-generated cert with a CA-signed certificate via the runtime configuration. The remote server must trust GoPLC's certificate (add it to the server's trusted certificates store).

---

## 5. Connecting to Common Platforms

### 5.1 Kepware KEPServerEX

Kepware is the most common OPC UA gateway in industrial environments. It exposes PLC tags through channels and devices.

```iecst
PROGRAM POU_Kepware
VAR
    state : INT := 0;
    temp  : REAL;
    valve : BOOL;
END_VAR

CASE state OF
    0: (* Kepware default port is 49320 *)
        IF OPCUA_CLIENT_CREATE('kep', 'opc.tcp://10.0.0.50:49320') THEN
            state := 1;
        END_IF;

    1:
        IF OPCUA_CLIENT_CONNECT('kep') THEN
            state := 10;
        END_IF;

    10: (* Node IDs follow Channel.Device.Tag pattern *)
        temp  := OPCUA_CLIENT_READ_REAL('kep', 'ns=2;s=Modbus.PLC1.Temperature');
        valve := OPCUA_CLIENT_READ_BOOL('kep', 'ns=2;s=Modbus.PLC1.ValveOpen');

        IF NOT OPCUA_CLIENT_IS_CONNECTED('kep') THEN
            state := 1;
        END_IF;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

**Kepware tips:**
- Default OPC UA port: **49320**
- Node IDs are `ns=2;s=ChannelName.DeviceName.TagName`
- Enable the OPC UA server interface in Kepware's project properties
- For browsing, start at `'i=85'` (Objects folder) then drill into channels

### 5.2 Ignition by Inductive Automation

Ignition exposes its tag providers as OPC UA namespaces.

```iecst
PROGRAM POU_Ignition
VAR
    state   : INT := 0;
    level   : REAL;
    alarm   : BOOL;
    sp      : REAL := 50.0;
END_VAR

CASE state OF
    0: (* Ignition default OPC UA port is 4096, though 4840 is common *)
        IF OPCUA_CLIENT_CREATE('ign', 'opc.tcp://10.0.0.60:4096') THEN
            state := 1;
        END_IF;

    1:
        IF OPCUA_CLIENT_CONNECT('ign') THEN
            state := 10;
        END_IF;

    10: (* Ignition tags: ns=2, path starts with [provider] *)
        level := OPCUA_CLIENT_READ_REAL('ign', 'ns=2;s=[default]Tank/Level');
        alarm := OPCUA_CLIENT_READ_BOOL('ign', 'ns=2;s=[default]Tank/HighAlarm');

        OPCUA_CLIENT_WRITE_REAL('ign', 'ns=2;s=[default]Tank/Setpoint', sp);

        IF NOT OPCUA_CLIENT_IS_CONNECTED('ign') THEN
            state := 1;
        END_IF;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

**Ignition tips:**
- Default OPC UA endpoint: `opc.tcp://<host>:4096` (configurable in Gateway settings)
- Tag paths use `/` as separator: `[default]Folder/Subfolder/Tag`
- The `[default]` prefix is the tag provider name
- Enable "OPC UA Server" module in the Ignition Gateway

### 5.3 Beckhoff TwinCAT 3

TwinCAT exposes PLC variables through its OPC UA Server (TS6100).

```iecst
PROGRAM POU_Beckhoff
VAR
    state    : INT := 0;
    encoder  : DINT;
    axis_pos : REAL;
    servo_en : BOOL;
END_VAR

CASE state OF
    0: (* TwinCAT OPC UA default port: 4840 *)
        IF OPCUA_CLIENT_CREATE('tc3', 'opc.tcp://10.0.0.34:4840') THEN
            state := 1;
        END_IF;

    1:
        IF OPCUA_CLIENT_CONNECT('tc3') THEN
            state := 10;
        END_IF;

    10: (* TwinCAT uses numeric node IDs: ns=4;s=MAIN.variableName *)
        encoder  := OPCUA_CLIENT_READ_INT('tc3', 'ns=4;s=MAIN.nEncoderCount');
        axis_pos := OPCUA_CLIENT_READ_REAL('tc3', 'ns=4;s=MAIN.fAxisPosition');
        servo_en := OPCUA_CLIENT_READ_BOOL('tc3', 'ns=4;s=MAIN.bServoEnable');

        IF NOT OPCUA_CLIENT_IS_CONNECTED('tc3') THEN
            state := 1;
        END_IF;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

**TwinCAT tips:**
- Install TF6100 (OPC UA Server) function in TwinCAT
- Variables must have the `{attribute 'OPC.UA.DA' := '1'}` pragma in TwinCAT ST
- Default namespace for PLC variables is `ns=4`
- Node IDs follow `ns=4;s=ProgramName.VariableName`
- TwinCAT supports `Basic256Sha256` — use `SignAndEncrypt` for production

---

## 6. Node Browsing

Browsing lets you explore a server's address space without knowing the exact Node IDs in advance. This is essential when integrating with unfamiliar systems.

### 6.1 Interactive Discovery

```iecst
PROGRAM POU_Browser
VAR
    state    : INT := 0;
    children : ARRAY[0..99] OF STRING;
END_VAR

CASE state OF
    0:
        IF OPCUA_CLIENT_CREATE('browse', 'opc.tcp://10.0.0.50:49320') THEN
            state := 1;
        END_IF;

    1:
        IF OPCUA_CLIENT_CONNECT('browse') THEN
            state := 10;
        END_IF;

    10: (* Browse the root Objects folder *)
        children := OPCUA_CLIENT_BROWSE('browse', 'i=85');
        (* Typical result: ['Server', 'Channel1', 'Channel2', '_System'] *)

        (* Drill deeper into Channel1 *)
        children := OPCUA_CLIENT_BROWSE('browse', 'ns=2;s=Channel1');
        (* Result: ['Device1', 'Device2'] *)

        (* Drill into Device1 *)
        children := OPCUA_CLIENT_BROWSE('browse', 'ns=2;s=Channel1.Device1');
        (* Result: ['Temperature', 'Pressure', 'Speed', 'Running'] *)

        state := 99;  (* done *)

    ELSE
        (* idle *)
END_CASE;
END_PROGRAM
```

### 6.2 Well-Known Starting Points

| Server | Root Browse Node | Notes |
|--------|-----------------|-------|
| **Any OPC UA server** | `'i=85'` | Objects folder — the universal starting point |
| **Kepware** | `'ns=2;s=ChannelName'` | One level per channel, then device, then tags |
| **Ignition** | `'ns=2;s=[default]'` | Tag provider name in brackets, then folder tree |
| **Beckhoff** | `'ns=4;s=MAIN'` | PLC program name, then variables |
| **Siemens** | `'ns=3;s="DataBlock"'` | DB names in quotes |

---

## 7. YAML Configuration

In addition to ST-based setup, you can configure OPC UA servers and clients in the GoPLC YAML config file. The YAML configuration starts the server/client automatically at runtime boot.

### 7.1 Server via YAML

```yaml
protocols:
  opcua:
    enabled: true
    port: 4840
    endpoint: "opc.tcp://0.0.0.0:4840/goplc"
    security_mode: None  # or: Sign, SignAndEncrypt
    # security_policy: Basic256Sha256
```

When `enabled: true`, the runtime creates and starts an OPC UA server automatically. Variables published via `OPCUA_SERVER_SET_*` calls in ST become visible to remote clients immediately.

### 7.2 Client via YAML

```yaml
protocols:
  opcua:
    enabled: true
    port: 4840

# Client connections are configured in ST code.
# The YAML config enables the OPC UA subsystem;
# CREATE/CONNECT calls in ST handle client instances.
```

---

## 8. Advanced Patterns

### 8.1 Multi-Server Client (Protocol Bridge)

Read from multiple OPC UA servers and consolidate data into a single GoPLC namespace. This is a common pattern for bridging isolated networks.

```iecst
PROGRAM POU_ProtocolBridge
VAR
    state   : INT := 0;
    (* Values from different servers *)
    boiler_temp  : REAL;
    chiller_temp : REAL;
    pump_running : BOOL;
END_VAR

CASE state OF
    0: (* Create clients to two different servers *)
        OPCUA_CLIENT_CREATE('boiler', 'opc.tcp://10.0.0.50:49320');
        OPCUA_CLIENT_CREATE('chiller', 'opc.tcp://10.0.1.50:4840');
        (* Create local server to republish *)
        OPCUA_SERVER_CREATE('bridge', 4841);
        OPCUA_SERVER_START('bridge');
        state := 1;

    1: (* Connect both *)
        IF OPCUA_CLIENT_CONNECT('boiler') AND OPCUA_CLIENT_CONNECT('chiller') THEN
            state := 10;
        END_IF;

    10: (* Read from both, republish on local server *)
        boiler_temp  := OPCUA_CLIENT_READ_REAL('boiler', 'ns=2;s=Boiler.Temperature');
        chiller_temp := OPCUA_CLIENT_READ_REAL('chiller', 'ns=2;s=Chiller.SupplyTemp');
        pump_running := OPCUA_CLIENT_READ_BOOL('boiler', 'ns=2;s=Boiler.PumpRunning');

        (* Republish to local OPC UA server *)
        OPCUA_SERVER_SET_REAL('bridge', 'BoilerTemp', boiler_temp);
        OPCUA_SERVER_SET_REAL('bridge', 'ChillerTemp', chiller_temp);
        OPCUA_SERVER_SET_BOOL('bridge', 'PumpRunning', pump_running);

        (* Reconnect handling *)
        IF NOT OPCUA_CLIENT_IS_CONNECTED('boiler') OR
           NOT OPCUA_CLIENT_IS_CONNECTED('chiller') THEN
            state := 1;
        END_IF;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

### 8.2 Bidirectional SCADA Gateway

GoPLC acts as both client (reading a PLC via Kepware) and server (exposing data to Ignition). Operator setpoints flow from Ignition through GoPLC into the PLC.

```iecst
PROGRAM POU_SCADAGateway
VAR
    state      : INT := 0;
    (* Process data — read from PLC via Kepware *)
    pv_temp    : REAL;
    pv_level   : REAL;
    pv_running : BOOL;
    (* Setpoints — written by Ignition operator *)
    sp_temp    : REAL;
    sp_level   : REAL;
    cmd_start  : BOOL;
END_VAR

CASE state OF
    0: (* Init everything *)
        OPCUA_CLIENT_CREATE('plc', 'opc.tcp://10.0.0.50:49320');
        OPCUA_SERVER_CREATE('scada', 4840);
        OPCUA_SERVER_START('scada');
        state := 1;

    1:
        IF OPCUA_CLIENT_CONNECT('plc') THEN
            state := 10;
        END_IF;

    10: (* Steady state *)
        (* Read from PLC *)
        pv_temp    := OPCUA_CLIENT_READ_REAL('plc', 'ns=2;s=Line1.Reactor.Temperature');
        pv_level   := OPCUA_CLIENT_READ_REAL('plc', 'ns=2;s=Line1.Reactor.Level');
        pv_running := OPCUA_CLIENT_READ_BOOL('plc', 'ns=2;s=Line1.Reactor.Running');

        (* Publish PVs to SCADA *)
        OPCUA_SERVER_SET_REAL('scada', 'Reactor_Temperature', pv_temp);
        OPCUA_SERVER_SET_REAL('scada', 'Reactor_Level', pv_level);
        OPCUA_SERVER_SET_BOOL('scada', 'Reactor_Running', pv_running);

        (* Read setpoints from SCADA operators *)
        sp_temp  := OPCUA_SERVER_GET_REAL('scada', 'Reactor_TempSetpoint');
        sp_level := OPCUA_SERVER_GET_REAL('scada', 'Reactor_LevelSetpoint');
        cmd_start := OPCUA_SERVER_GET_BOOL('scada', 'Reactor_StartCmd');

        (* Write setpoints back to PLC *)
        OPCUA_CLIENT_WRITE_REAL('plc', 'ns=2;s=Line1.Reactor.TempSP', sp_temp);
        OPCUA_CLIENT_WRITE_REAL('plc', 'ns=2;s=Line1.Reactor.LevelSP', sp_level);
        OPCUA_CLIENT_WRITE_BOOL('plc', 'ns=2;s=Line1.Reactor.StartCmd', cmd_start);

        IF NOT OPCUA_CLIENT_IS_CONNECTED('plc') THEN
            state := 1;
        END_IF;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

### 8.3 Node Mapping with Add Node

For performance-critical applications, pre-register nodes with `ADD_NODE` to enable batch operations and reduce per-read overhead.

```iecst
PROGRAM POU_MappedReads
VAR
    state : INT := 0;
    temp  : REAL;
    ok    : BOOL;
END_VAR

CASE state OF
    0:
        IF OPCUA_CLIENT_CREATE('kep', 'opc.tcp://10.0.0.50:49320') THEN
            state := 1;
        END_IF;

    1: (* Register node mappings before connecting *)
        ok := OPCUA_CLIENT_ADD_NODE('kep', 'Temperature',
                  'ns=2;s=Channel1.Device1.Temperature', 'REAL', FALSE);
        ok := OPCUA_CLIENT_ADD_NODE('kep', 'Setpoint',
                  'ns=2;s=Channel1.Device1.Setpoint', 'REAL', TRUE);
        ok := OPCUA_CLIENT_ADD_NODE('kep', 'Running',
                  'ns=2;s=Channel1.Device1.Running', 'BOOL', FALSE);
        state := 2;

    2:
        IF OPCUA_CLIENT_CONNECT('kep') THEN
            state := 10;
        END_IF;

    10: (* Read using mapped Node IDs *)
        temp := OPCUA_CLIENT_READ_REAL('kep', 'ns=2;s=Channel1.Device1.Temperature');

        IF NOT OPCUA_CLIENT_IS_CONNECTED('kep') THEN
            state := 2;
        END_IF;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
```

---

## 9. Diagnostics and Troubleshooting

### 9.1 Connection Failures

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `CREATE` returns `FALSE` | Duplicate instance name | Use a unique name or `DELETE` the existing one |
| `CONNECT` returns `FALSE` | Server unreachable | Verify endpoint URL, check firewall (TCP port), confirm server is running |
| `CONNECT` fails with security | Certificate not trusted | Add GoPLC's auto-generated cert to the server's trust store |
| `IS_CONNECTED` flips to `FALSE` | Session timeout or network drop | Implement reconnect logic in your state machine |
| Reads return zero/empty | Wrong Node ID or namespace | Use `BROWSE` to verify the exact node path |
| Writes return `FALSE` | Node is read-only on the server | Check server-side access permissions; verify `writable` flag in `ADD_NODE` |

### 9.2 Server Diagnostics

```iecst
(* Check server health *)
stats := OPCUA_SERVER_GET_STATS('main');
(* Parse error count *)
(* IF errors > last_errors THEN trigger alarm *)
```

### 9.3 Runtime Logging

Enable OPC UA debug logging in the YAML config:

```yaml
runtime:
  log_level: debug
  log_modules:
    - opcua
```

This produces per-message traces including connection attempts, session state changes, read/write operations, and security handshake details.

### 9.4 Common Node ID Mistakes

```
WRONG:  'ns=2;s=Channel1/Device1/Temperature'   (* forward slashes *)
RIGHT:  'ns=2;s=Channel1.Device1.Temperature'    (* Kepware uses dots *)

WRONG:  'ns=2;s=Temperature'                     (* missing path *)
RIGHT:  'ns=2;s=Channel1.Device1.Temperature'    (* full qualified path *)

WRONG:  'ns=2;i=Temperature'                     (* string in numeric ID *)
RIGHT:  'ns=2;i=1001'                            (* numeric must be integer *)
RIGHT:  'ns=2;s=Temperature'                     (* string uses 's=' *)
```

---

## Appendix A: Client Function Quick Reference

| Function | Signature | Returns |
|----------|-----------|---------|
| `OPCUA_CLIENT_CREATE` | `(name, endpoint [, policy] [, mode])` | `BOOL` |
| `OPCUA_CLIENT_CONNECT` | `(name)` | `BOOL` |
| `OPCUA_CLIENT_DISCONNECT` | `(name)` | `BOOL` |
| `OPCUA_CLIENT_IS_CONNECTED` | `(name)` | `BOOL` |
| `OPCUA_CLIENT_DELETE` | `(name)` | `BOOL` |
| `OPCUA_CLIENT_LIST` | `()` | `ARRAY` |
| `OPCUA_CLIENT_ADD_NODE` | `(name, tag, nodeID, dataType, writable)` | `BOOL` |
| `OPCUA_CLIENT_GET_MAPPINGS` | `(name)` | `ARRAY` |
| `OPCUA_CLIENT_GET_ENDPOINT` | `(name)` | `STRING` |
| `OPCUA_CLIENT_READ_NODE` | `(name, nodeID)` | `ANY` |
| `OPCUA_CLIENT_READ_BOOL` | `(name, nodeID)` | `BOOL` |
| `OPCUA_CLIENT_READ_INT` | `(name, nodeID)` | `INT` |
| `OPCUA_CLIENT_READ_REAL` | `(name, nodeID)` | `REAL` |
| `OPCUA_CLIENT_READ_STRING` | `(name, nodeID)` | `STRING` |
| `OPCUA_CLIENT_WRITE_NODE` | `(name, nodeID, value)` | `BOOL` |
| `OPCUA_CLIENT_WRITE_BOOL` | `(name, nodeID, value)` | `BOOL` |
| `OPCUA_CLIENT_WRITE_INT` | `(name, nodeID, value)` | `BOOL` |
| `OPCUA_CLIENT_WRITE_REAL` | `(name, nodeID, value)` | `BOOL` |
| `OPCUA_CLIENT_WRITE_STRING` | `(name, nodeID, value)` | `BOOL` |
| `OPCUA_CLIENT_BROWSE` | `(name, nodeID)` | `ARRAY` |

## Appendix B: Server Function Quick Reference

| Function | Signature | Returns |
|----------|-----------|---------|
| `OPCUA_SERVER_CREATE` | `(name, port)` | `BOOL` |
| `OPCUA_SERVER_START` | `(name)` | `BOOL` |
| `OPCUA_SERVER_STOP` | `(name)` | `BOOL` |
| `OPCUA_SERVER_IS_RUNNING` | `(name)` | `BOOL` |
| `OPCUA_SERVER_DELETE` | `(name)` | `BOOL` |
| `OPCUA_SERVER_LIST` | `()` | `ARRAY` |
| `OPCUA_SERVER_GET_ENDPOINT` | `(name)` | `STRING` |
| `OPCUA_SERVER_GET_STATS` | `(name)` | `STRING` (JSON) |
| `OPCUA_SERVER_SET_INT` | `(name, varName, value)` | `BOOL` |
| `OPCUA_SERVER_SET_REAL` | `(name, varName, value)` | `BOOL` |
| `OPCUA_SERVER_SET_BOOL` | `(name, varName, value)` | `BOOL` |
| `OPCUA_SERVER_SET_STRING` | `(name, varName, value)` | `BOOL` |
| `OPCUA_SERVER_GET_INT` | `(name, varName)` | `INT` |
| `OPCUA_SERVER_GET_REAL` | `(name, varName)` | `REAL` |
| `OPCUA_SERVER_GET_BOOL` | `(name, varName)` | `BOOL` |
| `OPCUA_SERVER_GET_STRING` | `(name, varName)` | `STRING` |

---

*GoPLC v1.0.533 | OPC UA Client (20 functions) + Server (16 functions)*
*Security: None, Basic256Sha256 (Sign, SignAndEncrypt)*

*(c) 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
