#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Building iOS binaries requires a macOS Xcode runner."
  exit 1
fi
xcodebuild -version
swift test
plutil -lint Config/Info.plist ParkCast.xcodeproj/project.pbxproj
xcodebuild -project ParkCast.xcodeproj -scheme ParkCast \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/Device CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' build
app_path="$PWD/build/Device/Build/Products/Release-iphoneos/ParkCast.app"
test -f "$app_path/ParkCast"
xcrun lipo "$app_path/ParkCast" -verify_arch arm64
mkdir -p dist
ipa_output="$PWD/dist/ParkCast-unsigned.ipa"
payload_root="$(mktemp -d "$PWD/build/payload.XXXXXX")"
mkdir -p "$payload_root/Payload"
ditto "$app_path" "$payload_root/Payload/ParkCast.app"
# An unsigned ARM64 device bundle, not a simulator bundle and not directly installable.
ditto -c -k --keepParent "$payload_root/Payload" "$ipa_output"
unzip -t "$ipa_output"
shasum -a 256 "$ipa_output" > "$ipa_output.sha256"
echo "Created $ipa_output. Sign/install using your own Apple account in a sideloading tool."
