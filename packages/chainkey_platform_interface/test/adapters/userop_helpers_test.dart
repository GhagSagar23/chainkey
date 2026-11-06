import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _addr(int fill) => Uint8List.fromList(List.filled(20, fill));

int _readUint256(Uint8List buf, int offset) {
  var value = 0;
  for (var i = 24; i < 32; i++) {
    value = (value << 8) | buf[offset + i];
  }
  return value;
}

Uint8List _readAddress(Uint8List buf, int offset) =>
    Uint8List.fromList(buf.sublist(offset + 12, offset + 32));

P256PublicKey _key() {
  final x = Uint8List(32)..[0] = 0xAA;
  final y = Uint8List(32)..[0] = 0xBB;
  return P256PublicKey.fromCoordinates(x: x, y: y);
}

void main() {
  group('encodeSafeAddOwnerCallData', () {
    test('produces correct ABI layout', () {
      final owner = _addr(0x11);
      final buf = encodeSafeAddOwnerCallData(ownerAddress: owner, threshold: 2);

      expect(buf.length, 68);
      // selector
      expect(buf.sublist(0, 4), [0x0d, 0x58, 0x2f, 0x13]);
      // address right-aligned
      expect(_readAddress(buf, 4), owner);
      // leading 12 bytes zero
      expect(buf.sublist(4, 16), Uint8List(12));
      // threshold
      expect(_readUint256(buf, 36), 2);
    });

    test('default threshold is 1', () {
      final buf = encodeSafeAddOwnerCallData(ownerAddress: _addr(0x22));
      expect(_readUint256(buf, 36), 1);
    });

    test('rejects non-20-byte address', () {
      expect(
        () => encodeSafeAddOwnerCallData(ownerAddress: Uint8List(19)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('encodeSafeRemoveOwnerCallData', () {
    test('produces correct ABI layout', () {
      final prev = _addr(0x01);
      final owner = _addr(0x02);
      final buf = encodeSafeRemoveOwnerCallData(
        prevOwner: prev,
        owner: owner,
        threshold: 1,
      );

      expect(buf.length, 100);
      expect(buf.sublist(0, 4), [0xf8, 0xdc, 0x5d, 0xd9]);
      expect(_readAddress(buf, 4), prev);
      expect(_readAddress(buf, 36), owner);
      expect(_readUint256(buf, 68), 1);
    });

    test('rejects invalid address lengths', () {
      expect(
        () => encodeSafeRemoveOwnerCallData(
          prevOwner: Uint8List(21),
          owner: _addr(0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('encodeErc7579InstallP256ValidatorCallData', () {
    test('produces correct ABI layout with P256 coordinates as initData', () {
      final module = _addr(0x33);
      final key = _key();
      final buf = encodeErc7579InstallP256ValidatorCallData(
        moduleAddress: module,
        publicKey: key,
      );

      // selector(4) + typeId(32) + addr(32) + offset(32) + len(32) + data(64) = 196
      expect(buf.length, 196);
      // selector
      expect(buf.sublist(0, 4), [0x95, 0x17, 0xe2, 0x9f]);
      // moduleTypeId = 1
      expect(_readUint256(buf, 4), 1);
      // module address
      expect(_readAddress(buf, 36), module);
      // offset to bytes = 96
      expect(_readUint256(buf, 68), 96);
      // bytes length = 64
      expect(_readUint256(buf, 100), 64);
      // x coordinate
      expect(buf.sublist(132, 164), key.x);
      // y coordinate
      expect(buf.sublist(164, 196), key.y);
    });

    test('rejects non-20-byte module address', () {
      expect(
        () => encodeErc7579InstallP256ValidatorCallData(
          moduleAddress: Uint8List(32),
          publicKey: _key(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('encodeErc7579UninstallValidatorCallData', () {
    test('encodes with empty deInitData', () {
      final module = _addr(0x44);
      final buf = encodeErc7579UninstallValidatorCallData(
        moduleAddress: module,
      );

      // selector(4) + typeId(32) + addr(32) + offset(32) + len(32) = 132
      expect(buf.length, 132);
      expect(buf.sublist(0, 4), [0xa7, 0x1d, 0x63, 0xa8]);
      expect(_readUint256(buf, 4), 1);
      expect(_readAddress(buf, 36), module);
      expect(_readUint256(buf, 68), 96);
      expect(_readUint256(buf, 100), 0);
    });

    test('encodes with provided deInitData', () {
      final module = _addr(0x55);
      final deInit = Uint8List.fromList(List.filled(20, 0xFF));
      final buf = encodeErc7579UninstallValidatorCallData(
        moduleAddress: module,
        deInitData: deInit,
      );

      // selector(4) + typeId(32) + addr(32) + offset(32) + len(32) + padded(32) = 164
      expect(buf.length, 164);
      expect(_readUint256(buf, 100), 20);
      expect(buf.sublist(132, 152), deInit);
      // padding bytes zero
      expect(buf.sublist(152, 164), Uint8List(12));
    });
  });
}
