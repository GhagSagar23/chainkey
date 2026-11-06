import 'dart:convert';

import 'package:chainkey/chainkey.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ChainkeyExampleApp());
}

// ---------------------------------------------------------------------------
// App shell
// ---------------------------------------------------------------------------

class ChainkeyExampleApp extends StatelessWidget {
  const ChainkeyExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'chainkey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  static const _chainkey = Chainkey();
  static const _keyAlias = 'dev.chainkey.demo_wallet';

  P256PublicKey? _walletKey;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _tryLoadExistingKey();
  }

  Future<void> _tryLoadExistingKey() async {
    // Attempt a no-op sign to detect if key exists.
    // If it throws HardwareEnclaveException with KEY_NOT_FOUND, no key.
    // Any other outcome means a key exists.
    try {
      await _chainkey.signWithHardwareKey(
        keyAlias: _keyAlias,
        hash32: Uint8List(32),
      );
      // Signing succeeded — key exists (shouldn't normally happen
      // without biometric, but some configs allow it)
    } on ChainkeyException {
      // Key doesn't exist or can't sign — go to onboarding
    } catch (_) {
      // Any other error — go to onboarding
    }
    if (mounted) setState(() => _booting = false);
  }

  void _onWalletCreated(P256PublicKey key) {
    setState(() => _walletKey = key);
  }

  void _onWalletDeleted() {
    setState(() => _walletKey = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_walletKey == null) {
      return _OnboardingScreen(
        chainkey: _chainkey,
        keyAlias: _keyAlias,
        onCreated: _onWalletCreated,
      );
    }
    return _WalletHome(
      chainkey: _chainkey,
      keyAlias: _keyAlias,
      publicKey: _walletKey!,
      onDeleted: _onWalletDeleted,
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding — one-tap wallet creation
// ---------------------------------------------------------------------------

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({
    required this.chainkey,
    required this.keyAlias,
    required this.onCreated,
  });

  final Chainkey chainkey;
  final String keyAlias;
  final ValueChanged<P256PublicKey> onCreated;

  @override
  State<_OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<_OnboardingScreen> {
  bool _creating = false;
  String? _error;

  Future<void> _createWallet() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final key = await widget.chainkey.generateHardwareKey(
        keyAlias: widget.keyAlias,
      );
      widget.onCreated(key);
    } on ChainkeyException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 80, color: cs.primary),
              const SizedBox(height: 24),
              Text(
                'chainkey',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Seedless smart account wallet.\n'
                'Your private key never leaves the hardware enclave.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _creating ? null : _createWallet,
                  icon: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(_creating ? 'Creating...' : 'Create Wallet'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wallet home — tabs: Dashboard, Transfer, Settings
// ---------------------------------------------------------------------------

class _WalletHome extends StatefulWidget {
  const _WalletHome({
    required this.chainkey,
    required this.keyAlias,
    required this.publicKey,
    required this.onDeleted,
  });

  final Chainkey chainkey;
  final String keyAlias;
  final P256PublicKey publicKey;
  final VoidCallback onDeleted;

  @override
  State<_WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<_WalletHome> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _DashboardTab(publicKey: widget.publicKey),
          _TransferTab(
            chainkey: widget.chainkey,
            keyAlias: widget.keyAlias,
            publicKey: widget.publicKey,
          ),
          _SettingsTab(
            chainkey: widget.chainkey,
            keyAlias: widget.keyAlias,
            publicKey: widget.publicKey,
            onDeleted: widget.onDeleted,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send),
            label: 'Transfer',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard tab
// ---------------------------------------------------------------------------

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.publicKey});

  final P256PublicKey publicKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shortId = publicKey.uncompressedHex.substring(2, 10).toUpperCase();
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Wallet'),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              _InfoCard(
                title: 'Account',
                icon: Icons.shield,
                children: [
                  _InfoRow('Identifier', '0x$shortId…'),
                  _InfoRow(
                    'Isolation',
                    publicKey.isolationLevel.name.toUpperCase(),
                  ),
                  _InfoRow('Curve', 'NIST P-256 (secp256r1)'),
                  _InfoRow('Key Size', '256-bit'),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Public Key (SEC1 Uncompressed)',
                icon: Icons.key,
                children: [
                  _CopyableHex(publicKey.uncompressedHex),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Coordinates',
                icon: Icons.grid_on,
                children: [
                  _CopyableHex(
                    _toHex(publicKey.x),
                    label: 'X',
                  ),
                  const SizedBox(height: 8),
                  _CopyableHex(
                    _toHex(publicKey.y),
                    label: 'Y',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                color: cs.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.onTertiaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Smart account address is determined by the '
                          'factory contract + salt + this public key. '
                          'Use encodeSafeAddOwnerCallData or '
                          'encodeErc7579InstallP256ValidatorCallData '
                          'to register this key on-chain.',
                          style: TextStyle(
                            color: cs.onTertiaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transfer tab — mock USDC transfer with biometric signing
// ---------------------------------------------------------------------------

class _TransferTab extends StatefulWidget {
  const _TransferTab({
    required this.chainkey,
    required this.keyAlias,
    required this.publicKey,
  });

  final Chainkey chainkey;
  final String keyAlias;
  final P256PublicKey publicKey;

  @override
  State<_TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends State<_TransferTab> {
  final _recipientController = TextEditingController(
    text: '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18',
  );
  final _amountController = TextEditingController(text: '1.00');

  bool _signing = false;
  String? _signedUserOpHex;
  String? _error;

  // ERC-20 transfer(address,uint256) selector
  static const _transferSelector = [0xa9, 0x05, 0x9c, 0xbb];

  // ponytail: Base Sepolia USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e

  Future<void> _signTransfer() async {
    setState(() {
      _signing = true;
      _signedUserOpHex = null;
      _error = null;
    });

    try {
      // Build ERC-20 transfer callData
      final recipientHex = _recipientController.text.replaceFirst('0x', '');
      final amount = (double.parse(_amountController.text) * 1e6).toInt();
      final callData = _encodeErc20Transfer(recipientHex, amount);

      // Hash the callData (in production this would be the UserOpHash
      // from the EntryPoint, but we demo with a simple hash)
      final hash32 = _simpleHash(callData);

      // Sign with hardware enclave + biometric
      final signature = await widget.chainkey.signWithHardwareKey(
        keyAlias: widget.keyAlias,
        hash32: hash32,
        promptOptions: const BiometricPromptOptions(
          title: 'Confirm USDC Transfer',
          subtitle: 'Sign ERC-4337 UserOperation',
        ),
      );

      // Build the EIP-7212 precompile verification payload
      final verifyPayload = encodeEip7212Payload(
        messageHash: hash32,
        signature: signature,
        publicKey: widget.publicKey,
      );

      setState(() {
        _signedUserOpHex = '--- Signed UserOp ---\n'
            'callData: 0x${_hexEncode(callData)}\n\n'
            'signature (r||s): 0x${signature.compactHex}\n\n'
            'EIP-7212 verify payload (160B): 0x${_hexEncode(verifyPayload)}\n\n'
            'Low-S: ${signature.isLowS ? "yes" : "NEEDS NORMALIZATION"}';
      });
    } on UserCancelledException {
      setState(() => _error = 'Cancelled by user');
    } on ChainkeyException catch (e) {
      setState(() => _error = e.message);
    } on FormatException catch (e) {
      setState(() => _error = 'Invalid input: $e');
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  Uint8List _encodeErc20Transfer(String recipientHex, int amount) {
    // transfer(address recipient, uint256 amount)
    // selector(4) + address(32) + uint256(32) = 68 bytes
    final buf = Uint8List(68);
    buf.setAll(0, _transferSelector);
    // address: right-aligned in 32-byte slot
    final addrBytes = _hexDecode(recipientHex);
    buf.setRange(4 + 12, 4 + 32, addrBytes);
    // amount: USDC has 6 decimals
    _writeUint256(buf, 36, amount);
    return buf;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(title: const Text('Transfer')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '\$',
                                style: TextStyle(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'USDC (Base Sepolia)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _recipientController,
                        decoration: const InputDecoration(
                          labelText: 'Recipient Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (USDC)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _signing ? null : _signTransfer,
                          icon: _signing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.fingerprint),
                          label: Text(
                            _signing ? 'Signing...' : 'Sign & Send',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: cs.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ),
              ],
              if (_signedUserOpHex != null) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Signed Transaction',
                  icon: Icons.check_circle,
                  children: [
                    SelectableText(
                      _signedUserOpHex!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Settings tab — key management, recovery info
// ---------------------------------------------------------------------------

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.chainkey,
    required this.keyAlias,
    required this.publicKey,
    required this.onDeleted,
  });

  final Chainkey chainkey;
  final String keyAlias;
  final P256PublicKey publicKey;
  final VoidCallback onDeleted;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  String? _recoveryData;

  void _showRecoveryInfo() {
    // In production: encode public key + credentialId into a QR code
    // for a secondary device to scan and register as co-signer.
    final data = jsonEncode({
      'publicKey': widget.publicKey.uncompressedHex,
      'keyAlias': widget.keyAlias,
      'isolationLevel': widget.publicKey.isolationLevel.name,
    });
    setState(() => _recoveryData = data);
  }

  Future<void> _deleteWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: const Text(
          'This will permanently delete the hardware key. '
          'Make sure you have a backup signer registered on-chain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.chainkey.deleteHardwareKey(keyAlias: widget.keyAlias);
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(title: const Text('Settings')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              _InfoCard(
                title: 'Key Recovery',
                icon: Icons.qr_code,
                children: [
                  Text(
                    'Link a secondary device by sharing your public key. '
                    'The new device registers as a co-signer on your '
                    'smart account using the UserOp helpers.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // ponytail: real QR needs qr_flutter dep, show JSON instead
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showRecoveryInfo,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Show Recovery Data'),
                    ),
                  ),
                  if (_recoveryData != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _recoveryData!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Multi-Signer State',
                icon: Icons.devices,
                children: [
                  Text(
                    'Track registered devices with MultiSignerState. '
                    'Active signers can authorize UserOperations; '
                    'revoked signers are removed on-chain.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    'This device',
                    widget.publicKey.isolationLevel.name,
                  ),
                  _InfoRow('Status', 'Active'),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danger Zone',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: cs.onErrorContainer),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _deleteWallet,
                          icon: Icon(Icons.delete_forever, color: cs.error),
                          label: Text(
                            'Delete Hardware Key',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CopyableHex extends StatelessWidget {
  const _CopyableHex(this.hex, {this.label});

  final String hex;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Clipboard.setData(ClipboardData(text: hex));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${label ?? "Hex"} copied'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hex,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
                Icon(Icons.copy, size: 14, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _toHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _hexEncode(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _hexDecode(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

void _writeUint256(Uint8List buf, int offset, int value) {
  for (var i = 31; i >= 24; i--) {
    buf[offset + i] = value & 0xFF;
    value >>= 8;
  }
}

Uint8List _simpleHash(Uint8List data) {
  // ponytail: proper keccak256 needs a dep; use a deterministic
  // fold for demo purposes — swap for real hash in production
  final hash = Uint8List(32);
  for (var i = 0; i < data.length; i++) {
    hash[i % 32] ^= data[i];
    hash[(i + 7) % 32] = (hash[(i + 7) % 32] + data[i]) & 0xFF;
  }
  return hash;
}
