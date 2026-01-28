# GOPLC Architecture

## System Overview

```mermaid
graph TB
    subgraph "Web Interface"
        IDE[Web IDE<br/>Monaco Editor]
        API[REST API<br/>+ WebSocket]
    end

    subgraph "Core Runtime"
        SCHED[Task Scheduler<br/>Priority-based]
        PARSER[ST Parser<br/>IEC 61131-3]
        EVAL[Expression<br/>Evaluator]
        IOMEM[I/O Memory<br/>%I/%Q/%M]
        GLOBALS[Global<br/>Variables]
    end

    subgraph "Protocol Layer"
        MB[Modbus<br/>TCP/RTU]
        OPCUA[OPC UA<br/>Server/Client]
        EIP[EtherNet/IP<br/>Adapter/Scanner]
        DNP3[DNP3<br/>Master/Outstation]
        BACNET[BACnet<br/>IP/MSTP]
        FINS[FINS<br/>Client]
    end

    subgraph "Communication"
        DL[DataLayer<br/>TCP/SHM]
        MQTT[MQTT<br/>Pub/Sub]
        SAF[Store &<br/>Forward]
    end

    subgraph "External Systems"
        SCADA[SCADA/HMI]
        CLOUD[Cloud/IoT]
        DEVICES[Field Devices]
        PLCS[Other PLCs]
    end

    IDE --> API
    API --> SCHED
    SCHED --> PARSER
    PARSER --> EVAL
    EVAL --> IOMEM
    EVAL --> GLOBALS

    IOMEM --> MB
    IOMEM --> OPCUA
    IOMEM --> EIP
    IOMEM --> DNP3
    IOMEM --> BACNET
    IOMEM --> FINS

    GLOBALS --> DL
    GLOBALS --> MQTT

    MB --> DEVICES
    OPCUA --> SCADA
    EIP --> DEVICES
    DNP3 --> DEVICES
    BACNET --> DEVICES
    FINS --> DEVICES
    DL --> PLCS
    MQTT --> CLOUD
    SAF --> CLOUD
```

## Task Scheduler

The task scheduler is the heart of GOPLC, providing deterministic execution of ST programs.

```mermaid
sequenceDiagram
    participant S as Scheduler
    participant T1 as FastTask (100μs)
    participant T2 as MediumTask (1ms)
    participant T3 as SlowTask (100ms)
    participant IO as I/O Memory

    loop Every 100μs
        S->>T1: Execute
        T1->>IO: Read Inputs
        T1->>T1: Run ST Program
        T1->>IO: Write Outputs
        T1->>S: Complete
    end

    loop Every 1ms
        S->>T2: Execute
        T2->>IO: Read/Write
        T2->>S: Complete
    end

    loop Every 100ms
        S->>T3: Execute
        T3->>IO: Read/Write
        T3->>S: Complete
    end
```

### Task Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Periodic** | Executes at fixed intervals | Control loops, I/O scanning |
| **Event** | Triggered by condition | Alarms, interrupts |
| **Freerun** | Runs continuously | Background processing |

### Priority System

- Priorities range from 1 (highest) to 255 (lowest)
- Higher priority tasks preempt lower priority tasks
- Same-priority tasks execute round-robin

## Memory Model

```
┌─────────────────────────────────────────────────────────────────┐
│                         Memory Map                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  %I (Input) │  │ %Q (Output) │  │ %M (Memory) │              │
│  │             │  │             │  │             │              │
│  │ %IX0.0-7    │  │ %QX0.0-7    │  │ %MX0.0-7    │  Bits        │
│  │ %IB0-n      │  │ %QB0-n      │  │ %MB0-n      │  Bytes       │
│  │ %IW0-n      │  │ %QW0-n      │  │ %MW0-n      │  Words       │
│  │ %ID0-n      │  │ %QD0-n      │  │ %MD0-n      │  DWords      │
│  │ %IL0-n      │  │ %QL0-n      │  │ %ML0-n      │  LWords      │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                  │
│  ┌─────────────────────────────────────────────────┐            │
│  │              Global Variables (VAR_GLOBAL)       │            │
│  │  - Named variables accessible from all programs  │            │
│  │  - Published via DataLayer/MQTT                  │            │
│  │  - Mapped to protocol registers                  │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
│  ┌─────────────────────────────────────────────────┐            │
│  │              Program Variables (VAR)             │            │
│  │  - Local to each program instance               │            │
│  │  - Persistent across scan cycles                 │            │
│  │  - Supports AT binding to I/O                   │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Protocol Integration

### Modbus TCP/RTU

```mermaid
graph LR
    subgraph "GOPLC"
        MBSRV[Modbus Server]
        MBCLI[Modbus Client]
        IOMEM[I/O Memory]
    end

    subgraph "External"
        SCADA[SCADA System]
        RTU1[RTU Device 1]
        RTU2[RTU Device 2]
    end

    SCADA -->|Read/Write| MBSRV
    MBSRV <-->|Map| IOMEM
    MBCLI -->|Poll| RTU1
    MBCLI -->|Poll| RTU2
    RTU1 -->|Data| IOMEM
    RTU2 -->|Data| IOMEM
```

### DataLayer (Multi-PLC Sync)

```mermaid
graph TB
    subgraph "PLC 1 (Server)"
        DL1[DataLayer Server]
        VARS1[Variables<br/>PLC1_*]
    end

    subgraph "PLC 2 (Client)"
        DL2[DataLayer Client]
        VARS2[Variables<br/>PLC2_*]
        REMOTE2[Remote Vars<br/>REMOTE_PLC1_*]
    end

    subgraph "PLC 3 (Client)"
        DL3[DataLayer Client]
        VARS3[Variables<br/>PLC3_*]
        REMOTE3[Remote Vars<br/>REMOTE_PLC1_*]
    end

    VARS1 --> DL1
    DL1 -->|TCP :4222| DL2
    DL1 -->|TCP :4222| DL3
    DL2 --> REMOTE2
    DL3 --> REMOTE3
    DL2 -->|Publish| DL1
    DL3 -->|Publish| DL1
```

## Cluster Architecture

GOPLC supports multi-PLC clustering with a boss/minion architecture:

```
                         ┌─────────────────────┐
                         │     Boss Node       │
                         │   (Coordinator)     │
                         │                     │
                         │  - TCP API :8082    │
                         │  - Cluster Proxy    │
                         │  - Load Balancing   │
                         └──────────┬──────────┘
                                    │
               ┌────────────────────┼────────────────────┐
               │                    │                    │
        ┌──────▼──────┐      ┌──────▼──────┐      ┌──────▼──────┐
        │  Minion 0   │      │  Minion 1   │      │  Minion 2   │
        │             │      │             │      │             │
        │ Unix Socket │      │ Unix Socket │      │ Unix Socket │
        │ /var/run/   │      │ /var/run/   │      │ /var/run/   │
        │ goplc/      │      │ goplc/      │      │ goplc/      │
        │ minion-0    │      │ minion-1    │      │ minion-2    │
        │             │      │             │      │             │
        │ Area A      │      │ Area B      │      │ Area C      │
        │ Control     │      │ Control     │      │ Control     │
        └─────────────┘      └─────────────┘      └─────────────┘
```

### Cluster Benefits

- **Isolation**: Each minion has its own protocol registries
- **Scalability**: Add minions for more I/O capacity
- **Fault Containment**: Minion failure doesn't affect others
- **Unified API**: Access all minions through boss proxy

## Real-Time Architecture

```mermaid
graph TB
    subgraph "Linux Kernel"
        SCHED_FIFO[SCHED_FIFO<br/>RT Priority]
        CPUSET[CPU Isolation<br/>cpuset/isolcpus]
        MLOCK[Memory Lock<br/>mlockall]
    end

    subgraph "GOPLC Process"
        MAIN[Main Thread]
        TASK1[Task Thread 1<br/>Pinned to Core 2]
        TASK2[Task Thread 2<br/>Pinned to Core 3]
        GC[GC Thread<br/>Low Priority]
    end

    SCHED_FIFO --> TASK1
    SCHED_FIFO --> TASK2
    CPUSET --> TASK1
    CPUSET --> TASK2
    MLOCK --> MAIN
    MLOCK --> TASK1
    MLOCK --> TASK2

    style TASK1 fill:#4ec9b0
    style TASK2 fill:#4ec9b0
```

### Real-Time Configuration

| Setting | Purpose | Typical Value |
|---------|---------|---------------|
| `lock_os_thread` | Pin goroutines to OS threads | `true` |
| `cpu_affinity` | Bind to specific CPU cores | `[2, 3]` |
| `memory_lock` | Prevent page faults | `true` |
| `gc_percent` | Reduce GC frequency | `500-1000` |
| `rt_priority` | SCHED_FIFO priority | `50` |

## Data Flow

```mermaid
flowchart LR
    subgraph Inputs
        SENSORS[Sensors]
        MODBUS_IN[Modbus Devices]
        OPCUA_IN[OPC UA Servers]
    end

    subgraph GOPLC
        IOIN[Input Scan]
        LOGIC[ST Programs]
        IOOUT[Output Scan]
    end

    subgraph Outputs
        ACTUATORS[Actuators]
        SCADA[SCADA/HMI]
        CLOUD[Cloud/MQTT]
    end

    SENSORS --> IOIN
    MODBUS_IN --> IOIN
    OPCUA_IN --> IOIN
    IOIN --> LOGIC
    LOGIC --> IOOUT
    IOOUT --> ACTUATORS
    LOGIC --> SCADA
    LOGIC --> CLOUD
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Security Layers                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Network Layer                         │    │
│  │  - CORS configuration for Web IDE                       │    │
│  │  - Connection limits per protocol                       │    │
│  │  - Idle timeout for unused connections                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Protocol Layer                         │    │
│  │  - OPC UA: Security policies (None, Sign, Encrypt)      │    │
│  │  - MQTT: TLS, username/password                         │    │
│  │  - Modbus: IP-based access control                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  Application Layer                       │    │
│  │  - Store-and-Forward: AES-256-GCM encryption            │    │
│  │  - JWT support in ST (JWT_ENCODE, JWT_DECODE)           │    │
│  │  - Crypto functions (AES, RSA, SHA, HMAC)               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
