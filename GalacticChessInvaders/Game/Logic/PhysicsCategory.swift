// PhysicsCategory.swift
// Bitmask constants for SpriteKit physics contact detection.

import Foundation

struct PhysicsCategory {
    static let none:          UInt32 = 0
    static let playerLaser:   UInt32 = 0b00001   // white laser beam
    static let enemyPiece:    UInt32 = 0b00010   // black chess piece
    static let friendlyPiece: UInt32 = 0b00100   // white chess piece
    static let enemyShot:     UInt32 = 0b01000   // black projectile
    static let ship:          UInt32 = 0b10000   // player spaceship
    static let raider:        UInt32 = 0b100000  // scout / escort / flagship
}
