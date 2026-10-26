#!/bin/bash
# Build with Xcode without a device/certificate and package the unsigned .app
# into a standard IPA container for a free-account sideloading client to sign.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/output"
ARCHIVE="$OUT/RPASnapshot-unsigned.xcarchive"
APP="$ARCHIVE/Products/Applications/RPASnapshot.app"
IPA="$OUT/RPASnapshot-unsigned.ipa"

if [[ "${1:-}" != "--package-only" ]]; then
  bash "$ROOT/build_unsigned_archive.command"
fi
if [[ ! -d "$APP" ]]; then
  echo "ERROR: Missing $APP; build the archive first." >&2
  exit 2
fi
INFO="$APP/Info.plist"
if [[ ! -f "$INFO" ]]; then echo "ERROR: Missing Info.plist" >&2; exit 3; fi
MIN_OS=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$INFO")
EXE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO")
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")
ARCHS=$(lipo -archs "$APP/$EXE")
case " $ARCHS " in *' arm64 '*) ;; *) echo 'ERROR: arm64 missing' >&2; exit 4;; esac
case "$MIN_OS" in 15|15.*) ;; *) echo "ERROR: This source should target iOS 15, got $MIN_OS" >&2; exit 5;; esac
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
# Preserve bundle files, avoid modifying anything in the archive.
ditto "$APP" "$STAGE/Payload/RPASnapshot.app"
rm -f "$IPA"
(cd "$STAGE" && /usr/bin/zip -qry "$IPA" Payload)
/usr/bin/unzip -tq "$IPA" >/dev/null
if ! /usr/bin/unzip -Z1 "$IPA" | grep -q '^Payload/RPASnapshot.app/Info.plist$'; then
  echo 'ERROR: IPA structure invalid' >&2; exit 6
fi
printf '\nSUCCESS: %s\nMinimum iOS: %s\nArchitecture: %s\nBundle ID: %s\n' "$IPA" "$MIN_OS" "$ARCHS" "$BUNDLE_ID"
echo 'NOTE: IPA is UNSIGNED and cannot be installed directly. Sign+install using your own free Apple Account in a compatible signing tool.'
