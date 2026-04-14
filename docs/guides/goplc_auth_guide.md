# GoPLC Authentication, RBAC, Audit Trail, and Electronic Signatures

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.594

---

GoPLC ships an opt-in authentication stack with four built-in roles, a route-level role matrix enforced by middleware, a bcrypt-hashed user database persisted to SQLite, JWT bearer tokens signed with HMAC-SHA256, cookie-based browser fallback for IDE navigation, and a 21 CFR Part 11-style electronic signature layer that re-authenticates the user and forces a reason string before critical actions execute. Every auth event (login, failed login, user created/deleted, password changed, signature verified, signature failed) flows through the same event bus as alarms and protocols, so the audit trail is queryable through the `GET /api/events` endpoint, subscribable over MQTT and WebSocket, and routable to Slack, Teams, or PagerDuty without any extra code. Plus transparent pass-through to a ctrlX Identity Manager for plants that already have a single sign-on directory.

## 1. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      GoPLC HTTP API                          │
│                                                              │
│  Request ─► Middleware chain (gin)                           │
│             │                                                │
│             ▼                                                │
│  ┌──────────────────────┐                                    │
│  │  auth.Middleware     │  JWT bearer / cookie / trust_proxy │
│  │  pkg/auth/middleware │  ctrlX IDM fallback                │
│  └──────────┬───────────┘  sets auth_username + auth_role    │
│             │                                                │
│             ▼                                                │
│  ┌──────────────────────┐                                    │
│  │  auth.RBACMiddleware │  matches method + path against     │
│  │  pkg/auth/roles.go   │  permissionRules → min role check  │
│  └──────────┬───────────┘                                    │
│             │                                                │
│             ▼                                                │
│  ┌──────────────────────┐                                    │
│  │  ESignatureMiddleware│  critical actions require          │
│  │  pkg/auth/signature  │  X-Signature-User / Password /     │
│  │                      │  Reason → re-verify + emit event   │
│  └──────────┬───────────┘                                    │
│             │                                                │
│             ▼                                                │
│         Handler (protected by all three)                     │
│             │                                                │
│             └───► auth events fan out via pkg/events.Bus ───►│
│                     auth.login                               │
│                     auth.failed                              │
│                     auth.user_created / deleted              │
│                     auth.password_changed                    │
│                     auth.signature_verified / failed         │
│                     config.change                            │
└──────────────────────────────────────────────────────────────┘
```

Three middlewares, strictly ordered:

1. **`auth.Middleware`** validates the JWT (or the cookie, or the `X-Forwarded-For` when `trust_proxy` is on) and writes `auth_username` and `auth_role` into the Gin context. Public paths — HMI, login, health — are allowed through without auth. If the request is a browser page load (`Accept: text/html`) it gets redirected to `/login?redirect=<path>`; API calls get a `401`.
2. **`RBACMiddleware`** reads `auth_role` and compares it against the minimum role required by the first matching rule in `permissionRules`. Returns `403 forbidden` with `role` + `required` in the body if the user is underprivileged.
3. **`ESignatureMiddleware`** catches the configured critical-action routes, requires the three `X-Signature-*` headers, re-verifies the password against the bcrypt hash, and emits `auth.signature_verified` or `auth.signature_failed`. Only after all three pass does the request reach the handler.

All four subsystems (JWT, RBAC, e-signature, audit) are optional and independent. You can run with auth on but RBAC off (single role for everyone), or RBAC on without e-signatures (no re-auth for critical actions), or the ctrlX Identity Manager forwarding mode without any local users at all.

## 2. Roles and privilege levels

Four built-in roles, ordered by privilege:

| Role | Level | Can do |
|------|-------|--------|
| `viewer` | 0 | Read any `GET` endpoint. No writes, no control. Audit log reader. |
| `operator` | 1 | Everything viewer can + acknowledge alarms, write variables and tags, flush RETAIN. |
| `engineer` | 2 | Everything operator can + create/update/delete programs and tasks, runtime start/stop/reload, debug endpoints, project deploy/import, read config. |
| `admin` | 3 | Everything engineer can + user management, system shutdown/restart, license management, config writes (`POST` / `PUT` / `DELETE /api/config`). |

The hierarchy is linear — a higher role can always do everything a lower role can. You cannot customize role names, add a fifth role, or rewire the privilege levels at runtime; these are compiled into `pkg/auth/auth.go` and `pkg/auth/roles.go`.

## 3. The route permission matrix

`RBACMiddleware` walks `permissionRules` top to bottom and uses the **first matching** rule's minimum level. More-specific rules live earlier in the list. Unmatched `GET` requests fall through to the final "`GET /api/` → viewer" catch-all; unmatched non-GET requests fall through to viewer as well (0), but since no handler allows viewer to write, they'll simply 404 out of the handler.

| Method + path prefix | Minimum role | Notes |
|----------------------|--------------|-------|
| `/api/auth/login`, `/api/auth/status`, `/api/auth/refresh`, `/api/auth/logout` | viewer | These are also in `isPublicPath` so unauthenticated requests reach them. |
| `* /api/auth/users` | admin | User management. |
| `POST /api/system/shutdown`, `POST /api/system/restart`, `POST /api/license` | admin | Destructive system operations. |
| `POST / PUT / DELETE /api/config` | admin | Config writes. |
| `GET /api/config` | engineer | Reading the full config can reveal JWT secrets, DB paths, etc. |
| `POST / PUT / DELETE /api/programs` | engineer | Program CRUD. |
| `POST / PUT / DELETE /api/tasks` | engineer | Task CRUD. |
| `POST /api/runtime` | engineer | Runtime start/stop/reload. |
| `POST / GET /api/debug` | engineer | Breakpoints, single-step, watches. |
| `POST /api/project` | engineer | Project deploy/import. |
| `POST /api/alarms` | operator | Acknowledge, shelve, enable, disable. Does not cover `DELETE /api/alarms/:name` — that's engineer-only implicitly via the final rule. |
| `POST / PUT /api/variables`, `POST / PUT /api/tags` | operator | HMI setpoint writes. |
| `POST /api/system/retain` | operator | RETAIN flush. |
| `GET /api/...` (catch-all) | viewer | Everything else readable. |

The catch-all at the bottom deliberately gives viewer access to every unmapped `GET`. When you add a new read-only endpoint in a new feature, it's automatically viewer-accessible without touching `roles.go`. When you add a new write endpoint, you must add an explicit rule — otherwise it silently falls through to viewer and becomes an unauthenticated-level vulnerability.

## 4. Configuration

Three blocks live under `auth:` in `config.yaml`. All three are optional; omitting the block entirely is equivalent to `enabled: true` with RBAC and e-sig off.

```yaml
auth:
  enabled: true
  token_expiry_hours: 24           # JWT lifetime — default 24 h
  jwt_secret: ""                    # HMAC-SHA256 secret — autogenerated if empty (tokens don't survive restart)
  trust_proxy: false                # when true, X-Forwarded-For requests bypass auth as "proxy" / admin
  ctrlx_auth: false                 # when true, fall through to ctrlX Identity Manager on local auth failure
  ctrlx_url: "https://localhost"    # ctrlX IDM base URL
  users: []                          # optional seed list (migrated into SQLite on first run, then edited via API)

  rbac:
    enabled: true                    # turn on the role matrix — off = all authenticated users are effectively admin
    default_role: viewer             # role assigned to users created without an explicit role

  electronic_signatures:
    enabled: true
    critical_actions:                # only routes on this list require the e-sig headers
      - runtime_stop
      - runtime_start
      - program_delete
      - config_change
      - user_delete
      - system_shutdown
      - system_restart
      - task_delete
```

Four things about this block:

**JWT secret.** An empty `jwt_secret` makes the manager generate a random 32-byte secret at boot. Tokens signed with the boot-time secret die on the next restart. For multi-node deployments or production sites, set a fixed secret from a key store or vault — you can generate one with `goplc auth gen-secret` (the built-in subcommand calls `GenerateRandomSecret()`).

**trust_proxy.** Turn this on when running behind a ctrlX Caddy proxy or any other reverse proxy that has already authenticated the user. Any request bearing an `X-Forwarded-For` header is accepted as the pseudo-user `"proxy"` with role `admin`. Do *not* turn this on if the PLC is directly reachable on the network — the header is trivial to forge.

**ctrlX fallback.** Set `ctrlx_auth: true` to forward local auth failures to the ctrlX Identity Manager at `<ctrlx_url>/identity-manager/api/v2/auth/token`. GoPLC uses `tls.Config.InsecureSkipVerify` to tolerate the ctrlX self-signed cert. A successful ctrlX auth mints a GoPLC-signed JWT with role `operator` — the user doesn't get persisted locally.

**Config-seeded users.** Any user listed under `auth.users` gets migrated into SQLite (`data/auth.db`) with role `admin` on first boot. After that, the config list is ignored — subsequent edits go through the API. If no users are configured and `ctrlx_auth` is off, GoPLC creates a default admin user `goplc` / `goplc` and logs the action. **Change this immediately** on any deployed system.

## 5. Users, bcrypt, persistence

Users are stored in `<data_dir>/auth.db` — a WAL-mode SQLite database in the runtime's data directory. The schema:

```sql
CREATE TABLE users (
    id          INTEGER PRIMARY KEY,
    username    TEXT UNIQUE NOT NULL,
    password    TEXT NOT NULL,       -- bcrypt hash, cost 10 (bcrypt.DefaultCost)
    role        TEXT NOT NULL DEFAULT 'viewer',
    email       TEXT DEFAULT '',
    created_at  TEXT DEFAULT (datetime('now')),
    created_by  TEXT DEFAULT '',
    locked      INTEGER DEFAULT 0,
    last_login  TEXT
);
```

Passwords are never stored in plaintext, never logged, and never returned from the API. The in-memory cache (`users map[string]*userEntry`) holds the bcrypt hash and the role — that's it. If the runtime cannot open `auth.db` at boot (permissions, disk full), it falls back to an in-memory-only mode and prints a warning; user changes in that mode are lost at shutdown.

The `locked` column and the `email` column are surfaced in `GET /api/auth/users` but not yet enforced by the authenticator — they are admin metadata for now. A `locked: true` user can still log in until the lockout policy spec lands.

## 6. REST API — login, users, refresh, logout

All auth routes live under `/api/auth/*`. The login, status, refresh, and logout routes are on the public path list, so unauthenticated requests can reach them. User management requires authentication.

### 6.1 Login

```bash
curl -X POST http://host:port/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"s3cret"}'
```

Response:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIi...",
  "expires_at": "2026-04-14T12:00:00Z",
  "username": "alice",
  "role": "engineer"
}
```

A failed login emits an `auth.failed` event at `warning` severity with the username, client IP, and the underlying reason string. A successful login emits `auth.login` at `info` severity with the username, client IP, and the token expiry time. Both events include the client IP as reported by `c.ClientIP()`, which honors `X-Forwarded-For` when `trust_proxy` is on.

### 6.2 Status — "am I logged in?"

```bash
curl -H 'Authorization: Bearer <token>' http://host:port/api/auth/status
```

Returns:

```json
{
  "enabled": true,
  "authenticated": true,
  "username": "alice",
  "role": "engineer"
}
```

When auth is disabled entirely, `enabled: false` and `authenticated: false`. When the token is missing or expired, `authenticated: false` with an empty username. The status endpoint also accepts the token via a cookie named `goplc_token` — that's the path the browser-based IDE uses for page navigation.

### 6.3 Refresh

```bash
curl -X POST \
  -H 'Authorization: Bearer <old-token>' \
  http://host:port/api/auth/refresh
```

Returns a new token with a fresh 24-hour expiry (or whatever `token_expiry_hours` is configured to). The refresh endpoint is authentication-protected — an expired token cannot refresh itself. Clients that want sliding sessions should refresh a few minutes before expiry, not on `401`.

### 6.4 Logout

```bash
curl -X POST \
  -H 'Authorization: Bearer <token>' \
  http://host:port/api/auth/logout
```

JWT is stateless, so logout is a client-side operation — the server just acknowledges. Web clients clear `localStorage` and the `goplc_token` cookie. The token remains valid until its expiry; if you need immediate invalidation across the fleet (user termination, credential compromise), rotate `jwt_secret` and restart all runtimes.

### 6.5 User management

```bash
# List users (admin only)
curl -H 'Authorization: Bearer <admin-token>' http://host:port/api/auth/users

# Create a user
curl -X POST -H 'Authorization: Bearer <admin-token>' \
  -H 'Content-Type: application/json' \
  -d '{"username":"bob","password":"t3mp!"}' \
  http://host:port/api/auth/users

# Change a password
curl -X PUT -H 'Authorization: Bearer <admin-token>' \
  -H 'Content-Type: application/json' \
  -d '{"password":"n3w-s3cret"}' \
  http://host:port/api/auth/users/bob/password

# Delete a user
curl -X DELETE -H 'Authorization: Bearer <admin-token>' \
  http://host:port/api/auth/users/bob
```

Every user-management mutation emits a corresponding bus event:

- `POST /api/auth/users` → `auth.user_created` at `info`
- `PUT /api/auth/users/:username/password` → `auth.password_changed` at `info`
- `DELETE /api/auth/users/:username` → `auth.user_deleted` at `warning`

All three events include the acting admin's username (from the JWT), the target username, and the client IP in the event payload. The event is emitted after the mutation commits, so a failed delete does not produce a `user_deleted` event.

Note that `AddUser` via the API creates the user with role `viewer` regardless of the `default_role` config setting. To create a user with a different role, either set the role post-create via `SetUserRole` (currently only exposed via the Go API, not the REST API), or use the CLI.

## 7. Electronic signatures (21 CFR Part 11)

`ESignatureMiddleware` intercepts configured critical actions and requires three HTTP headers on top of the normal JWT. Failing the check returns `403` and emits `auth.signature_failed`; passing emits `auth.signature_verified`.

### 7.1 Which actions are critical

Only the actions listed under `auth.electronic_signatures.critical_actions` get the e-sig check. The mapping from action name to method + path prefix is compiled into `signature.go` and cannot be changed at runtime:

| Action name | HTTP method | Path prefix |
|-------------|-------------|-------------|
| `runtime_stop` | POST | `/api/runtime/stop` |
| `runtime_start` | POST | `/api/runtime/start` |
| `program_delete` | DELETE | `/api/programs/` |
| `config_change` | PUT | `/api/config/` |
| `user_delete` | DELETE | `/api/auth/users/` |
| `system_shutdown` | POST | `/api/system/shutdown` |
| `system_restart` | POST | `/api/system/restart` |
| `task_delete` | DELETE | `/api/tasks/` |

If you omit an action from the config list, that route is *not* subject to the e-sig check — it goes straight through the RBAC gate to the handler. This means disabling e-sig for a single action is a config edit, not a code change.

Note that the e-sig middleware does not cover every destructive operation. It is designed for the narrow set of "user intent must be positively re-verified" actions mandated by 21 CFR Part 11, not as a general-purpose confirmation layer. The alarm acknowledge path, for example, is deliberately not on the list — every ack already carries the authenticated user as the `acked_by` field, which is sufficient for audit.

### 7.2 The three required headers

```bash
curl -X DELETE \
  -H 'Authorization: Bearer <engineer-jwt>' \
  -H 'X-Signature-Username: alice' \
  -H 'X-Signature-Password: her-real-password' \
  -H 'X-Signature-Reason: Removing deprecated Program3 per CR-2026-118' \
  http://host:port/api/programs/Program3
```

| Header | Meaning |
|--------|---------|
| `X-Signature-Username` | The user who is signing. Does **not** have to be the same as the JWT subject — this is the "second person" sign-off pattern. A supervisor can authorize an engineer's deletion. |
| `X-Signature-Password` | The signing user's password, re-verified against their bcrypt hash. |
| `X-Signature-Reason` | Free-text reason. Stored in the audit event payload verbatim. Required — an empty string fails the check. |

The re-verification uses the same bcrypt path as the login flow — it reads the hash from the in-memory cache (backed by SQLite) and calls `bcrypt.CompareHashAndPassword`. There is no rate limit on e-sig attempts; the caller is already authenticated via the JWT.

### 7.3 The emitted events

Every e-sig attempt (success or failure) emits a bus event with the action, the signing user, the reason, and the acting user's JWT subject and IP. Success:

```json
{
  "id": "...",
  "timestamp": "2026-04-13T14:22:01.512Z",
  "type": "auth.signature_verified",
  "severity": "info",
  "source": "esig",
  "message": "e-sig verified: alice authorized program_delete (Removing deprecated Program3 per CR-2026-118)",
  "data": {
    "action": "program_delete",
    "sig_user": "alice",
    "reason": "Removing deprecated Program3 per CR-2026-118",
    "path": "/api/programs/Program3",
    "actor": "alice",
    "ip": "10.0.0.196"
  }
}
```

Failure looks identical but with `type: auth.signature_failed`, severity `warning`, and a different message. A subscriber can filter for `auth.signature_*` and route all e-sig activity to a tamper-evident log destination — S3 with Object Lock, a write-once compliance archive, or a PagerDuty with `min_severity: warning` to get paged on failures.

## 8. The audit trail via events

Every authentication-related and config-changing event rides the same bus as alarms and protocol events. There is no separate audit log file, no separate database, no separate API — the audit trail is `GET /api/events?type=auth.*`.

### 8.1 Event types

| Type | Severity | Source | Payload highlights |
|------|----------|--------|-------------------|
| `auth.login` | info | `auth:login` | `username`, `ip`, `expires_at` |
| `auth.failed` | warning | `auth:login` | `username`, `ip`, `reason` |
| `auth.user_created` | info | `auth` | `actor`, `target_user`, `ip` |
| `auth.user_deleted` | warning | `auth` | `actor`, `target_user`, `ip` |
| `auth.password_changed` | info | `auth` | `actor`, `target_user`, `ip` |
| `auth.signature_verified` | info | `esig` | `action`, `sig_user`, `reason`, `path`, `actor`, `ip` |
| `auth.signature_failed` | warning | `esig` | same as above |
| `config.change` | info | `config` | `section`, `username`, `ip`, `bytes_before`, `bytes_after` |

`config.change` is not in `pkg/auth/` — it's emitted by `pkg/api/handlers/tasks.go` and other config-mutating handlers. It is included here because it completes the audit picture: every change to task configs, runtime settings, or other reloadable state ends up in the events log as an attributable edit.

### 8.2 Querying the audit trail

```bash
# Last 100 auth events
curl -H 'Authorization: Bearer <admin>' \
  'http://host:port/api/events?type=auth.*&limit=100'

# Every failed login in the last 24 hours
curl -H 'Authorization: Bearer <admin>' \
  'http://host:port/api/events?type=auth.failed&start=2026-04-12T00:00:00Z'

# Who deleted what
curl -H 'Authorization: Bearer <admin>' \
  'http://host:port/api/events?type=auth.user_deleted'

# Every e-sig attempt (success and failure)
curl -H 'Authorization: Bearer <admin>' \
  'http://host:port/api/events?type=auth.signature_*'

# Full config-change audit, piped through jq
curl -s -H 'Authorization: Bearer <admin>' \
  'http://host:port/api/events?type=config.change&limit=500' | \
  jq '.events[] | {ts: .timestamp, user: .data.username, section: .data.section, ip: .data.ip}'
```

The `GET /api/events` endpoint supports `type` with `*` wildcards, `severity`, `min_severity`, `source`, `start`, `end`, and `limit`. It reads from the bus's SQLite store (`events.db`), so results are retained for `events.log.max_age_days` days (default 90). For longer retention, pipe the events into a historian or an external log sink via webhooks.

### 8.3 Live streaming audit

```bash
# Subscribe to every auth event over MQTT
mosquitto_sub -h 127.0.0.1 -p 1883 -t 'goplc/events/auth.#' -v

# Subscribe to signature events over WebSocket
wscat -c 'ws://host:port/api/events/stream'
# … then filter client-side for type starting with "auth.signature_"
```

The MQTT topic prefix is whatever you configured in `events.mqtt.topic_prefix` (default `goplc/events`). Subscribing to `goplc/events/auth.#` gets all auth events live as they happen.

## 9. Reacting to auth events from ST

Because auth events are ordinary bus events, ST code can query them with the same builtins you'd use for protocol or alarm events. The typical use case: force a safe state when a critical action is denied or when a suspicious pattern appears in the audit log.

```iec
PROGRAM SecurityWatch
VAR
    recent_failures : DINT;
    alarm_state     : DINT;
    lockdown        : BOOL := FALSE;
END_VAR

    (* Count failed logins in the last 5 minutes *)
    recent_failures := EVENT_COUNT('auth.failed', 300000);

    IF recent_failures > 10 AND NOT lockdown THEN
        lockdown := TRUE;
        (* Trip a BOOL alarm that the HMI banner listens for *)
        ALARM_CREATE_BOOL('auth_lockdown', 'securitywatch.lockdown', 1);
        NOTIFY_CRITICAL('More than 10 failed logins in 5 minutes — possible brute force');
    END_IF;
END_PROGRAM
```

Pair that with an alarm definition in YAML so the SCADA banner lights up and a PagerDuty webhook fires. No new auth primitives needed — the events bus is the single ingress and egress.

## 10. Deployment patterns

### 10.1 Small site — local users only

Simplest. No directory server, a handful of users, auth.db persistent across reboots. Start with a seed admin in `config.yaml`, rotate to API-managed users after first boot.

```yaml
auth:
  enabled: true
  jwt_secret: "0f29...7c4a"        # fixed — from a key file checked into ops, not git
  users:
    - username: admin
      password_hash: "$2a$10$..."   # bcrypt, generated by `goplc auth hash-password`
  rbac:
    enabled: true
  electronic_signatures:
    enabled: false                   # turn on only if compliance requires
```

### 10.2 Compliance-regulated site — e-sig + audit retention

Full 21 CFR Part 11 posture: RBAC on, e-sig on every destructive action, the events log pointed at a long-retention SQLite and fanned out to a write-once archive.

```yaml
auth:
  enabled: true
  jwt_secret: "${GOPLC_JWT_SECRET}"  # from environment
  rbac:
    enabled: true
    default_role: viewer
  electronic_signatures:
    enabled: true
    critical_actions:
      - runtime_stop
      - runtime_start
      - program_delete
      - config_change
      - user_delete
      - system_shutdown
      - system_restart
      - task_delete

events:
  enabled: true
  log:
    enabled: true
    database: "data/events.db"
    max_age_days: 3650               # 10 years — Part 11 minimum retention
  webhooks:
    - name: "compliance-archive"
      url: "https://s3.internal/goplc-audit/events"
      format: "generic"
      secret: "${ARCHIVE_HMAC_SECRET}"
      event_types: ["auth.*", "config.change", "alarm.ack"]
      min_severity: "info"
      retry_count: 10                # never drop a compliance event
```

The HMAC signing on the archive webhook means the receiver can prove every event came from the PLC and hasn't been tampered with in transit; pair with S3 Object Lock (or equivalent) for at-rest immutability.

### 10.3 ctrlX integration — single sign-on via Identity Manager

Running GoPLC as a ctrlX snap on an X3 PLC. The Caddy reverse proxy handles the front-door auth; GoPLC trusts the proxy and enforces RBAC internally.

```yaml
auth:
  enabled: true
  trust_proxy: true                  # accept X-Forwarded-For as pre-authenticated
  rbac:
    enabled: false                   # the ctrlX front door does role gating
```

Or, alternatively, use the local RBAC on top of ctrlX-minted JWTs:

```yaml
auth:
  enabled: true
  ctrlx_auth: true
  ctrlx_url: "https://localhost"
  rbac:
    enabled: true
```

In this second mode, ctrlX users are authenticated via the `identity-manager/api/v2/auth/token` endpoint; if that succeeds, GoPLC mints its own JWT with role `operator`. They can read everything a viewer can, acknowledge alarms, and write variables — but not edit programs or run `runtime_stop` without re-authentication through a local engineer account.

## 11. Recipes

### 11.1 Browser-based IDE login (the default cookie flow)

The IDE doesn't use the `Authorization: Bearer` header for page navigation — browsers can't inject headers on `window.location.href`. Instead, a successful `POST /api/auth/login` stores the token in a cookie named `goplc_token` (via JavaScript, not a `Set-Cookie` response), and subsequent page loads find the cookie in `auth.Middleware` via `c.Cookie("goplc_token")`.

The login page is at `/login` (public) and redirects to `?redirect=<requested-path>` if the middleware bounces an unauthenticated browser request. The client-side code in `web/login.html` handles the cookie set and the redirect.

### 11.2 Scripted API access with a long-lived service account

Create a dedicated service account via the API once, then store the JWT somewhere safe and refresh it nightly:

```bash
# One-time setup (as an admin)
curl -X POST -H 'Authorization: Bearer <admin>' \
  -H 'Content-Type: application/json' \
  -d '{"username":"deploy-bot","password":"'"$(openssl rand -hex 32)"'"}' \
  http://host:port/api/auth/users

# Daily refresh from the scripted client
TOKEN=$(curl -sX POST http://host:port/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"deploy-bot","password":"'"$BOT_PASSWORD"'"}' \
  | jq -r .token)

# Then use $TOKEN on subsequent calls
curl -H "Authorization: Bearer $TOKEN" http://host:port/api/variables/
```

Raise the service account to `engineer` or `admin` via `SetUserRole` (Go API or a future `PUT /api/auth/users/:username/role` endpoint — currently only settable via the CLI). The default role after `AddUser` is `viewer`, which is read-only.

### 11.3 Executing a critical action with e-sig

```bash
# Required: the caller's JWT + the signer's re-auth + a reason
curl -X POST http://host:port/api/runtime/stop \
  -H 'Authorization: Bearer <engineer-jwt>' \
  -H 'X-Signature-Username: supervisor' \
  -H 'X-Signature-Password: '"$SUPERVISOR_PASSWORD"'' \
  -H 'X-Signature-Reason: Emergency shutdown for unscheduled PM on pump 3'
```

The acting engineer is the JWT subject; the signing supervisor is the `X-Signature-Username`. Both are recorded in the `auth.signature_verified` event under `actor` and `sig_user` respectively. The reason is attached verbatim.

### 11.4 Rotating the JWT secret without downtime

Not possible. JWT is stateless — all existing tokens would be invalidated at the moment of rotation, and the handler has no way to re-sign them. The rotation procedure is:

1. Push the new secret to config.
2. Restart the runtime (on a single-node site) or restart nodes one at a time (on a cluster) to pick up the new secret.
3. Every user re-logs in, picking up a freshly-signed token.

If you need hot rotation, run a key-store-backed JWT library; the in-tree implementation is deliberately simple and deployment-scale-appropriate.

## 12. Security notes

- **Passwords are bcrypt, not PBKDF2 or Argon2.** Cost factor 10 (the `bcrypt.DefaultCost` constant). This is adequate for modern hardware; if you need to raise the cost factor, it's a one-line change in `pkg/auth/auth.go` but requires re-hashing every user's password on their next login.
- **JWT uses HS256, not RS256.** The secret is shared between all middleware instances; there is no public/private key split. Good enough for a single runtime or a small cluster, not appropriate for a multi-tenant federation.
- **`X-Forwarded-For` is trusted without verification when `trust_proxy` is on.** Only enable this when the PLC is physically behind a reverse proxy on a trusted network. Any client that can reach the PLC directly can forge the header.
- **ctrlX fallback uses `InsecureSkipVerify: true`** — the TLS cert from the local ctrlX IDM is not validated. This is appropriate only inside the ctrlX snap environment where the target is `https://localhost`. Never set `ctrlx_url` to a remote host.
- **The `goplc` / `goplc` default user** is created on first boot when no users are configured and `ctrlx_auth` is off. Log message warns. Change it before exposing the API to anything.
- **Failed e-sig attempts are logged but not counted.** There is no lockout after N failures. A rate limit is a backlog item; for now, pair with an upstream WAF or fail2ban if you need rate limiting.
- **JWT secrets in config.yaml are readable by anyone with `GET /api/config`** — and `/api/config` is engineer-gated, not admin. Consider either raising the rule to admin or pulling the secret from an environment variable and leaving the YAML field empty.

## 13. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Every request returns `401 unauthorized` after a runtime restart | `jwt_secret` was empty and got regenerated | Set a fixed `jwt_secret` in config so tokens survive restarts, or have clients re-login on 401. |
| `auth.login` event fires but subsequent API call returns `401` | JWT secret differs between the login handler and the middleware | Should be impossible; if you see this, clock skew between host and client is a possible cause — check the `iat` vs `exp` in the token. |
| User created via `POST /api/auth/users` is always `viewer` even though `default_role: engineer` | `AddUser` hardcodes `RoleViewer` | Use `SetUserRole` after creation, or wait for the role-aware create endpoint. |
| Logins succeed locally but ctrlX fallback never fires | The local username exists (even locked), so the fallback branch is skipped | Delete the local entry, or rename it so the login name only matches ctrlX. |
| `trust_proxy` mode not honoring role from the proxy | Headers with role aren't consumed — only `X-Forwarded-For` presence is checked | The pseudo-user `proxy` gets role `admin`. If you need granular roles via the proxy, emit your own JWT upstream and use the bearer path. |
| e-sig fails with "electronic_signature_failed" even though password is right | Wrong field name on the header — it's `X-Signature-Password` not `X-ESig-Password` | Use the exact headers: `X-Signature-Username`, `X-Signature-Password`, `X-Signature-Reason`. |
| Audit trail missing `config.change` events for task edits | The task handler emits `config.change`; the alarms handler does not | Expected — alarms emit their own `alarm.*` events instead of `config.change`. Filter accordingly. |
| `/api/events?type=auth.*` returns fewer events than expected | Events are subject to the bus's dedup window | Check `events.bus.dedup_window_ms`; set to `0` to disable dedup for audit purposes (at the cost of emission amplification on protocol flap). |

## 14. Related

- [`goplc_events_guide.md`](goplc_events_guide.md) — the event bus every auth event rides on, plus webhook and MQTT fan-out for audit trail delivery.
- [`goplc_alarms_guide.md`](goplc_alarms_guide.md) — the alarm engine that surfaces an `auth_lockdown` condition to the HMI banner.
- [`goplc_api_guide.md`](goplc_api_guide.md) — REST and WebSocket fundamentals, Swagger UI, bearer-token conventions.
- [`goplc_config_guide.md`](goplc_config_guide.md) — the full `config.yaml` reference including the `auth:` block schema.
- [`goplc_clustering_guide.md`](goplc_clustering_guide.md) — how JWT secrets and user databases interact in a boss + minions deployment.
