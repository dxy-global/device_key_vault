import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_key_vault_method_channel.dart';

abstract class DeviceKeyVaultPlatform extends PlatformInterface {
  /// Constructs a DeviceKeyVaultPlatform.
  DeviceKeyVaultPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceKeyVaultPlatform _instance = MethodChannelDeviceKeyVault();

  /// The default instance of [DeviceKeyVaultPlatform] to use.
  ///
  /// Defaults to [MethodChannelDeviceKeyVault].
  static DeviceKeyVaultPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DeviceKeyVaultPlatform] when
  /// they register themselves.
  static set instance(DeviceKeyVaultPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
