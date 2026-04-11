# Appendix A: Acknowledgements {-}

GoPLC is written in Go, assembled from dozens of excellent open-source libraries, and rendered into this manual with open-source tooling. None of what you are reading would exist without the generosity of the engineers and maintainers listed on these pages. **Thank you** — this project stands entirely on your shoulders.

The list below is not exhaustive; it covers the direct dependencies that ship inside the GoPLC binary and the tools used to build this book. Every library is cited with its license so that commercial users can verify compatibility without digging through `go.sum`.

## Runtime and Language Tooling {-}

| Library | Purpose | License |
|---------|---------|---------|
| **The Go Programming Language** (golang.org) | Runtime, compiler, standard library | BSD 3-Clause |
| **golang.org/x/crypto** | TLS, AES-GCM, Ed25519, bcrypt, X.509 helpers | BSD 3-Clause |
| **golang.org/x/sys, /x/net, /x/text, /x/sync** | Cross-platform system, networking, and text primitives | BSD 3-Clause |
| **google.golang.org/protobuf** | Protocol buffer encoding used by EtherNet/IP, OPC UA, Sparkplug B | BSD 3-Clause |
| **gopkg.in/yaml.v3** | YAML configuration parser | MIT + Apache 2.0 |

## Web, API, and Serialization {-}

| Library | Purpose | License |
|---------|---------|---------|
| **gin-gonic/gin** | HTTP router and middleware used by the REST API | MIT |
| **gorilla/websocket** | WebSocket transport for live variable streaming, event bus, and analyzer | BSD 2-Clause |
| **swaggo/swag, gin-swagger, files** | Swagger/OpenAPI generation and browser UI | MIT |
| **google/uuid** | RFC 4122 UUID generation | BSD 3-Clause |
| **grandcat/zeroconf** | mDNS/Bonjour for fleet auto-discovery | MIT |
| **alecthomas/participle** | PEG parser used by the Structured Text compiler | MIT |
| **Monaco Editor** (microsoft/monaco-editor) | Browser-side code editor for the IDE | MIT |

## Storage and Data {-}

| Library | Purpose | License |
|---------|---------|---------|
| **modernc.org/sqlite** | Pure-Go SQLite driver for snapshots, store-and-forward, and event store | BSD 3-Clause |
| **lib/pq** | PostgreSQL driver | MIT |
| **go-sql-driver/mysql** | MySQL driver | MPL 2.0 |

## Industrial Protocol Stacks {-}

| Library | Purpose | License |
|---------|---------|---------|
| **eclipse/paho.mqtt.golang** | MQTT 3.1.1 client, used under the hood by `MQTT_*` functions | EPL 2.0 / EDL 1.0 |
| **mochi-mqtt/server** | Embedded MQTT broker (`MQTT_BROKER_*` functions) | MIT |
| **simonvetter/modbus** | Modbus TCP and RTU client/server implementation | MIT |
| **tbrandon/mbserver** | Modbus server primitives | BSD 3-Clause |
| **gopcua/opcua** | OPC UA client and server stack | MIT |
| **boschrexroth/ctrlx-datalayer-golang** | ctrlX DataLayer IPC bridge for the Bosch Rexroth ctrlX CORE platform | MIT |

## Hardware and Serial {-}

| Library | Purpose | License |
|---------|---------|---------|
| **go.bug.st/serial** | Cross-platform serial port library used by all serial protocol drivers | BSD 3-Clause |
| **tarm/serial** | Legacy serial helper retained for compatibility | BSD 3-Clause |
| **periph.io/x/conn, periph.io/x/host** | GPIO, I²C, and SPI access on Linux single-board computers | Apache 2.0 |

## Security and Encoding {-}

| Library | Purpose | License |
|---------|---------|---------|
| **fernet/fernet-go** | Symmetric token encryption for license verification | MIT |

## Bundled Third-Party Structured Text Library {-}

| Library | Purpose | License |
|---------|---------|---------|
| **OSCAT — Open Source Community for Automation Technology** | IEC 61131-3 function library with 550+ blocks for engineering math, signal processing, control, and time/date handling. Bundled with GoPLC and callable directly from ST. | LGPL 3.0 |

OSCAT is an independent community project and is not affiliated with JMB Technical Services LLC. The library is included for convenience and may be removed or replaced at any time.

## Firmware and Microcontroller Toolchains {-}

GoPLC talks to a range of microcontrollers over USB and serial. Those devices run their own firmware, compiled with their own toolchains, maintained by communities that predate GoPLC by many years. The firmware images are distributed as separate files alongside the GoPLC binary — they are not statically linked into the runtime — so each license applies only to the firmware image on the target device, not to GoPLC itself.

Without the work of the following projects, the entire hardware-interface story in Part IV of this manual would be impossible. **Thank you.**

| Platform | Firmware / Toolchain | Maintainers | License |
|----------|----------------------|-------------|---------|
| **Parallax Propeller 2 (P2)** | Spin2 language, PASM2 assembler, `flexspin` / `PNut` compilers | Chip Gracey, Eric Smith, Parallax Inc. and the Parallax community | Per upstream Parallax and `flexspin` repositories (permissive) |
| **P2 Forth** | Tachyon / TAQOZ-style Forth cores for the Propeller 2 | Peter Jakacki and the Parallax Forth community | Per upstream (permissive) |
| **Arduino (Uno R4 WiFi)** | Arduino core for Renesas RA, ArduinoCore-API, standard Arduino libraries | Arduino S.r.l. and the Arduino community | LGPL 2.1 (Arduino core), MIT / BSD (most libraries) |
| **Teensy 4.0** | Teensyduino core, `cores/teensy4`, TeensyThreads, SPI/I²C/USB libraries | Paul Stoffregen / PJRC and contributors | MIT (majority of PJRC core), LGPL 2.1 (Arduino-derived portions) |
| **Waveshare RP2040-Zero** | `rp-hal`, `rp2040-hal`, `embedded-hal`, `embassy` Rust crates; optionally the Raspberry Pi Pico SDK | The Rust Embedded Working Group, Raspberry Pi Ltd. | MIT / Apache 2.0 (dual-licensed) |
| **ESP32 HMI dongle (ESP32-S3-LCD-1.47)** | ESP-IDF, LVGL display stack, `esp32-arduino` | Espressif Systems, LVGL community | Apache 2.0 (ESP-IDF), MIT (LVGL), LGPL 2.1 (esp32-arduino where used) |
| **Flipper Zero** | Flipper Zero firmware and application SDK | Flipper Devices Inc. and contributors | Per upstream Flipper firmware repository |

Readers who plan to redistribute modified firmware for any of these targets should consult the upstream repositories for authoritative and current license terms. The table above is a best-effort summary, not a substitute for reading the upstream `LICENSE` files.

## Documentation and Build Tooling {-}

This manual was typeset with the following open-source tools. Thank you to the TeX, pandoc, and LaTeX communities for decades of free access to professional-grade typography.

| Tool | Purpose | License |
|------|---------|---------|
| **pandoc** | Markdown-to-LaTeX conversion and manual assembly | GPL 2.0+ |
| **XeLaTeX / TeX Live** | PDF rendering engine | LPPL 1.3c |
| **KOMA-Script (scrbook)** | Book document class and page layout | LPPL 1.3c |
| **fancyhdr** | Page headers and footers | LPPL 1.3c |
| **DejaVu Fonts** | Serif, sans-serif, and monospace families used throughout the book | DejaVu Fonts License (Bitstream Vera derivative, permissive) |

## A Note on Licensing Compatibility {-}

GoPLC is distributed under a commercial, per-instance license. All of the libraries above were selected in part for their compatibility with commercial redistribution. The GPL-licensed tools in the "Documentation and Build Tooling" table are used **only** to build this manual — they are not linked into or distributed with the GoPLC binary.

## Corrections {-}

If you believe a library is misattributed, licensed differently than shown, or missing from this list, please file an issue at `goplc.app` or email `jbelcher@jmbtechnical.com`. We will correct the next edition promptly.

---

*Thank you, again, to every author whose code made this possible.*
