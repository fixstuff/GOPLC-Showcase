# GOPLC: The Operator's Revenge

**Technical White Paper | March 2026**

---

## Abstract

Every feature in GOPLC exists because its creator suffered through the alternative. Proprietary programming cables, $5,000 IDE licenses, firmware updates that require truck rolls, 300 PLCs with 300 different spare parts, licensing models that charge per device per protocol per seat per year — the operational reality of industrial automation is a landscape of pain that the industry has normalized.

GOPLC is a 49MB Go binary that replaces all of it. One binary. One browser. One API. One license. One JSON file to define an entire controller. This paper covers the operational story: how GOPLC eliminates every friction point in deploying, managing, securing, and scaling industrial control systems.

This is the companion paper to *GOPLC: Planetary Scale Determinism*, which covers the architecture and vision. This paper covers how you actually live with the thing.

---

## 1. The 49MB Binary

GOPLC ships as a single statically-linked Go binary with no external dependencies:

| Binary | Size |
|--------|------|
| `goplc` (amd64, release) | 49MB |
| `goplc` (arm64, release) | 48MB |
| Snap package (compressed) | 13-16MB |
| With Node-RED bundled | ~340MB total runtime memory |

That binary contains:

- IEC 61131-3 Structured Text interpreter with 1,450+ built-in functions
- Multi-task deadline scheduler with sub-millisecond accuracy
- 17 industrial protocol drivers (Modbus, OPC UA, EtherNet/IP, FINS, DNP3, IEC 104, BACnet, S7, SNMP, and more)
- Embedded MQTT broker (full broker, not just client)
- OPC UA server (auto-exposes all variables as OPC UA nodes)
- REST API with full CRUD for programs, tasks, variables, configuration
- WebSocket server for live variable streaming
- Web IDE with syntax highlighting, error markers, and integrated debug
- AI code assistant (natural language to ST generation)
- MCP server for AI model integration
- Fleet management UI
- Cluster engine (boss/minion with DataLayer)
- JWT authentication
- Project import/export (complete runtime definition as JSON)
- Node-RED integration (optional, same process)

No JVM. No Python. No Node.js (except for Node-RED if included). No container runtime. No orchestration framework. No license daemon. No database. Copy the binary, run it, open a browser. That's the deployment.

For comparison:

| Platform | What you install | Size | Dependencies |
|----------|-----------------|------|-------------|
| Siemens TIA Portal | Windows IDE + runtime | 15GB+ | Windows 10/11, SQL Server, .NET |
| CODESYS | IDE + runtime + gateway | 2GB+ | Windows, license dongle |
| Ignition (SCADA) | Gateway + modules | 1-2GB | JVM, database, web server |
| Node-RED standalone | Node.js + npm + packages | 200MB+ | Node.js runtime |
| **GOPLC** | **One binary** | **49MB** | **None** |

---

## 2. No Programming Software

### 2.1 The Browser Is the IDE

Every GOPLC runtime serves a full web IDE at `/ide/` on its API port. Open a browser, navigate to the runtime's address, start programming. Features:

- ST code editor with syntax highlighting and real-time error markers
- Program upload, task assignment, and hot-reload
- Live variable watch with WebSocket updates
- Task monitoring (scan count, average/last scan time, jitter, faults)
- Cluster management (view all minions, proxy API calls)
- Fleet management (discover and manage all connected runtimes)
- Built-in AI assistant for code generation and explanation
- Function reference (all 1,450+ functions browsable and searchable)

There is nothing to install on the engineer's machine. Any device with a browser — laptop, tablet, phone — is a programming terminal. Any operating system. Any network. No VPN required if the runtime is accessible.

### 2.2 The API Is the Programming Interface

Everything the IDE does, the API does. The IDE is just one consumer of the API:

```
POST   /api/programs                    — upload a new ST program
PUT    /api/programs/{name}             — modify an existing program
DELETE /api/programs/{name}             — remove a program
POST   /api/programs/validate           — check syntax without deploying
POST   /api/programs/estimate           — static scan time estimation
POST   /api/tasks                       — create a new task
PUT    /api/tasks/{name}/programs       — assign programs to a task
POST   /api/tasks/{name}/reload         — hot-reload one task
POST   /api/runtime/start               — start the runtime
GET    /api/variables                   — read all variable values
PUT    /api/variables/{name}            — write a variable
POST   /api/project/import              — import entire project (JSON)
POST   /api/cluster-ops/export          — export entire cluster state
```

An AI agent, a CI/CD pipeline, a Python script, a curl command, or a human in a browser — they all use the same endpoints with the same guarantees. There is no privileged access path. The API is the only interface.

### 2.3 No Proprietary Cable

Traditional PLCs require vendor-specific programming connections:

- Siemens: PROFINET or MPI cable + specific network configuration
- Allen-Bradley: USB, EtherNet/IP, or ControlNet + RSLinx driver
- Omron: USB, serial, or Ethernet + CX-Programmer
- Mitsubishi: USB, serial, or CC-Link + GX Works

GOPLC: standard HTTP over standard Ethernet. `curl http://10.0.0.45:8082/api/programs`. Done. The same network the runtime uses for protocol communication is the same network used for programming. No special cables, no special drivers, no special software.

---

## 3. Hot Loading

### 3.1 Per-Task Reload

Traditional PLCs stop the entire runtime to accept new programs. All outputs drop. All processes halt. In a running plant, this means scheduling a maintenance window — sometimes weeks in advance — for a one-line code change.

GOPLC reloads individual tasks without affecting others:

```
POST /api/tasks/MainTask/reload
```

MainTask stops, recompiles its programs, and restarts. ModbusTask, FINSTask, ENIPTask — they never stopped. Their scan cycles continued uninterrupted. The process they control never noticed.

This enables a development workflow that is impossible on traditional PLCs:

1. Engineer edits code in the browser IDE
2. Clicks "Save & Reload" — the affected task reloads in milliseconds
3. Variables update in real-time in the watch window
4. If something is wrong, edit and reload again — still milliseconds
5. Other tasks, other processes, other control loops: unaffected

No compilation step. No download step. No restart step. No "are you sure?" dialog with a 30-second timeout. Edit, reload, observe. The feedback loop is measured in milliseconds, not minutes.

### 3.2 Full Project Hot-Load

Beyond individual tasks, the entire project — config, programs, tasks, variables, protocols — can be replaced at runtime via the project import API:

```
POST /api/project/import
Content-Type: application/json

{"config": {...}, "programs": {...}, "gvl": {...}}
```

The runtime morphs into whatever the JSON defines. Different protocols, different tasks, different logic. No reboot. No reflash. The runtime has no permanent identity — it becomes whatever is deployed to it.

### 3.3 The Shapeshifter Model

This morphability has profound operational implications:

- **Spares inventory**: You don't stock spare PLCs matched by vendor and model. You stock servers. Any server running GOPLC can become any controller by importing the right project JSON.
- **Disaster recovery**: Export all projects to git. If a server dies, spin up a new one, import the projects, and the controllers exist again. Minutes, not days.
- **Seasonal operations**: A greenhouse controller in summer needs different logic than in winter. Push the seasonal project JSON via the API. No technician visit.
- **Multi-tenant**: One cluster serves multiple customers. Each minion runs a different customer's project. Onboard a new customer by adding a minion and importing their project JSON.

---

## 4. Integrated Debug

### 4.1 Debug Built Into Everything

Traditional PLC debugging requires adding watch tables, forcing values, and manually tracing logic through vendor-specific tools. It is a separate workflow from programming.

GOPLC builds debug into every layer:

- **Every built-in function** includes integrated debug output observable through the API. Not "add a breakpoint and hope you catch it" — the function tells you what it did, what it received, what it returned, automatically.
- **Variable watch**: All variables are always observable via the REST API and WebSocket. There is no "add to watch table" step. Every variable is always watchable.
- **Scan statistics**: Every task reports average scan time, last scan time, scan count, and fault status — live, through the API.
- **Diagnostics endpoint**: `GET /api/diagnostics` returns runtime state, memory usage, goroutine count, GC stats, driver status, connected protocols, and per-task health — in one call.
- **Fault reporting**: `GET /api/faults` returns all current and historical faults with timestamps, affected tasks, and error details.

### 4.2 AI-Assisted Diagnosis

The MCP server gives AI models structured access to all diagnostic information. An AI agent troubleshooting a problem can:

1. `goplc_faults` — see what's wrong
2. `goplc_diagnostics` — see runtime health
3. `goplc_variable_list` — see all state
4. `goplc_program_get` — read the code causing the issue
5. Reason about the problem using its training on control systems
6. `goplc_program_update` — deploy a fix
7. `goplc_task_start` — restart the affected task
8. Observe the result through `goplc_variable_get`

End-to-end diagnosis and repair without a human touching the system. The debug infrastructure that makes this possible is not a bolt-on — it is the same infrastructure the web IDE uses.

---

## 5. Security by Architecture

### 5.1 The Traditional Security Nightmare

Industrial control system security is catastrophically broken:

- **Modbus TCP**: Zero authentication. Any device on the network reads/writes any register on any PLC. Designed in 1979.
- **S7 (Siemens)**: Optional password protection, trivially bypassed. Default credentials well-known.
- **EtherNet/IP**: No encryption, no authentication on implicit messaging (fast I/O path).
- **FINS (Omron)**: UDP, no authentication, no encryption.
- **BACnet**: Optional authentication rarely enabled.
- **OPC UA**: Has security, but many implementations disable it for "ease of deployment."

A typical plant: 300 PLCs on a flat network, each with open protocol ports, many with default credentials, none with encrypted communications. One compromised laptop and an attacker can write arbitrary values to any actuator in the facility.

### 5.2 GOPLC's Security Model

GOPLC's security is architectural, not bolted on:

**One API endpoint.** The boss exposes one port. That is the entire attack surface. One IP address to firewall. One port to monitor. One authentication layer to enforce.

**Zero direct minion access.** Minions communicate via unix sockets (in-process cluster) or boss-proxied API calls (Docker cluster). They have no network listeners. You cannot reach a minion except through the authenticated boss API. There is no backdoor protocol. There is no "maintenance port." There is no telnet. There is no FTP. There is nothing except the one API.

**JWT token authentication.** Engineering endpoints (program deployment, task control, configuration changes) require JWT authentication. No passwords. No default credentials. Token-based auth with configurable expiration. Every API call is authenticated and every action is auditable.

**Engineering/operator separation.** Operators can view dashboards and adjust setpoints through the web IDE without credentials. Engineering operations require authentication. This mirrors the physical security model in plants (operators can press buttons; engineers need keys).

**Boss dies, minions die.** If the boss process terminates, all minions terminate. No orphaned runtimes running unmanaged on forgotten ports. The system is either managed or it's off. This eliminates the zombie controller problem that plagues traditional plants — PLCs running stale logic for years because nobody remembers they exist.

### 5.3 Scaling Security

At any scale — 10 minions or 10,000 — the security model is identical:

- 1 boss = 1 authenticated endpoint
- All minion access through boss proxy
- All actions authenticated and auditable
- No increase in attack surface with scale

Compare to scaling 10,000 traditional PLCs: 10,000 IP addresses, 10,000 open protocol ports, 10,000 potential attack surfaces, 10,000 devices that will never be patched.

---

## 6. Licensing: The Industry's Shame

### 6.1 How the Industry Charges

The traditional industrial automation licensing model:

**Siemens:**
| Item | Cost |
|------|------|
| TIA Portal Professional | $5,000 |
| Per-PLC runtime license | $500-5,000 |
| OPC UA server option | $800 |
| Safety option | $2,000 |
| Web server option | $500 |
| Per-seat engineering license | $5,000 |
| Annual maintenance | 20% of total |

**Allen-Bradley:**
| Item | Cost |
|------|------|
| Studio 5000 Standard | $7,000 |
| Per-controller (baked into hardware) | $10,000+ |
| FactoryTalk View (HMI) | $3,000 |
| FactoryTalk Historian | $15,000 |
| Per-connection license for add-ons | $200-500 each |

**CODESYS:**
| Item | Cost |
|------|------|
| Development system | $500 |
| Per-device runtime | $50-500 |
| Per-protocol add-on | varies |
| SoftMotion | $2,000 |
| Visualization | $500 |

For a 300-PLC plant: **$600,000 to $15,000,000** in licensing. Per year for maintenance. Forever.

### 6.2 How GOPLC Charges

**One license per boss.** That license covers:

- Unlimited minions under that boss
- Unlimited tasks per minion
- Unlimited programs per task
- Every protocol driver included
- Web IDE included — unlimited users
- AI assistant included
- MCP server included
- MQTT broker included
- OPC UA server included
- Fleet management included
- API access — unlimited clients
- No annual maintenance fee
- No per-seat charges
- No per-protocol add-ons
- No separate SCADA/HMI license

Pricing scales with cluster size. A boss managing 200 minions costs more than a standalone runtime. But at every tier, the total cost is a fraction of the traditional equivalent.

The economics align incentives: customers consolidate onto fewer, larger clusters and save more as they scale. Revenue comes from value delivered, not from artificial per-unit restrictions.

### 6.3 The Datacenter Play

For datacenters specifically, the licensing model creates a compelling business case:

| Scenario | Traditional | GOPLC |
|----------|------------|-------|
| 200 HVAC/power controllers | 200 PLCs + licenses = $200K-2M | 1 boss + 200 minions = fraction |
| Programming software | Per-seat, per-vendor = $20K-50K | $0 (browser) |
| Annual maintenance | 20% of everything, forever | $0 |
| Protocol add-ons | Per-PLC per-protocol | All included |
| SCADA/historian | Separate product, $50K-100K | Built-in (API + InfluxDB via ST) |
| Spare hardware | Match every PLC model | One server SKU |
| **Year 1 total** | **$500K - $3M+** | **Transformational savings** |

The customer doesn't just save money. They eliminate entire categories of cost that they've been told are unavoidable.

---

## 7. Fleet Management Built In

### 7.1 No Separate Management Layer

Traditional fleet management is a separate product:

- Siemens: SINEMA Server, additional license
- Rockwell: FactoryTalk AssetCentre, $50,000+
- Generic: SCADA system deployed above the controllers
- Each requires installation, configuration, licensing, maintenance

GOPLC builds fleet management into every runtime. Open a browser to any GOPLC instance and you see the fleet:

- Every runtime the instance is connected to
- Every task on every runtime — name, state, scan times, faults
- Every variable — current values, live updates
- Every protocol connection — status, health, error counts
- Cluster topology — boss, minions, DataLayer status

### 7.2 Every Node Is the Management Console

There is no single management server that, if it fails, blinds you. Every node can manage every other node. If one GOPLC instance is accessible, you can see and manage the entire fleet through its web UI.

For datacenter operators: walk up to any terminal, open a browser to any GOPLC endpoint, and you have full visibility and control over the entire facility's automation infrastructure. No credentials for the management system (operators can view). No VPN to a central server. No special client software.

### 7.3 Self-Describing Fabric

The fleet management capability means the system is self-describing. There is no separate asset inventory, no CMDB, no spreadsheet of "what's running where." Every runtime knows about its peers. The fabric is its own map.

For AI agents, this eliminates the discovery problem. The AI doesn't need to be told what exists. It queries any boss and discovers the entire cluster topology, every minion, every task, every variable, every protocol. The fabric tells the AI what it is.

---

## 8. Zero-Downtime Lifecycle

### 8.1 Rolling Upgrades

Traditional PLC firmware upgrades:

1. Schedule maintenance window (weeks of coordination)
2. Send technician to physical location
3. Connect proprietary programming cable
4. Back up project (hope software versions match)
5. Flash firmware (runtime stops, outputs drop)
6. Reload project (hope compatibility)
7. Test manually
8. Repeat for each PLC
9. Discover PLC #247 has different firmware branch

GOPLC:

```bash
# Deploy new binary to server
# Start new cluster alongside old cluster on different port

# For every node in the cluster:
curl -s $OLD:8082/api/cluster-ops/export > node.json
curl -s -X POST $NEW:8083/api/cluster-ops/import -d @node.json

# Verify all tasks running on new cluster
curl -s $NEW:8083/api/tasks | jq '.[] | .name, .state'

# Cut over network traffic
# Shut down old cluster

# Zero downtime. Zero truck rolls. Zero prayer.
```

### 8.2 Version Control Via Git

Every project is a JSON file. Every program is a text file. Git handles the rest:

```bash
# Export current state
curl -s $BOSS/api/cluster-ops/export > cluster-state.json
git add cluster-state.json
git commit -m "production state 2026-03-05"

# Roll back to any point in history
git checkout abc123 -- cluster-state.json
curl -s -X POST $BOSS/api/cluster-ops/import -d @cluster-state.json

# Diff any two deployments
git diff HEAD~3..HEAD -- cluster-state.json
```

The entire operational history of the automation system is a git repository. Every change is tracked. Every state is recoverable. Every deployment is auditable.

### 8.3 Autonomous AI Lifecycle Management

At scale, the AI manages the upgrade lifecycle:

1. Detects new binary version available
2. Spins up parallel cluster on new binary
3. Migrates projects node by node, verifying each
4. Runs old and new simultaneously, comparing outputs
5. Confidence reaches 100% → cuts over
6. Any anomaly → old cluster still running, instant rollback

250 million runtimes upgraded. Zero downtime. Zero physical access. Zero maintenance windows. Every project state is a git commit.

---

## 9. The ST Language: A Rich Vocabulary

### 9.1 Beyond Traditional PLC

Traditional PLC languages provide the minimum: math, timers, counters, basic string operations, and maybe a PID function block. Anything beyond that requires leaving the PLC — calling out to middleware, scripts, or external systems.

GOPLC's Structured Text includes 1,450+ built-in functions:

| Category | Examples | Traditional PLC? |
|----------|---------|-----------------|
| JSON | `JSON_PARSE`, `JSON_EXTRACT_REAL`, `JSON_BUILD` | No — requires middleware |
| HTTP | `HTTP_GET`, `HTTP_POST`, `HTTP_PUT` | No — requires middleware |
| Crypto | `SHA256`, `HMAC_SHA256`, `AES_ENCRYPT` | No — not available |
| Regex | `REGEX_MATCH`, `REGEX_REPLACE`, `REGEX_EXTRACT` | No — not available |
| File I/O | `FILE_READ`, `FILE_WRITE`, `FILE_APPEND` | No — not available |
| Data structures | Maps, queues, stacks, sorted arrays | No — basic arrays only |
| Resilience | Retry patterns, circuit breakers, timeouts | No — not available |
| Motion | Inverse kinematics, trajectory planning | Expensive add-on ($2,000+) |
| DateTime | Real-time operations, formatting, zones | Basic TON/TOF timers only |
| Math | 100+ functions including OSCAT library | Partial |
| String | 50+ manipulation functions | Basic only |
| Protocol | Modbus, OPC UA, FINS, ENIP, BACnet, S7, DNP3, IEC104, MQTT from ST | Gateway required per protocol |
| Database | InfluxDB writes directly from ST | Requires historian license |

A controls engineer who needs to parse a JSON payload from a REST API, validate a field with regex, compute an HMAC for data integrity, and log the result to InfluxDB would need four separate systems on a traditional PLC. On GOPLC, that's five lines of ST executing in a single scan cycle.

### 9.2 Designed for AI Authorship

The rich function library was a deliberate design choice with AI in mind:

- An AI with perfect recall benefits from more tools, not fewer
- High-level builtins (`JSON_EXTRACT`, `HTTP_GET`, `REGEX_MATCH`) mean fewer lines of generated code
- Fewer lines means fewer bugs, faster deployment, easier review
- The language is still standard IEC 61131-3 ST — any controls engineer can read what the AI wrote
- AI writes it, human audits it, scan engine executes it deterministically

This is a language designed for **AI authorship with human auditability and deterministic execution** — three properties nobody else optimizes for simultaneously.

---

## 10. Node-RED Integration

GOPLC includes optional Node-RED integration in the same process:

| Concern | GOPLC | Node-RED |
|---------|-------|----------|
| Deterministic control | Scan engine, guaranteed timing | Not designed for it |
| Visual service wiring | Not its strength | Drag and drop |
| Industrial protocols | Native ST functions, proven | Community nodes, variable quality |
| IT integration (email, Slack, DB) | Possible but verbose in ST | One node each |
| Dashboards | Variable watch, diagnostic views | Full UI builder |
| Real-time PID | Built for it | Would never attempt it |

GOPLC handles what *must* happen on time. Node-RED handles what *should* happen when things change:

- Temperature crosses threshold → GOPLC trips the interlock (same scan cycle)
- Node-RED sends the email, logs to InfluxDB, posts to Slack, updates the dashboard

Node-RED reads and writes the same variables through the same API. It is not a separate system — it is another consumer of the same fabric. The AI agent, the web IDE, Node-RED, and a Python script all see the same variables, the same API, the same guarantees.

Determinism where it matters. Flexibility everywhere else. One binary.

---

## 11. The Complete Picture

### 11.1 What One Binary Replaces

| Traditional Product | License Cost | GOPLC Equivalent |
|-------------------|-------------|-----------------|
| PLC hardware (×N) | $3,000-50,000 each | Commodity server |
| Programming software | $5,000-7,000/seat | Browser (included) |
| Protocol gateways | $500-2,000 each | Built into binary |
| OPC UA server | $800/device | Built into binary |
| MQTT broker | $0-5,000 (infrastructure cost) | Built into binary |
| SCADA software | $3,000-50,000 | API + web IDE |
| Historian | $15,000-100,000 | InfluxDB via ST (included) |
| Fleet management | $10,000-50,000 | Built into every runtime |
| AI integration | Does not exist | MCP server + AI assistant |
| Redundancy hardware | Match every PLC | One extra server |
| Programming cables | $50-500 each | Not applicable |
| Annual maintenance | 20% of everything | Not applicable |

### 11.2 The Operational Difference

```
Traditional: Buy hardware → Install software → Configure network →
             Connect cable → Create project → Download → Test →
             Repeat for each PLC → Schedule maintenance windows →
             Stock spare parts → Pay annual licenses → Pray

GOPLC:       Copy binary → Run → Open browser → Write code →
             Reload → Done

             Or: POST /api/project/import → Done

             Or: AI thinks about it → Done
```

### 11.3 What Pain Feels Like

Every feature in GOPLC exists because its creator experienced the pain of the alternative and decided no one should suffer through it again.

Proprietary programming cable? **Browser.**
$5,000 IDE license? **Included.**
Download stops the runtime? **Hot reload per-task.**
Can't debug without vendor tools? **Debug in every function.**
No API, no integration path? **API-first, everything.**
Per-device licensing extortion? **One license.**
Backup is a prayer? **Export is one API call.**
Fleet management is another product? **Built into every runtime.**
Orphaned controllers running blind? **Boss dies, minions die.**
300 IP addresses to secure? **One JWT endpoint.**
Firmware update requires a truck roll? **Push JSON over API.**
Vendor lock-in? **49MB Go binary, runs on anything.**
AI integration? **Built in. MCP, code assistant, API — all native.**

This is not a feature list. This is a revenge list.

---

*GOPLC is available at goplc.app. Downloads, documentation, and benchmarking tools are all there.*

*White Paper Version 1.0 | March 2026*
