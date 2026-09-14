#!/usr/bin/env bash
# The iOS device lane. Boots nothing: pass the udid of a booted Face ID simulator.
#   tool/integration_ios.sh <udid>
# Set DKV_ENROLMENT_AUTOMATED=true only if doc/automation.md says enrolment works.
set -euo pipefail
cd "$(dirname "$0")/.."
udid="$1"
automated="${DKV_ENROLMENT_AUTOMATED:-false}"

tool/sim_biometrics.sh ios "$udid" enroll
cd example
flutter test integration_test/vault_test.dart -d "$udid" \
  --dart-define=DKV_ENROLMENT_AUTOMATED="$automated" 2>&1 |
while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *DKV:MATCH*)
      ( sleep 2; ../tool/sim_biometrics.sh ios "$udid" match ) & ;;
    *DKV:REENROL*)
      ( ../tool/sim_biometrics.sh ios "$udid" unenroll; sleep 1; ../tool/sim_biometrics.sh ios "$udid" enroll ) & ;;
  esac
done
test "${PIPESTATUS[0]}" -eq 0
