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

  /// What the platforms answer, before any prompt, when biometrics cannot be
  /// used: a locked-out sensor is `lockedOut`; anything else is `unavailable`.
  static VaultFailure _refusal(VaultUnavailableReason reason) =>
      reason == VaultUnavailableReason.lockedOut ? VaultFailure.lockedOut : VaultFailure.unavailable;

  @override
  Future<VaultAvailability> availability() async => available;

  @override
  Future<VaultResult<void>> store(String secret, {required String prompt}) async {
    if (!available.isReady) return VaultError(_refusal(available.reason!));
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
    if (!available.isReady) {
      if (available.reason == VaultUnavailableReason.notEnrolled) {
        // Every face or finger was removed: on both platforms the stored
        // secret is already unusable, and unlock clears the slot.
        _secret = null;
        return const VaultError(VaultFailure.invalidated);
      }
      return VaultError(_refusal(available.reason!));
    }
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
