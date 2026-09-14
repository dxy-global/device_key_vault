import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_key_vault_platform_interface.dart';

/// An implementation of [DeviceKeyVaultPlatform] that uses method channels.
class MethodChannelDeviceKeyVault extends DeviceKeyVaultPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('device_key_vault');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
