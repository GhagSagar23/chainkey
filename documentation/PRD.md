# Product Requirement Document (PRD)

## Project: `chainkey`
**Turnkey Hardware-Enclave & Passkey Signer for Account Abstraction (ERC-4337 & EIP-7212) on Flutter**

---

| Metadata | Value |
| :--- | :--- |
| **Document Version** | 1.0.0 |
| **Status** | Approved for Development |
| **Author** | Web3 & Mobile Systems Architecture Team |
| **Target Platforms** | iOS 16.0+, Android API 28+ (Pie / KeyMint / BiometricPrompt), Web (WebAuthn W3C) |
| **Dart / Flutter Compatibility** | Dart SDK ≥ 3.4.0, Flutter ≥ 3.22.0 |
| **License** | Apache-2.0 |

---

## 1. Executive Summary & Vision

### 1.1 Problem Statement
The Web3 mobile ecosystem suffers from a catastrophic onboarding barrier: **seed phrase management** and **vulnerable software private keys** stored in insecure application sandboxes. 

With Ethereum’s **ERC-4337** (Account Abstraction) and **EIP-7212** (Precompile for `secp256r1` / NIST P-256 Curve Support on L2s like Arbitrum, Base, Optimism, and Polygon), mobile apps can now authenticate smart contract wallets directly using hardware-bound biometrics (Apple Secure Enclave, Android StrongBox / KeyMint).

However, **no turnkey Flutter/Dart package exists today** to bridge this gap:
1. Existing WebAuthn plugins are designed strictly for Web2 server authentication (relying on JSON challenges and cookies) and cannot output raw signature tuple components `(r, s)` normalized for EVM smart contract verifiers.
2. Direct cryptography bridges (e.g., raw FFI to `CryptoKit` or Android `KeyStore`) require deep mobile security knowledge, custom ASN.1 DER parser implementations, malleable curve normalization, and manual `clientDataJSON` / `authenticatorData` assembly.
3. Mobile Web3 developers are forced to write fragile native Swift/Kotlin boilerplate across projects, leading to security vulnerabilities and broken multi-chain account abstraction implementations.

### 1.2 Solution & Vision
`chainkey` is an open-source, production-grade Flutter plugin providing end-to-end hardware-enclave biometric key generation, passkey attestation, and ERC-4337/EIP-7212 compatible Web3 signing. It allows any Flutter app to turn the user's device into a non-custodial, seedless, biometric hardware wallet in under 10 lines of Dart code.

---

## 2. Competitive Landscape & Market Research Findings

| Solution / Ecosystem | Current State | Critical Limitations |
| :--- | :--- | :--- |
| **`passkeys` (pub.dev)** | General-purpose WebAuthn plugin for Web2 auth | Only returns base64 auth tokens; cannot sign arbitrary 32-byte EVM hashes; no ASN.1 to `(r, s)` unpacking; no Smart Account UserOp compatibility. |
| **`web3dart`** | Standard JSON-RPC & EVM transaction engine | Strictly supports `secp256k1` software private key signing. Zero support for hardware keys, Secure Enclave, or P-256 curve verification. |
| **Turnkey / Privy / Dynamic SDKs** | Proprietary React Native & Web SDKs | Web-first; closed ecosystems; either vendor locked or lacking first-class Flutter support; requires monthly paid cloud infrastructure. |
| **Native Swift / Kotlin custom code** | Fragmented snippets in private repos | High maintenance overhead; lack of unified EIP-712 hashing; tricky Android StrongBox key invalidation bugs. |

---

## 3. Goals & Success Metrics

### 3.1 Primary Objectives
1. **Zero Native Code for Consumers:** Flutter developers can initialize, register, and sign transactions with zero Swift/Kotlin knowledge.
2. **Standard-Compliant Cryptography:** Native extraction of uncompressed public keys `(0x04 || X || Y)` and `(r, s)` signatures with full BIP-62 low-$S$ malleability mitigation.
3. **EIP-7212 & ERC-4337 Ready:** Native helper serializers for UserOperations matching standard Smart Account implementations (Safe Passkey Module, Biconomy Nexus, ZeroDev Kernel, Soul Wallet).
4. **Cross-Platform Parity:** Consistent behavior across iOS (Secure Enclave / ASAuthorization), Android (KeyMint / FIDO2 Credential Manager), and Flutter Web (Navigator Credentials).

### 3.2 Key Performance Indicators (KPIs)
* **Execution Latency:** Biometric prompt to valid `(r, s, authData, clientDataJSON)` payload in $< 350\text{ ms}$.
* **Zero Cryptographic Malformations:** 100% verification pass rate across EIP-7212 verifier contracts on Sepolia / Base / Arbitrum testnets.
* **Package Size Footprint:** Native binary overhead $< 180\text{ KB}$ on iOS and $< 140\text{ KB}$ on Android.

---

## 4. Technical Architecture

### 4.1 System Overview
```text
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

### 4.2 Cryptographic Pipeline & Low-S Normalization
1. **Key Generation:**
   - Elliptic Curve: `NIST P-256` (also known as `secp256r1` or `prime256v1`).
   - Private Key: Generated directly inside hardware isolated execution environments (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` on iOS; `KeyProperties.PURPOSE_SIGN` with StrongBox isolation on Android). Private keys are mathematically unexportable.
   - Public Key Format: Uncompressed 65-byte point `0x04 || X (32 bytes) || Y (32 bytes)`.

2. **ASN.1 DER to Padded `(r, s)` Decoupling:**
   - Standard hardware enclaves produce signatures in ASN.1 DER format:
     `0x30 || Length || 0x02 || r_length || r || 0x02 || s_length || s`
   - The plugin unpacks `r` and `s`, strips any leading null byte padding introduced by ASN.1 integers, and guarantees exact 32-byte big-endian buffers.

3. **EIP-2 / BIP-62 Low-$S$ Enforcement:**
   - In EVM smart contracts, signatures where $s > n/2$ (where $n$ is the curve order of `secp256r1`) are rejected to eliminate signature malleability.
   - If $s > n / 2$, the package replaces $s$ with $s' = n - s$:
     $$\text{Curve Order } n = \text{0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551}$$

4. **WebAuthn UserOp Serialization:**
   - Outputs structured WebAuthn auth structs matching standard EIP-7212 verifiers:
     ```solidity
     struct WebAuthnAuth {
         bytes authenticatorData;
         bytes clientDataJSON;
         uint256 challengeLocation;
         uint256 responseTypeLocation;
         uint256 r;
         uint256 s;
     }
     ```

---

## 5. Functional Requirements & Feature Specification

### 5.1 Key Pair Management (`PasskeyManager`)
* **`createPasskey(PasskeyCreationOptions options) -> Future<PasskeyCredential>`**
  - Triggers native platform passkey / hardware key generation dialog.
  - Returns credential ID, uncompressed public key coordinates `(qx, qy)`, and hardware attestation.
* **`getPasskey(String credentialId) -> Future<PasskeyCredential?>`**
  - Retrieves registered public metadata for a saved credential.
* **`deletePasskey(String credentialId) -> Future<void>`**
  - Permanently invalidates and deletes the private key from the local hardware chip.

### 5.2 Transaction & Hash Signing (`PasskeySigner`)
* **`signRawHash(Uint8List hash32, PasskeySignOptions options) -> Future<P256Signature>`**
  - Authenticates via FaceID/TouchID/Biometrics and computes signature directly on the 32-byte hash (used for Enclave-only mode).
* **`signWebAuthnChallenge(Uint8List challenge, PasskeySignOptions options) -> Future<WebAuthnSignature>`**
  - Conforms to standard WebAuthn flow where `challenge` is the userOp hash.
  - Captures `authenticatorData` and `clientDataJSON`.
  - Automatically identifies byte index offsets for `challenge` and `type` within `clientDataJSON`.

### 5.3 ERC-4337 Utility Suite (`ChainPasskeyUtils`)
* **`formatForEIP7212(WebAuthnSignature sig) -> Uint8List`**
  - ABI-encodes signature components for direct consumption by EIP-7212 precompiles and verification contracts.
* **`formatForSafeModule(WebAuthnSignature sig) -> Uint8List`**
  - Encodes signature specifically for Safe's 4337 WebAuthn Signer Module.

---

## 6. Public API Design (Dart Code Example)

```dart
import 'dart:typed_data';
import 'package:chainkey/chainkey.dart';

void main() async {
  final passkey = Chainkey();

  // 1. Register a new biometric hardware key
  final credential = await passkey.createCredential(
    PasskeyCreationOptions(
      relyingPartyId: 'xyz.petpal.wallet',
      userName: 'user@petpal.xyz',
      userDisplayName: 'Petpal Mobile Vault',
      requireHardwareIsolation: true, // Secure Enclave / StrongBox
    ),
  );

  print('Public Key X: ${credential.publicKeyX.toHex()}');
  print('Public Key Y: ${credential.publicKeyY.toHex()}');

  // 2. Sign an ERC-4337 UserOperation Hash
  final Uint8List userOpHash = calculateUserOpHash(...);

  final WebAuthnSignature signature = await passkey.signChallenge(
    credentialId: credential.id,
    challenge: userOpHash,
    prompt: BiometricPromptOptions(
      title: 'Authorize Transaction',
      subtitle: 'Transfer 50 USDC to 0x123...',
      cancelButtonText: 'Cancel',
    ),
  );

  // 3. Serialize for Smart Account Contract Submission
  final Uint8List erc4337SignatureBytes = signature.toEIP7212Packed();
  
  // Attach `erc4337SignatureBytes` directly to UserOperation.signature
}
```

---

## 7. Non-Functional Requirements

### 7.1 Security & Hardware Constraints
* **Isolated Execution:** Private keys must never touch application RAM or Dart heap memory. All curve operations must execute within the native Secure Enclave or Android StrongBox / TEE.
* **Biometric Invalidation:** On Android, keys must be generated with `setUserAuthenticationRequired(true)` and optional `setInvalidatedByBiometricEnrollment(true)` to prevent rogue fingerprint exploit vectors.
* **No Telemetry / No Phone-Home:** The SDK contains zero network calls, tracking, analytics, or external SDK dependencies.

### 7.2 Reliability & Platform Fallbacks
* If a physical device lacks StrongBox HSM (e.g. older Android devices), gracefully fall back to standard Android KeyStore TEE while surfacing a security warning flag: `HardwareIsolationLevel.tee` vs `HardwareIsolationLevel.strongBox`.

---

## 8. Implementation Roadmap

### Phase 1: Core Cryptographic Engines (Weeks 1–3)
- [ ] iOS Swift Plugin implementation using `AuthenticationServices` (`ASAuthorizationPlatformPublicKeyCredentialProvider`) and `CryptoKit`.
- [ ] Android Kotlin Plugin implementation using `androidx.credentials` and `java.security.keystore`.
- [ ] DER ASN.1 unpacker and low-$S$ curve arithmetic library written in pure Dart.

### Phase 2: WebAuthn & EVM Serialization (Weeks 4–5)
- [ ] Implement `clientDataJSON` challenge and type offset scanners.
- [ ] Integrate EIP-7212 precompile ABI packing.
- [ ] Comprehensive unit tests verifying output against Ethereum test vectors.

### Phase 3: Smart Account Integration Kits (Weeks 6–7)
- [ ] End-to-end integration tests with Safe WebAuthn Shared Signer module on Base Sepolia.
- [ ] Biconomy Nexus and ZeroDev Kernel account abstraction testing.
- [ ] Flutter WebAuthn fallback bridge.

### Phase 4: Documentation, Security Audit & Launch (Weeks 8+)
- [ ] Formal independent security audit on native cryptographic bridges.
- [ ] Publish example application demonstrating seedless onboarding to testnet.
- [ ] Publish to `pub.dev` with verified publisher status.

---

## 9. Appendix: EIP-7212 Curve Parameter Reference

$$\text{NIST P-256 Curve Equation: } y^2 = x^3 - 3x + b \pmod p$$

* **Modulus ($p$):** `0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF`
* **Order ($n$):** `0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551`
* **Half-Order ($n / 2$):** `0x7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCE4279DCFE617E3192A8`
* **Standard EVM EIP-7212 Precompile Address:** `0x0000000000000000000000000000000000000100`
