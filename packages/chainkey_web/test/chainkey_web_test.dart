import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:chainkey_web/chainkey_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChainkeyWeb plugin;

  setUp(() {
    plugin = ChainkeyWeb();
  });

  test('isHardwareIsolationSupported returns true only for software tier',
      () async {
    expect(
      await plugin
          .isHardwareIsolationSupported(HardwareIsolationLevel.software),
      isTrue,
    );
    expect(
      await plugin
          .isHardwareIsolationSupported(HardwareIsolationLevel.secureEnclave),
      isFalse,
    );
    expect(
      await plugin
          .isHardwareIsolationSupported(HardwareIsolationLevel.strongBox),
      isFalse,
    );
    expect(
      await plugin.isHardwareIsolationSupported(HardwareIsolationLevel.tee),
      isFalse,
    );
  });

  test('generateHardwareKey throws PasskeyException on web', () async {
    expect(
      () => plugin.generateHardwareKey(keyAlias: 'test'),
      throwsA(isA<PasskeyException>()),
    );
  });

  test('signWithHardwareKey throws PasskeyException on web', () async {
    expect(
      () => plugin.signWithHardwareKey(
        keyAlias: 'test',
        hash32: Uint8List(32),
      ),
      throwsA(isA<PasskeyException>()),
    );
  });

  test('deleteHardwareKey returns false on web', () async {
    expect(await plugin.deleteHardwareKey(keyAlias: 'test'), isFalse);
  });

  // In Chrome test env, WebAuthn IS available but calls fail with
  // SecurityError (no real RP domain). Verify we get PasskeyException.
  test('registerPasskey throws PasskeyException in test environment', () async {
    expect(
      () => plugin.registerPasskey(
        relyingPartyId: 'example.com',
        userName: 'user',
        userDisplayName: 'User',
        userId: Uint8List.fromList([1, 2, 3]),
        challenge: Uint8List(32),
      ),
      throwsA(isA<PasskeyException>()),
    );
  });

  test('assertPasskey throws PasskeyException in test environment', () async {
    expect(
      () => plugin.assertPasskey(
        relyingPartyId: 'example.com',
        challenge: Uint8List(32),
      ),
      throwsA(isA<PasskeyException>()),
    );
  });
}
