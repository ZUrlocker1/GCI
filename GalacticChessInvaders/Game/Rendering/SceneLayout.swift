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

    /// How large everything on the playfield is drawn, relative to the canvas
    /// it was composed against.
    ///
    /// Read directly by the things that are pooled for the life of the scene —
    /// rounds, raiders, score pops, explosions — rather than pushed to them by
    /// `adopt`. They all re-derive their size each time they are put into play,
    /// so reading it at that moment resizes the whole pool without anything
    /// having to walk it, and there is no copy of the number to go stale.
    @MainActor static var contentScale: CGFloat { current.contentScale }

    let size: CGSize

    /// The side of one square, and the root of the whole coordinate system:
    /// the board is eight of these, piece art is fitted to it, and the fleet
    /// sweeps in multiples of it.
    ///
    /// Whole points, deliberately. A grid line drawn at 63.4pt spacing aliases
    /// into a dashed mess; the remainder is given back to the gutters by the
    /// centring, where nobody can see it.
    ///
    /// Capped, but not at the design square. Letting the board grow without
    /// limit was tried and looked wrong — at 1900pt wide the squares came out
    /// at 176pt and the pieces were enormous, because the chrome around them
    /// stays a fixed size. Capping at the design 64 went too far the other
    /// way: a laptop in full screen left most of the window black. 96 is one
    /// and a half times the design square, which fills a full-screen laptop
    /// without the chrome looking miniature beside it.
    ///
    /// Stored, and computed once in `init`, because everything else here
    /// derives from it — `boardSize`, `boardOriginX`, `contentScale`, every
    /// gutter position. As a computed property the fit arithmetic ran several
    /// times over for a single reading of `boardCentre`, and `applyLayout`
    /// reads a dozen of these in a row.
    let squareSize: CGFloat

    /// The smallest size the layout will reason about.
    ///
    /// Under `.resizeFill` a scene can be handed a zero size before its view has
    /// been laid out — a path that simply did not exist while the canvas was a
    /// fixed 960×700. Clamping here means no consumer ever sees a zero or
    /// negative dimension, rather than each of them guarding separately.
    /// 480 until 1.4, which silently widened every iPhone in portrait: a 393pt
    /// scene was clamped to 480, so the board was sized for a screen 87pt wider
    /// than the one it was drawn on and ran off the right edge. Nothing enforced
    /// 480 — the Mac's own minimum window is 640 — so it was only ever a guard
    /// against a zero size, and 320 is the narrowest iPhone Apple has shipped.
    static let minimumSize = CGSize(width: 320, height: 360)

    init(size: CGSize = SceneLayout.designSize) {
        let clamped = CGSize(width: max(size.width, Self.minimumSize.width),
                             height: max(size.height, Self.minimumSize.height))
        self.size = clamped
        let bands = Self.bands(forHeight: clamped.height)
        let hidden = Self.hidesReadouts(width: clamped.width, height: clamped.height)
        let stacked = Self.usesStackedReadouts(width: clamped.width) && !hidden
        // Either way the column is not beside the board, so the board has the
        // width; only a stacked column costs height.
        let fullWidth = stacked || hidden
        let bottom = bands.ship + (stacked ? Self.stackedReadoutBandHeight : 0)
        let fromHeight = (clamped.height - bands.hud - bottom) / 8

        // Width is the binding constraint on every iPad in portrait, and the
        // gutter's share of it depends on the scale its type is drawn at —
        // which depends on the square. Two regimes, because that scale stops
        // shrinking at `minGutterScale`:
        //
        //   scaling — every point of square costs 8pt of board plus
        //             `gutterContentWidth / designSquareSize` of gutter;
        //   floored — the type is at its floor, so the gutter is a constant
        //             and the board takes whatever is left.
        //
        // Solve the scaling case and use it if it lands above the floor;
        // otherwise the floored one applies, capped at where the floor begins.
        let gutterCostPerPoint = Self.gutterContentWidth / Self.designSquareSize
        let ifScaling = (clamped.width - Self.gutterAir - Self.rightMarginWidth)
            / (8 + gutterCostPerPoint)
        let ifFloored = (clamped.width - Self.gutterWidth(atScale: Self.minGutterScale)
            - Self.rightMarginWidth) / 8
        let flooredCeiling = Self.minGutterScale * Self.designSquareSize
        // Stacked: the board owns the width, less a margin each side.
        let fromWidth = fullWidth
            ? (clamped.width - Self.stackedSideMargin * 2) / 8
            : (ifScaling >= flooredCeiling ? ifScaling : min(ifFloored, flooredCeiling))

        let fitted = floor(min(fromHeight, fromWidth))
        self.squareSize = min(Self.maxSquareSize, max(Self.minSquareSize, fitted))
    }

    // MARK: - Bands
    //
    // The scene is three horizontal bands: a HUD strip along the top, the ship's
    // lane along the bottom, and the board between them. The bands held their
    // design size at every height until 1.4, on the grounds that they carry type
    // and the ship and should not shrink because a window got shorter.
    //
    // A phone in landscape broke that. The board needs 256pt at the 32pt square
    // floor, and 68 + 120 of chrome on top of it comes to 444 — against an
    // iPhone 15's 393pt and a 17 Pro Max's 440. Every landscape phone failed on
    // height while having width to spare, and the Pro Max failed by four points.
    //
    // So the bands give way before the board does, but only once there is no
    // alternative: full size above 500pt of height, which is the Mac's own
    // minimum window and below every iPad, so nothing that shipped moves.

    /// 700 − 632, the gap above the board on the design canvas.
    static let hudBandHeight: CGFloat = 68
    /// The design `boardBottomY`: everything below the board.
    static let shipBandHeight: CGFloat = 120

    /// What the bands shrink to when a screen cannot hold them.
    ///
    /// 44 still clears the 36pt HUD bar. 70 is the contentious one: §4 wants the
    /// ship's band generous on a phone *because* it is the drag region, and this
    /// halves the thumb's working area on the device with least of it. It is the
    /// first thing to judge on hardware rather than on paper.
    static let compactHudBandHeight: CGFloat = 44
    static let compactShipBandHeight: CGFloat = 70

    /// Above this the bands are untouched; below `compactBandsBelow` they are
    /// fully compact; between, they ramp.
    static let fullBandsAbove: CGFloat = 500
    static let compactBandsBelow: CGFloat = 400

    /// Ramped rather than switched, because the alternative is a step: at a
    /// threshold the board would jump *larger* as the screen got one point
    /// shorter. A Mac window drag and a Duo hinge both cross this continuously.
    static func bands(forHeight height: CGFloat) -> (hud: CGFloat, ship: CGFloat) {
        let span = fullBandsAbove - compactBandsBelow
        let t = min(1, max(0, (fullBandsAbove - height) / span))
        return (hud: hudBandHeight - (hudBandHeight - compactHudBandHeight) * t,
                ship: shipBandHeight - (shipBandHeight - compactShipBandHeight) * t)
    }

    var hudBandHeight: CGFloat { Self.bands(forHeight: size.height).hud }
    var shipBandHeight: CGFloat { Self.bands(forHeight: size.height).ship }
    /// What the left gutter needs for the widest thing it carries, **at the
    /// largest square the game allows**. Kept as the headline number because
    /// that is the case the gutter was designed against.
    static let minGutterWidth: CGFloat = 224
    /// What it needs *here*, which is less whenever the type is smaller.
    ///
    /// The widest thing in the gutter is about 130pt of monospace at scale 1
    /// — "FRIENDLY FIRE!" at 9pt, "OR KNIGHT" at 13 — and it is centred, so
    /// the gutter holds that plus air for the rank labels. At `gutterScale`
    /// 1.5, the scale a 96pt square gives, that comes to 223: the 224 above,
    /// which is where the number came from.
    ///
    /// Reserving 224 at *every* scale is what left a band of dead space down
    /// the left in portrait, where the square is small and the scale sits on
    /// its 0.9 floor — 145 is enough there, and the other 79 goes to the
    /// board. Nothing moves: the gutter keeps its position and its contents,
    /// it is simply not over-reserved.
    var minGutterWidth: CGFloat { Self.gutterWidth(atScale: gutterScale) }

    static let gutterContentWidth: CGFloat = 130
    static let gutterAir: CGFloat = 28

    static func gutterWidth(atScale scale: CGFloat) -> CGFloat {
        gutterContentWidth * scale + gutterAir
    }

    // MARK: - Stacked readouts, for a screen too narrow to carry a gutter
    //
    // A phone in portrait cannot hold the composition at all: the smallest
    // gutter is 145, the smallest board 256 and the right margin 96, which wants
    // 497pt against an iPhone 15's 393. Nothing survives trimming — every
    // variant buys the fit by shrinking the square below the 44pt touch floor,
    // and GCI punishes a mis-tap specifically, because the five-second clock
    // expires and the engine moves for you.
    //
    // So on those screens the readouts come out from beside the board and go
    // underneath it, below the ship, and the board takes the full width. An
    // iPhone 15 goes from a 32pt square that does not fit to a 47pt one that
    // does.
    //
    // The column itself is unchanged. Its four items already sit between −4 and
    // +172 of a single anchor, so this moves the anchor rather than relaying out
    // the contents — see `readoutAnchorY`.

    /// What the stacked column needs, at the 0.9 gutter floor: the −4…+172
    /// spread scaled, plus air top and bottom.
    static let stackedReadoutBandHeight: CGFloat = 170
    /// How close to the wall the ship may get. Shared with `shipMargin`, since
    /// the board's inset below is derived from it.
    static let shipWallMargin: CGFloat = 30

    /// How far past each board edge the ship must still be able to sit.
    ///
    /// **This is a gameplay rule, not spacing.** The ship fires straight up, and
    /// White's own pawns stand on every file. If the ship cannot leave the
    /// board's columns there is nowhere it can shoot from without one of its own
    /// pieces in the way — the fleet sweeps out past the files and the player
    /// cannot follow it. A full-width board trapped the ship 21pt inside its own
    /// edges, which Zack caught on a phone.
    static let stackedShipClearance: CGFloat = 14

    /// Air either side of the board once the readouts have been stacked. Wide
    /// enough that the ship's centre clears the outermost file.
    static let stackedSideMargin: CGFloat = shipWallMargin + stackedShipClearance

    /// True where the gutter cannot fit beside the board at any square size.
    ///
    /// Width alone decides it, so it is answerable before `squareSize` exists.
    /// 497 is the floor: 145 of gutter, 256 of board, 96 of right margin.
    static func usesStackedReadouts(width: CGFloat) -> Bool {
        width < gutterWidth(atScale: minGutterScale) + minSquareSize * 8 + rightMarginWidth
    }

    /// The height a stacked column needs before it can be afforded: the two
    /// bands, the column's own band, and a board at its minimum square.
    ///
    /// 614 on the full bands. Every phone in portrait clears it comfortably —
    /// the shortest is an SE at 667 — and the only thing that does not is a Mac
    /// window, whose minimum is 500.
    static var stackedReadoutsNeedHeight: CGFloat {
        let bands = Self.bands(forHeight: fullBandsAbove)
        return bands.hud + bands.ship + stackedReadoutBandHeight + minSquareSize * 8
    }

    /// Too narrow for a gutter beside the board *and* too short to put one
    /// under it — so there is no column at all and the board takes the scene.
    ///
    /// Reachable on a Mac and nowhere else: it needs a window under 497 wide,
    /// which only happens with the log sidebar open, and under 614 tall, which
    /// is near the 500 minimum. Zack's call, and the right one — stacking there
    /// drove the board 82pt up under the HUD bar, and the log panel beside it
    /// is already showing everything the column would have said.
    static func hidesReadouts(width: CGFloat, height: CGFloat) -> Bool {
        usesStackedReadouts(width: width) && height < stackedReadoutsNeedHeight
    }

    var hidesReadouts: Bool { Self.hidesReadouts(width: size.width, height: size.height) }

    /// Stacked only where the column is both needed and affordable.
    var usesStackedReadouts: Bool {
        Self.usesStackedReadouts(width: size.width) && !hidesReadouts
    }

    /// True wherever the column is not beside the board — stacked under it, or
    /// gone — because in both cases the board has the whole width.
    var boardTakesFullWidth: Bool { usesStackedReadouts || hidesReadouts }

    /// Everything below the board: the ship's lane, plus the readout column on a
    /// screen that has had to stack it.
    var bottomChrome: CGFloat {
        shipBandHeight + (usesStackedReadouts ? Self.stackedReadoutBandHeight : 0)
    }
    /// Breathing room to the right of the board.
    ///
    /// Reserving a second *full* gutter here was tried and reverted: at 224 it
    /// cost the board 200pt it did not need, and opening the log sidebar
    /// shrank the game far more than the sidebar actually took. 24 was the
    /// answer to that, and it was too far the other way — on a window too
    /// narrow to centre the board, the left kept its whole 224 and the right
    /// got whatever was left, which on an iPad in portrait was **40pt**. The
    /// board read as shoved against the edge.
    ///
    /// 96 is the middle. It is not symmetry — the left carries every readout
    /// in the game and the right carries nothing, so it should not be — but
    /// it is enough that the board sits in the window rather than against it.
    ///
    /// Taken out of the *square*, not out of the gutter: `squareSize` fits the
    /// board to what is left after both margins, so a narrow window now gets a
    /// slightly smaller board with room on both sides, rather than a board at
    /// the cap with none. The gutter is untouched, which matters — the Chess
    /// Hint is the widest thing in it and at a 96pt square it needs every one
    /// of its 224 points. Squeezing the gutter instead was tried first and
    /// clipped "OR KNIGHT" off the left edge of an iPad.
    static let rightMarginWidth: CGFloat = 96
    var rightMarginWidth: CGFloat { Self.rightMarginWidth }

    /// Never smaller than this, whatever the window does. Below it the pieces
    /// stop being readable and the game stops being playable.
    static let minSquareSize: CGFloat = 32

    // MARK: - Board

    /// The square the game was composed at. Banners and other chrome measure
    /// themselves against this, so it stays the reference even though the board
    /// may now be larger.
    static let designSquareSize: CGFloat = 64
    /// How large the board may grow. See `squareSize`.
    static let maxSquareSize: CGFloat = 96

    var boardSize: CGFloat { squareSize * 8 }

    /// Centred in whatever vertical space the two chrome bands leave.
    var boardBottomY: CGFloat {
        let available = size.height - hudBandHeight - bottomChrome
        return bottomChrome + max(0, (available - boardSize) / 2)
    }
    /// Centred where there is room, and never further left than the gutter
    /// needs — otherwise a narrow window slides the board over the readouts.
    var boardOriginX: CGFloat {
        boardTakesFullWidth ? (size.width - boardSize) / 2
                            : max(minGutterWidth, (size.width - boardSize) / 2)
    }
    var boardOrigin: CGPoint { CGPoint(x: boardOriginX, y: boardBottomY) }
    var boardTopY: CGFloat { boardBottomY + boardSize }

    /// The middle of the board, which is where a centred banner belongs.
    ///
    /// Not the middle of the scene, and the two are never quite the same: the
    /// HUD strip is 68 and the ship's lane 120, so the board sits 26pt above
    /// the window's centre, and on a narrow window the gutter's minimum pushes
    /// it right of centre as well. Banners centred on the window read as
    /// slightly low and slightly left of the board they cover.
    var boardCentre: CGPoint {
        CGPoint(x: boardOriginX + boardSize / 2, y: boardBottomY + boardSize / 2)
    }

    // MARK: - The playfield box
    //
    // The arena the game is played in, as distinct from the window it is drawn
    // in. Extra height already becomes margin rather than board; this makes
    // extra width behave the same way.

    /// How far past the board the playfield extends on each side: one gutter,
    /// scaled with the board.
    ///
    /// The number reproduces the canvas the game was composed on. At the design
    /// size the box is 512 + 2×224 = 960 — exactly the old fixed canvas — and it
    /// stops growing once the square hits its 96pt cap.
    /// Deliberately the static 224 and not `minGutterWidth`, even though the
    /// reservation is now narrower than that in portrait. This is the ship's
    /// lane and the centre the gutter's readouts hang off, so deriving it from
    /// the smaller number would move both — and the portrait change is meant
    /// to grow the board, not relocate anything. Against the constant,
    /// `playfieldMinX` simply clamps to 0 in portrait: the ship gets the dead
    /// space at the far left, which is the same space the board just took a
    /// share of.
    var playfieldMargin: CGFloat { Self.minGutterWidth * contentScale }

    /// Centred on the board, and never outside the window.
    ///
    /// Under the old fixed canvas the ship could fly 194pt — three squares —
    /// past each edge of the board, because that is all the room there was. On
    /// a 2560pt monitor the same code let it fly 866pt, nine squares, out into
    /// empty space, and raiders crossed the whole monitor: `crossingDuration`
    /// is measured in points, so a wide window quietly made every scout take
    /// 2.6× as long and thinned the raider cadence to match. The box puts both
    /// back where they were composed.
    var playfieldMinX: CGFloat {
        boardTakesFullWidth ? 0 : max(0, boardOriginX - playfieldMargin)
    }
    var playfieldMaxX: CGFloat {
        boardTakesFullWidth ? size.width : min(size.width, boardTopX + playfieldMargin)
    }
    var playfieldWidth: CGFloat { playfieldMaxX - playfieldMinX }

    /// The board's right edge.
    var boardTopX: CGFloat { boardOriginX + boardSize }

    // MARK: - Ship lane

    /// Just below the board, so the ship stays with it rather than pinned to
    /// the window's bottom edge as the board moves.
    var shipLaneY: CGFloat { boardBottomY - 58 }
    /// How close to the wall the ship may get.
    var shipMargin: CGFloat { Self.shipWallMargin }

    /// Where the ship may fly: the playfield box, inset by its own margin.
    /// 30…930 at the design size, which is exactly what the fixed canvas gave.
    var shipLane: ClosedRange<CGFloat> {
        let low = playfieldMinX + shipMargin
        return low...max(low, playfieldMaxX - shipMargin)
    }

    // MARK: - Left gutter
    //
    // The column left of the board carrying the turn clock, the check banner,
    // the power-up alley and the Chess and Arcade Hints. In portrait on a phone
    // there is no room for it at all — see docs/IOS-Port.md §5.

    /// The middle of the gutter — measured inside the playfield box, not inside
    /// the window.
    ///
    /// x=112 at the design size, which is the figure every comment in this file
    /// and every alley test is measured against. Against the window instead, a
    /// 2560pt monitor put it at 448 and the turn clock drifted hundreds of
    /// points away from the board it belongs to. Inside the box the column
    /// keeps a constant distance from the board's edge at any size.
    var gutterCentreX: CGFloat {
        usesStackedReadouts ? Self.stackedSideMargin + 12
                            : (playfieldMinX + boardOriginX) / 2
    }

    /// Whether the readout column is drawn from a left edge rather than a centre
    /// line. True wherever it has been stacked under the board — see
    /// `ChessHintNode.setLeftAligned`.
    var readoutsAreLeftAligned: Bool { usesStackedReadouts }

    /// How much to scale everything that is not the board itself: the gutter
    /// readouts, and the centred banners.
    ///
    /// The gutter's *width* is `boardOriginX`, which shrinks with the board —
    /// so its type has to shrink with it or a narrow window has 11pt text in a
    /// 120pt column. Tied to the square, which makes it 1 at the design canvas
    /// and bounded to 0.5…1.5 by the square's own limits.
    var contentScale: CGFloat { squareSize / Self.designSquareSize }

    /// The gutter's own scale, floored.
    ///
    /// `contentScale` reaches 0.5 on the smallest board, which would put the
    /// alley's 9pt type at 4.5 — smaller than the HUD's, and unreadable. The
    /// gutter has room to spare on a narrow window anyway: it is the *board*
    /// that ran out of space, not the column beside it. So it scales, but never
    /// below the point where its type drops under the HUD's.
    var gutterScale: CGFloat { max(Self.minGutterScale, contentScale) }
    /// 9pt of alley type stays at or above 8, which is the HUD's smallest.
    static let minGutterScale: CGFloat = 0.9

    /// Everything from the turn timer down sits this much lower than it used
    /// to, to open a gap between the chess readouts and the power-up block
    /// above them. One constant rather than four edited literals, because the
    /// four move together or the timer's digits land on the transient notice.
    var gutterDrop: CGFloat { 8 * gutterScale }

    /// What the readout column hangs from.
    ///
    /// The board's bottom edge where there is a gutter, and a fixed offset from
    /// the bottom of the screen where the column has been stacked underneath
    /// instead. 10 puts the scaled −4…+172 spread inside the 170pt band with air
    /// at both ends, so nothing below needed re-deriving.
    /// 24 rather than 10: the column's lowest item is `statusBannerY`, which
    /// sits at −4 × scale and then drops a further `gutterDrop`, so a smaller
    /// anchor put it below the bottom of the screen.
    var readoutAnchorY: CGFloat { usesStackedReadouts ? 24 : boardBottomY }

    /// How big FIRE is drawn where it has no margin to be measured against.
    /// Capped so it cannot crowd the readout column beside it.
    var fireButtonScale: CGFloat { min(1, max(0.6, contentScale)) }

    var turnTimerY: CGFloat { readoutAnchorY + 46 * gutterScale - gutterDrop }
    var gutterNoticeY: CGFloat { readoutAnchorY + 30 * gutterScale - gutterDrop }
    var statusBannerY: CGFloat { readoutAnchorY - 4 * gutterScale - gutterDrop }

    /// Chess Hints sit above everything else in the gutter, clearing a full
    /// power-up stack.
    var chessHintY: CGFloat { readoutAnchorY + 172 * gutterScale }

    // MARK: - Power-up alley

    var powerUpAlleyLines: Int { 3 }
    /// The block stacks *upward* from this floor, so the first line the player
    /// earns stays where they last read it and later ones go above it.
    ///
    /// Hung off `readoutAnchorY`, not `boardBottomY`. The two are the same thing
    /// wherever there is a gutter, so this is identical on a Mac and an iPad —
    /// but stacked mode moves the readout column to a fixed offset from the
    /// bottom of the screen, and the alley stayed behind on the board. With a
    /// power-up held it drew about 100pt up onto the squares and straight
    /// through the Chess Hint, whose whole job is to sit clear of a full stack.
    /// `PowerUpAlleyClearanceTests` measures both.
    var powerUpAlleyBottomY: CGFloat { readoutAnchorY + 76 * gutterScale }
    var powerUpAlleyStep: CGFloat { 14 * gutterScale }   // 9pt of type, 5pt of air
    var powerUpAlleyFontSize: CGFloat { 9 * gutterScale }
    var powerUpBarWidth: CGFloat { 84 * gutterScale }
    /// Under the bottom line, which is always the timed effect — it is appended
    /// last and the block grows upward, so the bar never moves.
    var powerUpBarY: CGFloat { powerUpAlleyBottomY - 7 * gutterScale }

    // MARK: - Raiders

    /// Raiders cross at mid-board height (§6), between ranks 4 and 5.
    var raiderLaneY: CGFloat { boardBottomY + boardSize / 2 }
}
