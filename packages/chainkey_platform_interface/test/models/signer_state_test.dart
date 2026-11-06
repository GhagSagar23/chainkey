import 'dart:typed_data';

import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

SignerEntry _entry(String id, {SignerStatus status = SignerStatus.active}) {
  final x = Uint8List(32)..[0] = id.codeUnitAt(0);
  final y = Uint8List(32)..[0] = id.codeUnitAt(0) + 1;
  return SignerEntry(
    credentialId: id,
    publicKey: P256PublicKey.fromCoordinates(x: x, y: y),
    status: status,
    addedAt: DateTime(2025, 1, 1),
    label: 'device-$id',
  );
}

void main() {
  group('MultiSignerState', () {
    test('empty state has no signers', () {
      const state = MultiSignerState.empty();
      expect(state.signers, isEmpty);
      expect(state.active, isEmpty);
    });

    test('addSigner appends entry', () {
      const state = MultiSignerState.empty();
      final updated = state.addSigner(_entry('a'));
      expect(updated.signers.length, 1);
      expect(updated.signers.first.credentialId, 'a');
    });

    test('active filters by status', () {
      final state = MultiSignerState([
        _entry('a'),
        _entry('b', status: SignerStatus.revoked),
        _entry('c', status: SignerStatus.pendingAddition),
      ]);
      expect(state.active.length, 1);
      expect(state.active.first.credentialId, 'a');
    });

    test('byCredentialId finds existing entry', () {
      final state = MultiSignerState([_entry('a'), _entry('b')]);
      expect(state.byCredentialId('b')?.credentialId, 'b');
      expect(state.byCredentialId('z'), isNull);
    });

    test('isRegistered checks presence', () {
      final state = MultiSignerState([_entry('a')]);
      expect(state.isRegistered('a'), isTrue);
      expect(state.isRegistered('b'), isFalse);
    });

    test('updateStatus transitions a signer', () {
      final state = MultiSignerState([_entry('a'), _entry('b')]);
      final updated =
          state.updateStatus('a', SignerStatus.pendingRevocation);
      expect(
        updated.byCredentialId('a')?.status,
        SignerStatus.pendingRevocation,
      );
      expect(updated.byCredentialId('b')?.status, SignerStatus.active);
    });

    test('immutability — original state unchanged after addSigner', () {
      const state = MultiSignerState.empty();
      state.addSigner(_entry('a'));
      expect(state.signers, isEmpty);
    });
  });

  group('SignerEntry', () {
    test('equality based on credentialId + publicKey + status', () {
      final a = _entry('a');
      final b = _entry('a');
      expect(a, equals(b));
    });

    test('copyWith preserves fields', () {
      final entry = _entry('a');
      final copy = entry.copyWith(status: SignerStatus.revoked);
      expect(copy.credentialId, 'a');
      expect(copy.status, SignerStatus.revoked);
      expect(copy.label, 'device-a');
    });
  });
}
