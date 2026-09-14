import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_key_vault_method_channel.dart';
import 'src/types.dart';

abstract class DeviceKeyVaultPlatform extends PlatformInterface {
  DeviceKeyVaultPlatform() : super(token: _token);

  static final Object _token = Object();
  static DeviceKeyVaultPlatform _instance = MethodChannelDeviceKeyVault();

  static DeviceKeyVaultPlatform get instance => _instance;

  static set instance(DeviceKeyVaultPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<VaultAvailability> availability();
  Future<VaultResult<void>> store(String secret, {required String prompt});
  Future<VaultResult<String>> unlock({required String prompt});
  Future<void> clear();
}
