#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This check requires macOS and Xcode."
  exit 1
fi
xcodebuild -version
swift test
xcodebuild -project ParkCast.xcodeproj -scheme ParkCast \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
if [[ "${1:-}" == "--carplay" ]]; then
  sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
  if (( ${sdk_version%%.*} < 27 )); then
    echo "The optional CarPlay scheme needs the iOS 27 SDK or later."
    exit 1
  fi
  xcodebuild -project ParkCast.xcodeproj -scheme ParkCastCarPlay \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
fi
