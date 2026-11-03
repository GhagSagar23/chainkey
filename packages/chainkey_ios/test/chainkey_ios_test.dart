import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_ios/chainkey_ios.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChainkeyIos plugin;
  late List<MethodCall> log;

  setUp(() {
    plugin = ChainkeyIos();
    log = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_ios'),
      (MethodCall call) async {
        log.add(call);
        switch (call.method) {
          case 'generateHardwareKey':
            final x = Uint8List(32)..fillRange(0, 32, 0xAA);
            final y = Uint8List(32)..fillRange(0, 32, 0xBB);
            final uncompressed = Uint8List(65);
            uncompressed[0] = 0x04;
            uncompressed.setRange(1, 33, x);
            uncompressed.setRange(33, 65, y);
            return {
              'keyAlias': call.arguments['keyAlias'],
              'x': x,
              'y': y,
              'uncompressedBytes': uncompressed,
              'isolationLevel': 'secureEnclave',
            };
          case 'signWithHardwareKey':
            return {
              'r': Uint8List(32)..fillRange(0, 32, 0x11),
              's': Uint8List(32)..fillRange(0, 32, 0x22),
              'rawDerSignature': Uint8List(0),
            };
          case 'deleteHardwareKey':
            return true;
          case 'isHardwareIsolationSupported':
            return call.arguments['level'] == 'secureEnclave';
          case 'registerPasskey':
            final x = Uint8List(32)..fillRange(0, 32, 0xCC);
            final y = Uint8List(32)..fillRange(0, 32, 0xDD);
            final uncompressed = Uint8List(65);
            uncompressed[0] = 0x04;
            uncompressed.setRange(1, 33, x);
            uncompressed.setRange(33, 65, y);
            return {
              'credentialId': 'cred-abc123',
              'rawAttestationObject': Uint8List.fromList([0xA3, 0x01]),
              'rawClientDataJson': Uint8List.fromList([0x7B, 0x7D]),
              'publicKey': {
                'keyAlias': 'cred-abc123',
                'x': x,
                'y': y,
                'uncompressedBytes': uncompressed,
                'isolationLevel': 'secureEnclave',
              },
              'isolationLevel': 'secureEnclave',
            };
          case 'assertPasskey':
            return {
              'credentialId': 'cred-abc123',
              'authenticatorData': Uint8List.fromList(
                List.generate(37, (i) => i),
              ),
              'clientDataJson': Uint8List.fromList([0x7B, 0x7D]),
              'signature': {
                'r': Uint8List(32)..fillRange(0, 32, 0x33),
                's': Uint8List(32)..fillRange(0, 32, 0x44),
                'rawDerSignature': Uint8List(0),
              },
              'userHandle': Uint8List.fromList([0x01, 0x02]),
            };
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_ios'),
      null,
    );
  });

  test('can be registered as default platform instance', () {
    ChainkeyIos.registerWith();
    expect(ChainkeyPlatform.instance, isA<ChainkeyIos>());
  });

  test('generateHardwareKey sends correct arguments and parses response',
      () async {
    final key = await plugin.generateHardwareKey(keyAlias: 'test-key');

    expect(log.single.method, 'generateHardwareKey');
    expect(log.single.arguments['keyAlias'], 'test-key');
    expect(log.single.arguments['requireUserPresence'], true);

    expect(key.keyAlias, 'test-key');
    expect(key.x.length, 32);
    expect(key.y.length, 32);
    expect(key.uncompressedBytes[0], 0x04);
    expect(key.isolationLevel, HardwareIsolationLevel.secureEnclave);
  });

  test('generateHardwareKey passes requireUserPresence=false', () async {
    await plugin.generateHardwareKey(
      keyAlias: 'no-bio',
      requireUserPresence: false,
    );

    expect(log.single.arguments['requireUserPresence'], false);
  });

  test('signWithHardwareKey sends correct arguments and parses response',
      () async {
    final hash = Uint8List(32)..fillRange(0, 32, 0xFF);
    final sig = await plugin.signWithHardwareKey(
      keyAlias: 'test-key',
      hash32: hash,
    );

    expect(log.single.method, 'signWithHardwareKey');
    expect(log.single.arguments['keyAlias'], 'test-key');
    expect(log.single.arguments['hash32'], hash);

    expect(sig.r.length, 32);
    expect(sig.s.length, 32);
  });

  test('deleteHardwareKey sends correct arguments', () async {
    final deleted = await plugin.deleteHardwareKey(keyAlias: 'test-key');

    expect(log.single.method, 'deleteHardwareKey');
    expect(log.single.arguments['keyAlias'], 'test-key');
    expect(deleted, true);
  });

  test('isHardwareIsolationSupported returns true for secureEnclave', () async {
    final supported = await plugin.isHardwareIsolationSupported(
      HardwareIsolationLevel.secureEnclave,
    );
    expect(supported, true);
  });

  test('isHardwareIsolationSupported returns false for strongBox', () async {
    final supported = await plugin.isHardwareIsolationSupported(
      HardwareIsolationLevel.strongBox,
    );
    expect(supported, false);
  });

  test('generateHardwareKey throws on PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_ios'),
      (MethodCall call) async {
        throw PlatformException(
          code: 'KEY_GENERATION_ERROR',
          message: 'Secure Enclave unavailable',
        );
      },
    );

    expect(
      () => plugin.generateHardwareKey(keyAlias: 'fail'),
      throwsA(isA<ChainkeyException>()),
    );
  });

  // MARK: - Passkey registration tests

  test('registerPasskey sends correct arguments and parses response', () async {
    final userId = Uint8List.fromList([0x01, 0x02, 0x03]);
    final challenge = Uint8List(32)..fillRange(0, 32, 0xAB);

    final credential = await plugin.registerPasskey(
      relyingPartyId: 'wallet.example.com',
      userName: 'user@example.com',
      userDisplayName: 'Test User',
      userId: userId,
      challenge: challenge,
    );

    expect(log.single.method, 'registerPasskey');
    expect(log.single.arguments['relyingPartyId'], 'wallet.example.com');
    expect(log.single.arguments['userName'], 'user@example.com');
    expect(log.single.arguments['userDisplayName'], 'Test User');
    expect(log.single.arguments['userId'], userId);
    expect(log.single.arguments['challenge'], challenge);
    expect(log.single.arguments['requireUserVerification'], true);

    expect(credential.credentialId, 'cred-abc123');
    expect(credential.rawAttestationObject, isNotEmpty);
    expect(credential.rawClientDataJson, isNotEmpty);
    expect(credential.publicKey.x.length, 32);
    expect(credential.isolationLevel, HardwareIsolationLevel.secureEnclave);
  });

  test('registerPasskey passes requireUserVerification=false', () async {
    await plugin.registerPasskey(
      relyingPartyId: 'wallet.example.com',
      userName: 'user@example.com',
      userDisplayName: 'Test User',
      userId: Uint8List.fromList([0x01]),
      challenge: Uint8List(32),
      requireUserVerification: false,
    );

    expect(log.single.arguments['requireUserVerification'], false);
  });

  test('registerPasskey throws PasskeyException on PlatformException',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_ios'),
      (MethodCall call) async {
        throw PlatformException(
          code: 'PASSKEY_ERROR',
          message: 'Registration failed',
        );
      },
    );

    expect(
      () => plugin.registerPasskey(
        relyingPartyId: 'example.com',
        userName: 'user',
        userDisplayName: 'User',
        userId: Uint8List(1),
        challenge: Uint8List(32),
      ),
      throwsA(isA<PasskeyException>()),
    );
  });

  // MARK: - Passkey assertion tests

  test('assertPasskey sends correct arguments and parses response', () async {
    final challenge = Uint8List(32)..fillRange(0, 32, 0xCD);

    final assertion = await plugin.assertPasskey(
      relyingPartyId: 'wallet.example.com',
      challenge: challenge,
    );

    expect(log.single.method, 'assertPasskey');
    expect(log.single.arguments['relyingPartyId'], 'wallet.example.com');
    expect(log.single.arguments['challenge'], challenge);
    expect(log.single.arguments['requireUserVerification'], true);
    expect(log.single.arguments.containsKey('allowedCredentialIds'), false);

    expect(assertion.credentialId, 'cred-abc123');
    expect(assertion.authenticatorData.length, 37);
    expect(assertion.clientDataJson, isNotEmpty);
    expect(assertion.signature.r.length, 32);
    expect(assertion.signature.s.length, 32);
    expect(assertion.userHandle, isNotNull);
  });

  test('assertPasskey passes allowedCredentialIds', () async {
    await plugin.assertPasskey(
      relyingPartyId: 'wallet.example.com',
      challenge: Uint8List(32),
      allowedCredentialIds: ['cred-1', 'cred-2'],
    );

    final args = log.single.arguments as Map;
    expect(args['allowedCredentialIds'], ['cred-1', 'cred-2']);
  });

  test('assertPasskey maps USER_CANCELLED to UserCancelledException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_ios'),
      (MethodCall call) async {
        throw PlatformException(
          code: 'USER_CANCELLED',
          message: 'User cancelled passkey operation',
        );
      },
    );

    expect(
      () => plugin.assertPasskey(
        relyingPartyId: 'example.com',
        challenge: Uint8List(32),
      ),
      throwsA(isA<UserCancelledException>()),
    );
  });
}
