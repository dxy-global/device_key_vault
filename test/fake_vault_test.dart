import 'package:device_key_vault/device_key_vault.dart';
import 'package:device_key_vault/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores, unlocks with a prompt, and clears', () async {
    final v = FakeDeviceKeyVault();
    expect(await v.store('k', prompt: 'on'), isA<VaultSuccess<void>>());
    final r = await v.unlock(prompt: 'in');
    expect((r as VaultSuccess<String>).value, 'k');
    expect(v.promptTexts, ['on', 'in']);
    await v.clear();
    expect(((await v.unlock(prompt: 'in')) as VaultError<String>).failure, VaultFailure.notFound);
  });

  test('an enrolment change invalidates the secret, as the real platforms do', () async {
    final v = FakeDeviceKeyVault();
    await v.store('k', prompt: 'on');
    v.changeEnrolment();
    expect(((await v.unlock(prompt: 'in')) as VaultError<String>).failure, VaultFailure.invalidated);
    expect(v.secret, isNull, reason: 'invalidated means gone, not merely refused once');
  });

  test('a scripted failure happens once, then behaviour returns to normal', () async {
    final v = FakeDeviceKeyVault()..nextStoreFailure = VaultFailure.cancelled;
    expect(((await v.store('k', prompt: 'on')) as VaultError<void>).failure, VaultFailure.cancelled);
    expect(v.secret, isNull);
    expect(await v.store('k', prompt: 'on'), isA<VaultSuccess<void>>());
  });

  test('unavailable biometrics refuse store and unlock without prompting', () async {
    final v = FakeDeviceKeyVault()
      ..available = const VaultAvailability.unavailable(VaultUnavailableReason.notEnrolled);
    expect(((await v.store('k', prompt: 'on')) as VaultError<void>).failure, VaultFailure.unavailable);
    expect(v.prompts, 0);
  });

  test('removing every biometric while a secret is stored invalidates it, as the phones do', () async {
    final v = FakeDeviceKeyVault();
    await v.store('k', prompt: 'on');
    v.available = const VaultAvailability.unavailable(VaultUnavailableReason.notEnrolled);
    expect(((await v.unlock(prompt: 'in')) as VaultError<String>).failure, VaultFailure.invalidated);
    expect(v.secret, isNull);
    expect(v.prompts, 1, reason: 'only the store prompted');
    expect(((await v.unlock(prompt: 'in')) as VaultError<String>).failure, VaultFailure.notFound);
  });

  test('a locked-out sensor refuses without prompting and keeps the secret', () async {
    final v = FakeDeviceKeyVault();
    await v.store('k', prompt: 'on');
    v.available = const VaultAvailability.unavailable(VaultUnavailableReason.lockedOut);
    expect(((await v.unlock(prompt: 'in')) as VaultError<String>).failure, VaultFailure.lockedOut);
    expect(((await v.store('k2', prompt: 'on')) as VaultError<void>).failure, VaultFailure.lockedOut);
    expect(v.secret, 'k');
    expect(v.prompts, 1);
  });
}
