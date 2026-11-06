import '../exceptions/chainkey_exceptions.dart';

/// Emitted when a hardware key is permanently invalidated by OS-level
/// security changes (e.g. new biometric enrollment on Android).
class KeyInvalidationEvent {
  const KeyInvalidationEvent({
    required this.keyAlias,
    required this.exception,
  });

  /// The alias of the invalidated hardware key.
  final String keyAlias;

  /// The original platform exception that surfaced the invalidation.
  final KeyPermanentlyInvalidatedException exception;

  @override
  String toString() => 'KeyInvalidationEvent($keyAlias)';
}
