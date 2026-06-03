// Piece.swift
// Piece type, color, HP, and damage state. Pure Swift — no SpriteKit.

import Foundation

enum PieceType: String, CaseIterable {
    case pawn, knight, bishop, rook, queen, king

    var maxHP: Int {
        switch self {
        case .pawn:   return 2
        case .knight: return 6
        case .bishop: return 6
        case .rook:   return 8
        case .queen:  return 12
        case .king:   return 16
        }
    }

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

    init(type: PieceType, color: PieceColor, square: String) {
        self.type = type
        self.color = color
        self.hp = type.maxHP
        self.logicalSquare = square
    }

    var isAlive: Bool { hp > 0 }

    var damageState: DamageState {
        let ratio = Double(hp) / Double(type.maxHP)
        switch ratio {
        case 0.75...:    return .full
        case 0.50..<0.75: return .chipped
        case 0.25..<0.50: return .cracked
        default:          return .critical
        }
    }

    /// The full atlas texture name for this piece's current damage state
    var textureName: String {
        "chess-\(color.atlasPrefix)-\(type.atlasName)\(damageState.textureSuffix)"
    }

    /// Apply damage, returns true if piece is now destroyed
    @discardableResult
    mutating func applyDamage(_ amount: Int) -> Bool {
        hp = max(0, hp - amount)
        return hp == 0
    }
}
