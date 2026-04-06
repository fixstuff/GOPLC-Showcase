# GoPLC Specialized Utilities Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

This guide covers specialized utility functions that don't fit into the major protocol or library guides.

| Category | Functions | Use Case |
|----------|-----------|----------|
| **KNX** | 6 | Building automation (lighting, HVAC, blinds) |
| **M-Bus** | 12 | Utility meter reading (water, gas, heat, electric) |
| **ZPL** | 8 | Zebra label printing |
| **Barcode** | 6 | Barcode parsing and validation |
| **URL** | 8 | URL parsing and building |
| **TLV/BER** | 12 | Tag-Length-Value encoding (smart cards, ASN.1) |
| **GSV/SSV** | 17 | Get/Set System Value (Allen-Bradley compatibility) |
| **ctrlX EtherCAT** | 10 | Bosch Rexroth ctrlX I/O |
| **DIR** | 4 | Directory operations |

---

## 2. KNX — Building Automation (6)

Control KNX/EIB devices (lights, blinds, HVAC) on a KNX/IP network.

```iecst
(* Switch a light on/off *)
KNX_SWITCH('knx-gw:3671', '1/1/1', TRUE);

(* Dim to 75% *)
KNX_DIM('knx-gw:3671', '1/1/2', 75);

(* Set temperature setpoint (2-byte float) *)
KNX_SET_FLOAT('knx-gw:3671', '3/1/0', 22.5);

(* Set 1-byte value *)
KNX_SET_VALUE('knx-gw:3671', '1/1/3', 128);

(* Raw data send *)
KNX_SEND('knx-gw:3671', '1/1/4', 16#01, 16#FF);

(* Build group address from components *)
addr := KNX_GROUP_ADDR(1, 1, 1);      (* "1/1/1" *)
```

| Function | Returns | Description |
|----------|---------|-------------|
| `KNX_SWITCH(target, addr, on_off)` | BOOL | DPT 1.001 switch |
| `KNX_DIM(target, addr, percent)` | BOOL | DPT 5.001 dimming (0-100) |
| `KNX_SET_VALUE(target, addr, byte)` | BOOL | DPT 5.x 1-byte value |
| `KNX_SET_FLOAT(target, addr, float)` | BOOL | DPT 9.001 2-byte float |
| `KNX_SEND(target, addr, bytes...)` | BOOL | Raw data telegram |
| `KNX_GROUP_ADDR(main, mid, sub)` | STRING | Build "main/mid/sub" |

---

## 3. M-Bus — Utility Metering (12)

Read utility meters (water, gas, heat, electricity) via M-Bus over TCP gateway.

```iecst
(* Connect to M-Bus gateway *)
ok := MBUS_TCP_CONNECT('meter', '10.0.0.60:10001');

(* Request data from meter at address 1 *)
raw := MBUS_REQUEST_DATA('meter', 1);

(* Parse response *)
resp := MBUS_PARSE_RESPONSE(raw);
mfr := MBUS_GET_MANUFACTURER(resp);           (* "KAM" *)
medium := MBUS_GET_MEDIUM(resp);               (* "Water" *)
records := MBUS_GET_RECORD_COUNT(resp);        (* 4 *)

(* Read individual records *)
FOR i := 0 TO records - 1 DO
    value := MBUS_GET_RECORD_VALUE(resp, i);   (* 1234.56 *)
    unit := MBUS_GET_RECORD_UNIT(resp, i);     (* "m3" *)
    rtype := MBUS_GET_RECORD_TYPE(resp, i);    (* "instantaneous" *)
END_FOR;

MBUS_TCP_CLOSE('meter');
```

| Function | Returns | Description |
|----------|---------|-------------|
| `MBUS_TCP_CONNECT(name, host_port)` | BOOL | Connect to TCP gateway |
| `MBUS_TCP_CLOSE(name)` | BOOL | Close connection |
| `MBUS_REQUEST_DATA(name, addr)` | ARRAY | Send SND_NKE + REQ_UD2, get response |
| `MBUS_PARSE_RESPONSE(bytes)` | Handle | Parse long frame |
| `MBUS_GET_MANUFACTURER(h)` | STRING | Manufacturer code |
| `MBUS_GET_MEDIUM(h)` | STRING | Medium type (Water, Gas, Heat...) |
| `MBUS_GET_RECORD_COUNT(h)` | INT | Data record count |
| `MBUS_GET_RECORD_VALUE(h, idx)` | REAL | Record value |
| `MBUS_GET_RECORD_UNIT(h, idx)` | STRING | Unit (m3, kWh, etc.) |
| `MBUS_GET_RECORD_TYPE(h, idx)` | STRING | Record type |
| `MBUS_BUILD_SND_NKE(addr)` | ARRAY | Build init frame |
| `MBUS_CHECKSUM(bytes...)` | INT | Calculate checksum |

---

## 4. ZPL — Zebra Label Printing (8)

Build ZPL II commands for Zebra thermal printers.

```iecst
(* Build a shipping label *)
label := ZPL_BEGIN(400, 600);
label := ZPL_TEXT(label, 50, 50, 30, 'SHIP TO:');
label := ZPL_TEXT(label, 50, 90, 20, '123 Main Street');
label := ZPL_TEXT(label, 50, 120, 20, 'Anytown, USA 12345');
label := ZPL_LINE(label, 50, 160, 300, 2);
label := ZPL_BOX(label, 40, 40, 320, 200, 3);
label := ZPL_QR(label, 250, 250, 5, 'https://track.example.com/PKG123');
zpl := ZPL_END(label);

(* Send to printer via HTTP or serial *)
HTTP_POST('http://zebra-printer:9100', zpl, 'text/plain');

(* Quick single-text label *)
quick := ZPL_LABEL('Part: 12345', 'Qty: 100', 'Date: 2026-04-05');
```

| Function | Returns | Description |
|----------|---------|-------------|
| `ZPL_BEGIN([width, height])` | Handle | Start label |
| `ZPL_END(h)` | STRING | Finalize ZPL string |
| `ZPL_LABEL(lines...)` | STRING | Quick multi-line label |
| `ZPL_TEXT(h, x, y, size, text)` | Handle | Add text |
| `ZPL_FIELD(h, x, y, field_num)` | Handle | Variable field placeholder |
| `ZPL_BOX(h, x, y, w, h, thick)` | Handle | Draw rectangle |
| `ZPL_LINE(h, x, y, w, thick)` | Handle | Draw horizontal line |
| `ZPL_QR(h, x, y, mag, data)` | Handle | QR code (magnification 1-10) |

---

## 5. Barcode — Parse & Validate (6)

Parse raw barcode scanner input and validate check digits.

```iecst
parsed := BARCODE_PARSE('0012345678905');
btype := BARCODE_GET_TYPE(parsed);        (* "EAN-13" *)
data := BARCODE_GET_DATA(parsed);         (* "0012345678905" *)

valid := BARCODE_VALIDATE_UPC('012345678905');   (* TRUE *)
check := BARCODE_CHECK_DIGIT('01234567890');     (* 5 *)
clean := BARCODE_STRIP(']E00012345678905');       (* Remove AIM identifier *)
```

| Function | Returns | Description |
|----------|---------|-------------|
| `BARCODE_PARSE(raw)` | Handle | Parse and detect type |
| `BARCODE_GET_TYPE(h)` | STRING | Type (EAN-13, CODE128, etc.) |
| `BARCODE_GET_DATA(h)` | STRING | Cleaned data |
| `BARCODE_VALIDATE_UPC(code)` | BOOL | Validate 12-digit UPC |
| `BARCODE_CHECK_DIGIT(digits)` | INT | Calculate Mod 10 check digit |
| `BARCODE_STRIP(raw)` | STRING | Remove AIM identifiers |

---

## 6. URL — Parse & Build (8)

```iecst
(* Parse URL into components *)
parts := URL_PARSE('https://api.example.com:8443/v2/data?key=abc&limit=10#section');
(* {scheme:"https", host:"api.example.com:8443", path:"/v2/data",
    query:"key=abc&limit=10", fragment:"section"} *)

(* Build URL from components *)
url := URL_BUILD('https', 'api.example.com', '/v2/data');

(* Encode/decode *)
encoded := URL_ENCODE('hello world & more');   (* "hello%20world%20%26%20more" *)
decoded := URL_DECODE(encoded);

(* Join paths *)
full := URL_JOIN('https://api.example.com/v2', 'data/123');

(* Query parameter manipulation *)
val := URL_QUERY_GET('https://x.com?page=3', 'page', '1');  (* "3" *)
url := URL_QUERY_SET('https://x.com?page=3', 'limit', '20');
url := URL_QUERY_DELETE(url, 'page');
```

| Function | Returns | Description |
|----------|---------|-------------|
| `URL_PARSE(url)` | MAP | Decompose URL |
| `URL_BUILD(scheme, host, path)` | STRING | Build URL |
| `URL_ENCODE(str)` | STRING | Percent-encode |
| `URL_DECODE(str)` | STRING | Percent-decode |
| `URL_JOIN(base, path)` | STRING | Join base + relative |
| `URL_QUERY_GET(url, key [,default])` | STRING | Read query param |
| `URL_QUERY_SET(url, key, value)` | STRING | Set query param |
| `URL_QUERY_DELETE(url, key)` | STRING | Remove query param |

---

## 7. TLV/BER — Tag-Length-Value Encoding (12)

Parse and build BER-TLV structures (smart cards, ASN.1, EMV payment).

```iecst
(* Parse TLV data *)
nodes := TLV_PARSE('6F 1A 84 07 A0000000041010 A5 0F 50 0A 4D617374657243617264');
count := TLV_COUNT(nodes);

tag := TLV_GET_TAG(nodes);
len := TLV_GET_LENGTH(nodes);
hex := TLV_GET_VALUE_HEX(nodes);
str := TLV_GET_VALUE_STRING(nodes);

(* Navigate constructed nodes *)
IF TLV_IS_CONSTRUCTED(nodes) THEN
    children := TLV_GET_CHILDREN(nodes);
END_IF;

(* Find by tag *)
app_label := TLV_FIND_TAG(nodes, 16#50);

(* Build TLV *)
tlv_bytes := TLV_BUILD(16#84, 16#A0, 16#00, 16#00, 16#00, 16#04);
```

| Function | Returns | Description |
|----------|---------|-------------|
| `TLV_PARSE(hex_or_bytes)` | ARRAY | Parse BER-TLV |
| `TLV_BUILD(tag, value_bytes...)` | ARRAY | Encode TLV |
| `TLV_COUNT(nodes)` | INT | Top-level node count |
| `TLV_GET_TAG(node)` | INT | Tag number |
| `TLV_GET_LENGTH(node)` | INT | Value length |
| `TLV_GET_VALUE(node)` | ARRAY | Raw bytes |
| `TLV_GET_VALUE_HEX(node)` | STRING | Value as hex |
| `TLV_GET_VALUE_INT(node)` | INT | Value as integer |
| `TLV_GET_VALUE_STRING(node)` | STRING | Value as UTF-8 |
| `TLV_GET_CHILDREN(node)` | ARRAY | Child nodes |
| `TLV_FIND_TAG(nodes, tag)` | Handle | Find tag recursively |
| `TLV_IS_CONSTRUCTED(node)` | BOOL | Has children? |

---

## 8. GSV/SSV — Get/Set System Value (17)

Allen-Bradley Logix compatibility functions for accessing runtime system attributes.

```iecst
(* Read system clock *)
ts := GSV_WALLCLOCKTIME();                    (* Unix ms *)

(* Read task scan time *)
scan := GSV_TASKSCANTIME('MainTask');          (* ms *)

(* Set task scan time *)
SSV_TASKSCANTIME('MainTask', 100);

(* System status *)
faulted := GSV_FAULTED();
state := GSV_ENTRYSTATE();
module := GSV_MODULESTATUS();
port := GSV_PORTSTATUS();
io := GSV_IOCONNECTION();
ethernet := GSV_ETHERNET_STATUS();
dlr := GSV_DLR_STATUS();
```

| Function | Returns | Description |
|----------|---------|-------------|
| `GSV_WALLCLOCKTIME()` | INT | Unix timestamp (ms) |
| `GSV_TASKSCANTIME([task])` | INT | Task scan time (ms) |
| `SSV_TASKSCANTIME(task, ms)` | BOOL | Set task scan time |
| `GSV_FAULTED()` | BOOL | PLC faulted? |
| `GSV_ENTRYSTATE()` | INT | Entry state code |
| `GSV_MODULESTATUS()` | STRING | Module status JSON |
| `GSV_PORTSTATUS()` | STRING | Port status JSON |
| `GSV_IOCONNECTION()` | STRING | I/O connection JSON |
| `GSV_ACTIVEPROCESSOR()` | STRING | Active processor ID |
| `GSV_REDUNDANCYSTATUS()` | STRING | Redundancy mode |
| `GSV_SYNCSTATUS()` | STRING | Sync/RTC status |
| `GSV_ETHERNET_STATUS()` | STRING | Ethernet port status |
| `GSV_DLR_STATUS()` | STRING | Device Level Ring status |
| `GSV` | (generic) | ANY | Generic system value access |
| `SSV` | (generic) | BOOL | Generic system value set |

---

## 9. ctrlX EtherCAT I/O (10)

Read/write digital I/O on Bosch Rexroth ctrlX CORE via EtherCAT Data Layer.

```iecst
(* Create EtherCAT I/O client *)
ok := CTRLX_EC_CREATE('io', 'https://localhost', 'boschrexroth', 'boschrexroth',
                       'ethercatio/fieldbus/di', 'ethercatio/fieldbus/do',
                       16, 16, 100);

CTRLX_EC_START('io');

(* Read digital inputs *)
sensor := CTRLX_EC_READ_DI('io', 1);          (* Channel 1, 1-based *)
limit := CTRLX_EC_READ_DI('io', 5);

(* Write digital outputs *)
CTRLX_EC_WRITE_DO('io', 1, TRUE);
CTRLX_EC_WRITE_DO('io', 2, FALSE);

(* Read back output state *)
out_state := CTRLX_EC_READ_DO('io', 1);

(* Diagnostics *)
connected := CTRLX_EC_CONNECTED('io');
modules := CTRLX_EC_BROWSE('io');              (* JSON module list *)
stats := CTRLX_EC_STATS('io');                 (* JSON diagnostics *)

CTRLX_EC_STOP('io');
CTRLX_EC_DELETE('io');
```

| Function | Returns | Description |
|----------|---------|-------------|
| `CTRLX_EC_CREATE(name, host, user, pass, di, do, di_count, do_count, poll_ms)` | BOOL | Create I/O client |
| `CTRLX_EC_START(name)` | BOOL | Start polling |
| `CTRLX_EC_STOP(name)` | BOOL | Stop polling |
| `CTRLX_EC_DELETE(name)` | BOOL | Remove client |
| `CTRLX_EC_CONNECTED(name)` | BOOL | Connection alive? |
| `CTRLX_EC_READ_DI(name, ch)` | BOOL | Read digital input (1-based) |
| `CTRLX_EC_READ_DO(name, ch)` | BOOL | Read back digital output (1-based) |
| `CTRLX_EC_WRITE_DO(name, ch, val)` | BOOL | Write digital output (1-based) |
| `CTRLX_EC_BROWSE(name)` | STRING | Discover I/O modules (JSON) |
| `CTRLX_EC_STATS(name)` | STRING | Diagnostic statistics (JSON) |

---

## 10. Directory Operations (4)

Supplement to the File I/O guide — manage directories from ST.

```iecst
DIR_CREATE('/data/logs/2026');           (* Creates parents *)

IF DIR_EXISTS('/data/logs') THEN
    files := DIR_LIST('/data/logs');      (* Array of filenames *)
END_IF;

DIR_DELETE('/data/temp');                 (* Empty directories only *)
```

| Function | Returns | Description |
|----------|---------|-------------|
| `DIR_CREATE(path)` | BOOL | Create directory (including parents) |
| `DIR_EXISTS(path)` | BOOL | Check if directory exists |
| `DIR_LIST(path)` | ARRAY | List directory contents |
| `DIR_DELETE(path)` | BOOL | Delete empty directory |

---

*GoPLC v1.0.535 | KNX, M-Bus, ZPL, Barcode, URL, TLV, GSV/SSV, ctrlX EtherCAT, DIR*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
