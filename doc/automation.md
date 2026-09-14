# Driving biometrics in automated tests

## iOS Simulator
- enroll / unenroll via BiometricKit.enrollmentChanged: WORKS (Xcode 26.6, iOS 26.4.1, simulator dkv-iphone)
- match / nomatch via BiometricKit_Sim.pearl.*: WORKS
- Consequence for Task 5: the enrolment-change test is MANUAL. Tried unenroll followed by enroll through `tool/sim_biometrics.sh`: `LAContext.domainState.biometry.stateHash` stayed identical and a `.biometryCurrentSet` Keychain item stayed readable, because the simulator enrols the same hard-coded identity every time.

## Android Emulator
- `adb emu finger touch 1` matches an enrolled fingerprint: WORKS (image android-36 google_apis_playstore arm64-v8a, AVD dkv_biometrics)
- Enrolment itself needs the Settings UI, so the enrolment-change test on Android is MANUAL.
