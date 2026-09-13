/// Represents the hardware security level backing the cryptographic key.
enum HardwareIsolationLevel {
  /// Hardware isolated using Apple Secure Enclave.
  secureEnclave,

  /// Hardware isolated using Android StrongBox HSM (dedicated hardware chip).
  strongBox,

  /// Hardware isolated using Android Trusted Execution Environment (TEE).
  tee,

  /// Software-backed or browser-managed key (e.g. WebAuthn or software sandbox).
  software,
}
