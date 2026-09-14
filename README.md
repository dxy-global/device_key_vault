# device_key_vault

One secret per app install, kept behind the phone's biometrics.

- `store(secret, prompt:)` and `unlock(prompt:)` each require a biometric match.
- The device passcode is never accepted.
- Adding or removing a face or fingerprint makes the secret unreadable:
  `unlock` returns `VaultFailure.invalidated`, and the slot is cleared.
- No network. The plugin does not know what the secret is for.

```dart
const vault = DeviceKeyVault();
const secret = 'device-key';
final available = await vault.availability();
if (available.isReady) {
  final stored = await vault.store(secret, prompt: 'Turn on Face ID');
  if (stored is VaultSuccess) {
    final unlocked = await vault.unlock(prompt: 'Sign in');
    switch (unlocked) {
      case VaultSuccess(:final value):
        print(value);
      case VaultError(:final failure): // cancelled, invalidated, notFound, lockedOut, unavailable, failed
        print(failure);
    }
  }
}
```

Tests: `import 'package:device_key_vault/testing.dart';` gives `FakeDeviceKeyVault`.

## Host app requirements

**Android**
- `MainActivity` must extend `FlutterFragmentActivity`.
- minSdk 24. Strong biometrics only (Class 3).
- On Android 8.1 (API 27) and below, androidx.biometric draws its own fingerprint dialog, which needs an AppCompat theme: make the parent of both `LaunchTheme` and `NormalTheme` (in `res/values/styles.xml` and `res/values-night/styles.xml`) a `Theme.AppCompat` theme, e.g. `Theme.AppCompat.Light.NoActionBar` and `Theme.AppCompat.NoActionBar`.
- A lockout is reported by `store` and `unlock` (`lockedOut`), not by `availability`: Android's `BiometricManager` has no public lockout status, so `availability` can say ready while the sensor is locked.

**iOS**
- `Info.plist` must contain `NSFaceIDUsageDescription`, or iOS terminates the app when Face ID is requested.
- iOS 13 or later.
- Keychain items survive deleting the app (Android app storage does not), so a reinstall finds the previous secret. Call `clear()` on first launch if a fresh install must start empty.
- A major iOS update can change the biometric domain state, so `unlock` may report `invalidated` once afterwards; the host app then asks the person to turn the feature on again.

## Depending on it

```yaml
dependencies:
  device_key_vault:
    git:
      url: git@github.com:dxy-global/device_key_vault.git
      ref: v0.1.0
```

## Working on it

- `./tool/verify.sh` is the whole gate. There is no CI.
- Device lanes: `tool/integration_ios.sh <udid>` and `tool/integration_android.sh <serial>`.
  See `doc/automation.md` for what each can drive.
- The iOS Simulator does not enforce `.biometryCurrentSet` and never changes the biometric domain state, so the iOS lane proves the channel and the Keychain plumbing, not the biometric protection or its invalidation; the manual checks below do. The lanes use the dedicated devices described in `doc/automation.md`: the simulator `dkv-iphone`, and the AVD `dkv_biometrics` with PIN `1234` and one enrolled fingerprint.

## Manual checks before a release

On a real iPhone with Face ID and a real Android phone with a fingerprint reader, in the example app:

1. Store, then Unlock: success with the stored value.
2. Unlock, then cancel the prompt: `error cancelled`.
3. Unlock, then present a face or finger that is not enrolled: the prompt says it did not recognise it and stays open; cancel it: `error cancelled`.
4. Unlock, and while the prompt is showing, send the app to the background and bring it back: the unlock ends with an error; Unlock again: success with the stored value (the key was kept).
5. Add a new face (alternate appearance) or fingerprint in Settings, then Unlock: `error invalidated`, then Unlock again: `error notFound`.
6. Store, then remove every face or fingerprint in Settings: Availability: `unavailable notEnrolled`; Unlock: `error invalidated`, then `error notFound`.
7. Store, then fail the biometric until the OS locks it (the prompt never offers the device passcode), then Unlock: `error lockedOut`.
8. Store, then Store again and cancel that prompt: Unlock still returns the first value.
9. On an Android 8.x phone (or an API 26/27 emulator), with the host's themes set as above: Store and Unlock show the fingerprint dialog without crashing.
10. On an iPhone, deny the Face ID permission alert the first Store triggers: Availability: `unavailable notAllowed`; allow it again in Settings → the app → Face ID: Availability: `ready face`.
