/// What kind of sensor the phone offers. Used to label a button, never to
/// decide whether something is allowed.
enum BiometricKind { face, fingerprint, iris, other }

/// Why biometrics cannot be used right now.
enum VaultUnavailableReason { noHardware, notEnrolled, lockedOut }

class VaultAvailability {
  const VaultAvailability.ready(BiometricKind this.kind) : reason = null;
  const VaultAvailability.unavailable(VaultUnavailableReason this.reason) : kind = null;

  final BiometricKind? kind;
  final VaultUnavailableReason? reason;

  bool get isReady => reason == null;

  static VaultAvailability fromWire(Map<Object?, Object?> m) {
    if (m['ready'] == true) {
      return VaultAvailability.ready(switch (m['kind']) {
        'face' => BiometricKind.face,
        'fingerprint' => BiometricKind.fingerprint,
        'iris' => BiometricKind.iris,
        _ => BiometricKind.other,
      });
    }
    return VaultAvailability.unavailable(switch (m['reason']) {
      'not_enrolled' => VaultUnavailableReason.notEnrolled,
      'locked_out' => VaultUnavailableReason.lockedOut,
      _ => VaultUnavailableReason.noHardware,
    });
  }
}

/// Every expected way an operation does not succeed.
enum VaultFailure { cancelled, invalidated, notFound, lockedOut, unavailable, failed }

VaultFailure vaultFailureFromCode(String code) => switch (code) {
      'cancelled' => VaultFailure.cancelled,
      'invalidated' => VaultFailure.invalidated,
      'not_found' => VaultFailure.notFound,
      'locked_out' => VaultFailure.lockedOut,
      'unavailable' => VaultFailure.unavailable,
      _ => VaultFailure.failed,
    };

/// A result, not an exception: cancelling a prompt is an ordinary outcome and
/// callers must handle it, so the type makes them.
sealed class VaultResult<T> {
  const VaultResult();
}

final class VaultSuccess<T> extends VaultResult<T> {
  const VaultSuccess(this.value);
  final T value;
}

final class VaultError<T> extends VaultResult<T> {
  const VaultError(this.failure, [this.message]);
  final VaultFailure failure;
  final String? message;
}
