import 'dart:io';

/// Environment-driven testnet configuration.
///
/// Set these env vars to run live testnet tests:
/// - CHAINKEY_RPC_BASE_SEPOLIA: Base Sepolia RPC URL
/// - CHAINKEY_RPC_ARBITRUM_SEPOLIA: Arbitrum Sepolia RPC URL
/// - CHAINKEY_BUNDLER_URL: ERC-4337 bundler endpoint (Pimlico/ZeroDev/Biconomy)
/// - CHAINKEY_PAYMASTER_URL: (optional) paymaster endpoint for sponsored gas
/// - CHAINKEY_ENTRY_POINT: EntryPoint v0.7 address (default: 0x0000000071727De22E5E9d8BAf0edAc6f37da032)
/// - CHAINKEY_SAFE_MODULE: Safe WebAuthn module address on testnet
/// - CHAINKEY_KERNEL_VALIDATOR: ZeroDev Kernel P256 validator address on testnet
class TestnetConfig {
  TestnetConfig._({
    required this.network,
    required this.rpcUrl,
    required this.bundlerUrl,
    this.paymasterUrl,
    required this.entryPoint,
    this.safeModuleAddress,
    this.kernelValidatorAddress,
    required this.chainId,
  });

  final String network;
  final String rpcUrl;
  final String bundlerUrl;
  final String? paymasterUrl;
  final String entryPoint;
  final String? safeModuleAddress;
  final String? kernelValidatorAddress;
  final int chainId;

  static const _defaultEntryPoint =
      '0x0000000071727De22E5E9d8BAf0edAc6f37da032';

  // ponytail: EIP-7212 precompile address is universal
  static const eip7212Precompile = '0x0000000000000000000000000000000000000100';

  static TestnetConfig? baseSepolia() {
    final rpc = Platform.environment['CHAINKEY_RPC_BASE_SEPOLIA'];
    final bundler = Platform.environment['CHAINKEY_BUNDLER_URL'];
    if (rpc == null || bundler == null) return null;
    return TestnetConfig._(
      network: 'Base Sepolia',
      rpcUrl: rpc,
      bundlerUrl: bundler,
      paymasterUrl: Platform.environment['CHAINKEY_PAYMASTER_URL'],
      entryPoint:
          Platform.environment['CHAINKEY_ENTRY_POINT'] ?? _defaultEntryPoint,
      safeModuleAddress: Platform.environment['CHAINKEY_SAFE_MODULE'],
      kernelValidatorAddress: Platform.environment['CHAINKEY_KERNEL_VALIDATOR'],
      chainId: 84532,
    );
  }

  static TestnetConfig? arbitrumSepolia() {
    final rpc = Platform.environment['CHAINKEY_RPC_ARBITRUM_SEPOLIA'];
    final bundler = Platform.environment['CHAINKEY_BUNDLER_URL'];
    if (rpc == null || bundler == null) return null;
    return TestnetConfig._(
      network: 'Arbitrum Sepolia',
      rpcUrl: rpc,
      bundlerUrl: bundler,
      paymasterUrl: Platform.environment['CHAINKEY_PAYMASTER_URL'],
      entryPoint:
          Platform.environment['CHAINKEY_ENTRY_POINT'] ?? _defaultEntryPoint,
      safeModuleAddress: Platform.environment['CHAINKEY_SAFE_MODULE'],
      kernelValidatorAddress: Platform.environment['CHAINKEY_KERNEL_VALIDATOR'],
      chainId: 421614,
    );
  }

  /// True if all required env vars are set for at least one network.
  static bool get isConfigured =>
      baseSepolia() != null || arbitrumSepolia() != null;

  @override
  String toString() => 'TestnetConfig($network, chainId: $chainId)';
}
