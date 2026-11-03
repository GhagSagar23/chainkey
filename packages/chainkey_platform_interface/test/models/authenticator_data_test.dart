import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal 37-byte authenticatorData with given flags and signCount.
Uint8List _buildAuthData({
  Uint8List? rpIdHash,
  int flags = 0x05, // UP + UV
  int signCount = 0,
  Uint8List? suffix,
}) {
  final hash = rpIdHash ?? Uint8List(32);
  final buf = BytesBuilder();
  buf.add(hash);
  buf.addByte(flags);
  buf.addByte((signCount >> 24) & 0xFF);
  buf.addByte((signCount >> 16) & 0xFF);
  buf.addByte((signCount >> 8) & 0xFF);
  buf.addByte(signCount & 0xFF);
  if (suffix != null) buf.add(suffix);
  return buf.toBytes();
}

void main() {
  group('AuthenticatorData.parse', () {
    test('parses minimal 37-byte buffer with UP+UV flags', () {
      final data = _buildAuthData(flags: 0x05, signCount: 42);
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.rpIdHash.length, 32);
      expect(parsed.userPresent, isTrue);
      expect(parsed.userVerified, isTrue);
      expect(parsed.backupEligible, isFalse);
      expect(parsed.backedUp, isFalse);
      expect(parsed.hasAttestedCredentialData, isFalse);
      expect(parsed.hasExtensionData, isFalse);
      expect(parsed.signCount, 42);
    });

    test('parses UP-only flag (no UV)', () {
      final data = _buildAuthData(flags: 0x01);
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.userPresent, isTrue);
      expect(parsed.userVerified, isFalse);
    });

    test('parses all flags set', () {
      // UP=1, UV=4, BE=8, BS=16, AT=64, ED=128 → 0xDD
      final data = _buildAuthData(flags: 0xDD);
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.userPresent, isTrue);
      expect(parsed.userVerified, isTrue);
      expect(parsed.backupEligible, isTrue);
      expect(parsed.backedUp, isTrue);
      expect(parsed.hasAttestedCredentialData, isTrue);
      expect(parsed.hasExtensionData, isTrue);
    });

    test('parses zero flags', () {
      final data = _buildAuthData(flags: 0x00);
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.userPresent, isFalse);
      expect(parsed.userVerified, isFalse);
      expect(parsed.backupEligible, isFalse);
      expect(parsed.backedUp, isFalse);
      expect(parsed.hasAttestedCredentialData, isFalse);
      expect(parsed.hasExtensionData, isFalse);
    });

    test('parses big-endian signCount correctly', () {
      // 0x00_01_00_00 = 65536
      final data = _buildAuthData(signCount: 65536);
      expect(AuthenticatorData.parse(data).signCount, 65536);

      // max uint32
      final maxData = _buildAuthData(signCount: 0xFFFFFFFF);
      expect(AuthenticatorData.parse(maxData).signCount, 0xFFFFFFFF);

      // zero
      final zeroData = _buildAuthData(signCount: 0);
      expect(AuthenticatorData.parse(zeroData).signCount, 0);
    });

    test('preserves rpIdHash bytes', () {
      final hash = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        hash[i] = i;
      }
      final data = _buildAuthData(rpIdHash: hash);
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.rpIdHash, hash);
    });

    test('preserves raw bytes', () {
      final data = _buildAuthData(
        flags: 0x05,
        signCount: 1,
        suffix: Uint8List.fromList([0xCA, 0xFE]),
      );
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.raw.length, 39);
      expect(parsed.raw, data);
    });

    test('accepts data longer than 37 bytes (extensions/attested cred)', () {
      final data = _buildAuthData(
        flags: 0xC5, // UP + UV + AT + ED
        suffix: Uint8List(100),
      );
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.hasAttestedCredentialData, isTrue);
      expect(parsed.hasExtensionData, isTrue);
      expect(parsed.raw.length, 137);
    });

    test('throws FormatException for data shorter than 37 bytes', () {
      expect(
        () => AuthenticatorData.parse(Uint8List(36)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('at least 37 bytes'),
          ),
        ),
      );
    });

    test('throws FormatException for empty data', () {
      expect(
        () => AuthenticatorData.parse(Uint8List(0)),
        throwsFormatException,
      );
    });

    test('backup flags: eligible but not backed up', () {
      // BE=8 set, BS=16 not set → 0x09 (UP + BE)
      final data = _buildAuthData(flags: 0x09);
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.backupEligible, isTrue);
      expect(parsed.backedUp, isFalse);
    });

    test('backup flags: eligible and backed up', () {
      // BE=8, BS=16 → 0x19 (UP + BE + BS)
      final data = _buildAuthData(flags: 0x19);
      final parsed = AuthenticatorData.parse(data);

      expect(parsed.backupEligible, isTrue);
      expect(parsed.backedUp, isTrue);
    });
  });
}
