import 'dart:typed_data';

import '../chainkey_platform_interface.dart';
import '../exceptions/chainkey_exceptions.dart';
import '../models/biometric_prompt_options.dart';
import '../models/key_invalidation_event.dart';
import '../models/p256_public_key.dart';
import '../models/p256_signature.dart';

/// Callback invoked when a hardware key is permanently invalidated.
///
/// The app should use this to update UI, log the event, and decide whether
/// to initiate on-chain key rotation via the UserOp helpers.
typedef OnKeyInvalidated = Future<void> Function(KeyInvalidationEvent event);

/// Wraps [ChainkeyPlatform] signing operations with automatic detection
/// and recovery from [KeyPermanentlyInvalidatedException].
///
/// Usage:
/// ```dart
/// final handler = KeyRecoveryHandler(
///   platform: ChainkeyPlatform.instance,
///   onKeyInvalidated: (event) async {
///     // notify user, update signer state, trigger rotation flow
///   },
/// );
///
/// try {
///   final sig = await handler.signWithRecovery(keyAlias: 'k1', hash32: hash);
/// } on KeyPermanentlyInvalidatedException {
///   final newKey = await handler.rotateKey(keyAlias: 'k1');
///   // submit on-chain key rotation UserOp with newKey
/// }
/// ```
class KeyRecoveryHandler {
  KeyRecoveryHandler({
    required ChainkeyPlatform platform,
    required OnKeyInvalidated onKeyInvalidated,
  })  : _platform = platform,
        _onKeyInvalidated = onKeyInvalidated;

  final ChainkeyPlatform _platform;
  final OnKeyInvalidated _onKeyInvalidated;

  /// Signs [hash32] with [keyAlias], catching key invalidation.
  ///
  /// On [KeyPermanentlyInvalidatedException]:
  /// 1. Fires [onKeyInvalidated] so the app can react.
  /// 2. Rethrows — the caller should then call [rotateKey] and submit
  ///    an on-chain key rotation UserOp.
  Future<P256Signature> signWithRecovery({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    try {
      return await _platform.signWithHardwareKey(
        keyAlias: keyAlias,
        hash32: hash32,
        promptOptions: promptOptions,
      );
    } on KeyPermanentlyInvalidatedException catch (e) {
      await _onKeyInvalidated(
        KeyInvalidationEvent(keyAlias: keyAlias, exception: e),
      );
      rethrow;
    }
  }

  /// Deletes the invalidated key and generates a fresh hardware keypair
  /// under the same [keyAlias].
  ///
  /// Returns the new [P256PublicKey] whose coordinates should be registered
  /// on-chain (via [encodeSafeAddOwnerCallData] or
  /// [encodeErc7579InstallP256ValidatorCallData]).
  Future<P256PublicKey> rotateKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) async {
    await _platform.deleteHardwareKey(keyAlias: keyAlias);
    return _platform.generateHardwareKey(
      keyAlias: keyAlias,
      requireUserPresence: requireUserPresence,
    );
  }
}
