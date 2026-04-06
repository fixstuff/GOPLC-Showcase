# GoPLC Cryptography & Security Guide

**James M. Belcher**
Founder, JMB Technical Services LLC
April 2026 | GoPLC v1.0.535

---

## 1. Overview

GoPLC provides ~55 built-in functions for cryptography, hashing, encoding, and authentication from Structured Text. Secure API calls, sign data, encrypt files, generate and verify JWTs, and validate checksums — all without external libraries.

| Category | Functions | Use Case |
|----------|-----------|----------|
| **Hashing** | 10 | Data integrity, fingerprinting, checksums |
| **HMAC** | 5 | Message authentication, webhook signatures |
| **AES Encryption** | 6 | Symmetric encryption (CBC, GCM) |
| **RSA** | 5 | Asymmetric encryption, digital signatures |
| **Base64** | 6 | Encoding binary data for transport |
| **JWT** | 12 | Token-based authentication |
| **Utility** | 8 | Key generation, constant-time compare, file encryption |

---

## 2. Hashing

One-way hash functions — input to fixed-length digest. Cannot be reversed.

```iecst
(* SHA-256 — most common, 64 hex chars *)
hash := SHA256('Hello World');
(* "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e" *)

(* SHA-512 — longer, stronger *)
hash := SHA512('Hello World');

(* MD5 — legacy, use SHA256 for new work *)
hash := MD5('Hello World');

(* SHA-1 — deprecated for security, still used in Git *)
hash := SHA1('Hello World');

(* SHA-384 — truncated SHA-512 *)
hash := SHA384('Hello World');
```

All return hex-encoded strings. For raw byte arrays:

```iecst
bytes := SHA256_BYTES('Hello World');    (* Array of integers *)
bytes := MD5_BYTES('Hello World');
```

### Checksums

```iecst
(* CRC-32 — file integrity, Ethernet *)
crc := CRC32(data);

(* CRC-16 — generic *)
crc := CRC16(data);

(* CRC-16/Modbus — Modbus RTU frame validation *)
crc := CRC16_MODBUS(frame_data);
```

---

## 3. HMAC — Message Authentication

Hash-based Message Authentication Code — proves a message was created by someone with the secret key.

```iecst
(* Sign a webhook payload *)
signature := HMAC_SHA256('my-secret-key', payload);

(* Verify incoming webhook *)
expected := HMAC_SHA256(webhook_secret, request_body);
IF HASH_EQUALS(expected, received_signature) THEN
    (* Authentic — process webhook *)
END_IF;
```

| Function | Returns | Description |
|----------|---------|-------------|
| `HMAC_SHA256(key, message)` | STRING (hex) | SHA-256 HMAC |
| `HMAC_SHA512(key, message)` | STRING (hex) | SHA-512 HMAC |
| `HMAC_SHA1(key, message)` | STRING (hex) | SHA-1 HMAC |
| `HMAC_MD5(key, message)` | STRING (hex) | MD5 HMAC |
| `HMAC_SHA256_BASE64(key, message)` | STRING (base64) | SHA-256 HMAC, base64-encoded |

> **Always use HASH_EQUALS for comparison** — never use `=` to compare hashes. `HASH_EQUALS` uses constant-time comparison to prevent timing attacks.

---

## 4. AES Encryption

Symmetric encryption — same key encrypts and decrypts. Three modes available:

| Mode | Functions | Use Case |
|------|-----------|----------|
| **AES (default)** | `AES_ENCRYPT` / `AES_DECRYPT` | General purpose |
| **AES-CBC** | `AES_CBC_ENCRYPT` / `AES_CBC_DECRYPT` | Block cipher, IV auto-generated |
| **AES-GCM** | `AES_GCM_ENCRYPT` / `AES_GCM_DECRYPT` | Authenticated encryption (recommended) |

```iecst
(* Generate a random key *)
key := GENERATE_KEY(32);     (* 256-bit key, base64-encoded *)

(* Encrypt *)
encrypted := AES_GCM_ENCRYPT('sensitive data', key);

(* Decrypt *)
plaintext := AES_GCM_DECRYPT(encrypted, key);
(* "sensitive data" *)
```

The IV/nonce is automatically generated and prepended to the ciphertext. Output is base64-encoded.

```iecst
(* AES-CBC mode *)
encrypted := AES_CBC_ENCRYPT('secret message', key);
plaintext := AES_CBC_DECRYPT(encrypted, key);

(* Default AES mode *)
encrypted := AES_ENCRYPT('secret message', key);
plaintext := AES_DECRYPT(encrypted, key);
```

> **Use AES-GCM** for new applications — it provides both encryption and authentication (detects tampering). CBC provides encryption only.

---

## 5. RSA — Asymmetric Encryption

Public key encrypts, private key decrypts. Also used for digital signatures.

### Generate Key Pair

```iecst
keys := RSA_GENERATE_KEYPAIR(2048);     (* 2048-bit keys *)

private_key := JSON_GET_STRING(keys, 'private');   (* PEM-encoded *)
public_key := JSON_GET_STRING(keys, 'public');     (* PEM-encoded *)

(* Store keys *)
FILE_WRITE('/data/private.pem', private_key);
FILE_WRITE('/data/public.pem', public_key);
```

### Encrypt / Decrypt

```iecst
(* Encrypt with public key — anyone can encrypt *)
encrypted := RSA_ENCRYPT('secret message', public_key);

(* Decrypt with private key — only key holder can decrypt *)
plaintext := RSA_DECRYPT(encrypted, private_key);
```

### Sign / Verify

```iecst
(* Sign with private key — proves authenticity *)
signature := RSA_SIGN('important data', private_key);

(* Verify with public key — anyone can verify *)
valid := RSA_VERIFY('important data', signature, public_key);
IF valid THEN
    (* Signature is authentic *)
END_IF;
```

---

## 6. Base64 Encoding

Encode binary data as ASCII text for safe transport in JSON, HTTP headers, and URLs.

```iecst
(* Standard Base64 *)
encoded := BASE64_ENCODE('Hello World');     (* "SGVsbG8gV29ybGQ=" *)
decoded := BASE64_DECODE(encoded);           (* "Hello World" *)

(* URL-safe Base64 (no padding, safe for URLs) *)
encoded := BASE64_URL_ENCODE('Hello World');
decoded := BASE64_URL_DECODE(encoded);

(* Byte array variants *)
encoded := BASE64_ENCODE_BYTES(byte_array);
bytes := BASE64_DECODE_BYTES(encoded);
```

B64_* aliases also available: `B64_ENCODE`, `B64_DECODE`, `B64_URL_ENCODE`, `B64_URL_DECODE`, `B64_ENCODE_BYTES`, `B64_DECODE_BYTES`.

---

## 7. JWT — JSON Web Tokens

Create, validate, and manage authentication tokens.

### Create a Token

```iecst
(* Build claims *)
claims := JWT_CREATE_CLAIMS(
    'user-123',           (* subject *)
    'goplc',              (* issuer *)
    'plant-api',          (* audience *)
    3600                  (* expires in 1 hour *)
);

(* Add custom claims *)
claims := JWT_ADD_CLAIM(claims, 'role', 'operator');
claims := JWT_ADD_CLAIM(claims, 'plant', 'Plant-A');

(* Encode to JWT string *)
token := JWT_ENCODE(claims, 'my-secret-key');
(* "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ..." *)
```

### Validate a Token

```iecst
(* Quick verify — signature only *)
valid := JWT_VERIFY(token, 'my-secret-key');

(* Full validation — signature + expiry + issuer + audience *)
result := JWT_VALIDATE(token, 'my-secret-key', 'goplc', 'plant-api');
IF JSON_GET_BOOL(result, 'valid') THEN
    payload := JSON_GET(result, 'payload');
ELSE
    error := JSON_GET_STRING(result, 'error');
END_IF;
```

### Read Token Data

```iecst
(* Get a specific claim *)
role := JWT_GET_CLAIM(token, 'role');         (* "operator" *)
sub := JWT_GET_CLAIM(token, 'sub');           (* "user-123" *)

(* Get all claims *)
all := JWT_GET_ALL_CLAIMS(token);

(* Get header info *)
alg := JWT_GET_HEADER(token, 'alg');          (* "HS256" *)

(* Check expiry *)
IF JWT_IS_EXPIRED(token) THEN
    (* Token expired — refresh or reject *)
END_IF;

remaining := JWT_TIME_TO_EXPIRY(token);       (* Seconds until expiry *)
```

### Refresh a Token

```iecst
(* Create new token with fresh expiry, same claims *)
new_token := JWT_REFRESH(token, 'my-secret-key', 3600);
```

### Decode Without Verification

```iecst
(* Decode (does NOT verify signature — for inspection only) *)
parts := JWT_DECODE(token);
(* Returns: {header: {...}, payload: {...}, signature: "..."} *)
```

---

## 8. Utility Functions

### Key and IV Generation

```iecst
(* Generate random encryption key — default 32 bytes (256-bit) *)
key := GENERATE_KEY();
key := GENERATE_KEY(16);       (* 128-bit key *)

(* Generate random initialization vector — 16 bytes *)
iv := GENERATE_IV();
```

Aliases: `RANDOM_KEY()`, `RANDOM_IV()`

### Constant-Time Comparison

```iecst
(* ALWAYS use for comparing hashes/secrets — prevents timing attacks *)
match := HASH_EQUALS(computed_hash, expected_hash);
match := SECURE_COMPARE(a, b);     (* Alias *)

(* Verify a hash against data *)
valid := HASH_VERIFY('sha256', data, expected_hash);
```

### File Encryption

```iecst
(* Encrypt a file in place *)
ok := ENCRYPT_FILE('/data/sensitive.csv', encryption_key);

(* Decrypt a file in place *)
ok := DECRYPT_FILE('/data/sensitive.csv', encryption_key);
```

---

## 9. Complete Example: Secure API Client

Authenticate with JWT and sign requests with HMAC:

```iecst
PROGRAM POU_SecureAPI
VAR
    state : INT := 0;
    token : STRING;
    claims : STRING;
    api_key : STRING := 'my-api-secret';
    payload : STRING;
    signature : STRING;
    hdrs : STRING;
    resp : STRING;
END_VAR

CASE state OF
    0: (* Create JWT for authentication *)
        claims := JWT_CREATE_CLAIMS('goplc-plant1', 'goplc', 'cloud-api', 3600);
        claims := JWT_ADD_CLAIM(claims, 'plant_id', 'PLANT-001');
        token := JWT_ENCODE(claims, api_key);
        state := 10;

    10: (* Build signed request *)
        payload := JSON_STRINGIFY(JSON_OBJECT(
            'temperature', 72.5,
            'pressure', 45.3
        ));

        (* HMAC signature for request body *)
        signature := HMAC_SHA256(api_key, payload);

        (* Build headers *)
        hdrs := HTTP_SET_HEADER('', 'Authorization', CONCAT('Bearer ', token));
        hdrs := HTTP_SET_HEADER(hdrs, 'X-Signature', signature);

        resp := HTTP_REQUEST('POST', 'https://api.example.com/telemetry',
                             payload, hdrs, 10);

        IF HTTP_OK(resp) THEN
            state := 10;    (* Loop *)
        END_IF;

        (* Refresh token before expiry *)
        IF JWT_TIME_TO_EXPIRY(token) < 300 THEN
            token := JWT_REFRESH(token, api_key, 3600);
        END_IF;
END_CASE;
END_PROGRAM
```

---

## 10. Complete Example: Encrypted Data Logger

Encrypt sensitive process data at rest:

```iecst
PROGRAM POU_EncryptedLog
VAR
    initialized : BOOL := FALSE;
    scan_count : DINT := 0;
    key : STRING;
    line : STRING;
    encrypted_line : STRING;
END_VAR

IF NOT initialized THEN
    (* Load or generate encryption key *)
    IF FILE_EXISTS('/data/log.key') THEN
        key := FILE_READ('/data/log.key');
    ELSE
        key := GENERATE_KEY(32);
        FILE_WRITE('/data/log.key', key);
    END_IF;
    initialized := TRUE;
END_IF;

scan_count := scan_count + 1;

IF (scan_count MOD 100) = 0 THEN
    (* Build log entry *)
    line := CONCAT(
        DT_TO_STRING(NOW()), ',',
        REAL_TO_STRING(temperature), ',',
        REAL_TO_STRING(pressure)
    );

    (* Encrypt and append *)
    encrypted_line := AES_GCM_ENCRYPT(line, key);
    FILE_APPEND('/data/encrypted_log.dat', CONCAT(encrypted_line, CHR(10)));
END_IF;
END_PROGRAM
```

---

## Appendix A: Quick Reference

### Hashing (10)

| Function | Returns | Description |
|----------|---------|-------------|
| `SHA256(data)` | STRING (hex) | SHA-256 hash |
| `SHA384(data)` | STRING (hex) | SHA-384 hash |
| `SHA512(data)` | STRING (hex) | SHA-512 hash |
| `SHA1(data)` | STRING (hex) | SHA-1 hash |
| `MD5(data)` | STRING (hex) | MD5 hash |
| `SHA256_BYTES(data)` | ARRAY | SHA-256 as byte array |
| `MD5_BYTES(data)` | ARRAY | MD5 as byte array |
| `CRC32(data)` | INT | CRC-32 checksum |
| `CRC16(data)` | INT | CRC-16 checksum |
| `CRC16_MODBUS(data)` | INT | CRC-16/Modbus |

### HMAC (5)

| Function | Returns | Description |
|----------|---------|-------------|
| `HMAC_SHA256(key, msg)` | STRING (hex) | HMAC-SHA256 |
| `HMAC_SHA512(key, msg)` | STRING (hex) | HMAC-SHA512 |
| `HMAC_SHA1(key, msg)` | STRING (hex) | HMAC-SHA1 |
| `HMAC_MD5(key, msg)` | STRING (hex) | HMAC-MD5 |
| `HMAC_SHA256_BASE64(key, msg)` | STRING (b64) | HMAC-SHA256, base64 output |

### AES (6)

| Function | Returns | Description |
|----------|---------|-------------|
| `AES_ENCRYPT(text, key)` | STRING (b64) | AES encrypt (IV auto-generated) |
| `AES_DECRYPT(cipher, key)` | STRING | AES decrypt |
| `AES_CBC_ENCRYPT(text, key)` | STRING (b64) | AES-CBC encrypt |
| `AES_CBC_DECRYPT(cipher, key)` | STRING | AES-CBC decrypt |
| `AES_GCM_ENCRYPT(text, key)` | STRING (b64) | AES-GCM authenticated encrypt |
| `AES_GCM_DECRYPT(cipher, key)` | STRING | AES-GCM authenticated decrypt |

### RSA (5)

| Function | Returns | Description |
|----------|---------|-------------|
| `RSA_GENERATE_KEYPAIR([bits])` | MAP | {private, public} PEM keys |
| `RSA_ENCRYPT(text, pubkey)` | STRING (b64) | Encrypt with public key |
| `RSA_DECRYPT(cipher, privkey)` | STRING | Decrypt with private key |
| `RSA_SIGN(msg, privkey)` | STRING (b64) | Sign with private key |
| `RSA_VERIFY(msg, sig, pubkey)` | BOOL | Verify signature |

### Base64 (6)

| Function | Returns | Description |
|----------|---------|-------------|
| `BASE64_ENCODE(str)` | STRING | Standard base64 |
| `BASE64_DECODE(str)` | STRING | Decode base64 |
| `BASE64_URL_ENCODE(str)` | STRING | URL-safe base64 (no padding) |
| `BASE64_URL_DECODE(str)` | STRING | Decode URL-safe base64 |
| `BASE64_ENCODE_BYTES(arr)` | STRING | Encode byte array |
| `BASE64_DECODE_BYTES(str)` | ARRAY | Decode to byte array |

### JWT (12)

| Function | Returns | Description |
|----------|---------|-------------|
| `JWT_CREATE_CLAIMS([sub,iss,aud,exp])` | MAP | Build standard claims |
| `JWT_ADD_CLAIM(claims, key, val)` | MAP | Add custom claim |
| `JWT_ENCODE(claims, secret [,alg])` | STRING | Create JWT string |
| `JWT_DECODE(token)` | MAP | Decode without verification |
| `JWT_VERIFY(token, secret)` | BOOL | Verify signature |
| `JWT_VALIDATE(token, secret [,iss,aud])` | MAP | Full validation |
| `JWT_GET_CLAIM(token, name)` | ANY | Read single claim |
| `JWT_GET_ALL_CLAIMS(token)` | MAP | Read all claims |
| `JWT_GET_HEADER(token, field)` | ANY | Read header field |
| `JWT_IS_EXPIRED(token)` | BOOL | Check expiry |
| `JWT_TIME_TO_EXPIRY(token)` | INT | Seconds remaining |
| `JWT_REFRESH(token, secret, exp)` | STRING | New token, fresh expiry |

### Utility (8)

| Function | Returns | Description |
|----------|---------|-------------|
| `GENERATE_KEY([len])` | STRING (b64) | Random key (default 32 bytes) |
| `GENERATE_IV()` | STRING (b64) | Random 16-byte IV |
| `HASH_EQUALS(a, b)` | BOOL | Constant-time compare |
| `HASH_VERIFY(alg, data, hash)` | BOOL | Verify hash matches data |
| `SECURE_COMPARE(a, b)` | BOOL | Alias for HASH_EQUALS |
| `ENCRYPT_FILE(path, key)` | BOOL | Encrypt file in place |
| `DECRYPT_FILE(path, key)` | BOOL | Decrypt file in place |

---

*GoPLC v1.0.535 | ~55 Crypto & Security Functions | SHA/AES/RSA/JWT/HMAC/Base64*

*© 2026 JMB Technical Services LLC. All rights reserved.*
*[Back to White Papers](https://jmbtechnical.com/whitepapers/)*
