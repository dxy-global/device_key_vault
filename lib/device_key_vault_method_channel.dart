import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_key_vault_platform_interface.dart';
import 'src/types.dart';

class MethodChannelDeviceKeyVault extends DeviceKeyVaultPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('device_key_vault');

  @override
  Future<VaultAvailability> availability() async {
    final m = await methodChannel.invokeMapMethod<Object?, Object?>('availability');
    return VaultAvailability.fromWire(m ?? const {});
  }

  @override
  Future<VaultResult<void>> store(String secret, {required String prompt}) async {
    // iOS terminates the app when LocalAuthentication gets an empty reason.
    if (prompt.trim().isEmpty) return const VaultError(VaultFailure.failed, 'prompt must not be empty');
    try {
      await methodChannel.invokeMethod<void>('store', {'secret': secret, 'prompt': prompt});
      return const VaultSuccess(null);
    } on PlatformException catch (e) {
      return VaultError(vaultFailureFromCode(e.code), e.message);
    }
  }

  @override
  Future<VaultResult<String>> unlock({required String prompt}) async {
    if (prompt.trim().isEmpty) return const VaultError(VaultFailure.failed, 'prompt must not be empty');
    try {
      final secret = await methodChannel.invokeMethod<String>('unlock', {'prompt': prompt});
      if (secret == null) return const VaultError(VaultFailure.failed, 'no secret returned');
      return VaultSuccess(secret);
    } on PlatformException catch (e) {
      return VaultError(vaultFailureFromCode(e.code), e.message);
    }
  }

  @override
  Future<void> clear() => methodChannel.invokeMethod<void>('clear');
}
