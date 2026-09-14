#!/usr/bin/env bash
# The Android device lane. Pass the serial of a running emulator that already
# has a fingerprint enrolled (see doc/automation.md).
#   tool/integration_android.sh emulator-5554
set -euo pipefail
cd "$(dirname "$0")/.."
serial="$1"

# After every boot the emulator stays locked until its PIN is entered once; a
# fingerprint touch cannot unlock it. PIN 1234 and the swipe coordinates are
# those of the dkv_biometrics AVD (1080x2400 screen) named in doc/automation.md.
if adb -s "$serial" shell dumpsys trust | grep -q 'deviceLocked=1'; then
  adb -s "$serial" shell input keyevent KEYCODE_WAKEUP
  adb -s "$serial" shell input swipe 540 1800 540 600 300
  sleep 1
  adb -s "$serial" shell input text 1234
  adb -s "$serial" shell input keyevent KEYCODE_ENTER
  sleep 3
fi
adb -s "$serial" shell dumpsys trust | grep -q 'deviceLocked=0' ||
  { echo "$serial is not unlocked: dumpsys trust shows no deviceLocked=0" >&2; exit 1; }

cd example
flutter test integration_test/vault_test.dart -d "$serial" 2>&1 |
while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *DKV:MATCH*)
      ( sleep 2; ../tool/sim_biometrics.sh android "$serial" touch ) & ;;
  esac
done
test "${PIPESTATUS[0]}" -eq 0
