import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'chainkey_platform_interface.dart';
import 'models/biometric_prompt_options.dart';
import 'models/hardware_isolation_level.dart';
import 'models/p256_public_key.dart';
import 'models/p256_signature.dart';

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
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'generateHardwareKey',
      {
        'keyAlias': keyAlias,
        'requireUserPresence': requireUserPresence,
      },
    );
    if (result == null) {
      throw StateError('Failed to receive response for generateHardwareKey');
    }
    return P256PublicKey.fromMap(result);
  }

  @override
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'signWithHardwareKey',
      {
        'keyAlias': keyAlias,
        'hash32': hash32,
        if (promptOptions != null) 'promptOptions': promptOptions.toMap(),
      },
    );
    if (result == null) {
      throw StateError('Failed to receive response for signWithHardwareKey');
    }
    return P256Signature.fromMap(result);
  }

  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async {
    final result = await methodChannel.invokeMethod<bool>(
      'deleteHardwareKey',
      {'keyAlias': keyAlias},
    );
    return result ?? false;
  }

  @override
  Future<bool> isHardwareIsolationSupported(
      HardwareIsolationLevel level) async {
    final result = await methodChannel.invokeMethod<bool>(
      'isHardwareIsolationSupported',
      {'level': level.name},
    );
    return result ?? false;
  }
}
