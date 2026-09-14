# chainkey_platform_interface

A common platform interface for the [`chainkey`](https://pub.dev/packages/chainkey) federated plugin.

This package defines the core abstractions, data models, exceptions, and Pigeon-generated host API contracts implemented by platform-specific packages (`chainkey_android`, `chainkey_ios`, and `chainkey_web`).

---

## Architecture Overview

`chainkey` uses the [federated plugin architecture](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins). Platform implementations extend `ChainkeyPlatform` to handle native hardware-isolated security enclaves and WebAuthn authenticators:

- **App-facing package**: [`chainkey`](https://pub.dev/packages/chainkey)
- **Platform interface**: `chainkey_platform_interface` (this package)
- **Android implementation**: [`chainkey_android`](https://pub.dev/packages/chainkey_android)
- **iOS implementation**: [`chainkey_ios`](https://pub.dev/packages/chainkey_ios)
- **Web implementation**: [`chainkey_web`](https://pub.dev/packages/chainkey_web)

---

## Core Models

### `HardwareIsolationLevel`
Defines the hardware security boundary protecting the cryptographic keypair:
- `secureEnclave`: Apple Secure Enclave Processor (SEP).
- `strongBox`: Dedicated hardware security chip (Android StrongBox Keymaster / KeyMint).
- `tee`: Trusted Execution Environment (Android ARM TrustZone).
- `software`: Platform keystore or browser-managed software sandbox.

### `EnclavePublicKey`
Represents an elliptic curve public key generated within the enclave:
- `x`: 32-byte big-endian X-coordinate on the NIST P-256 (secp256r1) curve.
- `y`: 32-byte big-endian Y-coordinate on the NIST P-256 curve.
- `uncompressedBytes`: 65-byte uncompressed SEC1 representation (`0x04 || X || Y`).
- `isolationLevel`: Confirmed isolation level.

### `DerSignatureResult`
Cryptographic signature produced by the enclave:
- `rawDerSignature`: ASN.1 DER-encoded signature bytes.
- `r`: 32-byte big-endian scalar component.
- `s`: 32-byte big-endian scalar component.
- `isLowS`: Indicates whether $s$ is normalized to low-$S$ ($s \le n/2$) per BIP-62 / EIP-2.

---

## Usage for Platform Implementers

To implement a new platform for `chainkey`, extend `ChainkeyPlatform`:

```dart
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

class CustomChainkeyPlatform extends ChainkeyPlatform {
  static void registerWith() {
    ChainkeyPlatform.instance = CustomChainkeyPlatform();
  }

  @override
  Future<bool> isHardwareIsolationSupported(HardwareIsolationLevel level) async {
    // Custom platform isolation check
    return true;
  }
}
```

---

## Issues & Contributing

For issues, bug reports, and feature requests, please visit the [Chainkey GitHub Repository](https://github.com/GhagSagar23/chainkey/issues).
