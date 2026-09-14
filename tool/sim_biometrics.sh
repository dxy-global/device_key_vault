#!/usr/bin/env bash
# Drives the simulated biometric sensor from the host.
#   tool/sim_biometrics.sh ios <udid> enroll|unenroll|match|nomatch
#   tool/sim_biometrics.sh android <serial> touch
# iOS uses the notifications the iOS Simulator's BiometricKit listens for (the
# same ones Appium's XCUITest driver sends). Android uses the emulator console.
set -euo pipefail
platform="$1"; target="$2"; action="$3"

case "$platform:$action" in
  ios:enroll)
    xcrun simctl spawn "$target" notifyutil -s com.apple.BiometricKit.enrollmentChanged '1'
    xcrun simctl spawn "$target" notifyutil -p com.apple.BiometricKit.enrollmentChanged ;;
  ios:unenroll)
    xcrun simctl spawn "$target" notifyutil -s com.apple.BiometricKit.enrollmentChanged '0'
    xcrun simctl spawn "$target" notifyutil -p com.apple.BiometricKit.enrollmentChanged ;;
  ios:match)
    xcrun simctl spawn "$target" notifyutil -p com.apple.BiometricKit_Sim.pearl.match ;;
  ios:nomatch)
    xcrun simctl spawn "$target" notifyutil -p com.apple.BiometricKit_Sim.pearl.nomatch ;;
  android:touch)
    adb -s "$target" emu finger touch 1 ;;
  *)
    echo "unknown: $platform $action" >&2; exit 2 ;;
esac
