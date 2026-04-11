# AI Gateway: One Pi Controls Every PLC

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.541

---

## 1. Overview

A single GoPLC instance — running on a $35 Raspberry Pi — can serve as an **AI gateway** to every GoPLC on your network. Your AI assistant (Claude Code, Cursor, Windsurf, or any MCP-compatible tool) connects to that one MCP server, and from there it can reach any GoPLC instance just by changing the `host` and `port` on each tool call.

No cloud. No relay. No separate server install. The same binary that runs your PLC programs also serves the MCP tools.

```
                         ┌──────────────────────┐
                         │   AI Assistant        │
                         │  (Claude Code, etc.)  │
                         └──────────┬───────────┘
                                    │ stdio (JSON-RPC)
                         ┌──────────▼───────────┐
                         │   Pi Gateway          │
                         │   ./goplc mcp         │
                         └──────────┬───────────┘
                                    │ HTTP (REST API)
                    ┌───────────────┼───────────────┐
                    │               │               │
             ┌──────▼──────┐ ┌─────▼──────┐ ┌──────▼──────┐
             │ GoPLC :8082 │ │ GoPLC :8082│ │ GoPLC :8082 │
             │ Pi (arm64)  │ │ PC (amd64) │ │ ctrlX (arm) │
             │ 10.0.0.170  │ │ 10.0.0.31  │ │ 10.0.0.45   │
             └─────────────┘ └────────────┘ └─────────────┘
```

### Why This Matters

- **One connection, entire plant.** Your AI assistant opens one MCP session and can read variables, deploy programs, debug issues, and build HMI dashboards on any GoPLC instance on the network.
- **Zero infrastructure.** No MQTT broker, no cloud account, no VPN, no Docker. Just a GoPLC binary on a Pi.
- **Cross-platform.** The gateway Pi can manage Linux, Windows, and ctrlX instances — ARM and x86 — all from the same MCP session.
- **80 tools per target.** Programs, tasks, variables, HMI, debugging, protocol analysis, fleet discovery, and more. All accessible on every target.

---

## 2. Hardware You Need

| Item | Purpose | Cost |
|------|---------|------|
| Raspberry Pi (3B+ or newer) | Runs the MCP gateway | ~$35 |
| SD card (8GB+) | Pi OS + GoPLC binary | ~$8 |
| Ethernet or Wi-Fi | Network access to other GoPLC instances | — |

The gateway Pi doesn't need to run PLC programs itself (though it can). Its primary job is translating AI tool calls into HTTP API requests to your other instances.

Any Linux machine on the network works — the Pi is just the cheapest dedicated option.

---

## 3. Setup (5 Minutes)

### 3.1 Install GoPLC on the Pi

Download the ARM64 Linux tarball and extract it:

```bash
# On the Pi
mkdir ~/goplc && cd ~/goplc
tar xzf goplc-linux-arm64.tar.gz
```

The tarball is self-contained — binary, Node-RED, web IDE, everything.

### 3.2 (Optional) Start a GoPLC Runtime on the Pi

If you want the Pi itself to also run PLC programs:

```bash
./start-goplc.sh
# Starts on port 8082, installs systemd service for auto-start on reboot
```

If the Pi is gateway-only, skip this step. The MCP server doesn't need a local runtime — it talks to remote instances over HTTP.

### 3.3 Add the MCP Server to Your AI Tool

On your workstation (where you run Claude Code, Cursor, etc.):

**Claude Code:**
```bash
claude mcp add goplc -- ssh pi@10.0.0.170 /home/pi/goplc/goplc mcp
```

This tells Claude Code to SSH into the Pi and launch the MCP server over stdio. Every tool call flows through that SSH tunnel.

**If Claude Code runs on the Pi itself:**
```bash
claude mcp add goplc -- /home/pi/goplc/goplc mcp
```

**Other MCP clients (Cursor, Windsurf, etc.):**
```json
{
  "mcpServers": {
    "goplc": {
      "command": "ssh",
      "args": ["pi@10.0.0.170", "/home/pi/goplc/goplc", "mcp"]
    }
  }
}
```

### 3.4 Verify It Works

Restart your AI tool, then ask it:

> "Get the info from my GoPLC on 10.0.0.31 port 8082"

The AI will call `goplc_info(host="31", port=8082)` and return version, uptime, license status, program count, and more.

---

## 4. Talking to Multiple Instances

Every MCP tool accepts `host` and `port` parameters. To talk to a different GoPLC, just change them:

```
# Read variables on the Pi
goplc_variable_list(host="170", port=8082)

# Deploy a program to the Windows PC
goplc_deploy(host="31", port=8082, task="MainTask", programs=[...])

# Check runtime status on a ctrlX controller
goplc_runtime_status(host="45", port=8082)

# Debug a program on a second Pi
goplc_debug_enable(host="171", port=8082)
```

### Host Shorthand

The `host` parameter supports shorthand — just use the last octet:

| You type | Expands to |
|----------|-----------|
| `"170"` | `10.0.0.170` |
| `"31"` | `10.0.0.31` |
| `"45"` | `10.0.0.45` |
| `"10.0.1.50"` | `10.0.1.50` (used as-is) |
| `"localhost"` | `localhost` |

### Discover All Instances

Use fleet discovery to find every GoPLC on your network:

```
goplc_fleet_discover(host="170", port=8082)
```

This returns all reachable instances with their IP, port, version, and status — giving your AI a map of the entire plant.

---

## 5. What Your AI Can Do Across the Fleet

With the gateway in place, your AI assistant has full access to every GoPLC. Here are real workflows that work across instances:

### 5.1 Deploy the Same Program Everywhere

> "Deploy this temperature controller to all three PLCs"

The AI calls `goplc_deploy` three times with different hosts — same program source, different targets. One conversation, entire fleet updated.

### 5.2 Monitor Variables Across Machines

> "Show me the pressure readings from all my PLCs"

The AI calls `goplc_variable_get` on each instance and presents a unified view.

### 5.3 Cross-Instance Debugging

> "The output on 10.0.0.45 seems wrong — check what its inputs look like vs 10.0.0.170"

The AI reads variables from both instances, compares them, and identifies the discrepancy.

### 5.4 Fleet-Wide Configuration

> "Set the scan time to 50ms on all instances"

The AI calls `goplc_task_update` on each target with the new scan time.

### 5.5 Build HMI Dashboards Per Machine

> "Create a pump status dashboard on the Pi and a motor dashboard on the Windows PC"

The AI calls `goplc_hmi_create` on each target with machine-specific HTML.

---

## 6. Authentication

If any GoPLC instance has JWT authentication enabled, set the token as an environment variable before the MCP server starts:

```bash
export GOPLC_AUTH_TOKEN="your-jwt-token-here"
```

The MCP server includes this as a Bearer header on every HTTP request. All instances that share the same auth token work automatically.

For instances with different tokens, configure them in your GoPLC config file (see the Configuration Guide).

---

## 7. Network Considerations

### Firewall

Each GoPLC instance must have its API port open. On Linux:

```bash
sudo ufw allow 8082/tcp
```

### Latency

The MCP server makes HTTP calls to each target. On a local network, round-trip times are typically 1-5ms. Even over a slower link, tool calls complete in under a second.

### No Internet Required

Everything runs on your local network. The AI assistant connects to the MCP server, the MCP server connects to your PLCs. No data leaves your network.

---

## 8. Example: Complete Home Automation Setup

Here's a realistic setup using the gateway pattern:

| Device | Location | Role | Address |
|--------|----------|------|---------|
| Pi 3B+ | Network closet | **AI Gateway** + HVAC controller | 10.0.0.170:8082 |
| Pi Zero 2W | Garage | Garage door + lighting | 10.0.0.171:8082 |
| Pi 4 | Workshop | CNC + dust collection | 10.0.0.172:8082 |
| Old laptop | Office | Monitoring dashboard | 10.0.0.31:8082 |

One `claude mcp add` command. The AI can now:
- Write HVAC logic for the closet Pi
- Deploy garage door safety interlocks to the Zero
- Monitor CNC spindle RPM from the workshop Pi
- Build a master dashboard on the laptop showing all four systems

All from natural language conversations.

---

## 9. Troubleshooting

### "Connection refused" on a target

The GoPLC instance isn't running or the port isn't open:
```bash
# Check if GoPLC is running on the target
ssh pi@10.0.0.170 "ss -tlnp | grep 8082"

# Open the firewall if needed
ssh pi@10.0.0.170 "sudo ufw allow 8082/tcp"
```

### MCP tools don't appear in Claude Code

Restart Claude Code after adding the MCP server:
```bash
claude mcp add goplc -- ssh pi@10.0.0.170 /home/pi/goplc/goplc mcp
# Then restart Claude Code
```

### SSH connection drops

Use an SSH key for passwordless auth (the MCP transport needs non-interactive SSH):
```bash
ssh-copy-id pi@10.0.0.170
```

### Wrong version on a target

Check from the AI:
```
goplc_info(host="170", port=8082)
```

If the version is old, update the binary on that machine and restart.

---

## 10. Summary

| What | How |
|------|-----|
| **Install** | Extract tarball on a Pi |
| **Connect AI** | `claude mcp add goplc -- ssh pi@IP /path/to/goplc mcp` |
| **Talk to any PLC** | Change `host` and `port` on any tool call |
| **Discover fleet** | `goplc_fleet_discover` |
| **Cost** | $35 Pi + GoPLC binary |
| **Dependencies** | None. Single binary. No cloud. |

One Pi. One binary. One MCP session. Every PLC on your network, controlled by AI.
