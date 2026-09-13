# `chainkey` Master Roadmap & Execution Plan

## Document Metadata
- **Project**: `chainkey`
- **Specification Version**: 1.0.0
- **Status**: Ready for Implementation
- **Source Documents**:
  - [`PRD.md`](file:///Users/ghag23/Projects/chainkey/documentation/PRD.md)
  - [`FINDINGS.md`](file:///Users/ghag23/Projects/chainkey/documentation/FINDINGS.md)
  - [`RESEARCH.md`](file:///Users/ghag23/Projects/chainkey/documentation/RESEARCH.md)

---

## Executive Summary & Consolidated Context

`chainkey` is a turnkey Flutter plugin designed to eliminate seed phrases and insecure private key storage in Web3 mobile applications. By leveraging native hardware execution environments (Apple Secure Enclave, Android StrongBox / KeyMint) and W3C WebAuthn standards, `chainkey` transforms any mobile device into a non-custodial biometric hardware signer compatible with **ERC-4337 Account Abstraction** and **EIP-7212 (`secp256r1` precompile)** smart contract accounts.

### Foundational Findings & Architectural Pillars
1. **Dual Driver Architecture**:
   - **Direct Hardware Driver**: Uses Secure Enclave / StrongBox to sign raw 32-byte `UserOpHash` digests directly over NIST P-256 (`secp256r1`). Maximizes security, eliminates JSON wrappers, and achieves minimal on-chain gas costs (~3,400 gas on EIP-7212 precompile-enabled L2s).
   - **WebAuthn Passkey Driver**: Uses OS-level Passkey APIs (iCloud Keychain, Google Password Manager) for cloud-synchronized multi-device recovery, producing standard `authenticatorData` and `clientDataJSON`.
2. **Deterministic Cryptographic Normalization**:
   - ASN.1 DER signature decoding into 32-byte big-endian `(r, s)` tuples.
   - BIP-62 / EIP-2 Low-$S$ enforcement ($s' = n - s$ if $s > n/2$).
   - 65-byte uncompressed public key point generation (`0x04 || X || Y`).
3. **Smart Account Gas Optimization (Zero-Copy Offsets)**:
   - On-chain JSON string scanning costs 50,000+ extra gas in EVM contracts. `chainkey` client-side auto-computes exact UTF-8 byte offsets for `challengeLocation` and `responseTypeLocation` matching Solady `WebAuthn.sol` specifications.
4. **Universal Account Abstraction Adapters**:
   - Modular packing for Safe Passkey Module, ZeroDev Kernel v3, Biconomy Nexus (ERC-7579), and raw EIP-7212 precompiles.
5. **Native Security Safeguards**:
   - Android StrongBox integration with graceful TEE fallback.
   - Prevention of hardware key destruction by enforcing `setInvalidatedByBiometricEnrollment(false)`.
   - Domain association validation (`apple-app-site-association` & `assetlinks.json`) for RP ID security.

---

## Chronological Implementation Roadmap

The implementation is structured strictly in chronological dependency order:
```
┌─────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Core Foundation & Cryptographic Primitives (The Base Engine)   │
│  - IPC Scaffolding & Domain Models                                      │
│  - Pure Dart DER Parser & Low-S Curve Math                              │
│  - Direct Native Hardware Enclave Signers (iOS / Android)               │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ Base types & crypto ready
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Phase 2: WebAuthn Passkey Engine & Protocol Scanners (The Protocol Layer)│
│  - Native OS Passkey Bridges (ASAuthorization / CredentialManager / Web)│
│  - ClientDataJSON UTF-8 Offset Scanner & AuthenticatorData Parser       │
│  - Relying Party (RP ID) & Mobile Domain Association Verifier           │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ WebAuthn signatures & offsets ready
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Phase 3: Smart Account Adapters & Production Launch (Integration Layer) │
│  - Universal ERC-4337 Adapters (Safe, ZeroDev, Biconomy, EIP-7212)      │
│  - Multi-Signer Lifecycle & Recovery UserOp Generators                  │
│  - Testnet Verification (Base/Arbitrum), Audit & pub.dev Release        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### Phase 1: Core Foundation & Cryptographic Primitives (The Base Engine)
> **Goal**: Build the zero-dependency mathematical and IPC foundation. Ensure all curve arithmetic, DER decoding, low-$S$ normalization, and direct enclave access are 100% verified before introducing WebAuthn or smart account layers.

#### Sub-Phase 1.1: Architecture Foundation, Domain Models & Pigeon IPC
- **Objective**: Establish the federated plugin structure, domain models, and type-safe platform IPC contracts.
- **Key Deliverables**:
  - Federated plugin structure (`chainkey`, `chainkey_platform_interface`, `chainkey_ios`, `chainkey_android`, `chainkey_web`).
  - Core domain models in Dart:
    - `P256PublicKey` (coordinates $X, Y$, uncompressed 65-byte bytes, hex format).
    - `P256Signature` (exact 32-byte big-endian $r$ and $s$).
    - `PasskeyCredential` (credential ID, public key, attestation format, hardware isolation level).
    - `BiometricPromptOptions` (title, subtitle, negativeButtonText, confirmationRequired).
    - `HardwareIsolationLevel` enum (`strongBox`, `tee`, `secureEnclave`, `software`).
  - Pigeon IDL specification (`pigeons/chainkey_api.dart`) defining:
    - `HardwareEnclaveHostApi` (direct keygen, raw 32-byte hash signing, key deletion).
    - `WebAuthnHostApi` (passkey registration, challenge assertion).
  - Robust exception hierarchy (`PasskeyException`, `HardwareEnclaveException`, `KeyPermanentlyInvalidatedException`, `UserCancelledException`).
- **Success Criteria**:
  - `flutter pub run pigeon` generates clean, type-safe Swift, Kotlin, and Dart bindings without manual glue code.

#### Sub-Phase 1.2: Pure Dart Cryptographic Engine (ASN.1 DER Parser & Curve Arithmetic)
- **Objective**: Implement standalone, zero-external-dependency cryptographic utilities in pure Dart.
- **Key Deliverables**:
  - **ASN.1 DER Signature Unpacker**:
    - Decodes ASN.1 DER sequence: `0x30 || Length || 0x02 || r_length || r || 0x02 || s_length || s`.
    - Handles variable-length integers and removes leading `0x00` padding bytes.
    - Zero-pads integers $< 32$ bytes to ensure exact 32-byte big-endian buffers for both $r$ and $s$.
  - **BIP-62 / EIP-2 Low-$S$ Malleability Normalizer**:
    - NIST P-256 (`secp256r1`) curve order constant $n$:
      `0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551`
    - Half-order constant $n/2$:
      `0x7FFFFFFF800000007FFFFFFFFFFFFFFFDE737D56D38BCE4279DCFE617E3192A8`
    - Logic: If $s > n/2$, normalize $s' = n - s$ via BigInt modular arithmetic.
  - **Public Key Parser & Point Coordinates**:
    - Parses uncompressed SEC1 65-byte point `0x04 || X (32B) || Y (32B)`.
    - Coordinates extraction and validation on the $y^2 = x^3 - 3x + b \pmod p$ curve.
- **Success Criteria**:
  - 100% test coverage on pure Dart crypto unit tests against Wycheproof test vectors, RFC 6979 vectors, and Ethereum testnet vectors.

#### Sub-Phase 1.3: Direct Native Hardware Enclave Driver (Secure Enclave & StrongBox)
- **Objective**: Implement direct, non-exportable hardware key generation and raw 32-byte digest signing for iOS and Android.
- **Key Deliverables**:
  - **iOS Native Engine (`chainkey_ios`)**:
    - Keypair generation via `Security.framework` and `CryptoKit` targeting Secure Enclave (`kSecAttrTokenIDSecureEnclave`).
    - Storage attributes: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
    - Raw 32-byte hash signing with FaceID/TouchID prompt (`kSecAccessControlBiometryAny`).
  - **Android Native Engine (`chainkey_android`)**:
    - Keypair generation via `android.security.keystore` with `KeyGenParameterSpec`.
    - StrongBox hardware isolation (`setIsStrongBoxBacked(true)`) with fallback to standard TEE.
    - Critical configuration: `setUserAuthenticationRequired(true)` with `setInvalidatedByBiometricEnrollment(false)` to prevent rogue fingerprint key erasure.
    - Raw 32-byte digest signing via `Signature.getInstance("SHA256withECDSA")`.
- **Success Criteria**:
  - Successfully generates non-exportable hardware keys on physical iOS (Secure Enclave) and Android (StrongBox/TEE) devices.
  - Biometric authentication prompt to raw $(r, s)$ output latency $< 350\text{ ms}$.

---

### Phase 2: WebAuthn Passkey Engine & Protocol Scanners (The Protocol Layer)
> **Goal**: Layer W3C WebAuthn / FIDO2 Passkey credential generation, assertion, and client-side zero-copy offset scanning on top of the Phase 1 base.

#### Sub-Phase 2.1: Native OS Passkey Credential Bridges
- **Objective**: Implement Passkey registration and assertion using platform credential managers supporting cloud synchronization (iCloud Keychain & Google Password Manager).
- **Key Deliverables**:
  - **iOS Passkey Engine**:
    - `AuthenticationServices` integration using `ASAuthorizationPlatformPublicKeyCredentialProvider`.
    - Credential registration via `ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest`.
    - Credential assertion via `ASAuthorizationPlatformPublicKeyCredentialAssertionRequest`.
    - Extracts `rawClientDataJSON`, `rawAuthenticatorData`, and DER signature.
  - **Android Passkey Engine**:
    - `androidx.credentials.CredentialManager` integration.
    - Registration via `CreatePublicKeyCredentialRequest` (JSON payload according to W3C WebAuthn).
    - Assertion via `GetPublicKeyCredentialOption`.
    - Extracts `clientDataJSON`, `authenticatorData`, and signature.
  - **Flutter Web Engine (`chainkey_web`)**:
    - `dart:js_interop` bridge to browser `window.navigator.credentials.create()` and `navigator.credentials.get()`.
- **Success Criteria**:
  - Seamless passkey registration and assertion across iOS 16+, Android 9+ (API 28+ with CredentialManager), and modern desktop/mobile web browsers.

#### Sub-Phase 2.2: Zero-Copy ClientDataJSON Offset Scanner & AuthenticatorData Parser
- **Objective**: Eliminate EVM gas penalties by extracting exact UTF-8 byte offsets on the client side before building the signature.
- **Key Deliverables**:
  - **AuthenticatorData Parser**:
    - Extracts `rpIdHash` (32 bytes), `flags` (1 byte: User Present `UP`, User Verified `UV`), and `signCount` (4 bytes).
  - **ClientDataJSON Scanner**:
    - Parses JSON string bytes to locate:
      - `challengeLocation`: Byte index where the base64url-encoded challenge begins.
      - `responseTypeLocation`: Byte index where the `"type":"webauthn.get"` begins.
    - Verified against Solady `WebAuthn.sol` slicing logic.
  - Verification that the parsed challenge matches the original `UserOpHash` or challenge payload.
- **Success Criteria**:
  - Client-computed offsets match exact EVM `mload` slice locations across arbitrary JSON key orderings, whitespace variations, and string escapes.

#### Sub-Phase 2.3: Relying Party (RP ID) & Mobile Domain Association Diagnostic Tooling
- **Objective**: Prevent native mobile WebAuthn failures caused by missing or misconfigured domain associations.
- **Key Deliverables**:
  - Diagnostic CLI tool: `chainkey verify-domain --rp-id <domain> --bundle-id <id> --package-name <pkg>`.
  - Built-in network check verifying:
    - iOS: `https://<rp-id>/.well-known/apple-app-site-association` contains valid `webcredentials` entitlement.
    - Android: `https://<rp-id>/.well-known/assetlinks.json` contains valid package name and SHA-256 certificate fingerprint.
  - Runtime warning system in debug mode when RP ID mismatch is detected.
- **Success Criteria**:
  - Developer receives clear, actionable error messages before running into silent OS WebAuthn origin rejections.

---

### Phase 3: Smart Account Adapters, ERC-4337 Serialization & Production Launch (Integration Layer)
> **Goal**: Provide out-of-the-box adapters for standard Account Abstraction frameworks, multi-signer management, live testnet validation, and pub.dev publication.

#### Sub-Phase 3.1: Universal Smart Account Signature Formatters (`chainkey/adapters`)
- **Objective**: Deliver turnkey ABI encoding helpers for standard ERC-4337 smart contract accounts and precompiles.
- **Key Deliverables**:
  - **Safe Passkey Module Adapter** (`SafePasskeyAdapter`):
    - Encodes signature tuple matching Safe 4337 WebAuthn Signer contract:
      `abi.encode(r, s, authData, clientDataJSON, challengeLocation, responseTypeLocation)`
  - **ZeroDev Kernel Adapter** (`ZeroDevKernelAdapter`):
    - Formats signature for Kernel v2 / v3 WebAuthn validator plugin:
      `bytes4(pluginId) + abi.encodePacked(...)`
  - **Biconomy Nexus Adapter** (`BiconomyNexusAdapter`):
    - Encodes ERC-7579 modular WebAuthn validator struct.
  - **EIP-7212 Raw Precompile Adapter** (`Eip7212PrecompileAdapter`):
    - ABI-encodes `(bytes32 messageHash, uint256 r, uint256 s, uint256 qx, uint256 qy)` for precompile address `0x0000000000000000000000000000000000000100`.
- **Success Criteria**:
  - ABI-encoded bytes validate 100% on deployed verifier smart contracts without signature formatting errors.

#### Sub-Phase 3.2: Multi-Signer Lifecycle & Recovery UserOp Generators
- **Objective**: Abstract smart account multi-device linking and hardware key lifecycle management.
- **Key Deliverables**:
  - UserOp helper to register a new `P256PublicKey` as an authorized signer on an existing smart account.
  - UserOp helper to revoke a compromised or lost device key.
  - Recovery flow handler for Android `KeyPermanentlyInvalidatedException`:
    - Automatically detects biometric enrollment invalidation.
    - Triggers recovery flow using secondary passkey or cloud-synced credential.
- **Success Criteria**:
  - End-to-end multi-device pairing: user can register a new hardware key on Device B authorized by an existing passkey on Device A.

#### Sub-Phase 3.3: Live Testnet Verification, Security Audit & Package Launch
- **Objective**: Conduct rigorous end-to-end on-chain testing, security verification, and release to the Flutter community.
- **Key Deliverables**:
  - **Live Testnet Integration Suite**:
    - Deploys test Smart Accounts (Safe, ZeroDev, Biconomy) on Base Sepolia and Arbitrum Sepolia.
    - Automated integration tests executing live ERC-4337 UserOperations signed by `chainkey`.
  - **Package Size & Latency Audit**:
    - Verify native binary overhead $< 180\text{ KB}$ (iOS) and $< 140\text{ KB}$ (Android).
    - Verify biometric prompt-to-signature latency $< 350\text{ ms}$.
  - **Complete Documentation & Example Application**:
    - Production-grade example Flutter app demonstrating seedless biometric onboarding, USDC transfer, and multi-device key registration.
    - Comprehensive README with setup guides for iOS Associated Domains and Android Digital Asset Links.
  - **Publication**:
    - Complete pubspec metadata, API documentation, and publish to `pub.dev` with 140/140 Pub points.
- **Success Criteria**:
  - 100% UserOp execution success rate on Base Sepolia and Arbitrum Sepolia testnets.
  - Successful publication to `pub.dev` under the Apache-2.0 license.

---

## Chronological Work Breakdown Structure (WBS) & Dependency Graph

```text
[1.1 Pigeon IPC & Models] ────► [1.2 Pure Dart Crypto: DER & Low-S] ────► [1.3 Native Enclave Signer]
                                                                                   │
┌──────────────────────────────────────────────────────────────────────────────────┘
▼
[2.1 Native Passkey Bridges] ──► [2.2 ClientDataJSON Offset Engine] ──► [2.3 Domain Association Tooling]
                                                                                   │
┌──────────────────────────────────────────────────────────────────────────────────┘
▼
[3.1 Universal AA Adapters] ───► [3.2 Multi-Signer Lifecycle] ────────► [3.3 Testnet E2E & pub.dev]
```

---

## Milestones & Tracking Matrix

| Milestone | Key Deliverables | Expected Completion | Dependencies |
| :--- | :--- | :---: | :--- |
| **M1: Cryptographic Foundation** | Scaffolding, Pigeon APIs, pure Dart DER unpacker, Low-$S$ math, unit tests. | End of Sprint 1 | None |
| **M2: Direct Enclave Engine** | iOS Secure Enclave & Android StrongBox/KeyStore native drivers, raw 32B signing. | End of Sprint 2 | M1 |
| **M3: WebAuthn Passkeys & Offsets** | iOS ASAuthorization, Android CredentialManager, Web interop, clientDataJSON offset scanner. | End of Sprint 4 | M1, M2 |
| **M4: AA Adapters & Domain Tools** | Safe, ZeroDev, Biconomy adapters, EIP-7212 encoder, domain check CLI. | End of Sprint 5 | M3 |
| **M5: Testnet Validation & Release**| Live UserOp tests on Base Sepolia, example app, pub.dev deployment. | End of Sprint 6 | M4 |
