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

    /// The design canvas as a layout, used as the starting value and by tests
    /// that assert the shipped composition.
    static let design = SceneLayout(size: designSize)

    /// The layout the playfield was last built at.
    ///
    /// A handful of call sites outside the scene — the power-up alley, the
    /// raider lane — need the geometry without holding a scene. They used to
    /// read `static let` constants on `GameScene`; routing those through
    /// `GameScene.shared` instead would have made reading a number construct
    /// the entire game, which is how the first attempt at this crashed a test.
    /// Main-actor isolated because it is shared mutable state and Swift 6 is
    /// right to insist. Everything that reads it is rendering, which is already
    /// on the main actor.
    @MainActor private(set) static var current: SceneLayout = .design

    /// Called from `buildPlayfield` before any node measures itself.
    @MainActor static func adopt(_ layout: SceneLayout) {
        current = layout
        BoardNode.adopt(layout)
    }

    let size: CGSize

    /// The smallest size the layout will reason about.
    ///
    /// Under `.resizeFill` a scene can be handed a zero size before its view has
    /// been laid out — a path that simply did not exist while the canvas was a
    /// fixed 960×700. Clamping here means no consumer ever sees a zero or
    /// negative dimension, rather than each of them guarding separately.
    static let minimumSize = CGSize(width: 480, height: 360)

    init(size: CGSize = SceneLayout.designSize) {
        self.size = CGSize(width: max(size.width, Self.minimumSize.width),
                           height: max(size.height, Self.minimumSize.height))
    }

    // MARK: - Bands
    //
    // The scene is three horizontal bands: a HUD strip along the top, the ship's
    // lane along the bottom, and the board between them. The two chrome bands
    // are fixed in points on purpose — they hold type and the ship, and neither
    // should shrink because a window got shorter. Only the board flexes.

    /// 700 − 632, the gap above the board on the design canvas.
    var hudBandHeight: CGFloat { 68 }
    /// The design `boardBottomY`: everything below the board.
    var shipBandHeight: CGFloat { 120 }
    /// What the left gutter needs for the widest thing it carries.
    var minGutterWidth: CGFloat { 224 }

    /// Never smaller than this, whatever the window does. Below it the pieces
    /// stop being readable and the game stops being playable.
    static let minSquareSize: CGFloat = 32

    // MARK: - Board

    /// The side of one square, and the root of the whole coordinate system:
    /// the board is eight of these, piece art is fitted to it, and the fleet
    /// sweeps in multiples of it.
    ///
    /// Whole points, deliberately. A grid line drawn at 63.4pt spacing aliases
    /// into a dashed mess; the remainder is given back to the gutters by the
    /// centring below, where nobody can see it.
    var squareSize: CGFloat {
        let fromHeight = (size.height - hudBandHeight - shipBandHeight) / 8
        let fromWidth  = (size.width - 2 * minGutterWidth) / 8
        return max(Self.minSquareSize, floor(min(fromHeight, fromWidth)))
    }

    var boardSize: CGFloat { squareSize * 8 }

    /// Centred in whatever vertical space the two chrome bands leave.
    var boardBottomY: CGFloat {
        let available = size.height - hudBandHeight - shipBandHeight
        return shipBandHeight + max(0, (available - boardSize) / 2)
    }
    var boardOriginX: CGFloat { (size.width - boardSize) / 2 }
    var boardOrigin: CGPoint { CGPoint(x: boardOriginX, y: boardBottomY) }
    var boardTopY: CGFloat { boardBottomY + boardSize }

    // MARK: - Ship lane

    /// Just below the board, so the ship stays with it rather than pinned to
    /// the window's bottom edge as the board moves.
    var shipLaneY: CGFloat { boardBottomY - 58 }
    /// How close to the wall the ship may get.
    var shipMargin: CGFloat { 30 }

    // MARK: - Left gutter
    //
    // The column left of the board carrying the turn clock, the check banner,
    // the power-up alley and the Chess and Arcade Hints. In portrait on a phone
    // there is no room for it at all — see docs/IOS-Port.md §5.

    /// The middle of the space left of the board, so the column follows the
    /// board rather than sitting at a fixed x and colliding with it.
    var gutterCentreX: CGFloat { boardOriginX / 2 }

    /// Everything from the turn timer down sits this much lower than it used
    /// to, to open a gap between the chess readouts and the power-up block
    /// above them. One constant rather than four edited literals, because the
    /// four move together or the timer's digits land on the transient notice.
    var gutterDrop: CGFloat { 8 }

    var turnTimerY: CGFloat { boardBottomY + 46 - gutterDrop }
    var gutterNoticeY: CGFloat { boardBottomY + 30 - gutterDrop }
    var statusBannerY: CGFloat { boardBottomY - 4 - gutterDrop }

    /// Chess Hints sit above everything else in the gutter, clearing a full
    /// power-up stack.
    var chessHintY: CGFloat { boardBottomY + 172 }

    // MARK: - Power-up alley

    var powerUpAlleyLines: Int { 3 }
    /// The block stacks *upward* from this floor, so the first line the player
    /// earns stays where they last read it and later ones go above it.
    var powerUpAlleyBottomY: CGFloat { boardBottomY + 76 }
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
