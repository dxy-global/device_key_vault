import 'dart:io';

import 'package:device_key_vault/device_key_vault.dart';
import 'package:device_key_vault_example/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs on a simulator or emulator driven by tool/integration_ios.sh or
/// tool/integration_android.sh. Each `DKV:` line is an instruction to the
/// runner, which answers it through tool/sim_biometrics.sh.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const vault = DeviceKeyVault();

  Future<VaultResult<T>> expectingMatch<T>(Future<VaultResult<T>> Function() op) {
    // ignore: avoid_print
    print('DKV:MATCH');
    return op();
  }

  testWidgets(
      'store, unlock, clear; a cancelled re-store keeps the secret (Android); '
      're-enrolment invalidates when automated (iOS)', (t) async {
    app.main();
    await t.pumpAndSettle();
    await vault.clear();

    final available = await vault.availability();
    expect(available.isReady, isTrue, reason: 'the runner enrols biometrics before the test');

    final stored = await expectingMatch(() => vault.store('kunci-perangkat', prompt: 'Turn on'));
    expect(stored, isA<VaultSuccess<void>>());

    final unlocked = await expectingMatch(() => vault.unlock(prompt: 'Sign in'));
    expect((unlocked as VaultSuccess<String>).value, 'kunci-perangkat');

    if (Platform.isAndroid) {
      // A cancelled re-store must leave the first secret in place (spec §6.1).
      // ignore: avoid_print
      print('DKV:CANCEL');
      final replaced = await vault.store('vervanging', prompt: 'Turn on again');
      expect((replaced as VaultError<void>).failure, VaultFailure.cancelled);
      final kept = await expectingMatch(() => vault.unlock(prompt: 'Sign in'));
      expect((kept as VaultSuccess<String>).value, 'kunci-perangkat');
    }

    if (Platform.isIOS && const bool.fromEnvironment('DKV_ENROLMENT_AUTOMATED')) {
      // ignore: avoid_print
      print('DKV:REENROL');
      await Future<void>.delayed(const Duration(seconds: 4));
      final after = await vault.unlock(prompt: 'Sign in');
      expect((after as VaultError<String>).failure, VaultFailure.invalidated);
      expect(((await vault.unlock(prompt: 'Sign in')) as VaultError<String>).failure,
          VaultFailure.notFound, reason: 'invalidated clears the slot');
    }

    await vault.clear();
    expect(((await vault.unlock(prompt: 'Sign in')) as VaultError<String>).failure,
        VaultFailure.notFound);
  });
}
