import 'package:flutter/services.dart';

/// Base exception for all chainkey operations.
abstract class ChainkeyException implements Exception {
  const ChainkeyException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final dynamic details;

  @override
  String toString() => '$runtimeType($code): $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChainkeyException &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code &&
          details == other.details;

  @override
  int get hashCode => Object.hash(runtimeType, message, code, details);

  /// Deterministically maps a [PlatformException] or generic exception to a strongly-typed [ChainkeyException].
  static ChainkeyException fromPlatformException(PlatformException exception) {
    final code = exception.code.toUpperCase();
    final message = exception.message ?? 'Unknown platform exception occurred';
    final details = exception.details;

    switch (code) {
      case 'USER_CANCELLED':
      case 'CANCELLED':
      case 'USER_CANCELED':
      case 'CANCELED':
      case 'AUTH_CANCELLED':
      case 'AUTH_CANCELED':
      case 'LAERRORUSERCANCEL':
      case 'LAERRORAPPCANCEL':
      case 'LAERRORSYSTEMCANCEL':
      case 'ERROR_USER_CANCELED':
        return UserCancelledException.withDetails(
          message,
          code: exception.code,
          details: details,
        );

      case 'KEY_PERMANENTLY_INVALIDATED':
      case 'KEY_INVALIDATED':
      case 'KEYPERMANENTLYINVALIDATEDEXCEPTION':
      case 'KEY_PERMANENTLY_INVALIDATED_EXCEPTION':
        return KeyPermanentlyInvalidatedException.withDetails(
          message,
          code: exception.code,
          details: details,
        );

      case 'BIOMETRICS_UNAVAILABLE':
      case 'BIOMETRIC_UNAVAILABLE':
      case 'NO_BIOMETRICS':
      case 'BIOMETRICS_NOT_ENROLLED':
      case 'NOT_ENROLLED':
      case 'LAERRORBIOMETRYNOTAVAILABLE':
      case 'LAERRORBIOMETRYNOTENROLLED':
      case 'LAERRORPASSCODENOTSET':
      case 'BIOMETRIC_ERROR_HW_UNAVAILABLE':
      case 'BIOMETRIC_ERROR_NO_BIOMETRICS':
      case 'BIOMETRIC_ERROR_HW_NOT_PRESENT':
        return BiometricsUnavailableException.withDetails(
          message,
          code: exception.code,
          details: details,
        );

      case 'PASSKEY_ERROR':
      case 'PASSKEY_EXCEPTION':
      case 'ORIGIN_MISMATCH':
      case 'UNSUPPORTED_ALGORITHM':
      case 'TIMEOUT':
      case 'WEBAUTHN_ERROR':
      case 'CREATE_CREDENTIAL_ERROR':
      case 'GET_CREDENTIAL_ERROR':
      case 'CREDENTIAL_EXCEPTION':
      case 'DOM_EXCEPTION':
        return PasskeyException(
          message,
          code: exception.code,
          details: details,
        );

      case 'HARDWARE_ENCLAVE_ERROR':
      case 'HARDWARE_ENCLAVE_EXCEPTION':
      case 'KEY_GENERATION_FAILED':
      case 'KEY_NOT_FOUND':
      case 'UNSUPPORTED_CURVE':
      case 'SECURE_ENCLAVE_ERROR':
      case 'STRONGBOX_ERROR':
      case 'KEYSTORE_ERROR':
        return HardwareEnclaveException(
          message,
          code: exception.code,
          details: details,
        );

      default:
        // Inspection of message or details if code is generic (e.g. channel-error or FlutterError)
        final lowerMsg = message.toLowerCase();
        if (lowerMsg.contains('user cancel') ||
            lowerMsg.contains('user dismissed') ||
            lowerMsg.contains('user_cancelled')) {
          return UserCancelledException.withDetails(
            message,
            code: exception.code,
            details: details,
          );
        }
        if (lowerMsg.contains('permanently invalidated') ||
            lowerMsg.contains('keypermanentlyinvalidated')) {
          return KeyPermanentlyInvalidatedException.withDetails(
            message,
            code: exception.code,
            details: details,
          );
        }
        if (lowerMsg.contains('biometric') &&
            (lowerMsg.contains('unavailable') ||
                lowerMsg.contains('not enrolled') ||
                lowerMsg.contains('not available'))) {
          return BiometricsUnavailableException.withDetails(
            message,
            code: exception.code,
            details: details,
          );
        }
        if (lowerMsg.contains('passkey') ||
            lowerMsg.contains('webauthn') ||
            lowerMsg.contains('origin mismatch')) {
          return PasskeyException(
            message,
            code: exception.code,
            details: details,
          );
        }
        return HardwareEnclaveException(
          message,
          code: exception.code,
          details: details,
        );
    }
  }

  /// Maps any caught error or exception to a [ChainkeyException].
  static ChainkeyException from(Object error) {
    if (error is ChainkeyException) {
      return error;
    }
    if (error is PlatformException) {
      return fromPlatformException(error);
    }
    return HardwareEnclaveException(error.toString());
  }
}

/// Thrown when the user cancels or dismisses a biometric or passkey authentication prompt.
class UserCancelledException extends ChainkeyException {
  const UserCancelledException([
    super.message = 'User cancelled authentication prompt',
  ]) : super(code: 'USER_CANCELLED');

  const UserCancelledException.withDetails(
    super.message, {
    super.code = 'USER_CANCELLED',
    super.details,
  });
}

/// Thrown when a key has been invalidated (e.g. by new biometric enrollment on Android KeyStore).
class KeyPermanentlyInvalidatedException extends ChainkeyException {
  const KeyPermanentlyInvalidatedException([
    super.message =
        'Hardware key was permanently invalidated by system security changes',
  ]) : super(code: 'KEY_PERMANENTLY_INVALIDATED');

  const KeyPermanentlyInvalidatedException.withDetails(
    super.message, {
    super.code = 'KEY_PERMANENTLY_INVALIDATED',
    super.details,
  });
}

/// Thrown when biometric authentication hardware is unavailable, no biometrics are enrolled, or passcode is not set.
class BiometricsUnavailableException extends ChainkeyException {
  const BiometricsUnavailableException([
    super.message =
        'Biometrics are unavailable or no biometric identities are enrolled',
  ]) : super(code: 'BIOMETRICS_UNAVAILABLE');

  const BiometricsUnavailableException.withDetails(
    super.message, {
    super.code = 'BIOMETRICS_UNAVAILABLE',
    super.details,
  });
}

/// Thrown when an underlying hardware enclave operation fails (e.g. keygen, signing, curve support, KeyStore error).
class HardwareEnclaveException extends ChainkeyException {
  const HardwareEnclaveException(
    super.message, {
    super.code = 'HARDWARE_ENCLAVE_ERROR',
    super.details,
  });
}

/// Thrown when WebAuthn passkey assertion or registration fails (e.g. origin mismatch, timeout, unsupported algorithm).
class PasskeyException extends ChainkeyException {
  const PasskeyException(
    super.message, {
    super.code = 'PASSKEY_ERROR',
    super.details,
  });
}
