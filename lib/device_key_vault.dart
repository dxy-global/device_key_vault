import 'device_key_vault_platform_interface.dart';
import 'src/types.dart';

export 'src/types.dart';

/// One secret per app install, behind the phone's biometrics.
///
/// `store` and `unlock` each ask for a biometric match. The device passcode is
/// never accepted. When the enrolled biometrics change, the secret becomes
/// unreadable and `unlock` answers [VaultFailure.invalidated].
abstract class DeviceKeyVault {
  const factory DeviceKeyVault() = _PlatformDeviceKeyVault;

  Future<VaultAvailability> availability();
  Future<VaultResult<void>> store(String secret, {required String prompt});
  Future<VaultResult<String>> unlock({required String prompt});
  Future<void> clear();
}

class _PlatformDeviceKeyVault implements DeviceKeyVault {
  const _PlatformDeviceKeyVault();

  @override
  Future<VaultAvailability> availability() => DeviceKeyVaultPlatform.instance.availability();

  @override
  Future<VaultResult<void>> store(String secret, {required String prompt}) =>
      DeviceKeyVaultPlatform.instance.store(secret, prompt: prompt);

  @override
  Future<VaultResult<String>> unlock({required String prompt}) =>
      DeviceKeyVaultPlatform.instance.unlock(prompt: prompt);

  @override
  Future<void> clear() => DeviceKeyVaultPlatform.instance.clear();
}
