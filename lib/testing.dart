import 'device_key_vault.dart';

/// A [DeviceKeyVault] for tests. No platform channel, no device.
///
/// Behaves like the real platforms in the ways callers depend on: prompting
/// only when biometrics are available, and losing the secret — not merely
/// refusing it — when enrolment changes.
class FakeDeviceKeyVault implements DeviceKeyVault {
  FakeDeviceKeyVault({this.available = const VaultAvailability.ready(BiometricKind.face)});

  VaultAvailability available;

  /// Applied to the next [store] or [unlock] only, then reset.
  VaultFailure? nextStoreFailure;
  VaultFailure? nextUnlockFailure;

  String? _secret;
  bool _invalidated = false;
  int prompts = 0;
  final List<String> promptTexts = [];

  String? get secret => _secret;

  /// Someone added or removed a face or fingerprint on the phone.
  void changeEnrolment() {
    if (_secret != null) _invalidated = true;
    _secret = null;
  }

  @override
  Future<VaultAvailability> availability() async => available;

  @override
  Future<VaultResult<void>> store(String secret, {required String prompt}) async {
    if (!available.isReady) return const VaultError(VaultFailure.unavailable);
    prompts++;
    promptTexts.add(prompt);
    final failure = nextStoreFailure;
    nextStoreFailure = null;
    if (failure != null) return VaultError(failure);
    _secret = secret;
    _invalidated = false;
    return const VaultSuccess(null);
  }

  @override
  Future<VaultResult<String>> unlock({required String prompt}) async {
    if (_invalidated) {
      _invalidated = false;
      return const VaultError(VaultFailure.invalidated);
    }
    if (_secret == null) return const VaultError(VaultFailure.notFound);
    if (!available.isReady) return const VaultError(VaultFailure.unavailable);
    prompts++;
    promptTexts.add(prompt);
    final failure = nextUnlockFailure;
    nextUnlockFailure = null;
    if (failure != null) return VaultError(failure);
    return VaultSuccess(_secret!);
  }

  @override
  Future<void> clear() async {
    _secret = null;
    _invalidated = false;
  }
}
