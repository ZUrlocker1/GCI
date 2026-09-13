// SceneLayout.swift
// Every position in the playfield, in one place.
//
// Stage 1 of the layout work in docs/IOS-Port.md §3. This deliberately returns
// exactly the numbers that used to be literals in GameScene, BoardNode and
// RaiderController, so the game is pixel-identical and the change is verifiable
// by screenshot. Nothing here depends on `size` yet except the board's own
// centring, which already did.
//
// Stage 2 makes these depend on the size the scene actually has, which is what
// lets the game fill an iPad, a phone in landscape, and a phone in portrait
// rather than being letterboxed into whatever is left of a 960×700 canvas.
// When that happens, this is the only file whose arithmetic changes.

import CoreGraphics

struct SceneLayout {

    /// The canvas the macOS game was composed against, and still runs at.
    static let designSize = CGSize(width: 960, height: 700)

    /// The layout the Mac ships with. Stage 2 replaces most uses of this with
    /// a layout built from the live scene size.
    static let design = SceneLayout(size: designSize)

    let size: CGSize

    init(size: CGSize = SceneLayout.designSize) {
        self.size = size
    }

    // MARK: - Board

    /// The side of one square, and the root of the whole coordinate system:
    /// the board is eight of these, piece art is fitted to it, and the fleet
    /// sweeps in multiples of it.
    var squareSize: CGFloat { 64 }
    var boardSize: CGFloat { squareSize * 8 }

    /// The board sits above the ship lane and below the HUD.
    var boardBottomY: CGFloat { 120 }
    /// Centred horizontally — this was already computed rather than a literal.
    var boardOriginX: CGFloat { (size.width - boardSize) / 2 }
    var boardOrigin: CGPoint { CGPoint(x: boardOriginX, y: boardBottomY) }
    var boardTopY: CGFloat { boardBottomY + boardSize }

    // MARK: - Ship lane

    var shipLaneY: CGFloat { 62 }
    /// How close to the wall the ship may get.
    var shipMargin: CGFloat { 30 }

    // MARK: - Left gutter
    //
    // The column left of the board carrying the turn clock, the check banner,
    // the power-up alley and the Chess and Arcade Hints. In portrait on a phone
    // there is no room for it at all — see docs/IOS-Port.md §5.

    var gutterCentreX: CGFloat { 112 }

    /// Everything from the turn timer down sits this much lower than it used
    /// to, to open a gap between the chess readouts and the power-up block
    /// above them. One constant rather than four edited literals, because the
    /// four move together or the timer's digits land on the transient notice.
    var gutterDrop: CGFloat { 8 }

    var turnTimerY: CGFloat { boardBottomY + 46 - gutterDrop }
    var gutterNoticeY: CGFloat { boardBottomY + 30 - gutterDrop }
    var statusBannerY: CGFloat { boardBottomY - 4 - gutterDrop }

    /// Chess Hints sit above everything else in the gutter. The power-up alley
    /// stacks upward from `powerUpAlleyBottomY` and tops out near 252 with
    /// every effect running, so this clears a full stack.
    var chessHintY: CGFloat { 292 }

    // MARK: - Power-up alley

    var powerUpAlleyLines: Int { 3 }
    /// The block stacks *upward* from this floor, so the first line the player
    /// earns stays where they last read it and later ones go above it.
    var powerUpAlleyBottomY: CGFloat { 196 }
    var powerUpAlleyStep: CGFloat { 14 }      // 9pt of type, 5pt of air
    var powerUpAlleyFontSize: CGFloat { 9 }
    var powerUpBarWidth: CGFloat { 84 }
    /// Under the bottom line, which is always the timed effect — it is appended
    /// last and the block grows upward, so the bar never moves.
    var powerUpBarY: CGFloat { powerUpAlleyBottomY - 7 }

    // MARK: - Raiders

    /// Raiders cross at mid-board height (§6), between ranks 4 and 5.
    var raiderLaneY: CGFloat { boardBottomY + boardSize / 2 }
}
