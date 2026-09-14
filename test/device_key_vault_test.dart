import 'package:flutter_test/flutter_test.dart';
import 'package:device_key_vault/device_key_vault.dart';
import 'package:device_key_vault/device_key_vault_platform_interface.dart';
import 'package:device_key_vault/device_key_vault_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceKeyVaultPlatform
    with MockPlatformInterfaceMixin
    implements DeviceKeyVaultPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DeviceKeyVaultPlatform initialPlatform = DeviceKeyVaultPlatform.instance;

  test('$MethodChannelDeviceKeyVault is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDeviceKeyVault>());
  });

  test('getPlatformVersion', () async {
    DeviceKeyVault deviceKeyVaultPlugin = DeviceKeyVault();
    MockDeviceKeyVaultPlatform fakePlatform = MockDeviceKeyVaultPlatform();
    DeviceKeyVaultPlatform.instance = fakePlatform;

    expect(await deviceKeyVaultPlugin.getPlatformVersion(), '42');
  });
}
