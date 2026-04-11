# GoPLC SMTP Email Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides 4 built-in functions for sending email from Structured Text. Send alarm notifications, shift reports, and diagnostic alerts directly from your PLC program — no external scripts or middleware required.

| Function | Auth | TLS | Port | Body Format |
|----------|------|-----|------|-------------|
| `SMTP_SEND` | None (relay) | No | 25 | Plain text |
| `SMTP_SEND_HTML` | None (relay) | No | 25 | HTML |
| `SMTP_SEND_AUTH` | Username/password | No | 587 | Plain text |
| `SMTP_SEND_TLS` | Username/password | Implicit TLS | 465 | Plain text |

---

## 2. SMTP_SEND — Plain Relay

No authentication — sends through an open relay or local mail server. Typical for internal plant networks with a local SMTP relay.

```iecst
ok := SMTP_SEND(
    'mail.plant.local:25',           (* SMTP server *)
    'plc@plant.local',               (* From *)
    'operator@plant.local',          (* To *)
    'High Temperature Alarm',        (* Subject *)
    'Temperature exceeded 180F at Zone 3. Check cooling system.'
);
```

| Param | Type | Description |
|-------|------|-------------|
| `host` | STRING | SMTP server address (host:port, default port 25) |
| `from` | STRING | Sender email address |
| `to` | STRING | Recipient email address |
| `subject` | STRING | Email subject line |
| `body` | STRING | Plain text body |

Returns: `BOOL` — TRUE if the email was accepted by the server.

---

## 3. SMTP_SEND_HTML — HTML Email

Same as SMTP_SEND but sends HTML content. No authentication.

```iecst
html := CONCAT(
    '<h2 style="color:red">ALARM: High Temperature</h2>',
    '<table border="1">',
    '<tr><td>Zone</td><td>3</td></tr>',
    '<tr><td>Temperature</td><td>', REAL_TO_STRING(temperature), ' F</td></tr>',
    '<tr><td>Threshold</td><td>180 F</td></tr>',
    '<tr><td>Time</td><td>', DT_TO_STRING(NOW()), '</td></tr>',
    '</table>',
    '<p>Please investigate immediately.</p>'
);

ok := SMTP_SEND_HTML(
    'mail.plant.local:25',
    'plc@plant.local',
    'operator@plant.local',
    'ALARM: High Temperature - Zone 3',
    html
);
```

---

## 4. SMTP_SEND_AUTH — Authenticated

Uses PLAIN authentication on port 587. Required for most external mail providers.

```iecst
ok := SMTP_SEND_AUTH(
    'smtp.gmail.com:587',            (* SMTP server *)
    'plc.alerts@gmail.com',          (* Username *)
    'app-password-here',             (* Password / app password *)
    'plc.alerts@gmail.com',          (* From *)
    'maintenance@company.com',       (* To *)
    'GoPLC Daily Report',            (* Subject *)
    report_text                      (* Body *)
);
```

| Param | Type | Description |
|-------|------|-------------|
| `host` | STRING | SMTP server (host:port, default port 587) |
| `username` | STRING | Auth username |
| `password` | STRING | Auth password or app password |
| `from` | STRING | Sender address |
| `to` | STRING | Recipient address |
| `subject` | STRING | Subject line |
| `body` | STRING | Plain text body |

---

## 5. SMTP_SEND_TLS — Encrypted (Implicit TLS)

Uses implicit TLS on port 465 — the connection is encrypted from the start. TLS 1.2 minimum.

```iecst
ok := SMTP_SEND_TLS(
    'smtp.office365.com:465',
    'plc-alerts@company.com',
    'password',
    'plc-alerts@company.com',
    'supervisor@company.com',
    'Critical Fault - Line 2 Stopped',
    CONCAT('Line 2 stopped at ', DT_TO_STRING(NOW()),
           '. Fault code: ', INT_TO_STRING(fault_code))
);
```

Same parameters as SMTP_SEND_AUTH. Connection uses `tls.Dial` — not STARTTLS.

---

## 6. Complete Example: Alarm Notification System

```iecst
PROGRAM POU_AlarmEmail
VAR
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;

    (* Alarm states *)
    high_temp : BOOL;
    low_pressure : BOOL;
    e_stop : BOOL;

    (* Edge detection — send once per alarm *)
    high_temp_sent : BOOL := FALSE;
    low_press_sent : BOOL := FALSE;
    e_stop_sent : BOOL := FALSE;

    (* Throttle — one email per 5 minutes max *)
    email_throttle : STRING;
    ok : BOOL;
    body : STRING;

    (* Config *)
    smtp_host : STRING := 'smtp.company.com:587';
    smtp_user : STRING := 'plc-alerts@company.com';
    smtp_pass : STRING := 'app-password';
    from_addr : STRING := 'plc-alerts@company.com';
    to_addr : STRING := 'operators@company.com';
END_VAR

IF NOT initialized THEN
    email_throttle := THROTTLE_CREATE(300000);    (* 5 minute minimum between emails *)
    initialized := TRUE;
END_IF;

(* High temperature alarm *)
IF high_temp AND NOT high_temp_sent AND THROTTLE_ALLOW(email_throttle) THEN
    body := CONCAT(
        'HIGH TEMPERATURE ALARM', CHR(10), CHR(10),
        'Temperature: ', REAL_TO_STRING(temperature), ' F', CHR(10),
        'Threshold: 180 F', CHR(10),
        'Time: ', DT_TO_STRING(NOW()), CHR(10),
        'Location: Zone 3', CHR(10), CHR(10),
        'Please investigate immediately.'
    );

    ok := SMTP_SEND_AUTH(smtp_host, smtp_user, smtp_pass,
                         from_addr, to_addr,
                         'ALARM: High Temperature',
                         body);
    IF ok THEN high_temp_sent := TRUE; END_IF;
END_IF;

IF NOT high_temp THEN high_temp_sent := FALSE; END_IF;

(* E-stop alarm — always send, override throttle *)
IF e_stop AND NOT e_stop_sent THEN
    ok := SMTP_SEND_AUTH(smtp_host, smtp_user, smtp_pass,
                         from_addr, to_addr,
                         'CRITICAL: Emergency Stop Activated',
                         CONCAT('E-Stop activated at ', DT_TO_STRING(NOW())));
    IF ok THEN e_stop_sent := TRUE; END_IF;
END_IF;

IF NOT e_stop THEN e_stop_sent := FALSE; END_IF;

END_PROGRAM
```

---

## 7. Complete Example: Shift Report

```iecst
PROGRAM POU_ShiftReport
VAR
    state : INT := 0;
    scan_count : DINT := 0;
    report_interval : DINT := 288000;   (* Every 8 hours at 100ms scan *)
    ok : BOOL;
    report : STRING;
    total_parts : DINT;
    total_faults : INT;
    avg_temp : REAL;
    uptime_hrs : REAL;
END_VAR

scan_count := scan_count + 1;

IF (scan_count MOD report_interval) = 0 THEN
    report := CONCAT(
        'SHIFT REPORT - ', DT_TO_STRING(NOW()), CHR(10),
        '========================================', CHR(10),
        'Parts Produced: ', DINT_TO_STRING(total_parts), CHR(10),
        'Fault Count:    ', INT_TO_STRING(total_faults), CHR(10),
        'Avg Temp:       ', REAL_TO_STRING(avg_temp), ' F', CHR(10),
        'Uptime:         ', REAL_TO_STRING(uptime_hrs), ' hours', CHR(10),
        '========================================', CHR(10),
        'GoPLC Automated Report'
    );

    ok := SMTP_SEND_AUTH(
        'smtp.company.com:587',
        'plc-reports@company.com', 'app-password',
        'plc-reports@company.com',
        'production-team@company.com',
        CONCAT('Shift Report - ', DT_TO_STRING(NOW())),
        report
    );

    (* Reset shift counters *)
    IF ok THEN
        total_parts := 0;
        total_faults := 0;
    END_IF;
END_IF;
END_PROGRAM
```

---

## 8. Tips

- **Use app passwords** for Gmail, Office 365, etc. — regular passwords won't work with 2FA enabled.
- **Use SMTP_SEND for internal relay** — most plant networks have a local SMTP relay that doesn't require auth. Simpler and more reliable.
- **Use SMTP_SEND_TLS for external services** — encrypts credentials and content in transit.
- **Throttle alarm emails** — use `THROTTLE_CREATE` from the resilience library to prevent email storms.
- **Edge detect alarms** — send once when alarm activates, not every scan cycle.
- **Include context** — timestamp, tag values, thresholds, and location in every alarm email.

---

## Appendix A: Quick Reference

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `SMTP_SEND(host, from, to, subject, body)` | 5 | BOOL | Plain relay, no auth, port 25 |
| `SMTP_SEND_HTML(host, from, to, subject, html)` | 5 | BOOL | HTML body, no auth, port 25 |
| `SMTP_SEND_AUTH(host, user, pass, from, to, subject, body)` | 7 | BOOL | PLAIN auth, port 587 |
| `SMTP_SEND_TLS(host, user, pass, from, to, subject, body)` | 7 | BOOL | Implicit TLS, port 465 |

---

*GoPLC v1.0.535 | 4 SMTP Functions | Email Alerts from ST*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to All Guides](/docs/guides/)*
