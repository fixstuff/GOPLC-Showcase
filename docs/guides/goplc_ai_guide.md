# GoPLC AI Assistant Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Architecture Overview

GoPLC includes a built-in AI assistant that understands the runtime context -- variables, tasks, programs, faults, and protocols. It operates in two modes: **Chat** for conversational code generation, and **Control** for autonomous tool-calling where the AI reads variables, writes outputs, deploys code, and runs diagnostics on its own.

| Mode | Endpoint | Use Case |
|------|----------|----------|
| **Chat** | `POST /api/ai/chat` | Ask questions, generate ST code, create HMI pages, produce Node-RED flows |
| **Control** | `POST /api/ai/control` | Autonomous troubleshooting, diagnostics, and code deployment with tool execution |
| **Control (Stream)** | `POST /api/ai/control/stream` | Same as Control, with real-time Server-Sent Events for progress tracking |
| **Status** | `GET /api/ai/status` | Check AI availability, provider, and model |

Three provider backends are supported:

| Provider | Default Model | API Key Env Var | Tool Calling |
|----------|---------------|-----------------|--------------|
| **Claude** (default) | `claude-sonnet-4-20250514` | `ANTHROPIC_API_KEY` | Native |
| **OpenAI** | User-configured | `OPENAI_API_KEY` | Native |
| **Ollama** | User-configured | N/A (local) | Simulated via prompt |

---

## 2. Configuration

### 2.1 YAML Configuration

Add an `ai` section to your GoPLC config file:

```yaml
# Minimal -- just set the API key environment variable
ai:
  enabled: true

# Full configuration
ai:
  enabled: true
  name: "Assistant"                    # Display name in the IDE
  provider: claude                     # claude, openai, or ollama
  api_key_env: ANTHROPIC_API_KEY       # Environment variable containing the key
  model: claude-sonnet-4-20250514      # Model to use
  timeout_seconds: 30                  # Request timeout
  max_tokens: 8192                     # Max response tokens
  temperature: 0.3                     # 0.0 = deterministic, 1.0 = creative
```

### 2.2 Configuration Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `false` | Enable AI assistant |
| `name` | string | `""` | Display name shown in the IDE |
| `provider` | string | `claude` | Provider: `claude`, `openai`, or `ollama` |
| `api_key` | string | `""` | Direct API key (prefer `api_key_env` instead) |
| `api_key_env` | string | `ANTHROPIC_API_KEY` | Environment variable containing the API key |
| `model` | string | `claude-sonnet-4-20250514` | Model identifier |
| `endpoint` | string | `""` | Custom endpoint URL (required for Ollama, e.g. `http://localhost:11434`) |
| `timeout_seconds` | int | `30` | Request timeout in seconds |
| `max_tokens` | int | `8192` | Maximum response tokens |
| `temperature` | float | `0.3` | Response creativity (low = deterministic code, high = creative prose) |

> **Auto-enable:** If the API key environment variable is set, the AI assistant enables automatically even if `enabled: false` in the config.

### 2.3 Provider Examples

```yaml
# Claude (default)
ai:
  enabled: true
  provider: claude
  api_key_env: ANTHROPIC_API_KEY

# OpenAI
ai:
  enabled: true
  provider: openai
  api_key_env: OPENAI_API_KEY
  model: gpt-4o

# Ollama (local, no API key needed)
ai:
  enabled: true
  provider: ollama
  endpoint: http://localhost:11434
  model: llama3.1
```

> **Ollama limitation:** Tool calling is simulated by injecting tool descriptions into the prompt and parsing JSON from the response. This works for simple tool use but is less reliable than native tool calling with Claude or OpenAI.

---

## 3. Chat Mode

Chat mode is a request/response interaction where you send a message and receive a structured response containing natural language, ST code, HMI pages, and/or Node-RED flows.

### 3.1 API

```
POST /api/ai/chat
```

**Request:**

```json
{
    "message": "Write a PID loop for temperature control with anti-windup",
    "variables": [
        {"name": "temperature", "type": "REAL", "value": "72.5"},
        {"name": "setpoint", "type": "REAL", "value": "75.0"}
    ],
    "tasks": [
        {"name": "MainTask", "priority": "1", "scan_time": "100ms"}
    ],
    "programs": ["POU_Control", "GVL_Process"],
    "current_code": "PROGRAM POU_Control\nVAR\n  ...\nEND_PROGRAM",
    "history": [
        {"role": "user", "content": "What protocols are available?"},
        {"role": "assistant", "content": "GoPLC supports Modbus TCP/RTU..."}
    ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | STRING | Yes | Your question or instruction |
| `variables` | ARRAY | No | Current PLC variables (name, type, value) |
| `tasks` | ARRAY | No | Current task configuration |
| `programs` | ARRAY | No | Program names in the project |
| `current_code` | STRING | No | ST code currently in the editor |
| `history` | ARRAY | No | Previous conversation turns (max 10 recommended) |

**Response:**

```json
{
    "message": "Here's a PID controller with anti-windup clamping...",
    "code": "FUNCTION_BLOCK FB_PID\nVAR_INPUT\n  ...\nEND_FUNCTION_BLOCK",
    "hmi": "<div id=\"pid-panel\">...</div>",
    "flow": "[{\"id\":\"...\",\"type\":\"inject\",...}]",
    "tokens_used": 1542
}
```

| Field | Type | Description |
|-------|------|-------------|
| `message` | STRING | Natural language explanation |
| `code` | STRING | Extracted ST code (from ` ```st ` blocks) |
| `hmi` | STRING | Extracted HTML (from ` ```html ` blocks) |
| `flow` | STRING | Extracted Node-RED flow JSON (from ` ```json ` blocks) |
| `tokens_used` | INT | Total tokens consumed |

The AI automatically extracts code blocks from its response and returns them in separate fields for the IDE to act on.

### 3.2 What the AI Knows

The AI receives a comprehensive system prompt containing:

- IEC 61131-3 Structured Text reference (data types, control structures, operators)
- GoPLC task scheduler documentation (scan cycles, watchdog, priority)
- All available ST functions with signatures (from the live function registry)
- Current project context (variables, tasks, programs) when provided
- Protocol driver reference (Modbus, OPC UA, EtherNet/IP, MQTT, etc.)
- Common patterns (state machines, PID control, timers, ramping)

This means the AI can generate code that uses the correct function names, parameter counts, and data types -- it is not guessing.

---

## 4. Control Mode

Control mode gives the AI autonomous access to the runtime through tool calls. Instead of generating code for you to deploy, the AI reads variables, writes outputs, starts/stops tasks, and deploys programs on its own.

### 4.1 API

```
POST /api/ai/control
```

**Request:**

```json
{
    "message": "The heater is overshooting. Diagnose and fix it.",
    "max_turns": 10,
    "history": []
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `message` | STRING | required | Instruction for the AI |
| `max_turns` | INT | 10 | Maximum tool-calling iterations |
| `history` | ARRAY | `[]` | Previous conversation turns |

**Response (blocking):**

```json
{
    "response": "I investigated the heater control loop and found...",
    "actions_executed": [
        {"tool": "list_variables", "args": {"filter": "heater"}, "result": "[heater_output, heater_sp, heater_pv]"},
        {"tool": "read_variable", "args": {"name": "heater_output"}, "result": "98.5"},
        {"tool": "get_diagnostics", "args": {}, "result": "{...}"}
    ],
    "turns_used": 3
}
```

### 4.2 Streaming

For real-time progress tracking, use the streaming endpoint:

```
POST /api/ai/control/stream
```

Returns Server-Sent Events (SSE):

```
data: {"type": "tool_call", "tool": "read_variable", "args": {"name": "temperature"}, "turn": 1}

data: {"type": "tool_result", "tool": "read_variable", "result": "72.5", "turn": 1}

data: {"type": "tool_call", "tool": "get_diagnostics", "turn": 2}

data: {"type": "tool_result", "tool": "get_diagnostics", "result": "{...}", "turn": 2}

data: {"type": "text", "text": "The temperature is stable at 72.5F..."}

data: {"type": "done"}
```

| Event Type | Description |
|------------|-------------|
| `tool_call` | AI is calling a tool (includes tool name and arguments) |
| `tool_result` | Tool returned a result |
| `text` | AI's final text response |
| `done` | Control loop finished |
| `error` | Fatal error occurred |

### 4.3 Available Tools

The AI can invoke these tools during control sessions:

| Tool | Arguments | Returns | Description |
|------|-----------|---------|-------------|
| `read_variable` | `name` | Value | Read any PLC variable |
| `list_variables` | `filter` (optional) | Variable list | List variables with optional prefix filter |
| `write_variable` | `name`, `value` | Success | Write a PLC variable |
| `get_task_status` | -- | Task states | Status of all tasks (running, faulted, scan time) |
| `start_task` | `name` | Success | Start a task (or `'all'`) |
| `stop_task` | `name` | Success | Stop a task (or `'all'`) |
| `reload_task` | `name` | Success | Reload task with updated code |
| `get_diagnostics` | -- | Runtime info | Memory, scan stats, uptime, faults |
| `get_faults` | -- | Fault list | Active task faults |
| `deploy_program` | `goal`, `system_id` | Result | Generate and deploy an ST program |
| `list_st_functions` | `category`, `search` | Functions | Look up available ST functions |
| `create_hmi_page` | `name`, `flow` | Success | Create a Node-RED Dashboard 2.0 flow |
| `create_manifest` | `id`, `name`, `hardware` | Success | Register a hardware manifest |

### 4.4 Automatic Context Injection

In control mode, the AI automatically receives a snapshot of the current runtime state:

- Runtime status (running/stopped, uptime)
- All task names, states, scan times, and fault info
- Current variable values (up to 40 in the prompt, rest searchable via `list_variables`)

You do not need to provide variables, tasks, or programs in the request -- the control endpoint captures them automatically.

---

## 5. IDE Integration

The GoPLC Web IDE includes a built-in AI chat panel accessible from the sidebar.

### 5.1 Chat Panel

- **Input:** Text area with Enter to send, Shift+Enter for newline
- **Voice input:** Microphone button (Chrome, Edge, Safari -- uses Web Speech API)
- **Context checkboxes:**
  - *Include editor code* -- sends the current ST code from the editor
  - *Include variables* -- sends current PLC variable values
- **History:** Last 10 messages maintained for conversation continuity

### 5.2 Code Actions

When the AI response contains code blocks, the IDE presents action buttons:

| Code Type | Detected By | Actions |
|-----------|-------------|---------|
| **ST code** | ` ```st ` block | "Create New Program" (deploys via API), "Insert at Cursor" |
| **HTML** | ` ```html ` block | "Preview HMI" (opens in new window), "Save as HMI Page" |
| **Node-RED flow** | ` ```json ` block (with Node-RED structure) | "Import to Node-RED" (merges and deploys), "Copy Flow JSON" |
| **YAML config** | ` ```yaml ` block | "Apply Config Snippet" (sends to wizard) |

### 5.3 Node-RED Flow Import

When you click "Import to Node-RED":

1. IDE checks if Node-RED is running (offers to start it if not)
2. Parses the AI-generated flow JSON
3. Fetches existing flows via `GET /nodered/flows`
4. Merges (appends) the new nodes
5. Deploys via `POST /nodered/flows` with full deployment
6. Offers to open the Node-RED editor

### 5.4 Streaming in the IDE

The IDE uses the streaming control endpoint (`/api/ai/control/stream`) by default. While the AI works:

- A "thinking" indicator shows which tool is being called
- Tool results appear in a summary panel (green background)
- The final response renders with markdown formatting

---

## 6. Practical Examples

### 6.1 Generate a Modbus Polling Program

```
POST /api/ai/chat
{
    "message": "Write a program that polls a VFD on 10.0.0.50 port 502, reads speed and current from holding registers 0-1, and writes a speed setpoint to register 10"
}
```

The AI will generate ST code using `MB_CLIENT_CREATE`, `MB_CLIENT_CONNECT`, `MB_READ_HOLDING`, and `MB_WRITE_REGISTER` -- the actual function names from the live registry.

### 6.2 Autonomous Troubleshooting

```
POST /api/ai/control
{
    "message": "The pump is not starting. Check variables related to pump control and report what you find."
}
```

The AI will autonomously:
1. Call `list_variables(filter: "pump")` to find pump-related tags
2. Call `read_variable` on each relevant variable
3. Call `get_faults` to check for active faults
4. Call `get_task_status` to verify tasks are running
5. Return a diagnosis with specific variable values and recommendations

### 6.3 Deploy and Test a Program

```
POST /api/ai/control
{
    "message": "Create a simple counter program that increments every scan and deploy it to MainTask"
}
```

The AI will:
1. Call `list_st_functions` to verify available functions
2. Call `deploy_program` with generated ST code
3. Call `read_variable` to verify the counter is incrementing
4. Report success with the live counter value

---

## 7. Status and Diagnostics

### 7.1 Check AI Availability

```
GET /api/ai/status
```

```json
{
    "available": true,
    "name": "Assistant",
    "provider": "claude",
    "model": "claude-sonnet-4-20250514"
}
```

### 7.2 Capabilities Debug Endpoint

```
GET /api/ai/capabilities
```

Returns the system prompt length, function count, and knowledge topics -- useful for debugging prompt size issues.

---

## 8. Best Practices

1. **Use control mode for troubleshooting** -- it reads live data and can chain multiple tool calls to diagnose issues. Chat mode only knows what you tell it.

2. **Include context in chat mode** -- check "Include variables" and "Include editor code" in the IDE for the most relevant responses.

3. **Low temperature for code** -- the default 0.3 is intentional. Code generation needs determinism, not creativity. Increase to 0.7+ only for brainstorming or documentation.

4. **Verify generated code** -- always validate AI-generated ST code before deploying to production. Use `POST /api/programs/{name}/validate` or the IDE's syntax checker.

5. **Ollama for offline use** -- when internet access is unavailable or data cannot leave the network, use Ollama with a local model. Tool calling is less reliable but basic code generation works.

6. **API key security** -- use `api_key_env` to reference an environment variable rather than putting the key directly in config files that may be version-controlled.

---

## Appendix A: Quick Reference

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/ai/status` | Check AI availability and model |
| POST | `/api/ai/chat` | Send message, get structured response |
| POST | `/api/ai/control` | Autonomous tool-calling (blocking) |
| POST | `/api/ai/control/stream` | Autonomous tool-calling (SSE streaming) |
| GET | `/api/ai/capabilities` | Debug: prompt size, function count |

### Control Tools

| Tool | Description |
|------|-------------|
| `read_variable` | Read any PLC variable |
| `list_variables` | List variables with optional filter |
| `write_variable` | Write a PLC variable |
| `get_task_status` | All task states |
| `start_task` | Start task (or 'all') |
| `stop_task` | Stop task (or 'all') |
| `reload_task` | Reload task code |
| `get_diagnostics` | Runtime diagnostics |
| `get_faults` | Active faults |
| `deploy_program` | Generate and deploy ST code |
| `list_st_functions` | Search available functions |
| `create_hmi_page` | Create Dashboard 2.0 flow |
| `create_manifest` | Register hardware manifest |

---

*GoPLC v1.0.533 | AI Assistant: Claude, OpenAI, Ollama | Chat + Autonomous Control*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
