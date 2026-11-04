import 'dart:convert';
import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List _hex(String hex) {
  final clean = hex.replaceAll(' ', '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

int _readUint256(Uint8List buf, int offset) {
  var value = 0;
  for (var i = 24; i < 32; i++) {
    value = (value << 8) | buf[offset + i];
  }
  return value;
}

P256Signature _sig({required Uint8List r, required Uint8List s}) =>
    P256Signature(r: r, s: s, rawDerSignature: Uint8List(0));

void main() {
  group('encodeErc7579WebAuthnSignature', () {
    test('field order matches WebAuthnAuth struct', () {
      final r = Uint8List(32)..[31] = 0x01;
      final s = Uint8List(32)..[31] = 0x02;
      final authData = Uint8List(37);
      const clientStr =
          '{"type":"webauthn.get","challenge":"dGVzdA","origin":"https://example.com"}';
      final clientData = _utf8(clientStr);
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeErc7579WebAuthnSignature(
        signature: _sig(r: r, s: s),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      // Slot 0: offset to authenticatorData (dynamic)
      final authDataOffset = _readUint256(encoded, 0);
      expect(authDataOffset, 192);

      // Slot 1: offset to clientDataJSON (dynamic)
      final clientDataOffset = _readUint256(encoded, 32);
      expect(clientDataOffset, greaterThan(192));

      // Slot 2: responseTypeLocation
      final responseTypeLoc = _readUint256(encoded, 64);
      expect(responseTypeLoc, clientParsed.typeOffset);

      // Slot 3: challengeLocation
      final challengeLoc = _readUint256(encoded, 96);
      expect(challengeLoc, clientParsed.challengeOffset);

      // Slots 4–5: rs[0]=r, rs[1]=s (inline, not offset)
      expect(encoded.sublist(128, 160), r);
      expect(encoded.sublist(160, 192), s);
    });

    test('differs from Safe encoding in field order', () {
      final r = Uint8List(32)..[31] = 0xAA;
      final s = Uint8List(32)..[31] = 0xBB;
      final authData = Uint8List(37);
      final clientData = _utf8('{"type":"webauthn.get","challenge":"YQ"}');
      final clientParsed = ClientDataJson.parse(clientData);

      final erc7579 = encodeErc7579WebAuthnSignature(
        signature: _sig(r: r, s: s),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );
      final safe = encodeSafePasskeySignature(
        signature: _sig(r: r, s: s),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      // Same total size (same data, same number of ABI slots)
      expect(erc7579.length, safe.length);

      // But different byte content (different field ordering)
      expect(erc7579, isNot(equals(safe)));

      // Safe puts r,s at slots 0-1; ERC-7579 puts them at slots 4-5
      expect(safe.sublist(0, 32), r); // Safe: r first
      expect(erc7579.sublist(128, 160), r); // ERC-7579: r at slot 4
    });

    test('dynamic data is correctly placed and padded', () {
      final authData = Uint8List.fromList(List.filled(50, 0xCC));
      final clientData = _utf8('{"type":"webauthn.get","challenge":"AAAA"}');
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeErc7579WebAuthnSignature(
        signature: _sig(r: Uint8List(32), s: Uint8List(32)),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      expect(encoded.length % 32, 0);

      final authDataOffset = _readUint256(encoded, 0);
      final authLen = _readUint256(encoded, authDataOffset);
      expect(authLen, 50);
      expect(encoded.sublist(authDataOffset + 32, authDataOffset + 32 + 50),
          authData);

      final clientDataOffset = _readUint256(encoded, 32);
      final clientLen = _readUint256(encoded, clientDataOffset);
      expect(clientLen, clientData.length);
      expect(
        encoded.sublist(
            clientDataOffset + 32, clientDataOffset + 32 + clientData.length),
        clientData,
      );
    });

    test('offsets chain for varying authData sizes', () {
      for (final authSize in [0, 1, 31, 32, 33, 64, 100]) {
        final authData = Uint8List(authSize);
        final clientData = _utf8('{"type":"webauthn.get","challenge":"YQ"}');
        final clientParsed = ClientDataJson.parse(clientData);

        final encoded = encodeErc7579WebAuthnSignature(
          signature: _sig(r: Uint8List(32), s: Uint8List(32)),
          authenticatorData: authData,
          clientDataJson: clientData,
          clientDataParsed: clientParsed,
        );

        final authDataOffset = _readUint256(encoded, 0);
        final clientDataOffset = _readUint256(encoded, 32);
        final authPadded = ((authSize + 31) ~/ 32) * 32;
        expect(clientDataOffset, authDataOffset + 32 + authPadded,
            reason: 'authSize=$authSize');
      }
    });

    test('encodes full 32-byte r and s values in slots 4-5', () {
      final r = _hex(
          'c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
      final s = _hex(
          '60fea793b7d8ceaebfed22e9648a8ae6f24efbf6e16ebff4ccf7a4e29bddf47c');
      final authData = Uint8List(37);
      final clientData = _utf8('{"type":"webauthn.get","challenge":"dGVzdA"}');
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeErc7579WebAuthnSignature(
        signature: _sig(r: r, s: s),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      expect(encoded.sublist(128, 160), r);
      expect(encoded.sublist(160, 192), s);
    });
  });
}
