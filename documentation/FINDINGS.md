# Technical Analysis & Architecture Findings

## Overview
This document consolidates key findings, cryptographic requirements, and competitive analysis for `chainkey`.

---

## 1. Technical Architecture & Cryptographic Pipeline

```
+-----------------------------------------------------------------------+
|                         Flutter Application Layer                     |
|    Smart Account SDK (Safe / Biconomy / ZeroDev) or Custom ERC-4337   |
+-----------------------------------------------------------------------+
                                  │
                                  ▼
+-----------------------------------------------------------------------+
|                         `chainkey` Dart API                           |
|  - PasskeySigner            - EIP712PasskeyEncoder                    |
|  - DerSignatureParser       - UserOpSignaturePacker                   |
+-----------------------------------------------------------------------+
                                  │ MethodChannel / Pigeon
         ┌────────────────────────┼────────────────────────┐
         ▼                        ▼                        ▼
+------------------+     +------------------+     +------------------+
|    iOS Engine    |     |  Android Engine  |     |    Web Engine    |
| (Swift / Native) |     | (Kotlin / Native)|     | (Dart / JS-Interop)
|                  |     |                  |     |                  |
| - Secure Enclave |     | - AndroidKeyStore|     | - WebAuthn API   |
| - ASAuthorization|     | - StrongBox HSM  |     | - W3C Credential |
| - CryptoKit P256 |     | - Credential Mgr |     |   Management     |
+------------------+     +------------------+     +------------------+
```

### Cryptographic Pipeline Steps
1. **Hardware Key Isolation**:
   - Curve: `NIST P-256` (`secp256r1`).
   - Private key generated inside hardware enclave (Secure Enclave on iOS, StrongBox/KeyMint on Android).
   - Private key is unexportable; output public key is 65-byte uncompressed: `0x04 || X (32B) || Y (32B)`.
2. **ASN.1 DER Unpacking**:
   - Enclaves return DER format (`0x30 || Length || 0x02 || r_length || r || 0x02 || s_length || s`).
   - `chainkey` strips leading zero padding and ensures standard 32-byte big-endian `r` and `s` integers.
3. **Low-$S$ Normalization (BIP-62 / EIP-2)**:
   - If $s > n/2$, set $s' = n - s$, where curve order $n$ is:
     `0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551`
4. **WebAuthn UserOp Packing**:
   - Parses `authenticatorData` and `clientDataJSON`.
   - Automatically computes byte offsets (`challengeLocation` and `responseTypeLocation`) for EIP-7212 verification contracts.

---

## 2. Competitive Landscape

| Solution | Current State | Limitations |
| :--- | :--- | :--- |
| **`passkeys` (pub.dev)** | Web2 WebAuthn auth | Only outputs base64 auth tokens; cannot sign raw 32B hashes; no ASN.1 unpacking; non-EVM compliant. |
| **`web3dart`** | Standard JSON-RPC engine | `secp256k1` software keys only. No hardware key support or P-256 curve verification. |
| **Turnkey / Privy / Dynamic** | Proprietary React Native / Web SDKs | Closed ecosystems, cloud vendor lock-in, paid subscriptions, lacking first-class Flutter support. |
| **Native Swift / Kotlin Snippets** | Fragmented per-project code | High maintenance overhead, insecure key storage bugs, inconsistent EIP-712 hashing. |

---

## 3. Recommended Implementation Stack

- **Inter-Platform IPC**: Use **Pigeon** (`package:pigeon`) for type-safe code generation between Dart, Swift, and Kotlin.
- **iOS Layer**: Swift with `AuthenticationServices` (`ASAuthorizationPlatformPublicKeyCredentialProvider`) and `CryptoKit`.
- **Android Layer**: Kotlin with `androidx.credentials.CredentialManager` (WebAuthn/Passkey) and `android.security.keystore` (direct Enclave signing).
- **Web Layer**: `dart:js_interop` interacting directly with W3C `navigator.credentials` API.
