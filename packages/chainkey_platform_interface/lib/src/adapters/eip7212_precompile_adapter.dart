import 'dart:typed_data';

import '../models/p256_public_key.dart';
import '../models/p256_signature.dart';

/// The EIP-7212 secp256r1 signature verification precompile address.
const String eip7212PrecompileAddress =
    '0x0000000000000000000000000000000000000100';

/// Encodes a 160-byte payload for the EIP-7212 P-256 precompile (0x100).
///
/// Layout: `abi.encode(bytes32 hash, uint256 r, uint256 s, uint256 x, uint256 y)`
///
/// The precompile returns `0x00...01` on valid signature, empty on invalid.
Uint8List encodeEip7212Payload({
  required Uint8List messageHash,
  required P256Signature signature,
  required P256PublicKey publicKey,
}) {
  if (messageHash.length != 32) {
    throw ArgumentError.value(
        messageHash.length, 'messageHash', 'must be exactly 32 bytes');
  }
  final buf = Uint8List(160);
  buf.setRange(0, 32, messageHash);
  buf.setRange(32, 64, signature.r);
  buf.setRange(64, 96, signature.s);
  buf.setRange(96, 128, publicKey.x);
  buf.setRange(128, 160, publicKey.y);
  return buf;
}
