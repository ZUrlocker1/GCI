// Piece.swift
// Piece type, color, HP, and damage state. Pure Swift — no SpriteKit.

import Foundation

enum PieceType: String, CaseIterable {
    case pawn, knight, bishop, rook, queen, king

    var maxHP: Int {
        switch self {
        case .pawn:   return 3
        case .knight: return 6
        case .bishop: return 6
        case .rook:   return 8
        case .queen:  return 12
        case .king:   return 16
        }
    }

    /// Points for *shooting* this piece dead with the laser (§9). Higher than
    /// the chess-capture value below — the design intentionally rewards the
    /// arcade half of the game more than the chess half.
    var pointValue: Int {
        switch self {
        case .pawn:   return 25
        case .knight: return 50
        case .bishop: return 50
        case .rook:   return 75
        case .queen:  return 150
        case .king:   return 500
        }
    }

    /// Points for taking this piece in a normal chess capture (§9) — distinct
    /// from, and lower than, `pointValue`. Until Phase 3.2 wired up shooting,
    /// `GameScene` awarded `pointValue` for chess captures too, since it was
    /// the only scoring path that existed; that call site now uses this instead.
    var chessCaptureValue: Int {
        switch self {
        case .pawn:   return 10
        case .knight: return 25
        case .bishop: return 25
        case .rook:   return 40
        case .queen:  return 75
        case .king:   return 500
        }
    }

    /// Atlas base name component e.g. "pawn", "knight"
    var atlasName: String { rawValue }
}

enum PieceColor {
    case white  // player side — cyan glow
    case black  // enemy fleet — magenta glow

    var atlasPrefix: String {
        switch self {
        case .white: return "w"
        case .black: return "b"
        }
    }

    /// Log category, so each move line is tagged WHITE or BLACK.
    var logCategory: LogCategory {
        switch self {
        case .white: return .white
        case .black: return .black
        }
    }
}

/// The four visual damage states driven by HP percentage.
/// Each maps to a specific sprite variant in the atlas.
enum DamageState {
    case full       // base sprite: chess-[w/b]-[piece].png
    case chipped    // d1 sprite:   chess-[w/b]-[piece]-d1.png
    case cracked    // d2 sprite:   chess-[w/b]-[piece]-d2.png
    case critical   // d2 sprite + programmatic flicker (alpha oscillation)

    /// Atlas texture name suffix for this state
    var textureSuffix: String {
        switch self {
        case .full:     return ""
        case .chipped:  return "-d1"
        case .cracked:  return "-d2"
        case .critical: return "-d2"   // same art as cracked; flicker is programmatic
        }
    }
}

struct Piece {
    let type: PieceType
    let color: PieceColor
    var hp: Int
    var logicalSquare: String   // algebraic notation e.g. "e7"

    /// This pawn came back through regeneration (§23.9): dimmer glow, and
    /// worth less than one off the starting board.
    var isRegenerated = false
    /// Chess turns of armor left (§10.1's Armored Pawns). Laser fire does
    /// nothing while this is above zero; a chess capture works as always.
    var armorTurns = 0
    var isArmored: Bool { armorTurns > 0 }

    init(type: PieceType, color: PieceColor, square: String) {
        self.type = type
        self.color = color
        self.hp = type.maxHP
        self.logicalSquare = square
    }

    var isAlive: Bool { hp > 0 }

    /// §7.1's explicit per-piece table, keyed on *damage taken* rather than a
    /// remaining-HP ratio.
    ///
    /// The ratio approximation this replaces was a stage late on exactly the
    /// pieces the player shoots most: a rook's first hit (8→6 HP, ratio 0.75)
    /// still read as undamaged, and a king took three hits before showing
    /// anything. Six of the twenty reachable states disagreed with the doc, all
    /// in the direction of hiding damage.
    var damageState: DamageState {
        let taken = type.maxHP - hp
        switch type {
        case .pawn:
            // 3 HP so a 2-damage laser needs two shots (playtest: one-shot
            // pawns read as inconsistent against every other piece). Two
            // stages so the second shot is always visibly earned.
            if taken >= 2 { return .cracked }
            return taken >= 1 ? .chipped : .full
        case .knight, .bishop:
            if taken >= 5 { return .critical }
            if taken >= 4 { return .cracked }
            return taken >= 2 ? .chipped : .full
        case .rook:
            if taken >= 6 { return .critical }
            if taken >= 4 { return .cracked }
            return taken >= 2 ? .chipped : .full
        case .queen:
            if taken >= 9 { return .critical }
            if taken >= 6 { return .cracked }
            return taken >= 3 ? .chipped : .full
        case .king:
            if taken >= 12 { return .critical }
            if taken >= 8 { return .cracked }
            return taken >= 4 ? .chipped : .full
        }
    }

    /// The full atlas texture name for this piece's current damage state
    var textureName: String {
        "chess-\(color.atlasPrefix)-\(type.atlasName)\(damageState.textureSuffix)"
    }

    /// What shooting this piece is worth. A regenerated pawn pays less: the
    /// armor window was the hard part, and it came back once already (§9).
    var shootValue: Int {
        isRegenerated && type == .pawn
            ? Regeneration.regeneratedPawnValue : type.pointValue
    }

    /// The undamaged art for this piece, whatever state it is in — the source
    /// the surviving wedge is cut from.
    var fullTextureName: String {
        "chess-\(color.atlasPrefix)-\(type.atlasName)"
    }

    /// Apply damage, returns true if piece is now destroyed
    @discardableResult
    mutating func applyDamage(_ amount: Int) -> Bool {
        hp = max(0, hp - amount)
        return hp == 0
    }
}
