#!/bin/bash
# Build a signed App Store archive of iPrompter for iPad and export a .ipa.
#
# Usage:  ./tools-appstore-archive.sh [output-dir]
#
# Prerequisites (one-time, all done by you in your Apple account):
#   1. Paid Apple Developer Program membership.
#   2. The bundle id in project.yml registered to your team.
#   3. Config/Signing.local.xcconfig with your DEVELOPMENT_TEAM (see
#      Config/Signing.xcconfig). This script reads the team id from there and
#      never writes it into the repo.
#
# Signing: uses Xcode automatic signing with -allowProvisioningUpdates, so the
# Apple Distribution certificate and the App Store provisioning profile are
# created for you on first run if they do not exist yet. You may be prompted
# to sign in to your Apple account.
#
# UPLOADING is deliberately NOT done here — see the end of this script.
set -euo pipefail

cd "$(dirname "$0")"
OUT="${1:-$HOME/Downloads/iPrompter-appstore}"
ARCHIVE="$OUT/iPrompter.xcarchive"
LOCAL_SIGNING="Config/Signing.local.xcconfig"

if [ ! -f "$LOCAL_SIGNING" ]; then
  echo "error: $LOCAL_SIGNING not found." >&2
  echo "       cp Config/Signing.local.xcconfig.example $LOCAL_SIGNING" >&2
  echo "       then set DEVELOPMENT_TEAM = YOURTEAMID" >&2
  exit 1
fi

TEAM="$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*\([A-Za-z0-9]*\).*/\1/p' \
  "$LOCAL_SIGNING" | head -1)"
if [ -z "$TEAM" ]; then
  echo "error: no DEVELOPMENT_TEAM found in $LOCAL_SIGNING" >&2
  exit 1
fi
echo "==> Team ${TEAM:0:3}******  (from $LOCAL_SIGNING)"

BUNDLE_ID="$(sed -n 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER:[[:space:]]*\(.*\)/\1/p' project.yml | head -1)"
VERSION="$(sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*"\(.*\)"/\1/p' project.yml | head -1)"
BUILD="$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*\(.*\)/\1/p' project.yml | head -1)"
echo "==> $BUNDLE_ID  version $VERSION build $BUILD"

mkdir -p "$OUT"
rm -rf "$ARCHIVE"

echo "==> Archiving (Release, generic/platform=iOS)"
xcodebuild -project iPrompter.xcodeproj -scheme iPrompter \
  -destination 'generic/platform=iOS' -configuration Release \
  -archivePath "$ARCHIVE" archive \
  -allowProvisioningUpdates \
  | grep -E "ARCHIVE (SUCCEEDED|FAILED)|error:|Signing" || true

[ -d "$ARCHIVE" ] || { echo "archive not produced" >&2; exit 1; }

# Sanity-check the two things App Store Connect rejects builds over.
APP="$ARCHIVE/Products/Applications/iPrompter.app"
echo "==> Preflight"
if [ -f "$APP/PrivacyInfo.xcprivacy" ]; then
  echo "    privacy manifest: present"
else
  echo "    privacy manifest: MISSING — upload will draw ITMS-91053" >&2
fi
if plutil -p "$APP/Info.plist" | grep -q ITSAppUsesNonExemptEncryption; then
  echo "    export compliance: declared"
else
  echo "    export compliance: not declared (you'll be asked on every upload)" >&2
fi
# NOTE: the archive itself is Development-signed — project.yml pins
# CODE_SIGN_IDENTITY[sdk=iphoneos*] to "Apple Development". exportArchive
# re-signs for distribution, so the signature that matters is the one in the
# exported .ipa, verified after the export below. Do not be alarmed by
# "Apple Development" here.

# ExportOptions is generated into the output dir, never committed: it carries
# the team id.
EXPORT_PLIST="$OUT/ExportOptions.plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>$TEAM</string>
	<key>destination</key>
	<string>export</string>
	<key>uploadSymbols</key>
	<true/>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
PLIST

echo "==> Exporting .ipa"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$OUT" \
  -allowProvisioningUpdates \
  | grep -E "EXPORT (SUCCEEDED|FAILED)|error:" || true

IPA="$(find "$OUT" -maxdepth 1 -name '*.ipa' | head -1)"
[ -n "$IPA" ] || { echo "no .ipa produced" >&2; exit 1; }

# The signature that actually matters: App Store Connect rejects anything not
# signed by an Apple Distribution certificate with an App Store profile.
echo "==> Verifying the exported .ipa"
VERIFY_DIR="$(mktemp -d)"
unzip -q "$IPA" -d "$VERIFY_DIR"
SIGNER="$(codesign -dvv "$VERIFY_DIR/Payload/iPrompter.app" 2>&1 \
  | sed -n 's/^Authority=//p' | head -1)"
echo "    signed by: $SIGNER"
case "$SIGNER" in
  "Apple Distribution"*)
    echo "    OK — distribution signed" ;;
  *)
    echo "    PROBLEM: not distribution-signed. App Store Connect will reject" >&2
    echo "    this at upload validation. Check that your team has an Apple" >&2
    echo "    Distribution certificate and that Xcode is signed in." >&2 ;;
esac
if [ -f "$VERIFY_DIR/Payload/iPrompter.app/PrivacyInfo.xcprivacy" ]; then
  echo "    privacy manifest: present in .ipa"
else
  echo "    privacy manifest: MISSING from .ipa — expect ITMS-91053" >&2
fi
rm -rf "$VERIFY_DIR"

echo
echo "==> Done: $(du -h "$IPA" | cut -f1)  $IPA"
echo
echo "To upload, pick ONE — both authenticate as you, which is why this script"
echo "stops here rather than handling your credentials:"
echo
echo "  Xcode:       Window > Organizer > select the archive > Distribute App"
echo "  Transporter: install from the Mac App Store, drag in the .ipa"
echo "  CLI, with an App Store Connect API key you created yourself:"
echo "      xcrun altool --upload-app -f \"$IPA\" -t ios \\"
echo "        --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo
echo "The build must then be attached to a version in App Store Connect and"
echo "submitted for review from there."
