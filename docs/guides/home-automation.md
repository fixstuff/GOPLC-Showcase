# GoPLC Home Automation Hub

> **DISCLAIMER:** This is a hypothetical project guide for educational and demonstration
> purposes. It illustrates how GoPLC can serve as a home automation controller. **All
> responsibility for implementation, safety, electrical work, and compliance with local
> codes lies entirely with the user.**

Use GoPLC as the automation backbone for your home — reading sensors, controlling
devices via MQTT, logging data to InfluxDB, building dashboards in Node-RED, and
integrating with Home Assistant for voice control and mobile access.

---

## Why GoPLC for Home Automation?

Home Assistant is great for coordination and UI. But it's not a real-time controller —
it's an event-driven Python app. When you need deterministic scan-based control
(HVAC sequencing, irrigation scheduling, pool chemistry, lighting scenes with precise
timing), a PLC runtime is the right tool. GoPLC bridges both worlds:

- **Deterministic control loops** — 100ms scan cycle, watchdog-protected
- **Native MQTT** — Publish/subscribe directly from Structured Text, no plugins
- **Native InfluxDB** — Write time-series data directly from ST, no middleware
- **Built-in MQTT broker** — No external Mosquitto needed (optional)
- **Node-RED bundled** — Dashboard 2.0 for custom panels, flow logic for glue
- **Home Assistant integration** — MQTT discovery, HA sees GoPLC devices automatically
- **1,600+ ST functions** — Timers, PID, math, string, JSON, HTTP, scheduling

---

## System Architecture

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                     Raspberry Pi (or any Linux box)             │
  │                                                                 │
  │  ┌──────────┐   ┌──────────┐   ┌──────────────┐               │
  │  │  GoPLC   │──►│ Node-RED │──►│ Dashboard 2.0│               │
  │  │ Runtime  │   │ (bundled)│   │ (phone/tablet)│               │
  │  │          │   └──────────┘   └──────────────┘               │
  │  │  MQTT ◄──┼─────────────────────────────────┐               │
  │  │  InfluxDB│                                  │               │
  │  └────┬─────┘                                  │               │
  │       │ MQTT                                   │               │
  └───────┼────────────────────────────────────────┼───────────────┘
          │                                        │
   ┌──────┴──────┐                          ┌──────┴──────┐
   │ MQTT Broker │◄─────────────────────────│    Home     │
   │ (built-in   │         MQTT             │  Assistant  │
   │  or extern) │◄───────────┐             │  (optional) │
   └──────┬──────┘            │             └─────────────┘
          │                   │
   ┌──────┴──────┐     ┌─────┴───────┐
   │  InfluxDB   │     │ IoT Devices │
   │  (Docker)   │     │ Zigbee/WiFi │
   │             │     │ Shelly/Tasmota│
   │  Grafana    │     │ ESP32/sensors│
   └─────────────┘     └─────────────┘
```

![GoPLC HMI Dashboard showing 3 tasks running](images/home-auto-hmi-dashboard.png)
*GoPLC built-in dashboard — memory usage, scan times, and goroutines for all 3 tasks*

**Three integration paths work simultaneously:**

1. **GoPLC ↔ MQTT ↔ Devices** — Direct control of Shelly, Tasmota, Zigbee2MQTT devices
2. **GoPLC → InfluxDB → Grafana** — Long-term data logging and visualization
3. **GoPLC ↔ MQTT ↔ Home Assistant** — Voice control, automations, mobile app

---

## Prerequisites

| Component | Purpose | Where |
|-----------|---------|-------|
| GoPLC on Linux | Automation runtime | Raspberry Pi or server |
| MQTT broker | Message bus | GoPLC built-in, or Mosquitto in Docker |
| InfluxDB v2 | Time-series database | Docker on same machine or separate |
| Grafana | Dashboards and alerts | Docker alongside InfluxDB |
| Home Assistant | Voice, mobile, automations | Separate Pi or Docker (optional) |
| IoT devices | Sensors and actuators | Shelly plugs, Zigbee sensors, ESP32, etc. |

### Docker Compose for InfluxDB + Grafana

```yaml
version: '3'
services:
  influxdb:
    image: influxdb:2
    container_name: influxdb
    ports:
      - "8086:8086"
    volumes:
      - influxdb-data:/var/lib/influxdb2
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=changeme123
      - DOCKER_INFLUXDB_INIT_ORG=homelab
      - DOCKER_INFLUXDB_INIT_BUCKET=home
      - DOCKER_INFLUXDB_INIT_RETENTION=30d
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=my-home-token

  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - influxdb

volumes:
  influxdb-data:
  grafana-data:
```

---

## Example Project: Whole-House Monitoring and Control

This example monitors temperature/humidity in 4 rooms, controls smart plugs, logs
everything to InfluxDB, and exposes devices to Home Assistant.

### Devices Used

| Device | Protocol | MQTT Topic | Purpose |
|--------|----------|------------|---------|
| Zigbee temp/humidity sensors (x4) | Zigbee2MQTT | `zigbee2mqtt/<name>` | Room climate |
| Shelly Plug S (x4) | WiFi/MQTT | `shellies/<id>/relay/0` | Smart plugs (lamps, fans) |
| Shelly H&T | WiFi/MQTT | `shellies/<id>/sensor` | Outdoor temp/humidity |
| ESP32 + DHT22 | WiFi/MQTT | `esp32/garage/climate` | Garage monitoring |
| Tasmota IR blaster | WiFi/MQTT | `cmnd/<name>/irhvac` | HVAC control |

---

## ST Programs

![GoPLC Web IDE with home automation programs](images/home-auto-ide.png)
*GoPLC Web IDE — GVL variables with live values in the monitor panel*

### GVL — Global Variables

```iecst
VAR_GLOBAL
    (* --- MQTT Connection --- *)
    mqtt_broker       : STRING := 'tcp://localhost:1883';
    mqtt_connected    : BOOL := FALSE;

    (* --- InfluxDB Connection --- *)
    influx_url        : STRING := 'http://localhost:8086';
    influx_org        : STRING := 'homelab';
    influx_bucket     : STRING := 'home';
    influx_token      : STRING := 'my-home-token';
    influx_connected  : BOOL := FALSE;

    (* --- Room Temperatures (from Zigbee2MQTT) --- *)
    temp_living       : REAL := 0.0;
    temp_bedroom      : REAL := 0.0;
    temp_kitchen      : REAL := 0.0;
    temp_office       : REAL := 0.0;
    hum_living        : REAL := 0.0;
    hum_bedroom       : REAL := 0.0;
    hum_kitchen       : REAL := 0.0;
    hum_office        : REAL := 0.0;

    (* --- Outdoor (Shelly H&T) --- *)
    temp_outdoor      : REAL := 0.0;
    hum_outdoor       : REAL := 0.0;

    (* --- Garage (ESP32) --- *)
    temp_garage       : REAL := 0.0;
    hum_garage        : REAL := 0.0;

    (* --- Smart Plug States --- *)
    plug_living_lamp  : BOOL := FALSE;
    plug_bedroom_fan  : BOOL := FALSE;
    plug_kitchen_light: BOOL := FALSE;
    plug_office_heater: BOOL := FALSE;

    (* --- Smart Plug Commands (from dashboard/HA) --- *)
    cmd_living_lamp   : BOOL := FALSE;
    cmd_bedroom_fan   : BOOL := FALSE;
    cmd_kitchen_light : BOOL := FALSE;
    cmd_office_heater : BOOL := FALSE;

    (* --- HVAC --- *)
    hvac_mode         : INT := 0;      (* 0=off, 1=cool, 2=heat, 3=auto *)
    hvac_setpoint     : REAL := 22.0;  (* Target temp C *)
    hvac_fan          : INT := 1;      (* 0=auto, 1=low, 2=med, 3=high *)

    (* --- Automation Rules --- *)
    auto_mode         : BOOL := TRUE;  (* Enable/disable automations *)
    night_mode        : BOOL := FALSE; (* Reduced activity 22:00-06:00 *)
    away_mode         : BOOL := FALSE; (* Nobody home *)

    (* --- Scheduling --- *)
    hour_of_day       : INT := 0;
    minute_of_day     : INT := 0;

    (* --- InfluxDB logging --- *)
    log_interval_s    : INT := 30;     (* Log every 30 seconds *)
    log_timer         : DINT := 0;

    (* --- Diagnostics --- *)
    mqtt_msg_count    : DINT := 0;
    influx_write_count: DINT := 0;
    last_fault        : STRING := '';
END_VAR
```

### POU_MqttBridge — MQTT Subscription and Publishing

```iecst
PROGRAM POU_MqttBridge
VAR
    init_done       : BOOL := FALSE;
    json_msg        : STRING;
    msg_payload     : STRING;

    (* Previous plug states for edge detection *)
    prev_living     : BOOL := FALSE;
    prev_bedroom    : BOOL := FALSE;
    prev_kitchen    : BOOL := FALSE;
    prev_office     : BOOL := FALSE;
END_VAR

(* ============================================================
   SECTION 1: MQTT INITIALIZATION
   ============================================================ *)
IF NOT init_done THEN
    MQTT_CLIENT_CREATE('home', GVL.mqtt_broker, 'goplc-home');
    MQTT_CLIENT_CONNECT('home');
    init_done := TRUE;
END_IF;

GVL.mqtt_connected := MQTT_CLIENT_IS_CONNECTED('home');

IF NOT GVL.mqtt_connected THEN
    MQTT_CLIENT_CONNECT('home');
    RETURN;
END_IF;

(* ============================================================
   SECTION 2: SUBSCRIBE TO SENSOR TOPICS (once)
   ============================================================ *)
(* Zigbee2MQTT sensors publish JSON: {"temperature":21.5,"humidity":45} *)
MQTT_SUBSCRIBE('home', 'zigbee2mqtt/living_sensor');
MQTT_SUBSCRIBE('home', 'zigbee2mqtt/bedroom_sensor');
MQTT_SUBSCRIBE('home', 'zigbee2mqtt/kitchen_sensor');
MQTT_SUBSCRIBE('home', 'zigbee2mqtt/office_sensor');

(* Shelly H&T outdoor *)
MQTT_SUBSCRIBE('home', 'shellies/shelly_outdoor/sensor/temperature');
MQTT_SUBSCRIBE('home', 'shellies/shelly_outdoor/sensor/humidity');

(* ESP32 garage *)
MQTT_SUBSCRIBE('home', 'esp32/garage/temperature');
MQTT_SUBSCRIBE('home', 'esp32/garage/humidity');

(* Shelly plug status *)
MQTT_SUBSCRIBE('home', 'shellies/plug_living/relay/0');
MQTT_SUBSCRIBE('home', 'shellies/plug_bedroom/relay/0');
MQTT_SUBSCRIBE('home', 'shellies/plug_kitchen/relay/0');
MQTT_SUBSCRIBE('home', 'shellies/plug_office/relay/0');

(* Home Assistant commands (optional) *)
MQTT_SUBSCRIBE('home', 'goplc/cmd/hvac_mode');
MQTT_SUBSCRIBE('home', 'goplc/cmd/hvac_setpoint');
MQTT_SUBSCRIBE('home', 'goplc/cmd/away_mode');
MQTT_SUBSCRIBE('home', 'goplc/cmd/auto_mode');

(* ============================================================
   SECTION 3: READ SENSOR DATA
   Zigbee2MQTT publishes JSON — use GET_MESSAGE_JSON to parse.
   Shelly/ESP32 publish plain values.
   ============================================================ *)

(* --- Zigbee2MQTT rooms (JSON payloads) --- *)
IF MQTT_HAS_MESSAGE('home', 'zigbee2mqtt/living_sensor') THEN
    json_msg := MQTT_GET_MESSAGE('home', 'zigbee2mqtt/living_sensor');
    GVL.temp_living := TO_REAL(JSON_GET(json_msg, 'temperature'));
    GVL.hum_living  := TO_REAL(JSON_GET(json_msg, 'humidity'));
    GVL.mqtt_msg_count := GVL.mqtt_msg_count + 1;
END_IF;

IF MQTT_HAS_MESSAGE('home', 'zigbee2mqtt/bedroom_sensor') THEN
    json_msg := MQTT_GET_MESSAGE('home', 'zigbee2mqtt/bedroom_sensor');
    GVL.temp_bedroom := TO_REAL(JSON_GET(json_msg, 'temperature'));
    GVL.hum_bedroom  := TO_REAL(JSON_GET(json_msg, 'humidity'));
    GVL.mqtt_msg_count := GVL.mqtt_msg_count + 1;
END_IF;

IF MQTT_HAS_MESSAGE('home', 'zigbee2mqtt/kitchen_sensor') THEN
    json_msg := MQTT_GET_MESSAGE('home', 'zigbee2mqtt/kitchen_sensor');
    GVL.temp_kitchen := TO_REAL(JSON_GET(json_msg, 'temperature'));
    GVL.hum_kitchen  := TO_REAL(JSON_GET(json_msg, 'humidity'));
    GVL.mqtt_msg_count := GVL.mqtt_msg_count + 1;
END_IF;

IF MQTT_HAS_MESSAGE('home', 'zigbee2mqtt/office_sensor') THEN
    json_msg := MQTT_GET_MESSAGE('home', 'zigbee2mqtt/office_sensor');
    GVL.temp_office := TO_REAL(JSON_GET(json_msg, 'temperature'));
    GVL.hum_office  := TO_REAL(JSON_GET(json_msg, 'humidity'));
    GVL.mqtt_msg_count := GVL.mqtt_msg_count + 1;
END_IF;

(* --- Shelly outdoor (plain string values) --- *)
IF MQTT_HAS_MESSAGE('home', 'shellies/shelly_outdoor/sensor/temperature') THEN
    GVL.temp_outdoor := MQTT_GET_MESSAGE_REAL('home', 'shellies/shelly_outdoor/sensor/temperature');
END_IF;
IF MQTT_HAS_MESSAGE('home', 'shellies/shelly_outdoor/sensor/humidity') THEN
    GVL.hum_outdoor := MQTT_GET_MESSAGE_REAL('home', 'shellies/shelly_outdoor/sensor/humidity');
END_IF;

(* --- ESP32 garage (plain values) --- *)
IF MQTT_HAS_MESSAGE('home', 'esp32/garage/temperature') THEN
    GVL.temp_garage := MQTT_GET_MESSAGE_REAL('home', 'esp32/garage/temperature');
END_IF;
IF MQTT_HAS_MESSAGE('home', 'esp32/garage/humidity') THEN
    GVL.hum_garage := MQTT_GET_MESSAGE_REAL('home', 'esp32/garage/humidity');
END_IF;

(* --- Shelly plug states (on/off) --- *)
IF MQTT_HAS_MESSAGE('home', 'shellies/plug_living/relay/0') THEN
    GVL.plug_living_lamp := MQTT_GET_MESSAGE('home', 'shellies/plug_living/relay/0') = 'on';
END_IF;
IF MQTT_HAS_MESSAGE('home', 'shellies/plug_bedroom/relay/0') THEN
    GVL.plug_bedroom_fan := MQTT_GET_MESSAGE('home', 'shellies/plug_bedroom/relay/0') = 'on';
END_IF;
IF MQTT_HAS_MESSAGE('home', 'shellies/plug_kitchen/relay/0') THEN
    GVL.plug_kitchen_light := MQTT_GET_MESSAGE('home', 'shellies/plug_kitchen/relay/0') = 'on';
END_IF;
IF MQTT_HAS_MESSAGE('home', 'shellies/plug_office/relay/0') THEN
    GVL.plug_office_heater := MQTT_GET_MESSAGE('home', 'shellies/plug_office/relay/0') = 'on';
END_IF;

(* --- Home Assistant commands --- *)
IF MQTT_HAS_MESSAGE('home', 'goplc/cmd/hvac_mode') THEN
    GVL.hvac_mode := MQTT_GET_MESSAGE_INT('home', 'goplc/cmd/hvac_mode');
END_IF;
IF MQTT_HAS_MESSAGE('home', 'goplc/cmd/hvac_setpoint') THEN
    GVL.hvac_setpoint := MQTT_GET_MESSAGE_REAL('home', 'goplc/cmd/hvac_setpoint');
END_IF;
IF MQTT_HAS_MESSAGE('home', 'goplc/cmd/away_mode') THEN
    GVL.away_mode := MQTT_GET_MESSAGE_BOOL('home', 'goplc/cmd/away_mode');
END_IF;
IF MQTT_HAS_MESSAGE('home', 'goplc/cmd/auto_mode') THEN
    GVL.auto_mode := MQTT_GET_MESSAGE_BOOL('home', 'goplc/cmd/auto_mode');
END_IF;

(* ============================================================
   SECTION 4: WRITE PLUG COMMANDS (edge-triggered)
   Only publish on state change to avoid MQTT flooding.
   ============================================================ *)
IF GVL.cmd_living_lamp <> prev_living THEN
    prev_living := GVL.cmd_living_lamp;
    IF GVL.cmd_living_lamp THEN
        MQTT_PUBLISH('home', 'shellies/plug_living/relay/0/command', 'on');
    ELSE
        MQTT_PUBLISH('home', 'shellies/plug_living/relay/0/command', 'off');
    END_IF;
END_IF;

IF GVL.cmd_bedroom_fan <> prev_bedroom THEN
    prev_bedroom := GVL.cmd_bedroom_fan;
    IF GVL.cmd_bedroom_fan THEN
        MQTT_PUBLISH('home', 'shellies/plug_bedroom/relay/0/command', 'on');
    ELSE
        MQTT_PUBLISH('home', 'shellies/plug_bedroom/relay/0/command', 'off');
    END_IF;
END_IF;

IF GVL.cmd_kitchen_light <> prev_kitchen THEN
    prev_kitchen := GVL.cmd_kitchen_light;
    IF GVL.cmd_kitchen_light THEN
        MQTT_PUBLISH('home', 'shellies/plug_kitchen/relay/0/command', 'on');
    ELSE
        MQTT_PUBLISH('home', 'shellies/plug_kitchen/relay/0/command', 'off');
    END_IF;
END_IF;

IF GVL.cmd_office_heater <> prev_office THEN
    prev_office := GVL.cmd_office_heater;
    IF GVL.cmd_office_heater THEN
        MQTT_PUBLISH('home', 'shellies/plug_office/relay/0/command', 'on');
    ELSE
        MQTT_PUBLISH('home', 'shellies/plug_office/relay/0/command', 'off');
    END_IF;
END_IF;

(* ============================================================
   SECTION 5: PUBLISH STATE TO HOME ASSISTANT
   Publish GoPLC state so HA can display/automate with it.
   Use retained messages so HA gets current state on restart.
   ============================================================ *)
MQTT_PUBLISH_RETAINED('home', 'goplc/state/temp_living', REAL_TO_STRING(GVL.temp_living));
MQTT_PUBLISH_RETAINED('home', 'goplc/state/temp_bedroom', REAL_TO_STRING(GVL.temp_bedroom));
MQTT_PUBLISH_RETAINED('home', 'goplc/state/temp_kitchen', REAL_TO_STRING(GVL.temp_kitchen));
MQTT_PUBLISH_RETAINED('home', 'goplc/state/temp_office', REAL_TO_STRING(GVL.temp_office));
MQTT_PUBLISH_RETAINED('home', 'goplc/state/temp_outdoor', REAL_TO_STRING(GVL.temp_outdoor));
MQTT_PUBLISH_RETAINED('home', 'goplc/state/temp_garage', REAL_TO_STRING(GVL.temp_garage));
MQTT_PUBLISH_RETAINED('home', 'goplc/state/hvac_mode', INT_TO_STRING(GVL.hvac_mode));
MQTT_PUBLISH_RETAINED('home', 'goplc/state/away_mode', BOOL_TO_STRING(GVL.away_mode));

END_PROGRAM
```

### POU_Automation — Control Logic

```iecst
PROGRAM POU_Automation
VAR
    prev_second    : DINT := 0;
    now_s          : DINT;
    hvac_cmd       : STRING;
    hvac_json      : STRING;
END_VAR

(* ============================================================
   TIMEKEEPING
   ============================================================ *)
now_s := NOW_MS() / 1000;
IF now_s <> prev_second THEN
    prev_second := now_s;

    (* Update time of day from wall clock — NOW_TIME() returns "HH:MM:SS" *)
    GVL.hour_of_day := STRING_TO_INT(LEFT(NOW_TIME(), 2));
    GVL.minute_of_day := STRING_TO_INT(MID(NOW_TIME(), 4, 2));

    (* Night mode: 22:00 to 06:00 *)
    GVL.night_mode := (GVL.hour_of_day >= 22) OR (GVL.hour_of_day < 6);
END_IF;

IF NOT GVL.auto_mode THEN
    RETURN;  (* Manual mode — no automations *)
END_IF;

(* ============================================================
   RULE 1: Office heater — ON if office < setpoint - 1, OFF if > setpoint
   Only during working hours (08:00-18:00), not in away mode.
   ============================================================ *)
IF NOT GVL.away_mode AND GVL.hour_of_day >= 8 AND GVL.hour_of_day < 18 THEN
    IF GVL.temp_office < (GVL.hvac_setpoint - 1.0) THEN
        GVL.cmd_office_heater := TRUE;
    ELSIF GVL.temp_office > GVL.hvac_setpoint THEN
        GVL.cmd_office_heater := FALSE;
    END_IF;
ELSE
    GVL.cmd_office_heater := FALSE;
END_IF;

(* ============================================================
   RULE 2: Bedroom fan — ON if bedroom > 26C at night
   ============================================================ *)
IF GVL.night_mode AND GVL.temp_bedroom > 26.0 THEN
    GVL.cmd_bedroom_fan := TRUE;
ELSIF GVL.temp_bedroom < 24.0 THEN
    GVL.cmd_bedroom_fan := FALSE;
END_IF;

(* ============================================================
   RULE 3: Living room lamp — ON at sunset (18:00), OFF at 23:00
   ============================================================ *)
IF GVL.hour_of_day >= 18 AND GVL.hour_of_day < 23 AND NOT GVL.away_mode THEN
    GVL.cmd_living_lamp := TRUE;
ELSE
    GVL.cmd_living_lamp := FALSE;
END_IF;

(* ============================================================
   RULE 4: Away mode — everything off except security
   ============================================================ *)
IF GVL.away_mode THEN
    GVL.cmd_office_heater := FALSE;
    GVL.cmd_bedroom_fan := FALSE;
    GVL.cmd_kitchen_light := FALSE;
    (* Living lamp: random on/off to simulate presence *)
    IF (now_s MOD 3600) < 1800 THEN
        GVL.cmd_living_lamp := TRUE;
    ELSE
        GVL.cmd_living_lamp := FALSE;
    END_IF;
END_IF;

(* ============================================================
   RULE 5: HVAC control via IR blaster (Tasmota)
   Publish irhvac JSON to Tasmota IR blaster.
   ============================================================ *)
IF GVL.mqtt_connected THEN
    (* Pre-compute fan speed string — CASE can't be used inside CONCAT *)
    CASE GVL.hvac_fan OF
        0: hvac_cmd := 'Auto';
        1: hvac_cmd := 'Low';
        2: hvac_cmd := 'Medium';
        3: hvac_cmd := 'High';
    ELSE
        hvac_cmd := 'Auto';
    END_CASE;

    CASE GVL.hvac_mode OF
        0: (* Off *)
            hvac_json := '{"Vendor":"LG","Power":"Off"}';
        1: (* Cool *)
            hvac_json := CONCAT('{"Vendor":"LG","Power":"On","Mode":"Cool","Temp":',
                         REAL_TO_STRING(GVL.hvac_setpoint),
                         ',"FanSpeed":"', hvac_cmd, '"}');
        2: (* Heat *)
            hvac_json := CONCAT('{"Vendor":"LG","Power":"On","Mode":"Heat","Temp":',
                         REAL_TO_STRING(GVL.hvac_setpoint),
                         ',"FanSpeed":"', hvac_cmd, '"}');
        3: (* Auto *)
            hvac_json := CONCAT('{"Vendor":"LG","Power":"On","Mode":"Auto","Temp":',
                         REAL_TO_STRING(GVL.hvac_setpoint),
                         ',"FanSpeed":"', hvac_cmd, '"}');
    END_CASE;

    MQTT_PUBLISH_RETAINED('home', 'goplc/state/hvac_json', hvac_json);
    (* Publish to Tasmota only on mode/setpoint change — handled by Node-RED
       to avoid blasting IR every scan cycle *)
END_IF;

END_PROGRAM
```

### POU_DataLogger — InfluxDB Time-Series Logging

```iecst
PROGRAM POU_DataLogger
VAR
    init_done      : BOOL := FALSE;
    prev_second    : DINT := 0;
    now_s          : DINT;
    log_counter    : DINT := 0;
    batch_ok       : BOOL;
    flush_count    : DINT;
END_VAR

(* ============================================================
   SECTION 1: INFLUXDB CONNECTION
   ============================================================ *)
IF NOT init_done THEN
    INFLUX_CONNECT('home_db', GVL.influx_url, GVL.influx_org,
                   GVL.influx_bucket, GVL.influx_token);
    init_done := TRUE;
END_IF;

GVL.influx_connected := INFLUX_IS_CONNECTED('home_db');

(* ============================================================
   SECTION 2: BATCH LOGGING (every log_interval_s seconds)
   Uses batch mode: add points to buffer, flush once.
   Much more efficient than individual writes.
   ============================================================ *)
now_s := NOW_MS() / 1000;
IF now_s <> prev_second THEN
    prev_second := now_s;
    log_counter := log_counter + 1;
END_IF;

IF GVL.influx_connected AND log_counter >= GVL.log_interval_s THEN
    log_counter := 0;

    (* --- Room temperatures --- *)
    INFLUX_BATCH_ADD('home_db', 'climate', 'room=living',
                     'temperature', GVL.temp_living);
    INFLUX_BATCH_ADD('home_db', 'climate', 'room=living',
                     'humidity', GVL.hum_living);

    INFLUX_BATCH_ADD('home_db', 'climate', 'room=bedroom',
                     'temperature', GVL.temp_bedroom);
    INFLUX_BATCH_ADD('home_db', 'climate', 'room=bedroom',
                     'humidity', GVL.hum_bedroom);

    INFLUX_BATCH_ADD('home_db', 'climate', 'room=kitchen',
                     'temperature', GVL.temp_kitchen);
    INFLUX_BATCH_ADD('home_db', 'climate', 'room=kitchen',
                     'humidity', GVL.hum_kitchen);

    INFLUX_BATCH_ADD('home_db', 'climate', 'room=office',
                     'temperature', GVL.temp_office);
    INFLUX_BATCH_ADD('home_db', 'climate', 'room=office',
                     'humidity', GVL.hum_office);

    INFLUX_BATCH_ADD('home_db', 'climate', 'room=outdoor',
                     'temperature', GVL.temp_outdoor);
    INFLUX_BATCH_ADD('home_db', 'climate', 'room=outdoor',
                     'humidity', GVL.hum_outdoor);

    INFLUX_BATCH_ADD('home_db', 'climate', 'room=garage',
                     'temperature', GVL.temp_garage);
    INFLUX_BATCH_ADD('home_db', 'climate', 'room=garage',
                     'humidity', GVL.hum_garage);

    (* --- Device states --- *)
    INFLUX_BATCH_ADD_INT('home_db', 'devices', 'device=living_lamp',
                         'state', BOOL_TO_INT(GVL.plug_living_lamp));
    INFLUX_BATCH_ADD_INT('home_db', 'devices', 'device=bedroom_fan',
                         'state', BOOL_TO_INT(GVL.plug_bedroom_fan));
    INFLUX_BATCH_ADD_INT('home_db', 'devices', 'device=kitchen_light',
                         'state', BOOL_TO_INT(GVL.plug_kitchen_light));
    INFLUX_BATCH_ADD_INT('home_db', 'devices', 'device=office_heater',
                         'state', BOOL_TO_INT(GVL.plug_office_heater));

    (* --- HVAC --- *)
    INFLUX_BATCH_ADD_INT('home_db', 'hvac', 'unit=main',
                         'mode', GVL.hvac_mode);
    INFLUX_BATCH_ADD('home_db', 'hvac', 'unit=main',
                     'setpoint', GVL.hvac_setpoint);

    (* --- Flush batch --- *)
    flush_count := INFLUX_BATCH_FLUSH('home_db');
    IF flush_count > 0 THEN
        GVL.influx_write_count := GVL.influx_write_count + flush_count;
    END_IF;
END_IF;

END_PROGRAM
```

---

## GoPLC Task Configuration

```yaml
tasks:
  - name: mqtt_bridge
    program: POU_MqttBridge
    scan_time_ms: 200
  - name: automation
    program: POU_Automation
    scan_time_ms: 1000
  - name: data_logger
    program: POU_DataLogger
    scan_time_ms: 1000
```

Three tasks, each at an appropriate scan rate:
- **mqtt_bridge** at 200ms — fast enough for responsive device control
- **automation** at 1000ms — rules don't need sub-second resolution
- **data_logger** at 1000ms — checks its own internal timer for log intervals

---

## Home Assistant Integration

Home Assistant connects to the same MQTT broker. GoPLC publishes state on retained
topics under `goplc/state/*`, and subscribes to commands on `goplc/cmd/*`.

### Home Assistant configuration.yaml

```yaml
mqtt:
  sensor:
    - name: "Living Room Temperature"
      state_topic: "goplc/state/temp_living"
      unit_of_measurement: "°C"
      device_class: temperature

    - name: "Bedroom Temperature"
      state_topic: "goplc/state/temp_bedroom"
      unit_of_measurement: "°C"
      device_class: temperature

    - name: "Kitchen Temperature"
      state_topic: "goplc/state/temp_kitchen"
      unit_of_measurement: "°C"
      device_class: temperature

    - name: "Office Temperature"
      state_topic: "goplc/state/temp_office"
      unit_of_measurement: "°C"
      device_class: temperature

    - name: "Outdoor Temperature"
      state_topic: "goplc/state/temp_outdoor"
      unit_of_measurement: "°C"
      device_class: temperature

    - name: "Garage Temperature"
      state_topic: "goplc/state/temp_garage"
      unit_of_measurement: "°C"
      device_class: temperature

  climate:
    - name: "GoPLC HVAC"
      modes: ["off", "cool", "heat", "auto"]
      mode_state_topic: "goplc/state/hvac_mode"
      mode_state_template: >
        {% set modes = {0: 'off', 1: 'cool', 2: 'heat', 3: 'auto'} %}
        {{ modes[value | int(0)] }}
      mode_command_topic: "goplc/cmd/hvac_mode"
      mode_command_template: >
        {% set modes = {'off': 0, 'cool': 1, 'heat': 2, 'auto': 3} %}
        {{ modes[value] }}
      temperature_state_topic: "goplc/state/hvac_setpoint"
      temperature_command_topic: "goplc/cmd/hvac_setpoint"
      min_temp: 16
      max_temp: 30

  switch:
    - name: "Away Mode"
      state_topic: "goplc/state/away_mode"
      command_topic: "goplc/cmd/away_mode"
      payload_on: "TRUE"
      payload_off: "FALSE"

    - name: "Auto Mode"
      state_topic: "goplc/state/auto_mode"
      command_topic: "goplc/cmd/auto_mode"
      payload_on: "TRUE"
      payload_off: "FALSE"
```

This gives you voice control via Google Home / Alexa through Home Assistant:
- "Set the thermostat to 24 degrees"
- "Turn on away mode"
- "What's the living room temperature?"

---

## Node-RED Dashboard

![Node-RED editor with GoPLC flow](images/home-auto-nodered.png)
*Node-RED flow polling GoPLC variables — debug panel shows live sensor data*

GoPLC bundles Node-RED with Dashboard 2.0. Access at `http://<pi-ip>:<port>/nodered/`.

### Recommended Flows

**Climate Overview Panel:**
```
[goplc-subscribe: temp_living]  → [ui_gauge: Living 🌡]
[goplc-subscribe: temp_bedroom] → [ui_gauge: Bedroom 🌡]
[goplc-subscribe: temp_kitchen] → [ui_gauge: Kitchen 🌡]
[goplc-subscribe: temp_office]  → [ui_gauge: Office 🌡]
[goplc-subscribe: temp_outdoor] → [ui_gauge: Outdoor 🌡]
[goplc-subscribe: temp_garage]  → [ui_gauge: Garage 🌡]
```

**Device Control Panel:**
```
[ui_switch: Living Lamp]    → [goplc-write: cmd_living_lamp]
[ui_switch: Bedroom Fan]    → [goplc-write: cmd_bedroom_fan]
[ui_switch: Kitchen Light]  → [goplc-write: cmd_kitchen_light]
[ui_switch: Office Heater]  → [goplc-write: cmd_office_heater]
```

**HVAC Control:**
```
[ui_dropdown: Mode (Off/Cool/Heat/Auto)]  → [goplc-write: hvac_mode]
[ui_slider: Setpoint 16-30C]              → [goplc-write: hvac_setpoint]
[ui_dropdown: Fan (Auto/Low/Med/High)]    → [goplc-write: hvac_fan]
```

**IR Blaster Bridge** (Node-RED handles edge detection so we don't blast IR every scan):
```
[goplc-subscribe: hvac_json] → [rbe: block unless changed] → [mqtt out: cmnd/ir_blaster/irhvac]
```

**Trend Charts:**
```
[goplc-subscribe: temp_living]  → [ui_chart: 24h Temperature Trend]
[goplc-subscribe: temp_outdoor] → [ui_chart: 24h Temperature Trend]
```

---

## Grafana Dashboards

![InfluxDB dashboard with temperature and device trends](images/home-auto-influxdb.png)
*InfluxDB dashboard — room temperatures, humidity, device states, and HVAC trends*

Connect Grafana to InfluxDB and create dashboards with Flux queries.

### Example: Room Temperature Comparison (last 24 hours)

```flux
from(bucket: "home")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "climate")
  |> filter(fn: (r) => r._field == "temperature")
  |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
```

### Example: Device Runtime per Day

```flux
from(bucket: "home")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "devices")
  |> filter(fn: (r) => r._field == "state")
  |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)
  |> map(fn: (r) => ({r with _value: r._value * 24.0}))
```

### Recommended Dashboard Panels

| Panel | Type | Query |
|-------|------|-------|
| Room temperatures | Time series (6 lines) | climate, field=temperature, group by room |
| Room humidity | Time series (6 lines) | climate, field=humidity, group by room |
| Current temps | Stat (6 values) | climate, last(), group by room |
| HVAC mode | Stat | hvac, field=mode, last() |
| Device on-time | Bar chart | devices, daily mean * 24h |
| Outdoor 7-day | Time series | climate, room=outdoor, 7d range |

---

## Expanding the Project

| Addition | What It Adds | GoPLC Functions Used |
|----------|-------------|---------------------|
| Water leak sensors | Floor sensors via Zigbee, alarm on detection | MQTT_SUBSCRIBE + MQTT_PUBLISH (push notification) |
| Energy monitoring | Shelly EM or CT clamp, track kWh | MQTT_GET_MESSAGE_REAL + INFLUX_BATCH_ADD |
| Irrigation control | Relay board via Modbus, schedule-based | MB_WRITE_COIL + time-of-day logic |
| Pool chemistry | pH/ORP sensors via analog input, dosing pumps | MB_READ_INPUT + PID control |
| Security cameras | Motion events from Frigate via MQTT | MQTT_SUBSCRIBE, trigger recording/lights |
| Weather forecast | HTTP API call, adjust heating/cooling proactively | HTTP_GET + JSON_GET |
| Solar/battery | Modbus to inverter, optimize self-consumption | MB_READ_HOLDING + INFLUX_BATCH_ADD |
| Presence detection | HA companion app publishes location via MQTT | MQTT_GET_MESSAGE, set away_mode |
| Garage door | Shelly 1 relay + reed switch, open/close/status | MQTT_PUBLISH + MQTT_SUBSCRIBE |
| Doorbell | ESP32-CAM + MQTT, snapshot + push notification | MQTT_SUBSCRIBE + HTTP_POST (webhook) |

---

## GoPLC Built-in MQTT Broker (Optional)

Instead of running a separate Mosquitto container, GoPLC can run its own MQTT broker
directly from ST code:

```iecst
(* Create and start a broker on port 1883 *)
MQTT_BROKER_CREATE('local_broker', 1883);
MQTT_BROKER_START('local_broker');

(* Check status *)
IF MQTT_BROKER_IS_RUNNING('local_broker') THEN
    (* Broker is serving clients *)
END_IF;

(* Monitor connected clients *)
clients := MQTT_BROKER_CLIENTS('local_broker');
stats   := MQTT_BROKER_STATS('local_broker');
```

Then point all devices, Home Assistant, and GoPLC's own MQTT client at `tcp://<pi-ip>:1883`.
One fewer container to manage.

---

## ST Function Reference (Used in This Guide)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `MQTT_CLIENT_CREATE` | (name, broker, clientID) | Create MQTT client |
| `MQTT_CLIENT_CREATE_AUTH` | (name, broker, clientID, user, pass) | Create with auth |
| `MQTT_CLIENT_CONNECT` | (name) | Connect to broker |
| `MQTT_CLIENT_IS_CONNECTED` | (name) -> BOOL | Check connection |
| `MQTT_PUBLISH` | (name, topic, payload) | Publish message |
| `MQTT_PUBLISH_RETAINED` | (name, topic, payload) | Publish with retain flag |
| `MQTT_SUBSCRIBE` | (name, topic) | Subscribe to topic |
| `MQTT_HAS_MESSAGE` | (name, topic) -> BOOL | Check for new message |
| `MQTT_GET_MESSAGE` | (name, topic) -> STRING | Get last message payload |
| `MQTT_GET_MESSAGE_REAL` | (name, topic) -> REAL | Get as float |
| `MQTT_GET_MESSAGE_INT` | (name, topic) -> INT | Get as integer |
| `MQTT_GET_MESSAGE_BOOL` | (name, topic) -> BOOL | Get as boolean |
| `MQTT_BROKER_CREATE` | (name, port) | Create built-in broker |
| `MQTT_BROKER_START` | (name) | Start broker |
| `INFLUX_CONNECT` | (name, url, org, bucket, token) | Connect InfluxDB v2 |
| `INFLUX_IS_CONNECTED` | (name) -> BOOL | Check connection |
| `INFLUX_BATCH_ADD` | (name, measurement, tags, field, value) | Buffer a REAL point |
| `INFLUX_BATCH_ADD_INT` | (name, measurement, tags, field, value) | Buffer an INT point |
| `INFLUX_BATCH_FLUSH` | (name) -> DINT | Flush buffer, return count |
| `INFLUX_WRITE` | (name, measurement, tags, field, value) | Write single REAL point |
