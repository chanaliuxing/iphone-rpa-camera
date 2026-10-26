#!/bin/bash
# Build an iOS 15 compatible unsigned archive with current Xcode, without connecting an iPhone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
IOS="$ROOT/iOS"
OUT="$ROOT/output"
mkdir -p "$OUT"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild is missing. Install Xcode, select it with xcode-select, and accept its license." >&2
  exit 2
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "ERROR: xcodegen is missing. Install it with: brew install xcodegen" >&2
  exit 2
fi
printf 'Xcode being used:\n'
xcodebuild -version
cd "$IOS"
xcodegen generate
xcodebuild \
  -project RPASnapshot.xcodeproj \
  -scheme RPASnapshot \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$OUT/RPASnapshot-unsigned.xcarchive" \
  CODE_SIGNING_ALLOWED=NO \
  archive 2>&1 | tee "$OUT/build.log"
APP="$OUT/RPASnapshot-unsigned.xcarchive/Products/Applications/RPASnapshot.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: Archive did not contain RPASnapshot.app" >&2
  exit 3
fi
INFO="$APP/Info.plist"
BIN_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO")
MIN_OS=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$INFO")
ARCHS=$(lipo -archs "$APP/$BIN_NAME")
printf '\nArchive: %s\nMinimum iOS: %s\nCPU architectures: %s\n' "$OUT/RPASnapshot-unsigned.xcarchive" "$MIN_OS" "$ARCHS"
case " $ARCHS " in *' arm64 '*) ;; *) echo 'ERROR: arm64 is missing' >&2; exit 4;; esac
case "$MIN_OS" in 15|15.*) ;; *) echo "WARNING: Unexpected deployment target $MIN_OS" >&2;; esac
echo 'SUCCESS: Unsigned archive built. Use a compatible signing tool and your own Apple Account to sign and install.'
