# Changelog

## 0.2.0

### Added

- **DER signature unpacker** — `P256Signature.fromDer` parses ASN.1 DER-encoded ECDSA signatures.
- **Low-S normalizer** — BIP-62 / EIP-2 canonical low-S enforcement for P-256 signatures.
- **SEC1 point formatter** — `P256PublicKey` SEC1 compressed/uncompressed encoding, SPKI parser, on-curve validation.
- **Wycheproof test vectors** — EIP-7212 and Wycheproof vectors covering all crypto primitives.

## 0.1.1

- Initial release with P-256 key generation and signing.
