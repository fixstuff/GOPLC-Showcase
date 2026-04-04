# GoPLC Reference Guides

Complete documentation for every GoPLC subsystem — hardware targets, industrial protocols, and platform features. Each guide includes function signatures, parameter tables, and IEC 61131-3 Structured Text code examples.

---

## Hardware Interfaces

| Guide | Target | Functions | Description |
|-------|--------|-----------|-------------|
| [Parallax P2](goplc_p2_guide.md) | Propeller 2 (Rev G) | 44 commands | Smart pins, UART, I2C, SPI, ADC/DAC, servo, OLED, animated eyes, TAQOZ Forth |
| [Arduino](goplc_arduino_guide.md) | Uno R4 WiFi | 20 | GPIO, analog (14-bit), PWM, DAC, I2C, servo, WiFi, BLE, LED matrix, HC-SR04 |
| [Teensy](goplc_teensy_guide.md) | Teensy 4.0 | 47 | CAN bus, hardware PID, complementary PWM, NeoPixel, encoder, RTC, TRNG, SPI, UART |
| [Flipper Zero](goplc_flipper_guide.md) | Flipper Zero | 31 | NFC, RFID (125kHz), Sub-GHz radio, infrared, iButton, GPIO |
| [Phidgets](goplc_phidgets_guide.md) | Phidgets USB | 16 | Voltage, current, temperature, humidity, load cells, relays, motors |

## Industrial Protocols

| Guide | Protocol | Functions | Description |
|-------|----------|-----------|-------------|
| [Modbus TCP](goplc_modbus_tcp_guide.md) | Modbus TCP/IP | 30 | Client + server, FC01-FC16, multi-device polling |
| [Modbus RTU](goplc_modbus_rtu_guide.md) | Modbus RTU (serial) | 30 | Client + server, RS-485, bus scanning, RTU-over-TCP bridge |
| [EtherNet/IP](goplc_enip_guide.md) | CIP / EtherNet/IP | 43 | Scanner + adapter, tag browsing, Allen-Bradley integration |
| [Siemens S7](goplc_s7_guide.md) | S7comm | 38 | Client + server, DB/I/Q/M areas, S7-300/400/1200/1500 |
| [OPC UA](goplc_opcua_guide.md) | OPC UA | 36 | Client + server, node browsing, security policies |
| [MQTT](goplc_mqtt_guide.md) | MQTT 3.1.1 | 36 | Client + built-in broker, pub/sub, message queue, QoS |
| [Omron FINS](goplc_fins_guide.md) | FINS/UDP | 15 | Client, DM/CIO memory areas, CJ/NJ/NX series |
| [DNP3](goplc_dnp3_guide.md) | DNP3 | 25 | Master + outstation, BI/BO/AI/AO/counter, SCADA/utility |
| [IEC 104](goplc_iec104_guide.md) | IEC 60870-5-104 | 27 | Client + server, SP/DP/float/scaled/counter, power utility |
| [BACnet](goplc_bacnet_guide.md) | BACnet/IP | 36+ | Client + server, priority array, COV, WhoIs, HVAC/BMS |
| [SNMP](goplc_snmp_guide.md) | SNMPv1/v2c/v3 | 36+ | Client + agent + trap receiver, OID helpers, datacenter |
| [DF1](goplc_df1_guide.md) | DF1 (AB serial) | 16 | Client, SLC 500 / MicroLogix, N7/F8/B3 file addressing |
| [Sparkplug B](goplc_sparkplug_guide.md) | Sparkplug B / MQTT | 16 | Edge node, NBIRTH/NDATA lifecycle, Ignition integration |
| [InfluxDB](goplc_influxdb_guide.md) | InfluxDB v1/v2 | 16 | Write + batch, line protocol, Grafana dashboards |

## Platform

| Guide | Topic | Description |
|-------|-------|-------------|
| [IDE & Runtime](goplc_ide_runtime_guide.md) | Development environment | Browser IDE, task scheduler, debugger (breakpoints + stepping), AI assistant, HMI builder, project files, protocol analyzer, store-and-forward |
| [Clustering](goplc_clustering_guide.md) | Distributed execution | Boss/minion architecture, DataLayer pub/sub, fleet management, 500-minion scaling |
| [Node-RED](goplc_nodered_guide.md) | Flow programming | 7 custom GOPLC nodes, Dashboard 2.0, AI-generated flows |

---

*GoPLC v1.0.520 | April 2026*
*© 2026 JMB Technical Services LLC. All rights reserved.*
