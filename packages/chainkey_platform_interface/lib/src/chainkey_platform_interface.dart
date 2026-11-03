import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_chainkey.dart';
import 'models/biometric_prompt_options.dart';
import 'models/hardware_isolation_level.dart';
import 'models/p256_public_key.dart';
import 'models/p256_signature.dart';
import 'models/passkey_assertion_result.dart';
import 'models/passkey_credential.dart';

/// The interface that platform implementations of `chainkey` must extend.
///
/// Platform implementations should extend this class rather than implement it,
/// as `chainkey` may add new methods in the future.
abstract class ChainkeyPlatform extends PlatformInterface {
  ChainkeyPlatform() : super(token: _token);

  static final Object _token = Object();

  static ChainkeyPlatform _instance = MethodChannelChainkey();

  /// The default instance of [ChainkeyPlatform] to use.
  ///
  /// Defaults to [MethodChannelChainkey].
  static ChainkeyPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ChainkeyPlatform] when
  /// they register themselves.
  static set instance(ChainkeyPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Generates a non-exportable NIST P-256 keypair within the device's hardware security module
  /// (Secure Enclave on iOS, StrongBox/KeyMint on Android).
  Future<P256PublicKey> generateHardwareKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) {
    throw UnimplementedError('generateHardwareKey() has not been implemented.');
  }

  /// Signs a raw 32-byte digest (e.g. ERC-4337 UserOpHash) directly using the hardware key.
  /// Prompts for biometric authentication (FaceID/TouchID/BiometricPrompt) as configured.
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) {
    throw UnimplementedError('signWithHardwareKey() has not been implemented.');
  }

  /// Deletes the keypair identified by [keyAlias] from the hardware keystore.
  Future<bool> deleteHardwareKey({required String keyAlias}) {
    throw UnimplementedError('deleteHardwareKey() has not been implemented.');
  }

  /// Checks whether a specific hardware isolation tier is available on this physical device.
  Future<bool> isHardwareIsolationSupported(HardwareIsolationLevel level) {
    throw UnimplementedError(
      'isHardwareIsolationSupported() has not been implemented.',
    );
  }

  /// Registers a new WebAuthn passkey credential via native OS Credential APIs.
  Future<PasskeyCredential> registerPasskey({
    required String relyingPartyId,
    required String userName,
    required String userDisplayName,
    required Uint8List userId,
    required Uint8List challenge,
    bool requireUserVerification = true,
  }) {
    throw UnimplementedError('registerPasskey() has not been implemented.');
  }

  /// Asserts an existing WebAuthn passkey credential to sign a challenge.
  Future<PasskeyAssertionResult> assertPasskey({
    required String relyingPartyId,
    required Uint8List challenge,
    List<String>? allowedCredentialIds,
    bool requireUserVerification = true,
  }) {
    throw UnimplementedError('assertPasskey() has not been implemented.');
  }
}
