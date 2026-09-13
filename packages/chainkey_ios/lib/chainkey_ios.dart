import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The iOS implementation of [ChainkeyPlatform].
class ChainkeyIos extends ChainkeyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dev.chainkey/chainkey_ios');

  /// Registers this class as the default instance of [ChainkeyPlatform].
  static void registerWith() {
    ChainkeyPlatform.instance = ChainkeyIos();
  }

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
      throw const HardwareEnclaveException(
        'Failed to generate hardware key on iOS Secure Enclave',
      );
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
      throw const HardwareEnclaveException(
        'Failed to sign with hardware key on iOS Secure Enclave',
      );
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
  Future<bool> isHardwareIsolationSupported(HardwareIsolationLevel level) async {
    final result = await methodChannel.invokeMethod<bool>(
      'isHardwareIsolationSupported',
      {'level': level.name},
    );
    return result ?? false;
  }
}
