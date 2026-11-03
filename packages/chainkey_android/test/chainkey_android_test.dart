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
}
