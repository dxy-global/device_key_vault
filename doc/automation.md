# Driving biometrics in automated tests

## iOS Simulator
- enroll / unenroll via BiometricKit.enrollmentChanged: WORKS (Xcode 26.6, iOS 26.4.1, simulator dkv-iphone)
- match / nomatch via BiometricKit_Sim.pearl.*: WORKS
- Consequence for the iOS lane: the enrolment-change test is MANUAL. Tried unenroll followed by enroll through `tool/sim_biometrics.sh`: `LAContext.domainState.biometry.stateHash` stayed identical and a `.biometryCurrentSet` Keychain item stayed readable, because the simulator enrols the same hard-coded identity every time.

## Android Emulator
- `adb emu finger touch 1` matches an enrolled fingerprint: WORKS (image android-36 google_apis_playstore arm64-v8a, AVD dkv_biometrics)
- Enrolment itself needs the Settings UI, so the enrolment-change test on Android is MANUAL.

## Recreating the lane devices

Both devices serve these lanes only. Everything below comes from the spike that made them (Xcode 26.6; emulator 36.4.9.0).

**iOS: the simulator `dkv-iphone`**
- `xcrun simctl create dkv-iphone "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-4` prints the UDID to pass to `tool/integration_ios.sh`. Two installed runtimes may share that identifier (26.4 and 26.4.1); the lane device runs 26.4.1 (`xcrun simctl getenv <udid> SIMULATOR_RUNTIME_VERSION`).
- Boot it with `xcrun simctl boot <udid>`. The lane enrols Face ID itself (`tool/sim_biometrics.sh ios <udid> enroll`); nothing else needs setting up.

**Android: the AVD `dkv_biometrics`**
- `avdmanager create avd -n dkv_biometrics -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_7` (a 1080×2400 screen).
- Start it with `emulator -avd dkv_biometrics -no-snapshot-save -no-window -no-audio -no-boot-anim`; it comes up as `emulator-5554`.
- Enrol the PIN `1234` and one fingerprint once, with adb only. Both survive a cold boot. On this image the path is Security & privacy → Device unlock → Pixel Imprint; tap coordinates come from the bounds in `adb shell uiautomator dump` (those below are the ones recorded on this screen):
  1. `adb -s emulator-5554 shell am start -a android.settings.SECURITY_SETTINGS`, then tap the "Device unlock" row (`input tap 540 2133`) and "Pixel Imprint" (`input tap 540 1671`).
  2. Choose "Pixel Imprint + PIN" (`input tap 540 938`). `input text 1234`, tap Next (`911 1538`); `input text 1234` again, tap Confirm (`905 1538`); tap Done (`911 2242`).
  3. On "Set up Pixel Imprint" tap More (`911 2242`), then the same button again, now I Agree.
  4. At "Touch the sensor", run `tool/sim_biometrics.sh android emulator-5554 touch` three times, until "Fingerprint added"; tap Done.
  5. Check: `adb -s emulator-5554 shell dumpsys fingerprint` shows `"count":1`, and `adb -s emulator-5554 shell dumpsys lock_settings` shows `CredentialType: PIN`.
- After every boot the emulator stays locked until the PIN is entered once; a fingerprint touch cannot unlock it. When `adb shell dumpsys trust` shows `deviceLocked=1`, `tool/integration_android.sh` unlocks it before `flutter test`, and stops unless `dumpsys trust` then shows `deviceLocked=0`:
  ```bash
  adb -s "$serial" shell input keyevent KEYCODE_WAKEUP
  adb -s "$serial" shell input swipe 540 1800 540 600 300   # the 1080×2400 screen
  sleep 1
  adb -s "$serial" shell input text 1234
  adb -s "$serial" shell input keyevent KEYCODE_ENTER
  sleep 3
  ```
  The sequence was verified starting at least 10 s after `sys.boot_completed=1`; sooner has not been tried.
