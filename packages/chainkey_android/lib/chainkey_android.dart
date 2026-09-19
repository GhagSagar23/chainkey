import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Android implementation of [ChainkeyPlatform].
class ChainkeyAndroid extends ChainkeyPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dev.chainkey/chainkey_android');

  /// Registers this class as the default instance of [ChainkeyPlatform].
  static void registerWith() {
    ChainkeyPlatform.instance = ChainkeyAndroid();
  }

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
          'Failed to generate hardware key on Android',
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
          'Failed to sign with hardware key on Android',
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
}
