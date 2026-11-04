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
  group('encodeSafePasskeySignature', () {
    test('produces correct ABI layout for known inputs', () {
      final r = Uint8List(32)..[31] = 0x01;
      final s = Uint8List(32)..[31] = 0x02;
      final authData = Uint8List.fromList(List.filled(37, 0xAA));
      const clientStr =
          '{"type":"webauthn.get","challenge":"dGVzdA","origin":"https://example.com"}';
      final clientData = _utf8(clientStr);
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeSafePasskeySignature(
        signature: _sig(r: r, s: s),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      // Head: 6 × 32 = 192 bytes
      // r at [0..31]
      expect(encoded.sublist(0, 32), r);
      // s at [32..63]
      expect(encoded.sublist(32, 64), s);

      // Dynamic offsets
      final authDataOffset = _readUint256(encoded, 64);
      final clientDataOffset = _readUint256(encoded, 96);
      expect(authDataOffset, 192); // 6 * 32

      // challengeLocation and responseTypeLocation
      final challengeLoc = _readUint256(encoded, 128);
      final typeLoc = _readUint256(encoded, 160);
      expect(challengeLoc, clientParsed.challengeOffset);
      expect(typeLoc, clientParsed.typeOffset);

      // authenticatorData dynamic section
      final authLen = _readUint256(encoded, authDataOffset);
      expect(authLen, 37);
      expect(encoded.sublist(authDataOffset + 32, authDataOffset + 32 + 37),
          authData);

      // clientDataJSON dynamic section
      final clientLen = _readUint256(encoded, clientDataOffset);
      expect(clientLen, clientData.length);
      expect(
          encoded.sublist(
              clientDataOffset + 32, clientDataOffset + 32 + clientData.length),
          clientData);
    });

    test('pads dynamic bytes to 32-byte boundaries', () {
      final r = Uint8List(32);
      final s = Uint8List(32);
      // 37 bytes → padded to 64 (2 * 32)
      final authData = Uint8List(37);
      final clientData = _utf8('{"type":"webauthn.get","challenge":"YQ"}');
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeSafePasskeySignature(
        signature: _sig(r: r, s: s),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      // Total should be 32-aligned
      expect(encoded.length % 32, 0);

      // Padding bytes should be zero
      final authDataOffset = _readUint256(encoded, 64);
      final authLen = _readUint256(encoded, authDataOffset);
      final padStart = authDataOffset + 32 + authLen;
      final padEnd = authDataOffset + 32 + ((authLen + 31) ~/ 32) * 32;
      for (var i = padStart; i < padEnd; i++) {
        expect(encoded[i], 0, reason: 'padding byte at $i should be 0');
      }
    });

    test('offsets chain correctly for varying authData sizes', () {
      for (final authSize in [0, 1, 31, 32, 33, 64, 100]) {
        final authData = Uint8List(authSize);
        final clientData = _utf8('{"type":"webauthn.get","challenge":"YQ"}');
        final clientParsed = ClientDataJson.parse(clientData);

        final encoded = encodeSafePasskeySignature(
          signature: _sig(r: Uint8List(32), s: Uint8List(32)),
          authenticatorData: authData,
          clientDataJson: clientData,
          clientDataParsed: clientParsed,
        );

        final authDataOffset = _readUint256(encoded, 64);
        final clientDataOffset = _readUint256(encoded, 96);

        final authPadded = ((authSize + 31) ~/ 32) * 32;
        expect(clientDataOffset, authDataOffset + 32 + authPadded,
            reason: 'authSize=$authSize');

        // Verify clientDataJSON is readable at that offset
        final clientLen = _readUint256(encoded, clientDataOffset);
        expect(clientLen, clientData.length, reason: 'authSize=$authSize');
      }
    });

    test('encodes full 32-byte r and s values', () {
      final r = _hex(
          'c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
      final s = _hex(
          '60fea793b7d8ceaebfed22e9648a8ae6f24efbf6e16ebff4ccf7a4e29bddf47c');
      final authData = Uint8List(37);
      final clientData = _utf8('{"type":"webauthn.get","challenge":"dGVzdA"}');
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeSafePasskeySignature(
        signature: _sig(r: r, s: s),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      expect(encoded.sublist(0, 32), r);
      expect(encoded.sublist(32, 64), s);
    });

    test('empty authenticatorData produces valid encoding', () {
      final authData = Uint8List(0);
      final clientData = _utf8('{"type":"webauthn.get","challenge":"YQ"}');
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeSafePasskeySignature(
        signature: _sig(r: Uint8List(32), s: Uint8List(32)),
        authenticatorData: authData,
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      final authDataOffset = _readUint256(encoded, 64);
      final authLen = _readUint256(encoded, authDataOffset);
      expect(authLen, 0);

      // clientDataJSON immediately follows (no padding needed for 0-length)
      final clientDataOffset = _readUint256(encoded, 96);
      expect(clientDataOffset, authDataOffset + 32);
    });

    test('reversed JSON key order produces correct offsets', () {
      final clientData =
          _utf8('{"challenge":"Zm9v","type":"webauthn.get","origin":"https://example.com"}');
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeSafePasskeySignature(
        signature: _sig(r: Uint8List(32), s: Uint8List(32)),
        authenticatorData: Uint8List(37),
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      // challengeLocation should point into the clientDataJSON, not type
      final challengeLoc = _readUint256(encoded, 128);
      final typeLoc = _readUint256(encoded, 160);
      expect(clientParsed.challenge, 'Zm9v');
      expect(clientParsed.type, 'webauthn.get');
      // challenge comes first in this JSON, so its offset < type offset
      expect(challengeLoc, lessThan(typeLoc));
    });
  });
}
