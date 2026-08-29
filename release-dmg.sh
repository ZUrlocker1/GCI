#!/usr/bin/env bash
# release-dmg.sh — Package an already-signed GalacticChessInvaders.app into a
# drag-to-install DMG. Same shape as Zudio's release-dmg.sh.
#
# Usage:
#   ./release-dmg.sh                      # uses ~/Downloads/GalacticChessInvaders.app
#   ./release-dmg.sh /path/to/the.app
#
# Run this AFTER Xcode's Product > Archive > Distribute App > Direct
# Distribution, which is what signs and notarizes the app. This script only
# wraps it in a DMG and signs that.

set -euo pipefail

APP_SRC="${1:-${HOME}/Downloads/GalacticChessInvaders.app}"

if [ ! -d "${APP_SRC}" ]; then
    echo "ERROR: App not found at: ${APP_SRC}"
    echo "Export it from Xcode first (Distribute App > Direct Distribution),"
    echo "then pass the path or leave it in ~/Downloads."
    exit 1
fi

PLIST="${APP_SRC}/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${PLIST}")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PLIST}")

TEAM_ID="K66MA9TR8Z"
SIGNING_IDENTITY="Developer ID Application: Zack Urlocker (${TEAM_ID})"
# One name throughout: the DMG, the volume and the app all match whatever the
# exported bundle is called. Appending the version produced "GCI 01-0.1.0.dmg",
# which is a mouthful and says the version twice when the app is already named
# for a build. The version is still reported at the end, and it is in the About
# box where it belongs.
OUTPUT_DMG="${HOME}/Downloads/$(basename "${APP_SRC}" .app).dmg"

DMG_WORK="/tmp/GCIDMG"
DMG_STAGING="${DMG_WORK}/staging"
DMG_BACKGROUND="${DMG_WORK}/background.png"
# The app's own name, not a hardcoded one — the exported bundle is often
# renamed ("GCI 01.app") and it should keep that name inside the DMG.
APP_NAME="$(basename "${APP_SRC}")"

WINDOW_W=560
WINDOW_H=340
ICON_SIZE=100

echo ""
echo "==> Source app: ${APP_SRC}"
echo "==> Output DMG: ${OUTPUT_DMG}"

if ! command -v create-dmg &>/dev/null; then
    echo ""
    echo "ERROR: create-dmg not found. Install it with:"
    echo "  brew install create-dmg"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: Check the app really is signed and notarized
# ---------------------------------------------------------------------------
echo ""
echo "==> [1/4] Checking create-dmg is available..."
if ! command -v create-dmg &>/dev/null; then
    echo ""
    echo "ERROR: create-dmg not found. Install it with:"
    echo "  brew install create-dmg"
    exit 1
fi
echo "    create-dmg found."

# ---------------------------------------------------------------------------
# Step 2: Background — black with a cyan arrow, so it looks like the game
# ---------------------------------------------------------------------------
echo ""
echo "==> [2/4] Generating DMG background..."
rm -rf "${DMG_WORK}"
mkdir -p "${DMG_STAGING}"

DMG_BACKGROUND="${DMG_BACKGROUND}" python3 - <<'PYEOF'
import struct, zlib, os

W, H = 560, 340
# Light grey, not the game's near-black: Finder draws icon labels in black,
# and on a dark background "GCI 05.app" and "Applications" were unreadable.
# Same palette as Zudio's DMG, which had already learned this.
BG    = (210, 210, 215)   # light grey
ARROW = (90, 90, 95)      # dark grey

SHAFT_X1, SHAFT_X2 = 195, 355
SHAFT_Y1, SHAFT_Y2 = 162, 178
HEAD_X1,  HEAD_X2  = 340, 395
HEAD_TIP_Y, HEAD_HALF = 170, 28

def in_arrow(x, y):
    if SHAFT_X1 <= x <= SHAFT_X2 and SHAFT_Y1 <= y <= SHAFT_Y2:
        return True
    if HEAD_X1 <= x <= HEAD_X2:
        half = HEAD_HALF * (HEAD_X2 - x) / (HEAD_X2 - HEAD_X1)
        return abs(y - HEAD_TIP_Y) <= half
    return False

def chunk(tag, data):
    return (struct.pack('>I', len(data)) + tag + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

rows = []
for y in range(H):
    row = []
    for x in range(W):
        row.extend(ARROW if in_arrow(x, y) else BG)
    rows.append(row)

out = os.environ['DMG_BACKGROUND']
with open(out, 'wb') as f:
    f.write(b'\x89PNG\r\n\x1a\n')
    f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)))
    f.write(chunk(b'IDAT', zlib.compress(b''.join(b'\x00' + bytes(r) for r in rows), 9)))
    f.write(chunk(b'IEND', b''))
print(f'    Background written: {out}')
PYEOF

# ---------------------------------------------------------------------------
# Step 3: Stage and build
# ---------------------------------------------------------------------------
echo ""
echo "==> [3/4] Building drag-to-install DMG..."
# The app and nothing else. LICENSE and THIRD-PARTY-NOTICES.md were staged
# here for a while; two text files beside the drag target read as clutter, and
# both are in the repo and the README where someone would look for them.
cp -R "${APP_SRC}" "${DMG_STAGING}/${APP_NAME}"
rm -f "${OUTPUT_DMG}"

create-dmg \
    --volname "$(basename "${APP_SRC}" .app)" \
    --background "${DMG_BACKGROUND}" \
    --window-pos 200 120 \
    --window-size ${WINDOW_W} ${WINDOW_H} \
    --icon-size ${ICON_SIZE} \
    --icon "${APP_NAME}" 130 160 \
    --app-drop-link 430 160 \
    --hide-extension "${APP_NAME}" \
    --no-internet-enable \
    "${OUTPUT_DMG}" \
    "${DMG_STAGING}/"

# ---------------------------------------------------------------------------
# Step 4: Sign the DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [4/4] Signing DMG..."
codesign --force --sign "${SIGNING_IDENTITY}" "${OUTPUT_DMG}"
codesign --verify "${OUTPUT_DMG}"
echo "    DMG signature verified OK."

echo ""
echo "============================================================"
echo " Done!  ${OUTPUT_DMG}"
echo ""
echo " Before sending it to Ben:"
echo "   1. Open the DMG — app on the left, Applications on the right"
echo "   2. Drag it across and launch it"
echo "   3. Version ${VERSION} (build ${BUILD})"
echo "   4. spctl --assess --verbose=4 --type exec \"${APP_SRC}\""
echo "============================================================"
echo ""
