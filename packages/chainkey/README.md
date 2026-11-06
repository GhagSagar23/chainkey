<p align="center">
  <img src="../../assets/chainkey-logo.png" alt="ChainKey Logo" width="180" />
</p>

# chainkey

[![pub package](https://img.shields.io/pub/v/chainkey.svg)](https://pub.dev/packages/chainkey)
[![license](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/GhagSagar23/chainkey/blob/master/LICENSE)
[![CI](https://github.com/GhagSagar23/chainkey/actions/workflows/ci.yml/badge.svg)](https://github.com/GhagSagar23/chainkey/actions/workflows/ci.yml)
[![Pana](https://github.com/GhagSagar23/chainkey/actions/workflows/pana.yml/badge.svg)](https://github.com/GhagSagar23/chainkey/actions/workflows/pana.yml)

A turnkey Flutter plugin for **seedless Web3 authentication** and **smart contract account abstraction**.

`chainkey` generates non-exportable cryptographic keypairs inside hardware security enclaves (**Apple Secure Enclave**, **Android StrongBox / TEE**) and web authenticators (**W3C WebAuthn / Passkeys**). Private keys never leave the hardware chip; every signature requires biometric presence (Face ID, Touch ID, Fingerprint).

Signatures are emitted with pre-unpacked, low-S normalized `(r, s)` scalars ready for on-chain verification via **EIP-7212** precompiles or **ERC-4337** smart contract wallets.

---

## Features

- **Hardware key generation** — NIST P-256 keypairs in Secure Enclave / StrongBox / TEE
- **WebAuthn passkeys** — Registration and assertion on iOS, Android, and Web
- **Smart account adapters** — ABI encoders for Safe, ZeroDev Kernel v3, Biconomy Nexus
- **EIP-7212 precompile** — 160-byte payload serializer for on-chain P-256 verification
- **ERC-4337 UserOp helpers** — `callData` builders for multi-device key registration and revocation
- **Key recovery handler** — Automatic detection and recovery from `KeyPermanentlyInvalidatedException`
- **Multi-signer state** — Immutable device lifecycle tracking model

---

## Supported Platforms

| Platform | Hardware Isolation | Biometric | Key Curve |
| :--- | :--- | :--- | :--- |
| **iOS** | Secure Enclave (SEP) | Face ID / Touch ID | NIST P-256 |
| **Android** | StrongBox HSM / ARM TEE | BiometricPrompt | NIST P-256 |
| **Web** | Platform Authenticator | Passkeys / WebAuthn | NIST P-256 |

---

## Getting Started

### 1. Add Dependency

```yaml
dependencies:
  chainkey: ^0.5.0
```

### 2. Platform Setup

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to sign transactions securely.</string>
```

**Android** — ensure `minSdk >= 24` in `android/app/build.gradle`.

---

## Usage

### Hardware Key Generation

```dart
import 'package:chainkey/chainkey.dart';

const chainkey = Chainkey();

// Generate a non-exportable P-256 keypair in the hardware enclave
final key = await chainkey.generateHardwareKey(
  keyAlias: 'wallet_key_0',
  requireUserPresence: true,
);

print('X: ${key.x}');  // 32-byte big-endian
print('Y: ${key.y}');  // 32-byte big-endian
print('Isolation: ${key.isolationLevel}');
```

### Biometric Signing

```dart
final signature = await chainkey.signWithHardwareKey(
  keyAlias: 'wallet_key_0',
  hash32: userOpHash,  // 32-byte digest (e.g. ERC-4337 UserOpHash)
  promptOptions: const BiometricPromptOptions(
    title: 'Confirm Transaction',
    subtitle: 'Authorize transfer from smart account',
  ),
);

// Low-S normalized scalars for EIP-7212:
print('r: ${signature.r}');
print('s: ${signature.s}');
print('isLowS: ${signature.isLowS}');
```

### EIP-7212 Precompile Verification

```dart
// Build the 160-byte payload for the P-256 precompile (0x100)
final payload = encodeEip7212Payload(
  messageHash: userOpHash,
  signature: signature,
  publicKey: key,
);
// Submit via eth_call to 0x0000...0100 on Base, Arbitrum, etc.
```

### Smart Account Signature Adapters

```dart
// Safe 4337 WebAuthn Signer module
final safeSig = encodeSafePasskeySignature(
  signature: sig,
  authenticatorData: authData,
  clientDataJson: clientJson,
  clientDataParsed: clientParsed,
);

// ZeroDev Kernel v3 / Biconomy Nexus (ERC-7579)
final erc7579Sig = encodeErc7579WebAuthnSignature(
  signature: sig,
  authenticatorData: authData,
  clientDataJson: clientJson,
  clientDataParsed: clientParsed,
);
```

### Multi-Device Key Management

```dart
// Add a new device's key to the smart account (Safe)
final callData = encodeSafeAddOwnerCallData(
  ownerAddress: newSignerAddress,
  threshold: 1,
);

// Or via ERC-7579 validator module
final callData = encodeErc7579InstallP256ValidatorCallData(
  moduleAddress: validatorAddress,
  publicKey: newDeviceKey,
);

// Track signer lifecycle
var state = const MultiSignerState.empty();
state = state.addSigner(SignerEntry(
  credentialId: credential.credentialId,
  publicKey: key,
  label: 'iPhone 15',
));
```

### Key Recovery

```dart
final handler = KeyRecoveryHandler(
  platform: ChainkeyPlatform.instance,
  onKeyInvalidated: (event) async {
    // Notify user, update UI, trigger rotation flow
    print('Key ${event.keyAlias} was invalidated');
  },
);

try {
  final sig = await handler.signWithRecovery(
    keyAlias: 'wallet_key_0',
    hash32: hash,
  );
} on KeyPermanentlyInvalidatedException {
  // Rotate: delete old key, generate new, register on-chain
  final newKey = await handler.rotateKey(keyAlias: 'wallet_key_0');
}
```

---

## Standards Compliance

| Standard | Purpose |
| :--- | :--- |
| **NIST P-256** | Curve supported by Apple SEP, Android StrongBox, WebAuthn |
| **BIP-62 / EIP-2** | Low-S normalization preventing signature malleability |
| **EIP-7212** | EVM precompile for secp256r1 verification on L2s |
| **ERC-4337** | Account abstraction — UserOperation signing |
| **ERC-7579** | Modular smart account validator interface |
| **WebAuthn / FIDO2** | W3C credential API for passkey auth |

---

## Example App

See [`example/`](example/) for a production-grade reference app demonstrating seedless wallet creation, USDC transfer signing, and key recovery.

```bash
cd packages/chainkey/example
flutter run
```

---

## License

Apache-2.0 — see [LICENSE](../../LICENSE).
