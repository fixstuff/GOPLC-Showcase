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
| **[SEL Relay](goplc_sel_guide.md)** | SEL Fast Message | 54 | Client + server + meter. Mirrored bits, SER, oscillography, COMTRADE, settings. |
| **[InfluxDB](goplc_influxdb_guide.md)** | InfluxDB v1/v2 | 16 | Write + batch, line protocol, Grafana dashboards. |

## ST Language & Libraries

Built-in functions callable from Structured Text — data processing, integration, and fault tolerance.

| Guide | Category | Functions | Description |
|-------|----------|:---------:|-------------|
| **[Timers, Counters & FBs](goplc_timers_counters_guide.md)** | Function Blocks | 14 | TON, TOF, TP, RTO, CTU, CTD, CTUD, SR, RS, R_TRIG, F_TRIG, PID, PIDE. |
| **[Math, String & Conversion](goplc_math_string_guide.md)** | IEC Standard + Extensions | 150+ | Trig, rounding, statistics, EMA/SMA, string ops, type conversions, bitwise, unit conversions. |
| **[JSON](goplc_json_guide.md)** | Data Interchange | 22 | Parse, build, query, modify JSON. Dot-path access, typed getters, JSONPath. |
| **[HTTP Client](goplc_http_guide.md)** | Web Integration | 16 | GET/POST/PUT/DELETE from ST. Response maps, custom headers, webhooks. |
| **[File I/O](goplc_fileio_guide.md)** | File System | 15 | Read/write/append files, line-by-line processing, CSV logging. Sandboxed. |
| **[Database](goplc_database_guide.md)** | Persistence | 18 | SQLite, PostgreSQL, MySQL. Query, insert, transactions, schema management. |
| **[Data Structures](goplc_datastructures_guide.md)** | Collections | ~160 | ARRAY, MAP, LIST, QUEUE, STACK, DEQUE, SET, HEAP/PQUEUE. |
| **[Resilience & Caching](goplc_resilience_guide.md)** | Fault Tolerance | 35 | Cache, circuit breaker, rate limiter, throttle, debounce, bulkhead, hysteresis. |
| **[Debug & Logging](goplc_debug_guide.md)** | Diagnostics | 36 | Multi-target logging: file, SQLite, PostgreSQL, InfluxDB, syslog, console. Per-module levels. |
| **[Motion Control](goplc_motion_guide.md)** | PLCopen MC | 23 | Create axes, trapezoidal profiles, absolute/relative/velocity moves, homing, jog, PLCopen state machine. |
| **[CSV & INI](goplc_csv_ini_guide.md)** | File Formats | 20 | CSV parse/query/modify/export + INI file read/write/parse. Recipe management, config files. |
| **[Regular Expressions](goplc_regex_guide.md)** | Pattern Matching | 13 | Match, find, replace, split, capture groups, count, validate. RE2 engine, RE_* aliases. |
| **[Cryptography](goplc_crypto_guide.md)** | Security | ~55 | SHA/MD5 hashing, HMAC, AES (CBC/GCM), RSA encrypt/sign, Base64, JWT auth, CRC checksums. |
| **[SMTP Email](goplc_smtp_guide.md)** | Email | 4 | Send plain text, HTML, authenticated, and TLS-encrypted email from ST. Alarm notifications. |
| **[Analyzer & Store-Forward](goplc_analyzer_storeforward_guide.md)** | Diagnostics | 22 | Protocol packet capture, decode, PCAP export + offline message queuing with SQLite persistence. |
| **[NMEA & GPS](goplc_nmea_gps_guide.md)** | Geospatial | 26 | Parse GPS sentences, extract position/speed/altitude, geofencing, distance/bearing calculations. |
| **[Entertainment](goplc_entertainment_guide.md)** | Show Control | 40 | Art-Net DMX (7), sACN/E1.31 (7), MIDI (14), OSC (12) — stage lighting, sound, installations. |
| **[Utilities](goplc_utilities_guide.md)** | Specialized | 83 | KNX, M-Bus, ZPL labels, barcode, URL, TLV/BER, GSV/SSV, ctrlX EtherCAT, directory ops. |
| **[OSCAT Library](goplc_oscat_guide.md)** | ST Library | 550 | Open-source IEC 61131-3 library. Complex math, PID, signal processing, sensors, date/time, scheduling. |

## Platform

Core development tools, distributed execution, and visual programming.

| Guide | Topic | Description |
|-------|-------|-------------|
| **[IDE & Runtime](goplc_ide_runtime_guide.md)** | Development Environment | Browser IDE, task scheduler, debugger with breakpoints + stepping, HMI builder, project files, protocol analyzer, store-and-forward. |
| **[AI Assistant](goplc_ai_guide.md)** | Built-in AI | Chat + autonomous control mode, 13 runtime tools, Claude/OpenAI/Ollama providers, code/HMI/flow generation, voice input. |
| **[REST API & Swagger](goplc_api_guide.md)** | API Reference | All 254 endpoints by group, Swagger UI, WebSocket, authentication, common patterns. |
| **[Configuration](goplc_config_guide.md)** | YAML Reference | Every config field documented: tasks, protocols, I/O mapping, DataLayer, AI, Node-RED, real-time, fleet, security, ctrlX. |
| **[Clustering](goplc_clustering_guide.md)** | Distributed Execution | Boss/minion architecture, DataLayer pub/sub, fleet management, tested to 500 minions. |
| **[Node-RED](goplc_nodered_guide.md)** | Flow Programming | 7 custom GoPLC nodes, Dashboard 2.0, AI-generated flows. |

---

*GoPLC v1.0.533 | April 2026*
*© 2026 JMB Technical Services LLC. All rights reserved.*
