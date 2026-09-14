
import 'device_key_vault_platform_interface.dart';

class DeviceKeyVault {
  Future<String?> getPlatformVersion() {
    return DeviceKeyVaultPlatform.instance.getPlatformVersion();
  }
}
