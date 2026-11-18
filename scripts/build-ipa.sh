#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ipa/Payload
xcodebuild \
  -project Xingli.xcodeproj \
  -scheme Xingli \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/Xingli.xcarchive" \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
app='build/Xingli.xcarchive/Products/Applications/Xingli.app'
test -f "$app/Info.plist"
test -f "$app/Xingli"
plutil -lint "$app/Info.plist"
file "$app/Xingli" | grep -q 'arm64'
cp -R "$app" build/ipa/Payload/
(cd build/ipa && zip -q -r ../Xingli-unsigned.ipa Payload)
unzip -l build/Xingli-unsigned.ipa
echo 'The device IPA is built. It still needs personal Apple signing before installation.'
