import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'chainkey_platform_interface.dart';
import 'exceptions/chainkey_exceptions.dart';
import 'models/biometric_prompt_options.dart';
import 'models/hardware_isolation_level.dart';
import 'models/p256_public_key.dart';
import 'models/p256_signature.dart';
import 'models/passkey_assertion_result.dart';
import 'models/passkey_credential.dart';

/// An implementation of [ChainkeyPlatform] that uses method channels.
class MethodChannelChainkey extends ChainkeyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dev.chainkey/chainkey');

  @override
  Future<P256PublicKey> generateHardwareKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) async {
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'generateHardwareKey',
        {
          'keyAlias': keyAlias,
          'requireUserPresence': requireUserPresence,
        },
      );
      if (result == null) {
        throw const HardwareEnclaveException(
          'Failed to receive response for generateHardwareKey',
        );
      }
      return P256PublicKey.fromMap(result);
    } on PlatformException catch (e) {
      throw ChainkeyException.fromPlatformException(e);
    }
  }

  @override
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'signWithHardwareKey',
        {
          'keyAlias': keyAlias,
          'hash32': hash32,
          if (promptOptions != null) 'promptOptions': promptOptions.toMap(),
        },
      );
      if (result == null) {
        throw const HardwareEnclaveException(
          'Failed to receive response for signWithHardwareKey',
        );
      }
      return P256Signature.fromMap(result);
    } on PlatformException catch (e) {
      throw ChainkeyException.fromPlatformException(e);
    }
  }

  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'deleteHardwareKey',
        {'keyAlias': keyAlias},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw ChainkeyException.fromPlatformException(e);
    }
  }

  @override
  Future<bool> isHardwareIsolationSupported(
      HardwareIsolationLevel level) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'isHardwareIsolationSupported',
        {'level': level.name},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw ChainkeyException.fromPlatformException(e);
    }
  }

  @override
  Future<PasskeyCredential> registerPasskey({
    required String relyingPartyId,
    required String userName,
    required String userDisplayName,
    required Uint8List userId,
    required Uint8List challenge,
    bool requireUserVerification = true,
  }) async {
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'registerPasskey',
        {
          'relyingPartyId': relyingPartyId,
          'userName': userName,
          'userDisplayName': userDisplayName,
          'userId': userId,
          'challenge': challenge,
          'requireUserVerification': requireUserVerification,
        },
      );
      if (result == null) {
        throw const PasskeyException(
          'Failed to receive response for registerPasskey',
        );
      }
      return PasskeyCredential.fromMap(result);
    } on PlatformException catch (e) {
      throw ChainkeyException.fromPlatformException(e);
    }
  }

  @override
  Future<PasskeyAssertionResult> assertPasskey({
    required String relyingPartyId,
    required Uint8List challenge,
    List<String>? allowedCredentialIds,
    bool requireUserVerification = true,
  }) async {
    try {
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'assertPasskey',
        {
          'relyingPartyId': relyingPartyId,
          'challenge': challenge,
          if (allowedCredentialIds != null)
            'allowedCredentialIds': allowedCredentialIds,
          'requireUserVerification': requireUserVerification,
        },
      );
      if (result == null) {
        throw const PasskeyException(
          'Failed to receive response for assertPasskey',
        );
      }
      return PasskeyAssertionResult.fromMap(result);
    } on PlatformException catch (e) {
      throw ChainkeyException.fromPlatformException(e);
    }
  }
}
