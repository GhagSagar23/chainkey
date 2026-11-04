import 'dart:typed_data';

import '../models/client_data_json.dart';
import '../models/p256_signature.dart';

/// ABI-encodes a WebAuthn assertion for Safe's 4337 WebAuthn Signer module.
///
/// Output layout matches:
/// ```solidity
/// abi.encode(
///   uint256 r, uint256 s,
///   bytes authenticatorData, bytes clientDataJSON,
///   uint256 challengeLocation, uint256 responseTypeLocation
/// )
/// ```
Uint8List encodeSafePasskeySignature({
  required P256Signature signature,
  required Uint8List authenticatorData,
  required Uint8List clientDataJson,
  required ClientDataJson clientDataParsed,
}) {
  final r = signature.r;
  final s = signature.s;
  final challengeLocation = clientDataParsed.challengeOffset;
  final responseTypeLocation = clientDataParsed.typeOffset;

  // Head: 6 × 32 = 192 bytes
  const headSize = 6 * 32;
  final authPadded = _padTo32(authenticatorData.length);
  final clientPadded = _padTo32(clientDataJson.length);

  // Dynamic offsets (from byte 0 of the encoding)
  final authDataOffset = headSize;
  final clientDataOffset = headSize + 32 + authPadded;

  final totalLen = clientDataOffset + 32 + clientPadded;
  final buf = Uint8List(totalLen);

  // r, s — already 32-byte big-endian
  buf.setRange(0, 32, r);
  buf.setRange(32, 64, s);

  // Offsets to dynamic data
  _writeUint256(buf, 64, authDataOffset);
  _writeUint256(buf, 96, clientDataOffset);

  // challengeLocation, responseTypeLocation
  _writeUint256(buf, 128, challengeLocation);
  _writeUint256(buf, 160, responseTypeLocation);

  // authenticatorData: length + padded bytes
  _writeUint256(buf, authDataOffset, authenticatorData.length);
  buf.setRange(authDataOffset + 32, authDataOffset + 32 + authenticatorData.length, authenticatorData);

  // clientDataJSON: length + padded bytes
  _writeUint256(buf, clientDataOffset, clientDataJson.length);
  buf.setRange(clientDataOffset + 32, clientDataOffset + 32 + clientDataJson.length, clientDataJson);

  return buf;
}

int _padTo32(int len) => ((len + 31) ~/ 32) * 32;

void _writeUint256(Uint8List buf, int offset, int value) {
  // Write as big-endian in the last 8 bytes of a 32-byte slot.
  // Values here are always < 2^53 so int is fine.
  for (var i = 31; i >= 24; i--) {
    buf[offset + i] = value & 0xFF;
    value >>= 8;
  }
}
