/// Base exception for all chainkey operations.
abstract class ChainkeyException implements Exception {
  const ChainkeyException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final dynamic details;

  @override
  String toString() => 'ChainkeyException($code): $message';
}

/// Thrown when the user cancels a biometric or passkey authentication prompt.
class UserCancelledException extends ChainkeyException {
  const UserCancelledException([
    super.message = 'User cancelled authentication prompt',
  ]) : super(code: 'USER_CANCELLED');
}

/// Thrown when a key has been invalidated (e.g. by new biometric enrollment on older OSes).
class KeyPermanentlyInvalidatedException extends ChainkeyException {
  const KeyPermanentlyInvalidatedException([
    super.message =
        'Hardware key was permanently invalidated by system security changes',
  ]) : super(code: 'KEY_PERMANENTLY_INVALIDATED');
}

/// Thrown when an underlying hardware enclave operation fails.
class HardwareEnclaveException extends ChainkeyException {
  const HardwareEnclaveException(
    super.message, {
    String? code,
    super.details,
  }) : super(code: code ?? 'HARDWARE_ENCLAVE_ERROR');
}

/// Thrown when WebAuthn passkey assertion or registration fails.
class PasskeyException extends ChainkeyException {
  const PasskeyException(
    super.message, {
    String? code,
    super.details,
  }) : super(code: code ?? 'PASSKEY_ERROR');
}
