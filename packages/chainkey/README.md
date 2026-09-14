# chainkey

[![pub package](https://img.shields.io/pub/v/chainkey.svg)](https://pub.dev/packages/chainkey)
[![license](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/GhagSagar23/chainkey/blob/master/LICENSE)
[![CI](https://github.com/GhagSagar23/chainkey/actions/workflows/ci.yml/badge.svg)](https://github.com/GhagSagar23/chainkey/actions/workflows/ci.yml)

A turnkey Flutter plugin for **seedless Web3 authentication** and **smart contract account abstraction**.

`chainkey` enables applications to generate non-exportable cryptographic keypairs directly inside hardware security enclaves (**Apple Secure Enclave** and **Android StrongBox / TEE**) and web authenticators (**W3C WebAuthn / Passkeys**). Private keys never leave the hardware chip and require user biometric presence (Face ID, Touch ID, Fingerprint) for every signature.

Signatures are emitted with pre-unpacked, low-$S$ normalized `(r, s)` scalar components ready for on-chain verification via **EIP-7212** precompiles or **ERC-4337** smart contract wallets.

---

## Supported Platforms & Hardware Tiers

| Platform | Hardware Isolation Tier | Biometric Technology | Key Curve |
| :--- | :--- | :--- | :--- |
| **iOS** | Apple Secure Enclave (SEP) | Face ID / Touch ID (`LAContext`) | NIST P-256 (`secp256r1`) |
| **Android** | StrongBox HSM / ARM TrustZone TEE | Android `BiometricPrompt` | NIST P-256 (`secp256r1`) |
| **Web** | Platform Authenticator / Security Keys | Passkeys / WebAuthn / WebCrypto | NIST P-256 (`secp256r1`) |

---

## Getting Started

### 1. Add Dependency

Add `chainkey` to your Flutter app's `pubspec.yaml`:

```yaml
dependencies:
  chainkey: ^0.1.0
```

### 2. Platform Setup

#### iOS
Add the `NSFaceIDUsageDescription` entry to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate using biometrics to sign transactions securely.</string>
```

#### Android
Ensure `minSdk` is at least `24` in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

---

## Usage

### 1. Check Hardware Isolation Support

```dart
import 'package:chainkey/chainkey.dart';

// Check if dedicated hardware HSM is available on this physical device
final isStrongBoxAvailable = await Chainkey.instance.isHardwareIsolationSupported(
  HardwareIsolationLevel.strongBox,
);

final isSecureEnclaveAvailable = await Chainkey.instance.isHardwareIsolationSupported(
  HardwareIsolationLevel.secureEnclave,
);
```

### 2. Generate a Hardware Keypair

```dart
final key = await Chainkey.instance.generateHardwareKey(
  alias: 'wallet_key_0',
  requireUserPresence: true,
  requireStrongBox: true,
);

print('Public key X: ${key.x}');
print('Public key Y: ${key.y}');
print('Uncompressed SEC1 bytes: ${key.uncompressedBytes}');
```

### 3. Sign a 32-Byte Hash (e.g. ERC-4337 UserOpHash)

```dart
import 'dart:typed_data';

final userOpHash = Uint8List(32); // 32-byte digest

final signature = await Chainkey.instance.signWithHardwareKey(
  alias: 'wallet_key_0',
  hash32: userOpHash,
  promptOptions: BiometricPromptOptions(
    title: 'Confirm Transaction',
    subtitle: 'Authorize transfer from smart account',
    negativeButtonText: 'Cancel',
  ),
);

// Low-S normalized scalar components for EIP-7212 precompile:
print('r scalar: ${signature.r}');
print('s scalar: ${signature.s}');
print('Raw ASN.1 DER signature: ${signature.rawDerSignature}');
```

### 4. Delete Keypair

```dart
await Chainkey.instance.deleteHardwareKey('wallet_key_0');
```

---

## Standards Compliance

- **NIST P-256 / secp256r1**: Standard curve supported by Apple SEP, Android StrongBox, and WebAuthn.
- **BIP-62 & EIP-2**: Strict low-$S$ scalar normalization ($s \le n/2$) preventing transaction malleability.
- **EIP-7212**: EVM precompile for secp256r1 curve support on Ethereum rollups and L2 networks.
- **ERC-4337**: Compatible with Smart Contract Wallets and Passkey-based Account Abstraction.

---

## License

This project is licensed under the Apache-2.0 License - see the [LICENSE](LICENSE) file for details.
