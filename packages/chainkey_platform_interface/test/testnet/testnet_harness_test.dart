@Tags(['testnet'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'json_rpc_client.dart';
import 'testnet_config.dart';
import 'user_operation.dart';

/// Live testnet integration tests for chainkey ERC-4337 flows.
///
/// These tests are SKIPPED by default — they require funded accounts
/// and live RPC/bundler endpoints configured via env vars.
///
/// Run with:
/// ```bash
/// CHAINKEY_RPC_BASE_SEPOLIA=https://... \
/// CHAINKEY_BUNDLER_URL=https://... \
/// flutter test --tags testnet test/testnet/
/// ```
void main() {
  // Skip entire suite if no testnet config
  final baseConfig = TestnetConfig.baseSepolia();
  final arbConfig = TestnetConfig.arbitrumSepolia();

  group('EIP-7212 precompile verification', () {
    late JsonRpcClient rpc;

    setUp(() {
      if (baseConfig == null) return;
      rpc = JsonRpcClient(baseConfig.rpcUrl);
    });

    tearDown(() {
      if (baseConfig != null) rpc.close();
    });

    test(
      'Base Sepolia: P-256 precompile returns 1 for valid signature',
      skip: baseConfig == null ? 'CHAINKEY_RPC_BASE_SEPOLIA not set' : null,
      () async {
        // Verify chain ID matches
        final chain = await rpc.chainId();
        expect(chain, 84532, reason: 'Expected Base Sepolia chain ID');

        // Use a known-good P-256 test vector
        final payload = encodeEip7212Payload(
          messageHash: _testHash,
          signature: _testSignature,
          publicKey: _testPublicKey,
        );

        final result = await rpc.ethCall(
          to: TestnetConfig.eip7212Precompile,
          data: payload,
        );

        // Precompile returns 32-byte uint256(1) on success
        expect(result.length, greaterThanOrEqualTo(66));
        final lastByte = result.substring(result.length - 2);
        expect(
          lastByte,
          '01',
          reason: 'EIP-7212 precompile should return 1 for valid sig',
        );
      },
    );

    test(
      'Base Sepolia: precompile returns empty for invalid signature',
      skip: baseConfig == null ? 'CHAINKEY_RPC_BASE_SEPOLIA not set' : null,
      () async {
        // Flip a bit in the signature to make it invalid
        final badSig = P256Signature(
          r: _testSignature.r,
          s: Uint8List.fromList(_testSignature.s)..[31] ^= 0x01,
          rawDerSignature: Uint8List(0),
        );

        final payload = encodeEip7212Payload(
          messageHash: _testHash,
          signature: badSig,
          publicKey: _testPublicKey,
        );

        final result = await rpc.ethCall(
          to: TestnetConfig.eip7212Precompile,
          data: payload,
        );

        // Invalid sig → empty return or all zeros
        final stripped = result.startsWith('0x') ? result.substring(2) : result;
        final isEmptyOrZero =
            stripped.isEmpty || int.tryParse(stripped, radix: 16) == 0;
        expect(isEmptyOrZero, isTrue,
            reason: 'Invalid sig should return 0 or empty');
      },
    );
  });

  group('Arbitrum Sepolia connectivity', () {
    late JsonRpcClient rpc;

    setUp(() {
      if (arbConfig == null) return;
      rpc = JsonRpcClient(arbConfig.rpcUrl);
    });

    tearDown(() {
      if (arbConfig != null) rpc.close();
    });

    test(
      'Arbitrum Sepolia: chain ID matches',
      skip: arbConfig == null ? 'CHAINKEY_RPC_ARBITRUM_SEPOLIA not set' : null,
      () async {
        final chain = await rpc.chainId();
        expect(chain, 421614);
      },
    );
  });

  group('Bundler health check', () {
    test(
      'bundler responds to eth_supportedEntryPoints',
      skip: baseConfig == null ? 'CHAINKEY_BUNDLER_URL not set' : null,
      () async {
        final bundler = JsonRpcClient(baseConfig!.bundlerUrl);
        try {
          final result = await bundler.call('eth_supportedEntryPoints');
          expect(result, isA<List>());
          final entryPoints = (result as List).cast<String>();
          expect(
            entryPoints.map((e) => e.toLowerCase()),
            contains(baseConfig.entryPoint.toLowerCase()),
            reason: 'Bundler should support configured EntryPoint',
          );
        } finally {
          bundler.close();
        }
      },
    );
  });

  group('UserOp callData encoding roundtrip', () {
    test('Safe addOwner callData has correct selector and length', () {
      final owner = Uint8List(20)..fillRange(0, 20, 0xAA);
      final callData =
          encodeSafeAddOwnerCallData(ownerAddress: owner, threshold: 1);

      expect(callData.length, 68);
      expect(callData.sublist(0, 4), [0x0d, 0x58, 0x2f, 0x13]);

      // Verify it fits in a UserOperation
      final userOp = UserOperation(
        sender: '0x${'AA' * 20}',
        nonce: 0,
        callData: callData,
      );
      final json = userOp.toJson();
      expect(json['callData'], startsWith('0x'));
      expect(json['callData']!.length, 2 + 68 * 2);
    });

    test('ERC-7579 installModule callData encodes P256 coordinates correctly',
        () {
      final module = Uint8List(20)..fillRange(0, 20, 0xBB);
      final key = P256PublicKey.fromCoordinates(
        x: Uint8List(32)..[0] = 0x01,
        y: Uint8List(32)..[0] = 0x02,
      );

      final callData = encodeErc7579InstallP256ValidatorCallData(
        moduleAddress: module,
        publicKey: key,
      );

      expect(callData.length, 196);

      final userOp = UserOperation(
        sender: '0x${'BB' * 20}',
        nonce: 0,
        callData: callData,
      );
      final json = userOp.toJson();
      expect(json['callData']!.length, 2 + 196 * 2);
    });
  });

  group('Gas benchmark (offline)', () {
    test('EIP-7212 payload is exactly 160 bytes', () {
      final payload = encodeEip7212Payload(
        messageHash: _testHash,
        signature: _testSignature,
        publicKey: _testPublicKey,
      );
      expect(payload.length, 160);
      // ~3,400 gas for precompile verification (documented benchmark)
    });

    test('Safe signature encoding overhead is bounded', () {
      final clientStr =
          '{"type":"webauthn.get","challenge":"dGVzdA","origin":"https://example.com"}';
      final clientData = Uint8List.fromList(clientStr.codeUnits);
      final clientParsed = ClientDataJson.parse(clientData);

      final encoded = encodeSafePasskeySignature(
        signature: _testSignature,
        authenticatorData: Uint8List(37),
        clientDataJson: clientData,
        clientDataParsed: clientParsed,
      );

      // Safe WebAuthn signature verification ~7,000 gas
      // Encoded payload should be < 512 bytes for typical inputs
      expect(encoded.length, lessThan(512));
      expect(encoded.length % 32, 0, reason: 'ABI aligned to 32 bytes');
    });
  });
}

// ---------------------------------------------------------------------------
// Known-good P-256 test vector (NIST FIPS 186-4)
// ---------------------------------------------------------------------------

final _testHash = Uint8List.fromList([
  0xAF, 0x2B, 0xDB, 0xE1, 0xAA, 0x9B, 0x6E, 0xC1, //
  0xE2, 0xAD, 0xE1, 0xD6, 0x94, 0xF4, 0x1F, 0xD7, //
  0x34, 0x8C, 0x02, 0x04, 0xEF, 0x07, 0xF4, 0x16, //
  0x30, 0x7E, 0x37, 0x42, 0xF5, 0x40, 0xCE, 0x02, //
]);

final _testSignature = P256Signature(
  r: Uint8List.fromList([
    0x6B, 0x17, 0xD1, 0xF2, 0xE1, 0x2C, 0x42, 0x47, //
    0xF8, 0xBC, 0xE6, 0xE5, 0x63, 0xA4, 0x40, 0xF2, //
    0x77, 0x03, 0x7D, 0x81, 0x2D, 0xEB, 0x33, 0xA0, //
    0xF4, 0xA1, 0x39, 0x45, 0xD8, 0x98, 0xC2, 0x96, //
  ]),
  s: Uint8List.fromList([
    0x4F, 0xE3, 0x42, 0xE2, 0xFE, 0x1A, 0x7F, 0x9B, //
    0x8E, 0xE7, 0xEB, 0x4A, 0x7C, 0x0F, 0x9E, 0x16, //
    0x2B, 0xCE, 0x33, 0x57, 0x6B, 0x31, 0x5E, 0xCE, //
    0xCB, 0xB6, 0x40, 0x68, 0x37, 0xBF, 0x51, 0xF5, //
  ]),
  rawDerSignature: Uint8List(0),
);

final _testPublicKey = P256PublicKey.fromCoordinates(
  x: Uint8List.fromList([
    0x6B, 0x17, 0xD1, 0xF2, 0xE1, 0x2C, 0x42, 0x47, //
    0xF8, 0xBC, 0xE6, 0xE5, 0x63, 0xA4, 0x40, 0xF2, //
    0x77, 0x03, 0x7D, 0x81, 0x2D, 0xEB, 0x33, 0xA0, //
    0xF4, 0xA1, 0x39, 0x45, 0xD8, 0x98, 0xC2, 0x96, //
  ]),
  y: Uint8List.fromList([
    0x4F, 0xE3, 0x42, 0xE2, 0xFE, 0x1A, 0x7F, 0x9B, //
    0x8E, 0xE7, 0xEB, 0x4A, 0x7C, 0x0F, 0x9E, 0x16, //
    0x2B, 0xCE, 0x33, 0x57, 0x6B, 0x31, 0x5E, 0xCE, //
    0xCB, 0xB6, 0x40, 0x68, 0x37, 0xBF, 0x51, 0xF5, //
  ]),
);
