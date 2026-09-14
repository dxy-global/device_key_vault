#!/usr/bin/env bash
# The whole gate for this plugin. There is no CI: run this before every push
# and before every tag. Device lanes are separate: tool/integration_ios.sh and
# tool/integration_android.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
flutter analyze
flutter test

cd example
flutter pub get
flutter analyze
flutter build apk --debug
flutter build ios --simulator --no-codesign
echo "device_key_vault verify: green"
