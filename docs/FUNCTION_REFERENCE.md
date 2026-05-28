<!-- Generated from GOPLC 1.0.959 on 2026-05-28 by scripts/docs-gen. DO NOT EDIT BY HAND. Source: /api/docs/functions on the running binary. -->


# GOPLC ST Function Reference

> Generated from GOPLC **1.0.959** on 2026-05-28. **2247** built-in functions.

## Categories

- [ALARM](#alarm) (19)
- [ANALYZER](#analyzer) (16)
- [ARDUINO](#arduino) (19)
- [ARITHMETIC](#arithmetic) (6)
- [ARRAY](#array) (49)
- [ARTNET](#artnet) (7)
- [AT](#at) (13)
- [BACNET](#bacnet) (54)
- [BARCODE](#barcode) (9)
- [BER](#ber) (17)
- [BITWISE](#bitwise) (27)
- [CAN](#can) (12)
- [CHECKSUM](#checksum) (7)
- [CLUSTER](#cluster) (11)
- [COMPARISON](#comparison) (6)
- [COMPRESSION](#compression) (5)
- [CONVERSION](#conversion) (163)
- [COUNTER](#counter) (3)
- [CRYPTO](#crypto) (69)
- [CSV](#csv) (10)
- [DATASTRUCTURE](#datastructure) (136)
- [DATETIME](#datetime) (40)
- [DB](#db) (20)
- [DBC](#dbc) (5)
- [DEBUG](#debug) (36)
- [DEQUE](#deque) (12)
- [DF1](#df1) (16)
- [DNP3](#dnp3) (25)
- [EDGE](#edge) (4)
- [ENIP](#enip) (43)
- [EXEC](#exec) (6)
- [FAILOVER](#failover) (8)
- [FILE](#file) (19)
- [FILTER](#filter) (8)
- [FINS](#fins) (31)
- [FLIPPER](#flipper) (31)
- [GCODE](#gcode) (39)
- [GPIO](#gpio) (7)
- [GPS](#gps) (9)
- [GSV](#gsv) (17)
- [HEAP](#heap) (19)
- [HISTORIAN](#historian) (16)
- [HTTP](#http) (24)
- [IEC104](#iec104) (27)
- [INFLUX](#influx) (16)
- [INI](#ini) (10)
- [J1939](#j1939) (8)
- [JSON](#json) (26)
- [KNX](#knx) (12)
- [MATH](#math) (44)
- [MBUS](#mbus) (13)
- [MEMORY](#memory) (4)
- [MIDI](#midi) (16)
- [MODBUS](#modbus) (47)
- [MODBUS_RTU](#modbus-rtu) (31)
- [MOTION](#motion) (23)
- [MQTT](#mqtt) (42)
- [NATS](#nats) (44)
- [NMEA](#nmea) (16)
- [OBD2](#obd2) (7)
- [OPCUA](#opcua) (49)
- [OSC](#osc) (12)
- [P2](#p2) (42)
- [P2_CMD](#p2-cmd) (46)
- [PHIDGET](#phidget) (16)
- [PQUEUE](#pqueue) (21)
- [RANGE](#range) (7)
- [REGEX](#regex) (26)
- [RESILIENCE](#resilience) (39)
- [RP2040](#rp2040) (26)
- [S7](#s7) (46)
- [SACN](#sacn) (7)
- [SCALE](#scale) (8)
- [SCALING](#scaling) (6)
- [SEL](#sel) (54)
- [SELECTION](#selection) (9)
- [SERIAL](#serial) (20)
- [SMTP](#smtp) (4)
- [SNMP](#snmp) (47)
- [SPARKPLUG](#sparkplug) (26)
- [SPECIAL](#special) (1)
- [STATISTICS](#statistics) (14)
- [STOREFORWARD](#storeforward) (10)
- [STRING](#string) (37)
- [SYSTEM](#system) (39)
- [TEST](#test) (9)
- [TIME](#time) (15)
- [TIMER](#timer) (4)
- [Teensy](#teensy) (47)
- [UTILITY](#utility) (29)
- [VIDEO](#video) (13)
- [VISION](#vision) (13)
- [WEBSOCKET](#websocket) (6)
- [ZPL](#zpl) (10)
- [ctrlX](#ctrlx) (10)

## ALARM

| Function | Signature | Returns | Description |
|---|---|---|---|
| ALARM_ACK | ALARM_ACK(name: STRING) : BOOL |  | Acknowledge a single alarm |
| ALARM_ACK_ALL | ALARM_ACK_ALL() : DINT |  | Acknowledge all unacknowledged alarms, returns count |
| ALARM_ACTIVE_COUNT | ALARM_ACTIVE_COUNT() : DINT |  | Number of active (non-NORM) alarms |
| ALARM_CREATE | ALARM_CREATE(name: STRING, tag: STRING, type: STRING, setpoint: REAL, deadband: REAL, priority: DINT, delay_ms: DINT) : BOOL |  | Create analog alarm (HI/LO/HIHI/LOLO/DEV/ROC) |
| ALARM_CREATE_BAND | ALARM_CREATE_BAND(name: STRING, tag: STRING, lo: REAL, hi: REAL, deadband: REAL, priority: DINT) : BOOL |  | Create out-of-range band alarm |
| ALARM_CREATE_BOOL | ALARM_CREATE_BOOL(name: STRING, tag: STRING, priority: DINT) : BOOL |  | Create digital (boolean) alarm |
| ALARM_DELETE | ALARM_DELETE(name: STRING) : BOOL |  | Delete an alarm definition |
| ALARM_DISABLE | ALARM_DISABLE(name: STRING) : BOOL |  | Disable alarm evaluation |
| ALARM_ENABLE | ALARM_ENABLE(name: STRING) : BOOL |  | Enable alarm evaluation |
| ALARM_HISTORY | ALARM_HISTORY(name: STRING, count: DINT) : STRING |  | JSON array of recent alarm transitions |
| ALARM_IS_ACTIVE | ALARM_IS_ACTIVE(name: STRING) : BOOL |  | True if alarm is in any active state |
| ALARM_IS_SHELVED | ALARM_IS_SHELVED(name: STRING) : BOOL |  | True if alarm is currently shelved |
| ALARM_LIST_ACTIVE | ALARM_LIST_ACTIVE() : STRING |  | JSON array of all active alarms |
| ALARM_LIST_SHELVED | ALARM_LIST_SHELVED() : STRING |  | JSON array of all shelved alarms |
| ALARM_PRIORITY | ALARM_PRIORITY(name: STRING) : DINT |  | Get alarm priority (1=critical, 2=high, 3=medium, 4=low) |
| ALARM_SHELVE | ALARM_SHELVE(name: STRING, duration_s: DINT) : BOOL |  | Shelve alarm for duration (critical alarms cannot be shelved) |
| ALARM_STATE | ALARM_STATE(name: STRING) : DINT |  | Get alarm state (0=NORM, 1=ACTIVE_UNACK, 2=ACTIVE_ACK, 3=CLEAR_UNACK) |
| ALARM_UNACK_COUNT | ALARM_UNACK_COUNT() : DINT |  | Number of unacknowledged alarms |
| ALARM_UNSHELVE | ALARM_UNSHELVE(name: STRING) : BOOL |  | Unshelve a shelved alarm |

## ANALYZER

| Function | Signature | Returns | Description |
|---|---|---|---|
| AN_CLEAR | AN_CLEAR() : BOOL |  | Clear capture buffer |
| AN_CLEAR | AN_CLEAR() : BOOL |  | Clear transactions |
| AN_COUNT | AN_COUNT() : INT |  | Get transaction count |
| AN_COUNT | AN_COUNT() : INT |  | Get captured packet count |
| AN_DECODE | AN_DECODE(protocol: STRING, data_hex: STRING) : MAP |  | Decode raw packet |
| AN_DECODE | AN_DECODE(packet: ARRAY) : MAP |  | Decode packet from buffer |
| AN_EXPORT_PCAP | AN_EXPORT_PCAP(filename: STRING) : BOOL |  | Export to PCAP |
| AN_FILTER | AN_FILTER(device_id: STRING, protocol: STRING, limit: INT) : ARRAY |  | Filter transactions |
| AN_GET | AN_GET(index: INT) : ARRAY |  | Get captured packet by index |
| AN_INIT | AN_INIT(buffer_size: INT) : BOOL |  | Initialize analyzer |
| AN_IS_CAPTURING | AN_IS_CAPTURING() : BOOL |  | Check if capturing |
| AN_RECORD | AN_RECORD(device_id: STRING, protocol: STRING, direction: STRING, data_hex: STRING) : BOOL |  | Record transaction |
| AN_START | AN_START([device_id: STRING, protocol: STRING]) : BOOL |  | Start capture |
| AN_STATS | AN_STATS() : MAP |  | Get statistics |
| AN_STATS | AN_STATS() : MAP |  | Get analyzer statistics |
| AN_STOP | AN_STOP() : BOOL |  | Stop capture |

## ARDUINO

| Function | Signature | Returns | Description |
|---|---|---|---|
| ARD_ANALOG_READ | ARD_ANALOG_READ(name: STRING, pin: INT) : INT |  | Read analog input (0-16383) |
| ARD_BLE_START | ARD_BLE_START(name: STRING, bleName: STRING) : BOOL |  | Start BLE advertising |
| ARD_BLE_STOP | ARD_BLE_STOP(name: STRING) : BOOL |  | Stop BLE |
| ARD_CLOSE | ARD_CLOSE(name: STRING) : BOOL |  | Close Arduino device |
| ARD_DAC_WRITE | ARD_DAC_WRITE(name: STRING, value: INT) : BOOL |  | Write DAC value (0-4095) |
| ARD_DIGITAL_READ | ARD_DIGITAL_READ(name: STRING, pin: INT) : BOOL |  | Read digital pin |
| ARD_DIGITAL_WRITE | ARD_DIGITAL_WRITE(name: STRING, pin: INT, value: BOOL) : BOOL |  | Write digital pin |
| ARD_DISTANCE | ARD_DISTANCE(name: STRING, trigPin: INT, echoPin: INT) : INT |  | Read ultrasonic distance sensor (mm) |
| ARD_I2C_SCAN | ARD_I2C_SCAN(name: STRING) : STRING |  | Scan I2C bus, returns comma-separated addresses |
| ARD_I2C_WRITE_BYTE | ARD_I2C_WRITE_BYTE(name: STRING, addr: INT, value: INT) : BOOL |  | Write byte to I2C device |
| ARD_INIT | ARD_INIT(name: STRING, port: STRING) : BOOL |  | Initialize Arduino device on serial port |
| ARD_LED_TEXT | ARD_LED_TEXT(name: STRING, speed: INT, text: STRING) : BOOL |  | Scroll text on LED matrix |
| ARD_PIN_MODE | ARD_PIN_MODE(name: STRING, pin: INT, mode: INT) : BOOL |  | Set pin mode (0=input, 1=output, 2=input_pullup) |
| ARD_PWM_WRITE | ARD_PWM_WRITE(name: STRING, pin: INT, duty: INT) : BOOL |  | Write PWM duty (0-65535) |
| ARD_SERVO_WRITE | ARD_SERVO_WRITE(name: STRING, idx: INT, pin: INT, angle: INT) : BOOL |  | Set servo angle |
| ARD_STATUS | ARD_STATUS(name: STRING) : STRING |  | Get Arduino device status (JSON) |
| ARD_TEMP_READ | ARD_TEMP_READ(name: STRING) : INT |  | Read onboard temperature sensor |
| ARD_WIFI_CONNECT | ARD_WIFI_CONNECT(name: STRING, ssid: STRING, password: STRING) : STRING |  | Connect to WiFi, returns IP |
| ARD_WIFI_STATUS | ARD_WIFI_STATUS(name: STRING) : STRING |  | Get WiFi status (JSON) |

## ARITHMETIC

| Function | Signature | Returns | Description |
|---|---|---|---|
| ADD | ADD(a: ANY_NUM, b: ANY_NUM) : ANY_NUM |  | Addition operator |
| DIFF | DIFF(a: ANY_NUM, b: ANY_NUM) : ANY_NUM |  | Difference |
| DIV | DIV(a: ANY_NUM, b: ANY_NUM) : ANY_NUM |  | Division operator |
| MUL | MUL(a: ANY_NUM, b: ANY_NUM) : ANY_NUM |  | Multiplication operator |
| NEG | NEG(val: ANY_NUM) : ANY_NUM |  | Negation operator |
| SUB | SUB(a: ANY_NUM, b: ANY_NUM) : ANY_NUM |  | Subtraction operator |

## ARRAY

| Function | Signature | Returns | Description |
|---|---|---|---|
| ARRAY_ADD | ARRAY_ADD(arr: ARRAY, value: ANY) : ARRAY |  | Append value (alias) |
| ARRAY_ALL | ARRAY_ALL(arr: ARRAY, predicate: STRING) : BOOL |  | Check if all elements match predicate |
| ARRAY_ANY | ARRAY_ANY(arr: ARRAY, predicate: STRING) : BOOL |  | Check if any element matches predicate |
| ARRAY_APPEND | ARRAY_APPEND(arr: ARRAY, value: ANY) : ARRAY |  | Append value to array |
| ARRAY_AT | ARRAY_AT(arr: ARRAY, index: INT) : ANY |  | Get element at index (alias) |
| ARRAY_AVG | ARRAY_AVG(arr: ARRAY) : REAL |  | Average of elements |
| ARRAY_CONCAT | ARRAY_CONCAT(arr1: ARRAY, arr2: ARRAY) : ARRAY |  | Concatenate arrays |
| ARRAY_CONTAINS | ARRAY_CONTAINS(arr: ARRAY, val: ANY) : BOOL |  | Check if contains value |
| ARRAY_COPY | ARRAY_COPY(arr: ARRAY) : ARRAY |  | Create copy of array |
| ARRAY_COUNT | ARRAY_COUNT(arr: ARRAY) : INT |  | Count elements |
| ARRAY_COUNT_IF | ARRAY_COUNT_IF(arr: ARRAY, predicate: STRING) : INT |  | Count elements matching predicate |
| ARRAY_CREATE | ARRAY_CREATE(val1: ANY, ...) : ARRAY |  | Create array from values |
| ARRAY_DROP | ARRAY_DROP(arr: ARRAY, n: INT) : ARRAY |  | Drop first n elements |
| ARRAY_DROP_WHILE | ARRAY_DROP_WHILE(arr: ARRAY, predicate: STRING) : ARRAY |  | Drop while predicate true |
| ARRAY_ELEMENT | ARRAY_ELEMENT(arr: ARRAY, index: INT) : ANY |  | Get element at index (alias) |
| ARRAY_EVERY | ARRAY_EVERY(arr: ARRAY, predicate: STRING) : BOOL |  | Check if all match predicate |
| ARRAY_FILL | ARRAY_FILL(arr: ARRAY, val: ANY) : ARRAY |  | Fill array with value |
| ARRAY_FILTER | ARRAY_FILTER(arr: ARRAY, predicate: STRING) : ARRAY |  | Filter elements by predicate |
| ARRAY_FIND | ARRAY_FIND(arr: ARRAY, predicate: STRING) : ANY |  | Find first matching element |
| ARRAY_FIND_INDEX | ARRAY_FIND_INDEX(arr: ARRAY, predicate: STRING) : INT |  | Find index of first match |
| ARRAY_GET | ARRAY_GET(arr: ARRAY, index: INT) : ANY |  | Get element at index |
| ARRAY_GROUP_BY | ARRAY_GROUP_BY(arr: ARRAY, keyFn: STRING) : MAP |  | Group elements by key |
| ARRAY_INSERT | ARRAY_INSERT(arr: ARRAY, idx: INT, val: ANY) : ARRAY |  | Insert element at index |
| ARRAY_JOIN | ARRAY_JOIN(arr: ARRAY, separator: STRING) : STRING |  | Join elements with separator |
| ARRAY_LEN | ARRAY_LEN(arr: ARRAY) : INT |  | Get array length |
| ARRAY_LENGTH | ARRAY_LENGTH(arr: ARRAY) : INT |  | Get array length |
| ARRAY_MAP | ARRAY_MAP(arr: ARRAY, transform: STRING) : ARRAY |  | Transform each element |
| ARRAY_MAX | ARRAY_MAX(arr: ARRAY) : ANY |  | Find maximum value |
| ARRAY_MIN | ARRAY_MIN(arr: ARRAY) : ANY |  | Find minimum value |
| ARRAY_NEW | ARRAY_NEW(val1: ANY, ...) : ARRAY |  | Create array (alias) |
| ARRAY_OF | ARRAY_OF(val1: ANY, ...) : ARRAY |  | Create array (alias) |
| ARRAY_PARTITION | ARRAY_PARTITION(arr: ARRAY, predicate: STRING) : ARRAY |  | Partition by predicate |
| ARRAY_PUSH | ARRAY_PUSH(arr: ARRAY, value: ANY) : ARRAY |  | Append value (alias) |
| ARRAY_PUT | ARRAY_PUT(arr: ARRAY, index: INT, value: ANY) : ARRAY |  | Set element at index (alias) |
| ARRAY_REDUCE | ARRAY_REDUCE(arr: ARRAY, initial: ANY, reducer: STRING) : ANY |  | Reduce to single value |
| ARRAY_REMOVE | ARRAY_REMOVE(arr: ARRAY, idx: INT) : ARRAY |  | Remove element at index |
| ARRAY_REPLACE | ARRAY_REPLACE(arr: ARRAY, idx: INT, val: ANY) : ARRAY |  | Replace element at index |
| ARRAY_REVERSE | ARRAY_REVERSE(arr: ARRAY) : ARRAY |  | Reverse array |
| ARRAY_SET | ARRAY_SET(arr: ARRAY, index: INT, value: ANY) : ARRAY |  | Set element at index |
| ARRAY_SIZE | ARRAY_SIZE(arr: ARRAY) : INT |  | Get array size |
| ARRAY_SLICE | ARRAY_SLICE(arr: ARRAY, start: INT, end: INT) : ARRAY |  | Get subarray |
| ARRAY_SOME | ARRAY_SOME(arr: ARRAY, predicate: STRING) : BOOL |  | Check if any match predicate |
| ARRAY_SORT | ARRAY_SORT(arr: ARRAY) : ARRAY |  | Sort array |
| ARRAY_SORT_DESC | ARRAY_SORT_DESC(arr: ARRAY) : ARRAY |  | Sort array descending |
| ARRAY_SUM | ARRAY_SUM(arr: ARRAY) : REAL |  | Sum of elements |
| ARRAY_TAKE | ARRAY_TAKE(arr: ARRAY, n: INT) : ARRAY |  | Take first n elements |
| ARRAY_TAKE_WHILE | ARRAY_TAKE_WHILE(arr: ARRAY, predicate: STRING) : ARRAY |  | Take while predicate true |
| ARRAY_UNIQUE | ARRAY_UNIQUE(arr: ARRAY) : ARRAY |  | Remove duplicate elements |
| ARRAY_ZIP_WITH | ARRAY_ZIP_WITH(arr1: ARRAY, arr2: ARRAY, fn: STRING) : ARRAY |  | Zip arrays with function |

## ARTNET

| Function | Signature | Returns | Description |
|---|---|---|---|
| ARTNET_BLACKOUT | ARTNET_BLACKOUT(handle: HANDLE) : HANDLE |  | Set all channels to 0 |
| ARTNET_CREATE_UNIVERSE | ARTNET_CREATE_UNIVERSE(name: STRING, universe: INT) : HANDLE |  | Create 512-channel DMX universe buffer |
| ARTNET_FULL | ARTNET_FULL(handle: HANDLE) : HANDLE |  | Set all channels to 255 |
| ARTNET_SEND | ARTNET_SEND(host: STRING, universe: INT, ch1: INT, ...) : BOOL |  | Send raw DMX channels via Art-Net |
| ARTNET_SEND_UNIVERSE | ARTNET_SEND_UNIVERSE(host: STRING, handle: HANDLE) : BOOL |  | Send entire universe buffer to Art-Net node |
| ARTNET_SET_CHANNEL | ARTNET_SET_CHANNEL(handle: HANDLE, channel: INT, value: INT) : HANDLE |  | Set DMX channel value (1-512, 0-255) |
| ARTNET_SET_RGB | ARTNET_SET_RGB(handle: HANDLE, start_ch: INT, r: INT, g: INT, b: INT) : HANDLE |  | Set 3 consecutive channels for RGB fixture |

## AT

| Function | Signature | Returns | Description |
|---|---|---|---|
| AT_CMD | AT_CMD(command: STRING) : STRING |  | Build AT command with CR termination |
| AT_DIAL | AT_DIAL(phone: STRING) : STRING |  | Build ATD dial command |
| AT_GET_DATA | AT_GET_DATA(handle: HANDLE, [line_index: INT]) : STRING |  | Get data lines from response |
| AT_GET_FIELD | AT_GET_FIELD(handle: HANDLE, index: INT) : STRING |  | Get comma-separated field from first data line |
| AT_GPS_ENABLE | AT_GPS_ENABLE() : STRING |  | Enable GPS on cellular module |
| AT_GPS_GET | AT_GPS_GET() : STRING |  | Query GPS position from cellular module |
| AT_HANGUP | AT_HANGUP() : STRING |  | Return ATH hangup command |
| AT_IS_ERROR | AT_IS_ERROR(handle: HANDLE) : BOOL |  | Check if response contains ERROR |
| AT_IS_OK | AT_IS_OK(handle: HANDLE) : BOOL |  | Check if response contains OK |
| AT_MODEM_INFO | AT_MODEM_INFO() : STRING |  | Return ATI command |
| AT_PARSE | AT_PARSE(response: STRING) : HANDLE |  | Parse AT command response |
| AT_SIGNAL_STRENGTH | AT_SIGNAL_STRENGTH() : STRING |  | Return AT+CSQ command |
| AT_SMS_SEND | AT_SMS_SEND(phone: STRING, message: STRING) : STRING |  | Build AT commands to send SMS |

## BACNET

| Function | Signature | Returns | Description |
|---|---|---|---|
| BACNET_CLIENT_CONNECT | BACNET_CLIENT_CONNECT(name: STRING) : BOOL |  | Start BACnet client |
| BACNET_CLIENT_CREATE | BACNET_CLIENT_CREATE(name: STRING, targetIP: STRING, deviceID: INT, [localPort: INT], [targetPort: INT]) : BOOL |  | Create BACnet client targeting a device |
| BACNET_CLIENT_DELETE | BACNET_CLIENT_DELETE(name: STRING) : BOOL |  | Remove and disconnect client |
| BACNET_CLIENT_DISCONNECT | BACNET_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Stop BACnet client |
| BACNET_CLIENT_IS_CONNECTED | BACNET_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check if client is running |
| BACNET_CLIENT_LIST | BACNET_CLIENT_LIST() : ARRAY |  | List all BACnet clients |
| BACNET_GET_ALARMS | BACNET_GET_ALARMS(name: STRING) : ARRAY |  | Get active alarms |
| BACNET_GET_STATS | BACNET_GET_STATS(name: STRING) : MAP |  | Get client statistics |
| BACNET_OBJECT_AI | BACNET_OBJECT_AI() : INT |  | Analog Input object type constant (0) |
| BACNET_OBJECT_AO | BACNET_OBJECT_AO() : INT |  | Analog Output object type constant (1) |
| BACNET_OBJECT_AV | BACNET_OBJECT_AV() : INT |  | Analog Value object type constant (2) |
| BACNET_OBJECT_BI | BACNET_OBJECT_BI() : INT |  | Binary Input object type constant (3) |
| BACNET_OBJECT_BO | BACNET_OBJECT_BO() : INT |  | Binary Output object type constant (4) |
| BACNET_OBJECT_BV | BACNET_OBJECT_BV() : INT |  | Binary Value object type constant (5) |
| BACNET_OBJECT_MSI | BACNET_OBJECT_MSI() : INT |  | Multi-State Input object type constant |
| BACNET_OBJECT_MSO | BACNET_OBJECT_MSO() : INT |  | Multi-State Output object type constant |
| BACNET_OBJECT_MSV | BACNET_OBJECT_MSV() : INT |  | Multi-State Value object type constant |
| BACNET_PROP_DESCRIPTION | BACNET_PROP_DESCRIPTION() : INT |  | Description property ID (28) |
| BACNET_PROP_OBJECT_NAME | BACNET_PROP_OBJECT_NAME() : INT |  | Object-name property ID (77) |
| BACNET_PROP_PRESENT_VALUE | BACNET_PROP_PRESENT_VALUE() : INT |  | Present-value property ID (85) |
| BACNET_PROP_PRIORITY_ARRAY | BACNET_PROP_PRIORITY_ARRAY() : INT |  | Priority-array property ID |
| BACNET_PROP_RELINQUISH_DEFAULT | BACNET_PROP_RELINQUISH_DEFAULT() : INT |  | Relinquish-default property ID |
| BACNET_PROP_UNITS | BACNET_PROP_UNITS() : INT |  | Units property ID |
| BACNET_READ_AI | BACNET_READ_AI(name: STRING, instance: INT) : REAL |  | Read Analog Input present value |
| BACNET_READ_AO | BACNET_READ_AO(name: STRING, instance: INT) : REAL |  | Read Analog Output present value |
| BACNET_READ_AV | BACNET_READ_AV(name: STRING, instance: INT) : REAL |  | Read Analog Value present value |
| BACNET_READ_BI | BACNET_READ_BI(name: STRING, instance: INT) : BOOL |  | Read Binary Input present value |
| BACNET_READ_BO | BACNET_READ_BO(name: STRING, instance: INT) : BOOL |  | Read Binary Output present value |
| BACNET_READ_BV | BACNET_READ_BV(name: STRING, instance: INT) : BOOL |  | Read Binary Value present value |
| BACNET_READ_PRESENT_VALUE | BACNET_READ_PRESENT_VALUE(name: STRING, objectType: INT, objectInstance: INT) : ANY |  | Read present value (convenience) |
| BACNET_READ_PROPERTY | BACNET_READ_PROPERTY(name: STRING, objectType: INT, objectInstance: INT, property: INT) : ANY |  | Read any BACnet object property |
| BACNET_RELINQUISH | BACNET_RELINQUISH(name: STRING, objectType: INT, objectInstance: INT, priority: INT) : BOOL |  | Relinquish priority slot |
| BACNET_SERVER_CREATE | BACNET_SERVER_CREATE(name: STRING, port: INT, deviceID: INT) : BOOL |  | Create BACnet/IP device server |
| BACNET_SERVER_DELETE | BACNET_SERVER_DELETE(name: STRING) : BOOL |  | Remove and stop server |
| BACNET_SERVER_GET_AO | BACNET_SERVER_GET_AO(name: STRING, instance: INT) : REAL |  | Get Analog Output (read client-written values) |
| BACNET_SERVER_GET_AV | BACNET_SERVER_GET_AV(name: STRING, instance: INT) : REAL |  | Get Analog Value (read client-written setpoints) |
| BACNET_SERVER_GET_BO | BACNET_SERVER_GET_BO(name: STRING, instance: INT) : BOOL |  | Get Binary Output (read client-written commands) |
| BACNET_SERVER_IS_RUNNING | BACNET_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if server is listening |
| BACNET_SERVER_LIST | BACNET_SERVER_LIST() : ARRAY |  | List all BACnet servers |
| BACNET_SERVER_SET_AI | BACNET_SERVER_SET_AI(name: STRING, instance: INT, value: REAL) : BOOL |  | Set Analog Input present value |
| BACNET_SERVER_SET_AV | BACNET_SERVER_SET_AV(name: STRING, instance: INT, value: REAL) : BOOL |  | Set Analog Value present value |
| BACNET_SERVER_SET_BI | BACNET_SERVER_SET_BI(name: STRING, instance: INT, value: BOOL) : BOOL |  | Set Binary Input present value |
| BACNET_SERVER_START | BACNET_SERVER_START(name: STRING) : BOOL |  | Start BACnet server |
| BACNET_SERVER_STOP | BACNET_SERVER_STOP(name: STRING) : BOOL |  | Stop BACnet server |
| BACNET_SUBSCRIBE_COV | BACNET_SUBSCRIBE_COV(name: STRING, objectType: INT, objectInstance: INT, lifetime: INT) : INT |  | Subscribe to change-of-value notifications |
| BACNET_UNSUBSCRIBE_COV | BACNET_UNSUBSCRIBE_COV(name: STRING, subscriptionID: INT) : BOOL |  | Cancel COV subscription |
| BACNET_WHO_IS | BACNET_WHO_IS(name: STRING, [lowLimit: INT], [highLimit: INT]) : ARRAY |  | Discover BACnet devices |
| BACNET_WRITE_AO | BACNET_WRITE_AO(name: STRING, instance: INT, value: REAL) : BOOL |  | Write Analog Output present value |
| BACNET_WRITE_AV | BACNET_WRITE_AV(name: STRING, instance: INT, value: REAL) : BOOL |  | Write Analog Value present value |
| BACNET_WRITE_BO | BACNET_WRITE_BO(name: STRING, instance: INT, value: BOOL) : BOOL |  | Write Binary Output present value |
| BACNET_WRITE_BV | BACNET_WRITE_BV(name: STRING, instance: INT, value: BOOL) : BOOL |  | Write Binary Value present value |
| BACNET_WRITE_PRESENT_VALUE | BACNET_WRITE_PRESENT_VALUE(name: STRING, objectType: INT, objectInstance: INT, value: ANY) : BOOL |  | Write present value (convenience) |
| BACNET_WRITE_PRIORITY | BACNET_WRITE_PRIORITY(name: STRING, objectType: INT, objectInstance: INT, value: ANY, priority: INT) : BOOL |  | Write value at priority level (1-16) |
| BACNET_WRITE_PROPERTY | BACNET_WRITE_PROPERTY(name: STRING, objectType: INT, objectInstance: INT, property: INT, value: ANY) : BOOL |  | Write any BACnet object property |

## BARCODE

| Function | Signature | Returns | Description |
|---|---|---|---|
| BARCODE_CHECK_DIGIT | BARCODE_CHECK_DIGIT(digits: STRING) : INT |  | Calculate EAN/UPC check digit (Mod 10) |
| BARCODE_GET_DATA | BARCODE_GET_DATA(handle: HANDLE) : STRING |  | Get cleaned barcode data |
| BARCODE_GET_TYPE | BARCODE_GET_TYPE(handle: HANDLE) : STRING |  | Get detected type (EAN-13, UPC-A, GS1, QR, etc.) |
| BARCODE_GS1_GET | BARCODE_GS1_GET(handle: HANDLE, ai: STRING) : STRING |  | Get GS1 Application Identifier value |
| BARCODE_IS_GS1 | BARCODE_IS_GS1(handle: HANDLE) : BOOL |  | Check if barcode contains GS1 data |
| BARCODE_PARSE | BARCODE_PARSE(raw: STRING) : HANDLE |  | Parse barcode string (auto-detect type) |
| BARCODE_STRIP | BARCODE_STRIP(raw: STRING) : STRING |  | Strip AIM identifiers and trailing CR/LF |
| BARCODE_VALIDATE_EAN13 | BARCODE_VALIDATE_EAN13(barcode: STRING) : BOOL |  | Validate EAN-13 barcode check digit |
| BARCODE_VALIDATE_UPC | BARCODE_VALIDATE_UPC(barcode: STRING) : BOOL |  | Validate UPC-A barcode check digit |

## BER

| Function | Signature | Returns | Description |
|---|---|---|---|
| BER_ENCODE_INTEGER | BER_ENCODE_INTEGER(value: INT) : ARRAY |  | Encode BER INTEGER TLV |
| BER_ENCODE_LENGTH | BER_ENCODE_LENGTH(length: INT) : ARRAY |  | Encode BER length field |
| BER_ENCODE_OID | BER_ENCODE_OID(oid: STRING) : ARRAY |  | Encode BER OID TLV |
| BER_ENCODE_SEQUENCE | BER_ENCODE_SEQUENCE(tlv1: ARRAY, tlv2: ARRAY, ...) : ARRAY |  | Wrap TLVs in BER SEQUENCE |
| BER_ENCODE_STRING | BER_ENCODE_STRING(text: STRING) : ARRAY |  | Encode BER OCTET STRING TLV |
| TLV_BUILD | TLV_BUILD(tag: INT, value_bytes...: INT) : ARRAY |  | Build TLV from tag and value bytes |
| TLV_COUNT | TLV_COUNT(array: ARRAY) : INT |  | Count top-level TLV nodes |
| TLV_FIND_TAG | TLV_FIND_TAG(data: ANY, tag: INT) : HANDLE |  | Find first node with tag (recursive BFS) |
| TLV_GET_CHILDREN | TLV_GET_CHILDREN(handle: HANDLE) : ARRAY |  | Get child nodes of constructed TLV |
| TLV_GET_LENGTH | TLV_GET_LENGTH(handle: HANDLE) : INT |  | Get TLV value length |
| TLV_GET_TAG | TLV_GET_TAG(handle: HANDLE) : INT |  | Get TLV tag number |
| TLV_GET_VALUE | TLV_GET_VALUE(handle: HANDLE) : ARRAY |  | Get TLV value as byte array |
| TLV_GET_VALUE_HEX | TLV_GET_VALUE_HEX(handle: HANDLE) : STRING |  | Get TLV value as hex string |
| TLV_GET_VALUE_INT | TLV_GET_VALUE_INT(handle: HANDLE) : INT |  | Get TLV value as big-endian integer |
| TLV_GET_VALUE_STRING | TLV_GET_VALUE_STRING(handle: HANDLE) : STRING |  | Get TLV value as UTF-8 string |
| TLV_IS_CONSTRUCTED | TLV_IS_CONSTRUCTED(handle: HANDLE) : BOOL |  | Check if TLV is constructed (has children) |
| TLV_PARSE | TLV_PARSE(data: ANY) : ARRAY |  | Parse BER-TLV encoded data |

## BITWISE

| Function | Signature | Returns | Description |
|---|---|---|---|
| AND | AND(a: ANY_INT, b: ANY_INT) : ANY_INT |  | Bitwise AND |
| BIT_CLR | BIT_CLR(val: ANY_INT, pos: INT) : ANY_INT |  | Clear bit at position |
| BIT_SET | BIT_SET(val: ANY_INT, pos: INT) : ANY_INT |  | Set bit at position |
| BIT_TST | BIT_TST(val: ANY_INT, pos: INT) : BOOL |  | Test bit at position |
| CHECK_PARITY | CHECK_PARITY(byte_val: BYTE) : BOOL |  | Check even parity |
| CLEAR_BIT | CLEAR_BIT(val: ANY_INT, pos: INT) : ANY_INT |  | Clear bit |
| CLRBIT | CLRBIT(val: ANY_INT, pos: INT) : ANY_INT |  | Clear bit (alias) |
| CLR_BIT | CLR_BIT(val: ANY_INT, pos: INT) : ANY_INT |  | Clear bit (alias) |
| CLR_BIT | CLR_BIT(value: DINT, bit_pos: INT) : DINT |  | Clear bit at position |
| GET_BIT | GET_BIT(val: ANY_INT, pos: INT) : BOOL |  | Get bit at position |
| NOT | NOT(val: ANY_INT) : ANY_INT |  | Bitwise NOT |
| OR | OR(a: ANY_INT, b: ANY_INT) : ANY_INT |  | Bitwise OR |
| ROL | ROL(val: ANY_INT, bits: INT) : ANY_INT |  | Rotate left |
| ROL_BYTE | ROL_BYTE(val: BYTE, n: INT) : BYTE |  | Rotate byte left |
| ROL_DWORD | ROL_DWORD(val: DWORD, n: INT) : DWORD |  | Rotate dword left |
| ROL_WORD | ROL_WORD(val: WORD, n: INT) : WORD |  | Rotate word left |
| ROR | ROR(val: ANY_INT, bits: INT) : ANY_INT |  | Rotate right |
| ROR_BYTE | ROR_BYTE(val: BYTE, n: INT) : BYTE |  | Rotate byte right |
| ROR_DWORD | ROR_DWORD(val: DWORD, n: INT) : DWORD |  | Rotate dword right |
| ROR_WORD | ROR_WORD(val: WORD, n: INT) : WORD |  | Rotate word right |
| SETBIT | SETBIT(val: ANY_INT, pos: INT) : ANY_INT |  | Set bit (alias) |
| SET_BIT | SET_BIT(value: DINT, bit_pos: INT) : DINT |  | Set bit at position |
| SHL | SHL(val: ANY_INT, bits: INT) : ANY_INT |  | Shift left |
| SHR | SHR(val: ANY_INT, bits: INT) : ANY_INT |  | Shift right |
| TOGGLE_BIT | TOGGLE_BIT(val: ANY_INT, pos: INT) : ANY_INT |  | Toggle bit at position |
| TSTBIT | TSTBIT(val: ANY_INT, pos: INT) : BOOL |  | Test bit (alias) |
| XOR | XOR(a: ANY_INT, b: ANY_INT) : ANY_INT |  | Bitwise XOR |

## CAN

| Function | Signature | Returns | Description |
|---|---|---|---|
| CAN_CLEAR_FILTERS | CAN_CLEAR_FILTERS(interface: STRING) : BOOL |  | Remove all CAN filters (receive everything) |
| CAN_CLOSE | CAN_CLOSE(interface: STRING) : BOOL |  | Close a SocketCAN interface |
| CAN_LIST | CAN_LIST() : STRING |  | List available CAN/VCAN interfaces as JSON array |
| CAN_OPEN | CAN_OPEN(interface: STRING) : BOOL |  | Open a SocketCAN interface in classic CAN mode (e.g. 'can0', 'vcan0') |
| CAN_OPEN_FD | CAN_OPEN_FD(interface: STRING) : BOOL |  | Open a SocketCAN interface in CAN FD mode (up to 64-byte payloads) |
| CAN_RECV | CAN_RECV(interface: STRING) : STRING |  | Receive next buffered CAN frame as JSON (or empty string) |
| CAN_RECV_COUNT | CAN_RECV_COUNT(interface: STRING) : DINT |  | Number of frames waiting in the receive buffer |
| CAN_SEND | CAN_SEND(interface: STRING, id: DWORD, data: STRING, dlc: DINT) : BOOL |  | Send a standard CAN frame (11-bit ID, hex data, max 8 bytes) |
| CAN_SEND_EXT | CAN_SEND_EXT(interface: STRING, id: DWORD, data: STRING, dlc: DINT) : BOOL |  | Send an extended CAN frame (29-bit ID, hex data, max 8 bytes) |
| CAN_SEND_FD | CAN_SEND_FD(interface: STRING, id: DWORD, data: STRING, brs: BOOL) : BOOL |  | Send a CAN FD frame (up to 64 bytes, optional BRS). Requires CAN_OPEN_FD. |
| CAN_SET_FILTER | CAN_SET_FILTER(interface: STRING, id: DWORD, mask: DWORD) : BOOL |  | Set a hardware CAN ID filter (id & mask match) |
| CAN_STATUS | CAN_STATUS(interface: STRING) : STRING |  | Interface stats as JSON (tx/rx counts, errors, state) |

## CHECKSUM

| Function | Signature | Returns | Description |
|---|---|---|---|
| BCC | BCC(data: STRING) : BYTE |  | Block check character |
| CHECKSUM | CHECKSUM(data: STRING) : INT |  | Simple checksum |
| CHECKSUM16 | CHECKSUM16(data: STRING) : WORD |  | 16-bit checksum |
| CRC16 | CRC16(data: STRING) : WORD |  | CRC-16 checksum |
| CRC16_MODBUS | CRC16_MODBUS(data: STRING) : WORD |  | CRC-16 Modbus |
| CRC32 | CRC32(data: STRING) : DWORD |  | CRC-32 checksum |
| LRC | LRC(data: STRING) : BYTE |  | Longitudinal redundancy check |

## CLUSTER

| Function | Signature | Returns | Description |
|---|---|---|---|
| CLUSTER_ADD_MINION | CLUSTER_ADD_MINION(name: STRING) : BOOL |  | Spawn a new in-process minion PLC |
| CLUSTER_COUNT | CLUSTER_COUNT() : INT |  | Number of active minions |
| CLUSTER_DEPLOY | CLUSTER_DEPLOY(minion: STRING, program_name: STRING, source: STRING) : BOOL |  | Push ST source code to a minion |
| CLUSTER_DISABLE | CLUSTER_DISABLE() : BOOL |  | Tear down all minions, revert to standalone |
| CLUSTER_ENABLE | CLUSTER_ENABLE() : BOOL |  | Promote this instance to boss mode |
| CLUSTER_HAS | CLUSTER_HAS(name: STRING) : BOOL |  | Check if a minion exists by name |
| CLUSTER_LIST | CLUSTER_LIST() : STRING |  | Comma-separated list of minion names |
| CLUSTER_REMOVE_MINION | CLUSTER_REMOVE_MINION(name: STRING) : BOOL |  | Tear down and remove a minion |
| CLUSTER_START | CLUSTER_START(minion: STRING) : BOOL |  | Start all tasks on a minion |
| CLUSTER_STATUS | CLUSTER_STATUS() : STRING |  | Returns 'boss', 'standalone', or 'disabled' |
| CLUSTER_STOP | CLUSTER_STOP(minion: STRING) : BOOL |  | Stop all tasks on a minion |

## COMPARISON

| Function | Signature | Returns | Description |
|---|---|---|---|
| EQ | EQ(a: ANY, b: ANY) : BOOL |  | Equal comparison |
| GE | GE(a: ANY_NUM, b: ANY_NUM) : BOOL |  | Greater or equal |
| GT | GT(a: ANY_NUM, b: ANY_NUM) : BOOL |  | Greater than |
| LE | LE(a: ANY_NUM, b: ANY_NUM) : BOOL |  | Less or equal |
| LT | LT(a: ANY_NUM, b: ANY_NUM) : BOOL |  | Less than |
| NE | NE(a: ANY, b: ANY) : BOOL |  | Not equal comparison |

## COMPRESSION

| Function | Signature | Returns | Description |
|---|---|---|---|
| COMPRESS_RATIO | COMPRESS_RATIO(original: STRING, compressed: STRING) : REAL |  | Get compression ratio |
| GZIP_COMPRESS | GZIP_COMPRESS(data: STRING) : STRING |  | GZIP compress |
| GZIP_DECOMPRESS | GZIP_DECOMPRESS(data: STRING) : STRING |  | GZIP decompress |
| ZLIB_COMPRESS | ZLIB_COMPRESS(data: STRING) : STRING |  | ZLIB compress |
| ZLIB_DECOMPRESS | ZLIB_DECOMPRESS(data: STRING) : STRING |  | ZLIB decompress |

## CONVERSION

| Function | Signature | Returns | Description |
|---|---|---|---|
| BIN_TO_DINT | BIN_TO_DINT(s: STRING) : DINT |  | Binary string to DINT |
| BIN_TO_INT | BIN_TO_INT(s: STRING) : INT |  | Binary string to INT |
| BOOL | BOOL(val: ANY) : BOOL |  | Convert to BOOL |
| BOOL_TO_BYTE | BOOL_TO_BYTE(val: BOOL) : BYTE |  | BOOL to BYTE |
| BOOL_TO_DINT | BOOL_TO_DINT(val: BOOL) : DINT |  | BOOL to DINT |
| BOOL_TO_DWORD | BOOL_TO_DWORD(val: BOOL) : DWORD |  | BOOL to DWORD |
| BOOL_TO_INT | BOOL_TO_INT(val: BOOL) : INT |  | BOOL to INT |
| BOOL_TO_LINT | BOOL_TO_LINT(val: BOOL) : LINT |  | BOOL to LINT |
| BOOL_TO_LWORD | BOOL_TO_LWORD(val: BOOL) : LWORD |  | BOOL to LWORD |
| BOOL_TO_SINT | BOOL_TO_SINT(val: BOOL) : SINT |  | BOOL to SINT |
| BOOL_TO_STRING | BOOL_TO_STRING(val: BOOL) : STRING |  | BOOL to STRING |
| BOOL_TO_UDINT | BOOL_TO_UDINT(val: BOOL) : UDINT |  | BOOL to UDINT |
| BOOL_TO_UINT | BOOL_TO_UINT(val: BOOL) : UINT |  | BOOL to UINT |
| BOOL_TO_ULINT | BOOL_TO_ULINT(val: BOOL) : ULINT |  | BOOL to ULINT |
| BOOL_TO_USINT | BOOL_TO_USINT(val: BOOL) : USINT |  | BOOL to USINT |
| BOOL_TO_WORD | BOOL_TO_WORD(val: BOOL) : WORD |  | BOOL to WORD |
| BYTE | BYTE(val: ANY) : BYTE |  | Convert to BYTE |
| BYTE_TO_DWORD | BYTE_TO_DWORD(val: BYTE) : DWORD |  | BYTE to DWORD |
| BYTE_TO_INT | BYTE_TO_INT(val: BYTE) : INT |  | BYTE to INT |
| BYTE_TO_REAL | BYTE_TO_REAL(val: BYTE) : REAL |  | BYTE to REAL |
| BYTE_TO_STRING | BYTE_TO_STRING(val: BYTE) : STRING |  | BYTE to STRING |
| BYTE_TO_WORD | BYTE_TO_WORD(val: BYTE) : WORD |  | BYTE to WORD |
| C_TO_F | C_TO_F(celsius: REAL) : REAL |  | Celsius to Fahrenheit |
| C_TO_K | C_TO_K(celsius: REAL) : REAL |  | Celsius to Kelvin |
| DATE_TO_DT | DATE_TO_DT(d: DATE) : DT |  | DATE to DT |
| DATE_TO_DWORD | DATE_TO_DWORD(d: DATE) : DWORD |  | DATE to DWORD |
| DATE_TO_STRING | DATE_TO_STRING(d: DATE) : STRING |  | DATE to STRING |
| DATE_TO_UDINT | DATE_TO_UDINT(d: DATE) : UDINT |  | DATE to UDINT |
| DINT | DINT(val: ANY) : DINT |  | Convert to DINT |
| DINT_TO_BIN | DINT_TO_BIN(val: DINT) : STRING |  | DINT to binary string |
| DINT_TO_BYTE | DINT_TO_BYTE(val: DINT) : BYTE |  | DINT to BYTE |
| DINT_TO_HEX | DINT_TO_HEX(val: DINT) : STRING |  | DINT to hex string |
| DINT_TO_INT | DINT_TO_INT(val: DINT) : INT |  | DINT to INT |
| DINT_TO_OCT | DINT_TO_OCT(val: DINT) : STRING |  | DINT to octal string |
| DINT_TO_REAL | DINT_TO_REAL(val: DINT) : REAL |  | DINT to REAL |
| DINT_TO_STRING | DINT_TO_STRING(val: DINT) : STRING |  | DINT to STRING |
| DINT_TO_TIME | DINT_TO_TIME(val: DINT) : TIME |  | DINT to TIME |
| DINT_TO_TOD | DINT_TO_TOD(val: DINT) : TOD |  | DINT to TOD |
| DINT_TO_WORD | DINT_TO_WORD(val: DINT) : WORD |  | DINT to WORD |
| DT | DT(val: ANY) : DT |  | Convert to DT |
| DT_TO_DATE | DT_TO_DATE(dt: DT) : DATE |  | DT to DATE |
| DT_TO_DWORD | DT_TO_DWORD(dt: DT) : DWORD |  | DT to DWORD |
| DT_TO_STRING | DT_TO_STRING(dt: DT) : STRING |  | DT to STRING |
| DT_TO_TOD | DT_TO_TOD(dt: DT) : TOD |  | DT to TOD |
| DT_TO_UDINT | DT_TO_UDINT(dt: DT) : UDINT |  | DT to UDINT |
| DWORD | DWORD(val: ANY) : DWORD |  | Convert to DWORD |
| DWORD_TO_BYTE | DWORD_TO_BYTE(val: DWORD) : BYTE |  | DWORD to BYTE |
| DWORD_TO_DATE | DWORD_TO_DATE(val: DWORD) : DATE |  | DWORD to DATE |
| DWORD_TO_DINT | DWORD_TO_DINT(val: DWORD) : DINT |  | DWORD to DINT |
| DWORD_TO_DT | DWORD_TO_DT(val: DWORD) : DT |  | DWORD to DT |
| DWORD_TO_INT | DWORD_TO_INT(val: DWORD) : INT |  | DWORD to INT |
| DWORD_TO_REAL | DWORD_TO_REAL(val: DWORD) : REAL |  | DWORD to REAL |
| DWORD_TO_STRING | DWORD_TO_STRING(val: DWORD) : STRING |  | DWORD to STRING |
| DWORD_TO_TIME | DWORD_TO_TIME(val: DWORD) : TIME |  | DWORD to TIME |
| DWORD_TO_TOD | DWORD_TO_TOD(val: DWORD) : TOD |  | DWORD to TOD |
| DWORD_TO_UINT | DWORD_TO_UINT(val: DWORD) : UINT |  | DWORD to UINT |
| DWORD_TO_WORD | DWORD_TO_WORD(val: DWORD) : WORD |  | DWORD to WORD |
| DW_TO_REAL | DW_TO_REAL(dw: DWORD) : REAL |  | DWORD bits to REAL |
| HEAP_TO_ARRAY | HEAP_TO_ARRAY(heap: HEAP) : ARRAY |  | Convert heap to array |
| HEX_TO_DINT | HEX_TO_DINT(s: STRING) : DINT |  | Hex string to DINT |
| HEX_TO_INT | HEX_TO_INT(s: STRING) : INT |  | Hex string to INT |
| INT | INT(val: ANY) : INT |  | Convert to INT |
| INT_TO_BIN | INT_TO_BIN(val: INT) : STRING |  | INT to binary string |
| INT_TO_BOOL | INT_TO_BOOL(val: INT) : BOOL |  | INT to BOOL |
| INT_TO_BYTE | INT_TO_BYTE(val: INT) : BYTE |  | INT to BYTE |
| INT_TO_DINT | INT_TO_DINT(val: INT) : DINT |  | INT to DINT |
| INT_TO_DWORD | INT_TO_DWORD(val: INT) : DWORD |  | INT to DWORD |
| INT_TO_HEX | INT_TO_HEX(val: INT) : STRING |  | INT to hex string |
| INT_TO_LINT | INT_TO_LINT(val: INT) : LINT |  | INT to LINT |
| INT_TO_OCT | INT_TO_OCT(val: INT) : STRING |  | INT to octal string |
| INT_TO_REAL | INT_TO_REAL(val: INT) : REAL |  | INT to REAL |
| INT_TO_STRING | INT_TO_STRING(val: INT) : STRING |  | INT to STRING |
| INT_TO_TIME | INT_TO_TIME(val: INT) : TIME |  | INT to TIME |
| INT_TO_UDINT | INT_TO_UDINT(val: INT) : UDINT |  | INT to UDINT |
| INT_TO_UINT | INT_TO_UINT(val: INT) : UINT |  | INT to UINT |
| INT_TO_ULINT | INT_TO_ULINT(val: INT) : ULINT |  | INT to ULINT |
| INT_TO_WORD | INT_TO_WORD(val: INT) : WORD |  | INT to WORD |
| JWT_TIME_TO_EXPIRY | JWT_TIME_TO_EXPIRY(token: STRING) : INT |  | JWT time to expiry |
| LINT | LINT(val: ANY) : LINT |  | Convert to LINT |
| LINT_TO_BYTE | LINT_TO_BYTE(val: LINT) : BYTE |  | LINT to BYTE |
| LINT_TO_INT | LINT_TO_INT(val: LINT) : INT |  | LINT to INT |
| LINT_TO_STRING | LINT_TO_STRING(val: LINT) : STRING |  | LINT to STRING |
| LINT_TO_WORD | LINT_TO_WORD(val: LINT) : WORD |  | LINT to WORD |
| LREAL | LREAL(val: ANY) : LREAL |  | Convert to LREAL |
| LWORD | LWORD(val: ANY) : LWORD |  | Convert to LWORD |
| LWORD_TO_STRING | LWORD_TO_STRING(val: LWORD) : STRING |  | LWORD to STRING |
| OCT_TO_DINT | OCT_TO_DINT(s: STRING) : DINT |  | Octal string to DINT |
| OCT_TO_INT | OCT_TO_INT(s: STRING) : INT |  | Octal string to INT |
| PQUEUE_TO_ARRAY | PQUEUE_TO_ARRAY(pq: PQUEUE) : ARRAY |  | Priority queue to array |
| REAL | REAL(val: ANY) : REAL |  | Convert to REAL |
| REAL_TO_BYTE | REAL_TO_BYTE(val: REAL) : BYTE |  | REAL to BYTE |
| REAL_TO_DINT | REAL_TO_DINT(val: REAL) : DINT |  | REAL to DINT |
| REAL_TO_DW | REAL_TO_DW(r: REAL) : DWORD |  | REAL to DWORD bits |
| REAL_TO_DWORD | REAL_TO_DWORD(val: REAL) : DWORD |  | REAL to DWORD |
| REAL_TO_INT | REAL_TO_INT(val: REAL) : INT |  | REAL to INT |
| REAL_TO_STRING | REAL_TO_STRING(val: REAL) : STRING |  | REAL to STRING |
| REAL_TO_TIME | REAL_TO_TIME(val: REAL) : TIME |  | REAL to TIME |
| REAL_TO_WORD | REAL_TO_WORD(val: REAL) : WORD |  | REAL to WORD |
| SINT | SINT(val: ANY) : SINT |  | Convert to SINT |
| SINT_TO_STRING | SINT_TO_STRING(val: SINT) : STRING |  | SINT to STRING |
| STRING_TO_BOOL | STRING_TO_BOOL(s: STRING) : BOOL |  | STRING to BOOL |
| STRING_TO_BYTE | STRING_TO_BYTE(str: STRING) : BYTE |  | Parse string to BYTE |
| STRING_TO_DATE | STRING_TO_DATE(s: STRING) : DATE |  | STRING to DATE |
| STRING_TO_DINT | STRING_TO_DINT(s: STRING) : DINT |  | STRING to DINT |
| STRING_TO_DT | STRING_TO_DT(s: STRING) : DT |  | STRING to DT |
| STRING_TO_DWORD | STRING_TO_DWORD(str: STRING) : DWORD |  | Parse string to DWORD |
| STRING_TO_INT | STRING_TO_INT(s: STRING) : INT |  | STRING to INT |
| STRING_TO_REAL | STRING_TO_REAL(s: STRING) : REAL |  | STRING to REAL |
| STRING_TO_TIME | STRING_TO_TIME(s: STRING) : TIME |  | STRING to TIME |
| STRING_TO_TOD | STRING_TO_TOD(s: STRING) : TOD |  | STRING to TOD |
| STRING_TO_UDINT | STRING_TO_UDINT(str: STRING) : UDINT |  | Parse string to UDINT |
| STRING_TO_UINT | STRING_TO_UINT(str: STRING) : UINT |  | Parse string to UINT |
| STRING_TO_WORD | STRING_TO_WORD(str: STRING) : WORD |  | Parse string to WORD |
| TIME | TIME(val: ANY) : TIME |  | Convert to TIME |
| TIME_TO_DINT | TIME_TO_DINT(t: TIME) : DINT |  | TIME to DINT |
| TIME_TO_DWORD | TIME_TO_DWORD(t: TIME) : DWORD |  | TIME to DWORD |
| TIME_TO_INT | TIME_TO_INT(t: TIME) : INT |  | TIME to INT |
| TIME_TO_REAL | TIME_TO_REAL(t: TIME) : REAL |  | TIME to REAL |
| TIME_TO_STRING | TIME_TO_STRING(t: TIME) : STRING |  | TIME to STRING |
| TIME_TO_TIME | TIME_TO_TIME(t: TIME) : TIME |  | TIME to TIME (copy) |
| TOD | TOD(val: ANY) : TOD |  | Convert to TOD |
| TOD_TO_DINT | TOD_TO_DINT(tod: TOD) : DINT |  | TOD to DINT |
| TOD_TO_DWORD | TOD_TO_DWORD(tod: TOD) : DWORD |  | TOD to DWORD |
| TOD_TO_TIME | TOD_TO_TIME(tod: TOD) : TIME |  | TOD to TIME |
| TOD_TO_UDINT | TOD_TO_UDINT(tod: TOD) : UDINT |  | TOD to UDINT |
| TO_BOOL | TO_BOOL(val: ANY) : BOOL |  | Convert to BOOL |
| TO_FLOAT | TO_FLOAT(val: ANY) : REAL |  | Convert to float |
| TO_INT | TO_INT(val: ANY) : INT |  | Convert to INT |
| TO_LOWER | TO_LOWER(s: STRING) : STRING |  | Convert to lowercase |
| TO_REAL | TO_REAL(val: ANY) : REAL |  | Convert to REAL |
| TO_STRING | TO_STRING(val: ANY) : STRING |  | Convert to STRING |
| TO_UPPER | TO_UPPER(s: STRING) : STRING |  | Convert to uppercase |
| UDINT | UDINT(val: ANY) : UDINT |  | Convert to UDINT |
| UDINT_TO_DATE | UDINT_TO_DATE(val: UDINT) : DATE |  | UDINT to DATE |
| UDINT_TO_DINT | UDINT_TO_DINT(val: UDINT) : DINT |  | UDINT to DINT |
| UDINT_TO_DT | UDINT_TO_DT(val: UDINT) : DT |  | UDINT to DT |
| UDINT_TO_DWORD | UDINT_TO_DWORD(val: UDINT) : DWORD |  | UDINT to DWORD |
| UDINT_TO_INT | UDINT_TO_INT(val: UDINT) : INT |  | UDINT to INT |
| UDINT_TO_LINT | UDINT_TO_LINT(val: UDINT) : LINT |  | UDINT to LINT |
| UDINT_TO_REAL | UDINT_TO_REAL(val: UDINT) : REAL |  | UDINT to REAL |
| UDINT_TO_STRING | UDINT_TO_STRING(val: UDINT) : STRING |  | UDINT to STRING |
| UDINT_TO_TOD | UDINT_TO_TOD(val: UDINT) : TOD |  | UDINT to TOD |
| UDINT_TO_UINT | UDINT_TO_UINT(val: UDINT) : UINT |  | UDINT to UINT |
| UDINT_TO_WORD | UDINT_TO_WORD(val: UDINT) : WORD |  | UDINT to WORD |
| UINT | UINT(val: ANY) : UINT |  | Convert to UINT |
| UINT_TO_DWORD | UINT_TO_DWORD(val: UINT) : DWORD |  | UINT to DWORD |
| UINT_TO_INT | UINT_TO_INT(val: UINT) : INT |  | UINT to INT |
| UINT_TO_REAL | UINT_TO_REAL(val: UINT) : REAL |  | UINT to REAL |
| UINT_TO_STRING | UINT_TO_STRING(val: UINT) : STRING |  | UINT to STRING |
| UINT_TO_UDINT | UINT_TO_UDINT(val: UINT) : UDINT |  | UINT to UDINT |
| UINT_TO_ULINT | UINT_TO_ULINT(val: UINT) : ULINT |  | UINT to ULINT |
| ULINT | ULINT(val: ANY) : ULINT |  | Convert to ULINT |
| ULINT_TO_STRING | ULINT_TO_STRING(val: ULINT) : STRING |  | ULINT to STRING |
| ULINT_TO_UINT | ULINT_TO_UINT(val: ULINT) : UINT |  | ULINT to UINT |
| ULINT_TO_WORD | ULINT_TO_WORD(val: ULINT) : WORD |  | ULINT to WORD |
| USINT | USINT(val: ANY) : USINT |  | Convert to USINT |
| USINT_TO_STRING | USINT_TO_STRING(val: USINT) : STRING |  | USINT to STRING |
| WORD | WORD(val: ANY) : WORD |  | Convert to WORD |
| WORD_TO_BYTE | WORD_TO_BYTE(val: WORD) : BYTE |  | WORD to BYTE |
| WORD_TO_DWORD | WORD_TO_DWORD(val: WORD) : DWORD |  | WORD to DWORD |
| WORD_TO_INT | WORD_TO_INT(val: WORD) : INT |  | WORD to INT |
| WORD_TO_REAL | WORD_TO_REAL(val: WORD) : REAL |  | WORD to REAL |
| WORD_TO_STRING | WORD_TO_STRING(val: WORD) : STRING |  | WORD to STRING |

## COUNTER

| Function | Signature | Returns | Description |
|---|---|---|---|
| CTD | CTD(CD: BOOL, LD: BOOL, PV: INT) : BOOL |  | Count down |
| CTU | CTU(CU: BOOL, R: BOOL, PV: INT) : BOOL |  | Count up |
| CTUD | CTUD(CU: BOOL, CD: BOOL, R: BOOL, LD: BOOL, PV: INT) : BOOL |  | Count up/down |

## CRYPTO

| Function | Signature | Returns | Description |
|---|---|---|---|
| AES_CBC_DECRYPT | AES_CBC_DECRYPT(ciphertext: STRING, key: STRING, iv: STRING) : STRING |  | AES CBC decryption |
| AES_CBC_ENCRYPT | AES_CBC_ENCRYPT(plaintext: STRING, key: STRING, iv: STRING) : STRING |  | AES CBC encryption |
| AES_DECRYPT | AES_DECRYPT(ciphertext: STRING, key: STRING) : STRING |  | AES decryption |
| AES_ENCRYPT | AES_ENCRYPT(plaintext: STRING, key: STRING) : STRING |  | AES encryption |
| AES_GCM_DECRYPT | AES_GCM_DECRYPT(ciphertext: STRING, key: STRING, nonce: STRING) : STRING |  | AES GCM decryption |
| AES_GCM_ENCRYPT | AES_GCM_ENCRYPT(plaintext: STRING, key: STRING, nonce: STRING) : STRING |  | AES GCM encryption |
| B64_DECODE | B64_DECODE(s: STRING) : STRING |  | Base64 decode |
| B64_DECODE_BYTES | B64_DECODE_BYTES(s: STRING) : ARRAY |  | Base64 decode to bytes |
| B64_ENCODE | B64_ENCODE(s: STRING) : STRING |  | Base64 encode |
| B64_ENCODE_BYTES | B64_ENCODE_BYTES(data: ARRAY) : STRING |  | Base64 encode bytes |
| B64_URL_DECODE | B64_URL_DECODE(s: STRING) : STRING |  | Base64 URL decode |
| B64_URL_ENCODE | B64_URL_ENCODE(s: STRING) : STRING |  | Base64 URL encode |
| BASE64_DECODE | BASE64_DECODE(s: STRING) : STRING |  | Base64 decode |
| BASE64_DECODE_BYTES | BASE64_DECODE_BYTES(s: STRING) : ARRAY |  | Base64 decode to bytes |
| BASE64_ENCODE | BASE64_ENCODE(s: STRING) : STRING |  | Base64 encode |
| BASE64_ENCODE_BYTES | BASE64_ENCODE_BYTES(data: ARRAY) : STRING |  | Base64 encode bytes |
| BASE64_URL_DECODE | BASE64_URL_DECODE(s: STRING) : STRING |  | Base64 URL decode |
| BASE64_URL_ENCODE | BASE64_URL_ENCODE(s: STRING) : STRING |  | Base64 URL encode |
| CONSTANT_TIME_COMPARE | CONSTANT_TIME_COMPARE(a: STRING, b: STRING) : BOOL |  | Constant-time comparison |
| DECRYPT_FILE | DECRYPT_FILE(path: STRING, key: STRING) : BOOL |  | Decrypt file |
| DERIVE_KEY | DERIVE_KEY(password: STRING, salt: STRING, iterations: INT, keyLen: INT) : STRING |  | Derive key from password |
| ENCRYPT_FILE | ENCRYPT_FILE(path: STRING, key: STRING) : BOOL |  | Encrypt file |
| GENERATE_IV | GENERATE_IV(len: INT) : STRING |  | Generate initialization vector |
| GENERATE_KEY | GENERATE_KEY(len: INT) : STRING |  | Generate random key |
| HASH_EQUALS | HASH_EQUALS(a: STRING, b: STRING) : BOOL |  | Hash equality check |
| HASH_VERIFY | HASH_VERIFY(data: STRING, hash: STRING) : BOOL |  | Verify hash |
| HEX_DECODE | HEX_DECODE(s: STRING) : STRING |  | Hex decode |
| HEX_DECODE_BYTES | HEX_DECODE_BYTES(s: STRING) : ARRAY |  | Hex decode to bytes |
| HEX_ENCODE | HEX_ENCODE(s: STRING) : STRING |  | Hex encode |
| HEX_ENCODE_BYTES | HEX_ENCODE_BYTES(data: ARRAY) : STRING |  | Hex encode bytes |
| HMAC_MD5 | HMAC_MD5(msg: STRING, key: STRING) : STRING |  | HMAC-MD5 |
| HMAC_SHA1 | HMAC_SHA1(msg: STRING, key: STRING) : STRING |  | HMAC-SHA1 |
| HMAC_SHA256 | HMAC_SHA256(msg: STRING, key: STRING) : STRING |  | HMAC-SHA256 |
| HMAC_SHA256_BASE64 | HMAC_SHA256_BASE64(msg: STRING, key: STRING) : STRING |  | HMAC-SHA256 base64 |
| HMAC_SHA512 | HMAC_SHA512(msg: STRING, key: STRING) : STRING |  | HMAC-SHA512 |
| JWT_ADD_CLAIM | JWT_ADD_CLAIM(claims: ANY, key: STRING, val: ANY) : ANY |  | Add claim to JWT |
| JWT_CREATE | JWT_CREATE(payload: MAP, secret: STRING, algorithm: STRING) : STRING |  | Create JWT token (alias for JWT_ENCODE) |
| JWT_CREATE_CLAIMS | JWT_CREATE_CLAIMS() : ANY |  | Create JWT claims |
| JWT_DECODE | JWT_DECODE(token: STRING, secret: STRING) : ANY |  | Decode JWT token |
| JWT_ENCODE | JWT_ENCODE(payload: ANY, secret: STRING) : STRING |  | Create JWT token |
| JWT_GET_ALL_CLAIMS | JWT_GET_ALL_CLAIMS(token: STRING) : ANY |  | Get all JWT claims |
| JWT_GET_CLAIM | JWT_GET_CLAIM(token: STRING, key: STRING) : ANY |  | Get JWT claim |
| JWT_GET_HEADER | JWT_GET_HEADER(token: STRING) : ANY |  | Get JWT header |
| JWT_IS_EXPIRED | JWT_IS_EXPIRED(token: STRING) : BOOL |  | Check if JWT expired |
| JWT_REFRESH | JWT_REFRESH(token: STRING, secret: STRING, ttl: INT) : STRING |  | Refresh JWT token |
| JWT_VALIDATE | JWT_VALIDATE(token: STRING, secret: STRING) : BOOL |  | Validate JWT token |
| JWT_VERIFY | JWT_VERIFY(token: STRING, secret: STRING) : BOOL |  | Verify JWT signature |
| MD5 | MD5(s: STRING) : STRING |  | MD5 hash |
| MD5_BYTES | MD5_BYTES(data: ARRAY) : STRING |  | MD5 hash bytes |
| PBKDF2 | PBKDF2(password: STRING, salt: STRING, iterations: INT, keyLen: INT) : STRING |  | PBKDF2 key derivation |
| RANDOM_BYTES | RANDOM_BYTES(length: INT) : ARRAY |  | Generate cryptographically random bytes |
| RANDOM_IV | RANDOM_IV(len: INT) : STRING |  | Generate random IV |
| RANDOM_KEY | RANDOM_KEY(len: INT) : STRING |  | Generate random key |
| RSA_DECRYPT | RSA_DECRYPT(ciphertext: STRING, privateKey: STRING) : STRING |  | RSA decryption |
| RSA_ENCRYPT | RSA_ENCRYPT(plaintext: STRING, publicKey: STRING) : STRING |  | RSA encryption |
| RSA_GENERATE_KEYPAIR | RSA_GENERATE_KEYPAIR(bits: INT) : MAP |  | Generate RSA keypair |
| RSA_SIGN | RSA_SIGN(msg: STRING, privateKey: STRING) : STRING |  | RSA signature |
| RSA_VERIFY | RSA_VERIFY(msg: STRING, sig: STRING, publicKey: STRING) : BOOL |  | Verify RSA signature |
| SECURE_COMPARE | SECURE_COMPARE(a: STRING, b: STRING) : BOOL |  | Secure string comparison |
| SECURE_EQUAL | SECURE_EQUAL(a: STRING, b: STRING) : BOOL |  | Secure equality check |
| SHA1 | SHA1(s: STRING) : STRING |  | SHA-1 hash |
| SHA256 | SHA256(s: STRING) : STRING |  | SHA-256 hash |
| SHA256_BYTES | SHA256_BYTES(data: ARRAY) : STRING |  | SHA-256 hash bytes |
| SHA384 | SHA384(s: STRING) : STRING |  | SHA-384 hash |
| SHA512 | SHA512(s: STRING) : STRING |  | SHA-512 hash |
| UUID | UUID() : STRING |  | Generate UUID |
| XOR_CHECKSUM | XOR_CHECKSUM(data: STRING) : BYTE |  | XOR checksum |
| XOR_DECRYPT | XOR_DECRYPT(data: STRING, key: STRING) : STRING |  | XOR decrypt |
| XOR_ENCRYPT | XOR_ENCRYPT(data: STRING, key: STRING) : STRING |  | XOR encrypt |

## CSV

| Function | Signature | Returns | Description |
|---|---|---|---|
| CSV_ADD_ROW | CSV_ADD_ROW(handle: HANDLE, val1: STRING, ...) : HANDLE |  | Add a new row of values |
| CSV_COL_COUNT | CSV_COL_COUNT(handle: HANDLE) : INT |  | Get number of columns |
| CSV_FIND_COL | CSV_FIND_COL(handle: HANDLE, name: STRING) : INT |  | Find column index by header name |
| CSV_GET_FIELD | CSV_GET_FIELD(handle: HANDLE, row: INT, col: INT) : STRING |  | Get field by row and column |
| CSV_GET_HEADER | CSV_GET_HEADER(handle: HANDLE) : ARRAY |  | Get first row as header array |
| CSV_GET_ROW | CSV_GET_ROW(handle: HANDLE, row: INT) : ARRAY |  | Get entire row as array |
| CSV_PARSE | CSV_PARSE(text: STRING) : HANDLE |  | Parse CSV text into handle |
| CSV_ROW_COUNT | CSV_ROW_COUNT(handle: HANDLE) : INT |  | Get number of rows |
| CSV_SET_FIELD | CSV_SET_FIELD(handle: HANDLE, row: INT, col: INT, value: STRING) : HANDLE |  | Set field value by row and column |
| CSV_TO_STRING | CSV_TO_STRING(handle: HANDLE) : STRING |  | Serialize CSV handle back to text |

## DATASTRUCTURE

| Function | Signature | Returns | Description |
|---|---|---|---|
| LIST_ADD_FIRST | LIST_ADD_FIRST(list: LIST, val: ANY) : LIST |  | Add to front of list |
| LIST_ADD_LAST | LIST_ADD_LAST(list: LIST, val: ANY) : LIST |  | Add to end of list |
| LIST_APPEND | LIST_APPEND(list: LIST, val: ANY) : LIST |  | Append to list |
| LIST_AT | LIST_AT(list: LIST, idx: INT) : ANY |  | Get element at index |
| LIST_BACK | LIST_BACK(list: LIST) : ANY |  | Get last element |
| LIST_CLEAR | LIST_CLEAR(list: LIST) : LIST |  | Clear list |
| LIST_CONCAT | LIST_CONCAT(list1: LIST, list2: LIST) : LIST |  | Concatenate lists |
| LIST_CONTAINS | LIST_CONTAINS(list: LIST, val: ANY) : BOOL |  | Check if contains value |
| LIST_COUNT | LIST_COUNT(list: LIST) : INT |  | Count elements |
| LIST_COUNT_VALUE | LIST_COUNT_VALUE(list: LIST, val: ANY) : INT |  | Count occurrences |
| LIST_CREATE | LIST_CREATE() : LIST |  | Create new list |
| LIST_DELETE_ALL | LIST_DELETE_ALL(list: LIST, val: ANY) : LIST |  | Delete all occurrences |
| LIST_DELETE_AT | LIST_DELETE_AT(list: LIST, idx: INT) : LIST |  | Delete at index |
| LIST_DELETE_VALUE | LIST_DELETE_VALUE(list: LIST, val: ANY) : LIST |  | Delete first occurrence |
| LIST_DISTINCT | LIST_DISTINCT(list: LIST) : LIST |  | Get distinct values |
| LIST_EMPTY | LIST_EMPTY(list: LIST) : BOOL |  | Check if empty |
| LIST_FILL | LIST_FILL(list: LIST, val: ANY) : LIST |  | Fill list with value |
| LIST_FIND | LIST_FIND(list: ARRAY, value: ANY) : INT |  | Find index of element in list |
| LIST_FIND_INDEX | LIST_FIND_INDEX(list: LIST, val: ANY) : INT |  | Find index of value |
| LIST_FIRST | LIST_FIRST(list: LIST) : ANY |  | Get first element |
| LIST_FLATTEN | LIST_FLATTEN(list: LIST) : LIST |  | Flatten nested list |
| LIST_FRONT | LIST_FRONT(list: LIST) : ANY |  | Get front element |
| LIST_GET | LIST_GET(list: LIST, idx: INT) : ANY |  | Get element |
| LIST_HAS | LIST_HAS(list: LIST, val: ANY) : BOOL |  | Check if has value |
| LIST_HEAD | LIST_HEAD(list: LIST) : ANY |  | Get first element |
| LIST_INCLUDES | LIST_INCLUDES(list: LIST, val: ANY) : BOOL |  | Check if includes |
| LIST_INDEX_OF | LIST_INDEX_OF(list: LIST, val: ANY) : INT |  | Get index of value |
| LIST_INSERT | LIST_INSERT(list: LIST, idx: INT, val: ANY) : LIST |  | Insert at index |
| LIST_INSERT_AT | LIST_INSERT_AT(list: LIST, idx: INT, val: ANY) : LIST |  | Insert at position |
| LIST_IS_EMPTY | LIST_IS_EMPTY(list: LIST) : BOOL |  | Check if empty |
| LIST_JOIN | LIST_JOIN(list: LIST, delim: STRING) : STRING |  | Join with delimiter |
| LIST_LAST | LIST_LAST(list: LIST) : ANY |  | Get last element |
| LIST_LAST_INDEX_OF | LIST_LAST_INDEX_OF(list: LIST, val: ANY) : INT |  | Last index of value |
| LIST_LENGTH | LIST_LENGTH(list: LIST) : INT |  | Get length |
| LIST_MERGE | LIST_MERGE(list1: LIST, list2: LIST) : LIST |  | Merge lists |
| LIST_NEW | LIST_NEW() : LIST |  | Create new list |
| LIST_NTH | LIST_NTH(list: LIST, n: INT) : ANY |  | Get nth element |
| LIST_POP_BACK | LIST_POP_BACK(list: LIST) : LIST |  | Remove last |
| LIST_POP_FRONT | LIST_POP_FRONT(list: LIST) : LIST |  | Remove first |
| LIST_PREPEND | LIST_PREPEND(list: LIST, val: ANY) : LIST |  | Add to front |
| LIST_PUSH_BACK | LIST_PUSH_BACK(list: LIST, val: ANY) : LIST |  | Add to back |
| LIST_PUSH_FRONT | LIST_PUSH_FRONT(list: LIST, val: ANY) : LIST |  | Add to front |
| LIST_PUT | LIST_PUT(list: LIST, idx: INT, val: ANY) : LIST |  | Put at index |
| LIST_RANGE | LIST_RANGE(list: LIST, start: INT, end: INT) : LIST |  | Get range |
| LIST_REMOVE | LIST_REMOVE(list: LIST, idx: INT) : LIST |  | Remove at index |
| LIST_REMOVE_ALL | LIST_REMOVE_ALL(list: LIST, val: ANY) : LIST |  | Remove all occurrences |
| LIST_REMOVE_AT | LIST_REMOVE_AT(list: LIST, idx: INT) : LIST |  | Remove at position |
| LIST_REMOVE_FIRST | LIST_REMOVE_FIRST(list: LIST) : LIST |  | Remove first element |
| LIST_REMOVE_LAST | LIST_REMOVE_LAST(list: LIST) : LIST |  | Remove last element |
| LIST_REMOVE_VALUE | LIST_REMOVE_VALUE(list: LIST, val: ANY) : LIST |  | Remove value |
| LIST_REVERSE | LIST_REVERSE(list: LIST) : LIST |  | Reverse list |
| LIST_ROTATE_LEFT | LIST_ROTATE_LEFT(list: LIST, n: INT) : LIST |  | Rotate left |
| LIST_ROTATE_RIGHT | LIST_ROTATE_RIGHT(list: LIST, n: INT) : LIST |  | Rotate right |
| LIST_SET | LIST_SET(list: LIST, idx: INT, val: ANY) : LIST |  | Set at index |
| LIST_SIZE | LIST_SIZE(list: LIST) : INT |  | Get size |
| LIST_SLICE | LIST_SLICE(list: LIST, start: INT, end: INT) : LIST |  | Get slice |
| LIST_SORT | LIST_SORT(list: LIST) : LIST |  | Sort list |
| LIST_SORT_ASC | LIST_SORT_ASC(list: LIST) : LIST |  | Sort ascending |
| LIST_SORT_DESC | LIST_SORT_DESC(list: LIST) : LIST |  | Sort descending |
| LIST_SUBLIST | LIST_SUBLIST(list: LIST, start: INT, end: INT) : LIST |  | Get sublist |
| LIST_SWAP | LIST_SWAP(list: LIST, i: INT, j: INT) : LIST |  | Swap elements |
| LIST_TAIL | LIST_TAIL(list: LIST) : LIST |  | Get all but first |
| LIST_TO_ARRAY | LIST_TO_ARRAY(list: LIST) : ARRAY |  | Convert to array |
| LIST_UNIQUE | LIST_UNIQUE(list: LIST) : LIST |  | Get unique values |
| LIST_UNZIP | LIST_UNZIP(list: LIST) : ARRAY |  | Unzip list of pairs |
| LIST_ZIP | LIST_ZIP(list1: LIST, list2: LIST) : LIST |  | Zip two lists |
| MAP_CLEAR | MAP_CLEAR(m: MAP) : MAP |  | Clear map |
| MAP_CONTAINS | MAP_CONTAINS(m: MAP, key: STRING) : BOOL |  | Check if contains key |
| MAP_CREATE | MAP_CREATE() : MAP |  | Create new map |
| MAP_DELETE | MAP_DELETE(m: MAP, key: STRING) : MAP |  | Delete key |
| MAP_EMPTY | MAP_EMPTY(m: MAP) : BOOL |  | Check if empty |
| MAP_ENTRIES | MAP_ENTRIES(m: MAP) : ARRAY |  | Get entries |
| MAP_FROM_ARRAYS | MAP_FROM_ARRAYS(keys: ARRAY, vals: ARRAY) : MAP |  | Create from arrays |
| MAP_GET | MAP_GET(m: MAP, key: STRING) : ANY |  | Get value by key |
| MAP_HAS | MAP_HAS(m: MAP, key: STRING) : BOOL |  | Check if has key |
| MAP_IS_EMPTY | MAP_IS_EMPTY(m: MAP) : BOOL |  | Check if empty |
| MAP_KEYS | MAP_KEYS(m: MAP) : ARRAY OF STRING |  | Get all keys |
| MAP_LENGTH | MAP_LENGTH(m: MAP) : INT |  | Get length |
| MAP_MERGE | MAP_MERGE(m1: MAP, m2: MAP) : MAP |  | Merge maps |
| MAP_NEW | MAP_NEW() : MAP |  | Create new map |
| MAP_PUT | MAP_PUT(m: MAP, key: STRING, val: ANY) : MAP |  | Put key-value |
| MAP_REMOVE | MAP_REMOVE(m: MAP, key: STRING) : MAP |  | Remove key |
| MAP_SET | MAP_SET(m: MAP, key: STRING, val: ANY) : MAP |  | Set value |
| MAP_SIZE | MAP_SIZE(m: MAP) : INT |  | Get size |
| MAP_VALUES | MAP_VALUES(m: MAP) : ARRAY |  | Get all values |
| QUEUE_ADD | QUEUE_ADD(q: QUEUE, val: ANY) : QUEUE |  | Add to queue |
| QUEUE_BACK | QUEUE_BACK(q: QUEUE) : ANY |  | Get back element |
| QUEUE_CLEAR | QUEUE_CLEAR(q: QUEUE) : QUEUE |  | Clear queue |
| QUEUE_CONTAINS | QUEUE_CONTAINS(q: QUEUE, val: ANY) : BOOL |  | Check if contains |
| QUEUE_CREATE | QUEUE_CREATE() : QUEUE |  | Create queue |
| QUEUE_EMPTY | QUEUE_EMPTY(q: QUEUE) : BOOL |  | Check if empty |
| QUEUE_FRONT | QUEUE_FRONT(q: QUEUE) : ANY |  | Get front element |
| QUEUE_IS_EMPTY | QUEUE_IS_EMPTY(q: QUEUE) : BOOL |  | Check if empty |
| QUEUE_LENGTH | QUEUE_LENGTH(q: QUEUE) : INT |  | Get length |
| QUEUE_NEW | QUEUE_NEW() : QUEUE |  | Create new queue |
| QUEUE_PEEK | QUEUE_PEEK(q: QUEUE) : ANY |  | Peek front |
| QUEUE_POP | QUEUE_POP(q: QUEUE) : ANY |  | Remove from front |
| QUEUE_PUSH | QUEUE_PUSH(q: QUEUE, val: ANY) : QUEUE |  | Add to back |
| QUEUE_REAR | QUEUE_REAR(q: QUEUE) : ANY |  | Get rear element |
| QUEUE_SIZE | QUEUE_SIZE(q: QUEUE) : INT |  | Get size |
| QUEUE_TO_ARRAY | QUEUE_TO_ARRAY(q: QUEUE) : ARRAY |  | Convert to array |
| SET_ADD | SET_ADD(s: SET, val: ANY) : SET |  | Add to set |
| SET_CLEAR | SET_CLEAR(s: SET) : SET |  | Clear set |
| SET_CONTAINS | SET_CONTAINS(s: SET, val: ANY) : BOOL |  | Check if contains |
| SET_CREATE | SET_CREATE() : SET |  | Create set |
| SET_DELETE | SET_DELETE(s: SET, val: ANY) : SET |  | Delete from set |
| SET_DIFFERENCE | SET_DIFFERENCE(s1: SET, s2: SET) : SET |  | Set difference |
| SET_EMPTY | SET_EMPTY(s: SET) : BOOL |  | Check if empty |
| SET_HAS | SET_HAS(s: SET, val: ANY) : BOOL |  | Check if has value |
| SET_INTERSECT | SET_INTERSECT(set1: SET, set2: SET) : SET |  | Intersection of two sets |
| SET_INTERSECTION | SET_INTERSECTION(s1: SET, s2: SET) : SET |  | Set intersection |
| SET_IS_EMPTY | SET_IS_EMPTY(s: SET) : BOOL |  | Check if empty |
| SET_IS_SUBSET | SET_IS_SUBSET(s1: SET, s2: SET) : BOOL |  | Check if subset |
| SET_IS_SUPERSET | SET_IS_SUPERSET(s1: SET, s2: SET) : BOOL |  | Check if superset |
| SET_LENGTH | SET_LENGTH(s: SET) : INT |  | Get length |
| SET_NEW | SET_NEW() : SET |  | Create new set |
| SET_REMOVE | SET_REMOVE(s: SET, val: ANY) : SET |  | Remove from set |
| SET_SIZE | SET_SIZE(s: SET) : INT |  | Get size |
| SET_SYMMETRIC_DIFFERENCE | SET_SYMMETRIC_DIFFERENCE(s1: SET, s2: SET) : SET |  | Symmetric difference |
| SET_TO_ARRAY | SET_TO_ARRAY(s: SET) : ARRAY |  | Convert to array |
| SET_UNION | SET_UNION(s1: SET, s2: SET) : SET |  | Set union |
| STACK_BOTTOM | STACK_BOTTOM(s: STACK) : ANY |  | Get bottom element |
| STACK_CLEAR | STACK_CLEAR(s: STACK) : STACK |  | Clear stack |
| STACK_CONTAINS | STACK_CONTAINS(s: STACK, val: ANY) : BOOL |  | Check if contains |
| STACK_CREATE | STACK_CREATE() : STACK |  | Create stack |
| STACK_EMPTY | STACK_EMPTY(s: STACK) : BOOL |  | Check if empty |
| STACK_IS_EMPTY | STACK_IS_EMPTY(s: STACK) : BOOL |  | Check if empty |
| STACK_LENGTH | STACK_LENGTH(s: STACK) : INT |  | Get length |
| STACK_NEW | STACK_NEW() : STACK |  | Create new stack |
| STACK_PEEK | STACK_PEEK(s: STACK) : ANY |  | Peek top |
| STACK_POP | STACK_POP(s: STACK) : ANY |  | Pop from top |
| STACK_PUSH | STACK_PUSH(s: STACK, val: ANY) : STACK |  | Push to top |
| STACK_REVERSE | STACK_REVERSE(s: STACK) : STACK |  | Reverse stack |
| STACK_SIZE | STACK_SIZE(s: STACK) : INT |  | Get size |
| STACK_TOP | STACK_TOP(s: STACK) : ANY |  | Get top element |
| STACK_TO_ARRAY | STACK_TO_ARRAY(s: STACK) : ARRAY |  | Convert to array |

## DATETIME

| Function | Signature | Returns | Description |
|---|---|---|---|
| ADD_DAYS | ADD_DAYS(ts_ms: DINT, days: DINT) : DINT |  | Add days to timestamp (ms) |
| ADD_DT_TIME | ADD_DT_TIME(dt: DT, t: TIME) : DT |  | Add time to date/time |
| ADD_HOURS | ADD_HOURS(ts_ms: DINT, hours: DINT) : DINT |  | Add hours to timestamp (ms) |
| ADD_MINUTES | ADD_MINUTES(ts_ms: DINT, minutes: DINT) : DINT |  | Add minutes to timestamp (ms) |
| ADD_SECONDS | ADD_SECONDS(ts_ms: DINT, seconds: DINT) : DINT |  | Add seconds to timestamp (ms) |
| ADD_TIME | ADD_TIME(t1: TIME, t2: TIME) : TIME |  | Add two time durations |
| DATE_AND_TIME | DATE_AND_TIME(year: INT, month: INT, day: INT, hour: INT, min: INT, sec: INT) : DT |  | Create DT from components |
| DATE_TIME | DATE_TIME(year: DINT, month: DINT, day: DINT, hour: DINT, minute: DINT, second: DINT) : DINT |  | Create Unix timestamp from components |
| DAY | DAY(d: DATE) : INT |  | Extract day from DATE |
| DAYS_IN_MONTH | DAYS_IN_MONTH(year: INT, month: INT) : INT |  | Days in month |
| DAY_OF_MONTH | DAY_OF_MONTH(dt: DT) : INT |  | Day of month (1-31) |
| DAY_OF_MONTH | DAY_OF_MONTH(ts: DINT) : DINT |  | Get day (1-31) from timestamp |
| DAY_OF_WEEK | DAY_OF_WEEK(ts: DINT) : DINT |  | Get day of week (0=Sun-6=Sat) |
| DAY_OF_WEEK | DAY_OF_WEEK(dt: DT) : INT |  | Day of week (0=Sunday) |
| DAY_OF_YEAR | DAY_OF_YEAR(ts: DINT) : DINT |  | Get day of year (1-366) |
| DAY_OF_YEAR | DAY_OF_YEAR(dt: DT) : INT |  | Day of year (1-366) |
| DIFF_DAYS | DIFF_DAYS(ts1_ms: DINT, ts2_ms: DINT) : DINT |  | Difference in days between timestamps |
| DIFF_SECONDS | DIFF_SECONDS(ts1_ms: DINT, ts2_ms: DINT) : DINT |  | Difference in seconds between timestamps |
| FORMAT_DATETIME | FORMAT_DATETIME(ts_ms: DINT, format: STRING) : STRING |  | Format timestamp as string |
| IS_WEEKEND | IS_WEEKEND(ts_ms: DINT) : BOOL |  | Check if timestamp is Saturday or Sunday |
| IS_WORKDAY | IS_WORKDAY(ts_ms: DINT) : BOOL |  | Check if timestamp is Monday-Friday |
| MONTH | MONTH(d: DATE) : INT |  | Extract month from DATE |
| NOW | NOW() : LINT |  | Current Unix timestamp in seconds (alias of SYSTIME). Use NOW_MS for millisecond precision. |
| NOW_DATE | NOW_DATE() : STRING |  | Current date YYYY-MM-DD |
| NOW_MS | NOW_MS() : LINT |  | Current Unix timestamp in milliseconds (returns int64 — DINT will overflow) |
| NOW_NS | NOW_NS() : LINT |  | Current Unix timestamp in nanoseconds — highest resolution |
| NOW_STR | NOW_STR() : STRING |  | Current timestamp as string |
| NOW_TIME | NOW_TIME() : STRING |  | Current time HH:MM:SS |
| NOW_US | NOW_US() : LINT |  | Current Unix timestamp in microseconds — sub-millisecond profiling |
| PARSE_DATETIME | PARSE_DATETIME(str: STRING, format: STRING) : DINT |  | Parse date string to timestamp_ms |
| SLEEP | SLEEP(ms: INT) : BOOL |  | Sleep for milliseconds |
| SUB_DT_DT | SUB_DT_DT(dt1: DT, dt2: DT) : TIME |  | Subtract two date/times |
| SUB_DT_TIME | SUB_DT_TIME(dt: DT, t: TIME) : DT |  | Subtract time from date/time |
| SUB_TIME | SUB_TIME(t1: TIME, t2: TIME) : TIME |  | Subtract time durations |
| TICK_MS | TICK_MS() : DINT |  | Current time in milliseconds |
| TICK_US | TICK_US() : DINT |  | Current time in microseconds |
| TIMESTAMP | TIMESTAMP() : LINT |  | Unix timestamp in seconds |
| TIME_OF_DAY | TIME_OF_DAY(dt: DT) : TOD |  | Extract time of day from DT |
| WEEK_OF_YEAR | WEEK_OF_YEAR(dt: DT) : INT |  | Week of year (1-53) |
| YEAR | YEAR(d: DATE) : INT |  | Extract year from DATE |

## DB

| Function | Signature | Returns | Description |
|---|---|---|---|
| DB_BEGIN | DB_BEGIN([name: STRING]) : BOOL |  | Start transaction |
| DB_BEGIN_TX | DB_BEGIN_TX([name: STRING]) : BOOL |  | Start transaction (alias) |
| DB_CLOSE | DB_CLOSE([name: STRING]) : BOOL |  | Close database (alias for DB_DISCONNECT) |
| DB_COMMIT | DB_COMMIT([name: STRING]) : BOOL |  | Commit transaction |
| DB_CONNECT | DB_CONNECT(dbType: STRING, connStr: STRING, [name: STRING]) : BOOL |  | Open database connection (sqlite/postgres/mysql) |
| DB_CREATE_TABLE | DB_CREATE_TABLE(table: STRING, columns: MAP, [name: STRING]) : BOOL |  | Create table with columns |
| DB_DISCONNECT | DB_DISCONNECT([name: STRING]) : BOOL |  | Close database connection |
| DB_EXEC | DB_EXEC(query: STRING, [params: ANY...]) : INT |  | Execute INSERT/UPDATE/DELETE/DDL |
| DB_IN_TRANSACTION | DB_IN_TRANSACTION([name: STRING]) : BOOL |  | Check if transaction in progress |
| DB_IS_CONNECTED | DB_IS_CONNECTED([name: STRING]) : BOOL |  | Check if database is connected |
| DB_LAST_INSERT_ID | DB_LAST_INSERT_ID([name: STRING]) : INT |  | Get last auto-increment ID |
| DB_LIST_CONNECTIONS | DB_LIST_CONNECTIONS() : ARRAY |  | List all connection names |
| DB_LIST_TABLES | DB_LIST_TABLES([name: STRING]) : ARRAY |  | List tables in database |
| DB_QUERY | DB_QUERY(query: STRING, [params: ANY...]) : ARRAY |  | Execute SELECT query |
| DB_QUERY_ROW | DB_QUERY_ROW(query: STRING, [params: ANY...]) : MAP |  | Execute query expecting single row |
| DB_QUERY_VALUE | DB_QUERY_VALUE(query: STRING, [params: ANY...]) : ANY |  | Execute query expecting single value |
| DB_ROLLBACK | DB_ROLLBACK([name: STRING]) : BOOL |  | Rollback transaction |
| DB_ROWS_AFFECTED | DB_ROWS_AFFECTED([name: STRING]) : INT |  | Get rows affected by last exec |
| DB_STATUS | DB_STATUS([name: STRING]) : MAP |  | Get connection status info |
| DB_TABLE_EXISTS | DB_TABLE_EXISTS(table: STRING, [name: STRING]) : BOOL |  | Check if table exists |

## DBC

| Function | Signature | Returns | Description |
|---|---|---|---|
| DBC_DECODE | DBC_DECODE(name: STRING, interface: STRING) : STRING |  | Decode next CAN frame into all signals as JSON |
| DBC_GET_SIGNAL | DBC_GET_SIGNAL(name: STRING, interface: STRING, signal_name: STRING) : REAL |  | Extract a named signal from the latest matching CAN frame |
| DBC_LIST_MESSAGES | DBC_LIST_MESSAGES(name: STRING) : STRING |  | List all messages in a loaded DBC as JSON |
| DBC_LOAD | DBC_LOAD(name: STRING, file_path: STRING) : BOOL |  | Load a .dbc file and register it under a name |
| DBC_UNLOAD | DBC_UNLOAD(name: STRING) : BOOL |  | Unload a previously loaded DBC file |

## DEBUG

| Function | Signature | Returns | Description |
|---|---|---|---|
| ASSERT | ASSERT(cond: BOOL, msg: STRING) : BOOL |  | Assert condition |
| DEBUG_CLEAR_BUFFER | DEBUG_CLEAR_BUFFER() : BOOL |  | Clear debug ring buffer |
| DEBUG_DB_CLOSE | DEBUG_DB_CLOSE() : BOOL |  | Close database debug connection |
| DEBUG_DB_QUERY | DEBUG_DB_QUERY(limit: INT, [module: STRING], [level: STRING]) : ARRAY |  | Query debug log table |
| DEBUG_DB_STATUS | DEBUG_DB_STATUS() : MAP |  | Get database connection status |
| DEBUG_DISABLE | DEBUG_DISABLE(module: STRING) : BOOL |  | Disable debug for module |
| DEBUG_ENABLE | DEBUG_ENABLE(module: STRING) : BOOL |  | Enable debug for module |
| DEBUG_ERROR | DEBUG_ERROR(module: STRING, message: STRING) : BOOL |  | Log at error level |
| DEBUG_FILE_CLOSE | DEBUG_FILE_CLOSE() : BOOL |  | Close debug log file |
| DEBUG_GET_BUFFER | DEBUG_GET_BUFFER([count: INT]) : ARRAY |  | Get recent debug messages from ring buffer |
| DEBUG_GET_BUFFER_SIZE | DEBUG_GET_BUFFER_SIZE() : INT |  | Get number of entries in buffer |
| DEBUG_GET_FILE_PATH | DEBUG_GET_FILE_PATH() : STRING |  | Get current debug file path |
| DEBUG_GET_GLOBAL_LEVEL | DEBUG_GET_GLOBAL_LEVEL() : STRING |  | Get global debug level |
| DEBUG_GET_LEVEL | DEBUG_GET_LEVEL(module: STRING) : STRING |  | Get debug level for module |
| DEBUG_INFLUX_CLOSE | DEBUG_INFLUX_CLOSE() : BOOL |  | Close InfluxDB connection |
| DEBUG_INFLUX_STATUS | DEBUG_INFLUX_STATUS() : MAP |  | Get InfluxDB connection status |
| DEBUG_INFO | DEBUG_INFO(module: STRING, message: STRING) : BOOL |  | Log at info level |
| DEBUG_IS_ENABLED | DEBUG_IS_ENABLED() : BOOL |  | Check if debug system is enabled |
| DEBUG_LIST_MODULES | DEBUG_LIST_MODULES() : ARRAY |  | List modules with level overrides |
| DEBUG_LOG | DEBUG_LOG(module: STRING, message: STRING) : BOOL |  | Log at debug level |
| DEBUG_SET_GLOBAL_LEVEL | DEBUG_SET_GLOBAL_LEVEL(level: STRING) : BOOL |  | Set global debug level |
| DEBUG_SET_LEVEL | DEBUG_SET_LEVEL(module: STRING, level: STRING) : BOOL |  | Set debug level for module |
| DEBUG_SYSLOG_CLOSE | DEBUG_SYSLOG_CLOSE() : BOOL |  | Disable syslog logging |
| DEBUG_SYSLOG_STATUS | DEBUG_SYSLOG_STATUS() : MAP |  | Get syslog connection status |
| DEBUG_SYSTEM_DISABLE | DEBUG_SYSTEM_DISABLE() : BOOL |  | Disable debug system globally |
| DEBUG_SYSTEM_ENABLE | DEBUG_SYSTEM_ENABLE() : BOOL |  | Enable debug system globally |
| DEBUG_TO_CONSOLE | DEBUG_TO_CONSOLE(enabled: BOOL) : BOOL |  | Enable/disable console output |
| DEBUG_TO_FILE | DEBUG_TO_FILE(path: STRING, [append: BOOL]) : BOOL |  | Enable logging to file |
| DEBUG_TO_INFLUX | DEBUG_TO_INFLUX(url: STRING, token: STRING, org: STRING, bucket: STRING) : BOOL |  | Enable logging to InfluxDB |
| DEBUG_TO_POSTGRES | DEBUG_TO_POSTGRES(connStr: STRING, [table: STRING]) : BOOL |  | Enable logging to PostgreSQL |
| DEBUG_TO_SQLITE | DEBUG_TO_SQLITE(path: STRING, [table: STRING]) : BOOL |  | Enable logging to SQLite |
| DEBUG_TO_SYSLOG | DEBUG_TO_SYSLOG(hostPort: STRING) : BOOL |  | Enable logging to syslog |
| DEBUG_TRACE | DEBUG_TRACE(module: STRING, message: STRING) : BOOL |  | Log at trace level |
| DEBUG_WARN | DEBUG_WARN(module: STRING, message: STRING) : BOOL |  | Log at warn level |
| LOG | LOG(msg: STRING) : BOOL |  | Log message |
| PRINT | PRINT(msg: STRING) : BOOL |  | Print message |

## DEQUE

| Function | Signature | Returns | Description |
|---|---|---|---|
| DEQUEUE | DEQUEUE(q: QUEUE) : ANY |  | Dequeue element |
| DEQUE_BACK | DEQUE_BACK(d: DEQUE) : ANY |  | Get back element |
| DEQUE_CREATE | DEQUE_CREATE() : DEQUE |  | Create deque |
| DEQUE_EMPTY | DEQUE_EMPTY(d: DEQUE) : BOOL |  | Check if empty |
| DEQUE_FRONT | DEQUE_FRONT(d: DEQUE) : ANY |  | Get front element |
| DEQUE_NEW | DEQUE_NEW() : DEQUE |  | Create new deque |
| DEQUE_POP_BACK | DEQUE_POP_BACK(d: DEQUE) : ANY |  | Pop from back |
| DEQUE_POP_FRONT | DEQUE_POP_FRONT(d: DEQUE) : ANY |  | Pop from front |
| DEQUE_PUSH_BACK | DEQUE_PUSH_BACK(d: DEQUE, val: ANY) : BOOL |  | Push to back |
| DEQUE_PUSH_FRONT | DEQUE_PUSH_FRONT(d: DEQUE, val: ANY) : BOOL |  | Push to front |
| DEQUE_SIZE | DEQUE_SIZE(d: DEQUE) : INT |  | Get size |
| ENQUEUE | ENQUEUE(q: QUEUE, val: ANY) : BOOL |  | Enqueue element |

## DF1

| Function | Signature | Returns | Description |
|---|---|---|---|
| DF1_CLIENT_ADD_POLL_ITEM | DF1_CLIENT_ADD_POLL_ITEM(name: STRING, address: STRING, tag_name: STRING) : BOOL |  | Add polling item to DF1 client |
| DF1_CLIENT_CONNECT | DF1_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect DF1 client |
| DF1_CLIENT_CREATE | DF1_CLIENT_CREATE(name: STRING, port: STRING, [baud: INT], [localNode: INT], [remoteNode: INT]) : BOOL |  | Create DF1 client |
| DF1_CLIENT_DELETE | DF1_CLIENT_DELETE(name: STRING) : BOOL |  | Delete client |
| DF1_CLIENT_DISCONNECT | DF1_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect DF1 client |
| DF1_CLIENT_ECHO | DF1_CLIENT_ECHO(name: STRING, data: ARRAY) : ARRAY |  | Echo test (diagnostic) |
| DF1_CLIENT_GET_DIAGNOSTIC_STATUS | DF1_CLIENT_GET_DIAGNOSTIC_STATUS(name: STRING) : ARRAY |  | Get diagnostic status |
| DF1_CLIENT_GET_STATS | DF1_CLIENT_GET_STATS(name: STRING) : MAP |  | Get communication stats |
| DF1_CLIENT_IS_CONNECTED | DF1_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check connection |
| DF1_CLIENT_LIST | DF1_CLIENT_LIST() : ARRAY |  | List clients |
| DF1_CLIENT_READ_WORD | DF1_CLIENT_READ_WORD(name: STRING, addr: STRING) : INT |  | Read single word |
| DF1_CLIENT_READ_WORDS | DF1_CLIENT_READ_WORDS(name: STRING, addr: STRING, count: INT) : ARRAY |  | Read words from address |
| DF1_CLIENT_SCAN_NODES | DF1_CLIENT_SCAN_NODES(name: STRING, start: INT, end: INT) : ARRAY |  | Scan for nodes |
| DF1_CLIENT_SET_CPU_MODE | DF1_CLIENT_SET_CPU_MODE(name: STRING, mode: INT) : BOOL |  | Set CPU mode (0=PROG, 1=RUN) |
| DF1_CLIENT_WRITE_WORD | DF1_CLIENT_WRITE_WORD(name: STRING, addr: STRING, value: INT) : BOOL |  | Write single word |
| DF1_CLIENT_WRITE_WORDS | DF1_CLIENT_WRITE_WORDS(name: STRING, addr: STRING, values: ARRAY) : BOOL |  | Write words to address |

## DNP3

| Function | Signature | Returns | Description |
|---|---|---|---|
| DNP3_MASTER_CONNECT | DNP3_MASTER_CONNECT(name: STRING) : BOOL |  | Connect to outstation |
| DNP3_MASTER_CREATE | DNP3_MASTER_CREATE(name: STRING, host: STRING, port: INT, [localAddr: INT], [remoteAddr: INT]) : BOOL |  | Create DNP3 master (client) |
| DNP3_MASTER_DELETE | DNP3_MASTER_DELETE(name: STRING) : BOOL |  | Remove and disconnect master |
| DNP3_MASTER_DISCONNECT | DNP3_MASTER_DISCONNECT(name: STRING) : BOOL |  | Disconnect from outstation |
| DNP3_MASTER_IS_CONNECTED | DNP3_MASTER_IS_CONNECTED(name: STRING) : BOOL |  | Check if master is connected |
| DNP3_MASTER_LIST | DNP3_MASTER_LIST() : ARRAY |  | List all masters |
| DNP3_MASTER_READ_AI | DNP3_MASTER_READ_AI(name: STRING, index: INT) : REAL |  | Read analog input from cache |
| DNP3_MASTER_READ_AO | DNP3_MASTER_READ_AO(name: STRING, index: INT) : REAL |  | Read analog output from cache |
| DNP3_MASTER_READ_BI | DNP3_MASTER_READ_BI(name: STRING, index: INT) : BOOL |  | Read binary input from cache |
| DNP3_MASTER_READ_BO | DNP3_MASTER_READ_BO(name: STRING, index: INT) : BOOL |  | Read binary output from cache |
| DNP3_MASTER_READ_COUNTER | DNP3_MASTER_READ_COUNTER(name: STRING, index: INT) : INT |  | Read counter from cache |
| DNP3_MASTER_WRITE_AO | DNP3_MASTER_WRITE_AO(name: STRING, index: INT, value: REAL) : BOOL |  | Write analog output |
| DNP3_MASTER_WRITE_BO | DNP3_MASTER_WRITE_BO(name: STRING, index: INT, value: BOOL) : BOOL |  | Write binary output |
| DNP3_OUTSTATION_CREATE | DNP3_OUTSTATION_CREATE(name: STRING, port: INT, [address: INT]) : BOOL |  | Create DNP3 outstation (server) |
| DNP3_OUTSTATION_DELETE | DNP3_OUTSTATION_DELETE(name: STRING) : BOOL |  | Remove and stop outstation |
| DNP3_OUTSTATION_GET_AO | DNP3_OUTSTATION_GET_AO(name: STRING, index: INT) : REAL |  | Get analog output (written by master) |
| DNP3_OUTSTATION_GET_BO | DNP3_OUTSTATION_GET_BO(name: STRING, index: INT) : BOOL |  | Get binary output (written by master) |
| DNP3_OUTSTATION_GET_STATS | DNP3_OUTSTATION_GET_STATS(name: STRING) : MAP |  | Get outstation statistics |
| DNP3_OUTSTATION_IS_CONNECTED | DNP3_OUTSTATION_IS_CONNECTED(name: STRING) : BOOL |  | Check if master is connected |
| DNP3_OUTSTATION_LIST | DNP3_OUTSTATION_LIST() : ARRAY |  | List all outstations |
| DNP3_OUTSTATION_SET_AI | DNP3_OUTSTATION_SET_AI(name: STRING, index: INT, value: REAL) : BOOL |  | Set analog input value |
| DNP3_OUTSTATION_SET_BI | DNP3_OUTSTATION_SET_BI(name: STRING, index: INT, value: BOOL) : BOOL |  | Set binary input value |
| DNP3_OUTSTATION_SET_COUNTER | DNP3_OUTSTATION_SET_COUNTER(name: STRING, index: INT, value: INT) : BOOL |  | Set counter value |
| DNP3_OUTSTATION_START | DNP3_OUTSTATION_START(name: STRING) : BOOL |  | Start outstation listener |
| DNP3_OUTSTATION_STOP | DNP3_OUTSTATION_STOP(name: STRING) : BOOL |  | Stop outstation |

## EDGE

| Function | Signature | Returns | Description |
|---|---|---|---|
| FALLING_EDGE | FALLING_EDGE(signal: BOOL) : BOOL |  | Detect falling edge |
| F_TRIG | F_TRIG(CLK: BOOL) : BOOL |  | Falling edge detection |
| RISING_EDGE | RISING_EDGE(signal: BOOL) : BOOL |  | Detect rising edge |
| R_TRIG | R_TRIG(CLK: BOOL) : BOOL |  | Rising edge detection |

## ENIP

| Function | Signature | Returns | Description |
|---|---|---|---|
| ENIP_ADAPTER_ADD_BOOL_TAG | ENIP_ADAPTER_ADD_BOOL_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add BOOL tag |
| ENIP_ADAPTER_ADD_DINT_TAG | ENIP_ADAPTER_ADD_DINT_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add DINT tag |
| ENIP_ADAPTER_ADD_INT_TAG | ENIP_ADAPTER_ADD_INT_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add INT tag |
| ENIP_ADAPTER_ADD_REAL_TAG | ENIP_ADAPTER_ADD_REAL_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add REAL tag |
| ENIP_ADAPTER_ADD_TAG | ENIP_ADAPTER_ADD_TAG(name: STRING, tag: STRING, type: INT, count: INT) : BOOL |  | Add CIP tag |
| ENIP_ADAPTER_CREATE | ENIP_ADAPTER_CREATE(name: STRING, [port: INT]) : BOOL |  | Create EtherNet/IP adapter |
| ENIP_ADAPTER_DELETE | ENIP_ADAPTER_DELETE(name: STRING) : BOOL |  | Delete adapter |
| ENIP_ADAPTER_GET_BOOL | ENIP_ADAPTER_GET_BOOL(name: STRING, tag: STRING, index: INT) : BOOL |  | Get BOOL value from adapter tag |
| ENIP_ADAPTER_GET_DINT | ENIP_ADAPTER_GET_DINT(name: STRING, tag: STRING, index: INT) : DINT |  | Get DINT value from adapter tag |
| ENIP_ADAPTER_GET_INT | ENIP_ADAPTER_GET_INT(name: STRING, tag: STRING, index: INT) : INT |  | Get INT value from adapter tag |
| ENIP_ADAPTER_GET_REAL | ENIP_ADAPTER_GET_REAL(name: STRING, tag: STRING, index: INT) : REAL |  | Get REAL value from adapter tag |
| ENIP_ADAPTER_GET_STATS | ENIP_ADAPTER_GET_STATS(name: STRING) : MAP |  | Get adapter statistics |
| ENIP_ADAPTER_IS_RUNNING | ENIP_ADAPTER_IS_RUNNING(name: STRING) : BOOL |  | Check if running |
| ENIP_ADAPTER_LIST | ENIP_ADAPTER_LIST() : ARRAY |  | List adapters |
| ENIP_ADAPTER_SET_BOOL | ENIP_ADAPTER_SET_BOOL(name: STRING, tag: STRING, index: INT, value: BOOL) : BOOL |  | Set BOOL value in adapter tag |
| ENIP_ADAPTER_SET_DINT | ENIP_ADAPTER_SET_DINT(name: STRING, tag: STRING, index: INT, value: DINT) : BOOL |  | Set DINT value in adapter tag |
| ENIP_ADAPTER_SET_INT | ENIP_ADAPTER_SET_INT(name: STRING, tag: STRING, index: INT, value: INT) : BOOL |  | Set INT value in adapter tag |
| ENIP_ADAPTER_SET_REAL | ENIP_ADAPTER_SET_REAL(name: STRING, tag: STRING, index: INT, value: REAL) : BOOL |  | Set REAL value in adapter tag |
| ENIP_ADAPTER_START | ENIP_ADAPTER_START(name: STRING) : BOOL |  | Start the adapter listening (non-blocking; on a busy port it retries the bind in the background — poll ENIP_ADAPTER_IS_RUNNING for the real listening state) |
| ENIP_ADAPTER_STOP | ENIP_ADAPTER_STOP(name: STRING) : BOOL |  | Stop adapter |
| ENIP_SCANNER_ADD_BOOL_TAG | ENIP_SCANNER_ADD_BOOL_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add BOOL poll item |
| ENIP_SCANNER_ADD_DINT_TAG | ENIP_SCANNER_ADD_DINT_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add DINT poll item |
| ENIP_SCANNER_ADD_INT_TAG | ENIP_SCANNER_ADD_INT_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add INT poll item |
| ENIP_SCANNER_ADD_REAL_TAG | ENIP_SCANNER_ADD_REAL_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add REAL poll item |
| ENIP_SCANNER_ADD_STRING_TAG | ENIP_SCANNER_ADD_STRING_TAG(name: STRING, tag: STRING, count: INT) : BOOL |  | Add STRING tag to scanner poll list (Rockwell STRING type) |
| ENIP_SCANNER_ADD_TAG | ENIP_SCANNER_ADD_TAG(name: STRING, tag: STRING, dataType: INT, count: INT) : BOOL |  | Add poll item with CIP data type |
| ENIP_SCANNER_AUTO_REGISTER | ENIP_SCANNER_AUTO_REGISTER(name: STRING) : DINT |  | Browse PLC and auto-register all discovered tags (BOOL, INT, DINT, REAL, STRING, arrays) |
| ENIP_SCANNER_CONNECT | ENIP_SCANNER_CONNECT(name: STRING) : BOOL |  | Start scanner polling loop |
| ENIP_SCANNER_CONNECTED | ENIP_SCANNER_CONNECTED(name: STRING) : BOOL |  | Check if scanner is connected |
| ENIP_SCANNER_CREATE | ENIP_SCANNER_CREATE(name: STRING, host: STRING, port: INT, [poll_rate_ms: INT]) : BOOL |  | Create EtherNet/IP scanner (client) |
| ENIP_SCANNER_DELETE | ENIP_SCANNER_DELETE(name: STRING) : BOOL |  | Stop and remove scanner |
| ENIP_SCANNER_DISCONNECT | ENIP_SCANNER_DISCONNECT(name: STRING) : BOOL |  | Stop scanner |
| ENIP_SCANNER_LIST | ENIP_SCANNER_LIST() : ARRAY |  | List all scanners |
| ENIP_SCANNER_READ_BOOL | ENIP_SCANNER_READ_BOOL(name: STRING, tag: STRING, index: INT) : BOOL |  | Read BOOL from cached poll data |
| ENIP_SCANNER_READ_DINT | ENIP_SCANNER_READ_DINT(name: STRING, tag: STRING, index: INT) : DINT |  | Read DINT from cached poll data |
| ENIP_SCANNER_READ_INT | ENIP_SCANNER_READ_INT(name: STRING, tag: STRING, index: INT) : INT |  | Read INT from cached poll data |
| ENIP_SCANNER_READ_REAL | ENIP_SCANNER_READ_REAL(name: STRING, tag: STRING, index: INT) : REAL |  | Read REAL from cached poll data |
| ENIP_SCANNER_READ_STRING | ENIP_SCANNER_READ_STRING(name: STRING, tag: STRING, index: INT) : STRING |  | Read STRING from cached poll data |
| ENIP_SCANNER_WRITE_BOOL | ENIP_SCANNER_WRITE_BOOL(name: STRING, tag: STRING, index: INT, value: BOOL) : BOOL |  | Write BOOL (queued for next poll) |
| ENIP_SCANNER_WRITE_DINT | ENIP_SCANNER_WRITE_DINT(name: STRING, tag: STRING, index: INT, value: DINT) : BOOL |  | Write DINT (queued for next poll) |
| ENIP_SCANNER_WRITE_INT | ENIP_SCANNER_WRITE_INT(name: STRING, tag: STRING, index: INT, value: INT) : BOOL |  | Write INT (queued for next poll) |
| ENIP_SCANNER_WRITE_REAL | ENIP_SCANNER_WRITE_REAL(name: STRING, tag: STRING, index: INT, value: REAL) : BOOL |  | Write REAL (queued for next poll) |
| ENIP_SCANNER_WRITE_STRING | ENIP_SCANNER_WRITE_STRING(name: STRING, tag: STRING, index: INT, value: STRING) : BOOL |  | Write STRING to Rockwell PLC (queued for next poll) |

## EXEC

| Function | Signature | Returns | Description |
|---|---|---|---|
| ENV_GET | ENV_GET(name: STRING) : STRING |  | Get environment variable |
| ENV_SET | ENV_SET(name: STRING, val: STRING) : BOOL |  | Set environment variable |
| EXEC | EXEC(cmd: STRING) : STRING |  | Execute shell command |
| EXEC_ASYNC | EXEC_ASYNC(cmd: STRING) : INT |  | Execute command async |
| EXEC_OUTPUT | EXEC_OUTPUT(id: INT) : STRING |  | Get async exec output |
| EXEC_STATUS | EXEC_STATUS(id: INT) : INT |  | Get async exec status |

## FAILOVER

| Function | Signature | Returns | Description |
|---|---|---|---|
| FAILOVER_DEMOTE | FAILOVER_DEMOTE() : BOOL |  | Force this instance to standby |
| FAILOVER_FORCE_SYNC | FAILOVER_FORCE_SYNC() : BOOL |  | Trigger immediate full state sync to peer |
| FAILOVER_IS_PRIMARY | FAILOVER_IS_PRIMARY() : BOOL |  | True if this instance is the active primary |
| FAILOVER_PEER_STATUS | FAILOVER_PEER_STATUS() : STRING |  | Peer status: 'connected', 'disconnected', or 'unknown' |
| FAILOVER_PROMOTE | FAILOVER_PROMOTE() : BOOL |  | Force this instance to primary |
| FAILOVER_ROLE | FAILOVER_ROLE() : STRING |  | Current role: 'primary', 'standby', or 'standalone' |
| FAILOVER_SYNC_LAG_MS | FAILOVER_SYNC_LAG_MS() : DINT |  | How far behind the standby is in milliseconds |
| FAILOVER_UPTIME_MS | FAILOVER_UPTIME_MS() : LINT |  | Milliseconds since last role change |

## FILE

| Function | Signature | Returns | Description |
|---|---|---|---|
| DIR_CREATE | DIR_CREATE(path: STRING) : BOOL |  | Create directory (including parents) |
| DIR_DELETE | DIR_DELETE(path: STRING) : BOOL |  | Delete empty directory |
| DIR_EXISTS | DIR_EXISTS(path: STRING) : BOOL |  | Check if directory exists |
| DIR_LIST | DIR_LIST(path: STRING) : ARRAY |  | List filenames in directory |
| FILE_APPEND | FILE_APPEND(path: STRING, data: STRING) : BOOL |  | Append data to file |
| FILE_CLOSE | FILE_CLOSE(handle: INT) : BOOL |  | Close file handle |
| FILE_COPY | FILE_COPY(src: STRING, dst: STRING) : BOOL |  | Copy file |
| FILE_DELETE | FILE_DELETE(path: STRING) : BOOL |  | Delete file |
| FILE_EOF | FILE_EOF(handle: INT) : BOOL |  | Check if at end of file |
| FILE_EXISTS | FILE_EXISTS(path: STRING) : BOOL |  | Check if file exists |
| FILE_MODIFIED | FILE_MODIFIED(path: STRING) : DINT |  | Get file modification time (Unix ms) |
| FILE_MOVE | FILE_MOVE(src: STRING, dst: STRING) : BOOL |  | Move/rename file |
| FILE_OPEN | FILE_OPEN(path: STRING, mode: STRING) : INT |  | Open file |
| FILE_READ | FILE_READ(path: STRING) : STRING |  | Read file contents |
| FILE_READ_LINE | FILE_READ_LINE(handle: INT) : STRING |  | Read line from file |
| FILE_READ_LINES | FILE_READ_LINES(path: STRING) : ARRAY |  | Read all lines from file |
| FILE_SIZE | FILE_SIZE(path: STRING) : LINT |  | Get file size |
| FILE_WRITE | FILE_WRITE(path: STRING, content: STRING) : BOOL |  | Write file contents |
| FILE_WRITE_LINE | FILE_WRITE_LINE(handle: INT, line: STRING) : BOOL |  | Write line to file |

## FILTER

| Function | Signature | Returns | Description |
|---|---|---|---|
| DEADBAND | DEADBAND(val: REAL, center: REAL, width: REAL) : REAL |  | Deadband filter |
| DEAD_BAND | DEAD_BAND(val: REAL, center: REAL, width: REAL) : REAL |  | Deadband filter (alias) |
| HIGHPASSFILTER | HIGHPASSFILTER(val: REAL, cutoff: REAL, dt: REAL) : REAL |  | High pass filter |
| HPF | HPF(val: REAL, cutoff: REAL, dt: REAL) : REAL |  | High pass filter (short) |
| HYSTERESIS | HYSTERESIS(val: REAL, low: REAL, high: REAL, [prevOutput: BOOL]) : BOOL |  | Hysteresis comparator with state |
| LOWPASSFILTER | LOWPASSFILTER(val: REAL, cutoff: REAL, dt: REAL) : REAL |  | Low pass filter |
| LPF | LPF(val: REAL, cutoff: REAL, dt: REAL) : REAL |  | Low pass filter (short) |
| PT1 | PT1(val: REAL, tau: REAL, dt: REAL) : REAL |  | First order lag filter |

## FINS

| Function | Signature | Returns | Description |
|---|---|---|---|
| FINS_CLIENT_ADD_CIO_POLL | FINS_CLIENT_ADD_CIO_POLL(name: STRING, addr: INT, count: INT) : BOOL |  | Add CIO to poll list |
| FINS_CLIENT_ADD_DM_POLL | FINS_CLIENT_ADD_DM_POLL(name: STRING, addr: INT, count: INT) : BOOL |  | Add DM to poll list |
| FINS_CLIENT_ADD_POLL_ITEM | FINS_CLIENT_ADD_POLL_ITEM(name: STRING, area: INT, addr: INT, count: INT) : BOOL |  | Add memory area to poll list (area: 0x82=DM, 0xB0=CIO) |
| FINS_CLIENT_CONNECT | FINS_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect FINS client |
| FINS_CLIENT_CREATE | FINS_CLIENT_CREATE(name: STRING, host: STRING, [port: INT], [destNode: INT], [srcNode: INT]) : BOOL |  | Create FINS client |
| FINS_CLIENT_DELETE | FINS_CLIENT_DELETE(name: STRING) : BOOL |  | Delete FINS client |
| FINS_CLIENT_DISCONNECT | FINS_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect FINS client |
| FINS_CLIENT_IS_CONNECTED | FINS_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check connection status |
| FINS_CLIENT_LIST | FINS_CLIENT_LIST() : ARRAY |  | List FINS clients |
| FINS_CLIENT_READ_CIO | FINS_CLIENT_READ_CIO(name: STRING, addr: INT, count: INT) : ARRAY |  | Read CIO words |
| FINS_CLIENT_READ_CIO_WORD | FINS_CLIENT_READ_CIO_WORD(name: STRING, addr: INT) : INT |  | Read single CIO word |
| FINS_CLIENT_READ_DM | FINS_CLIENT_READ_DM(name: STRING, addr: INT, count: INT) : ARRAY |  | Read DM words |
| FINS_CLIENT_READ_DM_WORD | FINS_CLIENT_READ_DM_WORD(name: STRING, addr: INT) : INT |  | Read single DM word |
| FINS_CLIENT_WRITE_DM | FINS_CLIENT_WRITE_DM(name: STRING, addr: INT, values: ARRAY) : BOOL |  | Write DM words |
| FINS_CLIENT_WRITE_DM_WORD | FINS_CLIENT_WRITE_DM_WORD(name: STRING, addr: INT, val: INT) : BOOL |  | Write single DM word |
| FINS_SERVER_CREATE | FINS_SERVER_CREATE(name: STRING, port: INT, [node: INT]) : BOOL |  | Create FINS server |
| FINS_SERVER_CREATE | FINS_SERVER_CREATE(name: STRING, port: INT, [node: INT]) : BOOL |  | Create FINS UDP server |
| FINS_SERVER_DELETE | FINS_SERVER_DELETE(name: STRING) : BOOL |  | Delete FINS server |
| FINS_SERVER_DELETE | FINS_SERVER_DELETE(name: STRING) : BOOL |  | Remove server instance |
| FINS_SERVER_GET_DM | FINS_SERVER_GET_DM(name: STRING, addr: INT) : INT |  | Get DM value |
| FINS_SERVER_GET_DM | FINS_SERVER_GET_DM(name: STRING, addr: INT) : INT |  | Get DM word from server |
| FINS_SERVER_IS_RUNNING | FINS_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if server is running |
| FINS_SERVER_IS_RUNNING | FINS_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if running |
| FINS_SERVER_LIST | FINS_SERVER_LIST() : ARRAY |  | List FINS servers |
| FINS_SERVER_LIST | FINS_SERVER_LIST() : ARRAY |  | List all FINS servers |
| FINS_SERVER_SET_DM | FINS_SERVER_SET_DM(name: STRING, addr: INT, value: INT) : BOOL |  | Set DM value |
| FINS_SERVER_SET_DM | FINS_SERVER_SET_DM(name: STRING, addr: INT, value: INT) : BOOL |  | Set DM word on server |
| FINS_SERVER_START | FINS_SERVER_START(name: STRING) : BOOL |  | Start FINS server |
| FINS_SERVER_START | FINS_SERVER_START(name: STRING) : BOOL |  | Start FINS server |
| FINS_SERVER_STOP | FINS_SERVER_STOP(name: STRING) : BOOL |  | Stop FINS server |
| FINS_SERVER_STOP | FINS_SERVER_STOP(name: STRING) : BOOL |  | Stop FINS server |

## FLIPPER

| Function | Signature | Returns | Description |
|---|---|---|---|
| FLIPPER_BTN_READ | FLIPPER_BTN_READ(name: STRING) : INT |  | Read button bitmask (OK=1,Up=2,Down=4,Left=8,Right=16,Back=32) |
| FLIPPER_CONNECT | FLIPPER_CONNECT(name: STRING, port: STRING) : BOOL |  | Open USB serial connection to Flipper Zero |
| FLIPPER_DELETE | FLIPPER_DELETE(name: STRING) : BOOL |  | Disconnect and remove device |
| FLIPPER_DISCONNECT | FLIPPER_DISCONNECT(name: STRING) : BOOL |  | Close Flipper connection |
| FLIPPER_GPIO_MODE | FLIPPER_GPIO_MODE(name: STRING, pin: ANY, mode: ANY) : BOOL |  | Set pin mode (pin: 2-16 or 'PA7', mode: 0-3 or 'output') |
| FLIPPER_GPIO_READ | FLIPPER_GPIO_READ(name: STRING, pin: ANY) : INT |  | Read pin state (0/1), -1 on error |
| FLIPPER_GPIO_WRITE | FLIPPER_GPIO_WRITE(name: STRING, pin: ANY, value: INT) : BOOL |  | Set pin high(1) or low(0) |
| FLIPPER_IBUTTON_EMULATE | FLIPPER_IBUTTON_EMULATE(name: STRING, data_hex: STRING) : BOOL |  | Emulate iButton key |
| FLIPPER_IBUTTON_READ | FLIPPER_IBUTTON_READ(name: STRING) : STRING |  | Read iButton key (hex), caches result |
| FLIPPER_IBUTTON_READ_CACHED | FLIPPER_IBUTTON_READ_CACHED(name: STRING) : STRING |  | Last cached iButton result (non-blocking) |
| FLIPPER_IBUTTON_STOP | FLIPPER_IBUTTON_STOP(name: STRING) : BOOL |  | Stop iButton operations |
| FLIPPER_INFO | FLIPPER_INFO(name: STRING) : STRING |  | Get HAL firmware version |
| FLIPPER_IR_RX_READ | FLIPPER_IR_RX_READ(name: STRING) : STRING |  | Read received IR data (hex), caches result |
| FLIPPER_IR_RX_START | FLIPPER_IR_RX_START(name: STRING) : BOOL |  | Start IR reception |
| FLIPPER_IR_RX_STOP | FLIPPER_IR_RX_STOP(name: STRING) : BOOL |  | Stop IR reception |
| FLIPPER_IR_TX | FLIPPER_IR_TX(name: STRING, protocol: STRING, address: INT, command: INT) : BOOL |  | Send IR signal (protocol: 0=NEC,1=Samsung,2=RC5,3=RC6 or name) |
| FLIPPER_IR_TX_RAW | FLIPPER_IR_TX_RAW(name: STRING, data_hex: STRING) : BOOL |  | Send raw IR timing data (hex) |
| FLIPPER_IS_CONNECTED | FLIPPER_IS_CONNECTED(name: STRING) : BOOL |  | Check connection state |
| FLIPPER_LIST | FLIPPER_LIST() : STRING |  | List connected Flipper devices |
| FLIPPER_NFC_EMULATE | FLIPPER_NFC_EMULATE(name: STRING, uid_hex: STRING) : BOOL |  | Emulate NFC tag with given UID |
| FLIPPER_NFC_READ | FLIPPER_NFC_READ(name: STRING) : STRING |  | Last cached NFC result (non-blocking) |
| FLIPPER_NFC_SCAN | FLIPPER_NFC_SCAN(name: STRING) : STRING |  | Read NFC tag UID (hex), caches result |
| FLIPPER_NFC_STOP | FLIPPER_NFC_STOP(name: STRING) : BOOL |  | Stop NFC operations |
| FLIPPER_RFID_EMULATE | FLIPPER_RFID_EMULATE(name: STRING, data_hex: STRING) : BOOL |  | Emulate RFID tag |
| FLIPPER_RFID_READ | FLIPPER_RFID_READ(name: STRING) : STRING |  | Read 125kHz RFID tag (hex), caches result |
| FLIPPER_RFID_READ_CACHED | FLIPPER_RFID_READ_CACHED(name: STRING) : STRING |  | Last cached RFID result (non-blocking) |
| FLIPPER_RFID_STOP | FLIPPER_RFID_STOP(name: STRING) : BOOL |  | Stop RFID operations |
| FLIPPER_SUBGHZ_RX_READ | FLIPPER_SUBGHZ_RX_READ(name: STRING) : STRING |  | Read received Sub-GHz data (hex), caches result |
| FLIPPER_SUBGHZ_RX_START | FLIPPER_SUBGHZ_RX_START(name: STRING, frequency: INT) : BOOL |  | Start receiving on frequency |
| FLIPPER_SUBGHZ_RX_STOP | FLIPPER_SUBGHZ_RX_STOP(name: STRING) : BOOL |  | Stop Sub-GHz receiving |
| FLIPPER_SUBGHZ_TX | FLIPPER_SUBGHZ_TX(name: STRING, frequency: INT, data: STRING) : BOOL |  | Transmit Sub-GHz signal (freq in Hz, data as hex) |

## GCODE

| Function | Signature | Returns | Description |
|---|---|---|---|
| GCODE_CLOSE | GCODE_CLOSE(handle: STRING) : BOOL |  | Close G-code file and free handle |
| GCODE_CONNECT | GCODE_CONNECT(target: STRING) : STRING |  | Connect to CNC/laser/printer (http:// or serial://) |
| GCODE_CONNECTED | GCODE_CONNECTED(handle: STRING) : BOOL |  | Check if machine connection is open |
| GCODE_DISCONNECT | GCODE_DISCONNECT(handle: STRING) : BOOL |  | Disconnect from machine |
| GCODE_DONE | GCODE_DONE(handle: STRING) : BOOL |  | Check if all G-code lines have been read |
| GCODE_GET_CODE | GCODE_GET_CODE(line: STRING) : STRING |  | Extract G/M code from line (e.g. G1, M3) |
| GCODE_GET_E | GCODE_GET_E(line: STRING) : REAL |  | Extract extruder value from line |
| GCODE_GET_F | GCODE_GET_F(line: STRING) : REAL |  | Extract feed rate from line |
| GCODE_GET_PARAM | GCODE_GET_PARAM(line: STRING, param: STRING) : REAL |  | Extract any parameter value from line |
| GCODE_GET_S | GCODE_GET_S(line: STRING) : REAL |  | Extract spindle/laser power from line |
| GCODE_GET_X | GCODE_GET_X(line: STRING) : REAL |  | Extract X coordinate from line |
| GCODE_GET_Y | GCODE_GET_Y(line: STRING) : REAL |  | Extract Y coordinate from line |
| GCODE_GET_Z | GCODE_GET_Z(line: STRING) : REAL |  | Extract Z coordinate from line |
| GCODE_HAS_PARAM | GCODE_HAS_PARAM(line: STRING, param: STRING) : BOOL |  | Check if parameter exists in line |
| GCODE_HOME | GCODE_HOME(handle: STRING) : BOOL |  | Home all axes |
| GCODE_IS_MOVE | GCODE_IS_MOVE(line: STRING) : BOOL |  | TRUE if line is a motion command (G0/G1/G2/G3) |
| GCODE_LINE_NUM | GCODE_LINE_NUM(handle: STRING) : DINT |  | Current line number (1-based) |
| GCODE_NEXT | GCODE_NEXT(handle: STRING) : STRING |  | Get next G-code line and advance position |
| GCODE_OPEN | GCODE_OPEN(path: STRING) : STRING |  | Open and parse G-code file, returns handle |
| GCODE_PAUSE | GCODE_PAUSE(handle: STRING) : BOOL |  | Pause machine (feed hold) |
| GCODE_PEEK | GCODE_PEEK(handle: STRING) : STRING |  | Preview next G-code line without advancing |
| GCODE_POSITION | GCODE_POSITION(handle: STRING) : STRING |  | Get current machine position as X,Y,Z string |
| GCODE_POS_X | GCODE_POS_X(handle: STRING) : REAL |  | Get current machine X position |
| GCODE_POS_Y | GCODE_POS_Y(handle: STRING) : REAL |  | Get current machine Y position |
| GCODE_POS_Z | GCODE_POS_Z(handle: STRING) : REAL |  | Get current machine Z position |
| GCODE_PROGRESS | GCODE_PROGRESS(handle: STRING) : REAL |  | Completion percentage (0.0 to 100.0) |
| GCODE_RESET | GCODE_RESET(handle: STRING) : BOOL |  | Reset read position to first line |
| GCODE_RESUME | GCODE_RESUME(handle: STRING) : BOOL |  | Resume machine after pause |
| GCODE_SEND_CMD | GCODE_SEND_CMD(handle: STRING, command: STRING) : STRING |  | Send G-code command to machine, returns response |
| GCODE_SET_E | GCODE_SET_E(line: STRING, value: REAL) : STRING |  | Set extruder value in line |
| GCODE_SET_F | GCODE_SET_F(line: STRING, value: REAL) : STRING |  | Set feed rate in line |
| GCODE_SET_PARAM | GCODE_SET_PARAM(line: STRING, param: STRING, value: REAL) : STRING |  | Set any parameter value in line |
| GCODE_SET_S | GCODE_SET_S(line: STRING, value: REAL) : STRING |  | Set spindle/laser power in line |
| GCODE_SET_X | GCODE_SET_X(line: STRING, value: REAL) : STRING |  | Set X coordinate in line |
| GCODE_SET_Y | GCODE_SET_Y(line: STRING, value: REAL) : STRING |  | Set Y coordinate in line |
| GCODE_SET_Z | GCODE_SET_Z(line: STRING, value: REAL) : STRING |  | Set Z coordinate in line |
| GCODE_STATUS | GCODE_STATUS(handle: STRING) : STRING |  | Get machine status (idle, running, alarm) |
| GCODE_STOP | GCODE_STOP(handle: STRING) : BOOL |  | Emergency stop the machine |
| GCODE_TOTAL | GCODE_TOTAL(handle: STRING) : DINT |  | Total number of G-code lines in file |

## GPIO

| Function | Signature | Returns | Description |
|---|---|---|---|
| GPIO_LIST | GPIO_LIST() : STRING |  | List all allowed pins with current mode/value as JSON |
| GPIO_MODE | GPIO_MODE(pin: DINT, mode: STRING) : BOOL |  | Configure pin as input or output (BCM number, mode 'input'/'output') |
| GPIO_PLATFORM | GPIO_PLATFORM() : STRING |  | Detected platform: 'rpi', 'opi', 'generic', or 'not_available' |
| GPIO_READ | GPIO_READ(pin: DINT) : BOOL |  | Read digital input pin level (TRUE=high). Auto-configures as input on first call. |
| GPIO_TOGGLE | GPIO_TOGGLE(pin: DINT) : BOOL |  | Invert output pin and return new value |
| GPIO_WRITE | GPIO_WRITE(pin: DINT, value: BOOL) : BOOL |  | Write digital output pin (TRUE=high). Auto-configures as output on first call. |
| I2C_SCAN | I2C_SCAN(bus: DINT) : STRING |  | Scan I2C bus and return JSON array of responding addresses (like i2cdetect) |

## GPS

| Function | Signature | Returns | Description |
|---|---|---|---|
| GPS_BEARING | GPS_BEARING(lat1: REAL, lon1: REAL, lat2: REAL, lon2: REAL) : REAL |  | Bearing from point 1 to point 2 in degrees (0-360) |
| GPS_DD_TO_DMS | GPS_DD_TO_DMS(dd: REAL, [axis: STRING]) : MAP |  | Convert decimal degrees to DMS |
| GPS_DESTINATION | GPS_DESTINATION(lat: REAL, lon: REAL, bearing: REAL, distance_m: REAL) : MAP |  | Calculate destination point from bearing and distance |
| GPS_DISTANCE | GPS_DISTANCE(lat1: REAL, lon1: REAL, lat2: REAL, lon2: REAL) : REAL |  | Haversine distance between two points in meters |
| GPS_DMS_TO_DD | GPS_DMS_TO_DD(deg: REAL, min: REAL, sec: REAL, [dir: STRING]) : REAL |  | Convert degrees/minutes/seconds to decimal degrees |
| GPS_IN_RADIUS | GPS_IN_RADIUS(lat: REAL, lon: REAL, center_lat: REAL, center_lon: REAL, radius_m: REAL) : BOOL |  | Check if point is within radius of center |
| GPS_IN_RECT | GPS_IN_RECT(lat: REAL, lon: REAL, min_lat: REAL, min_lon: REAL, max_lat: REAL, max_lon: REAL) : BOOL |  | Check if point is within bounding rectangle |
| GPS_MIDPOINT | GPS_MIDPOINT(lat1: REAL, lon1: REAL, lat2: REAL, lon2: REAL) : MAP |  | Calculate geographic midpoint |
| GPS_SPEED | GPS_SPEED(lat1: REAL, lon1: REAL, lat2: REAL, lon2: REAL, time_s: REAL) : REAL |  | Calculate speed from two points and time |

## GSV

| Function | Signature | Returns | Description |
|---|---|---|---|
| GSV | GSV(class: STRING, instance: STRING, attribute: STRING) : ANY |  | Get system value |
| GSV_ACTIVEPROCESSOR | GSV_ACTIVEPROCESSOR() : INT |  | Get active processor info |
| GSV_DLRSTATUS | GSV_DLRSTATUS() : INT |  | Get DLR status |
| GSV_DLR_STATUS | GSV_DLR_STATUS() : INT |  | Get DLR status (alias) |
| GSV_ENTRYSTATE | GSV_ENTRYSTATE() : INT |  | Get entry state |
| GSV_ETHERNETSTATUS | GSV_ETHERNETSTATUS(port: INT) : INT |  | Get Ethernet status |
| GSV_ETHERNET_STATUS | GSV_ETHERNET_STATUS(port: INT) : INT |  | Get Ethernet status (alias) |
| GSV_FAULTED | GSV_FAULTED() : BOOL |  | Check if faulted |
| GSV_IOCONNECTION | GSV_IOCONNECTION(instance: INT) : INT |  | Get I/O connection status |
| GSV_MODULESTATUS | GSV_MODULESTATUS(slot: INT) : INT |  | Get module status |
| GSV_PORTSTATUS | GSV_PORTSTATUS(port: INT) : INT |  | Get port status |
| GSV_REDUNDANCYSTATUS | GSV_REDUNDANCYSTATUS() : INT |  | Get redundancy status |
| GSV_SYNCSTATUS | GSV_SYNCSTATUS() : INT |  | Get sync status |
| GSV_TASKSCANTIME | GSV_TASKSCANTIME(task: STRING) : REAL |  | Get task scan time |
| GSV_WALLCLOCKTIME | GSV_WALLCLOCKTIME() : DT |  | Get wall clock time |
| SSV | SSV(class: STRING, instance: STRING, attribute: STRING, value: ANY) : BOOL |  | Set system value |
| SSV_TASKSCANTIME | SSV_TASKSCANTIME(task: STRING, time: REAL) : BOOL |  | Set task scan time |

## HEAP

| Function | Signature | Returns | Description |
|---|---|---|---|
| HEAP_CLEAR | HEAP_CLEAR(h: HEAP) : BOOL |  | Clear heap |
| HEAP_CONTAINS | HEAP_CONTAINS(h: HEAP, val: ANY) : BOOL |  | Check if contains |
| HEAP_CREATE | HEAP_CREATE() : HEAP |  | Create heap |
| HEAP_CREATE_MAX | HEAP_CREATE_MAX() : HEAP |  | Create max heap |
| HEAP_CREATE_MIN | HEAP_CREATE_MIN() : HEAP |  | Create min heap |
| HEAP_EMPTY | HEAP_EMPTY(h: HEAP) : BOOL |  | Check if empty |
| HEAP_FROM_ARRAY | HEAP_FROM_ARRAY(arr: ARRAY) : HEAP |  | Create from array |
| HEAP_IS_EMPTY | HEAP_IS_EMPTY(h: HEAP) : BOOL |  | Check if empty (alias) |
| HEAP_LENGTH | HEAP_LENGTH(h: HEAP) : INT |  | Get length |
| HEAP_MERGE | HEAP_MERGE(h1: HEAP, h2: HEAP) : HEAP |  | Merge heaps |
| HEAP_N_LARGEST | HEAP_N_LARGEST(h: HEAP, n: INT) : ARRAY |  | Get N largest |
| HEAP_N_SMALLEST | HEAP_N_SMALLEST(h: HEAP, n: INT) : ARRAY |  | Get N smallest |
| HEAP_PEEK | HEAP_PEEK(h: HEAP) : ANY |  | Peek top element |
| HEAP_PEEK_PRIORITY | HEAP_PEEK_PRIORITY(h: HEAP) : REAL |  | Peek top priority |
| HEAP_POP | HEAP_POP(h: HEAP) : ANY |  | Pop element |
| HEAP_PUSH | HEAP_PUSH(h: HEAP, val: ANY, priority: REAL) : BOOL |  | Push element |
| HEAP_SIZE | HEAP_SIZE(h: HEAP) : INT |  | Get size |
| HEAP_TOP | HEAP_TOP(h: HEAP) : ANY |  | Get top element |
| HEAP_UPDATE_PRIORITY | HEAP_UPDATE_PRIORITY(h: HEAP, val: ANY, newPriority: REAL) : BOOL |  | Update priority |

## HISTORIAN

| Function | Signature | Returns | Description |
|---|---|---|---|
| HIST_ASOF | HIST_ASOF(tag_a: STRING, tag_b: STRING, start_ms: LINT, end_ms: LINT, max_points: DINT) : STRING |  | As-of join: each tag_a sample paired with tag_b's most-recent value at-or-before it (cross-rate correlation). Requires historian.engine: parquet. |
| HIST_AVG | HIST_AVG(tag_name: STRING, start_ms: LINT, end_ms: LINT) : REAL |  | Average value over time range |
| HIST_BURST_START | HIST_BURST_START(tags: STRING, duration_s: DINT, interval_ms: DINT) : STRING |  | Start event-triggered high-res capture (reserved) |
| HIST_BURST_STOP | HIST_BURST_STOP(burst_id: STRING) : BOOL |  | Stop a burst capture (reserved) |
| HIST_DB_SIZE_MB | HIST_DB_SIZE_MB() : REAL |  | Current historian database size in MB |
| HIST_FLUSH | HIST_FLUSH() : BOOL |  | Force immediate flush of ring buffers to disk |
| HIST_LAST | HIST_LAST(tag_name: STRING) : REAL |  | Most recent logged value for a tag |
| HIST_LOG | HIST_LOG(tag_name: STRING, deadband: REAL, interval_ms: DINT) : BOOL |  | Register a tag for historian logging |
| HIST_LOG_VALUE | HIST_LOG_VALUE(tag_name: STRING, value: ANY, quality: DINT) : BOOL |  | Manually log a value with optional quality code |
| HIST_MAX | HIST_MAX(tag_name: STRING, start_ms: LINT, end_ms: LINT) : REAL |  | Maximum value over time range |
| HIST_MIN | HIST_MIN(tag_name: STRING, start_ms: LINT, end_ms: LINT) : REAL |  | Minimum value over time range |
| HIST_PRUNE | HIST_PRUNE(max_age_days: DINT) : LINT |  | Trigger a retention prune cycle |
| HIST_QUERY | HIST_QUERY(tag_name: STRING, start_ms: LINT, end_ms: LINT, max_points: DINT) : STRING |  | Query historical data as JSON (auto-selects decimation tier) |
| HIST_SAMPLE_COUNT | HIST_SAMPLE_COUNT(tag_name: STRING) : LINT |  | Number of raw samples for a tag |
| HIST_STOP | HIST_STOP(tag_name: STRING) : BOOL |  | Stop logging a tag and remove its data |
| HIST_TAG_COUNT | HIST_TAG_COUNT() : DINT |  | Number of registered historian tags |

## HTTP

| Function | Signature | Returns | Description |
|---|---|---|---|
| HTTP_BODY | HTTP_BODY(response: ANY) : STRING |  | Get response body |
| HTTP_DELETE | HTTP_DELETE(url: STRING) : STRING |  | HTTP DELETE request |
| HTTP_ERROR | HTTP_ERROR() : STRING |  | Get last HTTP error |
| HTTP_GET | HTTP_GET(url: STRING) : STRING |  | HTTP GET request |
| HTTP_GET_BODY | HTTP_GET_BODY(url: STRING) : STRING |  | HTTP GET body only |
| HTTP_GET_HEADER | HTTP_GET_HEADER(response: MAP, header: STRING) : STRING |  | Get HTTP response header |
| HTTP_HEAD | HTTP_HEAD(url: STRING) : STRING |  | HTTP HEAD request |
| HTTP_HEADERS | HTTP_HEADERS(response: ANY) : MAP |  | Get response headers |
| HTTP_OK | HTTP_OK(response: ANY) : BOOL |  | Check if response OK |
| HTTP_PATCH | HTTP_PATCH(url: STRING, body: STRING) : STRING |  | HTTP PATCH request |
| HTTP_POST | HTTP_POST(url: STRING, body: STRING) : STRING |  | HTTP POST request |
| HTTP_POST_JSON | HTTP_POST_JSON(url: STRING, json: ANY) : STRING |  | HTTP POST JSON |
| HTTP_PUT | HTTP_PUT(url: STRING, body: STRING) : STRING |  | HTTP PUT request |
| HTTP_REQUEST | HTTP_REQUEST(method: STRING, url: STRING, headers: STRING, body: STRING) : STRING |  | Custom HTTP request |
| HTTP_SET_HEADER | HTTP_SET_HEADER(request: MAP, header: STRING, value: STRING) : MAP |  | Set HTTP request header |
| HTTP_STATUS | HTTP_STATUS(response: ANY) : INT |  | Get response status code |
| URL_BUILD | URL_BUILD(base: STRING, path: STRING, query: MAP) : STRING |  | Build URL from parts |
| URL_DECODE | URL_DECODE(s: STRING) : STRING |  | URL decode string |
| URL_ENCODE | URL_ENCODE(s: STRING) : STRING |  | URL encode string |
| URL_JOIN | URL_JOIN(base: STRING, path: STRING) : STRING |  | Join URL paths |
| URL_PARSE | URL_PARSE(url: STRING) : MAP |  | Parse URL components |
| URL_QUERY_DELETE | URL_QUERY_DELETE(url: STRING, key: STRING) : STRING |  | Delete query parameter |
| URL_QUERY_GET | URL_QUERY_GET(url: STRING, key: STRING) : STRING |  | Get query parameter |
| URL_QUERY_SET | URL_QUERY_SET(url: STRING, key: STRING, val: STRING) : STRING |  | Set query parameter |

## IEC104

| Function | Signature | Returns | Description |
|---|---|---|---|
| IEC104_CLIENT_CONNECT | IEC104_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect to server |
| IEC104_CLIENT_CREATE | IEC104_CLIENT_CREATE(name: STRING, host: STRING, port: INT, [commonAddr: INT]) : BOOL |  | Create IEC 104 client |
| IEC104_CLIENT_DELETE | IEC104_CLIENT_DELETE(name: STRING) : BOOL |  | Delete IEC 104 client |
| IEC104_CLIENT_DISCONNECT | IEC104_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect from server |
| IEC104_CLIENT_IS_CONNECTED | IEC104_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check connection status |
| IEC104_CLIENT_LIST | IEC104_CLIENT_LIST() : STRING |  | List IEC 104 clients |
| IEC104_CLIENT_READ_COUNTER | IEC104_CLIENT_READ_COUNTER(name: STRING, ioa: INT) : INT |  | Read integrated total (M_IT) |
| IEC104_CLIENT_READ_DP | IEC104_CLIENT_READ_DP(name: STRING, ioa: INT) : INT |  | Read double point (M_DP) |
| IEC104_CLIENT_READ_FLOAT | IEC104_CLIENT_READ_FLOAT(name: STRING, ioa: INT) : REAL |  | Read short float (M_ME_NC) |
| IEC104_CLIENT_READ_SCALED | IEC104_CLIENT_READ_SCALED(name: STRING, ioa: INT) : INT |  | Read scaled value (M_ME_NB) |
| IEC104_CLIENT_READ_SP | IEC104_CLIENT_READ_SP(name: STRING, ioa: INT) : BOOL |  | Read single point (M_SP) |
| IEC104_CLIENT_WRITE_SC | IEC104_CLIENT_WRITE_SC(name: STRING, ioa: INT, value: BOOL) : BOOL |  | Send single command (C_SC) |
| IEC104_CLIENT_WRITE_SETPOINT | IEC104_CLIENT_WRITE_SETPOINT(name: STRING, ioa: INT, value: REAL) : BOOL |  | Send float setpoint (C_SE_NC) |
| IEC104_SERVER_CREATE | IEC104_SERVER_CREATE(name: STRING, port: INT, [commonAddr: INT]) : BOOL |  | Create IEC 104 server |
| IEC104_SERVER_DELETE | IEC104_SERVER_DELETE(name: STRING) : BOOL |  | Delete IEC 104 server |
| IEC104_SERVER_GET_SC | IEC104_SERVER_GET_SC(name: STRING, ioa: INT) : BOOL |  | Get received single command |
| IEC104_SERVER_GET_SETPOINT | IEC104_SERVER_GET_SETPOINT(name: STRING, ioa: INT) : REAL |  | Get received float setpoint |
| IEC104_SERVER_GET_STATS | IEC104_SERVER_GET_STATS(name: STRING) : STRING |  | Get server statistics (JSON) |
| IEC104_SERVER_IS_CONNECTED | IEC104_SERVER_IS_CONNECTED(name: STRING) : BOOL |  | Check if client connected |
| IEC104_SERVER_LIST | IEC104_SERVER_LIST() : STRING |  | List IEC 104 servers |
| IEC104_SERVER_SET_COUNTER | IEC104_SERVER_SET_COUNTER(name: STRING, ioa: INT, value: INT) : BOOL |  | Set counter value |
| IEC104_SERVER_SET_DP | IEC104_SERVER_SET_DP(name: STRING, ioa: INT, value: INT) : BOOL |  | Set double point value |
| IEC104_SERVER_SET_FLOAT | IEC104_SERVER_SET_FLOAT(name: STRING, ioa: INT, value: REAL) : BOOL |  | Set float measurement |
| IEC104_SERVER_SET_SCALED | IEC104_SERVER_SET_SCALED(name: STRING, ioa: INT, value: INT) : BOOL |  | Set scaled measurement |
| IEC104_SERVER_SET_SP | IEC104_SERVER_SET_SP(name: STRING, ioa: INT, value: BOOL) : BOOL |  | Set single point value |
| IEC104_SERVER_START | IEC104_SERVER_START(name: STRING) : BOOL |  | Start server |
| IEC104_SERVER_STOP | IEC104_SERVER_STOP(name: STRING) : BOOL |  | Stop server |

## INFLUX

| Function | Signature | Returns | Description |
|---|---|---|---|
| INFLUX_BATCH_ADD | INFLUX_BATCH_ADD(name: STRING, measurement: STRING, tags: STRING, field: STRING, value: ANY) : BOOL |  | Add auto-typed field to batch buffer. Does not write immediately — call INFLUX_BATCH_FLUSH to send. |
| INFLUX_BATCH_ADD_INT | INFLUX_BATCH_ADD_INT(name: STRING, measurement: STRING, tags: STRING, field: STRING, value: INT) : BOOL |  | Add integer field to batch buffer |
| INFLUX_BATCH_CLEAR | INFLUX_BATCH_CLEAR(name: STRING) : BOOL |  | Discard batch buffer without sending |
| INFLUX_BATCH_FLUSH | INFLUX_BATCH_FLUSH(name: STRING) : INT |  | Send all buffered lines in one HTTP POST. Returns lines sent, 0 if buffer empty, -1 if client not found. Async. |
| INFLUX_BATCH_SIZE | INFLUX_BATCH_SIZE(name: STRING) : INT |  | Return number of lines currently in batch buffer |
| INFLUX_BUILD_LINE | INFLUX_BUILD_LINE(measurement: STRING, tags: STRING, field: STRING, value: ANY) : STRING |  | Build formatted line-protocol string without sending. Pass result to INFLUX_WRITE_LINE. |
| INFLUX_CONNECT | INFLUX_CONNECT(name: STRING, url: STRING, org: STRING, bucket: STRING, token: STRING) : BOOL |  | Create InfluxDB v2 client (token auth) |
| INFLUX_CONNECT_V1 | INFLUX_CONNECT_V1(name: STRING, url: STRING, database: STRING) : BOOL |  | Create InfluxDB v1 client (no authentication) |
| INFLUX_CONNECT_V1_AUTH | INFLUX_CONNECT_V1_AUTH(name: STRING, url: STRING, database: STRING, username: STRING, password: STRING) : BOOL |  | Create InfluxDB v1 client with HTTP basic authentication |
| INFLUX_DISCONNECT | INFLUX_DISCONNECT(name: STRING) : BOOL |  | Remove InfluxDB client |
| INFLUX_IS_CONNECTED | INFLUX_IS_CONNECTED(name: STRING) : BOOL |  | Check if named InfluxDB client exists |
| INFLUX_WRITE | INFLUX_WRITE(name: STRING, measurement: STRING, tags: STRING, field: STRING, value: ANY) : BOOL |  | Write single field with auto-detected type. Async (non-blocking). tags='key=val,key2=val2' or ''. |
| INFLUX_WRITE_BOOL | INFLUX_WRITE_BOOL(name: STRING, measurement: STRING, tags: STRING, field: STRING, value: BOOL) : BOOL |  | Write single boolean field. Async. |
| INFLUX_WRITE_INT | INFLUX_WRITE_INT(name: STRING, measurement: STRING, tags: STRING, field: STRING, value: INT) : BOOL |  | Write single integer field (appends 'i' suffix). Async. |
| INFLUX_WRITE_LINE | INFLUX_WRITE_LINE(name: STRING, line: STRING) : BOOL |  | Write raw InfluxDB line-protocol string. Async. Use INFLUX_BUILD_LINE to construct. |
| INFLUX_WRITE_STR | INFLUX_WRITE_STR(name: STRING, measurement: STRING, tags: STRING, field: STRING, value: STRING) : BOOL |  | Write single string field (double-quoted). Async. |

## INI

| Function | Signature | Returns | Description |
|---|---|---|---|
| INI_DELETE_KEY | INI_DELETE_KEY(handle: HANDLE, section: STRING, key: STRING) : HANDLE |  | Delete key from section |
| INI_DELETE_SECTION | INI_DELETE_SECTION(handle: HANDLE, section: STRING) : HANDLE |  | Delete entire section |
| INI_GET | INI_GET(handle: HANDLE, section: STRING, key: STRING, [default: STRING]) : STRING |  | Get value from INI handle |
| INI_KEYS | INI_KEYS(handle: HANDLE, section: STRING) : ARRAY |  | List keys in section |
| INI_PARSE | INI_PARSE(text: STRING) : HANDLE |  | Parse INI text into handle |
| INI_READ | INI_READ(filepath: STRING, section: STRING, key: STRING, [default: STRING]) : STRING |  | Read value from INI file |
| INI_SECTIONS | INI_SECTIONS(handle: HANDLE) : ARRAY |  | List section names |
| INI_SET | INI_SET(handle: HANDLE, section: STRING, key: STRING, value: STRING) : HANDLE |  | Set value in INI handle |
| INI_TO_STRING | INI_TO_STRING(handle: HANDLE) : STRING |  | Serialize INI handle to text |
| INI_WRITE | INI_WRITE(filepath: STRING, section: STRING, key: STRING, value: STRING) : BOOL |  | Write value to INI file |

## J1939

| Function | Signature | Returns | Description |
|---|---|---|---|
| J1939_COOLANT_TEMP | J1939_COOLANT_TEMP(interface: STRING) : REAL |  | Engine coolant temperature from PGN 65262 SPN 110 (°C, offset -40) |
| J1939_ENGINE_HOURS | J1939_ENGINE_HOURS(interface: STRING) : REAL |  | Total engine hours from PGN 65253 SPN 247 (hours, 0.05 resolution) |
| J1939_ENGINE_RPM | J1939_ENGINE_RPM(interface: STRING) : REAL |  | Engine RPM from PGN 61444 SPN 190 (0.125 RPM resolution) |
| J1939_FUEL_RATE | J1939_FUEL_RATE(interface: STRING) : REAL |  | Fuel consumption rate from PGN 65266 SPN 183 (L/h, 0.05 resolution) |
| J1939_READ_PGN | J1939_READ_PGN(interface: STRING, pgn: DWORD) : STRING |  | Read latest cached J1939 message for a PGN as JSON |
| J1939_REQUEST_PGN | J1939_REQUEST_PGN(interface: STRING, pgn: DWORD, dest: DINT) : BOOL |  | Request a PGN from the network (sends PGN 59904) |
| J1939_SEND_PGN | J1939_SEND_PGN(interface: STRING, pgn: DWORD, dest: DINT, data: STRING) : BOOL |  | Send a J1939 PGN message (hex data, up to 8 bytes) |
| J1939_VEHICLE_SPEED | J1939_VEHICLE_SPEED(interface: STRING) : REAL |  | Vehicle speed from PGN 65265 SPN 84 (km/h, 1/256 resolution) |

## JSON

| Function | Signature | Returns | Description |
|---|---|---|---|
| JSON_APPEND | JSON_APPEND(json: ANY, val: ANY) : ANY |  | Append to JSON array |
| JSON_ARRAY | JSON_ARRAY(vals: ANY...) : ANY |  | Create JSON array |
| JSON_ARRAY_LENGTH | JSON_ARRAY_LENGTH(handle: STRING, path: STRING) : INT |  | Get length of JSON array at path |
| JSON_DELETE | JSON_DELETE(json: ANY, path: STRING) : ANY |  | Delete value at path |
| JSON_ENCODE | JSON_ENCODE(val: ANY) : STRING |  | Encode to JSON string |
| JSON_EXISTS | JSON_EXISTS(json: ANY, path: STRING) : BOOL |  | Check if path exists |
| JSON_GET | JSON_GET(json: ANY, path: STRING) : ANY |  | Get value by path |
| JSON_GET_ARRAY | JSON_GET_ARRAY(handle: STRING, path: STRING, index: INT) : ANY |  | Get array element by index |
| JSON_GET_BOOL | JSON_GET_BOOL(handle: STRING, path: STRING) : BOOL |  | Get boolean from JSON |
| JSON_GET_INT | JSON_GET_INT(handle: STRING, path: STRING) : INT |  | Get integer from JSON |
| JSON_GET_REAL | JSON_GET_REAL(handle: STRING, path: STRING) : REAL |  | Get float from JSON |
| JSON_GET_STRING | JSON_GET_STRING(handle: STRING, path: STRING) : STRING |  | Get string from JSON |
| JSON_HAS | JSON_HAS(json: ANY, key: STRING) : BOOL |  | Check if key exists |
| JSON_KEYS | JSON_KEYS(json: ANY) : ARRAY OF STRING |  | Get object keys |
| JSON_LENGTH | JSON_LENGTH(json: ANY) : INT |  | Get array/object length |
| JSON_MERGE | JSON_MERGE(obj1: ANY, obj2: ANY) : ANY |  | Merge JSON objects |
| JSON_OBJECT | JSON_OBJECT(key: STRING, val: ANY, ...) : ANY |  | Create JSON object |
| JSON_PARSE | JSON_PARSE(s: STRING) : ANY |  | Parse JSON string |
| JSON_PATH | JSON_PATH(json: ANY, path: STRING) : ANY |  | Get value by JSONPath |
| JSON_REMOVE | JSON_REMOVE(json: ANY, key: STRING) : ANY |  | Remove key from object |
| JSON_SET | JSON_SET(json: ANY, path: STRING, val: ANY) : ANY |  | Set value at path |
| JSON_SIZE | JSON_SIZE(json: ANY) : INT |  | Get size of JSON |
| JSON_STRINGIFY | JSON_STRINGIFY(val: ANY) : STRING |  | Convert to JSON string |
| JSON_TYPE | JSON_TYPE(val: ANY) : STRING |  | Get JSON value type |
| JSON_VALID | JSON_VALID(s: STRING) : BOOL |  | Check if valid JSON |
| JSON_VALUES | JSON_VALUES(json: ANY) : ARRAY |  | Get object values |

## KNX

| Function | Signature | Returns | Description |
|---|---|---|---|
| KNX_DECODE_DPT1 | KNX_DECODE_DPT1(byte: INT) : BOOL |  | Decode DPT 1.x from byte |
| KNX_DECODE_DPT5 | KNX_DECODE_DPT5(byte: INT) : INT |  | Decode DPT 5.x from byte |
| KNX_DECODE_DPT9 | KNX_DECODE_DPT9(hi: INT, lo: INT) : REAL |  | Decode DPT 9.x from 2 bytes |
| KNX_DIM | KNX_DIM(target: STRING, group_addr: STRING, percent: REAL) : BOOL |  | Send DPT 5.001 dim percentage |
| KNX_ENCODE_DPT1 | KNX_ENCODE_DPT1(value: BOOL) : INT |  | Encode DPT 1.x boolean |
| KNX_ENCODE_DPT5 | KNX_ENCODE_DPT5(value: INT) : INT |  | Encode DPT 5.x 8-bit unsigned |
| KNX_ENCODE_DPT9 | KNX_ENCODE_DPT9(value: REAL) : ARRAY |  | Encode DPT 9.x 2-byte float |
| KNX_GROUP_ADDR | KNX_GROUP_ADDR(main: INT, middle: INT, sub: INT) : STRING |  | Build group address string |
| KNX_SEND | KNX_SEND(target: STRING, group_addr: STRING, data...: INT) : BOOL |  | Send KNX/IP routing indication |
| KNX_SET_FLOAT | KNX_SET_FLOAT(target: STRING, group_addr: STRING, value: REAL) : BOOL |  | Send DPT 9.001 2-byte float |
| KNX_SET_VALUE | KNX_SET_VALUE(target: STRING, group_addr: STRING, value: INT) : BOOL |  | Send raw 1-byte value (DPT 5.x) |
| KNX_SWITCH | KNX_SWITCH(target: STRING, group_addr: STRING, on_off: BOOL) : BOOL |  | Send DPT 1.001 switch command |

## MATH

| Function | Signature | Returns | Description |
|---|---|---|---|
| ABS | ABS(x: ANY_NUM) : ANY_NUM |  | Absolute value |
| ACOS | ACOS(x: REAL) : REAL |  | Arc cosine |
| ASIN | ASIN(x: REAL) : REAL |  | Arc sine |
| ATAN | ATAN(x: REAL) : REAL |  | Arc tangent |
| ATAN2 | ATAN2(y: REAL, x: REAL) : REAL |  | Arc tangent of y/x |
| CEIL | CEIL(x: REAL) : DINT |  | Round up to nearest integer |
| COS | COS(x: REAL) : REAL |  | Cosine (radians) |
| COSD | COSD(degrees: REAL) : REAL |  | Cosine (degrees) |
| COSH | COSH(x: REAL) : REAL |  | Hyperbolic cosine |
| DEG2RAD | DEG2RAD(degrees: REAL) : REAL |  | Convert degrees to radians (alias) |
| DEG_TO_RAD | DEG_TO_RAD(degrees: REAL) : REAL |  | Convert degrees to radians |
| EVEN | EVEN(x: ANY_INT) : BOOL |  | Check if number is even |
| EXP | EXP(x: REAL) : REAL |  | Exponential (e^x) |
| EXPT | EXPT(x: REAL, y: REAL) : REAL |  | Power (x^y) |
| FACTORIAL | FACTORIAL(n: DINT) : DINT |  | Factorial (n!) |
| FIBONACCI | FIBONACCI(n: DINT) : DINT |  | Fibonacci number at position n |
| FLOOR | FLOOR(x: REAL) : DINT |  | Round down to nearest integer |
| FMOD | FMOD(x: REAL, y: REAL) : REAL |  | Floating-point modulo |
| FRAC | FRAC(x: REAL) : REAL |  | Fractional part of number |
| IS_BETWEEN | IS_BETWEEN(value: REAL, min: REAL, max: REAL) : BOOL |  | Check if value is between min and max |
| IS_NUMERIC | IS_NUMERIC(str: STRING) : BOOL |  | Check if string is numeric |
| LCM | LCM(a: DINT, b: DINT) : DINT |  | Least common multiple |
| LERP | LERP(x1: REAL, x2: REAL, ratio: REAL) : REAL |  | Linear interpolation |
| LGAMMA | LGAMMA(x: REAL) : REAL |  | Log-gamma function |
| LN | LN(x: REAL) : REAL |  | Natural logarithm |
| MAP | MAP(raw: REAL, raw_min: REAL, raw_max: REAL, eu_min: REAL, eu_max: REAL) : REAL |  | Scale value between ranges |
| MOD | MOD(a: ANY_INT, b: ANY_INT) : ANY_INT |  | Modulo operation |
| ODD | ODD(x: ANY_INT) : BOOL |  | Check if number is odd |
| POW | POW(base: REAL, exp: REAL) : REAL |  | Power function |
| RAD2DEG | RAD2DEG(radians: REAL) : REAL |  | Convert radians to degrees (alias) |
| RAD_TO_DEG | RAD_TO_DEG(radians: REAL) : REAL |  | Convert radians to degrees |
| RAND | RAND() : REAL |  | Random number 0-1 |
| ROUND | ROUND(x: REAL) : DINT |  | Round to nearest integer |
| SIGN | SIGN(x: ANY_NUM) : INT |  | Sign of number (-1, 0, 1) |
| SIN | SIN(x: REAL) : REAL |  | Sine (radians) |
| SIND | SIND(degrees: REAL) : REAL |  | Sine (degrees) |
| SINH | SINH(x: REAL) : REAL |  | Hyperbolic sine |
| SPHERE_A | SPHERE_A(radius: REAL) : REAL |  | Surface area of sphere (4*pi*r^2) |
| SQR | SQR(x: REAL) : REAL |  | Square of x (x^2) |
| SQRT | SQRT(x: REAL) : REAL |  | Square root |
| TAN | TAN(x: REAL) : REAL |  | Tangent (radians) |
| TAND | TAND(degrees: REAL) : REAL |  | Tangent (degrees) |
| TANH | TANH(x: REAL) : REAL |  | Hyperbolic tangent |
| TRUNC | TRUNC(x: REAL) : DINT |  | Truncate to integer |

## MBUS

| Function | Signature | Returns | Description |
|---|---|---|---|
| MBUS_BUILD_REQ_UD2 | MBUS_BUILD_REQ_UD2(address: INT) : ARRAY |  | Build REQ_UD2 data request frame |
| MBUS_BUILD_SND_NKE | MBUS_BUILD_SND_NKE(address: INT) : ARRAY |  | Build SND_NKE initialization frame |
| MBUS_CHECKSUM | MBUS_CHECKSUM(byte1: INT, byte2: INT, ...) : INT |  | Calculate M-Bus checksum (sum mod 256) |
| MBUS_GET_MANUFACTURER | MBUS_GET_MANUFACTURER(handle: HANDLE) : STRING |  | Get meter manufacturer code |
| MBUS_GET_MEDIUM | MBUS_GET_MEDIUM(handle: HANDLE) : STRING |  | Get meter medium type (Water, Gas, Heat, etc.) |
| MBUS_GET_RECORD_COUNT | MBUS_GET_RECORD_COUNT(handle: HANDLE) : INT |  | Get number of data records |
| MBUS_GET_RECORD_TYPE | MBUS_GET_RECORD_TYPE(handle: HANDLE, index: INT) : STRING |  | Get record type (instantaneous, maximum, etc.) |
| MBUS_GET_RECORD_UNIT | MBUS_GET_RECORD_UNIT(handle: HANDLE, index: INT) : STRING |  | Get record unit (kWh, m3, °C, etc.) |
| MBUS_GET_RECORD_VALUE | MBUS_GET_RECORD_VALUE(handle: HANDLE, index: INT) : REAL |  | Get record value by index |
| MBUS_PARSE_RESPONSE | MBUS_PARSE_RESPONSE(bytes: ARRAY) : HANDLE |  | Parse M-Bus response frame |
| MBUS_REQUEST_DATA | MBUS_REQUEST_DATA(name: STRING, address: INT) : ARRAY |  | Send SND_NKE + REQ_UD2 and get response |
| MBUS_TCP_CLOSE | MBUS_TCP_CLOSE(name: STRING) : BOOL |  | Close M-Bus TCP connection |
| MBUS_TCP_CONNECT | MBUS_TCP_CONNECT(name: STRING, host_port: STRING) : BOOL |  | Connect to M-Bus gateway via TCP |

## MEMORY

| Function | Signature | Returns | Description |
|---|---|---|---|
| ADR | ADR(var: ANY) : POINTER |  | Get address of variable |
| MOVE | MOVE(val: ANY) : ANY |  | Move/copy value |
| REF | REF(var: ANY) : REF |  | Get reference |
| SIZEOF | SIZEOF(var: ANY) : INT |  | Get size in bytes |

## MIDI

| Function | Signature | Returns | Description |
|---|---|---|---|
| MIDI_BUILD_CC | MIDI_BUILD_CC(channel: INT, controller: INT, value: INT) : INT |  | Build packed CC as single integer |
| MIDI_BUILD_NOTE_OFF | MIDI_BUILD_NOTE_OFF(channel: INT, note: INT, velocity: INT) : INT |  | Build packed Note Off as single integer |
| MIDI_BUILD_NOTE_ON | MIDI_BUILD_NOTE_ON(channel: INT, note: INT, velocity: INT) : INT |  | Build packed Note On as single integer |
| MIDI_CC | MIDI_CC(channel: INT, controller: INT, value: INT) : ARRAY |  | Build Control Change MIDI bytes |
| MIDI_GET_CHANNEL | MIDI_GET_CHANNEL(handle: HANDLE) : INT |  | Get channel (0-15) |
| MIDI_GET_DATA1 | MIDI_GET_DATA1(handle: HANDLE) : INT |  | Get data byte 1 (note/CC number) |
| MIDI_GET_DATA2 | MIDI_GET_DATA2(handle: HANDLE) : INT |  | Get data byte 2 (velocity/CC value) |
| MIDI_GET_STATUS | MIDI_GET_STATUS(handle: HANDLE) : INT |  | Get status byte (0x80, 0x90, etc.) |
| MIDI_NAME_TO_NOTE | MIDI_NAME_TO_NOTE(name: STRING) : INT |  | Convert note name to MIDI number (C4 → 60) |
| MIDI_NOTE_OFF | MIDI_NOTE_OFF(channel: INT, note: INT, velocity: INT) : ARRAY |  | Build Note Off MIDI bytes |
| MIDI_NOTE_ON | MIDI_NOTE_ON(channel: INT, note: INT, velocity: INT) : ARRAY |  | Build Note On MIDI bytes |
| MIDI_NOTE_TO_NAME | MIDI_NOTE_TO_NAME(note: INT) : STRING |  | Convert MIDI note to name (60 → C4) |
| MIDI_PARSE | MIDI_PARSE(byte1: INT, [byte2: INT], [byte3: INT]) : HANDLE |  | Parse raw MIDI bytes into handle |
| MIDI_PITCH_BEND | MIDI_PITCH_BEND(channel: INT, value: INT) : ARRAY |  | Build Pitch Bend MIDI bytes (0-16383, center=8192) |
| MIDI_PROGRAM_CHANGE | MIDI_PROGRAM_CHANGE(channel: INT, program: INT) : ARRAY |  | Build Program Change MIDI bytes |
| MIDI_SYSEX | MIDI_SYSEX(manufacturer_id: INT, data...: INT) : ARRAY |  | Build SysEx message with F0/F7 framing |

## MODBUS

| Function | Signature | Returns | Description |
|---|---|---|---|
| MB_CLIENT_CONNECT | MB_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect to server |
| MB_CLIENT_CONNECTED | MB_CLIENT_CONNECTED(name: STRING) : BOOL |  | Check if client is connected - shorthand |
| MB_CLIENT_CONNECTED | MB_CLIENT_CONNECTED(name: STRING) : BOOL |  | Check connected |
| MB_CLIENT_CREATE | MB_CLIENT_CREATE(name: STRING, host: STRING, port: INT, unit_id: INT) : BOOL |  | Create client |
| MB_CLIENT_DELETE | MB_CLIENT_DELETE(name: STRING) : BOOL |  | Delete client |
| MB_CLIENT_DISCONNECT | MB_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect |
| MB_CLIENT_LIST | MB_CLIENT_LIST() : ARRAY |  | List clients |
| MB_CLIENT_STATS | MB_CLIENT_STATS(name: STRING) : MAP |  | Get statistics |
| MB_CLIENT_STATS | MB_CLIENT_STATS(name: STRING) : MAP |  | Get client statistics |
| MB_READ_COILS | MB_READ_COILS(name: STRING, addr: INT, count: INT) : ARRAY OF BOOL |  | Read coils (FC01) - shorthand |
| MB_READ_COILS | MB_READ_COILS(name: STRING, addr: INT, count: INT) : ARRAY |  | Read coils (FC01) |
| MB_READ_DISCRETE | MB_READ_DISCRETE(name: STRING, addr: INT, count: INT) : ARRAY |  | Read discrete inputs (FC02) |
| MB_READ_DISCRETE | MB_READ_DISCRETE(name: STRING, addr: INT, count: INT) : ARRAY OF BOOL |  | Read discrete inputs (FC02) - shorthand |
| MB_READ_HOLDING | MB_READ_HOLDING(name: STRING, addr: INT, count: INT) : ARRAY OF INT |  | Read holding registers (FC03) - shorthand |
| MB_READ_HOLDING | MB_READ_HOLDING(name: STRING, addr: INT, count: INT) : ARRAY |  | Read holding registers (FC03) |
| MB_READ_INPUT | MB_READ_INPUT(name: STRING, addr: INT, count: INT) : ARRAY OF INT |  | Read input registers (FC04) - shorthand |
| MB_READ_INPUT | MB_READ_INPUT(name: STRING, addr: INT, count: INT) : ARRAY |  | Read input registers (FC04) |
| MB_SERVER_CONNECTIONS | MB_SERVER_CONNECTIONS(name: STRING) : ARRAY |  | Get active connection info |
| MB_SERVER_CONNECTIONS | MB_SERVER_CONNECTIONS(name: STRING) : ARRAY |  | Get connections |
| MB_SERVER_CREATE | MB_SERVER_CREATE(name: STRING, port: INT, unit_id: INT) : BOOL |  | Create server |
| MB_SERVER_DELETE | MB_SERVER_DELETE(name: STRING) : BOOL |  | Delete server |
| MB_SERVER_GET_COIL | MB_SERVER_GET_COIL(name: STRING, addr: INT) : BOOL |  | Get coil |
| MB_SERVER_GET_DISCRETE | MB_SERVER_GET_DISCRETE(name: STRING, addr: INT) : BOOL |  | Get discrete input |
| MB_SERVER_GET_HOLDING | MB_SERVER_GET_HOLDING(name: STRING, addr: INT) : INT |  | Get holding register from server |
| MB_SERVER_GET_HOLDING | MB_SERVER_GET_HOLDING(name: STRING, addr: INT) : INT |  | Get holding register |
| MB_SERVER_GET_INPUT | MB_SERVER_GET_INPUT(name: STRING, addr: INT) : INT |  | Get input register |
| MB_SERVER_GET_INPUT | MB_SERVER_GET_INPUT(name: STRING, addr: INT) : INT |  | Get input register from server |
| MB_SERVER_IS_RUNNING | MB_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if running |
| MB_SERVER_LIST | MB_SERVER_LIST() : ARRAY |  | List servers |
| MB_SERVER_SET_COIL | MB_SERVER_SET_COIL(name: STRING, addr: INT, value: BOOL) : BOOL |  | Set coil |
| MB_SERVER_SET_DISCRETE | MB_SERVER_SET_DISCRETE(name: STRING, addr: INT, value: BOOL) : BOOL |  | Set discrete input |
| MB_SERVER_SET_HOLDING | MB_SERVER_SET_HOLDING(name: STRING, addr: INT, value: INT) : BOOL |  | Set holding register in server memory |
| MB_SERVER_SET_HOLDING | MB_SERVER_SET_HOLDING(name: STRING, addr: INT, value: INT) : BOOL |  | Set holding register |
| MB_SERVER_SET_INPUT | MB_SERVER_SET_INPUT(name: STRING, addr: INT, value: INT) : BOOL |  | Set input register in server memory |
| MB_SERVER_SET_INPUT | MB_SERVER_SET_INPUT(name: STRING, addr: INT, value: INT) : BOOL |  | Set input register |
| MB_SERVER_START | MB_SERVER_START(name: STRING) : BOOL |  | Start server |
| MB_SERVER_STATS | MB_SERVER_STATS(name: STRING) : MAP |  | Get server statistics |
| MB_SERVER_STATS | MB_SERVER_STATS(name: STRING) : MAP |  | Get statistics |
| MB_SERVER_STOP | MB_SERVER_STOP(name: STRING) : BOOL |  | Stop server |
| MB_WRITE_COIL | MB_WRITE_COIL(name: STRING, addr: INT, value: BOOL) : BOOL |  | Write single coil (FC05) - shorthand |
| MB_WRITE_COIL | MB_WRITE_COIL(name: STRING, addr: INT, value: BOOL) : BOOL |  | Write coil (FC05) |
| MB_WRITE_COILS | MB_WRITE_COILS(name: STRING, addr: INT, values: ARRAY) : BOOL |  | Write multiple coils (FC15) - shorthand |
| MB_WRITE_COILS | MB_WRITE_COILS(name: STRING, addr: INT, values: ARRAY) : BOOL |  | Write coils (FC15) |
| MB_WRITE_REGISTER | MB_WRITE_REGISTER(name: STRING, addr: INT, value: INT) : BOOL |  | Write single register (FC06) - shorthand |
| MB_WRITE_REGISTER | MB_WRITE_REGISTER(name: STRING, addr: INT, value: INT) : BOOL |  | Write register (FC06) |
| MB_WRITE_REGISTERS | MB_WRITE_REGISTERS(name: STRING, addr: INT, values: ARRAY) : BOOL |  | Write multiple registers (FC16) - shorthand |
| MB_WRITE_REGISTERS | MB_WRITE_REGISTERS(name: STRING, addr: INT, values: ARRAY) : BOOL |  | Write registers (FC16) |

## MODBUS_RTU

| Function | Signature | Returns | Description |
|---|---|---|---|
| MB_RTU_CLOSE | MB_RTU_CLOSE(name: STRING) : BOOL |  | Close RTU connection |
| MB_RTU_CONNECT | MB_RTU_CONNECT(name: STRING, device: STRING, baud: INT [, slave_id: INT] [, parity: STRING]) : BOOL |  | Open RTU serial connection |
| MB_RTU_CONNECTED | MB_RTU_CONNECTED(name: STRING) : BOOL |  | Check RTU connection |
| MB_RTU_LIST | MB_RTU_LIST() : ARRAY |  | List RTU connections |
| MB_RTU_READ_COILS | MB_RTU_READ_COILS(name: STRING, addr: INT, count: INT) : ARRAY |  | FC01 Read coils |
| MB_RTU_READ_DISCRETE | MB_RTU_READ_DISCRETE(name: STRING, addr: INT, count: INT) : ARRAY |  | FC02 Read discrete inputs |
| MB_RTU_READ_HOLDING | MB_RTU_READ_HOLDING(name: STRING, addr: INT, count: INT) : ARRAY |  | FC03 Read holding registers |
| MB_RTU_READ_INPUT | MB_RTU_READ_INPUT(name: STRING, addr: INT, count: INT) : ARRAY |  | FC04 Read input registers |
| MB_RTU_SCAN_BUS | MB_RTU_SCAN_BUS(name: STRING, start_id: INT, end_id: INT) : ARRAY |  | Scan for responding slaves |
| MB_RTU_SERVER_CONNECT_TCP | MB_RTU_SERVER_CONNECT_TCP(name: STRING, addr: STRING) : BOOL |  | RTU-over-TCP client mode |
| MB_RTU_SERVER_CREATE | MB_RTU_SERVER_CREATE(name: STRING, slave_id: INT [, baud: INT]) : BOOL |  | Create RTU server |
| MB_RTU_SERVER_DELETE | MB_RTU_SERVER_DELETE(name: STRING) : BOOL |  | Delete RTU server |
| MB_RTU_SERVER_GET_COIL | MB_RTU_SERVER_GET_COIL(name: STRING, addr: INT) : BOOL |  | Get coil |
| MB_RTU_SERVER_GET_DISCRETE | MB_RTU_SERVER_GET_DISCRETE(name: STRING, addr: INT) : BOOL |  | Get discrete input |
| MB_RTU_SERVER_GET_HOLDING | MB_RTU_SERVER_GET_HOLDING(name: STRING, addr: INT) : INT |  | Get holding register |
| MB_RTU_SERVER_IS_RUNNING | MB_RTU_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if RTU server running |
| MB_RTU_SERVER_LIST | MB_RTU_SERVER_LIST() : ARRAY |  | List RTU servers |
| MB_RTU_SERVER_SET_COIL | MB_RTU_SERVER_SET_COIL(name: STRING, addr: INT, value: BOOL) : BOOL |  | Set coil |
| MB_RTU_SERVER_SET_DISCRETE | MB_RTU_SERVER_SET_DISCRETE(name: STRING, addr: INT, value: BOOL) : BOOL |  | Set discrete input |
| MB_RTU_SERVER_SET_HOLDING | MB_RTU_SERVER_SET_HOLDING(name: STRING, addr: INT, value: INT) : BOOL |  | Set holding register |
| MB_RTU_SERVER_SET_INPUT | MB_RTU_SERVER_SET_INPUT(name: STRING, addr: INT, value: INT) : BOOL |  | Set input register |
| MB_RTU_SERVER_START_SERIAL | MB_RTU_SERVER_START_SERIAL(name: STRING, device: STRING) : BOOL |  | Listen on serial port |
| MB_RTU_SERVER_START_TCP | MB_RTU_SERVER_START_TCP(name: STRING, addr: STRING) : BOOL |  | Listen on TCP (RTU-over-TCP) |
| MB_RTU_SERVER_STATS | MB_RTU_SERVER_STATS(name: STRING) : MAP |  | Get RTU server statistics |
| MB_RTU_SERVER_STOP | MB_RTU_SERVER_STOP(name: STRING) : BOOL |  | Stop RTU server |
| MB_RTU_SET_SLAVE | MB_RTU_SET_SLAVE(name: STRING, slave_id: INT) : BOOL |  | Change target slave ID |
| MB_RTU_STATS | MB_RTU_STATS(name: STRING) : MAP |  | Get RTU connection statistics |
| MB_RTU_WRITE_COIL | MB_RTU_WRITE_COIL(name: STRING, addr: INT, value: BOOL) : BOOL |  | FC05 Write single coil |
| MB_RTU_WRITE_COILS | MB_RTU_WRITE_COILS(name: STRING, addr: INT, values: ARRAY) : BOOL |  | FC15 Write multiple coils |
| MB_RTU_WRITE_REGISTER | MB_RTU_WRITE_REGISTER(name: STRING, addr: INT, value: INT) : BOOL |  | FC06 Write single register |
| MB_RTU_WRITE_REGISTERS | MB_RTU_WRITE_REGISTERS(name: STRING, addr: INT, values: ARRAY) : BOOL |  | FC16 Write multiple registers |

## MOTION

| Function | Signature | Returns | Description |
|---|---|---|---|
| MC_CONFIG | MC_CONFIG(axis: INT, config: MAP) : BOOL |  | Configure axis |
| MC_CREATE_AXIS | MC_CREATE_AXIS(id: INT, name: STRING) : BOOL |  | Create axis |
| MC_GET_STATE | MC_GET_STATE(axis: INT) : STRING |  | Get axis state |
| MC_HALT | MC_HALT(axis: INT) : BOOL |  | Halt axis |
| MC_HOME | MC_HOME(axis: INT) : BOOL |  | Home axis |
| MC_IS_ENABLED | MC_IS_ENABLED(axis: INT) : BOOL |  | Check if enabled |
| MC_IS_HOMED | MC_IS_HOMED(axis: INT) : BOOL |  | Check if homed |
| MC_IS_MOVING | MC_IS_MOVING(axis: INT) : BOOL |  | Check if moving |
| MC_JOG | MC_JOG(axis: INT, vel: REAL) : BOOL |  | Jog axis |
| MC_LIST_AXES | MC_LIST_AXES() : ARRAY |  | List all axes |
| MC_MOVE_ABSOLUTE | MC_MOVE_ABSOLUTE(axis: INT, pos: REAL, vel: REAL) : BOOL |  | Move to position |
| MC_MOVE_DONE | MC_MOVE_DONE(axis: INT) : BOOL |  | Check if move done |
| MC_MOVE_RELATIVE | MC_MOVE_RELATIVE(axis: INT, dist: REAL, vel: REAL) : BOOL |  | Move relative |
| MC_MOVE_VELOCITY | MC_MOVE_VELOCITY(axis: INT, vel: REAL) : BOOL |  | Move at velocity |
| MC_POWER | MC_POWER(axis: INT, enable: BOOL) : BOOL |  | Enable axis |
| MC_READ_ERROR | MC_READ_ERROR(axis: INT) : INT |  | Read error code |
| MC_READ_POSITION | MC_READ_POSITION(axis: INT) : REAL |  | Read position |
| MC_READ_STATUS | MC_READ_STATUS(axis: INT) : INT |  | Read status |
| MC_READ_VELOCITY | MC_READ_VELOCITY(axis: INT) : REAL |  | Read velocity |
| MC_RESET | MC_RESET(axis: INT) : BOOL |  | Reset axis |
| MC_SET_POSITION | MC_SET_POSITION(axis: INT, pos: REAL) : BOOL |  | Set position |
| MC_STOP | MC_STOP(axis: INT) : BOOL |  | Stop axis |
| MC_UPDATE | MC_UPDATE(axis: INT) : BOOL |  | Update axis |

## MQTT

| Function | Signature | Returns | Description |
|---|---|---|---|
| MQTT_BROKER_CLIENTS | MQTT_BROKER_CLIENTS(name: STRING) : STRING |  | Get connected clients (JSON array) |
| MQTT_BROKER_CREATE | MQTT_BROKER_CREATE(name: STRING, tcpPort: STRING, [wsPort: STRING]) : BOOL |  | Create embedded MQTT broker |
| MQTT_BROKER_CREATE_AUTH | MQTT_BROKER_CREATE_AUTH(name: STRING, tcpPort: STRING, wsPort: STRING, username: STRING, password: STRING) : BOOL |  | Create embedded MQTT broker with auth |
| MQTT_BROKER_DELETE | MQTT_BROKER_DELETE(name: STRING) : BOOL |  | Stop and remove embedded broker |
| MQTT_BROKER_IS_RUNNING | MQTT_BROKER_IS_RUNNING(name: STRING) : BOOL |  | Check if broker is running |
| MQTT_BROKER_KICK | MQTT_BROKER_KICK(name: STRING, clientID: STRING) : BOOL |  | Disconnect a client by ID |
| MQTT_BROKER_LIST | MQTT_BROKER_LIST() : STRING |  | List all embedded brokers |
| MQTT_BROKER_PUBLISH | MQTT_BROKER_PUBLISH(name: STRING, topic: STRING, payload: STRING) : BOOL |  | Publish message from broker |
| MQTT_BROKER_START | MQTT_BROKER_START(name: STRING) : BOOL |  | Start embedded broker |
| MQTT_BROKER_STATS | MQTT_BROKER_STATS(name: STRING) : STRING |  | Get broker statistics (JSON) |
| MQTT_BROKER_STOP | MQTT_BROKER_STOP(name: STRING) : BOOL |  | Stop embedded broker |
| MQTT_CLEAR_ALL | MQTT_CLEAR_ALL(name: STRING) : BOOL |  | Clear all stored messages |
| MQTT_CLEAR_MESSAGE | MQTT_CLEAR_MESSAGE(name: STRING, topic: STRING) : BOOL |  | Clear stored message for topic |
| MQTT_CLIENT_CONNECT | MQTT_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect to broker |
| MQTT_CLIENT_CREATE | MQTT_CLIENT_CREATE(name: STRING, broker: STRING, clientID: STRING) : BOOL |  | Create MQTT client |
| MQTT_CLIENT_CREATE_AUTH | MQTT_CLIENT_CREATE_AUTH(name: STRING, broker: STRING, clientID: STRING, username: STRING, password: STRING) : BOOL |  | Create MQTT client with auth |
| MQTT_CLIENT_DELETE | MQTT_CLIENT_DELETE(name: STRING) : BOOL |  | Remove and disconnect client |
| MQTT_CLIENT_DISCONNECT | MQTT_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect from broker |
| MQTT_CLIENT_IS_CONNECTED | MQTT_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check if connected |
| MQTT_CLIENT_LIST | MQTT_CLIENT_LIST() : ARRAY |  | List all MQTT clients |
| MQTT_CONNECT | MQTT_CONNECT(name: STRING) : BOOL |  | Connect (alias) |
| MQTT_DISCONNECT | MQTT_DISCONNECT(name: STRING) : BOOL |  | Disconnect (alias) |
| MQTT_GET_BROKER | MQTT_GET_BROKER(name: STRING) : STRING |  | Get broker URL |
| MQTT_GET_CLIENT_ID | MQTT_GET_CLIENT_ID(name: STRING) : STRING |  | Get client ID |
| MQTT_GET_MESSAGE | MQTT_GET_MESSAGE(name: STRING, topic: STRING) : STRING |  | Get last message for topic |
| MQTT_GET_MESSAGE_AGE | MQTT_GET_MESSAGE_AGE(name: STRING, topic: STRING) : INT |  | Milliseconds since last message |
| MQTT_GET_MESSAGE_BOOL | MQTT_GET_MESSAGE_BOOL(name: STRING, topic: STRING) : BOOL |  | Get last message as BOOL |
| MQTT_GET_MESSAGE_INT | MQTT_GET_MESSAGE_INT(name: STRING, topic: STRING) : INT |  | Get last message as INT |
| MQTT_GET_MESSAGE_JSON | MQTT_GET_MESSAGE_JSON(name: STRING, topic: STRING) : ANY |  | Get last message as parsed JSON |
| MQTT_GET_MESSAGE_REAL | MQTT_GET_MESSAGE_REAL(name: STRING, topic: STRING) : REAL |  | Get last message as REAL |
| MQTT_HAS_MESSAGE | MQTT_HAS_MESSAGE(name: STRING, topic: STRING) : BOOL |  | Check if message exists for topic |
| MQTT_IS_CONNECTED | MQTT_IS_CONNECTED(name: STRING) : BOOL |  | Check connected (alias) |
| MQTT_PUBLISH | MQTT_PUBLISH(name: STRING, topic: STRING, payload: ANY, [qos: INT], [retained: BOOL]) : BOOL |  | Publish message to topic |
| MQTT_PUBLISH_JSON | MQTT_PUBLISH_JSON(name: STRING, topic: STRING, value: ANY, [qos: INT]) : BOOL |  | Publish JSON payload |
| MQTT_PUBLISH_RETAINED | MQTT_PUBLISH_RETAINED(name: STRING, topic: STRING, payload: ANY) : BOOL |  | Publish retained message |
| MQTT_QUEUE_LENGTH | MQTT_QUEUE_LENGTH(name: STRING) : INT |  | Get queued message count |
| MQTT_QUEUE_PEEK | MQTT_QUEUE_PEEK(name: STRING) : STRING |  | View oldest queued message without removing |
| MQTT_QUEUE_POP | MQTT_QUEUE_POP(name: STRING) : STRING |  | Remove and return oldest queued message |
| MQTT_SET_QOS | MQTT_SET_QOS(name: STRING, qos: INT) : BOOL |  | Set default QoS level |
| MQTT_SET_RETAINED | MQTT_SET_RETAINED(name: STRING, retained: BOOL) : BOOL |  | Set default retained flag |
| MQTT_SUBSCRIBE | MQTT_SUBSCRIBE(name: STRING, topic: STRING, [qos: INT]) : BOOL |  | Subscribe to topic |
| MQTT_UNSUBSCRIBE | MQTT_UNSUBSCRIBE(name: STRING, topic: STRING) : BOOL |  | Unsubscribe from topic |

## NATS

| Function | Signature | Returns | Description |
|---|---|---|---|
| NATS_BROKER_CREATE | NATS_BROKER_CREATE(name: STRING, port: INT) : BOOL |  | Create embedded NATS broker (no auth) |
| NATS_BROKER_CREATE_AUTH | NATS_BROKER_CREATE_AUTH(name: STRING, port: INT, user: STRING, password: STRING) : BOOL |  | Create embedded broker with single user/password |
| NATS_BROKER_CREATE_JS | NATS_BROKER_CREATE_JS(name: STRING, port: INT, store_dir: STRING) : BOOL |  | Create embedded broker with JetStream enabled |
| NATS_BROKER_DELETE | NATS_BROKER_DELETE(name: STRING) : BOOL |  | Stop and unregister broker |
| NATS_BROKER_IS_RUNNING | NATS_BROKER_IS_RUNNING(name: STRING) : BOOL |  | Check if broker is accepting connections |
| NATS_BROKER_LIST | NATS_BROKER_LIST() : STRING |  | List all embedded brokers (CSV) |
| NATS_BROKER_NUM_CONNECTIONS | NATS_BROKER_NUM_CONNECTIONS(name: STRING) : DINT |  | Active client connection count |
| NATS_BROKER_NUM_ROUTES | NATS_BROKER_NUM_ROUTES(name: STRING) : DINT |  | Connected cluster route count |
| NATS_BROKER_START | NATS_BROKER_START(name: STRING) : BOOL |  | Launch broker (waits up to 5s for ready) |
| NATS_BROKER_STATS | NATS_BROKER_STATS(name: STRING) : STRING |  | One-line summary (running/conns/routes/subs/url) |
| NATS_BROKER_STOP | NATS_BROKER_STOP(name: STRING) : BOOL |  | Shut down running broker (idempotent) |
| NATS_BROKER_URL | NATS_BROKER_URL(name: STRING) : STRING |  | Bound nats:// client URL |
| NATS_CLIENT_CONNECT | NATS_CLIENT_CONNECT(name: STRING) : BOOL |  | Open connection to NATS server |
| NATS_CLIENT_CREATE | NATS_CLIENT_CREATE(name: STRING, url: STRING, [clientID: STRING]) : BOOL |  | Create NATS client (no connection yet) |
| NATS_CLIENT_CREATE_AUTH | NATS_CLIENT_CREATE_AUTH(name: STRING, url: STRING, user: STRING, password: STRING) : BOOL |  | Create NATS client with user/password auth |
| NATS_CLIENT_CREATE_TOKEN | NATS_CLIENT_CREATE_TOKEN(name: STRING, url: STRING, token: STRING) : BOOL |  | Create NATS client with token auth |
| NATS_CLIENT_DELETE | NATS_CLIENT_DELETE(name: STRING) : BOOL |  | Remove and close client |
| NATS_CLIENT_DISCONNECT | NATS_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Drain and close connection |
| NATS_CLIENT_IS_CONNECTED | NATS_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check if connected |
| NATS_CLIENT_LIST | NATS_CLIENT_LIST() : STRING |  | List client names (CSV) |
| NATS_CLIENT_STATUS | NATS_CLIENT_STATUS(name: STRING) : STRING |  | Raw connection state (CONNECTED/RECONNECTING/...) |
| NATS_DROPPED | NATS_DROPPED(name: STRING, subject: STRING) : DINT |  | Cumulative drop count for subject |
| NATS_HAS_MESSAGE | NATS_HAS_MESSAGE(name: STRING, subject: STRING) : BOOL |  | Check if buffered messages are available |
| NATS_JS_DROPPED | NATS_JS_DROPPED(name: STRING, durable: STRING) : DINT |  | Cumulative drop count for durable |
| NATS_JS_NEXT_MESSAGE | NATS_JS_NEXT_MESSAGE(name: STRING, durable: STRING) : STRING |  | Pop oldest JetStream message payload |
| NATS_JS_PENDING | NATS_JS_PENDING(name: STRING, durable: STRING) : DINT |  | Buffered JetStream message count |
| NATS_JS_PUBLISH | NATS_JS_PUBLISH(name: STRING, subject: STRING, payload: STRING) : BOOL |  | Publish to JetStream (async, non-blocking) |
| NATS_JS_PULL_SUBSCRIBE | NATS_JS_PULL_SUBSCRIBE(name: STRING, stream: STRING, durable: STRING, [subject_filter: STRING]) : BOOL |  | Bind a pre-existing pull consumer |
| NATS_JS_UNSUBSCRIBE | NATS_JS_UNSUBSCRIBE(name: STRING, durable: STRING) : BOOL |  | Stop pull goroutine, durable persists on server |
| NATS_KV_DELETE | NATS_KV_DELETE(name: STRING, bucket: STRING, key: STRING) : BOOL |  | Tombstone key |
| NATS_KV_GET | NATS_KV_GET(name: STRING, bucket: STRING, key: STRING) : STRING |  | Read key from bucket (empty if missing) |
| NATS_KV_HAS | NATS_KV_HAS(name: STRING, bucket: STRING, key: STRING) : BOOL |  | Check key existence (distinguishes empty value from missing) |
| NATS_KV_KEYS | NATS_KV_KEYS(name: STRING, bucket: STRING) : STRING |  | List all keys in bucket (CSV) |
| NATS_KV_PUT | NATS_KV_PUT(name: STRING, bucket: STRING, key: STRING, value: STRING) : BOOL |  | Write key to bucket |
| NATS_NEXT_MESSAGE | NATS_NEXT_MESSAGE(name: STRING, subject: STRING) : STRING |  | Pop oldest buffered message payload (empty if none) |
| NATS_PENDING | NATS_PENDING(name: STRING, subject: STRING) : DINT |  | Buffered message count |
| NATS_PUBLISH | NATS_PUBLISH(name: STRING, subject: STRING, payload: STRING) : BOOL |  | Fire-and-forget publish |
| NATS_QUEUE_SUBSCRIBE | NATS_QUEUE_SUBSCRIBE(name: STRING, subject: STRING, queue: STRING) : BOOL |  | Subscribe in load-balanced queue group |
| NATS_REQUEST_DATA | NATS_REQUEST_DATA(name: STRING, request_id: DINT) : STRING |  | Drain reply payload (releases handle on read) |
| NATS_REQUEST_DROP | NATS_REQUEST_DROP(name: STRING, request_id: DINT) : BOOL |  | Abandon request without reading |
| NATS_REQUEST_RESULT | NATS_REQUEST_RESULT(name: STRING, request_id: DINT) : INT |  | Status: 0 pending, 1 ready, -1 timeout, -2 error |
| NATS_REQUEST_SEND | NATS_REQUEST_SEND(name: STRING, subject: STRING, payload: STRING, [timeout_ms: DINT]) : DINT |  | Issue async request, returns positive id (0 on err) |
| NATS_SUBSCRIBE | NATS_SUBSCRIBE(name: STRING, subject: STRING) : BOOL |  | Subscribe to subject (drop-old ring buffer) |
| NATS_UNSUBSCRIBE | NATS_UNSUBSCRIBE(name: STRING, subject: STRING) : BOOL |  | Drop subject interest and discard buffered messages |

## NMEA

| Function | Signature | Returns | Description |
|---|---|---|---|
| NMEA_BUILD | NMEA_BUILD(talker: STRING, type: STRING, field1: STRING, ...) : STRING |  | Build NMEA sentence with checksum |
| NMEA_CHECKSUM | NMEA_CHECKSUM(sentence: STRING) : STRING |  | Calculate NMEA checksum |
| NMEA_FIELD_COUNT | NMEA_FIELD_COUNT(handle: HANDLE) : INT |  | Get number of fields |
| NMEA_GET_ALT | NMEA_GET_ALT(handle: HANDLE) : REAL |  | Get altitude in meters |
| NMEA_GET_COURSE | NMEA_GET_COURSE(handle: HANDLE) : REAL |  | Get course over ground |
| NMEA_GET_DATE | NMEA_GET_DATE(handle: HANDLE) : STRING |  | Get date string |
| NMEA_GET_FIELD | NMEA_GET_FIELD(handle: HANDLE, index: INT) : STRING |  | Get raw field by index |
| NMEA_GET_FIX | NMEA_GET_FIX(handle: HANDLE) : INT |  | Get fix quality |
| NMEA_GET_HDOP | NMEA_GET_HDOP(handle: HANDLE) : REAL |  | Get horizontal dilution of precision |
| NMEA_GET_LAT | NMEA_GET_LAT(handle: HANDLE) : REAL |  | Get latitude in decimal degrees |
| NMEA_GET_LON | NMEA_GET_LON(handle: HANDLE) : REAL |  | Get longitude in decimal degrees |
| NMEA_GET_SATS | NMEA_GET_SATS(handle: HANDLE) : INT |  | Get number of satellites |
| NMEA_GET_SPEED | NMEA_GET_SPEED(handle: HANDLE) : REAL |  | Get speed in knots |
| NMEA_GET_TIME | NMEA_GET_TIME(handle: HANDLE) : STRING |  | Get UTC time string |
| NMEA_GET_TYPE | NMEA_GET_TYPE(handle: HANDLE) : STRING |  | Get sentence type (GGA, RMC, etc.) |
| NMEA_PARSE | NMEA_PARSE(sentence: STRING) : HANDLE |  | Parse NMEA 0183 sentence |

## OBD2

| Function | Signature | Returns | Description |
|---|---|---|---|
| OBD2_COOLANT_TEMP | OBD2_COOLANT_TEMP(interface: STRING) : REAL |  | Coolant temperature in °C via PID 0x05 (A-40) |
| OBD2_FUEL_LEVEL | OBD2_FUEL_LEVEL(interface: STRING) : REAL |  | Fuel tank level as percentage via PID 0x2F |
| OBD2_MAF | OBD2_MAF(interface: STRING) : REAL |  | Mass air flow rate in g/s via PID 0x10 ((A*256+B)/100) |
| OBD2_READ_PID | OBD2_READ_PID(interface: STRING, mode: DINT, pid: DINT) : REAL |  | Read an OBD-II Mode 01 PID and return the raw value |
| OBD2_RPM | OBD2_RPM(interface: STRING) : REAL |  | Engine RPM via PID 0x0C ((A*256+B)/4) |
| OBD2_SPEED | OBD2_SPEED(interface: STRING) : REAL |  | Vehicle speed in km/h via PID 0x0D |
| OBD2_THROTTLE | OBD2_THROTTLE(interface: STRING) : REAL |  | Throttle position as percentage via PID 0x11 |

## OPCUA

| Function | Signature | Returns | Description |
|---|---|---|---|
| OPCUA_CLIENT_ADD_NODE | OPCUA_CLIENT_ADD_NODE(name: STRING, tag: STRING, nodeID: STRING, dataType: STRING, writable: BOOL) : BOOL |  | Add node mapping |
| OPCUA_CLIENT_BROWSE | OPCUA_CLIENT_BROWSE(name: STRING, nodeID: STRING) : ARRAY |  | Browse child nodes |
| OPCUA_CLIENT_CONNECT | OPCUA_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect to server |
| OPCUA_CLIENT_CREATE | OPCUA_CLIENT_CREATE(name: STRING, endpoint: STRING, [policy: STRING], [mode: STRING]) : BOOL |  | Create OPC UA client |
| OPCUA_CLIENT_DELETE | OPCUA_CLIENT_DELETE(name: STRING) : BOOL |  | Delete client |
| OPCUA_CLIENT_DISCONNECT | OPCUA_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect from server |
| OPCUA_CLIENT_GET_ENDPOINT | OPCUA_CLIENT_GET_ENDPOINT(name: STRING) : STRING |  | Get client endpoint URL |
| OPCUA_CLIENT_GET_MAPPINGS | OPCUA_CLIENT_GET_MAPPINGS(name: STRING) : ARRAY |  | Get node mappings |
| OPCUA_CLIENT_IS_CONNECTED | OPCUA_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check connection |
| OPCUA_CLIENT_LIST | OPCUA_CLIENT_LIST() : ARRAY |  | List clients |
| OPCUA_CLIENT_READ_BOOL | OPCUA_CLIENT_READ_BOOL(name: STRING, nodeID: STRING) : BOOL |  | Read BOOL node |
| OPCUA_CLIENT_READ_INT | OPCUA_CLIENT_READ_INT(name: STRING, nodeID: STRING) : INT |  | Read INT node |
| OPCUA_CLIENT_READ_NODE | OPCUA_CLIENT_READ_NODE(name: STRING, nodeID: STRING) : ANY |  | Read node value |
| OPCUA_CLIENT_READ_REAL | OPCUA_CLIENT_READ_REAL(name: STRING, nodeID: STRING) : REAL |  | Read REAL node |
| OPCUA_CLIENT_READ_STRING | OPCUA_CLIENT_READ_STRING(name: STRING, nodeID: STRING) : STRING |  | Read STRING node |
| OPCUA_CLIENT_WRITE_BOOL | OPCUA_CLIENT_WRITE_BOOL(name: STRING, nodeID: STRING, value: BOOL) : BOOL |  | Write BOOL node |
| OPCUA_CLIENT_WRITE_INT | OPCUA_CLIENT_WRITE_INT(name: STRING, nodeID: STRING, value: INT) : BOOL |  | Write INT node |
| OPCUA_CLIENT_WRITE_NODE | OPCUA_CLIENT_WRITE_NODE(name: STRING, nodeID: STRING, value: ANY) : BOOL |  | Write node value |
| OPCUA_CLIENT_WRITE_REAL | OPCUA_CLIENT_WRITE_REAL(name: STRING, nodeID: STRING, value: REAL) : BOOL |  | Write REAL node |
| OPCUA_CLIENT_WRITE_STRING | OPCUA_CLIENT_WRITE_STRING(name: STRING, nodeID: STRING, value: STRING) : BOOL |  | Write string value to node |
| OPCUA_SERVER_CREATE | OPCUA_SERVER_CREATE(name: STRING, port: INT) : BOOL |  | Create OPC UA server |
| OPCUA_SERVER_DELETE | OPCUA_SERVER_DELETE(name: STRING) : BOOL |  | Delete OPC UA server |
| OPCUA_SERVER_GET_BOOL | OPCUA_SERVER_GET_BOOL(name: STRING, varName: STRING) : BOOL |  | Read boolean variable |
| OPCUA_SERVER_GET_ENDPOINT | OPCUA_SERVER_GET_ENDPOINT(name: STRING) : STRING |  | Get server endpoint URL |
| OPCUA_SERVER_GET_INT | OPCUA_SERVER_GET_INT(name: STRING, varName: STRING) : INT |  | Read integer variable |
| OPCUA_SERVER_GET_REAL | OPCUA_SERVER_GET_REAL(name: STRING, varName: STRING) : REAL |  | Read real variable |
| OPCUA_SERVER_GET_STATS | OPCUA_SERVER_GET_STATS(name: STRING) : STRING |  | Get server statistics as JSON |
| OPCUA_SERVER_GET_STRING | OPCUA_SERVER_GET_STRING(name: STRING, varName: STRING) : STRING |  | Read string variable |
| OPCUA_SERVER_IS_RUNNING | OPCUA_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if server is running |
| OPCUA_SERVER_LIST | OPCUA_SERVER_LIST() : ARRAY |  | List OPC UA servers |
| OPCUA_SERVER_SET_BOOL | OPCUA_SERVER_SET_BOOL(name: STRING, varName: STRING, value: BOOL) : BOOL |  | Set boolean variable (auto-creates node) |
| OPCUA_SERVER_SET_INT | OPCUA_SERVER_SET_INT(name: STRING, varName: STRING, value: INT) : BOOL |  | Set integer variable (auto-creates node) |
| OPCUA_SERVER_SET_REAL | OPCUA_SERVER_SET_REAL(name: STRING, varName: STRING, value: REAL) : BOOL |  | Set real variable (auto-creates node) |
| OPCUA_SERVER_SET_STRING | OPCUA_SERVER_SET_STRING(name: STRING, varName: STRING, value: STRING) : BOOL |  | Set string variable (auto-creates node) |
| OPCUA_SERVER_START | OPCUA_SERVER_START(name: STRING) : BOOL |  | Start OPC UA server |
| OPCUA_SERVER_STOP | OPCUA_SERVER_STOP(name: STRING) : BOOL |  | Stop OPC UA server |
| UADP_PUB_ADD_VAR | UADP_PUB_ADD_VAR(name: STRING, var_name: STRING) : BOOL |  | Register a field on a UADP publisher (must be called before START) |
| UADP_PUB_CREATE | UADP_PUB_CREATE(name: STRING, group_addr: STRING, publisher_id: DINT, writer_group_id: INT, dataset_writer_id: INT, publishing_interval_ms: REAL) : BOOL |  | Create UADP publisher (no goroutine until START) |
| UADP_PUB_DELETE | UADP_PUB_DELETE(name: STRING) : BOOL |  | Stop and remove a UADP publisher |
| UADP_PUB_SET | UADP_PUB_SET(name: STRING, var_name: STRING, value: ANY) : BOOL |  | Update the cached value for a registered UADP publisher field |
| UADP_PUB_START | UADP_PUB_START(name: STRING) : BOOL |  | Lock the schema and start the UADP publishing goroutine |
| UADP_PUB_STOP | UADP_PUB_STOP(name: STRING) : BOOL |  | Stop the UADP publishing goroutine (schema and cached values preserved) |
| UADP_SUB_CREATE | UADP_SUB_CREATE(name: STRING, group_addr: STRING, pub_id_filter: DINT, wg_id_filter: INT, dsw_id_filter: INT) : BOOL |  | Create UADP subscriber with optional filters (zero = wildcard) |
| UADP_SUB_DELETE | UADP_SUB_DELETE(name: STRING) : BOOL |  | Stop and remove a UADP subscriber |
| UADP_SUB_GET_INT | UADP_SUB_GET_INT(name: STRING, field_index: INT) : DINT |  | Read the most-recently-received field at index as INT |
| UADP_SUB_GET_REAL | UADP_SUB_GET_REAL(name: STRING, field_index: INT) : REAL |  | Read the most-recently-received field at index as REAL |
| UADP_SUB_GET_STRING | UADP_SUB_GET_STRING(name: STRING, field_index: INT) : STRING |  | Read the most-recently-received field at index as STRING |
| UADP_SUB_START | UADP_SUB_START(name: STRING) : BOOL |  | Open the UADP receive socket and start the subscriber goroutine |
| UADP_SUB_STOP | UADP_SUB_STOP(name: STRING) : BOOL |  | Stop the UADP subscriber goroutine (cached values preserved) |

## OSC

| Function | Signature | Returns | Description |
|---|---|---|---|
| OSC_MSG_ADD_BOOL | OSC_MSG_ADD_BOOL(handle: HANDLE, value: BOOL) : HANDLE |  | Add boolean arg to OSC message |
| OSC_MSG_ADD_FLOAT | OSC_MSG_ADD_FLOAT(handle: HANDLE, value: REAL) : HANDLE |  | Add float arg to OSC message |
| OSC_MSG_ADD_INT | OSC_MSG_ADD_INT(handle: HANDLE, value: INT) : HANDLE |  | Add integer arg to OSC message |
| OSC_MSG_ADD_STRING | OSC_MSG_ADD_STRING(handle: HANDLE, value: STRING) : HANDLE |  | Add string arg to OSC message |
| OSC_MSG_CREATE | OSC_MSG_CREATE(address: STRING) : HANDLE |  | Create multi-arg OSC message |
| OSC_MSG_SEND | OSC_MSG_SEND(target: STRING, handle: HANDLE) : BOOL |  | Send built OSC message |
| OSC_SEND | OSC_SEND(target: STRING, address: STRING, value: ANY) : BOOL |  | Send OSC message (auto-detect type) |
| OSC_SEND_BOOL | OSC_SEND_BOOL(target: STRING, address: STRING, value: BOOL) : BOOL |  | Send OSC boolean message |
| OSC_SEND_BUNDLE | OSC_SEND_BUNDLE(target: STRING, msg1: HANDLE, msg2: HANDLE, ...) : BOOL |  | Send OSC bundle with multiple messages |
| OSC_SEND_FLOAT | OSC_SEND_FLOAT(target: STRING, address: STRING, value: REAL) : BOOL |  | Send OSC float message |
| OSC_SEND_INT | OSC_SEND_INT(target: STRING, address: STRING, value: INT) : BOOL |  | Send OSC integer message |
| OSC_SEND_STRING | OSC_SEND_STRING(target: STRING, address: STRING, value: STRING) : BOOL |  | Send OSC string message |

## P2

| Function | Signature | Returns | Description |
|---|---|---|---|
| P2_ADC_READ | P2_ADC_READ(name: STRING, pin: INT) : INT |  | Read ADC value in millivolts |
| P2_ADC_SETUP | P2_ADC_SETUP(name: STRING, pin: INT, gain: INT) : BOOL |  | Setup ADC on pin (gain: 0=1x, 1=3.16x, 2=10x, 3=31.6x, 4=100x) |
| P2_CLOSE | P2_CLOSE(name: STRING) : BOOL |  | Close P2 device |
| P2_CMD | P2_CMD(name: STRING, command: STRING, [params: STRING \| key-value pairs]) : STRING |  | Send schema-driven command to P2 device. Accepts JSON string or key-value pairs. Commands: adc_read, adc_setup, dac_setup, dac_write, enc_read, enc_reset, enc_setup, eye_bottom_lid, eye_lid, eye_move, eye_pupil, eye_ring, eye_start, freq_read, freq_setup, fw_info, i2c_setup, i2c_stop, i2c_xfer, oled_clear, oled_init, oled_print, pin_mode, pin_read, pin_write, ping, pwm_duty, pwm_setup, pwm_stop, servo_batch, smartpin_read, smartpin_start, smartpin_stop, smartpin_write, spi_setup, spi_stop, spi_xfer, status, uart_rx, uart_setup, uart_stop, uart_tx, uart_txrx, version |
| P2_DAC_SETUP | P2_DAC_SETUP(name: STRING, pin: INT) : BOOL |  | Setup DAC on pin |
| P2_DAC_WRITE | P2_DAC_WRITE(name: STRING, pin: INT, value: INT) : BOOL |  | Write DAC value (0-65535) |
| P2_ENC_READ | P2_ENC_READ(name: STRING, pinA: INT) : INT |  | Read encoder count |
| P2_ENC_RESET | P2_ENC_RESET(name: STRING, pinA: INT) : BOOL |  | Reset encoder count to zero (uses DIR pulse, preserves config) |
| P2_ENC_SETUP | P2_ENC_SETUP(name: STRING, pinA: INT, pinB: INT) : BOOL |  | Setup quadrature encoder on pin pair |
| P2_FREQ_READ | P2_FREQ_READ(name: STRING, pin: INT) : INT |  | Read frequency in Hz |
| P2_FREQ_SETUP | P2_FREQ_SETUP(name: STRING, pin: INT, gateMs: INT) : BOOL |  | Setup frequency counter on pin with gate time |
| P2_I2C_READ | P2_I2C_READ(name: STRING, ch: INT, addr: INT, count: INT) : STRING |  | Read bytes from I2C device (returns hex string) |
| P2_I2C_SETUP | P2_I2C_SETUP(name: STRING, ch: INT, sclPin: INT, sdaPin: INT, speedKHz: INT) : BOOL |  | Setup I2C channel on P2 pins |
| P2_I2C_STOP | P2_I2C_STOP(name: STRING, ch: INT) : BOOL |  | Stop I2C channel |
| P2_I2C_WRITE | P2_I2C_WRITE(name: STRING, ch: INT, addr: INT, data: STRING) : BOOL |  | Write bytes to I2C device (data as hex string) |
| P2_I2C_WRITE_BYTE | P2_I2C_WRITE_BYTE(name: STRING, ch: INT, addr: INT, byte: INT) : BOOL |  | Write single byte to I2C device |
| P2_I2C_WRITE_READ | P2_I2C_WRITE_READ(name: STRING, ch: INT, addr: INT, writeData: STRING, readCount: INT) : STRING |  | Write then read from I2C device (register access pattern) |
| P2_INIT | P2_INIT(name: STRING, port: STRING, firmwarePath: STRING) : BOOL |  | Initialize P2 device on serial port, loads command schema from firmware directory |
| P2_OLED_CLEAR | P2_OLED_CLEAR(name: STRING, ch: INT) : BOOL |  | Clear OLED display |
| P2_OLED_INIT | P2_OLED_INIT(name: STRING, ch: INT, addr: INT) : BOOL |  | Initialize SSD1306 OLED display on I2C channel |
| P2_OLED_PRINT | P2_OLED_PRINT(name: STRING, row: INT, text: STRING) : BOOL |  | Print text on OLED row (0-7) |
| P2_PIN_MODE | P2_PIN_MODE(name: STRING, pin: INT, mode: INT) : BOOL |  | Set pin direction (0=input, 1=output) |
| P2_PIN_READ | P2_PIN_READ(name: STRING, pin: INT) : INT |  | Read digital pin state |
| P2_PIN_TOGGLE | P2_PIN_TOGGLE(name: STRING, pin: INT) : BOOL |  | Toggle digital pin (read then write inverse) |
| P2_PIN_WRITE | P2_PIN_WRITE(name: STRING, pin: INT, value: INT) : BOOL |  | Write digital pin state |
| P2_PWM_DUTY | P2_PWM_DUTY(name: STRING, pin: INT, duty: INT) : BOOL |  | Set PWM duty cycle (0-65535 scaled) |
| P2_PWM_SETUP | P2_PWM_SETUP(name: STRING, pin: INT, freq: INT) : BOOL |  | Setup PWM on pin at given frequency |
| P2_PWM_STOP | P2_PWM_STOP(name: STRING, pin: INT) : BOOL |  | Stop PWM on pin |
| P2_SERVO_MOVE | P2_SERVO_MOVE(name: STRING, pin: INT, duty: INT, speed: INT) : BOOL |  | Move servo (pin, duty 0-65535, speed) |
| P2_SMARTPIN_READ | P2_SMARTPIN_READ(name: STRING, pin: INT) : INT |  | Read smart pin value |
| P2_SMARTPIN_START | P2_SMARTPIN_START(name: STRING, pin: INT, mode: DINT, x: DINT, y: DINT) : BOOL |  | Configure and start a smart pin |
| P2_SMARTPIN_STOP | P2_SMARTPIN_STOP(name: STRING, pin: INT) : BOOL |  | Stop and release a smart pin |
| P2_SMARTPIN_WRITE | P2_SMARTPIN_WRITE(name: STRING, pin: INT, value: DINT) : BOOL |  | Write smart pin value |
| P2_SPI_SETUP | P2_SPI_SETUP(name: STRING, ch: INT, clk: INT, mosi: INT, miso: INT, cs: INT, speedKHz: INT, mode: INT) : BOOL |  | Setup SPI channel on P2 pins |
| P2_SPI_STOP | P2_SPI_STOP(name: STRING, ch: INT) : BOOL |  | Stop SPI channel |
| P2_SPI_XFER | P2_SPI_XFER(name: STRING, ch: INT, flags: INT, txData: STRING) : STRING |  | SPI transfer (flags: 1=CS assert, 2=CS deassert, 4=read). Data as hex |
| P2_STATUS | P2_STATUS(name: STRING) : STRING |  | Get P2 device status (JSON) |
| P2_UART_RECV | P2_UART_RECV(name: STRING, ch: INT, maxLen: INT, timeoutMs: INT) : STRING |  | Receive data from UART channel (returns hex string) |
| P2_UART_SEND | P2_UART_SEND(name: STRING, ch: INT, data: STRING) : INT |  | Send data on UART channel (hex string) |
| P2_UART_SETUP | P2_UART_SETUP(name: STRING, ch: INT, txPin: INT, rxPin: INT, baud: INT) : BOOL |  | Setup UART channel on P2 pins |
| P2_UART_STOP | P2_UART_STOP(name: STRING, ch: INT) : BOOL |  | Stop UART channel |
| P2_UART_TXRX | P2_UART_TXRX(name: STRING, ch: INT, data: STRING, timeoutMs: INT) : STRING |  | Send data and receive response on UART (hex strings) |

## P2_CMD

| Function | Signature | Returns | Description |
|---|---|---|---|
| P2_CMD:adc_read | P2_CMD('dev', 'adc_read', 'pin', pin) : STRING |  | P2_CMD 'adc_read' (0x81) → millivolts: INT |
| P2_CMD:adc_setup | P2_CMD('dev', 'adc_setup', 'pin', pin, 'gain', gain) : STRING |  | P2_CMD 'adc_setup' (0x80) → ok: INT |
| P2_CMD:dac_setup | P2_CMD('dev', 'dac_setup', 'pin', pin) : STRING |  | P2_CMD 'dac_setup' (0x82) → ok: INT |
| P2_CMD:dac_write | P2_CMD('dev', 'dac_write', 'pin', pin, 'value', value) : STRING |  | P2_CMD 'dac_write' (0x83) → ok: INT |
| P2_CMD:enc_read | P2_CMD('dev', 'enc_read', 'pinA', pinA) : STRING |  | P2_CMD 'enc_read' (0x88) → count: INT |
| P2_CMD:enc_reset | P2_CMD('dev', 'enc_reset', 'pinA', pinA) : STRING |  | P2_CMD 'enc_reset' (0x89) → ok: INT |
| P2_CMD:enc_setup | P2_CMD('dev', 'enc_setup', 'pinA', pinA, 'pinB', pinB) : STRING |  | P2_CMD 'enc_setup' (0x87) → ok: INT |
| P2_CMD:eye_batch | P2_CMD('dev', 'eye_batch', '{"count": N, "entries": [{"eye": e, "flags": f, "x": x, "y": y, "top_lid": t, "bot_lid": b, "pupil": p, "ring": r}, ...]}') : STRING |  | P2_CMD 'eye_batch' (0x8E) → updated: INT. Updates up to 2 animated eye displays in ONE serial round-trip. Each entry has a 'flags' bitmask selecting which fields apply: 0x01=x/y, 0x02=top_lid, 0x04=bot_lid, 0x08=pupil, 0x10=ring (0x1F = apply all). Use this instead of eye_move+eye_lid+eye_pupil+eye_ring per-eye to cut 4-8 round-trips to 1 per scan. Requires JSON form: 'entries' is an ARRAY. |
| P2_CMD:eye_bottom_lid | P2_CMD('dev', 'eye_bottom_lid', 'eye', eye, 'position', position) : STRING |  | P2_CMD 'eye_bottom_lid' (0x79) → ok: INT |
| P2_CMD:eye_lid | P2_CMD('dev', 'eye_lid', 'eye', eye, 'position', position) : STRING |  | P2_CMD 'eye_lid' (0x78) → ok: INT |
| P2_CMD:eye_move | P2_CMD('dev', 'eye_move', 'eye', eye, 'x', x, 'y', y) : STRING |  | P2_CMD 'eye_move' (0x75) → ok: INT |
| P2_CMD:eye_pupil | P2_CMD('dev', 'eye_pupil', 'eye', eye, 'radius', radius) : STRING |  | P2_CMD 'eye_pupil' (0x76) → ok: INT |
| P2_CMD:eye_ring | P2_CMD('dev', 'eye_ring', 'eye', eye, 'radius', radius) : STRING |  | P2_CMD 'eye_ring' (0x7A) → ok: INT |
| P2_CMD:eye_start | P2_CMD('dev', 'eye_start', 'sda', sda, 'scl', scl, 'addr', addr) : STRING |  | P2_CMD 'eye_start' (0x74) → ok: INT |
| P2_CMD:freq_read | P2_CMD('dev', 'freq_read', 'pin', pin) : STRING |  | P2_CMD 'freq_read' (0x8B) → hz: INT, duty: INT |
| P2_CMD:freq_setup | P2_CMD('dev', 'freq_setup', 'pin', pin, 'gate_ms', gate_ms) : STRING |  | P2_CMD 'freq_setup' (0x8A) → ok: INT |
| P2_CMD:fw_info | P2_CMD('dev', 'fw_info') : STRING |  | P2_CMD 'fw_info' (0x30) → version: INT, clkfreq: INT, num_din: INT, num_dout: INT, num_ain: INT, num_aout: INT |
| P2_CMD:i2c_setup | P2_CMD('dev', 'i2c_setup', 'ch', ch, 'scl', scl, 'sda', sda, 'speed_khz', speed_khz) : STRING |  | P2_CMD 'i2c_setup' (0x50) → ok: INT |
| P2_CMD:i2c_stop | P2_CMD('dev', 'i2c_stop', 'ch', ch) : STRING |  | P2_CMD 'i2c_stop' (0x52) → ok: INT |
| P2_CMD:i2c_xfer | P2_CMD('dev', 'i2c_xfer', 'ch', ch, 'addr', addr, 'flags', flags, 'write_len', write_len, 'read_len', read_len, 'write_data', write_data) : STRING |  | P2_CMD 'i2c_xfer' (0x51) → ack: INT, read_data: STRING |
| P2_CMD:oled_clear | P2_CMD('dev', 'oled_clear', 'ch', ch) : STRING |  | P2_CMD 'oled_clear' (0x71) → ok: INT |
| P2_CMD:oled_init | P2_CMD('dev', 'oled_init', 'ch', ch, 'addr', addr) : STRING |  | P2_CMD 'oled_init' (0x70) → ok: INT |
| P2_CMD:oled_print | P2_CMD('dev', 'oled_print', 'row', row, 'text', text) : STRING |  | P2_CMD 'oled_print' (0x72) → ok: INT |
| P2_CMD:pin_mode | P2_CMD('dev', 'pin_mode', 'pin', pin, 'mode', mode) : STRING |  | P2_CMD 'pin_mode' (0x20) → ok: INT |
| P2_CMD:pin_read | P2_CMD('dev', 'pin_read', 'pin', pin) : STRING |  | P2_CMD 'pin_read' (0x21) → value: INT |
| P2_CMD:pin_write | P2_CMD('dev', 'pin_write', 'pin', pin, 'value', value) : STRING |  | P2_CMD 'pin_write' (0x22) → ok: INT |
| P2_CMD:ping | P2_CMD('dev', 'ping') : STRING |  | P2_CMD 'ping' (0x01) — liveness check |
| P2_CMD:pwm_duty | P2_CMD('dev', 'pwm_duty', 'pin', pin, 'duty', duty) : STRING |  | P2_CMD 'pwm_duty' (0x85) → ok: INT |
| P2_CMD:pwm_setup | P2_CMD('dev', 'pwm_setup', 'pin', pin, 'freq', freq) : STRING |  | P2_CMD 'pwm_setup' (0x84) → ok: INT |
| P2_CMD:pwm_stop | P2_CMD('dev', 'pwm_stop', 'pin', pin) : STRING |  | P2_CMD 'pwm_stop' (0x86) → ok: INT |
| P2_CMD:servo_batch | P2_CMD('dev', 'servo_batch', '{"count": N, "entries": [{"pin": p, "duty": d, "speed": s}, ...]}') : STRING |  | P2_CMD 'servo_batch' (0x8C) → updated: INT. Updates up to 204 servos in ONE serial round-trip while preserving the same per-servo speed ramp as servo_move (1=instant, 5=default, 20=slow, negative=linear deg/sec). Use this instead of multiple servo_move calls when you have several servos on the same P2 — same motion, ~8x less serial overhead per scan. Requires JSON form: 'entries' is an ARRAY of {pin:u8, duty:u16, speed:i16} objects and cannot be expressed via ST key-value syntax. |
| P2_CMD:servo_move | P2_CMD('dev', 'servo_move', 'pin', pin, 'duty', duty, 'speed', speed) : STRING |  | P2_CMD 'servo_move' (0x8D) — set servo position with speed control. speed>0: divisor (1=instant, 5=default, 20=very slow). speed=0: default |
| P2_CMD:smartpin_read | P2_CMD('dev', 'smartpin_read', 'pin', pin) : STRING |  | P2_CMD 'smartpin_read' (0x24) → value: INT |
| P2_CMD:smartpin_start | P2_CMD('dev', 'smartpin_start', 'pin', pin, 'mode', mode, 'x', x, 'y', y) : STRING |  | P2_CMD 'smartpin_start' (0x23) → ok: INT |
| P2_CMD:smartpin_stop | P2_CMD('dev', 'smartpin_stop', 'pin', pin) : STRING |  | P2_CMD 'smartpin_stop' (0x26) → ok: INT |
| P2_CMD:smartpin_write | P2_CMD('dev', 'smartpin_write', 'pin', pin, 'value', value) : STRING |  | P2_CMD 'smartpin_write' (0x25) → ok: INT |
| P2_CMD:spi_setup | P2_CMD('dev', 'spi_setup', 'ch', ch, 'clk', clk, 'mosi', mosi, 'miso', miso, 'cs', cs, 'speed_khz', speed_khz, 'mode', mode) : STRING |  | P2_CMD 'spi_setup' (0x60) → ok: INT |
| P2_CMD:spi_stop | P2_CMD('dev', 'spi_stop', 'ch', ch) : STRING |  | P2_CMD 'spi_stop' (0x62) → ok: INT |
| P2_CMD:spi_xfer | P2_CMD('dev', 'spi_xfer', 'ch', ch, 'flags', flags, 'tx_data', tx_data) : STRING |  | P2_CMD 'spi_xfer' (0x61) → rx_data: STRING |
| P2_CMD:status | P2_CMD('dev', 'status') : STRING |  | P2_CMD 'status' (0x05) → status: INT |
| P2_CMD:uart_rx | P2_CMD('dev', 'uart_rx', 'ch', ch, 'max_len', max_len, 'timeout_ms', timeout_ms) : STRING |  | P2_CMD 'uart_rx' (0x42) → count: INT, data: STRING |
| P2_CMD:uart_setup | P2_CMD('dev', 'uart_setup', 'ch', ch, 'tx_pin', tx_pin, 'rx_pin', rx_pin, 'baud', baud) : STRING |  | P2_CMD 'uart_setup' (0x40) → ok: INT |
| P2_CMD:uart_stop | P2_CMD('dev', 'uart_stop', 'ch', ch) : STRING |  | P2_CMD 'uart_stop' (0x43) → ok: INT |
| P2_CMD:uart_tx | P2_CMD('dev', 'uart_tx', 'ch', ch, 'data', data) : STRING |  | P2_CMD 'uart_tx' (0x41) → count: INT |
| P2_CMD:uart_txrx | P2_CMD('dev', 'uart_txrx', 'ch', ch, 'timeout_ms', timeout_ms, 'data', data) : STRING |  | P2_CMD 'uart_txrx' (0x44) → count: INT, data: STRING |
| P2_CMD:version | P2_CMD('dev', 'version') : STRING |  | P2_CMD 'version' (0x03) → version: INT |

## PHIDGET

| Function | Signature | Returns | Description |
|---|---|---|---|
| PHIDGET_CLOSE | PHIDGET_CLOSE(name: STRING) : BOOL |  | Close and unregister channel |
| PHIDGET_CURRENT | PHIDGET_CURRENT(name: STRING) : REAL |  | Read CurrentInput value |
| PHIDGET_DELETE | PHIDGET_DELETE(name: STRING) : BOOL |  | Stop and remove client |
| PHIDGET_HUMIDITY | PHIDGET_HUMIDITY(name: STRING) : REAL |  | Read HumiditySensor value |
| PHIDGET_IS_ATTACHED | PHIDGET_IS_ATTACHED(clientName: STRING) : BOOL |  | Device-level liveness probe. The argument is the CLIENT name (typically 'default'), not a channel name — attached is a property of the USB device, not individual channels. Returns true only while the backend reader goroutine is running AND a packet arrived within the last second. Drops to false on USB detach within ~1s. Poll from state 1 of a CASE state machine; drop to state 0 on false to re-run PHIDGET_OPEN (which reclaims USB like SERIAL_FIND + P2_INIT). |
| PHIDGET_LIST | PHIDGET_LIST() : STRING |  | List channels as comma-separated name(type) pairs |
| PHIDGET_OPEN | PHIDGET_OPEN(name: STRING, channel_type: STRING, serial: INT, hub_port: INT, channel: INT) : BOOL |  | Register and open a Phidgets channel |
| PHIDGET_RATIO | PHIDGET_RATIO(name: STRING) : REAL |  | Read VoltageRatioInput value |
| PHIDGET_READ | PHIDGET_READ(name: STRING) : REAL |  | Read any numeric channel value |
| PHIDGET_READ_BOOL | PHIDGET_READ_BOOL(name: STRING) : BOOL |  | Read DigitalInput/DigitalOutput state |
| PHIDGET_SET_MOTOR | PHIDGET_SET_MOTOR(name: STRING, velocity: REAL) : BOOL |  | Set DCMotor velocity (0.0-1.0) |
| PHIDGET_SET_RELAY | PHIDGET_SET_RELAY(name: STRING, value: BOOL) : BOOL |  | Set DigitalOutput relay (alias for WRITE_BOOL) |
| PHIDGET_TEMPERATURE | PHIDGET_TEMPERATURE(name: STRING) : REAL |  | Read TemperatureSensor value |
| PHIDGET_VOLTAGE | PHIDGET_VOLTAGE(name: STRING) : REAL |  | Read VoltageInput value |
| PHIDGET_WRITE | PHIDGET_WRITE(name: STRING, value: REAL) : BOOL |  | Write DCMotor velocity or VoltageOutput |
| PHIDGET_WRITE_BOOL | PHIDGET_WRITE_BOOL(name: STRING, value: BOOL) : BOOL |  | Write DigitalOutput/relay |

## PQUEUE

| Function | Signature | Returns | Description |
|---|---|---|---|
| PQUEUE_CLEAR | PQUEUE_CLEAR(pq: PQUEUE) : BOOL |  | Clear queue |
| PQUEUE_CONTAINS | PQUEUE_CONTAINS(pq: PQUEUE, val: ANY) : BOOL |  | Check if contains |
| PQUEUE_CREATE | PQUEUE_CREATE() : PQUEUE |  | Create priority queue |
| PQUEUE_CREATE_MAX | PQUEUE_CREATE_MAX() : PQUEUE |  | Create max priority queue |
| PQUEUE_CREATE_MIN | PQUEUE_CREATE_MIN() : PQUEUE |  | Create min priority queue |
| PQUEUE_DEQUEUE | PQUEUE_DEQUEUE(pq: PQUEUE) : ANY |  | Dequeue element |
| PQUEUE_EMPTY | PQUEUE_EMPTY(pq: PQUEUE) : BOOL |  | Check if empty |
| PQUEUE_ENQUEUE | PQUEUE_ENQUEUE(pq: PQUEUE, val: ANY, priority: REAL) : BOOL |  | Enqueue element |
| PQUEUE_FROM_ARRAY | PQUEUE_FROM_ARRAY(arr: ARRAY) : PQUEUE |  | Create from array |
| PQUEUE_IS_EMPTY | PQUEUE_IS_EMPTY(pq: PQUEUE) : BOOL |  | Check if empty (alias) |
| PQUEUE_LENGTH | PQUEUE_LENGTH(pq: PQUEUE) : INT |  | Get length |
| PQUEUE_MERGE | PQUEUE_MERGE(pq1: PQUEUE, pq2: PQUEUE) : PQUEUE |  | Merge queues |
| PQUEUE_N_LARGEST | PQUEUE_N_LARGEST(pq: PQUEUE, n: INT) : ARRAY |  | Get N largest |
| PQUEUE_N_SMALLEST | PQUEUE_N_SMALLEST(pq: PQUEUE, n: INT) : ARRAY |  | Get N smallest |
| PQUEUE_PEEK | PQUEUE_PEEK(pq: PQUEUE) : ANY |  | Peek top element |
| PQUEUE_PEEK_PRIORITY | PQUEUE_PEEK_PRIORITY(pq: PQUEUE) : REAL |  | Peek top priority |
| PQUEUE_POP | PQUEUE_POP(pq: PQUEUE) : ANY |  | Pop element |
| PQUEUE_PUSH | PQUEUE_PUSH(pq: PQUEUE, val: ANY, priority: REAL) : BOOL |  | Push element |
| PQUEUE_SIZE | PQUEUE_SIZE(pq: PQUEUE) : INT |  | Get size |
| PQUEUE_TOP | PQUEUE_TOP(pq: PQUEUE) : ANY |  | Get top element |
| PQUEUE_UPDATE_PRIORITY | PQUEUE_UPDATE_PRIORITY(pq: PQUEUE, val: ANY, newPriority: REAL) : BOOL |  | Update priority |

## RANGE

| Function | Signature | Returns | Description |
|---|---|---|---|
| BETWEEN | BETWEEN(val: ANY_NUM, low: ANY_NUM, high: ANY_NUM) : BOOL |  | Check if value is between |
| IN_RANGE | IN_RANGE(val: ANY_NUM, low: ANY_NUM, high: ANY_NUM) : BOOL |  | Check if value in range |
| LOWER_BOUND | LOWER_BOUND(arr: ARRAY) : ANY |  | Get lower bound |
| NOT_BETWEEN | NOT_BETWEEN(val: ANY_NUM, low: ANY_NUM, high: ANY_NUM) : BOOL |  | Check if value is not between |
| RANGE | RANGE(start: INT, stop: INT, step: INT) : ARRAY |  | Generate range array |
| UPPER_BOUND | UPPER_BOUND(arr: ARRAY) : ANY |  | Get upper bound |
| WITHIN | WITHIN(val: ANY_NUM, center: ANY_NUM, tolerance: ANY_NUM) : BOOL |  | Check if value within range |

## REGEX

| Function | Signature | Returns | Description |
|---|---|---|---|
| REGEX_COUNT | REGEX_COUNT(pattern: STRING, s: STRING) : INT |  | Count pattern matches |
| REGEX_ESCAPE | REGEX_ESCAPE(s: STRING) : STRING |  | Escape regex chars |
| REGEX_FIND | REGEX_FIND(pattern: STRING, s: STRING) : STRING |  | Find first match |
| REGEX_FIND_ALL | REGEX_FIND_ALL(pattern: STRING, s: STRING) : ARRAY OF STRING |  | Find all matches |
| REGEX_GROUPS | REGEX_GROUPS(pattern: STRING, s: STRING) : ARRAY OF STRING |  | Extract capture groups |
| REGEX_GROUPS_ALL | REGEX_GROUPS_ALL(pattern: STRING, s: STRING) : ARRAY |  | Extract all groups |
| REGEX_INDEX | REGEX_INDEX(pattern: STRING, s: STRING) : INT |  | Get match index |
| REGEX_INDICES | REGEX_INDICES(pattern: STRING, s: STRING) : ARRAY |  | Get all match indices |
| REGEX_MATCH | REGEX_MATCH(pattern: STRING, s: STRING) : BOOL |  | Check if pattern matches |
| REGEX_REPLACE | REGEX_REPLACE(pattern: STRING, s: STRING, repl: STRING) : STRING |  | Replace all matches |
| REGEX_REPLACE_FIRST | REGEX_REPLACE_FIRST(pattern: STRING, s: STRING, repl: STRING) : STRING |  | Replace first match |
| REGEX_SPLIT | REGEX_SPLIT(pattern: STRING, s: STRING) : ARRAY OF STRING |  | Split by pattern |
| REGEX_VALID | REGEX_VALID(pattern: STRING) : BOOL |  | Check if valid regex |
| RE_COUNT | RE_COUNT(pattern: STRING, str: STRING) : INT |  | Regex count (alias) |
| RE_ESCAPE | RE_ESCAPE(str: STRING) : STRING |  | Regex escape (alias) |
| RE_FIND | RE_FIND(pattern: STRING, str: STRING) : STRING |  | Regex find (alias) |
| RE_FIND_ALL | RE_FIND_ALL(pattern: STRING, str: STRING) : ARRAY |  | Regex find all (alias) |
| RE_GROUPS | RE_GROUPS(pattern: STRING, str: STRING) : ARRAY |  | Regex groups (alias) |
| RE_GROUPS_ALL | RE_GROUPS_ALL(pattern: STRING, str: STRING) : ARRAY |  | Regex all groups (alias) |
| RE_INDEX | RE_INDEX(pattern: STRING, str: STRING) : INT |  | Regex index (alias) |
| RE_INDICES | RE_INDICES(pattern: STRING, str: STRING) : ARRAY |  | Regex indices (alias) |
| RE_MATCH | RE_MATCH(pattern: STRING, str: STRING) : BOOL |  | Regex match (alias) |
| RE_REPLACE | RE_REPLACE(pattern: STRING, str: STRING, repl: STRING) : STRING |  | Regex replace (alias) |
| RE_REPLACE_FIRST | RE_REPLACE_FIRST(pattern: STRING, str: STRING, repl: STRING) : STRING |  | Regex replace first (alias) |
| RE_SPLIT | RE_SPLIT(pattern: STRING, str: STRING) : ARRAY |  | Regex split (alias) |
| RE_VALID | RE_VALID(pattern: STRING) : BOOL |  | Regex valid (alias) |

## RESILIENCE

| Function | Signature | Returns | Description |
|---|---|---|---|
| BACKOFF_CALCULATE | BACKOFF_CALCULATE(attempt: INT, baseMs: INT, maxMs: INT, [jitter: BOOL]) : INT |  | Calculate backoff delay |
| BULKHEAD_ACQUIRE | BULKHEAD_ACQUIRE(handle: STRING) : BOOL |  | Acquire bulkhead slot |
| BULKHEAD_AVAILABLE | BULKHEAD_AVAILABLE(handle: STRING) : INT |  | Get available slots |
| BULKHEAD_CREATE | BULKHEAD_CREATE([maxConcurrent: INT]) : STRING |  | Create bulkhead, returns handle |
| BULKHEAD_RELEASE | BULKHEAD_RELEASE(handle: STRING) : BOOL |  | Release bulkhead slot |
| BULKHEAD_STATS | BULKHEAD_STATS(handle: STRING) : MAP |  | Get bulkhead stats |
| CACHE_CLEANUP | CACHE_CLEANUP(handle: STRING) : INT |  | Cleanup expired entries |
| CACHE_CLEAR | CACHE_CLEAR(handle: STRING) : BOOL |  | Clear cache |
| CACHE_CREATE | CACHE_CREATE([maxSize: INT], [defaultTTLSeconds: INT]) : STRING |  | Create cache, returns handle |
| CACHE_DELETE | CACHE_DELETE(handle: STRING, key: STRING) : BOOL |  | Delete from cache |
| CACHE_EXPIRE | CACHE_EXPIRE(handle: STRING, key: STRING, ttlSeconds: INT) : BOOL |  | Set expiration on key |
| CACHE_GET | CACHE_GET(handle: STRING, key: STRING, [default: ANY]) : ANY |  | Get from cache |
| CACHE_GET_OR_SET | CACHE_GET_OR_SET(handle: STRING, key: STRING, val: ANY, [ttlSeconds: INT]) : ANY |  | Get or set cache |
| CACHE_HAS | CACHE_HAS(handle: STRING, key: STRING) : BOOL |  | Check if cached |
| CACHE_KEYS | CACHE_KEYS(handle: STRING) : ARRAY |  | Get cache keys |
| CACHE_SET | CACHE_SET(handle: STRING, key: STRING, val: ANY, [ttlSeconds: INT]) : BOOL |  | Set in cache |
| CACHE_SIZE | CACHE_SIZE(handle: STRING) : INT |  | Get cache size |
| CACHE_TTL | CACHE_TTL(handle: STRING, key: STRING) : INT |  | Get entry TTL |
| CIRCUIT_BREAKER_ALLOW | CIRCUIT_BREAKER_ALLOW(handle: STRING) : BOOL |  | Check if allowed |
| CIRCUIT_BREAKER_CREATE | CIRCUIT_BREAKER_CREATE([failureThreshold: INT], [successThreshold: INT], [timeoutSeconds: INT]) : STRING |  | Create circuit breaker, returns handle |
| CIRCUIT_BREAKER_RECORD_FAILURE | CIRCUIT_BREAKER_RECORD_FAILURE(handle: STRING) : BOOL |  | Record failure |
| CIRCUIT_BREAKER_RECORD_SUCCESS | CIRCUIT_BREAKER_RECORD_SUCCESS(handle: STRING) : BOOL |  | Record success |
| CIRCUIT_BREAKER_RESET | CIRCUIT_BREAKER_RESET(handle: STRING) : BOOL |  | Reset breaker |
| CIRCUIT_BREAKER_STATE | CIRCUIT_BREAKER_STATE(handle: STRING) : STRING |  | Get breaker state |
| CIRCUIT_BREAKER_STATS | CIRCUIT_BREAKER_STATS(handle: STRING) : MAP |  | Get breaker stats |
| DEBOUNCE_CALL | DEBOUNCE_CALL(handle: STRING) : BOOL |  | Record a debounced call |
| DEBOUNCE_CREATE | DEBOUNCE_CREATE([delayMs: INT]) : STRING |  | Create debouncer, returns handle |
| DEBOUNCE_READY | DEBOUNCE_READY(handle: STRING) : BOOL |  | Check if debounce period passed |
| FALLBACK | FALLBACK(val: ANY, fallback: ANY) : ANY |  | Return fallback value |
| RATE_LIMITER_ALLOW | RATE_LIMITER_ALLOW(handle: STRING) : BOOL |  | Check if allowed |
| RATE_LIMITER_CREATE | RATE_LIMITER_CREATE([maxRequests: INT], [windowSeconds: INT]) : STRING |  | Create rate limiter, returns handle |
| RATE_LIMITER_REMAINING | RATE_LIMITER_REMAINING(handle: STRING) : INT |  | Get remaining requests |
| RATE_LIMITER_RESET | RATE_LIMITER_RESET(handle: STRING) : BOOL |  | Reset limiter |
| RETRY_CONFIG | RETRY_CONFIG([maxAttempts: INT], [baseDelayMs: INT], [maxDelayMs: INT], [jitter: BOOL]) : MAP |  | Create retry config map |
| THROTTLE_ALLOW | THROTTLE_ALLOW(handle: STRING) : BOOL |  | Check throttle |
| THROTTLE_CREATE | THROTTLE_CREATE([minIntervalMs: INT]) : STRING |  | Create throttle, returns handle |
| THROTTLE_WAIT_TIME | THROTTLE_WAIT_TIME(handle: STRING) : INT |  | Get ms until next allowed call |
| TIMEOUT_CHECK | TIMEOUT_CHECK(startTimeMs: INT, timeoutMs: INT) : BOOL |  | Check if timeout elapsed |
| TIMEOUT_REMAINING | TIMEOUT_REMAINING(startTimeMs: INT, timeoutMs: INT) : INT |  | Get remaining ms |

## RP2040

| Function | Signature | Returns | Description |
|---|---|---|---|
| RP2040_ANALOG_READ | RP2040_ANALOG_READ(name: STRING, pin: INT) : INT |  | Read ADC pin (0-65535). Valid pins: 26, 27, 28, 29 |
| RP2040_BOOTLOADER | RP2040_BOOTLOADER(name: STRING) : BOOL |  | Reboot RP2040 into UF2 bootloader mode for firmware update |
| RP2040_CLOSE | RP2040_CLOSE(name: STRING) : BOOL |  | Disconnect from RP2040 board |
| RP2040_DIGITAL_READ | RP2040_DIGITAL_READ(name: STRING, pin: INT) : BOOL |  | Read digital pin (auto-configures as input) |
| RP2040_DIGITAL_WRITE | RP2040_DIGITAL_WRITE(name: STRING, pin: INT, value: BOOL) : BOOL |  | Write digital pin (auto-configures as output) |
| RP2040_DISTANCE | RP2040_DISTANCE(name: STRING, trigPin: INT, echoPin: INT) : INT |  | Read HC-SR04 ultrasonic distance sensor, returns mm |
| RP2040_I2C_READ_BYTE | RP2040_I2C_READ_BYTE(name: STRING, addr: INT) : INT |  | Read a byte from I2C device (-1 on error) |
| RP2040_I2C_SCAN | RP2040_I2C_SCAN(name: STRING) : STRING |  | Scan I2C bus (GP4=SDA, GP5=SCL), returns comma-separated hex addresses |
| RP2040_I2C_WRITE_BYTE | RP2040_I2C_WRITE_BYTE(name: STRING, addr: INT, value: INT) : BOOL |  | Write a byte to I2C device |
| RP2040_I2C_WRITE_READ | RP2040_I2C_WRITE_READ(name: STRING, addr: INT, reg: INT, readLen: INT) : STRING |  | Write register then read N bytes (comma-separated decimal) |
| RP2040_INIT | RP2040_INIT(name: STRING, port: STRING) : BOOL |  | Connect to RP2040 board on serial port |
| RP2040_NEOPIXEL | RP2040_NEOPIXEL(name: STRING, r: INT, g: INT, b: INT) : BOOL |  | Set onboard NeoPixel color (GP16) |
| RP2040_NEO_STRIP | RP2040_NEO_STRIP(name: STRING, numLeds: INT, hexColors: STRING) : BOOL |  | Send full NeoPixel strip update (up to 64 LEDs on GP16) |
| RP2040_OLED_CLEAR | RP2040_OLED_CLEAR(name: STRING, addr: INT) : BOOL |  | Clear OLED screen |
| RP2040_OLED_INIT | RP2040_OLED_INIT(name: STRING, addr: INT) : BOOL |  | Init SSD1306 OLED on I2C0 (GP4=SDA, GP5=SCL) |
| RP2040_OLED_PRINT | RP2040_OLED_PRINT(name: STRING, addr: INT, row: INT, text: STRING) : BOOL |  | Print text on OLED row (0-7), 21 chars/line, 5x7 font |
| RP2040_PIN_MODE | RP2040_PIN_MODE(name: STRING, pin: INT, mode: INT) : BOOL |  | Set pin mode (0=input, 1=output, 2=input_pullup, 3=pwm, 4=adc) |
| RP2040_PWM_WRITE | RP2040_PWM_WRITE(name: STRING, pin: INT, duty: INT) : BOOL |  | Set PWM duty cycle (0-65535). Valid pins: GP0-GP15 |
| RP2040_RESET_PINS | RP2040_RESET_PINS(name: STRING) : BOOL |  | Release all pins to default state |
| RP2040_SERVO | RP2040_SERVO(name: STRING, pin: INT, angle: INT) : BOOL |  | Set servo angle (0-180) on a pin. Uses 50Hz PWM |
| RP2040_SPI_TRANSFER | RP2040_SPI_TRANSFER(name: STRING, hexData: STRING) : STRING |  | SPI transfer (GP10=SCK, GP11=MOSI, GP12=MISO, GP13=CS). Hex in/out |
| RP2040_STATUS | RP2040_STATUS(name: STRING) : STRING |  | Get board status JSON (ping, board info, connection state) |
| RP2040_TEMP_READ | RP2040_TEMP_READ(name: STRING) : INT |  | Read internal temperature sensor (returns C * 100) |
| RP2040_UART_INIT | RP2040_UART_INIT(name: STRING, channel: INT, baudRate: INT) : BOOL |  | Init UART channel (0=GP0/GP1, 1=GP4/GP5) at baud rate |
| RP2040_UART_RECV | RP2040_UART_RECV(name: STRING, channel: INT, maxLen: INT) : STRING |  | Read up to maxLen bytes from UART channel ring buffer (non-blocking) |
| RP2040_UART_SEND | RP2040_UART_SEND(name: STRING, channel: INT, data: STRING) : BOOL |  | Send string data via UART channel |

## S7

| Function | Signature | Returns | Description |
|---|---|---|---|
| S7_ADD_POLL | S7_ADD_POLL(name: STRING, area: STRING, db: INT, byteAddr: INT, byteCount: INT) : BOOL |  | Register memory range for polling |
| S7_CLIENT_CONNECT | S7_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect S7 client (non-blocking) |
| S7_CLIENT_CREATE | S7_CLIENT_CREATE(name: STRING, host: STRING, rack: INT, slot: INT, [port: INT], [timeout_ms: INT], [poll_rate_ms: INT]) : BOOL |  | Create S7 client |
| S7_CLIENT_DELETE | S7_CLIENT_DELETE(name: STRING) : BOOL |  | Delete S7 client |
| S7_CLIENT_DISCONNECT | S7_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect S7 client |
| S7_CLIENT_GET_STATS | S7_CLIENT_GET_STATS(name: STRING) : MAP |  | Get client statistics |
| S7_CLIENT_IS_CONNECTED | S7_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check connection status |
| S7_CLIENT_LIST | S7_CLIENT_LIST() : ARRAY |  | List S7 clients |
| S7_READ_DB_BOOL | S7_READ_DB_BOOL(name: STRING, db: INT, byteAddr: INT, bit: INT) : BOOL |  | Read single bit from DB |
| S7_READ_DB_BYTE | S7_READ_DB_BYTE(name: STRING, db: INT, byteAddr: INT) : INT |  | Read unsigned byte from DB |
| S7_READ_DB_DINT | S7_READ_DB_DINT(name: STRING, db: INT, byteAddr: INT) : INT |  | Read signed DINT (32-bit) from DB |
| S7_READ_DB_DWORD | S7_READ_DB_DWORD(name: STRING, db: INT, byteAddr: INT) : INT |  | Read unsigned dword (32-bit) from DB |
| S7_READ_DB_INT | S7_READ_DB_INT(name: STRING, db: INT, byteAddr: INT) : INT |  | Read signed INT (16-bit) from DB |
| S7_READ_DB_REAL | S7_READ_DB_REAL(name: STRING, db: INT, byteAddr: INT) : REAL |  | Read REAL (32-bit float) from DB |
| S7_READ_DB_WORD | S7_READ_DB_WORD(name: STRING, db: INT, byteAddr: INT) : INT |  | Read unsigned word (16-bit) from DB |
| S7_READ_I | S7_READ_I(name: STRING, byteAddr: INT, count: INT) : ARRAY |  | Read bytes from Inputs area |
| S7_READ_I_BOOL | S7_READ_I_BOOL(name: STRING, byteAddr: INT, bit: INT) : BOOL |  | Read bit from Inputs |
| S7_READ_M | S7_READ_M(name: STRING, byteAddr: INT, count: INT) : ARRAY |  | Read bytes from Flags/Markers area |
| S7_READ_M_BOOL | S7_READ_M_BOOL(name: STRING, byteAddr: INT, bit: INT) : BOOL |  | Read bit from Flags |
| S7_READ_Q | S7_READ_Q(name: STRING, byteAddr: INT, count: INT) : ARRAY |  | Read bytes from Outputs area |
| S7_READ_Q_BOOL | S7_READ_Q_BOOL(name: STRING, byteAddr: INT, bit: INT) : BOOL |  | Read bit from Outputs |
| S7_SERVER_CREATE | S7_SERVER_CREATE(name: STRING, port: INT) : BOOL |  | Create S7 server (emulator) |
| S7_SERVER_DELETE | S7_SERVER_DELETE(name: STRING) : BOOL |  | Delete S7 server |
| S7_SERVER_GET_DB | S7_SERVER_GET_DB(name: STRING, db: INT, byteAddr: INT) : INT |  | Get byte from server DB |
| S7_SERVER_GET_I | S7_SERVER_GET_I(name: STRING, byteAddr: INT) : INT |  | Get Inputs byte |
| S7_SERVER_GET_M | S7_SERVER_GET_M(name: STRING, byteAddr: INT) : INT |  | Get Flags byte |
| S7_SERVER_GET_Q | S7_SERVER_GET_Q(name: STRING, byteAddr: INT) : INT |  | Get Outputs byte |
| S7_SERVER_IS_RUNNING | S7_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if server running |
| S7_SERVER_LIST | S7_SERVER_LIST() : ARRAY |  | List S7 servers |
| S7_SERVER_SET_DB | S7_SERVER_SET_DB(name: STRING, db: INT, byteAddr: INT, value: INT) : BOOL |  | Set byte in server DB |
| S7_SERVER_SET_I | S7_SERVER_SET_I(name: STRING, byteAddr: INT, value: INT) : BOOL |  | Set Inputs byte |
| S7_SERVER_SET_M | S7_SERVER_SET_M(name: STRING, byteAddr: INT, value: INT) : BOOL |  | Set Flags byte |
| S7_SERVER_SET_Q | S7_SERVER_SET_Q(name: STRING, byteAddr: INT, value: INT) : BOOL |  | Set Outputs byte |
| S7_SERVER_START | S7_SERVER_START(name: STRING) : BOOL |  | Start S7 server |
| S7_SERVER_STOP | S7_SERVER_STOP(name: STRING) : BOOL |  | Stop S7 server |
| S7_WRITE_DB_BOOL | S7_WRITE_DB_BOOL(name: STRING, db: INT, byteAddr: INT, bit: INT, value: BOOL) : BOOL |  | Write single bit to DB |
| S7_WRITE_DB_BYTE | S7_WRITE_DB_BYTE(name: STRING, db: INT, byteAddr: INT, value: INT) : BOOL |  | Write byte to DB |
| S7_WRITE_DB_DINT | S7_WRITE_DB_DINT(name: STRING, db: INT, byteAddr: INT, value: INT) : BOOL |  | Write DINT (32-bit signed) to DB |
| S7_WRITE_DB_DWORD | S7_WRITE_DB_DWORD(name: STRING, db: INT, byteAddr: INT, value: INT) : BOOL |  | Write dword (32-bit) to DB |
| S7_WRITE_DB_INT | S7_WRITE_DB_INT(name: STRING, db: INT, byteAddr: INT, value: INT) : BOOL |  | Write INT (16-bit signed) to DB |
| S7_WRITE_DB_REAL | S7_WRITE_DB_REAL(name: STRING, db: INT, byteAddr: INT, value: REAL) : BOOL |  | Write REAL (32-bit float) to DB |
| S7_WRITE_DB_WORD | S7_WRITE_DB_WORD(name: STRING, db: INT, byteAddr: INT, value: INT) : BOOL |  | Write word (16-bit) to DB |
| S7_WRITE_M | S7_WRITE_M(name: STRING, byteAddr: INT, values: ARRAY) : BOOL |  | Write bytes to Flags area |
| S7_WRITE_M_BOOL | S7_WRITE_M_BOOL(name: STRING, byteAddr: INT, bit: INT, value: BOOL) : BOOL |  | Write bit to Flags |
| S7_WRITE_Q | S7_WRITE_Q(name: STRING, byteAddr: INT, values: ARRAY) : BOOL |  | Write bytes to Outputs area |
| S7_WRITE_Q_BOOL | S7_WRITE_Q_BOOL(name: STRING, byteAddr: INT, bit: INT, value: BOOL) : BOOL |  | Write bit to Outputs |

## SACN

| Function | Signature | Returns | Description |
|---|---|---|---|
| SACN_BLACKOUT | SACN_BLACKOUT(handle: HANDLE) : HANDLE |  | Set all channels to 0 |
| SACN_CREATE_UNIVERSE | SACN_CREATE_UNIVERSE(name: STRING, universe: INT) : HANDLE |  | Create sACN universe buffer |
| SACN_SEND | SACN_SEND(host: STRING, universe: INT, ch1: INT, ...) : BOOL |  | Send raw DMX channels via sACN/E1.31 |
| SACN_SEND_UNIVERSE | SACN_SEND_UNIVERSE(host: STRING, handle: HANDLE) : BOOL |  | Send universe buffer (empty host = multicast) |
| SACN_SET_CHANNEL | SACN_SET_CHANNEL(handle: HANDLE, channel: INT, value: INT) : HANDLE |  | Set DMX channel value |
| SACN_SET_PRIORITY | SACN_SET_PRIORITY(handle: HANDLE, priority: INT) : HANDLE |  | Set sACN priority (0-200, default 100) |
| SACN_SET_RGB | SACN_SET_RGB(handle: HANDLE, start_ch: INT, r: INT, g: INT, b: INT) : HANDLE |  | Set 3 consecutive channels for RGB |

## SCALE

| Function | Signature | Returns | Description |
|---|---|---|---|
| SCALE_GET_STATUS | SCALE_GET_STATUS(handle: HANDLE) : STRING |  | Get status (stable, unstable, overload, etc.) |
| SCALE_GET_UNIT | SCALE_GET_UNIT(handle: HANDLE) : STRING |  | Get weight unit (kg, g, lb, oz, etc.) |
| SCALE_GET_WEIGHT | SCALE_GET_WEIGHT(handle: HANDLE) : REAL |  | Get weight value |
| SCALE_IS_NET | SCALE_IS_NET(handle: HANDLE) : BOOL |  | Check if net weight (vs gross) |
| SCALE_IS_STABLE | SCALE_IS_STABLE(handle: HANDLE) : BOOL |  | Check if reading is stable |
| SCALE_PARSE | SCALE_PARSE(raw: STRING) : HANDLE |  | Auto-detect and parse weigh scale protocol |
| SCALE_PARSE_MT_SICS | SCALE_PARSE_MT_SICS(raw: STRING) : HANDLE |  | Parse Mettler-Toledo SICS protocol |
| SCALE_PARSE_OHAUS | SCALE_PARSE_OHAUS(raw: STRING) : HANDLE |  | Parse Ohaus protocol |

## SCALING

| Function | Signature | Returns | Description |
|---|---|---|---|
| SCALEANALOGINPUT | SCALEANALOGINPUT(raw: INT, rawLow: INT, rawHigh: INT, engLow: REAL, engHigh: REAL) : REAL |  | Scale analog input |
| SCALEANALOGOUTPUT | SCALEANALOGOUTPUT(eng: REAL, engLow: REAL, engHigh: REAL, rawLow: INT, rawHigh: INT) : INT |  | Scale analog output |
| SCALEOUTPUT | SCALEOUTPUT(val: REAL, inLow: REAL, inHigh: REAL, outLow: REAL, outHigh: REAL) : REAL |  | Scale output value |
| SCALE_AI | SCALE_AI(raw: INT, rawLow: INT, rawHigh: INT, engLow: REAL, engHigh: REAL) : REAL |  | Scale analog input (short) |
| SCALE_AO | SCALE_AO(eng: REAL, engLow: REAL, engHigh: REAL, rawLow: INT, rawHigh: INT) : INT |  | Scale analog output (short) |
| SCL | SCL(val: REAL, inLow: REAL, inHigh: REAL, outLow: REAL, outHigh: REAL) : REAL |  | Linear scaling |

## SEL

| Function | Signature | Returns | Description |
|---|---|---|---|
| SEL_CLIENT_CLEAR_SER | SEL_CLIENT_CLEAR_SER(name: STRING) : BOOL |  | Clear SER buffer |
| SEL_CLIENT_CONNECT | SEL_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect SEL client |
| SEL_CLIENT_CREATE | SEL_CLIENT_CREATE(name: STRING, port: STRING, [baud: INT]) : BOOL |  | Create SEL client |
| SEL_CLIENT_DELETE | SEL_CLIENT_DELETE(name: STRING) : BOOL |  | Delete SEL client |
| SEL_CLIENT_DISCONNECT | SEL_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect SEL client |
| SEL_CLIENT_EXPORT_COMTRADE | SEL_CLIENT_EXPORT_COMTRADE(name: STRING, event: INT) : MAP |  | Export COMTRADE format |
| SEL_CLIENT_GET_ACCESS_LEVEL | SEL_CLIENT_GET_ACCESS_LEVEL(name: STRING) : INT |  | Get current access level |
| SEL_CLIENT_GET_ACTIVE_GROUP | SEL_CLIENT_GET_ACTIVE_GROUP(name: STRING) : INT |  | Get active settings group |
| SEL_CLIENT_GET_DEVICE_ID | SEL_CLIENT_GET_DEVICE_ID(name: STRING) : STRING |  | Get device ID |
| SEL_CLIENT_GET_DEVICE_TYPE | SEL_CLIENT_GET_DEVICE_TYPE(name: STRING) : STRING |  | Get device type |
| SEL_CLIENT_GET_LOCAL_BIT | SEL_CLIENT_GET_LOCAL_BIT(name: STRING, bit: INT) : BOOL |  | Get local mirrored bit |
| SEL_CLIENT_GET_LOCAL_BITS | SEL_CLIENT_GET_LOCAL_BITS(name: STRING) : INT |  | Get all local bits |
| SEL_CLIENT_GET_METERING | SEL_CLIENT_GET_METERING(name: STRING) : MAP |  | Get metering data |
| SEL_CLIENT_GET_OSCILLOGRAPHY_COUNT | SEL_CLIENT_GET_OSCILLOGRAPHY_COUNT(name: STRING) : INT |  | Get oscillography record count |
| SEL_CLIENT_GET_REMOTE_BIT | SEL_CLIENT_GET_REMOTE_BIT(name: STRING, bit: INT) : BOOL |  | Get remote mirrored bit |
| SEL_CLIENT_GET_REMOTE_BITS | SEL_CLIENT_GET_REMOTE_BITS(name: STRING) : INT |  | Get all remote bits as INT |
| SEL_CLIENT_GET_SER_COUNT | SEL_CLIENT_GET_SER_COUNT(name: STRING) : INT |  | Get SER entry count |
| SEL_CLIENT_GET_STATUS | SEL_CLIENT_GET_STATUS(name: STRING) : MAP |  | Get status word |
| SEL_CLIENT_IS_CONNECTED | SEL_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check connection status |
| SEL_CLIENT_LIST | SEL_CLIENT_LIST() : ARRAY |  | List SEL clients |
| SEL_CLIENT_READ_OSCILLOGRAPHY | SEL_CLIENT_READ_OSCILLOGRAPHY(name: STRING, event: INT) : MAP |  | Read oscillography |
| SEL_CLIENT_READ_SER | SEL_CLIENT_READ_SER(name: STRING, count: INT) : ARRAY |  | Read SER events |
| SEL_CLIENT_READ_SETTING | SEL_CLIENT_READ_SETTING(name: STRING, setting: STRING) : STRING |  | Read setting value |
| SEL_CLIENT_SEND_COMMAND | SEL_CLIENT_SEND_COMMAND(name: STRING, cmd: STRING) : STRING |  | Send ASCII command |
| SEL_CLIENT_SET_LOCAL_BIT | SEL_CLIENT_SET_LOCAL_BIT(name: STRING, bit: INT, val: BOOL) : BOOL |  | Set local mirrored bit |
| SEL_CLIENT_SET_LOCAL_BITS | SEL_CLIENT_SET_LOCAL_BITS(name: STRING, bits: INT) : BOOL |  | Set all local bits |
| SEL_CLIENT_START_MIRRORED_BITS | SEL_CLIENT_START_MIRRORED_BITS(name: STRING) : BOOL |  | Start Mirrored Bits exchange |
| SEL_CLIENT_STOP_MIRRORED_BITS | SEL_CLIENT_STOP_MIRRORED_BITS(name: STRING) : BOOL |  | Stop Mirrored Bits |
| SEL_CLIENT_SWITCH_GROUP | SEL_CLIENT_SWITCH_GROUP(name: STRING, group: INT) : BOOL |  | Switch settings group |
| SEL_CLIENT_WRITE_SETTING | SEL_CLIENT_WRITE_SETTING(name: STRING, setting: STRING, value: STRING) : BOOL |  | Write setting value |
| SEL_METER_CREATE | SEL_METER_CREATE(name: STRING, port: INT, [device_type: STRING], [serial: STRING]) : BOOL |  | Create TCP SEL meter server |
| SEL_METER_DELETE | SEL_METER_DELETE(name: STRING) : BOOL |  | Stop and remove meter server |
| SEL_METER_IS_RUNNING | SEL_METER_IS_RUNNING(name: STRING) : BOOL |  | Check if meter server is active |
| SEL_METER_SET_CURRENT | SEL_METER_SET_CURRENT(name: STRING, ia: REAL, ib: REAL, ic: REAL, in_: REAL) : BOOL |  | Set 3-phase currents |
| SEL_METER_SET_DEMAND | SEL_METER_SET_DEMAND(name: STRING, kw: REAL) : BOOL |  | Set 15-min demand (kW) |
| SEL_METER_SET_ENERGY | SEL_METER_SET_ENERGY(name: STRING, fwdKWh: REAL, revKWh: REAL, fwdKVARh: REAL) : BOOL |  | Set energy counters |
| SEL_METER_SET_FREQ | SEL_METER_SET_FREQ(name: STRING, freq: REAL) : BOOL |  | Set frequency (Hz) |
| SEL_METER_SET_POWER | SEL_METER_SET_POWER(name: STRING, kw: REAL, kvar: REAL, kva: REAL, pf: REAL) : BOOL |  | Set power and power factor |
| SEL_METER_SET_THD | SEL_METER_SET_THD(name: STRING, thdV: REAL, thdI: REAL) : BOOL |  | Set THD percentages |
| SEL_METER_SET_VOLTAGE | SEL_METER_SET_VOLTAGE(name: STRING, va: REAL, vb: REAL, vc: REAL) : BOOL |  | Set 3-phase voltages |
| SEL_METER_START | SEL_METER_START(name: STRING) : BOOL |  | Start TCP meter server |
| SEL_METER_STOP | SEL_METER_STOP(name: STRING) : BOOL |  | Stop TCP meter server |
| SEL_SERVER_CREATE | SEL_SERVER_CREATE(name: STRING, portName: STRING, [baud: INT]) : BOOL |  | Create SEL server (emulator) |
| SEL_SERVER_DELETE | SEL_SERVER_DELETE(name: STRING) : BOOL |  | Stop and remove server |
| SEL_SERVER_GET_REMOTE_BIT | SEL_SERVER_GET_REMOTE_BIT(name: STRING, bit: INT) : BOOL |  | Get remote mirrored bit |
| SEL_SERVER_IS_RUNNING | SEL_SERVER_IS_RUNNING(name: STRING) : BOOL |  | Check if server is running |
| SEL_SERVER_LIST | SEL_SERVER_LIST() : ARRAY |  | List all SEL servers |
| SEL_SERVER_SET_LOCAL_BIT | SEL_SERVER_SET_LOCAL_BIT(name: STRING, bit: INT, value: BOOL) : BOOL |  | Set local mirrored bit |
| SEL_SERVER_SET_METERING | SEL_SERVER_SET_METERING(name: STRING, va: REAL, vb: REAL, vc: REAL, ia: REAL, ib: REAL, ic: REAL) : BOOL |  | Set metering values |
| SEL_SERVER_SET_STATUS | SEL_SERVER_SET_STATUS(name: STRING, word: INT, trip: BOOL, close: BOOL, alarm: BOOL, fault: BOOL, inService: BOOL) : BOOL |  | Set status word |
| SEL_SERVER_START | SEL_SERVER_START(name: STRING) : BOOL |  | Start SEL server |
| SEL_SERVER_START_MIRRORED_BITS | SEL_SERVER_START_MIRRORED_BITS(name: STRING) : BOOL |  | Start mirrored bits exchange |
| SEL_SERVER_STOP | SEL_SERVER_STOP(name: STRING) : BOOL |  | Stop SEL server |
| SEL_SERVER_STOP_MIRRORED_BITS | SEL_SERVER_STOP_MIRRORED_BITS(name: STRING) : BOOL |  | Stop mirrored bits exchange |

## SELECTION

| Function | Signature | Returns | Description |
|---|---|---|---|
| AVG | AVG(values: ANY_NUM...) : REAL |  | Average of values |
| BETWEEN | BETWEEN(val: ANY_NUM, min: ANY_NUM, max: ANY_NUM) : BOOL |  | Check if value in range |
| CLAMP | CLAMP(val: ANY_NUM, min: ANY_NUM, max: ANY_NUM) : ANY_NUM |  | Clamp value to range |
| LIMIT | LIMIT(min: ANY_NUM, val: ANY_NUM, max: ANY_NUM) : ANY_NUM |  | Limit value to range |
| MAX | MAX(a: ANY_NUM, b: ANY_NUM, ...) : ANY_NUM |  | Maximum of values |
| MIN | MIN(a: ANY_NUM, b: ANY_NUM, ...) : ANY_NUM |  | Minimum of values |
| MUX | MUX(idx: INT, val0: ANY, val1: ANY, ...) : ANY |  | Multiplexer |
| SEL | SEL(cond: BOOL, false_val: ANY, true_val: ANY) : ANY |  | Binary selection |
| SUM | SUM(values: ANY_NUM...) : ANY_NUM |  | Sum of values |

## SERIAL

| Function | Signature | Returns | Description |
|---|---|---|---|
| SERIAL_FIND | SERIAL_FIND(search: STRING) : STRING |  | Find serial port by vendor/product/driver name (case-insensitive substring match) |
| SERIAL_PORTS | SERIAL_PORTS() : STRING |  | List all serial ports with device info (vendor, product, serial, driver) |
| SERIAL_PORT_INFO | SERIAL_PORT_INFO(port: STRING) : STRING |  | Get device info for a specific serial port |
| SER_CLOSE | SER_CLOSE(port: STRING) : BOOL |  | Close serial port |
| SER_CLOSE_ALL | SER_CLOSE_ALL() : INT |  | Close all ports |
| SER_FLUSH | SER_FLUSH(port: STRING) : BOOL |  | Flush buffers |
| SER_IS_OPEN | SER_IS_OPEN(port: STRING) : BOOL |  | Check if open |
| SER_LIST | SER_LIST() : ARRAY |  | List ports |
| SER_MODEM_STATUS | SER_MODEM_STATUS(port: STRING) : MAP |  | Get modem status |
| SER_MODEM_STATUS | SER_MODEM_STATUS(port: STRING) : INT |  | Get modem status flags |
| SER_OPEN | SER_OPEN(port: STRING, baud: INT, [databits: INT, parity: STRING, stopbits: INT]) : STRING |  | Open serial port |
| SER_READ | SER_READ(port: STRING, count: INT) : ARRAY |  | Read bytes |
| SER_READ_LINE | SER_READ_LINE(port: STRING) : STRING |  | Read until newline |
| SER_READ_STR | SER_READ_STR(port: STRING) : STRING |  | Read string from serial port |
| SER_READ_STR | SER_READ_STR(port: STRING, count: INT) : STRING |  | Read as string |
| SER_SET_DTR | SER_SET_DTR(port: STRING, state: BOOL) : BOOL |  | Set DTR line |
| SER_SET_RTS | SER_SET_RTS(port: STRING, state: BOOL) : BOOL |  | Set RTS line |
| SER_WRITE | SER_WRITE(port: STRING, data: ARRAY) : INT |  | Write bytes |
| SER_WRITE_STR | SER_WRITE_STR(port: STRING, data: STRING) : INT |  | Write string |
| SER_WRITE_STR | SER_WRITE_STR(port: STRING, str: STRING) : BOOL |  | Write string to serial port |

## SMTP

| Function | Signature | Returns | Description |
|---|---|---|---|
| SMTP_SEND | SMTP_SEND(host: STRING, from: STRING, to: STRING, subject: STRING, body: STRING) : BOOL |  | Send plain text email (no auth) |
| SMTP_SEND_AUTH | SMTP_SEND_AUTH(host: STRING, user: STRING, pass: STRING, from: STRING, to: STRING, subject: STRING, body: STRING) : BOOL |  | Send email with PLAIN authentication |
| SMTP_SEND_HTML | SMTP_SEND_HTML(host: STRING, from: STRING, to: STRING, subject: STRING, html_body: STRING) : BOOL |  | Send HTML email (no auth) |
| SMTP_SEND_TLS | SMTP_SEND_TLS(host: STRING, user: STRING, pass: STRING, from: STRING, to: STRING, subject: STRING, body: STRING) : BOOL |  | Send email with implicit TLS (port 465) |

## SNMP

| Function | Signature | Returns | Description |
|---|---|---|---|
| SNMP_AGENT_CREATE | SNMP_AGENT_CREATE(name: STRING, port: INT, [community: STRING], [sysDescr: STRING], [sysName: STRING]) : BOOL |  | Create SNMP agent (server) |
| SNMP_AGENT_DELETE | SNMP_AGENT_DELETE(name: STRING) : BOOL |  | Delete and stop agent |
| SNMP_AGENT_GET_INT | SNMP_AGENT_GET_INT(name: STRING, oid: STRING) : INT |  | Read back INTEGER OID value |
| SNMP_AGENT_IS_RUNNING | SNMP_AGENT_IS_RUNNING(name: STRING) : BOOL |  | Check if agent is running |
| SNMP_AGENT_LIST | SNMP_AGENT_LIST() : ARRAY |  | List all agents |
| SNMP_AGENT_SET_COUNTER | SNMP_AGENT_SET_COUNTER(name: STRING, oid: STRING, value: DWORD) : BOOL |  | Set OID to Counter32 value |
| SNMP_AGENT_SET_GAUGE | SNMP_AGENT_SET_GAUGE(name: STRING, oid: STRING, value: DWORD) : BOOL |  | Set OID to Gauge32 value |
| SNMP_AGENT_SET_INT | SNMP_AGENT_SET_INT(name: STRING, oid: STRING, value: INT) : BOOL |  | Set OID to INTEGER value |
| SNMP_AGENT_SET_STR | SNMP_AGENT_SET_STR(name: STRING, oid: STRING, value: STRING) : BOOL |  | Set OID to OctetString value |
| SNMP_AGENT_START | SNMP_AGENT_START(name: STRING) : BOOL |  | Start SNMP agent listener |
| SNMP_AGENT_STOP | SNMP_AGENT_STOP(name: STRING) : BOOL |  | Stop SNMP agent |
| SNMP_CLIENT_CONNECT | SNMP_CLIENT_CONNECT(name: STRING) : BOOL |  | Connect to SNMP agent |
| SNMP_CLIENT_CREATE | SNMP_CLIENT_CREATE(name: STRING, host: STRING, [port: INT], [community: STRING], [version: INT]) : BOOL |  | Create SNMP v1/v2c client |
| SNMP_CLIENT_CREATE_V3 | SNMP_CLIENT_CREATE_V3(name: STRING, host: STRING, user: STRING, authProto: INT, authPass: STRING, privProto: INT, privPass: STRING) : BOOL |  | Create SNMPv3 client with auth/privacy |
| SNMP_CLIENT_DELETE | SNMP_CLIENT_DELETE(name: STRING) : BOOL |  | Remove and disconnect client |
| SNMP_CLIENT_DISCONNECT | SNMP_CLIENT_DISCONNECT(name: STRING) : BOOL |  | Disconnect from agent |
| SNMP_CLIENT_GET_STATS | SNMP_CLIENT_GET_STATS(name: STRING) : MAP |  | Get client statistics |
| SNMP_CLIENT_IS_CONNECTED | SNMP_CLIENT_IS_CONNECTED(name: STRING) : BOOL |  | Check if connected |
| SNMP_CLIENT_LIST | SNMP_CLIENT_LIST() : ARRAY |  | List all SNMP clients |
| SNMP_GET | SNMP_GET(name: STRING, oid: STRING) : ANY |  | Get single OID value |
| SNMP_GET_MULTIPLE | SNMP_GET_MULTIPLE(name: STRING, oids: ARRAY) : MAP |  | Get multiple OID values |
| SNMP_GET_NEXT | SNMP_GET_NEXT(name: STRING, oid: STRING) : MAP |  | Get next OID after given OID |
| SNMP_GET_SYS_CONTACT | SNMP_GET_SYS_CONTACT(name: STRING) : STRING |  | Get sysContact (1.3.6.1.2.1.1.4.0) |
| SNMP_GET_SYS_DESCR | SNMP_GET_SYS_DESCR(name: STRING) : STRING |  | Get sysDescr (1.3.6.1.2.1.1.1.0) |
| SNMP_GET_SYS_LOCATION | SNMP_GET_SYS_LOCATION(name: STRING) : STRING |  | Get sysLocation (1.3.6.1.2.1.1.6.0) |
| SNMP_GET_SYS_NAME | SNMP_GET_SYS_NAME(name: STRING) : STRING |  | Get sysName (1.3.6.1.2.1.1.5.0) |
| SNMP_GET_SYS_UPTIME | SNMP_GET_SYS_UPTIME(name: STRING) : INT |  | Get sysUpTime in seconds |
| SNMP_OID_IF_NUMBER | SNMP_OID_IF_NUMBER() : STRING |  | ifNumber OID constant |
| SNMP_OID_IF_TABLE | SNMP_OID_IF_TABLE() : STRING |  | ifTable OID prefix constant |
| SNMP_OID_SYS_CONTACT | SNMP_OID_SYS_CONTACT() : STRING |  | sysContact OID constant |
| SNMP_OID_SYS_DESCR | SNMP_OID_SYS_DESCR() : STRING |  | sysDescr OID constant |
| SNMP_OID_SYS_LOCATION | SNMP_OID_SYS_LOCATION() : STRING |  | sysLocation OID constant |
| SNMP_OID_SYS_NAME | SNMP_OID_SYS_NAME() : STRING |  | sysName OID constant |
| SNMP_OID_SYS_OBJECT_ID | SNMP_OID_SYS_OBJECT_ID() : STRING |  | sysObjectID OID constant |
| SNMP_OID_SYS_UPTIME | SNMP_OID_SYS_UPTIME() : STRING |  | sysUpTime OID constant |
| SNMP_OID_UPS_BATTERY_STATUS | SNMP_OID_UPS_BATTERY_STATUS() : STRING |  | UPS battery status OID |
| SNMP_OID_UPS_INPUT_VOLTAGE | SNMP_OID_UPS_INPUT_VOLTAGE() : STRING |  | UPS input voltage OID prefix |
| SNMP_OID_UPS_OUTPUT_LOAD | SNMP_OID_UPS_OUTPUT_LOAD() : STRING |  | UPS output load OID prefix |
| SNMP_SET | SNMP_SET(name: STRING, oid: STRING, valueType: STRING, value: ANY) : BOOL |  | Set OID to value |
| SNMP_TRAP_CLEAR_BUFFER | SNMP_TRAP_CLEAR_BUFFER() : BOOL |  | Clear trap buffer |
| SNMP_TRAP_GET_BUFFER | SNMP_TRAP_GET_BUFFER() : ARRAY |  | Get buffered traps and clear |
| SNMP_TRAP_GET_COUNT | SNMP_TRAP_GET_COUNT() : INT |  | Get number of traps in buffer |
| SNMP_TRAP_GET_STATS | SNMP_TRAP_GET_STATS(name: STRING) : MAP |  | Get trap receiver statistics |
| SNMP_TRAP_IS_RUNNING | SNMP_TRAP_IS_RUNNING(name: STRING) : BOOL |  | Check if trap receiver is running |
| SNMP_TRAP_START | SNMP_TRAP_START(name: STRING, port: INT, [communities: ARRAY]) : BOOL |  | Start trap receiver on port |
| SNMP_TRAP_STOP | SNMP_TRAP_STOP(name: STRING) : BOOL |  | Stop trap receiver |
| SNMP_WALK | SNMP_WALK(name: STRING, rootOid: STRING) : ARRAY |  | Walk OID tree from root |

## SPARKPLUG

| Function | Signature | Returns | Description |
|---|---|---|---|
| SPARKPLUG_CMD_CLEAR | SPARKPLUG_CMD_CLEAR(name: STRING, metricName: STRING) : BOOL |  | Mark command as handled so SPARKPLUG_CMD_HAS returns FALSE |
| SPARKPLUG_CMD_GET | SPARKPLUG_CMD_GET(name: STRING, metricName: STRING) : ANY |  | Get received command value (any type) |
| SPARKPLUG_CMD_GET_BOOL | SPARKPLUG_CMD_GET_BOOL(name: STRING, metricName: STRING) : BOOL |  | Get received command value as BOOL |
| SPARKPLUG_CMD_GET_INT | SPARKPLUG_CMD_GET_INT(name: STRING, metricName: STRING) : INT |  | Get received command value as INT |
| SPARKPLUG_CMD_GET_REAL | SPARKPLUG_CMD_GET_REAL(name: STRING, metricName: STRING) : REAL |  | Get received command value as REAL |
| SPARKPLUG_CMD_GET_STR | SPARKPLUG_CMD_GET_STR(name: STRING, metricName: STRING) : STRING |  | Get received command value as STRING |
| SPARKPLUG_CMD_HAS | SPARKPLUG_CMD_HAS(name: STRING, metricName: STRING) : BOOL |  | Check if a command metric has been received and not yet cleared |
| SPARKPLUG_CMD_SUBSCRIBE | SPARKPLUG_CMD_SUBSCRIBE(name: STRING) : BOOL |  | Subscribe to NCMD messages for this edge node. Call after connecting. |
| SPARKPLUG_GET_SEQ | SPARKPLUG_GET_SEQ(name: STRING) : INT |  | Get current message sequence number (0–255, wraps per spec) |
| SPARKPLUG_METRIC_ADD | SPARKPLUG_METRIC_ADD(name: STRING, metricName: STRING, initialValue: ANY) : BOOL |  | Register a metric — data type inferred from initial value. Call before SPARKPLUG_NODE_BIRTH. |
| SPARKPLUG_METRIC_GET | SPARKPLUG_METRIC_GET(name: STRING, metricName: STRING) : ANY |  | Get current metric value (any type) |
| SPARKPLUG_METRIC_GET_BOOL | SPARKPLUG_METRIC_GET_BOOL(name: STRING, metricName: STRING) : BOOL |  | Get metric value as BOOL |
| SPARKPLUG_METRIC_GET_INT | SPARKPLUG_METRIC_GET_INT(name: STRING, metricName: STRING) : INT |  | Get metric value as INT |
| SPARKPLUG_METRIC_GET_REAL | SPARKPLUG_METRIC_GET_REAL(name: STRING, metricName: STRING) : REAL |  | Get metric value as REAL |
| SPARKPLUG_METRIC_GET_STR | SPARKPLUG_METRIC_GET_STR(name: STRING, metricName: STRING) : STRING |  | Get metric value as STRING |
| SPARKPLUG_METRIC_SET | SPARKPLUG_METRIC_SET(name: STRING, metricName: STRING, value: ANY) : BOOL |  | Update a metric value and mark it dirty for next NDATA |
| SPARKPLUG_NODE_BIRTH | SPARKPLUG_NODE_BIRTH(name: STRING) : BOOL |  | Send NBIRTH with all registered metrics. Resets seq to 0. Call after connecting. |
| SPARKPLUG_NODE_CONNECT | SPARKPLUG_NODE_CONNECT(name: STRING) : BOOL |  | Connect edge node to MQTT broker |
| SPARKPLUG_NODE_CREATE | SPARKPLUG_NODE_CREATE(name: STRING, groupID: STRING, edgeNodeID: STRING, brokerURL: STRING, clientID: STRING) : BOOL |  | Create Sparkplug B edge node with NDEATH LWT pre-configured |
| SPARKPLUG_NODE_CREATE_AUTH | SPARKPLUG_NODE_CREATE_AUTH(name: STRING, groupID: STRING, edgeNodeID: STRING, brokerURL: STRING, clientID: STRING, username: STRING, password: STRING) : BOOL |  | Create Sparkplug B edge node with MQTT username/password authentication |
| SPARKPLUG_NODE_DATA | SPARKPLUG_NODE_DATA(name: STRING) : BOOL |  | Send NDATA with only changed metrics since last NBIRTH/NDATA. Returns FALSE if nothing changed. |
| SPARKPLUG_NODE_DEATH | SPARKPLUG_NODE_DEATH(name: STRING) : BOOL |  | Send NDEATH manually (also sent automatically as LWT on ungraceful disconnect) |
| SPARKPLUG_NODE_DELETE | SPARKPLUG_NODE_DELETE(name: STRING) : BOOL |  | Delete edge node and free resources |
| SPARKPLUG_NODE_DISCONNECT | SPARKPLUG_NODE_DISCONNECT(name: STRING) : BOOL |  | Send NDEATH then disconnect from broker |
| SPARKPLUG_NODE_IS_CONNECTED | SPARKPLUG_NODE_IS_CONNECTED(name: STRING) : BOOL |  | Check if edge node is connected to broker |
| SPARKPLUG_NODE_LIST | SPARKPLUG_NODE_LIST() : STRING |  | List all edge node names (comma-separated) |

## SPECIAL

| Function | Signature | Returns | Description |
|---|---|---|---|
| HALT | HALT() : BOOL |  | Halt program execution |

## STATISTICS

| Function | Signature | Returns | Description |
|---|---|---|---|
| CORRELATION | CORRELATION(x: ARRAY, y: ARRAY) : REAL |  | Correlation coefficient |
| COVARIANCE | COVARIANCE(x: ARRAY, y: ARRAY) : REAL |  | Covariance of two datasets |
| DERIVATIVE | DERIVATIVE(val: REAL, dt: REAL) : REAL |  | Calculate derivative |
| EMA | EMA(val: REAL, alpha: REAL) : REAL |  | Exponential moving average |
| INTEGRATE | INTEGRATE(val: REAL, dt: REAL) : REAL |  | Integrate value over time |
| MEAN | MEAN(values: ARRAY) : REAL |  | Arithmetic mean |
| MEDIAN | MEDIAN(values: ARRAY) : REAL |  | Median value |
| MODE | MODE(values: ARRAY) : ANY |  | Most frequent value |
| MOVING_AVG | MOVING_AVG(val: REAL, n: INT) : REAL |  | Moving average |
| PERCENTILE | PERCENTILE(values: ARRAY, pct: REAL) : REAL |  | Percentile value |
| PRODUCT | PRODUCT(values: ARRAY) : REAL |  | Product of array |
| SMA | SMA(val: REAL, period: INT) : REAL |  | Simple moving average |
| STDDEV | STDDEV(values: ARRAY) : REAL |  | Standard deviation |
| VARIANCE | VARIANCE(values: ARRAY) : REAL |  | Variance |

## STOREFORWARD

| Function | Signature | Returns | Description |
|---|---|---|---|
| SF_CLEAR | SF_CLEAR() : BOOL |  | Clear all pending messages |
| SF_CLOSE | SF_CLOSE() : BOOL |  | Close store-forward subsystem |
| SF_COUNT | SF_COUNT() : INT |  | Get pending message count |
| SF_FORWARD | SF_FORWARD(url: STRING) : INT |  | Forward to HTTP endpoint |
| SF_GET_PENDING | SF_GET_PENDING(limit: INT) : STRING |  | Get pending messages |
| SF_INIT | SF_INIT(db_path: STRING, max_msgs: INT, max_age_sec: INT) : BOOL |  | Initialize store-forward |
| SF_ONLINE | SF_ONLINE([online: BOOL]) : BOOL |  | Get/set online state |
| SF_STATS | SF_STATS() : STRING |  | Get statistics |
| SF_STORE | SF_STORE(topic: STRING, priority: INT, payload: STRING) : INT |  | Store message |
| SF_STORE_JSON | SF_STORE_JSON(topic: STRING, priority: INT, json: STRING) : INT |  | Store JSON payload |

## STRING

| Function | Signature | Returns | Description |
|---|---|---|---|
| ASCII | ASCII(s: STRING) : INT |  | Get ASCII value of character |
| CHAR | CHAR(code: INT) : STRING |  | Character from ASCII value |
| CHR | CHR(code: INT) : STRING |  | Character from code point |
| CONCAT | CONCAT(s1: STRING, s2: STRING, ...) : STRING |  | Concatenate strings |
| CONTAINS | CONTAINS(s: STRING, sub: STRING) : BOOL |  | Check if contains substring |
| COUNT | COUNT(s: STRING, sub: STRING) : INT |  | Count occurrences of substring |
| DELETE | DELETE(s: STRING, pos: INT, len: INT) : STRING |  | Delete characters from string |
| ENDSWITH | ENDSWITH(str: STRING, suffix: STRING) : BOOL |  | Check if string ends with |
| ENDS_WITH | ENDS_WITH(str: STRING, suffix: STRING) : BOOL |  | Check if string ends with suffix |
| FIND | FIND(haystack: STRING, needle: STRING) : INT |  | Find substring position |
| FORMAT | FORMAT(fmt: STRING, args: ANY...) : STRING |  | Format string with values |
| INDEX_OF | INDEX_OF(str: STRING, search: STRING) : INT |  | Find index of substring |
| INSERT | INSERT(s: STRING, pos: INT, insert: STRING) : STRING |  | Insert string at position |
| LEFT | LEFT(s: STRING, n: INT) : STRING |  | Left substring |
| LEN | LEN(s: STRING) : INT |  | String length |
| LOWER | LOWER(s: STRING) : STRING |  | Convert to lowercase |
| LPAD | LPAD(str: STRING, len: INT, pad: STRING) : STRING |  | Left pad string |
| LTRIM | LTRIM(s: STRING) : STRING |  | Trim left whitespace |
| MID | MID(s: STRING, pos: INT, len: INT) : STRING |  | Middle substring |
| ORD | ORD(s: STRING) : INT |  | Unicode code point of character |
| PADLEFT | PADLEFT(str: STRING, len: INT, pad: STRING) : STRING |  | Pad left (alias) |
| PADRIGHT | PADRIGHT(str: STRING, len: INT, pad: STRING) : STRING |  | Pad right (alias) |
| PAD_LEFT | PAD_LEFT(str: STRING, length: INT, pad_char: STRING) : STRING |  | Pad string on left |
| PAD_RIGHT | PAD_RIGHT(str: STRING, length: INT, pad_char: STRING) : STRING |  | Pad string on right |
| REPEAT | REPEAT(str: STRING, n: INT) : STRING |  | Repeat string n times |
| REPLACE | REPLACE(s: STRING, old: STRING, new: STRING) : STRING |  | Replace first occurrence |
| REPLACE_ALL | REPLACE_ALL(s: STRING, old: STRING, new: STRING) : STRING |  | Replace all occurrences |
| REPLICATE | REPLICATE(str: STRING, count: INT) : STRING |  | Replicate string |
| REVERSE | REVERSE(s: STRING) : STRING |  | Reverse string |
| RIGHT | RIGHT(s: STRING, n: INT) : STRING |  | Right substring |
| RPAD | RPAD(str: STRING, len: INT, pad: STRING) : STRING |  | Right pad string |
| RTRIM | RTRIM(s: STRING) : STRING |  | Trim right whitespace |
| SPLIT | SPLIT(s: STRING, delim: STRING) : ARRAY OF STRING |  | Split string by delimiter |
| STARTSWITH | STARTSWITH(str: STRING, prefix: STRING) : BOOL |  | Check if string starts with |
| STARTS_WITH | STARTS_WITH(str: STRING, prefix: STRING) : BOOL |  | Check if string starts with prefix |
| TRIM | TRIM(s: STRING) : STRING |  | Trim whitespace |
| UPPER | UPPER(s: STRING) : STRING |  | Convert to uppercase |

## SYSTEM

| Function | Signature | Returns | Description |
|---|---|---|---|
| ADVANCE_CLOCK | ADVANCE_CLOCK(duration_ms: DINT) : DINT |  | Advance virtual clock by N ms (test-mode only; no-op on real clock) |
| DEBUG_PRINT | DEBUG_PRINT(msg: STRING) : BOOL |  | Debug print message |
| DELAY | DELAY(ms: INT) : BOOL |  | Delay execution |
| DL_EXISTS | DL_EXISTS(var_path: STRING) : BOOL |  | Check if DataLayer variable exists |
| DL_GET | DL_GET(var_path: STRING) : ANY |  | Read DataLayer variable by path |
| DL_GET_TS | DL_GET_TS(var_path: STRING) : DINT |  | Get timestamp of last DataLayer update (ms) |
| DL_LATENCY_US | DL_LATENCY_US(var_path: STRING) : DINT |  | Get latency of last DataLayer read (us) |
| EXIT | EXIT(code: INT) : BOOL |  | Exit program |
| GET_ENV | GET_ENV(name: STRING) : STRING |  | Get environment variable |
| GET_HOSTNAME | GET_HOSTNAME() : STRING |  | Get hostname |
| GET_MEMORY | GET_MEMORY() : INT |  | Get memory usage |
| GET_MEMORY_TOTAL | GET_MEMORY_TOTAL() : INT |  | Get total memory |
| GET_NUM_CPU | GET_NUM_CPU() : INT |  | Get CPU count |
| GET_NUM_GOROUTINE | GET_NUM_GOROUTINE() : INT |  | Get goroutine count |
| GET_PID | GET_PID() : INT |  | Get process ID |
| GET_TICK | GET_TICK() : INT |  | Get tick count |
| GET_TICK_MS | GET_TICK_MS() : INT |  | Get tick in milliseconds |
| GET_TICK_NS | GET_TICK_NS() : LINT |  | Get tick in nanoseconds |
| GET_TICK_US | GET_TICK_US() : LINT |  | Get tick in microseconds |
| GET_UPTIME | GET_UPTIME() : INT |  | Get uptime in seconds |
| GET_UPTIME_MS | GET_UPTIME_MS() : LINT |  | Get uptime in milliseconds |
| GUID | GUID() : STRING |  | Generate GUID |
| IO_AGE_MS | IO_AGE_MS(var_name: STRING) : DINT |  | Age of I/O variable in milliseconds |
| IO_AGE_US | IO_AGE_US(var_name: STRING) : DINT |  | Age of I/O variable in microseconds |
| IO_TS | IO_TS(var_name: STRING) : DINT |  | Timestamp of I/O variable (Unix ms) |
| SYS_CLEAR_ERRORS | SYS_CLEAR_ERRORS() : BOOL |  | Clear all system error flags |
| SYS_EXIT | SYS_EXIT(exit_code: INT) : BOOL |  | Exit interpreter with code |
| SYS_RETAIN_FLUSH | SYS_RETAIN_FLUSH() : BOOL |  | Force immediate RETAIN save for this task |
| SYS_RETAIN_STATUS | SYS_RETAIN_STATUS() : STRING |  | RETAIN status as JSON (file, dirty, size, last_save, var count) |
| SYS_SHUTDOWN | SYS_SHUTDOWN(reason: STRING) : BOOL |  | Graceful shutdown: save RETAIN, stop tasks, exit |
| SYS_UPS_CHARGE | SYS_UPS_CHARGE() : REAL |  | UPS battery percentage (0.0–100.0), 0 if not available |
| SYS_UPS_RUNTIME_S | SYS_UPS_RUNTIME_S() : DINT |  | Estimated UPS runtime in seconds, 0 if not available |
| SYS_UPS_STATUS | SYS_UPS_STATUS() : STRING |  | UPS status: 'online', 'on_battery', 'low_battery', or 'not_available' |
| SYS_WATCHDOG_KICK | SYS_WATCHDOG_KICK() : BOOL |  | Manual hardware watchdog kick (normally automatic) |
| SYS_WATCHDOG_STATUS | SYS_WATCHDOG_STATUS() : STRING |  | Hardware watchdog status: 'active', 'disabled', or 'not_available' |
| UNIQUE_ID | UNIQUE_ID() : STRING |  | Generate unique ID |
| VAR_AGE_MS | VAR_AGE_MS(var_name: STRING) : DINT |  | Age of program variable in milliseconds |
| VAR_AGE_US | VAR_AGE_US(var_name: STRING) : DINT |  | Age of program variable in microseconds |
| VAR_TS | VAR_TS(var_name: STRING) : DINT |  | Timestamp of program variable (Unix ms) |

## TEST

| Function | Signature | Returns | Description |
|---|---|---|---|
| ASSERT_ARRAY_EQ | ASSERT_ARRAY_EQ(actual: ARRAY, expected: ARRAY, message: STRING) : BOOL |  | Test assertion: element-wise array equality (length + values) |
| ASSERT_BETWEEN | ASSERT_BETWEEN(actual: REAL, lo: REAL, hi: REAL, message: STRING) : BOOL |  | Test assertion: lo <= actual <= hi (inclusive) |
| ASSERT_EQ | ASSERT_EQ(actual: ANY, expected: ANY, message: STRING) : BOOL |  | Test assertion: actual == expected (non-halting; accumulates into collector) |
| ASSERT_FALSE | ASSERT_FALSE(condition: BOOL, message: STRING) : BOOL |  | Test assertion: condition is FALSE |
| ASSERT_GT | ASSERT_GT(actual: REAL, bound: REAL, message: STRING) : BOOL |  | Test assertion: actual > bound (strict) |
| ASSERT_LT | ASSERT_LT(actual: REAL, bound: REAL, message: STRING) : BOOL |  | Test assertion: actual < bound (strict) |
| ASSERT_NEAR | ASSERT_NEAR(actual: REAL, expected: REAL, tolerance: REAL, message: STRING) : BOOL |  | Test assertion: \|actual - expected\| <= tolerance |
| ASSERT_TRUE | ASSERT_TRUE(condition: BOOL, message: STRING) : BOOL |  | Test assertion: condition is TRUE |
| SNAPSHOT | SNAPSHOT(name: STRING, value: ANY) : BOOL |  | Record (name, value) into the per-test snapshot trace. Runner compares against __snapshots__/<test>.snap on subsequent runs; rewrite with --update-snapshots |

## TIME

| Function | Signature | Returns | Description |
|---|---|---|---|
| CONCAT_DATE_TOD | CONCAT_DATE_TOD(d: DATE, tod: TOD) : DT |  | Combine date and time of day |
| DIV_TIME | DIV_TIME(t: TIME, divisor: REAL) : TIME |  | Divide time by scalar |
| HOUR | HOUR(t: TIME) : INT |  | Get hour from time |
| IS_LEAP_YEAR | IS_LEAP_YEAR(year: INT) : BOOL |  | Check if leap year |
| IS_VALID_DATE | IS_VALID_DATE(year: INT, month: INT, day: INT) : BOOL |  | Check if valid date |
| MAKE_DATE | MAKE_DATE(year: INT, month: INT, day: INT) : DATE |  | Create date from components |
| MAKE_TIME | MAKE_TIME(hour: INT, minute: INT, second: INT, ms: INT) : TIME |  | Create time from components |
| MAKE_TOD | MAKE_TOD(hour: INT, minute: INT, second: INT) : TOD |  | Create time of day |
| MILLISECOND | MILLISECOND(t: TIME) : INT |  | Get millisecond from time |
| MINUTE | MINUTE(t: TIME) : INT |  | Get minute from time |
| MS | MS(ms: INT) : TIME |  | Convert milliseconds to TIME |
| MUL_TIME | MUL_TIME(t: TIME, factor: REAL) : TIME |  | Multiply time by scalar |
| SECOND | SECOND(t: TIME) : INT |  | Get second from time |
| SYSTIME | SYSTIME() : TIME |  | Get system time |
| TODAY | TODAY() : DATE |  | Get today's date |

## TIMER

| Function | Signature | Returns | Description |
|---|---|---|---|
| AVERAGE | AVERAGE(val: REAL, n: INT) : REAL |  | Running average |
| TOF | TOF(IN: BOOL, PT: TIME) : BOOL |  | Off-delay timer |
| TON | TON(IN: BOOL, PT: TIME) : BOOL |  | On-delay timer |
| TP | TP(IN: BOOL, PT: TIME) : BOOL |  | Pulse timer |

## Teensy

| Function | Signature | Returns | Description |
|---|---|---|---|
| TEENSY_ANALOG_READ | TEENSY_ANALOG_READ(name: STRING, pin: INT) : INT |  | Read ADC pin. Valid pins: 14-27 (A0-A13), 38-39 (A14-A15) |
| TEENSY_BOOTLOADER | TEENSY_BOOTLOADER(name: STRING) : BOOL |  | Reboot Teensy into HalfKay bootloader mode for firmware update |
| TEENSY_CAN_FILTER | TEENSY_CAN_FILTER(name: STRING, port: INT, id: INT, mask: INT) : BOOL |  | Set CAN receive filter (id AND mask) |
| TEENSY_CAN_INIT | TEENSY_CAN_INIT(name: STRING, port: INT, baudRate: INT) : BOOL |  | Init FlexCAN port (0=CAN1 pins 22/23, 1=CAN2 pins 0/1, 2=CAN3 pins 30/31) |
| TEENSY_CAN_RECV | TEENSY_CAN_RECV(name: STRING, port: INT, maxMsgs: INT) : STRING |  | Receive up to N CAN messages, returns JSON array |
| TEENSY_CAN_SEND | TEENSY_CAN_SEND(name: STRING, port: INT, id: INT, hexData: STRING) : BOOL |  | Send CAN message (hex data). Extended ID auto-detected for ID > 0x7FF |
| TEENSY_CAN_STATUS | TEENSY_CAN_STATUS(name: STRING, port: INT) : STRING |  | Get CAN port status JSON (enabled, errors, message count) |
| TEENSY_CLOSE | TEENSY_CLOSE(name: STRING) : BOOL |  | Disconnect from Teensy 4.0 board |
| TEENSY_DIGITAL_READ | TEENSY_DIGITAL_READ(name: STRING, pin: INT) : BOOL |  | Read digital pin (0-39) |
| TEENSY_DIGITAL_WRITE | TEENSY_DIGITAL_WRITE(name: STRING, pin: INT, value: BOOL) : BOOL |  | Write digital pin (0-39) |
| TEENSY_DISTANCE | TEENSY_DISTANCE(name: STRING, trigPin: INT, echoPin: INT) : INT |  | Read HC-SR04 ultrasonic distance sensor, returns mm |
| TEENSY_ENCODER_INIT | TEENSY_ENCODER_INIT(name: STRING, pinA: INT, pinB: INT) : BOOL |  | Start hardware quadrature decoder (QuadTimer). Zero CPU — counts at full speed |
| TEENSY_ENCODER_READ | TEENSY_ENCODER_READ(name: STRING, pinA: INT) : INT |  | Read encoder position (signed 32-bit count) |
| TEENSY_ENCODER_RESET | TEENSY_ENCODER_RESET(name: STRING, pinA: INT) : BOOL |  | Zero the encoder counter |
| TEENSY_FREQ_INIT | TEENSY_FREQ_INIT(name: STRING, pin: INT) : BOOL |  | Start hardware frequency counter (QuadTimer edge counting) |
| TEENSY_FREQ_READ | TEENSY_FREQ_READ(name: STRING, pin: INT) : INT |  | Read measured frequency in Hz |
| TEENSY_I2C_READ | TEENSY_I2C_READ(name: STRING, port: INT, addr: INT) : INT |  | Read a byte from I2C device on port (-1 on error) |
| TEENSY_I2C_SCAN | TEENSY_I2C_SCAN(name: STRING, port: INT) : STRING |  | Scan I2C bus (port 0=18/19, 1=16/17, 2=24/25), returns hex addresses |
| TEENSY_I2C_WRITE | TEENSY_I2C_WRITE(name: STRING, port: INT, addr: INT, value: INT) : BOOL |  | Write a byte to I2C device on port |
| TEENSY_I2C_WRITE_READ | TEENSY_I2C_WRITE_READ(name: STRING, port: INT, addr: INT, reg: INT, readLen: INT) : STRING |  | Write register then read N bytes on port (comma-separated decimal) |
| TEENSY_INIT | TEENSY_INIT(name: STRING, path: STRING) : BOOL |  | Connect to Teensy 4.0 via USB RawHID. Empty path auto-discovers by VID/PID |
| TEENSY_NEOPIXEL | TEENSY_NEOPIXEL(name: STRING, r: INT, g: INT, b: INT) : BOOL |  | Set NeoPixel LED color (R, G, B: 0-255) |
| TEENSY_NEO_STRIP | TEENSY_NEO_STRIP(name: STRING, numLeds: INT, hexColors: STRING) : BOOL |  | Send full NeoPixel strip update (up to 64 LEDs) |
| TEENSY_OLED_CLEAR | TEENSY_OLED_CLEAR(name: STRING, addr: INT) : BOOL |  | Clear OLED screen |
| TEENSY_OLED_INIT | TEENSY_OLED_INIT(name: STRING, addr: INT) : BOOL |  | Init SSD1306 OLED via I2C |
| TEENSY_OLED_PRINT | TEENSY_OLED_PRINT(name: STRING, addr: INT, row: INT, text: STRING) : BOOL |  | Print text on OLED row (0-7), 21 chars/line, 5x7 font |
| TEENSY_PID_CONFIG | TEENSY_PID_CONFIG(name: STRING, id: INT, inputPin: INT, outputPin: INT, kp: REAL, ki: REAL, kd: REAL, rateHz: INT, outMin: INT, outMax: INT) : BOOL |  | Configure on-device PID loop (runs at rateHz on Teensy, no USB in loop). Up to 4 loops (id 0-3) |
| TEENSY_PID_READ | TEENSY_PID_READ(name: STRING, id: INT) : STRING |  | Read PID state JSON (setpoint, input, output, error, integral, running) |
| TEENSY_PID_SETPOINT | TEENSY_PID_SETPOINT(name: STRING, id: INT, setpoint: REAL) : BOOL |  | Set PID target value. The Teensy loop tracks this autonomously |
| TEENSY_PID_STOP | TEENSY_PID_STOP(name: STRING, id: INT) : BOOL |  | Stop PID loop and set output to zero |
| TEENSY_PID_TUNE | TEENSY_PID_TUNE(name: STRING, id: INT, kp: REAL, ki: REAL, kd: REAL) : BOOL |  | Update PID gains while running (bumpless transfer) |
| TEENSY_PIN_MODE | TEENSY_PIN_MODE(name: STRING, pin: INT, mode: INT) : BOOL |  | Set pin mode (0=input, 1=output, 2=pullup, 3=pulldown, 4=pwm, 5=adc) |
| TEENSY_PWM_CONFIG | TEENSY_PWM_CONFIG(name: STRING, pin: INT, freqHz: INT, alignment: INT) : BOOL |  | Configure FlexPWM channel with frequency and alignment (0=edge, 1=center) |
| TEENSY_PWM_FAULT | TEENSY_PWM_FAULT(name: STRING, faultPin: INT) : BOOL |  | Set hardware fault input — disables all PWM outputs instantly on trigger (no software latency) |
| TEENSY_PWM_PAIR | TEENSY_PWM_PAIR(name: STRING, pinH: INT, pinL: INT, freqHz: INT, deadtimeNs: INT) : BOOL |  | Configure complementary FlexPWM pair with dead-time insertion (ns). For H-bridge/motor drive |
| TEENSY_PWM_WRITE | TEENSY_PWM_WRITE(name: STRING, pin: INT, duty: INT) : BOOL |  | Set PWM duty cycle (0-65535) |
| TEENSY_RESET_PINS | TEENSY_RESET_PINS(name: STRING) : BOOL |  | Release all pins to default state |
| TEENSY_RTC_GET | TEENSY_RTC_GET(name: STRING) : INT |  | Read RTC timestamp (unix seconds). Battery-backed SNVS RTC |
| TEENSY_RTC_SET | TEENSY_RTC_SET(name: STRING, timestamp: INT) : BOOL |  | Set RTC timestamp (unix seconds) |
| TEENSY_SERVO | TEENSY_SERVO(name: STRING, pin: INT, angle: INT) : BOOL |  | Set servo angle (0-180) on a pin. Uses 50Hz PWM |
| TEENSY_SPI_TRANSFER | TEENSY_SPI_TRANSFER(name: STRING, port: INT, hexData: STRING) : STRING |  | SPI transfer on port (0=11/12/13, 1=SPI1, 2=SPI2). Hex in/out |
| TEENSY_STATUS | TEENSY_STATUS(name: STRING) : STRING |  | Get board status JSON (ping, board info, capabilities, connection state) |
| TEENSY_TEMP_READ | TEENSY_TEMP_READ(name: STRING) : INT |  | Read iMXRT1062 internal temperature sensor (returns C * 100) |
| TEENSY_TRNG_READ | TEENSY_TRNG_READ(name: STRING, len: INT) : STRING |  | Read true random bytes from hardware TRNG (hex string) |
| TEENSY_UART_INIT | TEENSY_UART_INIT(name: STRING, channel: INT, baudRate: INT) : BOOL |  | Init UART channel (0-6: Serial1-Serial7) at baud rate |
| TEENSY_UART_RECV | TEENSY_UART_RECV(name: STRING, channel: INT, maxLen: INT) : STRING |  | Read up to maxLen bytes from UART channel ring buffer (non-blocking) |
| TEENSY_UART_SEND | TEENSY_UART_SEND(name: STRING, channel: INT, data: STRING) : BOOL |  | Send string data via UART channel |

## UTILITY

| Function | Signature | Returns | Description |
|---|---|---|---|
| DWORD_OF_WORD | DWORD_OF_WORD(high: WORD, low: WORD) : DWORD |  | Combine words to dword |
| DYNAMIC_VALUE | DYNAMIC_VALUE(name: STRING) : ANY |  | Get dynamic value by name |
| EVEN_ODD | EVEN_ODD(val: INT) : STRING |  | Check even or odd |
| LINKED_LIST_CREATE | LINKED_LIST_CREATE() : LINKED_LIST |  | Create linked list |
| MOV | MOV(val: ANY) : ANY |  | Move/copy value |
| NEGATIVE | NEGATIVE(val: ANY_NUM) : BOOL |  | Check if negative |
| NON_ZERO | NON_ZERO(val: ANY_NUM) : BOOL |  | Check if non-zero |
| POSITIVE | POSITIVE(val: ANY_NUM) : BOOL |  | Check if positive |
| QUERY_STRING_BUILD | QUERY_STRING_BUILD(params: MAP) : STRING |  | Build query string |
| QUERY_STRING_PARSE | QUERY_STRING_PARSE(qs: STRING) : MAP |  | Parse query string |
| RANDOM | RANDOM() : REAL |  | Random number 0-1 |
| RANDOM_RANGE | RANDOM_RANGE(min: INT, max: INT) : INT |  | Random in range |
| RANDOM_SEED | RANDOM_SEED(seed: INT) : BOOL |  | Set random seed |
| RAND_SEED | RAND_SEED(seed: INT) : BOOL |  | Set random seed (alias) |
| RATELIMIT | RATELIMIT(name: STRING, limit: INT, windowMs: INT) : BOOL |  | Rate limit check |
| RUN_ASYNC | RUN_ASYNC(cmd: STRING) : INT |  | Run async task |
| RUN_COMMAND | RUN_COMMAND(cmd: STRING) : STRING |  | Run command |
| SCRIPT_OUTPUT | SCRIPT_OUTPUT(id: INT) : STRING |  | Get script output |
| SCRIPT_RUN | SCRIPT_RUN(path: STRING) : INT |  | Run script |
| SWAP | SWAP(a: ANY, b: ANY) : BOOL |  | Swap two values |
| TO_BOOL | TO_BOOL(val: ANY) : BOOL |  | Convert to boolean |
| TO_FLOAT | TO_FLOAT(val: ANY) : REAL |  | Convert to float |
| TO_INT | TO_INT(val: ANY) : INT |  | Convert to integer |
| TO_LOWER | TO_LOWER(str: STRING) : STRING |  | Convert to lowercase |
| TO_REAL | TO_REAL(val: ANY) : REAL |  | Convert to real |
| TO_STRING | TO_STRING(val: ANY) : STRING |  | Convert to string |
| TO_UPPER | TO_UPPER(str: STRING) : STRING |  | Convert to uppercase |
| WORD_OF_DWORD | WORD_OF_DWORD(d: DWORD, index: INT) : WORD |  | Extract word from dword |
| ZERO | ZERO(val: ANY_NUM) : BOOL |  | Check if zero |

## VIDEO

| Function | Signature | Returns | Description |
|---|---|---|---|
| VIDEO_CAMERA_BURST | VIDEO_CAMERA_BURST(name: STRING, pre_s: REAL, post_s: REAL, [burst_fps: REAL], [event_id: STRING]) : BOOL |  | Flag lookback frames event_clip + burst-capture the post window |
| VIDEO_CAMERA_CREATE | VIDEO_CAMERA_CREATE(name: STRING, [tool: STRING], [device: STRING], [width: DINT], [height: DINT], [fps: REAL], [quality_pct: DINT], [title: STRING]) : BOOL |  | Create and start a camera at runtime |
| VIDEO_CAMERA_DELETE | VIDEO_CAMERA_DELETE(name: STRING) : BOOL |  | Stop and remove a camera |
| VIDEO_CAMERA_FRAME_COUNT | VIDEO_CAMERA_FRAME_COUNT(name: STRING) : LINT |  | Frames captured by this camera since create |
| VIDEO_CAMERA_LAST_TS | VIDEO_CAMERA_LAST_TS(name: STRING) : LINT |  | Unix-ms of most recent successful capture (0 if none) |
| VIDEO_CAMERA_SET_INPUT_FORMAT | VIDEO_CAMERA_SET_INPUT_FORMAT(name: STRING, fmt: STRING) : BOOL |  | Set ffmpeg -input_format (e.g. 'mjpeg' unlocks higher res on USB webcams) |
| VIDEO_CAMERA_SET_TIMEOUT | VIDEO_CAMERA_SET_TIMEOUT(name: STRING, ms: DINT) : BOOL |  | Update capture command timeout (ms, 0 = default) |
| VIDEO_CAMERA_SET_TITLE | VIDEO_CAMERA_SET_TITLE(name: STRING, title: STRING) : BOOL |  | Set human-facing label rendered in the /video HMI header |
| VIDEO_CAMERA_START | VIDEO_CAMERA_START(name: STRING) : BOOL |  | Resume a previously stopped camera |
| VIDEO_CAMERA_STOP | VIDEO_CAMERA_STOP(name: STRING) : BOOL |  | Pause a camera without removing it |
| VIDEO_CAMERA_TAG_ADD | VIDEO_CAMERA_TAG_ADD(name: STRING, tag: STRING) : BOOL |  | Add a variable to the per-frame tag snapshot |
| VIDEO_CAMERA_TAG_CLEAR | VIDEO_CAMERA_TAG_CLEAR(name: STRING) : BOOL |  | Clear all snapshot tags for a camera |
| VIDEO_HISTORIAN_ENABLED | VIDEO_HISTORIAN_ENABLED() : BOOL |  | True if the video historian engine is running (either from YAML config or via lazy-init on first VIDEO_CAMERA_CREATE call) |

## VISION

| Function | Signature | Returns | Description |
|---|---|---|---|
| VISION_CANCEL | VISION_CANCEL(request_id: STRING) : BOOL |  | Cancel a pending or running request |
| VISION_ERROR | VISION_ERROR(request_id: STRING) : STRING |  | Inference error message; empty if none |
| VISION_FRAME_ID | VISION_FRAME_ID(request_id: STRING) : DINT |  | videohist frame_id for spine correlation (time-travel debug) |
| VISION_INFERENCE_MS | VISION_INFERENCE_MS(request_id: STRING) : REAL |  | Backend inference time in milliseconds |
| VISION_OBJECT_CONFIDENCE | VISION_OBJECT_CONFIDENCE(request_id: STRING, idx: DINT) : REAL |  | Per-object confidence 0..1 |
| VISION_OBJECT_COUNT | VISION_OBJECT_COUNT(request_id: STRING) : DINT |  | Number of detected objects in the result |
| VISION_OBJECT_FIELD | VISION_OBJECT_FIELD(request_id: STRING, idx: DINT, field: STRING) : STRING |  | Capability-specific extra (gauge_value, color_hsv, etc.) as STRING; convert numeric extras with STRING_TO_REAL |
| VISION_OBJECT_LABEL | VISION_OBJECT_LABEL(request_id: STRING, idx: DINT) : STRING |  | ResultObject.Class — barcode text, class name, gauge id, OCR transcription |
| VISION_READY | VISION_READY(request_id: STRING) : BOOL |  | True once status is done, error, or canceled (terminal state) |
| VISION_STATUS | VISION_STATUS(request_id: STRING) : STRING |  | Lifecycle status: pending\|running\|done\|error\|canceled\|unknown |
| VISION_TRIGGER | VISION_TRIGGER(camera: STRING, capability: STRING) : STRING |  | Submit vision scan via videohist camera; returns request_id (UUIDv7) or '' on error |
| VISION_TRIGGER_BACKEND | VISION_TRIGGER_BACKEND(camera: STRING, capability: STRING, backend_name: STRING) : STRING |  | Like VISION_TRIGGER but pins to a named backend (e.g. for shadow A/B model testing) |
| VISION_TRIGGER_FILE | VISION_TRIGGER_FILE(file_path: STRING, capability: STRING) : STRING |  | Submit scan against a frame file on disk (offline ST workflows; bypasses videohist) |

## WEBSOCKET

| Function | Signature | Returns | Description |
|---|---|---|---|
| WS_CLOSE | WS_CLOSE(handle: STRING) : BOOL |  | Close WebSocket connection |
| WS_CONNECT | WS_CONNECT(url: STRING) : STRING |  | Open WebSocket connection, returns handle |
| WS_CONNECTED | WS_CONNECTED(handle: STRING) : BOOL |  | Check if WebSocket is still connected |
| WS_PING | WS_PING(handle: STRING) : BOOL |  | Send WebSocket ping keepalive |
| WS_RECV | WS_RECV(handle: STRING) : STRING |  | Read last received message (non-blocking) |
| WS_SEND | WS_SEND(handle: STRING, message: STRING) : BOOL |  | Send text message over WebSocket |

## ZPL

| Function | Signature | Returns | Description |
|---|---|---|---|
| ZPL_BARCODE_128 | ZPL_BARCODE_128(handle: HANDLE, x: INT, y: INT, height: INT, data: STRING) : HANDLE |  | Add Code 128 barcode |
| ZPL_BARCODE_EAN13 | ZPL_BARCODE_EAN13(handle: HANDLE, x: INT, y: INT, height: INT, data: STRING) : HANDLE |  | Add EAN-13 barcode |
| ZPL_BEGIN | ZPL_BEGIN([width: INT], [height: INT]) : HANDLE |  | Start building ZPL label |
| ZPL_BOX | ZPL_BOX(handle: HANDLE, x: INT, y: INT, width: INT, height: INT, thickness: INT) : HANDLE |  | Draw rectangle |
| ZPL_END | ZPL_END(handle: HANDLE) : STRING |  | Finish label and get ZPL command string |
| ZPL_FIELD | ZPL_FIELD(handle: HANDLE, x: INT, y: INT, field_num: INT) : HANDLE |  | Add variable field placeholder |
| ZPL_LABEL | ZPL_LABEL(line1: STRING, line2: STRING, ...) : STRING |  | Quick multi-line text label |
| ZPL_LINE | ZPL_LINE(handle: HANDLE, x: INT, y: INT, width: INT, thickness: INT) : HANDLE |  | Draw horizontal line |
| ZPL_QR | ZPL_QR(handle: HANDLE, x: INT, y: INT, magnification: INT, data: STRING) : HANDLE |  | Add QR code |
| ZPL_TEXT | ZPL_TEXT(handle: HANDLE, x: INT, y: INT, font_size: INT, text: STRING) : HANDLE |  | Add text at position |

## ctrlX

| Function | Signature | Returns | Description |
|---|---|---|---|
| CTRLX_EC_BROWSE | CTRLX_EC_BROWSE(name: STRING) : STRING |  | Discover I/O modules — returns JSON {inputs:[...], outputs:[...]} |
| CTRLX_EC_CONNECTED | CTRLX_EC_CONNECTED(name: STRING) : BOOL |  | Returns TRUE if client is polling successfully |
| CTRLX_EC_CREATE | CTRLX_EC_CREATE(name: STRING, [host: STRING], [user: STRING], [pass: STRING], [di_module: STRING], [do_module: STRING], [di_count: INT], [do_count: INT], [poll_ms: INT], [mode: STRING]) : BOOL |  | Create ctrlX EtherCAT I/O client (defaults: host=https://localhost, user=boschrexroth, DI=XI110116[16], DO=XI211116[16], mode=rest). Mode 'dl' uses native IPC (requires ctrlxdl build tag). |
| CTRLX_EC_DELETE | CTRLX_EC_DELETE(name: STRING) : BOOL |  | Stop and remove client instance |
| CTRLX_EC_READ_DI | CTRLX_EC_READ_DI(name: STRING, channel: INT) : BOOL |  | Read cached digital input state (1-based channel) |
| CTRLX_EC_READ_DO | CTRLX_EC_READ_DO(name: STRING, channel: INT) : BOOL |  | Read back current digital output state (1-based channel) |
| CTRLX_EC_START | CTRLX_EC_START(name: STRING) : BOOL |  | Start background I/O polling loop |
| CTRLX_EC_STATS | CTRLX_EC_STATS(name: STRING) : STRING |  | Get JSON diagnostics (connected, poll_count, read_errors, write_errors) |
| CTRLX_EC_STOP | CTRLX_EC_STOP(name: STRING) : BOOL |  | Stop background I/O polling loop |
| CTRLX_EC_WRITE_DO | CTRLX_EC_WRITE_DO(name: STRING, channel: INT, value: BOOL) : BOOL |  | Queue digital output write (1-based channel). Returns FALSE if not connected — check CTRLX_EC_CONNECTED() on failure. |

