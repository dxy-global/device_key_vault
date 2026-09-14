## 0.1.0

- `DeviceKeyVault`: `availability`, `store`, `unlock`, `clear`, with typed results.
- iOS: Keychain item with `.biometryCurrentSet`, domain-state marker for invalidation.
- iOS: `VaultUnavailableReason.notAllowed` when the person refused the app the use of Face ID.
- Android: AES-GCM KeyStore key, `BIOMETRIC_STRONG`, invalidated by biometric enrolment.
- `FakeDeviceKeyVault` in `package:device_key_vault/testing.dart`.
