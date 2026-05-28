<!-- Generated from GOPLC 1.0.959 on 2026-05-28 by scripts/docs-gen. DO NOT EDIT BY HAND. Source: /api/openapi.json on the running binary. -->


# GOPLC API

> Generated from GOPLC **1.0.959** on 2026-05-28. OpenAPI 3.1.0. **320** paths.

### `POST /api/agent/deploy`

Generate and deploy a control program for a system manifest

*Tags:* agent

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/ai/capabilities`

AI capabilities documentation

*Tags:* ai

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/ai/control`

Run the agentic control loop (read/write vars, start/stop tasks)

*Tags:* ai

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/ai/memory`

List AI memory notes

*Tags:* ai-memory

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| kind | query | False | string |
| topic | query | False | string |
| q | query | False | string |
| limit | query | False | integer |
| include_superseded | query | False | boolean |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/ai/memory`

Create an AI memory note

*Tags:* ai-memory

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/ai/memory/{id}`

Delete an AI memory note

*Tags:* ai-memory

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | integer |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/ai/sessions`

List AI chat sessions

*Tags:* ai-memory

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| limit | query | False | integer |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/ai/sessions/{id}`

Delete a session and its chat turns

*Tags:* ai-memory

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/ai/sessions/{id}/turns`

Get chat turns for a session (chronological)

*Tags:* ai-memory

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |
| limit | query | False | integer |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/ai/status`

AI assistant availability and model info

*Tags:* ai

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/ai/turns/search`

Search chat turns by content substring

*Tags:* ai-memory

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| q | query | True | string |
| session | query | False | string |
| limit | query | False | integer |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/alarms`

List all configured alarms with current state

*Tags:* alarms

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/alarms`

Create a new alarm

*Tags:* alarms

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/alarms/ack-all`

Acknowledge all unacknowledged alarms

*Tags:* alarms

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/alarms/active`

List active (non-NORM) alarms

*Tags:* alarms

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/alarms/history`

Alarm state-transition history

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | query | False | string |
| limit | query | False | integer |
| start | query | False | string |
| end | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/alarms/shelved`

List shelved alarms

*Tags:* alarms

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/alarms/summary`

Alarm counts by state and priority

*Tags:* alarms

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/alarms/unacknowledged`

List unacknowledged alarms

*Tags:* alarms

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/alarms/{name}`

Get a single alarm's detail

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/alarms/{name}`

Delete an alarm

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/alarms/{name}/ack`

Acknowledge an alarm

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/alarms/{name}/disable`

Disable an alarm

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/alarms/{name}/enable`

Enable an alarm

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/alarms/{name}/shelve`

Shelve an alarm (optional duration)

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/alarms/{name}/unshelve`

Unshelve an alarm

*Tags:* alarms

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/analyzer`

Analyzer capture state and statistics

*Tags:* analyzer

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/analyzer/decode`

Decode raw hex data with a protocol decoder

*Tags:* analyzer

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/analyzer/export/pcap`

Export captured transactions as a PCAP download

*Tags:* analyzer

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| device_ids | query | False | string |
| protocols | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/analyzer/protocols`

List protocols that can be decoded

*Tags:* analyzer

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/analyzer/start`

Start capturing protocol transactions

*Tags:* analyzer

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/analyzer/stats`

Detailed capture statistics

*Tags:* analyzer

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/analyzer/stop`

Stop the current capture session

*Tags:* analyzer

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/analyzer/transactions`

Captured transactions from the buffer

*Tags:* analyzer

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| limit | query | False | string |
| offset | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/analyzer/transactions`

Clear the transaction buffer

*Tags:* analyzer

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/analyzer/transactions/{id}`

A single transaction with full details

*Tags:* analyzer

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/audit`

Query the audit trail with optional filters

*Tags:* audit

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| start | query | False | string |
| end | query | False | string |
| user | query | False | string |
| action | query | False | string |
| resource | query | False | string |
| limit | query | False | string |
| offset | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/audit/export`

Export the audit trail as a CSV download

*Tags:* audit

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| start | query | False | string |
| end | query | False | string |
| user | query | False | string |
| action | query | False | string |
| resource | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/audit/summary`

Audit event counts grouped by action type

*Tags:* audit

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/auth/login`

Log in with username + password, returns a JWT

*Tags:* auth

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/auth/logout`

Acknowledge logout (stateless JWT — client clears its token)

*Tags:* auth

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/auth/refresh`

Refresh the caller's JWT

*Tags:* auth

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/auth/status`

Report whether auth is enabled and the caller authenticated

*Tags:* auth

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/auth/users`

List configured usernames (protected)

*Tags:* auth

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/auth/users`

Create a user (protected)

*Tags:* auth

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/auth/users/{username}`

Delete a user (protected)

*Tags:* auth

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| username | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/auth/users/{username}/password`

Change a user's password (protected)

*Tags:* auth

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| username | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/browse`

Browse directories for project save/load

*Tags:* project

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| dir | query | False | string |
| filter | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/can`

List CAN interfaces and open-interface stats

*Tags:* can

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/can/{interface}`

Stats for one open CAN interface

*Tags:* can

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| interface | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/can/{interface}/close`

Close a SocketCAN interface

*Tags:* can

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| interface | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/can/{interface}/open`

Open a SocketCAN interface (optional CAN FD)

*Tags:* can

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| interface | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/can/{interface}/recv`

Buffered received CAN frames

*Tags:* can

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| interface | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/can/{interface}/send`

Transmit a CAN frame

*Tags:* can

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| interface | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/capabilities`

Get PLC capabilities for AI discovery

*Tags:* docs

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/export`

Bundle every node's project into one .goplc-cluster download

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/import`

Distribute a .goplc-cluster bundle to each node

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/new`

Reset all cluster nodes to a blank project

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/reload-all`

Reload programs on every cluster node

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/save-all`

Save every node's project to its own disk

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/snapshot`

Bundle every node's project + live variables into one .goplc-cluster download

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/start-all`

Start runtime on every cluster node

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/cluster-ops/status-all`

Runtime status from every cluster node

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/stop-all`

Stop runtime on every cluster node

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster-ops/validate-all`

Validate all programs on every cluster node

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster/disable`

Tear down all minions and revert to standalone

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/cluster/dynamic`

Dynamic cluster mode status and minions

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster/enable`

Promote this standalone instance to boss mode

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/cluster/heartbeat`

Cluster heartbeat for health monitoring

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/cluster/members`

List cluster members with online status

*Tags:* cluster

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster/minions`

Spawn a new in-process minion PLC instance

*Tags:* cluster

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/cluster/minions/{name}`

Tear down and remove a minion by name

*Tags:* cluster

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/cluster/sync`

Receive a variable state-sync payload from the boss node

*Tags:* cluster

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/config/export`

Export the stored config as a YAML download

*Tags:* config

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/config/runtime`

Get the runtime config YAML stored in the project

*Tags:* config

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/config/runtime`

Save runtime config YAML to the project file

*Tags:* config

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/config/runtime`

Clear the stored runtime config from the project file

*Tags:* config

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/config/secrets`

Export the per-instance deployment overlay (--config) YAML

*Tags:* config

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| include_secrets | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/datalayer/reconnect`

Reconnect the DataLayer bridge (optionally at a new address)

*Tags:* datalayer

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/datalayer/status`

DataLayer tag browser (local + remote nodes)

*Tags:* datalayer

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/console`

Read (and clear) buffered browser-JS console logs

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/console`

Receive a browser-JS console log message

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/db`

Get the debug database-logging status

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/debug/db`

Disable debug database logging

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/db/postgres`

Enable debug PostgreSQL logging

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/db/query`

Query the debug database log table

*Tags:* debug

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| limit | query | False | string |
| module | query | False | string |
| level | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/db/sqlite`

Enable debug SQLite logging

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/file`

Get the debug file-logging status

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/file`

Enable debug file logging

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/debug/file`

Disable debug file logging

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/goroutines`

Summary of all goroutines grouped by stack trace

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/hash`

Project hash breakdown (running/pending/ide + per-type counts)

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/ide-hash`

Report the frontend's locally-computed project hash

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/influx`

Get the debug InfluxDB-logging status

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/influx`

Enable debug InfluxDB logging

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/debug/influx`

Disable debug InfluxDB logging

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/log`

Read the debug log buffer (optionally filtered by module)

*Tags:* debug

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| module | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/log`

Write a debug log message from the Web IDE

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/debug/log`

Clear the debug log buffer

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/runtime`

Get the runtime debug system status

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/runtime`

Enable or disable the runtime debug system

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/runtime/buffer`

Get the debug log ring buffer

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/debug/runtime/buffer`

Clear the debug log ring buffer

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/runtime/level`

Get the global debug level

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/debug/runtime/level`

Set the global debug level

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/runtime/modules`

List all module debug levels

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/runtime/modules/{module}`

Get the debug level for a module

*Tags:* debug

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| module | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/debug/runtime/modules/{module}`

Set the debug level for a module

*Tags:* debug

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| module | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/debug/runtime/modules/{module}`

Remove a module's debug-level override (revert to global)

*Tags:* debug

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| module | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/status`

Get debug status (global + webui module)

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/step/breakpoints`

List all step-debug breakpoints

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/step/breakpoints`

Set a step-debug breakpoint at a program line

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/debug/step/breakpoints/{program}/{line}`

Remove a step-debug breakpoint

*Tags:* debug

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| program | path | True | string |
| line | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/step/continue`

Resume execution until the next breakpoint

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/step/disable`

Disable statement-level debugging

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/step/enable`

Enable statement-level debugging

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/step/into`

Step to the next statement, entering FB/function calls

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/step/out`

Run until the current FB/function call returns

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/step/over`

Step to the next statement, skipping FB/function internals

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/debug/step/state`

Get the current step-debug state

*Tags:* debug

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/debug/toggle`

Toggle Web IDE debug logging on/off

*Tags:* debug

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/demos`

List available simulation demo templates

*Tags:* demos

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/devices/import-map`

Import a vendor register-map CSV into ST gateway code

*Tags:* project

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| Content-Type | header | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/diagnostics`

System diagnostics (memory, goroutines, driver + runtime state)

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/dl-bridge/log`

dl-bridge diagnostic log (snap deployments)

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/dl-bridge/status`

dl-bridge runtime status JSON (snap deployments)

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/docs/functions`

Get ST function reference (filterable, grouped by category)

*Tags:* docs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| category | query | False | string |
| search | query | False | string |
| library | query | False | string |
| limit | query | False | integer |
| names_only | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/docs/guides`

Get programming guides and language concepts

*Tags:* docs

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/docs/howtos`

List how-to guides (optionally filtered by search)

*Tags:* docs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| search | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/docs/howtos/{name}`

Get a single how-to guide by slug

*Tags:* docs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/drivers`

List protocol drivers, DataLayer, and MQTT status

*Tags:* drivers

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/drivers/{name}`

Get a driver's details and address mappings

*Tags:* drivers

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/drivers/{name}/diagnostics`

Get Modbus protocol diagnostics statistics

*Tags:* drivers

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/drivers/{name}/diagnostics`

Enable/disable Modbus packet capture

*Tags:* drivers

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| enable | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/drivers/{name}/diagnostics`

Clear captured Modbus packets (and statistics with ?all=true)

*Tags:* drivers

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| all | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/drivers/{name}/diagnostics/packets`

Get captured Modbus packets

*Tags:* drivers

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| count | query | False | string |
| direction | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/drivers/{name}/metrics`

Get a driver's protocol metrics (connections, requests, heartbeat)

*Tags:* drivers

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/drivers/{name}/trace`

Enable/disable Modbus packet tracing to the debug system

*Tags:* drivers

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| enable | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/edit/commit`

Apply the staged set to live atomically

*Tags:* edit

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/edit/diff`

Unified diff (live → staged) for one staged path

*Tags:* edit

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| path | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/edit/discard`

Discard a staged file (alias for unstage in MVP)

*Tags:* edit

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/edit/history`

Commit history (newest first) with optional filters

*Tags:* edit

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| path | query | False | string |
| since | query | False | string |
| until | query | False | string |
| limit | query | False | string |
| cursor | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/edit/history/{id}`

Full detail (metadata + per-file diffs) for one commit

*Tags:* edit

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/edit/revert`

Stage the reverse-diff of an earlier commit

*Tags:* edit

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/edit/stage`

Add or replace a file in the staging area

*Tags:* edit

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/edit/status`

List staged files with their state vs the running runtime

*Tags:* edit

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/edit/unstage`

Remove a file from the staging area

*Tags:* edit

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/enip/browse`

Browse EtherNet/IP tags on a Rockwell Logix PLC

*Tags:* enip

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| host | query | False | string |
| port | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/events`

Query the SQLite event log

*Tags:* events

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| type | query | False | string |
| severity | query | False | string |
| source | query | False | string |
| min_severity | query | False | string |
| limit | query | False | string |
| start | query | False | string |
| end | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/events`

Emit a custom event onto the bus

*Tags:* events

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/events/summary`

Event counts grouped by (type, severity) plus bus stats

*Tags:* events

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| since_hours | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/events/types`

Catalog of registered event type constants

*Tags:* events

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/failover`

Failover status

*Tags:* failover

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/failover/demote`

Force demotion to standby

*Tags:* failover

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/failover/history`

Role-change history

*Tags:* failover

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/failover/promote`

Force promotion to primary

*Tags:* failover

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/failover/sync`

Force an immediate full state sync

*Tags:* failover

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/failover/sync/status`

Failover sync status

*Tags:* failover

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/faults`

List current task faults

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/faults/{task}/clear`

Clear the fault on a specific task

*Tags:* system

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| task | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/features/search`

Unified feature search across wizard topics, functions, and how-tos

*Tags:* docs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| q | query | False | string |
| limit | query | False | integer |
| kinds | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/files`

List ST files in a directory

*Tags:* files

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| dir | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/files/read`

Read the contents of an ST file

*Tags:* files

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| path | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/files/write`

Write contents to an ST file

*Tags:* files

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/fleet/discover`

Scan the local network for GOPLC nodes via mDNS

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| timeout | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/fleet/drift`

Compare project hashes across healthy fleet nodes

*Tags:* fleet

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/fleet/nodes`

List all known fleet nodes

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| role | query | False | string |
| family | query | False | string |
| tier | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/fleet/nodes/{id}`

Get a single fleet node by ID

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/fleet/nodes/{id}`

Manually add or update a fleet node

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/fleet/nodes/{id}`

Remove a node from the fleet registry

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/nodes/{id}/config`

Push a config YAML (with optional template vars) to a node

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/fleet/nodes/{id}/history`

Snapshot history for a specific node

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |
| limit | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/nodes/{id}/poll`

Trigger an immediate health poll

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/nodes/{id}/push`

Push a stored snapshot to a remote node

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/fleet/nodes/{id}/snapshots`

List snapshots available to push to a node

*Tags:* fleet

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |
| limit | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/push-bulk`

Push a stored snapshot to multiple nodes concurrently

*Tags:* fleet

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/snapshots/collect`

Reset prev hashes and trigger an immediate re-collect poll

*Tags:* fleet

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/snapshots/export`

Save all snapshots to a timestamped directory as .goplc files

*Tags:* fleet

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/snapshots/purge`

Delete all snapshots and reset collection state

*Tags:* fleet

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/fleet/template/render`

Apply template substitution to a config YAML without pushing

*Tags:* fleet

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/fuxa/status`

Get FUXA reachability status

*Tags:* fuxa

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/gpio`

List configured GPIO pins and availability

*Tags:* gpio

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/gpio/{pin}`

Read a single GPIO pin

*Tags:* gpio

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| pin | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/gpio/{pin}`

Configure or write a GPIO pin

*Tags:* gpio

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| pin | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/historian/backfill`

SQLite→Parquet backfill progress (read-only)

*Tags:* history

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/historian/backfill`

Copy SQLite raw samples into the Parquet substrate (resumable)

*Tags:* history

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| max_rows | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/historian/parity`

SQLite-vs-Parquet read parity check for one tag/window

*Tags:* history

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| tag | query | False | string |
| start | query | False | string |
| end | query | False | string |
| points | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/historian/query`

Multi-tag bucketed history query over the Parquet substrate

*Tags:* history

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| tags | query | False | string |
| start | query | False | string |
| end | query | False | string |
| points | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/history/prune`

Trigger a manual flush/prune cycle

*Tags:* history

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/history/stats`

Overall historian DB statistics

*Tags:* history

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/history/tags`

List all logged tags with stats

*Tags:* history

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/history/tags`

Register a new tag for logging

*Tags:* history

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/history/tags/{name}`

Stop logging a tag and remove its data

*Tags:* history

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/history/value/{tag}`

Latest recorded value for a single tag

*Tags:* history

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| tag | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/hmi/import`

Import a page from an exported envelope

*Tags:* hmi

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/hmi/pages`

List stored HMI pages

*Tags:* hmi

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/hmi/pages`

Create a new HMI page

*Tags:* hmi

**Request body:** application/json

**Responses**

- `201` — Created
- `default` — Error

### `DELETE /api/hmi/pages`

Wipe every stored HMI page

*Tags:* hmi

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/hmi/pages/{name}`

Get a single HMI page

*Tags:* hmi

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/hmi/pages/{name}`

Update an existing HMI page

*Tags:* hmi

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/hmi/pages/{name}`

Delete an HMI page

*Tags:* hmi

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/hmi/pages/{name}/export`

Export a page as a self-describing envelope

*Tags:* hmi

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/hmi/pages/{name}/rename`

Rename an HMI page

*Tags:* hmi

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/i2c/scan/{bus}`

Probe an I2C bus for responding addresses

*Tags:* i2c

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| bus | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/include/source`

Read a child file from a declared include

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| path | query | False | string |
| program | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/include/source`

Write a child file in a declared include (re-resolves the wrapper)

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| path | query | False | string |
| program | query | False | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/info`

Runtime identification info for the web IDE

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/instances`

Flat view of every template instance across tasks

*Tags:* templates

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/io/connections`

Live health of southbound device connections (Modbus/ENIP/FINS/BACnet)

*Tags:* io

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/io/mappings`

Get all configured I/O point mappings

*Tags:* io

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/io/mappings`

Add an I/O point mapping

*Tags:* io

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/io/mappings/{category}/{address}`

Get a specific I/O point by category and address

*Tags:* io

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| category | path | True | string |
| address | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/io/mappings/{category}/{address}`

Update an existing I/O point mapping

*Tags:* io

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| category | path | True | string |
| address | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/io/mappings/{category}/{address}`

Remove an I/O point mapping

*Tags:* io

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| category | path | True | string |
| address | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/iomemory`

List all I/O memory values

*Tags:* variables

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/l5x/export`

Export a program as a Rockwell L5X download

*Tags:* l5x

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/l5x/import`

Import a Rockwell L5X file, converting it to ST

*Tags:* l5x

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/l5x/validate-rll`

Check whether ST source is RLL (ladder-export) compatible

*Tags:* l5x

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/libraries`

List loaded ST libraries

*Tags:* libraries

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/libraries`

Load an ST library by name or path

*Tags:* libraries

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/libraries/clear`

Unload all libraries

*Tags:* libraries

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/libraries/upload`

Load a library from ST source code

*Tags:* libraries

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/libraries/{name}`

Get library details (function/FB lists)

*Tags:* libraries

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/libraries/{name}`

Unload a library from the scheduler

*Tags:* libraries

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/libraries/{name}/source`

Get the ST source for a loaded library

*Tags:* libraries

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/license/activate`

Validate an unlock code and activate the license

*Tags:* license

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/license/deactivate`

Remove the license and revert to demo mode

*Tags:* license

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/license/info`

Full license status including installation ID

*Tags:* license

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/license/restart-demo`

Reset the demo timer

*Tags:* license

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/license/status`

Lightweight license status for IDE polling

*Tags:* license

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/load_warnings`

Project load warnings

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/logs`

Recent log entries with optional level/limit/since filters

*Tags:* system

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| level | query | False | string |
| limit | query | False | string |
| since | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/logs`

Clear the in-RAM log ring (durable Parquet logs are retained)

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/mkdir`

Create a new directory

*Tags:* project

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/nodered/restart`

Restart the Node-RED subprocess

*Tags:* nodered

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/nodered/start`

Start the Node-RED subprocess

*Tags:* nodered

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/nodered/status`

Get Node-RED subprocess status

*Tags:* nodered

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/nodered/stop`

Stop the Node-RED subprocess

*Tags:* nodered

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/p2/{name}/inspect`

Snapshot a P2 device's firmware-internal state

*Tags:* p2

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/paths`

Configured projects/st_code/lib/data paths

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/programs`

List all programs (metadata; ?include_source for source)

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| include_source | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/programs`

Create or update a program (auto-detects type, auto-renames prefix)

*Tags:* programs

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/programs/clear`

Clear all user programs (keeps libraries)

*Tags:* programs

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/programs/estimate`

Estimate scan time for arbitrary ST source

*Tags:* programs

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/programs/reload`

Download programs to runtime (validate, deploy, leave stopped)

*Tags:* programs

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/programs/validate`

Validate program source (syntax + undefined functions)

*Tags:* programs

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/programs/{name}`

Get a program's source and metadata

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/programs/{name}`

Update a program's source / task / mode

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/programs/{name}`

Delete a program

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/programs/{name}/detach`

Detach a program from its include

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/programs/{name}/estimate`

Estimate scan time for a loaded program

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/programs/{name}/folder`

Set a program's cosmetic IDE-tree folder

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/programs/{name}/task`

Assign a program to a task

*Tags:* programs

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/project`

Export the current state as a project.goplc download

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/project`

Import a project from JSON content (stages for download)

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/project/deploy`

Stage, validate, deploy, and start a project in one shot

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/project/export`

Export the current state as a project.goplc download (alias)

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/project/file`

Read a single file from the active project directory

*Tags:* project

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| path | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/project/file`

Write a single file under the active project directory

*Tags:* project

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| path | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/project/hash`

Get the running and pending/IDE project hashes

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/project/import`

Import a project from JSON content (alias)

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/project/load`

Load a project file from disk into the runtime

*Tags:* project

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/project/new`

Clear the IDE project and start a new one

*Tags:* project

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/project/save`

Save the current project to disk

*Tags:* project

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/project/tree`

File tree of the active directory project

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/project/validate`

Validate the project's ST programs

*Tags:* project

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/projects/folder`

Get the default projects folder path

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/pubsub/stats`

IDE event pub/sub hub statistics

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/runtime`

Get runtime statistics (uptime, task/tag counts, I/O + scan stats)

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/runtime/download`

Get the runtime's current programs and task configs

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/pause`

Pause the scan loop after the current scan completes

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/reload`

Download to runtime (reparse programs from stored sources, leave stopped)

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/reset`

Reset the runtime (warm/cold/origin) — requires {"confirm":"RESET"}

*Tags:* runtime

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/restart`

Stop, reload programs, and start again

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/resume`

Resume continuous scanning after a pause

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/start`

Start all tasks (validates programs unless ?force=true)

*Tags:* runtime

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| force | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/step`

Execute one scan then pause again

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/stop`

Stop all tasks

*Tags:* runtime

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/runtime/upload`

Replace the runtime's programs/tasks and restart

*Tags:* runtime

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/serial/close`

Close a serial port session

*Tags:* serial

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| device | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/serial/open`

Open a serial port session

*Tags:* serial

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/serial/ports`

List available serial devices

*Tags:* serial

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/serial/recv`

Read buffered data from an open serial port

*Tags:* serial

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| device | query | False | string |
| max | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/serial/send`

Write data to an open serial port

*Tags:* serial

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/serial/sessions`

List open serial port sessions

*Tags:* serial

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/shutdown/status`

Shutdown progress observer (phase/step/elapsed)

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/simulation/status`

Simulation engine state and running models

*Tags:* simulation

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/simulation/time_scale`

Adjust the wall-clock-to-sim time multiplier

*Tags:* simulation

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/snapshots`

List stored project snapshots (?name to scope to one project)

*Tags:* snapshots

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| limit | query | False | string |
| name | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/snapshots`

Capture the current running state as a snapshot

*Tags:* snapshots

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/snapshots/history`

History of which snapshot hash was active when

*Tags:* snapshots

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| limit | query | False | string |
| node_id | query | False | string |
| name | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/snapshots/{hash}`

Get a snapshot's full project JSON by hash

*Tags:* snapshots

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| hash | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/snapshots/{hash}`

Delete a snapshot by hash

*Tags:* snapshots

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| hash | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/snapshots/{hash}/restore`

Restore a snapshot as the current project (Download to apply)

*Tags:* snapshots

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| hash | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/spine/events`

Query the unified event-spine log

*Tags:* events

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| kind | query | False | string |
| subject | query | False | string |
| correlation | query | False | string |
| exclude_kind_prefix | query | False | string |
| from | query | False | string |
| to | query | False | string |
| limit | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/spine/events`

Append a manual event to the spine (engineer+)

*Tags:* events

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/spine/events/{id}`

Get one spine event by its monotonic ID

*Tags:* events

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/stats`

Basic runtime stats (uptime, tag count)

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/status`

Consolidated instance status (version, uptime, scheduler, license)

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/storeforward/clear`

Delete all pending messages

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/storeforward/close`

Close the store-forward subsystem

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/storeforward/count`

Pending-message count

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/storeforward/forward`

Forward pending messages to a target URL

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/storeforward/init`

Initialize the store-forward subsystem

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/storeforward/online`

Get the network online state

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/storeforward/online`

Set the network online state

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/storeforward/pending`

Pending messages with metadata

*Tags:* storeforward

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| limit | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/storeforward/stats`

Store-forward statistics

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/storeforward/store`

Store a message for later forwarding

*Tags:* storeforward

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/system/manifests`

List hardware manifests

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/system/manifests`

Create a hardware manifest

*Tags:* system

**Responses**

- `201` — Created
- `default` — Error

### `GET /api/system/manifests/{id}`

Get a hardware manifest by ID

*Tags:* system

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/system/manifests/{id}`

Create or update a hardware manifest by ID

*Tags:* system

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/system/manifests/{id}`

Delete a hardware manifest by ID

*Tags:* system

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/system/manifests/{id}/init-program`

Generate the ST init program for a manifest

*Tags:* system

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/system/platform`

Direct-GPIO platform name + availability

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/system/power`

UPS / power status

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/system/restart`

Re-exec the GOPLC process (requires {"confirm":true})

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/system/retain`

Per-task RETAIN file status

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/system/retain/flush`

Force an immediate RETAIN save on all tasks

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/system/shutdown`

Gracefully shut down the GOPLC process (requires {"confirm":true})

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/system/watchdog`

Hardware + systemd watchdog status

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/tags`

List all I/O tags (driver values + PLC variables)

*Tags:* variables

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/tags/{tag}`

Get a tag value (I/O cache first, then PLC variables)

*Tags:* variables

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| tag | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/tags/{tag}`

Set a tag value (updates I/O cache and PLC scheduler)

*Tags:* variables

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| tag | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/tags/{tag}`

Set a tag value (updates I/O cache and PLC scheduler)

*Tags:* variables

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| tag | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/tasks`

List all tasks (configs + runtime stats)

*Tags:* tasks

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/tasks`

Create a new task (restart required to take effect)

*Tags:* tasks

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/tasks/configs`

Replace all task configs (download push)

*Tags:* tasks

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/tasks/{name}`

Get a task's config and runtime state

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/tasks/{name}`

Update a task's scan time, priority, watchdog, programs

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/tasks/{name}`

Delete a task

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/tasks/{name}/programs`

Assign programs to a task

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/tasks/{name}/reload`

Reload (download) a single task

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/tasks/{name}/start`

Start a single task

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/tasks/{name}/stop`

Stop a single task

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/tasks/{name}/validate`

Validate a task's programs (syntax check, no load)

*Tags:* tasks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/templates`

List TAG_TEMPLATE declarations

*Tags:* templates

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/templates/{name}`

Get one TAG_TEMPLATE definition

*Tags:* templates

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/templates/{name}/instances`

List instances of a specific template

*Tags:* templates

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/upload`

Capture the running PLC state as a timestamped .goplc download

*Tags:* project

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/variables`

List all PLC executor variables

*Tags:* variables

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/variables/bulk`

Get values for a list of variables in one request

*Tags:* variables

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/variables/meta`

List variable metadata (type, retain, constant)

*Tags:* variables

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/variables/{name}`

Get a PLC variable value

*Tags:* variables

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/variables/{name}`

Set a PLC variable value (writes directly to the executor)

*Tags:* variables

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/variables/{name}`

Set a PLC variable value (writes directly to the executor)

*Tags:* variables

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/video/cameras`

List configured cameras with capture stats

*Tags:* video

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/video/cameras`

Live-register a camera with the running historian

*Tags:* video

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/video/cameras/{name}`

Stop and forget a camera

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/video/cameras/{name}/burst`

Flag recent frames as an event clip and raise capture rate

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/video/cameras/{name}/frames`

Frame index for a camera within a time window

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| from | query | False | string |
| to | query | False | string |
| limit | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/video/cameras/{name}/nearest`

Frame nearest a timestamp

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| ts | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/video/cameras/{name}/start`

(Re)start a camera's capture loop

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/video/cameras/{name}/stop`

Pause a camera's capture loop

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/video/cameras/{name}/tags`

Per-frame snapshot tag list for a camera

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/video/cameras/{name}/tags`

Append snapshot tags to a camera

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/video/cameras/{name}/tags`

Drop every snapshot tag from a camera

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/video/cameras/{name}/tags/{tag}`

Drop one snapshot tag from a camera

*Tags:* video

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| tag | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/vision/audit`

Read audit chain entries by lot / correlation / range

*Tags:* vision

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| lot_id | query | False | string |
| correlation | query | False | string |
| from | query | False | string |
| to | query | False | string |
| verify | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/vision/audit/info`

Audit chain entry count + last-entry metadata

*Tags:* vision

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/vision/audit/verify`

Verify a lot's audit chain (chain + optional HMAC)

*Tags:* vision

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/vision/cancel/{id}`

Cancel a pending or running vision request

*Tags:* vision

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/vision/info`

Vision engine stats + capabilities

*Tags:* vision

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/vision/scan`

Trigger a single inference and wait for the result

*Tags:* vision

**Request body:** application/json (required)

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/vision/status/{id}`

Status (and result, if finished) for a vision request

*Tags:* vision

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/watch`

List active watch windows

*Tags:* watch

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/watch`

Create a watch window for monitoring tags

*Tags:* watch

**Request body:** application/json

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/watch/{id}`

Get current values for a watch window

*Tags:* watch

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/watch/{id}`

Delete a watch window

*Tags:* watch

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/webhooks`

List configured webhook destinations with stats

*Tags:* webhooks

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/webhooks`

Register a new webhook at runtime

*Tags:* webhooks

**Responses**

- `200` — OK
- `default` — Error

### `PUT /api/webhooks/{name}`

Replace an existing webhook's configuration

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/webhooks/{name}`

Remove a webhook by name

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/webhooks/{name}/dead-letter`

Dead-letter rows for a webhook

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| limit | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/webhooks/{name}/dead-letter/purge`

Remove every dead-letter row for a webhook

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `DELETE /api/webhooks/{name}/dead-letter/{id}`

Remove a dead-letter row without redelivery

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/webhooks/{name}/dead-letter/{id}/replay`

Re-deliver a dead-letter row to its webhook

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/webhooks/{name}/history`

Recent delivery attempts for a webhook

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |
| limit | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/webhooks/{name}/test`

Deliver a synthesized test event to a webhook

*Tags:* webhooks

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| name | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/wizard/apply`

Merge static form values into the project config

*Tags:* wizard

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/wizard/apply-manifest`

Parse an AI-generated manifest YAML and save it

*Tags:* wizard

**Responses**

- `200` — OK
- `default` — Error

### `POST /api/wizard/apply-yaml`

Merge an AI-generated YAML snippet into the project config

*Tags:* wizard

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/wizard/topics`

List config-wizard topics

*Tags:* wizard

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| q | query | False | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /api/wizard/topics/{id}`

Get one config-wizard topic

*Tags:* wizard

**Parameters**

| Name | In | Required | Type |
|---|---|---|---|
| id | path | True | string |

**Responses**

- `200` — OK
- `default` — Error

### `GET /health`

Liveness probe

*Tags:* system

**Responses**

- `200` — OK
- `default` — Error

