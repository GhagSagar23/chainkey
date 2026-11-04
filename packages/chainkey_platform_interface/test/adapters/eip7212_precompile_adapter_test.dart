import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _hex(String hex) {
  final clean = hex.replaceAll(' ', '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

P256Signature _sig({required Uint8List r, required Uint8List s}) =>
    P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

P256PublicKey _pubKey({required Uint8List x, required Uint8List y}) {
  final uncompressed = Uint8List(65)..[0] = 0x04;
  uncompressed.setRange(1, 33, x);
  uncompressed.setRange(33, 65, y);
  return P256PublicKey(
    keyAlias: 'test',
    x: x,
    y: y,
    uncompressedBytes: uncompressed,
    isolationLevel: HardwareIsolationLevel.software,
  );
}

void main() {
  group('encodeEip7212Payload', () {
    test('produces exactly 160 bytes', () {
      final payload = encodeEip7212Payload(
        messageHash: Uint8List(32),
        signature: _sig(r: Uint8List(32), s: Uint8List(32)),
        publicKey: _pubKey(x: Uint8List(32), y: Uint8List(32)),
      );
      expect(payload.length, 160);
    });

    test('layout: hash | r | s | x | y at correct offsets', () {
      final hash = Uint8List(32)..[0] = 0xAA;
      final r = Uint8List(32)..[0] = 0xBB;
      final s = Uint8List(32)..[0] = 0xCC;
      final x = Uint8List(32)..[0] = 0xDD;
      final y = Uint8List(32)..[0] = 0xEE;

      final payload = encodeEip7212Payload(
        messageHash: hash,
        signature: _sig(r: r, s: s),
        publicKey: _pubKey(x: x, y: y),
      );

      expect(payload.sublist(0, 32), hash);
      expect(payload.sublist(32, 64), r);
      expect(payload.sublist(64, 96), s);
      expect(payload.sublist(96, 128), x);
      expect(payload.sublist(128, 160), y);
    });

    test('encodes full-width scalars correctly', () {
      final hash = _hex(
          'bb5a52f42f9c9261ed4361f59422a1e30036e7c32b270c8807a419feca605023');
      final r = _hex(
          'c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
      final s = _hex(
          '60fea793b7d8ceaebfed22e9648a8ae6f24efbf6e16ebff4ccf7a4e29bddf47c');
      final x = _hex(
          '1ccbe91c075fc7f4f033bfa248db8fccd3565de94bbfb12f3c59ff46c271bf83');
      final y = _hex(
          'ce4014c68811f9a21a1fdb2c0e6113e06db7ca93b7404e78dc7ccd5ca89a4ca9');

      final payload = encodeEip7212Payload(
        messageHash: hash,
        signature: _sig(r: r, s: s),
        publicKey: _pubKey(x: x, y: y),
      );

      expect(payload.sublist(0, 32), hash);
      expect(payload.sublist(32, 64), r);
      expect(payload.sublist(64, 96), s);
      expect(payload.sublist(96, 128), x);
      expect(payload.sublist(128, 160), y);
    });

    test('throws ArgumentError for wrong hash length', () {
      expect(
        () => encodeEip7212Payload(
          messageHash: Uint8List(31),
          signature: _sig(r: Uint8List(32), s: Uint8List(32)),
          publicKey: _pubKey(x: Uint8List(32), y: Uint8List(32)),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => encodeEip7212Payload(
          messageHash: Uint8List(33),
          signature: _sig(r: Uint8List(32), s: Uint8List(32)),
          publicKey: _pubKey(x: Uint8List(32), y: Uint8List(32)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('precompile address constant is correct', () {
      expect(eip7212PrecompileAddress,
          '0x0000000000000000000000000000000000000100');
    });
  });
}
