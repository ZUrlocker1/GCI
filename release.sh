#!/usr/bin/env bash
# release.sh — Build, sign, notarize and package Galactic Chess Invaders as a
# drag-to-install DMG. Modelled on Zudio's release.sh, same team and same route.
#
# Usage:
#   ./release.sh
#
# One-time prerequisites:
#   - A "Developer ID Application" certificate in your keychain
#     (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID
#      Application; needs the Account Holder role)
#   - An app-specific password stored for notarytool:
#       xcrun notarytool store-credentials "AC_PASSWORD" \
#         --apple-id YOUR_APPLE_ID --team-id K66MA9TR8Z --password THE_APP_PASSWORD
#     (create the password at appleid.apple.com → App-Specific Passwords)
#   - brew install create-dmg
#
# Why this route rather than App Store Connect: notarized Developer ID is what
# Zudio ships, it needs no review, and Ben can download and run it. TestFlight
# would mean App Store distribution certificates and a review pass for external
# testers — a lot of process to get a build to one friend.

set -euo pipefail

SCHEME="GalacticChessInvaders"
APP_NAME="GalacticChessInvaders.app"
TEAM_ID="K66MA9TR8Z"
SIGNING_IDENTITY="Developer ID Application: Zack Urlocker (${TEAM_ID})"
NOTARYTOOL_PROFILE="AC_PASSWORD"
ENTITLEMENTS="$(pwd)/GalacticChessInvaders.entitlements"

# Read the version from the project rather than repeating it here, so the DMG
# name can never disagree with the About box.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    GalacticChessInvaders/Info.plist)

DERIVED_DATA_PATH="/tmp/GCIBuild"
BUILD_DIR="${DERIVED_DATA_PATH}/Build/Products/Release"
APP_SRC="${BUILD_DIR}/${APP_NAME}"

DMG_DIR="/tmp/GCIDMG"
DMG_STAGING="${DMG_DIR}/staging"
DMG_BACKGROUND="${DMG_DIR}/background.png"
OUTPUT_DMG="${HOME}/Downloads/GalacticChessInvaders-${VERSION}.dmg"

echo ""
echo "==> [1/6] Building universal binary (Release, arm64 + x86_64)..."
xcodebuild \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination "platform=macOS" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    clean build

echo ""
echo "==> [2/6] Signing with Developer ID..."
codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${SIGNING_IDENTITY}" \
    "${APP_SRC}"
codesign --verify --deep --strict "${APP_SRC}"
echo "    Signature verified OK."

echo ""
echo "==> [3/6] Submitting for notarization (1-5 minutes)..."
NOTARIZE_ZIP="/tmp/GCI-notarize.zip"
ditto -c -k --keepParent "${APP_SRC}" "${NOTARIZE_ZIP}"
xcrun notarytool submit "${NOTARIZE_ZIP}" \
    --keychain-profile "${NOTARYTOOL_PROFILE}" \
    --wait
rm -f "${NOTARIZE_ZIP}"
echo "    Notarization approved."

echo ""
echo "==> [4/6] Stapling the ticket..."
xcrun stapler staple "${APP_SRC}"
xcrun stapler validate "${APP_SRC}"
echo "    Staple verified OK."

echo ""
echo "==> [5/6] Building the DMG..."
if ! command -v create-dmg &>/dev/null; then
    echo "ERROR: create-dmg not found. Install it with: brew install create-dmg"
    exit 1
fi

rm -rf "${DMG_DIR}"
mkdir -p "${DMG_STAGING}"

# A black background with a cyan chevron, so the installer window looks like the
# game rather than like a generic disk image.
DMG_BACKGROUND="${DMG_BACKGROUND}" python3 - <<'PYEOF'
import os, struct, zlib
W, H = 560, 340
rows = []
for y in range(H):
    row = []
    for x in range(W):
        dx, dy = x - 280, y - H // 2
        on_arrow = (
            (abs(dy + dx * 0.7) < 5 and 0 <= dx <= 28 and dy <= 0) or
            (abs(dy - dx * 0.7) < 5 and 0 <= dx <= 28 and dy >= 0)
        )
        row.extend([18, 224, 255] if on_arrow else [8, 9, 14])
    rows.append(row)

def chunk(tag, data):
    return (struct.pack('>I', len(data)) + tag + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

raw = b''.join(b'\x00' + bytes(r) for r in rows)
with open(os.environ['DMG_BACKGROUND'], 'wb') as f:
    f.write(b'\x89PNG\r\n\x1a\n')
    f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)))
    f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
    f.write(chunk(b'IEND', b''))
PYEOF

cp -R "${APP_SRC}" "${DMG_STAGING}/${APP_NAME}"
rm -f "${OUTPUT_DMG}"
create-dmg \
    --volname "Galactic Chess Invaders ${VERSION}" \
    --background "${DMG_BACKGROUND}" \
    --window-pos 200 120 \
    --window-size 560 340 \
    --icon-size 100 \
    --icon "${APP_NAME}" 130 160 \
    --app-drop-link 430 160 \
    --hide-extension "${APP_NAME}" \
    --no-internet-enable \
    "${OUTPUT_DMG}" \
    "${DMG_STAGING}/"

echo ""
echo "==> [6/6] Signing the DMG..."
codesign --force --sign "${SIGNING_IDENTITY}" "${OUTPUT_DMG}"
codesign --verify "${OUTPUT_DMG}"

echo ""
echo "============================================================"
echo " Build complete!"
echo " Output: ${OUTPUT_DMG}"
echo ""
echo " Verify before sending it to anyone:"
echo "   1. Open the DMG, drag the app to Applications, launch it"
echo "   2. Play a level — the sandbox is on for the first time, so"
echo "      confirm sound, sprites and the high score table all work"
echo "   3. spctl --assess --type exec -vv '/Applications/${APP_NAME}'"
echo "      should say: accepted, source=Notarized Developer ID"
echo "============================================================"
echo ""
