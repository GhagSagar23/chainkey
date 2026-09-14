# chainkey_android

Android platform implementation for the [`chainkey`](https://pub.dev/packages/chainkey) federated plugin.

This package provides native Android hardware security enclave integration using AndroidKeyStore, StrongBox KeyMint, and the Android BiometricPrompt API.

---

## Features

- **Hardware Enclave Backing**: Generates non-exportable NIST P-256 (`secp256r1`) private keys inside dedicated hardware (StrongBox HSM chip on supported devices, or ARM TrustZone TEE).
- **Biometric User Presence**: Integrates with Android `BiometricPrompt` to enforce biometric or device passcode authentication prior to signing operations.
- **ERC-4337 & EIP-7212 Compliance**: Produces ASN.1 DER signatures and automatically computes low-$S$ normalized scalar components `(r, s)` to prevent signature malleability.
- **Hardware Key Attestation**: Supports Android Keystore X.509 attestation certificate chains embedding server challenge nonces.

---

## Minimum Requirements

- **Android SDK (minSdk)**: `24` (Android 7.0 Nougat)
- **Compile SDK**: `34+`
- **JDK**: `17`

---

## Usage

This package is endorsed by the main [`chainkey`](https://pub.dev/packages/chainkey) package. When adding `chainkey` to your `pubspec.yaml`, `chainkey_android` is automatically included and registered:

```yaml
dependencies:
  chainkey: ^0.1.0
```

To invoke hardware isolation methods from Flutter:

```dart
import 'package:chainkey/chainkey.dart';

final supported = await Chainkey.instance.isHardwareIsolationSupported(
  HardwareIsolationLevel.strongBox,
);
```

---

## Issues & Contributing

For bug reports, feature requests, and contributing guidelines, please visit the [Chainkey GitHub Repository](https://github.com/GhagSagar23/chainkey).
