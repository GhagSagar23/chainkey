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
}
