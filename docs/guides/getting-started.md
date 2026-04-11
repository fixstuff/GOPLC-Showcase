# Getting Started with GoPLC

From download to your first running program in under 10 minutes.

---

## 1. Download and Install

### Requirements

- Any Linux machine: Raspberry Pi (2/3/4/5), server, VM, or desktop
- x86_64 (Intel/AMD) or ARM64 (Raspberry Pi, ARM SBCs)
- 150MB RAM, 100MB disk
- A web browser on any device on the same network

### Download

Get the latest release from the [GoPLC download page](https://goplc.app/download)
or extract the tarball directly:

```bash
# Download (substitute your platform: linux-amd64 or linux-arm64)
tar xzf goplc-v1.0.535-linux-amd64.tar.gz
cd goplc-v1.0.535-linux-amd64
```

### Install as a System Service

The included installer sets up GoPLC as a systemd service that starts automatically
on boot:

```bash
sudo ./install.sh
```

This will:
- Copy the `goplc` binary to `/usr/local/bin/`
- Create a systemd service (`goplc.service`)
- Start GoPLC on port **8082** by default
- Set up Node-RED with Dashboard 2.0

### Or Run Manually

If you prefer to run without installing:

```bash
./goplc --api-port 8082
```

### Verify It's Running

Open a browser and go to:

```
http://<your-machine-ip>:8082/ide/
```

You should see the GoPLC Web IDE. If you're on the same machine, use `http://localhost:8082/ide/`.

> **Tip:** If the page doesn't load, check that the port is open in your firewall:
> `sudo ufw allow 8082/tcp`

---

## 2. The Web IDE

The IDE is your main workspace. Here's what you'll see:

### Left Panel — Program Explorer
- **Programs** — your ST (Structured Text) source files
- **Tasks** — execution containers that run programs on a scan cycle
- **Libraries** — reusable function collections

### Center — Code Editor
- Syntax-highlighted ST editor
- Click any program in the explorer to open it

### Right Panel — Variable Monitor
- Live values of all variables, updated in real-time
- Search and filter variables by name

### Top Bar
- **Run/Stop** — start and stop the PLC runtime
- **Download** — deploy your code to the runtime
- **Online** — toggle online mode to see live values in the editor
- **AI Assistant** — generate ST code, HMI pages, or Node-RED flows

### Bottom Bar
- **Messages** — compilation errors and warnings
- **Faults** — runtime fault log

---

## 3. License Activation

GoPLC runs in **demo mode** for 2 hours without a license. After that, you'll need
to activate with a license key.

### Find Your Install ID

In the IDE, click the **license** indicator in the top bar. You'll see your
**Installation ID** — a unique identifier for this machine.

Or via the API:

```bash
curl http://localhost:8082/api/license
```

### Activate Your License

If you have a cloud license key (format: `GOPLC-XXXX-XXXX-XXXX-XXXX`):

**Option A — From the IDE:**
Click the license indicator → paste your key → click Activate.

**Option B — From the API:**

```bash
curl -X POST http://localhost:8082/api/license/activate \
  -H "Content-Type: application/json" \
  -d '{"unlock_code": "GOPLC-XXXX-XXXX-XXXX-XXXX"}'
```

The key activates once and is cached permanently — no internet required after
the first activation.

---

## 4. Your First Program

Let's create a simple counter that increments every second and calculates a
sine wave. This demonstrates variables, timers, math, and the scan cycle.

### Step 1: Create the Program

In the IDE, click **New Program** (+ icon) and name it `my_counter`.

Paste this code:

```iecst
PROGRAM my_counter
VAR
    count       : DINT := 0;
    prev_second : DINT := 0;
    now_s       : DINT;
    sine_value  : REAL := 0.0;
    running     : BOOL := TRUE;
END_VAR

(* Increment counter once per second *)
now_s := NOW_MS() / 1000;

IF now_s <> prev_second THEN
    prev_second := now_s;

    IF running THEN
        count := count + 1;
    END_IF;
END_IF;

(* Calculate a sine wave from the counter *)
sine_value := SIN(INT_TO_REAL(count) * 0.1) * 100.0;

END_PROGRAM
```

### Step 2: Deploy

Click the **Download** button (or press Ctrl+D). This compiles your code and
deploys it to the runtime. If there are errors, they'll appear in the Messages
panel at the bottom.

### Step 3: Start the Runtime

Click the **Run** button (green play icon). The runtime starts executing your
program on its configured scan cycle.

### Step 4: Watch It Run

Click **Online** to enable online mode. You'll see live values next to each
variable in the editor:

- `count` incrementing every second: 1, 2, 3, 4...
- `sine_value` oscillating: 9.98, 19.86, 29.55, 38.94...
- `running` showing TRUE

You can also see all variables in the **Monitor** panel on the right.

### Step 5: Interact

Try changing `running` to FALSE from the monitor panel — the counter stops.
Set it back to TRUE — it resumes. This is live interaction with a running PLC.

---

## 5. Add a Task Configuration

By default, GoPLC creates a MainTask for your program. You can customize the
scan cycle time and add multiple tasks.

### From the IDE

Click the **Tasks** section in the left panel. You'll see your task with:
- **Scan Time** — how often the program runs (default 100ms = 10 times/second)
- **Programs** — which programs are assigned to this task
- **Watchdog** — maximum allowed scan time before a fault

### Multiple Tasks

You can create separate tasks for different purposes:

| Task | Scan Time | Purpose |
|------|-----------|---------|
| fast_control | 10ms | Time-critical control loops |
| normal | 100ms | General logic, I/O scanning |
| slow_logging | 1000ms | Data logging, diagnostics |

Each task runs independently with its own scan cycle.

---

## 6. Node-RED is Already Running

GoPLC bundles Node-RED with 7 custom PLC nodes and Dashboard 2.0. It started
automatically when GoPLC launched.

### Open Node-RED

Navigate to:

```
http://<your-machine-ip>:8082/nodered/
```

### Built-in GOPLC Nodes

In the Node-RED palette (left side), you'll find the **goplc** category with:

| Node | Purpose |
|------|---------|
| goplc-connection | Auto-discovers the local GoPLC instance |
| goplc-read | Read a variable value (REST poll) |
| goplc-write | Write a value to a variable |
| goplc-subscribe | Real-time variable updates (WebSocket) |
| goplc-runtime | Start/stop/pause the runtime |
| goplc-task | Task info and control |
| goplc-cluster | Access minion nodes via boss proxy |

### Quick Dashboard Example

Try this flow to display your counter on a phone dashboard:

1. Drag a **goplc-subscribe** node onto the canvas
2. Double-click it, set Variable to `my_counter.count`
3. Drag a **dashboard gauge** node and connect them
4. Click **Deploy**
5. Open the dashboard: `http://<your-machine-ip>:8082/nodered/dashboard/`

You'll see your counter value updating live on a gauge widget — accessible
from any phone or tablet on your network.

---

## 7. What's Next?

You now have a running PLC with a web IDE, live monitoring, and a Node-RED
dashboard. Here's where to go from here:

### Learn More

| Guide | What You'll Build |
|-------|-------------------|
| [Home Automation](home-automation.md) | MQTT sensors, InfluxDB logging, Home Assistant integration |
| [Washing Machine Controller](washing-machine-controller.md) | Full appliance controller with Modbus I/O, state machine, phone dashboard |

### Explore the IDE

- **AI Assistant** — Ask it to generate programs, HMI pages, or Node-RED flows
- **HMI Builder** — Create custom web dashboards at `/hmi/`
- **Step Debugger** — Set breakpoints, step through code, inspect the call stack
- **Protocol Analyzer** — Capture and decode industrial protocol traffic

### Connect Real Hardware

GoPLC supports 14+ industrial protocols out of the box:

| Protocol | Use Case |
|----------|----------|
| Modbus TCP/RTU | Most common — PLCs, VFDs, sensors, relay modules |
| MQTT | IoT devices, Home Assistant, cloud |
| OPC UA | Interoperability with other PLCs and SCADA |
| EtherNet/IP | Allen-Bradley / Rockwell devices |
| S7 | Siemens devices |
| FINS | Omron devices |
| BACnet | Building automation |
| DNP3 | Utility / SCADA |

### Scale Up

- **Clustering** — Distribute workloads across multiple GoPLC instances
- **Docker** — Deploy as containers for production
- **ctrlX CORE** — Run as a snap on Bosch Rexroth industrial controllers

### Get Help

- Web IDE built-in docs: click **Docs** in the top bar
- API reference: `http://<your-ip>:8082/api/docs`
- Function search: `http://<your-ip>:8082/api/docs/functions?search=keyword`
