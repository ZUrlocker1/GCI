#!/bin/bash
# install_font.sh — downloads Press Start 2P and wires it into the project.
# Run once from the GCI/ root:  bash assets/install_font.sh

set -e
FONT_URL="https://github.com/google/fonts/raw/main/ofl/pressstart2p/PressStart2P-Regular.ttf"
# Resources, not assets: the app target bundles GalacticChessInvaders/, and a
# font downloaded into assets/ would never reach the app.
DEST="GalacticChessInvaders/Resources/PressStart2P-Regular.ttf"

echo "Downloading Press Start 2P (OFL license)..."
curl -L -o "$DEST" "$FONT_URL"
echo "Saved to $DEST ($(du -h "$DEST" | cut -f1))"

echo "Regenerating Xcode project to include font in bundle..."
if command -v xcodegen &>/dev/null; then
    xcodegen generate
    echo "Done — open GalacticChessInvaders.xcodeproj in Xcode and build."
else
    echo "xcodegen not found — drag $DEST into Xcode manually (target membership checked)."
fi
