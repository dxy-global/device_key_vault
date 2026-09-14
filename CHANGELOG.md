## 0.1.0

- `DeviceKeyVault`: `availability`, `store`, `unlock`, `clear`, with typed results.
- iOS: Keychain item with `.biometryCurrentSet`, domain-state marker for invalidation.
- Android: AES-GCM KeyStore key, `BIOMETRIC_STRONG`, invalidated by biometric enrolment.
- `FakeDeviceKeyVault` in `package:device_key_vault/testing.dart`.
