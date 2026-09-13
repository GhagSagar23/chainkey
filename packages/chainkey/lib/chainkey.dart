import 'dart:typed_data';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

export 'package:chainkey_platform_interface/chainkey_platform_interface.dart'
    show
        HardwareIsolationLevel,
        BiometricPromptOptions,
        P256PublicKey,
        P256Signature,
        PasskeyCredential,
        ChainkeyException,
        UserCancelledException,
        KeyPermanentlyInvalidatedException,
        HardwareEnclaveException,
        PasskeyException;

/// Primary app-facing class for `chainkey`.
class Chainkey {
  const Chainkey();

  static ChainkeyPlatform get _platform => ChainkeyPlatform.instance;

  /// Generates a non-exportable NIST P-256 keypair in the device's hardware enclave
  /// (Secure Enclave on iOS, StrongBox/KeyMint on Android).
  Future<P256PublicKey> generateHardwareKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) {
    return _platform.generateHardwareKey(
      keyAlias: keyAlias,
      requireUserPresence: requireUserPresence,
    );
  }

  /// Signs an arbitrary 32-byte digest (e.g. ERC-4337 `userOpHash`) using the hardware key.
  /// Returns a normalized, low-S `P256Signature` ready for EVM / EIP-7212 verification.
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) {
    if (hash32.length != 32) {
      throw ArgumentError.value(
        hash32.length,
        'hash32',
        'Hash to sign must be exactly 32 bytes',
      );
    }
    return _platform.signWithHardwareKey(
      keyAlias: keyAlias,
      hash32: hash32,
      promptOptions: promptOptions,
    );
  }

  /// Deletes the keypair identified by [keyAlias] from the hardware enclave.
  Future<bool> deleteHardwareKey({required String keyAlias}) {
    return _platform.deleteHardwareKey(keyAlias: keyAlias);
  }

  /// Checks if the hardware isolation tier is supported on this device.
  Future<bool> isHardwareIsolationSupported(HardwareIsolationLevel level) {
    return _platform.isHardwareIsolationSupported(level);
  }
}
