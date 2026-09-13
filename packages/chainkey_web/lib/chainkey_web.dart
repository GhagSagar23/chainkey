import 'dart:typed_data';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// The Web implementation of [ChainkeyPlatform].
class ChainkeyWeb extends ChainkeyPlatform {
  /// Registers this class as the default instance of [ChainkeyPlatform].
  static void registerWith(Registrar registrar) {
    ChainkeyPlatform.instance = ChainkeyWeb();
  }

  @override
  Future<P256PublicKey> generateHardwareKey({
    required String keyAlias,
    bool requireUserPresence = true,
  }) async {
    throw const PasskeyException(
      'Direct hardware keygen is not available on web; use WebAuthn passkey registration.',
    );
  }

  @override
  Future<P256Signature> signWithHardwareKey({
    required String keyAlias,
    required Uint8List hash32,
    BiometricPromptOptions? promptOptions,
  }) async {
    throw const PasskeyException(
      'Direct hardware signing is not available on web; use WebAuthn assertion.',
    );
  }

  @override
  Future<bool> deleteHardwareKey({required String keyAlias}) async {
    return false;
  }

  @override
  Future<bool> isHardwareIsolationSupported(HardwareIsolationLevel level) async {
    // Web only supports browser/software-backed WebAuthn credentials
    return level == HardwareIsolationLevel.software;
  }
}
