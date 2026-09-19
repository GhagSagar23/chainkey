import 'package:chainkey_platform_interface/chainkey_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChainkeyException hierarchy', () {
    test('UserCancelledException properties and defaults', () {
      const ex1 = UserCancelledException();
      expect(ex1.message, equals('User cancelled authentication prompt'));
      expect(ex1.code, equals('USER_CANCELLED'));
      expect(ex1.details, isNull);
      expect(
          ex1.toString(), contains('UserCancelledException(USER_CANCELLED)'));

      const ex2 = UserCancelledException.withDetails(
        'User tapped cancel button',
        code: 'LAErrorUserCancel',
        details: {'key': 'val'},
      );
      expect(ex2.message, equals('User tapped cancel button'));
      expect(ex2.code, equals('LAErrorUserCancel'));
      expect(ex2.details, equals({'key': 'val'}));
      expect(ex2, isA<ChainkeyException>());
    });

    test('KeyPermanentlyInvalidatedException properties and defaults', () {
      const ex1 = KeyPermanentlyInvalidatedException();
      expect(
        ex1.message,
        equals(
            'Hardware key was permanently invalidated by system security changes'),
      );
      expect(ex1.code, equals('KEY_PERMANENTLY_INVALIDATED'));
      expect(ex1.details, isNull);
      expect(
        ex1.toString(),
        contains(
            'KeyPermanentlyInvalidatedException(KEY_PERMANENTLY_INVALIDATED)'),
      );

      const ex2 = KeyPermanentlyInvalidatedException.withDetails(
        'Key invalidated',
        code: 'KeyPermanentlyInvalidatedException',
        details: 'Biometric enrolled',
      );
      expect(ex2.message, equals('Key invalidated'));
      expect(ex2.code, equals('KeyPermanentlyInvalidatedException'));
      expect(ex2.details, equals('Biometric enrolled'));
      expect(ex2, isA<ChainkeyException>());
    });

    test('BiometricsUnavailableException properties and defaults', () {
      const ex1 = BiometricsUnavailableException();
      expect(
        ex1.message,
        equals(
            'Biometrics are unavailable or no biometric identities are enrolled'),
      );
      expect(ex1.code, equals('BIOMETRICS_UNAVAILABLE'));
      expect(ex1.details, isNull);
      expect(
        ex1.toString(),
        contains('BiometricsUnavailableException(BIOMETRICS_UNAVAILABLE)'),
      );

      const ex2 = BiometricsUnavailableException.withDetails(
        'Passcode not set',
        code: 'LAErrorPasscodeNotSet',
        details: 101,
      );
      expect(ex2.message, equals('Passcode not set'));
      expect(ex2.code, equals('LAErrorPasscodeNotSet'));
      expect(ex2.details, equals(101));
      expect(ex2, isA<ChainkeyException>());
    });

    test('HardwareEnclaveException properties and defaults', () {
      const ex1 = HardwareEnclaveException('Failed to generate key');
      expect(ex1.message, equals('Failed to generate key'));
      expect(ex1.code, equals('HARDWARE_ENCLAVE_ERROR'));
      expect(ex1.details, isNull);
      expect(
        ex1.toString(),
        contains('HardwareEnclaveException(HARDWARE_ENCLAVE_ERROR)'),
      );

      const ex2 = HardwareEnclaveException(
        'Curve not supported',
        code: 'UNSUPPORTED_CURVE',
        details: 'secp256k1',
      );
      expect(ex2.message, equals('Curve not supported'));
      expect(ex2.code, equals('UNSUPPORTED_CURVE'));
      expect(ex2.details, equals('secp256k1'));
      expect(ex2, isA<ChainkeyException>());
    });

    test('PasskeyException properties and defaults', () {
      const ex1 = PasskeyException('Origin mismatch');
      expect(ex1.message, equals('Origin mismatch'));
      expect(ex1.code, equals('PASSKEY_ERROR'));
      expect(ex1.details, isNull);
      expect(ex1.toString(), contains('PasskeyException(PASSKEY_ERROR)'));

      const ex2 = PasskeyException(
        'Timeout',
        code: 'TIMEOUT',
        details: 30000,
      );
      expect(ex2.message, equals('Timeout'));
      expect(ex2.code, equals('TIMEOUT'));
      expect(ex2.details, equals(30000));
      expect(ex2, isA<ChainkeyException>());
    });

    test('Equality and HashCode across exception classes', () {
      const ex1 = UserCancelledException.withDetails('msg', code: 'CODE');
      const ex2 = UserCancelledException.withDetails('msg', code: 'CODE');
      const ex3 = UserCancelledException.withDetails('diff', code: 'CODE');
      const ex4 =
          BiometricsUnavailableException.withDetails('msg', code: 'CODE');

      expect(ex1, equals(ex2));
      expect(ex1.hashCode, equals(ex2.hashCode));
      expect(ex1, isNot(equals(ex3)));
      expect(ex1, isNot(equals(ex4)));
    });
  });

  group('ChainkeyException.fromPlatformException mapping', () {
    test('maps iOS LAError / user cancelled codes', () {
      final pe1 = PlatformException(
        code: 'LAErrorUserCancel',
        message: 'User tapped cancel',
        details: 'ios-details',
      );
      final ex1 = ChainkeyException.fromPlatformException(pe1);
      expect(ex1, isA<UserCancelledException>());
      expect(ex1.code, equals('LAErrorUserCancel'));
      expect(ex1.message, equals('User tapped cancel'));
      expect(ex1.details, equals('ios-details'));

      final pe2 = PlatformException(
        code: 'USER_CANCELLED',
        message: 'User cancelled authentication prompt',
      );
      expect(
        ChainkeyException.fromPlatformException(pe2),
        isA<UserCancelledException>(),
      );

      final pe3 = PlatformException(
        code: 'ERROR_USER_CANCELED',
        message: 'Android biometric prompt cancelled by user',
      );
      expect(
        ChainkeyException.fromPlatformException(pe3),
        isA<UserCancelledException>(),
      );
    });

    test('maps key invalidated codes', () {
      final pe1 = PlatformException(
        code: 'KEY_PERMANENTLY_INVALIDATED',
        message: 'Key permanently invalidated',
      );
      final ex1 = ChainkeyException.fromPlatformException(pe1);
      expect(ex1, isA<KeyPermanentlyInvalidatedException>());
      expect(ex1.code, equals('KEY_PERMANENTLY_INVALIDATED'));

      final pe2 = PlatformException(
        code: 'KEYPERMANENTLYINVALIDATEDEXCEPTION',
        message: 'Biometric enrollment changed',
      );
      expect(
        ChainkeyException.fromPlatformException(pe2),
        isA<KeyPermanentlyInvalidatedException>(),
      );
    });

    test('maps biometrics unavailable codes', () {
      final pe1 = PlatformException(
        code: 'LAErrorBiometryNotEnrolled',
        message: 'No Face ID enrolled',
      );
      final ex1 = ChainkeyException.fromPlatformException(pe1);
      expect(ex1, isA<BiometricsUnavailableException>());
      expect(ex1.code, equals('LAErrorBiometryNotEnrolled'));

      final pe2 = PlatformException(
        code: 'BIOMETRIC_ERROR_HW_UNAVAILABLE',
        message: 'Hardware sensor busy or unavailable',
      );
      expect(
        ChainkeyException.fromPlatformException(pe2),
        isA<BiometricsUnavailableException>(),
      );

      final pe3 = PlatformException(
        code: 'BIOMETRICS_UNAVAILABLE',
        message: 'Device has no biometric sensors',
      );
      expect(
        ChainkeyException.fromPlatformException(pe3),
        isA<BiometricsUnavailableException>(),
      );
    });

    test('maps passkey and webauthn codes', () {
      final pe1 = PlatformException(
        code: 'ORIGIN_MISMATCH',
        message: 'Relying party ID does not match app domain',
      );
      final ex1 = ChainkeyException.fromPlatformException(pe1);
      expect(ex1, isA<PasskeyException>());
      expect(ex1.code, equals('ORIGIN_MISMATCH'));

      final pe2 = PlatformException(
        code: 'UNSUPPORTED_ALGORITHM',
        message: 'Algorithm COSE -7 not supported',
      );
      expect(
        ChainkeyException.fromPlatformException(pe2),
        isA<PasskeyException>(),
      );

      final pe3 = PlatformException(
        code: 'TIMEOUT',
        message: 'Credential creation timed out',
      );
      expect(
        ChainkeyException.fromPlatformException(pe3),
        isA<PasskeyException>(),
      );
    });

    test('maps hardware enclave codes', () {
      final pe1 = PlatformException(
        code: 'KEY_GENERATION_FAILED',
        message: 'Failed to generate key inside Secure Enclave',
      );
      final ex1 = ChainkeyException.fromPlatformException(pe1);
      expect(ex1, isA<HardwareEnclaveException>());
      expect(ex1.code, equals('KEY_GENERATION_FAILED'));

      final pe2 = PlatformException(
        code: 'STRONGBOX_ERROR',
        message: 'StrongBox HSM unavailable',
      );
      expect(
        ChainkeyException.fromPlatformException(pe2),
        isA<HardwareEnclaveException>(),
      );
    });

    test('fallback fuzzy keyword matching in messages', () {
      final pe1 = PlatformException(
        code: 'GENERIC_CODE',
        message: 'The user dismissed the biometric dialog',
      );
      expect(
        ChainkeyException.fromPlatformException(pe1),
        isA<UserCancelledException>(),
      );

      final pe2 = PlatformException(
        code: 'GENERIC_CODE',
        message: 'The cryptographic key was permanently invalidated by user',
      );
      expect(
        ChainkeyException.fromPlatformException(pe2),
        isA<KeyPermanentlyInvalidatedException>(),
      );

      final pe3 = PlatformException(
        code: 'GENERIC_CODE',
        message: 'Biometric authentication is not available on this device',
      );
      expect(
        ChainkeyException.fromPlatformException(pe3),
        isA<BiometricsUnavailableException>(),
      );

      final pe4 = PlatformException(
        code: 'GENERIC_CODE',
        message: 'WebAuthn passkey registration failed with origin mismatch',
      );
      expect(
        ChainkeyException.fromPlatformException(pe4),
        isA<PasskeyException>(),
      );

      final pe5 = PlatformException(
        code: 'OTHER_CODE',
        message: 'Unknown hardware failure',
      );
      expect(
        ChainkeyException.fromPlatformException(pe5),
        isA<HardwareEnclaveException>(),
      );
    });

    test('ChainkeyException.from helper handles various error types', () {
      const existing = PasskeyException('already typed');
      expect(ChainkeyException.from(existing), same(existing));

      final pe = PlatformException(code: 'USER_CANCELLED');
      expect(ChainkeyException.from(pe), isA<UserCancelledException>());

      final se = StateError('Something went wrong');
      final ex = ChainkeyException.from(se);
      expect(ex, isA<HardwareEnclaveException>());
      expect(ex.message, contains('Something went wrong'));
    });
  });
}
