# GoPLC NMEA & GPS Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

26 built-in functions for GPS/GNSS integration from Structured Text. Parse NMEA sentences from serial GPS receivers, extract position/speed/altitude, and perform geospatial calculations — geofencing, distance, bearing, and coordinate conversion.

---

## 2. NMEA Sentence Parsing (17)

```iecst
(* Parse a GPRMC sentence from serial GPS *)
sentence := '$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A';
nmea := NMEA_PARSE(sentence);

IF NMEA_VALID(nmea) THEN
    msg_type := NMEA_GET_TYPE(nmea);        (* "GPRMC" *)
    lat := NMEA_GET_LAT(nmea);              (* 48.1173 decimal degrees *)
    lon := NMEA_GET_LON(nmea);              (* 11.5167 decimal degrees *)
    speed := NMEA_GET_SPEED(nmea);          (* m/s *)
    course := NMEA_GET_COURSE(nmea);        (* degrees *)
    date := NMEA_GET_DATE(nmea);            (* "1994-03-23" *)
    time := NMEA_GET_TIME(nmea);            (* "12:35:19" *)
END_IF;

(* GGA sentence — altitude and fix quality *)
gga := NMEA_PARSE('$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,47.0,M,,*47');
alt := NMEA_GET_ALT(gga);                  (* 545.4 meters *)
fix := NMEA_GET_FIX(gga);                  (* 1 = GPS fix *)
sats := NMEA_GET_SATS(gga);               (* 8 satellites *)
hdop := NMEA_GET_HDOP(gga);               (* 0.9 *)

(* Raw field access *)
field_count := NMEA_FIELD_COUNT(nmea);
raw_field := NMEA_GET_FIELD(nmea, 3);      (* Field by index *)

(* Build and validate *)
checksum := NMEA_CHECKSUM('GPRMC,123519,A,...');
custom := NMEA_BUILD('PPLC', 'GOPLC', '1.0', '72.5');
(* Returns: "$PPLC,GOPLC,1.0,72.5*XX" with calculated checksum *)
```

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `NMEA_PARSE(sentence)` | 1 | Handle | Parse NMEA sentence |
| `NMEA_VALID(h)` | 1 | BOOL | Verify checksum |
| `NMEA_GET_TYPE(h)` | 1 | STRING | Sentence type ("GPRMC", "GPGGA") |
| `NMEA_GET_LAT(h)` | 1 | REAL | Latitude (decimal degrees) |
| `NMEA_GET_LON(h)` | 1 | REAL | Longitude (decimal degrees) |
| `NMEA_GET_ALT(h)` | 1 | REAL | Altitude (meters, GGA only) |
| `NMEA_GET_SPEED(h)` | 1 | REAL | Speed (m/s) |
| `NMEA_GET_COURSE(h)` | 1 | REAL | Course (degrees) |
| `NMEA_GET_DATE(h)` | 1 | STRING | Date (YYYY-MM-DD) |
| `NMEA_GET_TIME(h)` | 1 | STRING | Time (HH:MM:SS) |
| `NMEA_GET_FIX(h)` | 1 | INT | Fix quality (0=none, 1=GPS, 2=DGPS) |
| `NMEA_GET_SATS(h)` | 1 | INT | Satellite count |
| `NMEA_GET_HDOP(h)` | 1 | REAL | Horizontal dilution of precision |
| `NMEA_GET_FIELD(h, index)` | 2 | STRING | Raw field by index |
| `NMEA_FIELD_COUNT(h)` | 1 | INT | Total fields |
| `NMEA_CHECKSUM(str)` | 1 | STRING | Calculate 2-char hex checksum |
| `NMEA_BUILD(type, fields...)` | 2+ | STRING | Build sentence with checksum |

---

## 3. GPS Calculations (9)

Geodesic functions using the haversine formula.

```iecst
(* Distance between two points *)
dist := GPS_DISTANCE(48.1173, 11.5167, 48.1375, 11.5755);    (* meters *)

(* Bearing from point A to point B *)
bearing := GPS_BEARING(48.1173, 11.5167, 48.1375, 11.5755);  (* degrees 0-360 *)

(* Calculate destination from start + bearing + distance *)
dest := GPS_DESTINATION(48.1173, 11.5167, 45.0, 1000.0);     (* 1km NE *)
new_lat := JSON_GET_REAL(dest, 'lat');
new_lon := JSON_GET_REAL(dest, 'lon');

(* Midpoint *)
mid := GPS_MIDPOINT(48.1173, 11.5167, 48.1375, 11.5755);

(* Speed from two positions + time *)
speed := GPS_SPEED(lat1, lon1, lat2, lon2, elapsed_seconds);  (* m/s *)

(* Geofencing *)
in_zone := GPS_IN_RADIUS(lat, lon, center_lat, center_lon, 500.0);  (* 500m radius *)
in_area := GPS_IN_RECT(lat, lon, min_lat, min_lon, max_lat, max_lon);

(* Coordinate conversion *)
dms := GPS_DD_TO_DMS(48.1173, 'N');    (* {deg:48, min:7, sec:2.28, dir:"N"} *)
dd := GPS_DMS_TO_DD(48, 7, 2.28, 'N'); (* 48.1173 *)
```

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `GPS_DISTANCE(lat1,lon1,lat2,lon2)` | 4 | REAL | Distance in meters (haversine) |
| `GPS_BEARING(lat1,lon1,lat2,lon2)` | 4 | REAL | Bearing in degrees (0-360) |
| `GPS_DESTINATION(lat,lon,bearing,dist)` | 4 | MAP | Destination {lat, lon} |
| `GPS_MIDPOINT(lat1,lon1,lat2,lon2)` | 4 | MAP | Midpoint {lat, lon} |
| `GPS_SPEED(lat1,lon1,lat2,lon2,sec)` | 5 | REAL | Speed in m/s |
| `GPS_IN_RADIUS(lat,lon,clat,clon,r)` | 5 | BOOL | Within radius? |
| `GPS_IN_RECT(lat,lon,minlat,minlon,maxlat,maxlon)` | 6 | BOOL | Within rectangle? |
| `GPS_DD_TO_DMS(dd [,axis])` | 1-2 | MAP | Decimal → degrees/minutes/seconds |
| `GPS_DMS_TO_DD(deg,min,sec [,dir])` | 3-4 | REAL | DMS → decimal degrees |

---

*GoPLC v1.0.535 | 26 NMEA/GPS Functions | GPS Parsing, Geofencing, Geodesic Math*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
