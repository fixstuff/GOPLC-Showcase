# GoPLC Reference Guides

Complete technical documentation for every GoPLC subsystem. Each guide includes architecture diagrams, function signatures, parameter tables, IEC 61131-3 Structured Text examples, and transport-specific notes.

---

## Hardware Interfaces

Connect microcontrollers and USB devices directly to your PLC logic. GoPLC handles firmware upload, protocol framing, and connection management — your ST code just calls functions.

| Guide | Target | Functions | Description |
|-------|--------|:---------:|-------------|
| **[Parallax P2](goplc_p2_guide.md)** | Propeller 2 (Rev G) | 82 | 44 binary protocol commands + 38 convenience functions. Smart pins, UART, I2C, SPI, ADC/DAC, PWM, servo, quadrature encoder, frequency counter, OLED display, animated eyes. 3 Mbaud USB, CRC-16 protected, schema-driven. |
| **[Arduino](goplc_arduino_guide.md)** | Uno R4 WiFi | 20 | GPIO, 14-bit analog, PWM, DAC, I2C, servo, WiFi, BLE, LED matrix, HC-SR04 ultrasonic. |
| **[Teensy](goplc_teensy_guide.md)** | Teensy 4.0 | 47 | CAN bus, hardware PID, complementary PWM, NeoPixel, encoder, RTC, TRNG, SPI, UART. |
| **[Flipper Zero](goplc_flipper_guide.md)** | Flipper Zero | 31 | NFC, RFID (125 kHz), Sub-GHz radio, infrared, iButton, GPIO. |
| **[RP2040-Zero](goplc_rp2040_guide.md)** | Waveshare RP2040-Zero | 26 | GPIO, ADC, PWM, NeoPixel, I2C, SPI, UART, servo, OLED, distance, temp sensor. Rust firmware (UF2). |
| **[ESP32 HMI Dongle](goplc_esp32_hmi_guide.md)** | ESP32-S3-LCD-1.47 | Companion | WiFi status display + USB mass storage. mDNS auto-discovery, live scan times/faults/memory, OTA updates. |
| **[Phidgets](goplc_phidgets_guide.md)** | Phidgets USB | 16 | Voltage, current, temperature, humidity, load cells, relays, motors. |

## CNC, Laser & 3D Printing

Stream G-code to machines with real-time parsing, parameter modification, and multi-transport support. Use ST logic to add safety limits, feed overrides, and sensor integration that slicers and CAM tools can't do alone.

| Guide | Target | Functions | Description |
|-------|--------|:---------:|-------------|
| **[G-code](goplc_gcode_guide.md)** | CNC / Laser / 3D Printer | 41 | File I/O, line parser/modifier, machine connection, status, position, pause/resume/stop. Three transports: xTool HTTP, GRBL serial, Marlin serial. CLI streaming mode (free, no license). |

## Industrial Protocols

First-class client and server implementations for every major automation protocol. Multi-device polling, type-safe memory areas, and diagnostic counters built in.

| Guide | Protocol | Functions | Description |
|-------|----------|:---------:|-------------|
| **[Modbus TCP](goplc_modbus_tcp_guide.md)** | Modbus TCP/IP | 30 | Client + server, FC01-FC16, multi-device polling. |
| **[Modbus RTU](goplc_modbus_rtu_guide.md)** | Modbus RTU (serial) | 30 | Client + server, RS-485, bus scanning, RTU-over-TCP bridge. |
| **[EtherNet/IP](goplc_enip_guide.md)** | CIP / EtherNet/IP | 43 | Scanner + adapter, tag browsing, Allen-Bradley integration. |
| **[Siemens S7](goplc_s7_guide.md)** | S7comm | 38 | Client + server, DB/I/Q/M areas, S7-300/400/1200/1500. |
| **[OPC UA](goplc_opcua_guide.md)** | OPC UA | 36 | Client + server, node browsing, security policies. |
| **[MQTT](goplc_mqtt_guide.md)** | MQTT 3.1.1 | 36 | Client + built-in broker, pub/sub, message queue, QoS levels. |
| **[Omron FINS](goplc_fins_guide.md)** | FINS/UDP | 23 | Client + server, DM/CIO memory areas, CJ/NJ/NX series. |
| **[DNP3](goplc_dnp3_guide.md)** | DNP3 | 25 | Master + outstation, BI/BO/AI/AO/counter, SCADA/utility. |
| **[IEC 104](goplc_iec104_guide.md)** | IEC 60870-5-104 | 27 | Client + server, SP/DP/float/scaled/counter, power grid. |
| **[BACnet](goplc_bacnet_guide.md)** | BACnet/IP | 36+ | Client + server, priority array, COV, WhoIs, HVAC/BMS. |
| **[SNMP](goplc_snmp_guide.md)** | SNMPv1/v2c/v3 | 36+ | Client + agent + trap receiver, OID helpers, datacenter monitoring. |
| **[DF1](goplc_df1_guide.md)** | DF1 (AB serial) | 16 | Client, SLC 500 / MicroLogix, N7/F8/B3 file addressing. |
| **[Sparkplug B](goplc_sparkplug_guide.md)** | Sparkplug B / MQTT | 16 | Edge node, NBIRTH/NDATA lifecycle, Ignition integration. |
| **[InfluxDB](goplc_influxdb_guide.md)** | InfluxDB v1/v2 | 16 | Write + batch, line protocol, Grafana dashboards. |
| **[JSON](goplc_json_guide.md)** | JSON Functions | 22 | Parse, build, query, modify JSON from ST. Dot-path access, typed getters, JSONPath. |
| **[HTTP Client](goplc_http_guide.md)** | HTTP Functions | 16 | GET/POST/PUT/DELETE from ST. Response maps, custom headers, JSON auto-parse, webhooks. |
| **[File I/O](goplc_fileio_guide.md)** | File Functions | 15 | Read/write/append files, line-by-line processing, CSV logging, recipe management. Sandboxed. |

## Platform

Core development tools, distributed execution, and visual programming.

| Guide | Topic | Description |
|-------|-------|-------------|
| **[IDE & Runtime](goplc_ide_runtime_guide.md)** | Development Environment | Browser IDE, task scheduler, debugger with breakpoints + stepping, HMI builder, project files, protocol analyzer, store-and-forward. |
| **[AI Assistant](goplc_ai_guide.md)** | Built-in AI | Chat + autonomous control mode, 13 runtime tools, Claude/OpenAI/Ollama providers, code/HMI/flow generation, voice input. |
| **[Timers, Counters & FBs](goplc_timers_counters_guide.md)** | Function Blocks | TON, TOF, TP, RTO, CTU, CTD, CTUD, SR, RS, R_TRIG, F_TRIG, PID, PIDE — 14 IEC 61131-3 FBs with timing diagrams. |
| **[Configuration](goplc_config_guide.md)** | YAML Reference | Every config field documented: tasks, protocols, I/O mapping, DataLayer, AI, Node-RED, real-time, fleet, security, ctrlX. |
| **[Clustering](goplc_clustering_guide.md)** | Distributed Execution | Boss/minion architecture, DataLayer pub/sub, fleet management, tested to 500 minions. |
| **[Node-RED](goplc_nodered_guide.md)** | Flow Programming | 7 custom GoPLC nodes, Dashboard 2.0, AI-generated flows. |

---

*GoPLC v1.0.533 | April 2026*
*© 2026 JMB Technical Services LLC. All rights reserved.*
