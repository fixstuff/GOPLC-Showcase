# GoPLC Entertainment & Show Control Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC supports four entertainment/show control protocols for stage lighting, sound, and interactive installations — all callable from Structured Text.

| Protocol | Functions | Use Case |
|----------|-----------|----------|
| **Art-Net** | 7 | DMX512 lighting via Ethernet (UDP port 6454) |
| **sACN/E1.31** | 7 | Streaming ACN lighting (multicast or unicast) |
| **MIDI** | 14 | Musical instrument control, show cues |
| **OSC** | 12 | Open Sound Control (media servers, projectors) |

---

## 2. Art-Net — DMX Over Ethernet

Control DMX512 lighting fixtures via Art-Net protocol.

```iecst
(* Create a 512-channel universe *)
u := ARTNET_CREATE_UNIVERSE('main', 0);

(* Set individual channels *)
u := ARTNET_SET_CHANNEL(u, 1, 255);         (* Ch 1 = full *)
u := ARTNET_SET_CHANNEL(u, 2, 128);         (* Ch 2 = 50% *)

(* Set RGB fixture starting at channel 10 *)
u := ARTNET_SET_RGB(u, 10, 255, 0, 0);      (* Red *)

(* Send to Art-Net node *)
ARTNET_SEND_UNIVERSE('10.0.0.200', u);

(* Quick send without universe buffer *)
ARTNET_SEND('10.0.0.200', 0, 255, 128, 64);  (* Universe 0, channels 1-3 *)

(* Blackout / full *)
u := ARTNET_BLACKOUT(u);                      (* All channels → 0 *)
u := ARTNET_FULL(u);                          (* All channels → 255 *)
```

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `ARTNET_CREATE_UNIVERSE(name, num)` | 2 | Handle | Create 512-channel buffer |
| `ARTNET_SET_CHANNEL(h, ch, val)` | 3 | Handle | Set channel 1-512 (0-255) |
| `ARTNET_SET_RGB(h, start, r, g, b)` | 5 | Handle | Set 3 consecutive RGB channels |
| `ARTNET_SEND(host, universe, vals...)` | 3+ | BOOL | Quick send raw channels |
| `ARTNET_SEND_UNIVERSE(host, h)` | 2 | BOOL | Send universe buffer (port 6454) |
| `ARTNET_BLACKOUT(h)` | 1 | Handle | All channels → 0 |
| `ARTNET_FULL(h)` | 1 | Handle | All channels → 255 |

---

## 3. sACN/E1.31 — Streaming ACN

ANSI E1.31 streaming DMX — supports multicast and priority.

```iecst
u := SACN_CREATE_UNIVERSE('wash', 1);
SACN_SET_PRIORITY(u, 150);                   (* Higher priority wins *)

SACN_SET_CHANNEL(u, 1, 255);
SACN_SET_RGB(u, 10, 0, 255, 0);             (* Green *)

(* Unicast *)
SACN_SEND_UNIVERSE('10.0.0.201', u);

(* Multicast — use empty string or multicast address *)
SACN_SEND_UNIVERSE('', u);

(* Quick send *)
SACN_SEND('10.0.0.201', 1, 255, 128, 64);

SACN_BLACKOUT(u);
```

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `SACN_CREATE_UNIVERSE(name, num)` | 2 | Handle | Create universe (priority 100) |
| `SACN_SET_CHANNEL(h, ch, val)` | 3 | Handle | Set channel 1-512 (0-255) |
| `SACN_SET_RGB(h, start, r, g, b)` | 5 | Handle | Set 3 RGB channels |
| `SACN_SET_PRIORITY(h, priority)` | 2 | Handle | Set sACN priority (0-200) |
| `SACN_SEND(host, universe, vals...)` | 3+ | BOOL | Quick send |
| `SACN_SEND_UNIVERSE(host, h)` | 2 | BOOL | Send buffer (multicast if host empty) |
| `SACN_BLACKOUT(h)` | 1 | Handle | All channels → 0 |

---

## 4. MIDI — Musical Instrument Control

Build and parse MIDI messages for instrument control, show cues, and sound design.

```iecst
(* Send Note On — middle C, velocity 100, channel 1 *)
msg := MIDI_NOTE_ON(0, 60, 100);

(* Note name conversion *)
note := MIDI_NAME_TO_NOTE('C4');              (* 60 *)
name := MIDI_NOTE_TO_NAME(60);               (* "C4" *)

(* Control Change — modulation wheel *)
cc := MIDI_CC(0, 1, 127);

(* Pitch bend — center = 8192 *)
pb := MIDI_PITCH_BEND(0, 8192);

(* Program change — select patch *)
pc := MIDI_PROGRAM_CHANGE(0, 42);

(* SysEx message *)
sx := MIDI_SYSEX(16#7E, 16#7F, 16#09, 16#01);

(* Parse incoming MIDI *)
parsed := MIDI_PARSE(16#90, 60, 100);
status := MIDI_GET_STATUS(parsed);            (* 16#90 = Note On *)
channel := MIDI_GET_CHANNEL(parsed);          (* 0 *)

(* Pack to single integer for serial transmission *)
packed := MIDI_BUILD_NOTE_ON(0, 60, 100);
```

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `MIDI_NOTE_ON(ch, note, vel)` | 3 | ARRAY | Note On bytes |
| `MIDI_NOTE_OFF(ch, note, vel)` | 3 | ARRAY | Note Off bytes |
| `MIDI_CC(ch, controller, val)` | 3 | ARRAY | Control Change bytes |
| `MIDI_PITCH_BEND(ch, val)` | 2 | ARRAY | Pitch Bend (0-16383) |
| `MIDI_PROGRAM_CHANGE(ch, prog)` | 2 | ARRAY | Program Change bytes |
| `MIDI_SYSEX(mfr, data...)` | 2+ | ARRAY | SysEx message |
| `MIDI_PARSE(bytes...)` | 1-3 | Handle | Parse raw MIDI |
| `MIDI_GET_STATUS(h)` | 1 | INT | Status byte (without channel) |
| `MIDI_GET_CHANNEL(h)` | 1 | INT | Channel (0-15) |
| `MIDI_NAME_TO_NOTE(name)` | 1 | INT | "C4" → 60 |
| `MIDI_NOTE_TO_NAME(note)` | 1 | STRING | 60 → "C4" |
| `MIDI_BUILD_NOTE_ON(ch, note, vel)` | 3 | INT | Pack to single int |
| `MIDI_BUILD_NOTE_OFF(ch, note, vel)` | 3 | INT | Pack to single int |
| `MIDI_BUILD_CC(ch, ctrl, val)` | 3 | INT | Pack to single int |

---

## 5. OSC — Open Sound Control

Control media servers, projection mapping, sound systems, and interactive installations.

```iecst
(* Simple typed sends *)
OSC_SEND_FLOAT('10.0.0.100:8000', '/master/volume', 0.75);
OSC_SEND_INT('10.0.0.100:8000', '/cue/number', 42);
OSC_SEND_STRING('10.0.0.100:8000', '/display/text', 'WELCOME');
OSC_SEND_BOOL('10.0.0.100:8000', '/projector/enable', TRUE);

(* Auto-detect type *)
OSC_SEND('10.0.0.100:8000', '/fader/1', 0.5);

(* Multi-argument message *)
msg := OSC_MSG_CREATE('/mixer/channel/1');
msg := OSC_MSG_ADD_FLOAT(msg, 0.75);        (* Volume *)
msg := OSC_MSG_ADD_INT(msg, 1);              (* Mute off *)
msg := OSC_MSG_ADD_STRING(msg, 'Main L');    (* Label *)
OSC_MSG_SEND('10.0.0.100:8000', msg);

(* Bundle — multiple messages, one packet *)
OSC_SEND_BUNDLE('10.0.0.100:8000',
    OSC_MSG_CREATE('/ch/1/mix/fader'),
    OSC_MSG_CREATE('/ch/2/mix/fader')
);
```

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `OSC_SEND(target, addr, val)` | 3 | BOOL | Auto-typed send |
| `OSC_SEND_INT(target, addr, val)` | 3 | BOOL | Send integer |
| `OSC_SEND_FLOAT(target, addr, val)` | 3 | BOOL | Send float |
| `OSC_SEND_STRING(target, addr, val)` | 3 | BOOL | Send string |
| `OSC_SEND_BOOL(target, addr, val)` | 3 | BOOL | Send boolean |
| `OSC_SEND_BUNDLE(target, msgs...)` | 2+ | BOOL | Send message bundle |
| `OSC_MSG_CREATE(addr)` | 1 | Handle | Create message builder |
| `OSC_MSG_ADD_INT(h, val)` | 2 | Handle | Add integer argument |
| `OSC_MSG_ADD_FLOAT(h, val)` | 2 | Handle | Add float argument |
| `OSC_MSG_ADD_STRING(h, val)` | 2 | Handle | Add string argument |
| `OSC_MSG_ADD_BOOL(h, val)` | 2 | Handle | Add boolean argument |
| `OSC_MSG_SEND(target, h)` | 2 | BOOL | Send constructed message |

---

*GoPLC v1.0.535 | Art-Net (7) + sACN (7) + MIDI (14) + OSC (12) | Entertainment & Show Control*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
