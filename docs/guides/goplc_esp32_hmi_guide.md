# GoPLC ESP32 HMI Dongle Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.533

---

## 1. Overview

The GoPLC HMI Dongle is a pocket-sized status display and USB drive built on the Waveshare ESP32-S3-LCD-1.47. It connects to any running GoPLC instance over WiFi and shows live runtime status on a 172x320 color LCD. The SD card slot doubles as a USB mass storage device — plug it into any PC and it appears as a flash drive containing your GoPLC portable installation.

No ST functions, no configuration files on the PLC side — the dongle discovers GoPLC automatically via mDNS and polls the REST API.

### What It Shows

```
┌──────────────────┐
│    GOPLC HMI     │  ← Header (green text on dark blue)
│                  │
│     Running      │  ← PLC state (green/orange/red)
│   USBKeyGOPLC    │  ← Instance name (cyan)
│   10.0.0.31      │  ← PLC IP address
│ ──────────────── │
│  Scan:   45us    │  ← Last scan time
│  Avg:    42us    │  ← Average scan time
│  Tasks:    3     │  ← Active task count
│  Faults:   0     │  ← Fault count (red if > 0)
│  Vars:   150     │  ← Variable count
│ ──────────────── │
│  Mem: 65.2/128MB │  ← Alloc / System memory
│  Up: 04:12:30    │  ← Uptime
│  Goroutines: 42  │
│  ESP Heap: 180KB │  ← ESP32 free memory
│  WiFi: -45dBm    │  ← Signal strength
│ ──────────────── │
│  USB: 7640MB     │  ← SD card size
│                  │
│  192.168.1.42    │  ← ESP32 IP address
└──────────────────┘
```

### Hardware

| Component | Detail |
|-----------|--------|
| **Board** | Waveshare ESP32-S3-LCD-1.47 |
| **MCU** | ESP32-S3 (dual-core, 240 MHz, WiFi + BLE) |
| **Display** | ST7789, 172x320 pixels, 1.47" rectangular LCD |
| **Storage** | MicroSD slot (FAT32, appears as USB mass storage) |
| **USB** | USB-C (power + USB OTG for mass storage) |
| **Firmware** | C++ (Arduino framework, PlatformIO) |

---

## 2. How It Works

```
┌───────────────────────┐         WiFi          ┌──────────────────────┐
│  ESP32 HMI Dongle     │◄──────────────────────►│  GoPLC Runtime       │
│                       │                        │                      │
│  1. WiFi connect      │   mDNS discovery       │  _goplc._tcp.local   │
│  2. mDNS: find GOPLC  │◄──────────────────────│  instance=USBKey...  │
│  3. Poll /api/diag    │   HTTP GET (1s)        │                      │
│  4. Update display    │◄──────────────────────►│  /api/diagnostics    │
│                       │                        │                      │
│  USB Mass Storage     │         USB            │                      │
│  SD card ←→ PC        │◄──────────────────────►│  (separate machine)  │
└───────────────────────┘                        └──────────────────────┘
```

1. **Boot**: ESP32 initializes display, SD card (USB mass storage), and WiFi
2. **Discovery**: Queries mDNS for `_goplc._tcp` services, matches by instance name
3. **Polling**: HTTP GET to `/api/diagnostics` every 1 second
4. **Display**: Parses JSON response, updates only changed values (flicker-free)
5. **Reconnect**: If 5 consecutive polls fail, re-runs mDNS discovery

No configuration needed on the GoPLC side — the dongle reads the standard `/api/diagnostics` endpoint that every GoPLC instance exposes.

---

## 3. Flashing the Firmware

### Prerequisites

- PlatformIO (CLI or VS Code extension)
- USB-C cable
- The ESP32-S3-LCD-1.47 board

### Build and Flash

```bash
cd esp32-hmi
pio run -t upload
```

If the board doesn't enter flash mode automatically, hold the **BOOT** button while plugging in USB, then run the upload command.

### OTA Updates (Over WiFi)

Once the firmware is running and connected to WiFi, subsequent updates can be done wirelessly:

```bash
pio run -t upload --upload-port <esp32-ip>
```

The display shows "OTA UPDATE" with a progress bar during the flash. Do not unplug power during OTA.

> **Windows firewall**: If OTA fails with "No response from device", allow UDP port 3232 and TCP ports 1024-65535 from the ESP32's IP.

---

## 4. Configuration

### WiFi Credentials

Edit `src/main.cpp` before flashing:

```cpp
#define WIFI_SSID     "YourNetwork"
#define WIFI_PASSWORD "YourPassword"
```

### Instance Filtering

By default, the dongle connects to the first GoPLC it finds via mDNS. To target a specific instance:

```cpp
String goplcInstance = "USBKeyGOPLC";   // Match this mDNS instance name
```

GoPLC advertises its instance name at startup:

```
mDNS: Advertising as MYPC-8300._goplc._tcp.local:8300
```

Set `goplcInstance` to match (e.g., `"MYPC-8300"`).

### SD Card Config (Alternative)

Instead of compile-time config, create `config.json` on the SD card:

```json
{
    "wifi_ssid": "YourNetwork",
    "wifi_password": "YourPassword",
    "goplc_instance": "MYPC-8300"
}
```

Or use explicit IP (skips mDNS):

```json
{
    "wifi_ssid": "YourNetwork",
    "wifi_password": "YourPassword",
    "goplc_host": "10.0.0.196",
    "goplc_port": 8302
}
```

---

## 5. USB Mass Storage

The SD card appears as a USB flash drive when the dongle is plugged into any PC. This enables a portable GoPLC deployment:

```
F:\                         (USB drive)
├── goplc\
│   ├── goplc.exe           Windows binary
│   ├── config.yaml         Runtime config (mdns_name: USBKeyGOPLC)
│   ├── st_code\            ST programs
│   │   └── main.st
│   └── web\                Web IDE files
└── config.json             ESP32 WiFi/instance config (optional)
```

**Usage:**
1. Plug dongle into any Windows PC
2. Open the USB drive
3. Run `goplc\goplc.exe`
4. The dongle automatically discovers and displays the running PLC status

The SD card uses the SDMMC interface on the ESP32-S3 with USB OTG for mass storage. Both the PC and the ESP32 can access the card, but not simultaneously — the ESP32 reads `config.json` at boot, then hands the card to USB.

---

## 6. Display Driver

The Waveshare ESP32-S3-LCD-1.47 uses an ST7789 display controller. The firmware uses Waveshare's native ST7789 driver — **not TFT_eSPI** (which crashes on this board).

### Pin Configuration

| Function | GPIO |
|----------|------|
| LCD MOSI | 45 |
| LCD SCLK | 40 |
| LCD CS | 42 |
| LCD DC | 41 |
| LCD RST | 39 |
| LCD Backlight | 48 |
| SD CS | 14 |
| SD MISO | 13 |

### Rendering

- 5x7 ASCII bitmap font (uppercase + digits + symbols)
- Flicker-free updates: only redraws changed values
- Color-coded status: green (running), orange (stopped), red (faulted)
- Fault count turns red when > 0
- Scan times auto-switch between microseconds and milliseconds

---

## 7. API Endpoint

The dongle polls a single endpoint:

```
GET /api/diagnostics
```

Response fields used:

| JSON Path | Display Field |
|-----------|---------------|
| `runtime.state` | PLC state (Running/Stopped/Faulted) |
| `tasks[0].last_scan_ms` | Scan time |
| `tasks[0].avg_scan_ms` | Average scan time |
| `tasks` (array length) | Task count |
| `tasks[].faulted` | Fault count |
| `variables.count` | Variable count |
| `memory.alloc_mb` | Allocated memory |
| `memory.sys_mb` | System memory |
| `uptime_seconds` | Uptime |
| `goroutines` | Goroutine count |

No authentication is required. The dongle makes read-only requests — it cannot modify the PLC.

---

## 8. Telnet Debug Server

When connected to WiFi, the dongle runs a telnet server on port 23 for remote debugging:

```bash
telnet <esp32-ip> 23
# or
nc <esp32-ip> 23
```

Debug output includes:
- mDNS discovery results
- HTTP poll status and errors
- WiFi connection events
- OTA progress

This is essential for troubleshooting since the USB port is used for mass storage and may not be available for serial monitor.

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Display shows "DISCONNECTED / Searching..." | GoPLC not found via mDNS | Verify GoPLC is running. Check instance name matches. Ensure both devices on same network/subnet. |
| WiFi won't connect | Wrong credentials or 5GHz network | ESP32 only supports 2.4GHz. Check SSID/password. |
| USB drive not appearing | SD card not FAT32 or not inserted | Format SD card as FAT32. Try different USB port. |
| Display blank | Backlight or driver issue | Check GPIO 48 (backlight). Verify ST7789 driver, not TFT_eSPI. |
| OTA update fails | Firewall blocking | Allow UDP 3232 and TCP 1024-65535 from ESP32 IP. |
| Scan times show 0 | No tasks running | Start the PLC runtime — dongle reads from first task. |
| "ESP Heap" dropping | Memory leak in HTTP client | Normal if stable. Restart dongle if it drops below 50KB. |

---

## 10. PlatformIO Project Structure

```
esp32-hmi/
├── platformio.ini              Build config (ESP32-S3, Arduino framework)
├── src/
│   ├── main.cpp                Application (WiFi, mDNS, API polling, display)
│   ├── Display_ST7789.cpp      ST7789 display driver (Waveshare native)
│   ├── Display_ST7789.h        Pin definitions and display functions
│   ├── USB_MSC.cpp             USB mass storage (SD card over USB OTG)
│   └── USB_MSC.h               MSC configuration
├── lib/                        Libraries (ArduinoJson)
├── sdcard/                     Default SD card contents
├── CLAUDE.md                   Development notes
└── README.md                   Quick start
```

### Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| ArduinoJson | 7.x | Parse `/api/diagnostics` response |
| ESPmDNS | (built-in) | Discover GoPLC on network |
| ArduinoOTA | (built-in) | Over-the-air firmware updates |
| WiFi | (built-in) | Network connectivity |

---

*GoPLC v1.0.533 | ESP32-S3 HMI Dongle | Waveshare ESP32-S3-LCD-1.47*
*WiFi + mDNS Auto-Discovery | USB Mass Storage | ST7789 172x320 Display*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
