#!/bin/bash
# setup.sh — one-shot bootstrap for Galactic Chess Invaders.
# Run from the GCI/ root after cloning:
#   bash setup.sh
#
# What it does:
#   1. Checks for required tools (xcodegen, Xcode)
#   2. Downloads Press Start 2P font (OFL license)
#   3. Generates GalacticChessInvaders.xcodeproj via xcodegen
#   4. Converts audio sources to .caf if originals are present
#   5. Prints next steps

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

step()  { echo -e "\n${CYAN}▶ $1${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()  { echo -e "${RED}  ✗ $1${NC}"; }

echo -e "${CYAN}"
echo "  ┌─────────────────────────────────────────┐"
echo "  │   GALACTIC CHESS INVADERS — Setup       │"
echo "  │   40 years in the making.               │"
echo "  └─────────────────────────────────────────┘"
echo -e "${NC}"

# ── 1. Verify we're in the right directory ───────────────────────────────────
if [[ ! -f "project.yml" ]] || [[ ! -f "CLAUDE.md" ]]; then
    fail "Run this script from the GCI/ project root (where project.yml lives)."
    exit 1
fi
ok "Project root confirmed"

# ── 2. Check for Xcode ───────────────────────────────────────────────────────
step "Checking dependencies"
if ! xcode-select -p &>/dev/null; then
    fail "Xcode Command Line Tools not found. Install with: xcode-select --install"
    exit 1
fi
ok "Xcode CLT: $(xcode-select -p)"

# ── 3. Check / install xcodegen ──────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    warn "xcodegen not found — attempting install via Homebrew"
    if command -v brew &>/dev/null; then
        brew install xcodegen
        ok "xcodegen installed"
    else
        fail "Homebrew not found either. Install xcodegen manually:"
        fail "  brew install xcodegen   OR   mint install yonaskolb/XcodeGen"
        exit 1
    fi
else
    ok "xcodegen: $(xcodegen --version 2>/dev/null || echo 'found')"
fi

# ── 4. Download Press Start 2P font ──────────────────────────────────────────
step "Fetching Press Start 2P font (OFL license, ~50 KB)"
FONT_DEST="assets/PressStart2P-Regular.ttf"
FONT_URL="https://github.com/google/fonts/raw/main/ofl/pressstart2p/PressStart2P-Regular.ttf"
if [[ -f "$FONT_DEST" ]]; then
    ok "Font already present: $FONT_DEST"
else
    if curl -fsSL -o "$FONT_DEST" "$FONT_URL"; then
        ok "Font downloaded: $FONT_DEST ($(du -h "$FONT_DEST" | cut -f1))"
    else
        warn "Font download failed — the app will use system monospace as fallback."
        warn "Download manually from https://fonts.google.com/specimen/Press+Start+2P"
        warn "and place PressStart2P-Regular.ttf in assets/"
    fi
fi

# ── 5. Convert audio if source files are present ─────────────────────────────
step "Audio"
CAF_DIR="assets/sfx"
CONVERT_SCRIPT="$CAF_DIR/convert_to_caf.sh"
if [[ -d "$CAF_DIR" ]] && [[ -f "$CONVERT_SCRIPT" ]]; then
    # Only convert if there are .ogg or .wav files that don't yet have .caf pairs
    NEED_CONVERT=$(find "$CAF_DIR" \( -name "*.ogg" -o -name "*.wav" \) 2>/dev/null | head -1)
    if [[ -n "$NEED_CONVERT" ]]; then
        warn "Audio source files found — converting to .caf (lowest-latency on macOS)"
        bash "$CONVERT_SCRIPT" && ok "Audio conversion done" || warn "Conversion had errors; check $CONVERT_SCRIPT"
    else
        ok "Audio: .caf files already present (no conversion needed)"
    fi
else
    ok "Audio: sfx directory excluded from repo (gitignored) — add .caf files to assets/sfx/ when ready"
fi

# ── 6. Generate Xcode project ─────────────────────────────────────────────────
step "Generating GalacticChessInvaders.xcodeproj"
xcodegen generate
ok "Xcode project generated"

# ── 7. Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete. Next steps:${NC}"
echo ""
echo -e "  1. Open the project in Xcode:"
echo -e "     ${CYAN}open GalacticChessInvaders.xcodeproj${NC}"
echo ""
echo -e "  2. Xcode will resolve the ChessKit SPM package automatically."
echo -e "     If it doesn't: File → Packages → Resolve Package Versions"
echo ""
echo -e "  3. Press ⌘R to build and run. You should see:"
echo -e "     • Black void with twinkling starfield"
echo -e "     • Title screen: GALACTIC CHESS INVADERS"
echo -e "     • Diagnostics sidebar on the right (debug builds)"
echo -e "     • 60fps confirmed in the FPS counter"
echo ""
echo -e "  4. Press any key → placeholder board. L → toggle sidebar."
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
