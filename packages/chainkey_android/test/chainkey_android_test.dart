import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chainkey_android/chainkey_android.dart';
import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChainkeyAndroid plugin;
  late List<MethodCall> log;

  setUp(() {
    plugin = ChainkeyAndroid();
    log = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_android'),
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
              'isolationLevel': 'strongBox',
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
            final level = call.arguments['level'] as String;
            return level == 'tee' || level == 'strongBox';
          case 'registerPasskey':
            final x = Uint8List(32)..fillRange(0, 32, 0xCC);
            final y = Uint8List(32)..fillRange(0, 32, 0xDD);
            final uncompressed = Uint8List(65);
            uncompressed[0] = 0x04;
            uncompressed.setRange(1, 33, x);
            uncompressed.setRange(33, 65, y);
            return {
              'credentialId': 'cred-android-123',
              'rawAttestationObject': Uint8List.fromList([0xA3, 0x01]),
              'rawClientDataJson': Uint8List.fromList([0x7B, 0x7D]),
              'publicKey': {
                'keyAlias': 'cred-android-123',
                'x': x,
                'y': y,
                'uncompressedBytes': uncompressed,
                'isolationLevel': 'software',
              },
              'isolationLevel': 'software',
            };
          case 'assertPasskey':
            return {
              'credentialId': 'cred-android-123',
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
      const MethodChannel('dev.chainkey/chainkey_android'),
      null,
    );
  });

  test('can be registered as default platform instance', () {
    ChainkeyAndroid.registerWith();
    expect(ChainkeyPlatform.instance, isA<ChainkeyAndroid>());
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
    expect(key.isolationLevel, HardwareIsolationLevel.strongBox);
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

  test('isHardwareIsolationSupported returns true for tee', () async {
    final supported = await plugin.isHardwareIsolationSupported(
      HardwareIsolationLevel.tee,
    );
    expect(supported, true);
  });

  test('isHardwareIsolationSupported returns true for strongBox', () async {
    final supported = await plugin.isHardwareIsolationSupported(
      HardwareIsolationLevel.strongBox,
    );
    expect(supported, true);
  });

  test('isHardwareIsolationSupported returns false for secureEnclave',
      () async {
    final supported = await plugin.isHardwareIsolationSupported(
      HardwareIsolationLevel.secureEnclave,
    );
    expect(supported, false);
  });

  test('generateHardwareKey throws on PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_android'),
      (MethodCall call) async {
        throw PlatformException(
          code: 'KEY_GENERATION_ERROR',
          message: 'StrongBox unavailable',
        );
      },
    );

    expect(
      () => plugin.generateHardwareKey(keyAlias: 'fail'),
      throwsA(isA<ChainkeyException>()),
    );
  });

  test('signWithHardwareKey throws on KEY_PERMANENTLY_INVALIDATED', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.chainkey/chainkey_android'),
      (MethodCall call) async {
        throw PlatformException(
          code: 'KEY_PERMANENTLY_INVALIDATED',
          message: 'Key invalidated after biometric enrollment change',
        );
      },
    );

    expect(
      () => plugin.signWithHardwareKey(
        keyAlias: 'fail',
        hash32: Uint8List(32),
      ),
      throwsA(isA<KeyPermanentlyInvalidatedException>()),
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

    expect(credential.credentialId, 'cred-android-123');
    expect(credential.rawAttestationObject, isNotEmpty);
    expect(credential.rawClientDataJson, isNotEmpty);
    expect(credential.publicKey.x.length, 32);
    expect(credential.isolationLevel, HardwareIsolationLevel.software);
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
      const MethodChannel('dev.chainkey/chainkey_android'),
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

    expect(assertion.credentialId, 'cred-android-123');
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
      const MethodChannel('dev.chainkey/chainkey_android'),
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
